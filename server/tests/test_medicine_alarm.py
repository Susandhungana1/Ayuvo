"""Tests for the medicine alarm feature: adherence log, push subscribe, and the
reminder scheduler that fires web pushes when the app is closed."""

import json

from sqlmodel import Session, select

import app.core.reminder_scheduler as scheduler
from app.core.config import engine, settings
from app.core.webpush import PushResult
from app.models.models import Medicine, MedicineIntakeLog, PushSubscription


def _add_medicine(client, taking_times):
    resp = client.post(
        "/api/medicines",
        json={
            "name": "Aspirin",
            "dosage": "500mg",
            "frequency": "Once daily",
            "start_date": "2020-01-01",
            "taking_times": json.dumps(taking_times),
        },
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


def test_intake_log_records_and_lists(auth_client):
    client, _ = auth_client
    med_id = _add_medicine(client, ["08:00"])

    r = client.post(f"/api/medicines/{med_id}/intake", json={"scheduled_time": "08:00", "status": "taken"})
    assert r.status_code == 200, r.text
    assert r.json()["status"] == "taken"

    # Unknown status falls back to "taken".
    r2 = client.post(f"/api/medicines/{med_id}/intake", json={"scheduled_time": "08:00", "status": "bogus"})
    assert r2.status_code == 200
    assert r2.json()["status"] == "taken"

    log = client.get("/api/medicines/intake/log")
    assert log.status_code == 200
    assert len(log.json()["intakes"]) == 2


def test_intake_rejects_other_users_medicine(auth_client, client):
    owner, _ = auth_client
    med_id = _add_medicine(owner, ["09:00"])

    # A second, unrelated user must not be able to log against that medicine.
    import uuid

    email = f"other_{uuid.uuid4().hex[:8]}@example.com"
    reg = client.post("/api/auth/register", json={"name": "Other", "email": email, "password": "supersecret1"})
    token = reg.json()["token"]
    r = client.post(
        f"/api/medicines/{med_id}/intake",
        json={"scheduled_time": "09:00", "status": "taken"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert r.status_code == 404


def _disable_push(monkeypatch):
    # Force push OFF regardless of the ambient env (a local .env may set keys).
    monkeypatch.setattr(settings, "vapid_public_key", "", raising=False)
    monkeypatch.setattr(settings, "vapid_private_key", "", raising=False)


def test_vapid_key_endpoint_reports_disabled_when_unconfigured(client, monkeypatch):
    _disable_push(monkeypatch)
    r = client.get("/api/push/vapid-public-key")
    assert r.status_code == 200
    assert r.json()["enabled"] is False


def test_subscribe_requires_push_configured(auth_client, monkeypatch):
    _disable_push(monkeypatch)
    client, _ = auth_client
    r = client.post(
        "/api/push/subscribe",
        json={"endpoint": "https://example.com/x", "keys": {"p256dh": "a", "auth": "b"}},
    )
    assert r.status_code == 503  # push not configured


def test_subscribe_when_enabled(auth_client, monkeypatch):
    client, _ = auth_client
    monkeypatch.setattr(settings, "vapid_public_key", "PUB", raising=False)
    monkeypatch.setattr(settings, "vapid_private_key", "PRIV", raising=False)

    r = client.post(
        "/api/push/subscribe",
        json={
            "endpoint": "https://push.example/endpoint-1",
            "keys": {"p256dh": "key-p", "auth": "key-a"},
            "timezone": "Asia/Kathmandu",
        },
    )
    assert r.status_code == 200, r.text

    with Session(engine) as db:
        sub = db.exec(
            select(PushSubscription).where(PushSubscription.endpoint == "https://push.example/endpoint-1")
        ).first()
        assert sub is not None
        assert sub.timezone == "Asia/Kathmandu"


def test_scheduler_pushes_due_medicine(auth_client, monkeypatch):
    client, _ = auth_client

    # A medicine due at the current UTC minute.
    now_hhmm = scheduler._local_now("UTC").strftime("%H:%M")
    med_id = _add_medicine(client, [now_hhmm])

    # Find the owning user id via the medicine row.
    with Session(engine) as db:
        med = db.get(Medicine, med_id)
        user_id = med.user_id
        db.add(
            PushSubscription(
                user_id=user_id,
                endpoint="https://push.example/tick-1",
                p256dh="p",
                auth="a",
                timezone="UTC",
            )
        )
        db.commit()

    sent = []

    def fake_send(endpoint, p256dh, auth, payload):
        sent.append((endpoint, payload))
        return PushResult(ok=True)

    monkeypatch.setattr(scheduler, "push_available", lambda: True)
    monkeypatch.setattr(scheduler, "send_push", fake_send)
    scheduler._sent.clear()

    scheduler._run_tick()

    assert len(sent) == 1
    endpoint, payload = sent[0]
    assert endpoint == "https://push.example/tick-1"
    assert payload["medId"] == med_id
    assert payload["time"] == now_hhmm

    # Second tick in the same minute must NOT re-send (dedupe).
    scheduler._run_tick()
    assert len(sent) == 1


def test_scheduler_catch_up_window(auth_client, monkeypatch):
    """A dose whose minute passed a few minutes ago must still fire (covers a
    free-tier instance that was asleep and woke late)."""
    client, _ = auth_client
    from datetime import timedelta

    past = (scheduler._local_now("UTC") - timedelta(minutes=5)).strftime("%H:%M")
    stale = (scheduler._local_now("UTC") - timedelta(minutes=30)).strftime("%H:%M")
    med_id = _add_medicine(client, [past, stale])

    with Session(engine) as db:
        user_id = db.get(Medicine, med_id).user_id
        db.add(
            PushSubscription(
                user_id=user_id, endpoint="https://push.example/late-1",
                p256dh="p", auth="a", timezone="UTC",
            )
        )
        db.commit()

    sent = []
    monkeypatch.setattr(scheduler, "push_available", lambda: True)
    monkeypatch.setattr(scheduler, "send_push", lambda ep, p, a, payload: (sent.append(payload) or PushResult(ok=True)))
    scheduler._sent.clear()

    scheduler._run_tick()

    # The 5-min-ago dose fires; the 30-min-ago one is outside the window.
    times = [p["time"] for p in sent]
    assert past in times
    assert stale not in times


def test_run_tick_endpoint_requires_secret(client, monkeypatch):
    monkeypatch.setattr(settings, "cron_secret", "", raising=False)
    assert client.post("/api/push/run-tick").status_code == 404

    monkeypatch.setattr(settings, "cron_secret", "s3cret", raising=False)
    assert client.post("/api/push/run-tick", headers={"X-Cron-Secret": "wrong"}).status_code == 404

    monkeypatch.setattr(scheduler, "push_available", lambda: False)
    ok = client.post("/api/push/run-tick", headers={"X-Cron-Secret": "s3cret"})
    assert ok.status_code == 200
    assert ok.json()["ok"] is True


def test_scheduler_deletes_dead_subscription(auth_client, monkeypatch):
    client, _ = auth_client
    now_hhmm = scheduler._local_now("UTC").strftime("%H:%M")
    med_id = _add_medicine(client, [now_hhmm])

    with Session(engine) as db:
        user_id = db.get(Medicine, med_id).user_id
        db.add(
            PushSubscription(
                user_id=user_id,
                endpoint="https://push.example/dead-1",
                p256dh="p",
                auth="a",
                timezone="UTC",
            )
        )
        db.commit()

    monkeypatch.setattr(scheduler, "push_available", lambda: True)
    monkeypatch.setattr(scheduler, "send_push", lambda *a, **k: PushResult(ok=False, gone=True))
    scheduler._sent.clear()

    scheduler._run_tick()

    with Session(engine) as db:
        gone = db.exec(
            select(PushSubscription).where(PushSubscription.endpoint == "https://push.example/dead-1")
        ).first()
        assert gone is None
