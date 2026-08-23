"""The three-stage reminder ladder: pre (T-30), dose (T), verify (T+10).

The dose stage is the original behaviour and keeps the original "webpush"
ledger channel, so old rows still dedupe. The pre and verify stages claim
their own channel values — that is what makes one slot produce up to three
pushes without ever producing six.

Verify is the only conditional stage: it asks "did you take it?" solely when
the patient's adherence log holds no taken/skipped entry for that slot since
the patient's local midnight. A snooze does not settle it; yesterday's log
must not either.
"""

import json
import uuid
from datetime import timedelta

from sqlmodel import Session, select

import app.core.doses as doses
import app.core.reminder_scheduler as scheduler
from app.core.config import engine, settings
from app.core.fcm import FcmResult
from app.core.time import utcnow
from app.core.webpush import PushResult
from app.models.models import (
    CareLink,
    FcmToken,
    Medicine,
    MedicineIntakeLog,
    PushSubscription,
    ReminderDelivery,
    User,
)


def _hhmm(offset_minutes: int) -> str:
    """A slot `offset` minutes from now (UTC), in HH:MM."""
    return (doses.local_now("UTC") + timedelta(minutes=offset_minutes)).strftime(
        "%H:%M"
    )


def _register(client, name: str) -> dict:
    email = f"stage_{uuid.uuid4().hex[:8]}@example.com"
    reg = client.post(
        "/api/auth/register",
        json={"name": name, "email": email, "password": "supersecret1"},
    )
    assert reg.status_code == 200, reg.text
    return reg.json()


def _add_medicine(client, token: str, taking_times: list[str], patient_id=None) -> str:
    """Create a medicine; `patient_id` scopes it via the caretaker route.
    Params-dict on purpose: user ids contain '#', which must arrive encoded."""
    med = client.post(
        "/api/medicines",
        params=({"patient_id": patient_id} if patient_id else None),
        json={
            "name": "Aspirin",
            "dosage": "500mg",
            "frequency": "Once daily",
            "start_date": "2020-01-01",
            "taking_times": json.dumps(taking_times),
        },
        headers={"Authorization": f"Bearer {token}"},
    )
    assert med.status_code == 200, med.text
    return med.json()["id"]


def _make_patient(client, taking_times: list[str]) -> tuple[str, str]:
    """A patient with one medicine and a UTC push device; zone inferred from it."""
    account = _register(client, "Stage User")
    med_id = _add_medicine(client, account["token"], taking_times)

    with Session(engine) as db:
        user = db.get(User, account["id"])
        # Unset so the zone must come from the push device — pins the tick to
        # UTC, where these tests compute their slot times.
        user.timezone = None
        db.add(user)
        db.add(
            PushSubscription(
                user_id=account["id"],
                endpoint=f"https://push.example/{account['id']}",
                p256dh="p",
                auth="a",
                timezone="UTC",
            )
        )
        db.commit()

    return account["id"], med_id


def _arm(monkeypatch, sent: list | None = None):
    """Enable Web Push delivery without touching the network."""
    monkeypatch.setattr(scheduler, "push_available", lambda: True)
    monkeypatch.setattr(scheduler, "fcm_available", lambda: False)

    def _send(endpoint, p256dh, auth, payload):
        if sent is not None:
            sent.append(payload)
        return PushResult(ok=True)

    monkeypatch.setattr(scheduler, "send_push", _send)


def test_pre_reminder_fires_thirty_minutes_before(client, monkeypatch):
    sent: list = []
    _arm(monkeypatch, sent)
    _make_patient(client, [_hhmm(30)])

    scheduler._run_tick()

    assert len(sent) == 1, sent
    payload = sent[0]
    assert payload["stage"] == "pre"
    assert " at " in payload["body"]

    # Idempotent: the next minute's tick must not repeat the heads-up.
    scheduler._run_tick()
    assert len(sent) == 1


def test_pre_window_survives_a_late_tick(client, monkeypatch):
    """A tick delayed to T-25 still lands inside the pre window."""
    sent: list = []
    _arm(monkeypatch, sent)
    _make_patient(client, [_hhmm(25)])

    scheduler._run_tick()

    assert len(sent) == 1
    assert sent[0]["stage"] == "pre"


def test_dose_stage_keeps_its_original_copy_and_channel(client, monkeypatch):
    """The T-stage stays compatible with what shipped before stages: same
    title shape, same ledger channel — historical rows still dedupe."""
    sent: list = []
    _arm(monkeypatch, sent)
    _, med_id = _make_patient(client, [_hhmm(0)])

    scheduler._run_tick()

    assert len(sent) == 1
    payload = sent[0]
    assert payload["title"] == "💊 Medicine Reminder"
    assert payload["medId"] == med_id

    with Session(engine) as db:
        row = db.exec(
            select(ReminderDelivery).where(ReminderDelivery.medicine_id == med_id)
        ).first()
        assert row is not None
        assert row.channel == scheduler.CHANNEL


def test_verify_asks_when_the_dose_was_not_taken(client, monkeypatch):
    sent: list = []
    _arm(monkeypatch, sent)
    _make_patient(client, [_hhmm(-12)])

    scheduler._run_tick()

    assert len(sent) == 1
    payload = sent[0]
    assert payload["stage"] == "verify"
    assert "confirm" in payload["body"].lower()


def test_verify_stays_silent_once_taken(client, monkeypatch):
    sent: list = []
    _arm(monkeypatch, sent)
    user_id, med_id = _make_patient(client, [_hhmm(-12)])

    with Session(engine) as db:
        db.add(
            MedicineIntakeLog(
                user_id=user_id,
                medicine_id=med_id,
                scheduled_time=_hhmm(-12),
                status="taken",
            )
        )
        db.commit()

    scheduler._run_tick()
    assert sent == []


def test_verify_treats_skipped_as_answered(client, monkeypatch):
    """A deliberate skip is an answer, not an oversight — no nag."""
    sent: list = []
    _arm(monkeypatch, sent)
    user_id, med_id = _make_patient(client, [_hhmm(-12)])

    with Session(engine) as db:
        db.add(
            MedicineIntakeLog(
                user_id=user_id,
                medicine_id=med_id,
                scheduled_time=_hhmm(-12),
                status="skipped",
            )
        )
        db.commit()

    scheduler._run_tick()
    assert sent == []


def test_verify_nags_on_a_snoozed_dose(client, monkeypatch):
    """Snoozed means postponed — exactly what the follow-up is for."""
    sent: list = []
    _arm(monkeypatch, sent)
    user_id, med_id = _make_patient(client, [_hhmm(-12)])

    with Session(engine) as db:
        db.add(
            MedicineIntakeLog(
                user_id=user_id,
                medicine_id=med_id,
                scheduled_time=_hhmm(-12),
                status="snoozed",
            )
        )
        db.commit()

    scheduler._run_tick()
    assert len(sent) == 1
    assert sent[0]["stage"] == "verify"


def test_verify_ignores_yesterdays_log(client, monkeypatch):
    """Adherence is per day: last Tuesday's 'taken' says nothing about today."""
    sent: list = []
    _arm(monkeypatch, sent)
    user_id, med_id = _make_patient(client, [_hhmm(-12)])

    with Session(engine) as db:
        db.add(
            MedicineIntakeLog(
                user_id=user_id,
                medicine_id=med_id,
                scheduled_time=_hhmm(-12),
                status="taken",
                recorded_at=utcnow() - timedelta(days=2),
            )
        )
        db.commit()

    scheduler._run_tick()
    assert len(sent) == 1
    assert sent[0]["stage"] == "verify"


def test_caretaker_hears_every_stage_of_a_medicine_they_added(
    client, monkeypatch
):
    """The reported bug: medicines a caretaker creates for their patient never
    seemed to reach the caretaker's devices. Creation assigns the row to the
    patient, so the ladder fans out to the notifying caretaker by name."""
    # The suite pins the flag off; this is the one stage that needs it on.
    monkeypatch.setattr(settings, "caretaker_enabled", True, raising=False)

    sent: list = []
    _arm(monkeypatch, sent)

    patient_id, _ = _make_patient(client, [])
    patient_name = "Stage User"

    keeper = _register(client, "Keeper")
    caretaker_id = keeper["id"]
    with Session(engine) as db:
        db.add(CareLink(patient_id=patient_id, caretaker_id=caretaker_id))
        db.add(
            PushSubscription(
                user_id=caretaker_id,
                endpoint=f"https://push.example/keeper-{caretaker_id}",
                p256dh="p",
                auth="a",
                timezone="UTC",
            )
        )
        db.commit()

    for offset, stage in ((30, "pre"), (0, "dose"), (-12, "verify")):
        # The caretaker adds each medicine FOR the patient — the scoped route.
        _add_medicine(client, keeper["token"], [_hhmm(offset)], patient_id=patient_id)
        scheduler._run_tick()

    to_keeper = [p for p in sent if p.get("forSelf") is False]
    assert len(to_keeper) == 3, sent
    assert {p["stage"] for p in to_keeper} == {"pre", "dose", "verify"}
    for payload in to_keeper:
        # Caretaker copy always leads with whose medicine it is.
        assert patient_name in payload["title"] or payload["patient_name"]


def test_scheduler_runs_when_only_fcm_is_configured(client, monkeypatch):
    """VAPID unset must not starve FCM devices — the gate is any transport."""
    fcm_sends: list = []

    monkeypatch.setattr(scheduler, "push_available", lambda: False)
    monkeypatch.setattr(scheduler, "fcm_available", lambda: True)
    monkeypatch.setattr(
        scheduler,
        "send_fcm",
        lambda token, payload: fcm_sends.append((token, payload))
        or FcmResult(ok=True),
    )

    user_id, _ = _make_patient(client, [_hhmm(0)])
    with Session(engine) as db:
        db.add(FcmToken(user_id=user_id, token="fcm-token-1", timezone="UTC"))
        db.commit()

    scheduler._run_tick()

    assert len(fcm_sends) == 1
    token, payload = fcm_sends[0]
    assert token == "fcm-token-1"
    assert payload["stage"] == "dose"
