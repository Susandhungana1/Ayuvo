"""Step 4: reminder fan-out to caretakers, and the delivery ledger.

The regression guarded hardest here is the zero-caretaker case: a patient with
no links must receive exactly what they received before this feature existed.
"""

import json
import uuid
from datetime import timedelta

import pytest
from sqlmodel import Session, select

import app.core.doses as doses
import app.core.reminder_scheduler as scheduler
from app.core.config import engine, settings
from app.core.webpush import PushResult
from app.models.models import CareLink, Medicine, PushSubscription, ReminderDelivery


@pytest.fixture
def caretaker_on():
    settings.caretaker_enabled = True
    yield
    settings.caretaker_enabled = False


@pytest.fixture
def captured(monkeypatch):
    """Intercept every push, so tests assert on payloads rather than network."""
    sent: list[tuple[str, dict]] = []
    monkeypatch.setattr(scheduler, "push_available", lambda: True)
    monkeypatch.setattr(
        scheduler,
        "send_push",
        lambda ep, p, a, payload: (sent.append((ep, payload)) or PushResult(ok=True)),
    )
    return sent


def _register(client, name):
    email = f"{uuid.uuid4().hex[:10]}@example.com"
    return client.post(
        "/api/auth/register",
        json={"name": name, "email": email, "password": "supersecret1"},
    ).json()


def _auth(user):
    return {"Authorization": f"Bearer {user['token']}"}


def _subscribe(user, tag, tz="UTC"):
    with Session(engine) as db:
        db.add(
            PushSubscription(
                user_id=user["id"],
                endpoint=f"https://push.example/{tag}",
                p256dh="p",
                auth="a",
                timezone=tz,
            )
        )
        db.commit()


def _medicine_due_now(client, user, name="Metformin", offset_minutes=0):
    when = (doses.local_now("UTC") - timedelta(minutes=offset_minutes)).strftime("%H:%M")
    resp = client.post(
        "/api/medicines",
        json={
            "name": name,
            "dosage": "500mg",
            "frequency": "daily",
            "start_date": "2020-01-01",
            "taking_times": json.dumps([when]),
        },
        headers=_auth(user),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["id"], when


def _link(client, patient, caretaker):
    code = client.post("/api/care/invites", headers=_auth(patient)).json()["code"]
    resp = client.post(
        "/api/care/invites/redeem", json={"code": code}, headers=_auth(caretaker)
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


def _fired(sent, *tags):
    """Which of this test's own endpoints actually received a push.

    A tick sweeps every patient in the shared test database, so earlier tests'
    users show up in `sent` too. Scoping to the tags a test created keeps the
    assertion about this test — while still catching a recipient among them who
    should not have been notified.
    """
    want = {f"https://push.example/{t}" for t in tags}
    return {ep for ep, _ in sent if ep in want}


# --- No regression for the un-linked patient ---


def test_patient_without_caretakers_is_unchanged(client, caretaker_on, captured):
    patient = _register(client, "Solo")
    _subscribe(patient, "solo")
    med_id, when = _medicine_due_now(client, patient)

    scheduler._run_tick()

    assert _fired(captured, "solo") == {"https://push.example/solo"}
    ep, payload = next(c for c in captured if c[0].endswith("/solo"))
    assert payload["title"] == "💊 Medicine Reminder"
    assert payload["body"] == "Time for Metformin 500mg"
    assert payload["medId"] == med_id
    assert payload["time"] == when


def test_flag_off_means_no_fanout(client, captured):
    """With the feature disabled the caretaker is not a recipient, even linked."""
    patient, caretaker = _register(client, "Ram"), _register(client, "Sita")
    _subscribe(patient, "p-off")
    _subscribe(caretaker, "c-off")
    with Session(engine) as db:
        db.add(CareLink(patient_id=patient["id"], caretaker_id=caretaker["id"]))
        db.commit()
    _medicine_due_now(client, patient)

    scheduler._run_tick()

    assert _fired(captured, "p-off", "c-off") == {"https://push.example/p-off"}


# --- Fan-out ---


def test_caretaker_receives_the_dose(client, caretaker_on, captured):
    patient, caretaker = _register(client, "Ram Bahadur"), _register(client, "Sita")
    _subscribe(patient, "p1")
    _subscribe(caretaker, "c1")
    _link(client, patient, caretaker)
    _medicine_due_now(client, patient)

    scheduler._run_tick()

    assert _fired(captured, "p1", "c1") == {
        "https://push.example/p1",
        "https://push.example/c1",
    }


def test_copy_differs_by_recipient(client, caretaker_on, captured):
    """A caretaker may watch several people, so their copy leads with the name."""
    patient, caretaker = _register(client, "Ram Bahadur"), _register(client, "Sita")
    _subscribe(patient, "p2")
    _subscribe(caretaker, "c2")
    _link(client, patient, caretaker)
    _medicine_due_now(client, patient)

    scheduler._run_tick()

    by_ep = {ep: payload for ep, payload in captured}
    assert by_ep["https://push.example/p2"]["body"] == "Time for Metformin 500mg"
    assert by_ep["https://push.example/c2"]["body"] == (
        "Ram Bahadur — Metformin 500mg due now"
    )
    assert by_ep["https://push.example/p2"]["forSelf"] is True
    assert by_ep["https://push.example/c2"]["forSelf"] is False


def test_muted_link_delivers_to_patient_only(client, caretaker_on, captured):
    patient, caretaker = _register(client, "Ram"), _register(client, "Sita")
    _subscribe(patient, "p3")
    _subscribe(caretaker, "c3")
    link_id = _link(client, patient, caretaker)
    client.patch(
        f"/api/care/links/{link_id}", json={"notify": False}, headers=_auth(caretaker)
    )
    _medicine_due_now(client, patient)

    scheduler._run_tick()

    assert _fired(captured, "p3", "c3") == {"https://push.example/p3"}


def test_revoked_link_stops_on_the_next_tick(client, caretaker_on, captured):
    patient, caretaker = _register(client, "Ram"), _register(client, "Sita")
    _subscribe(patient, "p4")
    _subscribe(caretaker, "c4")
    link_id = _link(client, patient, caretaker)
    client.delete(f"/api/care/links/{link_id}", headers=_auth(patient))
    _medicine_due_now(client, patient)

    scheduler._run_tick()

    assert _fired(captured, "p4", "c4") == {"https://push.example/p4"}


# --- Idempotency ---


def test_two_ticks_produce_one_delivery_per_recipient(client, caretaker_on, captured):
    patient, caretaker = _register(client, "Ram"), _register(client, "Sita")
    _subscribe(patient, "p5")
    _subscribe(caretaker, "c5")
    _link(client, patient, caretaker)
    med_id, _ = _medicine_due_now(client, patient)

    scheduler._run_tick()
    scheduler._run_tick()
    scheduler._run_tick()

    assert _fired(captured, "p5", "c5") == {
        "https://push.example/p5",
        "https://push.example/c5",
    }
    with Session(engine) as db:
        rows = db.exec(
            select(ReminderDelivery).where(ReminderDelivery.medicine_id == med_id)
        ).all()
        assert len(rows) == 2
        assert {r.recipient_id for r in rows} == {patient["id"], caretaker["id"]}
        assert all(r.status == "sent" for r in rows)


def test_caretaker_linked_mid_day_is_not_backfilled(client, caretaker_on, captured):
    """Linking after a dose already fired must not replay it."""
    patient, caretaker = _register(client, "Ram"), _register(client, "Sita")
    _subscribe(patient, "p6")
    _subscribe(caretaker, "c6")
    med_id, _ = _medicine_due_now(client, patient)

    # The dose fires for the patient alone.
    scheduler._run_tick()
    assert _fired(captured, "p6", "c6") == {"https://push.example/p6"}

    # Caretaker joins, then a later tick covers the same slot.
    _link(client, patient, caretaker)
    captured.clear()
    scheduler._run_tick()

    assert _fired(captured, "p6", "c6") == set()
    with Session(engine) as db:
        rows = db.exec(
            select(ReminderDelivery).where(ReminderDelivery.medicine_id == med_id)
        ).all()
        assert {r.recipient_id for r in rows} == {patient["id"]}


def test_ledger_records_the_dose_slot_not_the_send_time(client, caretaker_on, captured):
    """scheduled_for identifies the dose; a late catch-up send keeps the slot."""
    patient = _register(client, "Ram")
    _subscribe(patient, "p7")
    med_id, when = _medicine_due_now(client, patient, offset_minutes=5)

    scheduler._run_tick()

    with Session(engine) as db:
        row = db.exec(
            select(ReminderDelivery).where(ReminderDelivery.medicine_id == med_id)
        ).first()
        assert row.scheduled_for.strftime("%H:%M") == when


# --- Failure isolation ---


def test_one_recipients_failure_does_not_block_the_other(
    client, caretaker_on, monkeypatch
):
    patient, caretaker = _register(client, "Ram"), _register(client, "Sita")
    _subscribe(patient, "p8-fails")
    _subscribe(caretaker, "c8-works")
    _link(client, patient, caretaker)
    med_id, _ = _medicine_due_now(client, patient)

    def flaky(endpoint, p256dh, auth, payload):
        if "fails" in endpoint:
            raise RuntimeError("push provider exploded")
        return PushResult(ok=True)

    monkeypatch.setattr(scheduler, "push_available", lambda: True)
    monkeypatch.setattr(scheduler, "send_push", flaky)

    scheduler._run_tick()

    with Session(engine) as db:
        rows = {
            r.recipient_id: r
            for r in db.exec(
                select(ReminderDelivery).where(ReminderDelivery.medicine_id == med_id)
            ).all()
        }
        assert rows[patient["id"]].status == "failed"
        assert rows[caretaker["id"]].status == "sent"


def test_deleted_medicine_stops_firing(client, caretaker_on, captured):
    patient = _register(client, "Ram")
    _subscribe(patient, "p9")
    med_id, _ = _medicine_due_now(client, patient)
    client.delete(f"/api/medicines/{med_id}", headers=_auth(patient))

    scheduler._run_tick()

    assert _fired(captured, "p9") == set()


# --- Timezone ---


def test_dose_resolves_in_the_patients_zone_not_the_caretakers(
    client, caretaker_on, captured
):
    """A caretaker abroad is notified at the patient's dose time.

    The patient's device reports Asia/Kathmandu, the caretaker's UTC. The dose
    is scheduled against Kathmandu's clock, and the caretaker still receives it
    at that moment rather than shifted into their own zone.
    """
    patient, caretaker = _register(client, "Ram"), _register(client, "Sita")
    _subscribe(patient, "p10", tz="Asia/Kathmandu")
    _subscribe(caretaker, "c10", tz="UTC")
    _link(client, patient, caretaker)

    ktm_now = doses.local_now("Asia/Kathmandu").strftime("%H:%M")
    client.post(
        "/api/medicines",
        json={
            "name": "Metformin",
            "dosage": "500mg",
            "frequency": "daily",
            "start_date": "2020-01-01",
            "taking_times": json.dumps([ktm_now]),
        },
        headers=_auth(patient),
    )

    scheduler._run_tick()

    assert _fired(captured, "p10", "c10") == {
        "https://push.example/p10",
        "https://push.example/c10",
    }
    mine = [pl for ep, pl in captured if ep.endswith(("/p10", "/c10"))]
    for payload in mine:
        assert payload["time"] == ktm_now
