"""The reminder tick must not issue queries per patient.

Sentry PYTHON-FASTAPI-A: `/api/push/run-tick` spent 852ms — 74% of the
transaction — across 12 database spans of three repeating statements. The
per-patient prefix (medicines, the user row, the newest push device) ran for
every patient on every tick, before the early return that skips patients with
nothing due, so the cost grew linearly with signups on a job that fires once a
minute.

Asserting "few queries" by eyeballing a trace does not survive a refactor, so
these tests count statements directly and assert the count does not move with
the number of patients.
"""

import json

from sqlalchemy import event
from sqlmodel import Session, select

import app.core.doses as doses
import app.core.reminder_scheduler as scheduler
from app.core.config import engine
from app.core.webpush import PushResult
from app.models.models import Medicine, PushSubscription, User


class _CountQueries:
    """Count SQL statements issued on the shared engine inside the block."""

    def __init__(self):
        self.statements: list[str] = []

    def _on_execute(self, conn, cursor, statement, params, context, executemany):
        self.statements.append(statement)

    def __enter__(self):
        event.listen(engine, "before_cursor_execute", self._on_execute)
        return self

    def __exit__(self, *exc):
        event.remove(engine, "before_cursor_execute", self._on_execute)
        return False

    def matching(self, needle: str) -> list[str]:
        return [s for s in self.statements if needle in s.lower()]


def _make_patient(client, taking_times, *, with_subscription=True):
    """A registered user owning one medicine, and optionally a push device."""
    import uuid

    email = f"tick_{uuid.uuid4().hex[:8]}@example.com"
    reg = client.post(
        "/api/auth/register",
        json={"name": "Tick User", "email": email, "password": "supersecret1"},
    )
    assert reg.status_code == 200, reg.text
    token = reg.json()["token"]
    headers = {"Authorization": f"Bearer {token}"}

    med = client.post(
        "/api/medicines",
        json={
            "name": "Aspirin",
            "dosage": "500mg",
            "frequency": "Once daily",
            "start_date": "2020-01-01",
            "taking_times": json.dumps(taking_times),
        },
        headers=headers,
    )
    assert med.status_code == 200, med.text
    med_id = med.json()["id"]

    with Session(engine) as db:
        user_id = db.get(Medicine, med_id).user_id
        # Unset so the zone must be inferred from the push device — the branch
        # that issued the second per-patient query.
        user = db.get(User, user_id)
        user.timezone = None
        db.add(user)
        if with_subscription:
            db.add(
                PushSubscription(
                    user_id=user_id,
                    endpoint=f"https://push.example/{user_id}",
                    p256dh="p",
                    auth="a",
                    timezone="UTC",
                )
            )
        db.commit()

    return user_id, med_id


def _quiet_push(monkeypatch):
    """Enable the scheduler without actually sending anything."""
    monkeypatch.setattr(scheduler, "push_available", lambda: True)
    monkeypatch.setattr(
        scheduler, "send_push", lambda *a, **k: PushResult(ok=True)
    )


def _nothing_due(monkeypatch):
    """Pin every patient to the idle path.

    The suite shares one database, so by the time these run it holds patients
    from other test modules — some with doses that really are due right now.
    Stubbing `_is_due` makes the count depend only on the code under test
    instead of on which files ran first, and the idle path is precisely the one
    Sentry flagged: it executes for every patient on every tick.
    """
    monkeypatch.setattr(scheduler, "_stage_for", lambda *a, **k: None)


def test_tick_query_count_does_not_grow_with_patient_count(client, monkeypatch):
    """The regression itself: three patients must not cost three times as much."""
    _quiet_push(monkeypatch)
    _nothing_due(monkeypatch)
    _make_patient(client, ["03:17"])

    with _CountQueries() as one_patient:
        scheduler._run_tick()

    _make_patient(client, ["03:18"])
    _make_patient(client, ["03:19"])

    with _CountQueries() as three_patients:
        scheduler._run_tick()

    assert len(three_patients.statements) == len(one_patient.statements), (
        "tick cost grew with patient count: "
        f"{len(one_patient.statements)} -> {len(three_patients.statements)} queries"
    )


def test_idle_tick_issues_one_query_per_table(client, monkeypatch):
    """Medicines, users, push devices and FCM tokens: one batched SELECT each, no more."""
    _quiet_push(monkeypatch)
    _nothing_due(monkeypatch)
    _make_patient(client, ["03:21"])
    _make_patient(client, ["03:22"])

    with _CountQueries() as counted:
        scheduler._run_tick()

    assert len(counted.matching("from medicines")) == 1
    assert len(counted.matching("from users")) == 1
    assert len(counted.matching("from push_subscriptions")) == 1
    assert len(counted.matching("from fcm_tokens")) == 1
    # Four statements total: no stragglers, and nothing per-patient.
    assert len(counted.statements) == 4, counted.statements


def test_batched_timezone_matches_the_single_patient_lookup(client, monkeypatch):
    """The batched path must resolve the same zone as doses.patient_timezone.

    Two rules that disagree would fire reminders at a time the UI never showed,
    which is worse than the N+1 was.
    """
    _quiet_push(monkeypatch)
    inferred_id, _ = _make_patient(client, ["04:00"])
    explicit_id, _ = _make_patient(client, ["04:01"])

    with Session(engine) as db:
        user = db.get(User, explicit_id)
        user.timezone = "Asia/Kathmandu"
        db.add(user)
        db.commit()

    with Session(engine) as db:
        ids = [inferred_id, explicit_id]
        users_by_id = scheduler._users_by_id(db, ids)
        newest = scheduler._newest_subscription_by_user(db, ids)

        for uid in ids:
            batched = doses.timezone_from(users_by_id.get(uid), newest.get(uid))
            assert batched == doses.patient_timezone(db, uid)

        # And specifically: the column wins, the device is the fallback.
        assert doses.timezone_from(users_by_id[explicit_id], newest.get(explicit_id)) == "Asia/Kathmandu"
        assert doses.timezone_from(users_by_id[inferred_id], newest.get(inferred_id)) == "UTC"


def test_newest_subscription_wins_for_timezone(client, monkeypatch):
    """Two devices, different zones — the most recent one decides."""
    from datetime import datetime, timedelta

    _quiet_push(monkeypatch)
    user_id, _ = _make_patient(client, ["04:30"], with_subscription=False)

    with Session(engine) as db:
        db.add(
            PushSubscription(
                user_id=user_id,
                endpoint="https://push.example/old",
                p256dh="p",
                auth="a",
                timezone="America/New_York",
                created_at=datetime.utcnow() - timedelta(days=2),
            )
        )
        db.add(
            PushSubscription(
                user_id=user_id,
                endpoint="https://push.example/new",
                p256dh="p",
                auth="a",
                timezone="Asia/Kathmandu",
                created_at=datetime.utcnow(),
            )
        )
        db.commit()

    with Session(engine) as db:
        newest = scheduler._newest_subscription_by_user(db, [user_id])
        assert newest[user_id].timezone == "Asia/Kathmandu"
        assert doses.timezone_from(None, newest[user_id]) == "Asia/Kathmandu"
        # Same answer as the unbatched lookup it replaced.
        assert doses.patient_timezone(db, user_id) == "Asia/Kathmandu"


def test_a_patient_with_no_push_device_still_ticks(client, monkeypatch):
    """The batched maps are sparse — a missing row must not raise."""
    _quiet_push(monkeypatch)
    _make_patient(client, ["05:00"], with_subscription=False)

    # Would KeyError rather than .get() if the batching assumed a row per patient.
    scheduler._run_tick()


def test_due_dose_still_fires_after_batching(client, monkeypatch):
    """The optimisation must not cost the feature: a due dose still pushes."""
    sent = []
    monkeypatch.setattr(scheduler, "push_available", lambda: True)
    monkeypatch.setattr(
        scheduler,
        "send_push",
        lambda endpoint, p256dh, auth, payload: (
            sent.append((endpoint, payload)) or PushResult(ok=True)
        ),
    )

    now_hhmm = doses.local_now("UTC").strftime("%H:%M")
    user_id, med_id = _make_patient(client, [now_hhmm])

    scheduler._run_tick()

    assert len(sent) == 1, f"expected one push, got {sent}"
    endpoint, payload = sent[0]
    assert endpoint == f"https://push.example/{user_id}"
    assert payload["medId"] == med_id
    assert payload["time"] == now_hhmm
