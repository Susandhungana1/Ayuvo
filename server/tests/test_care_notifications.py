"""Step 7: the one-off notices about care-link and medicine activity.

These ride the existing Web Push channel — the feature introduces no new
delivery mechanism.
"""

import uuid

import pytest
from sqlmodel import Session

import app.core.notify as notify
from app.core.config import engine, settings
from app.core.webpush import PushResult
from app.models.models import PushSubscription


@pytest.fixture
def caretaker_on():
    settings.caretaker_enabled = True
    yield
    settings.caretaker_enabled = False


@pytest.fixture
def captured(monkeypatch):
    sent: list[tuple[str, dict]] = []
    monkeypatch.setattr(notify, "push_available", lambda: True)
    monkeypatch.setattr(
        notify,
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


def _subscribe(user, tag):
    with Session(engine) as db:
        db.add(
            PushSubscription(
                user_id=user["id"],
                endpoint=f"https://push.example/{tag}",
                p256dh="p",
                auth="a",
                timezone="UTC",
            )
        )
        db.commit()


def _bodies(sent, tag):
    return [p["body"] for ep, p in sent if ep.endswith(f"/{tag}")]


def _link(client, patient, caretaker):
    code = client.post("/api/care/invites", headers=_auth(patient)).json()["code"]
    resp = client.post(
        "/api/care/invites/redeem", json={"code": code}, headers=_auth(caretaker)
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


def _add_medicine(client, actor, name, patient_id=None):
    return client.post(
        "/api/medicines",
        json={
            "name": name,
            "dosage": "500mg",
            "frequency": "daily",
            "start_date": "2020-01-01",
        },
        params={"patient_id": patient_id} if patient_id else {},
        headers=_auth(actor),
    )


def test_patient_is_told_when_someone_redeems_their_code(client, caretaker_on, captured):
    patient, caretaker = _register(client, "Ram"), _register(client, "Sita Sharma")
    _subscribe(patient, "n1")
    _link(client, patient, caretaker)

    assert _bodies(captured, "n1") == ["Sita Sharma is now a caretaker on your account."]


def test_caretaker_is_told_when_the_patient_revokes(client, caretaker_on, captured):
    patient, caretaker = _register(client, "Ram Bahadur"), _register(client, "Sita")
    _subscribe(caretaker, "n2")
    link_id = _link(client, patient, caretaker)
    captured.clear()

    client.delete(f"/api/care/links/{link_id}", headers=_auth(patient))
    assert _bodies(captured, "n2") == ["Ram Bahadur removed you as a caretaker."]


def test_caretaker_leaving_does_not_notify_themselves(client, caretaker_on, captured):
    patient, caretaker = _register(client, "Ram"), _register(client, "Sita")
    _subscribe(caretaker, "n3")
    link_id = _link(client, patient, caretaker)
    captured.clear()

    client.delete(f"/api/care/links/{link_id}", headers=_auth(caretaker))
    assert _bodies(captured, "n3") == []


def test_patient_is_told_when_a_caretaker_adds_or_removes_a_medicine(
    client, caretaker_on, captured
):
    patient, caretaker = _register(client, "Ram"), _register(client, "Sita Sharma")
    _subscribe(patient, "n4")
    _link(client, patient, caretaker)
    captured.clear()

    med_id = _add_medicine(client, caretaker, "Metformin", patient["id"]).json()["id"]
    client.delete(
        f"/api/medicines/{med_id}",
        params={"patient_id": patient["id"]},
        headers=_auth(caretaker),
    )

    assert _bodies(captured, "n4") == [
        "Sita Sharma added Metformin.",
        "Sita Sharma removed Metformin.",
    ]


def test_patients_own_edits_do_not_notify_themselves(client, caretaker_on, captured):
    patient = _register(client, "Ram")
    _subscribe(patient, "n5")

    _add_medicine(client, patient, "Aspirin")
    assert _bodies(captured, "n5") == []


def test_a_dosage_correction_is_not_announced(client, caretaker_on, captured):
    """Updates stay quiet: a caretaker fixing a typo shouldn't be as loud as a
    deletion. The audit feed still records it."""
    patient, caretaker = _register(client, "Ram"), _register(client, "Sita")
    _subscribe(patient, "n6")
    _link(client, patient, caretaker)
    med_id = _add_medicine(client, caretaker, "Metformin", patient["id"]).json()["id"]
    captured.clear()

    client.put(
        f"/api/medicines/{med_id}",
        json={"dosage": "850mg"},
        params={"patient_id": patient["id"]},
        headers=_auth(caretaker),
    )
    assert _bodies(captured, "n6") == []

    entries = client.get("/api/medicines/audit", headers=_auth(patient)).json()["entries"]
    assert entries[0]["action"] == "update"


def test_a_failed_notification_does_not_break_the_request(
    client, caretaker_on, monkeypatch
):
    patient, caretaker = _register(client, "Ram"), _register(client, "Sita")
    _subscribe(patient, "n7")

    monkeypatch.setattr(notify, "push_available", lambda: True)
    monkeypatch.setattr(
        notify,
        "send_push",
        lambda *a, **k: (_ for _ in ()).throw(RuntimeError("provider down")),
    )

    # The link is still created even though announcing it blew up.
    assert _link(client, patient, caretaker)
