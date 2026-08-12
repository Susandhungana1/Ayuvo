"""§7: the server can learn a mobile user's timezone.

Before this change the server inferred a patient's zone from the newest Web Push
subscription. A mobile-only patient has none, so their dose arithmetic ran in
UTC — in Nepal that is 5h45m of error, and the caretaker card named the wrong
medicine at the wrong time on the wrong day. The fix is a nullable
`users.timezone` column set through the existing `PUT /api/users/me`, with
`patient_timezone` preferring it and falling back to the push-subscription
lookup exactly as before (unset column ⇒ identical behaviour).
"""

import uuid

import pytest
from fastapi.testclient import TestClient
from sqlmodel import Session

import app.core.doses as doses
from app.core.config import engine, settings
from app.models.models import PushSubscription


@pytest.fixture
def caretaker_on():
    settings.caretaker_enabled = True
    yield
    settings.caretaker_enabled = False


def _register(client: TestClient, name: str) -> dict:
    email = f"{uuid.uuid4().hex[:10]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": name, "email": email, "password": "supersecret1"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


def _auth(user: dict) -> dict:
    return {"Authorization": f"Bearer {user['token']}"}


def _subscribe(patient_id: str, timezone: str, tag: str) -> None:
    with Session(engine) as db:
        db.add(
            PushSubscription(
                user_id=patient_id,
                endpoint=f"https://push.example/{tag}",
                p256dh="p",
                auth="a",
                timezone=timezone,
            )
        )
        db.commit()


# --- PUT /api/users/me accepts the field ---


def test_put_me_stores_and_returns_timezone(client):
    user = _register(client, "Ram Bahadur")

    resp = client.put(
        "/api/users/me",
        json={"timezone": "Asia/Kathmandu"},
        headers=_auth(user),
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["timezone"] == "Asia/Kathmandu"

    me = client.get("/api/users/me", headers=_auth(user)).json()
    assert me["timezone"] == "Asia/Kathmandu"


def test_omitting_timezone_leaves_it_unset_and_does_not_clear_existing(client):
    user = _register(client, "Sita Sharma")

    resp = client.put("/api/users/me", json={"city": "Kathmandu"}, headers=_auth(user))
    assert resp.status_code == 200, resp.text
    assert resp.json()["timezone"] is None

    client.put(
        "/api/users/me",
        json={"timezone": "Asia/Kathmandu"},
        headers=_auth(user),
    )
    resp = client.put("/api/users/me", json={"city": "Pokhara"}, headers=_auth(user))
    assert resp.json()["timezone"] == "Asia/Kathmandu"


def test_blank_timezone_is_treated_as_unset(client):
    user = _register(client, "Gita")
    client.put(
        "/api/users/me",
        json={"timezone": "Asia/Kathmandu"},
        headers=_auth(user),
    )

    resp = client.put("/api/users/me", json={"timezone": "  "}, headers=_auth(user))
    assert resp.status_code == 200, resp.text
    assert resp.json()["timezone"] is None


def test_put_me_response_shape_unchanged_for_existing_fields(client):
    """Regression: the route's existing keys keep their exact meaning."""
    user = _register(client, "Hari")
    before = client.get("/api/users/me", headers=_auth(user)).json()
    expected_keys = {"id", "name", "email", "role", "address", "city"}

    resp = client.put(
        "/api/users/me",
        json={"name": "Hari Prasad", "timezone": "Asia/Kathmandu"},
        headers=_auth(user),
    )
    body = resp.json()
    assert expected_keys.issubset(body.keys())
    assert body["name"] == "Hari Prasad"
    assert before["role"] == body["role"]
    assert before["email"] == body["email"]


# --- patient_timezone prefers the column, then the push device ---


def test_patient_timezone_prefers_user_column_over_push_subscription(client):
    user = _register(client, "Mobile-Only Patient")
    # A push subscription (older inference source) disagrees with the column.
    _subscribe(user["id"], "UTC", "old-device")
    client.put(
        "/api/users/me",
        json={"timezone": "Asia/Kathmandu"},
        headers=_auth(user),
    )

    with Session(engine) as db:
        assert doses.patient_timezone(db, user["id"]) == "Asia/Kathmandu"


def test_patient_timezone_falls_back_to_push_subscription_when_column_unset(client):
    user = _register(client, "Web-Only Patient")
    _subscribe(user["id"], "Asia/Kathmandu", "browser-1")

    with Session(engine) as db:
        assert doses.patient_timezone(db, user["id"]) == "Asia/Kathmandu"


def test_patient_timezone_falls_back_to_utc_when_neither_set(client):
    user = _register(client, "Fresh Patient")

    with Session(engine) as db:
        assert doses.patient_timezone(db, user["id"]) == "UTC"


# --- The symptom this was filed for: the caretaker card's timezone ---


def test_caretaker_card_uses_the_patients_column_timezone(
    client, caretaker_on, monkeypatch
):
    """The card's `next_dose_timezone` comes from the patient's column, not the
    inferrer. The mobile-only patient's zone is what makes 07:00 "tomorrow"
    instead of today's 19:48-in-UTC misreading."""
    patient = _register(client, "Ram Bahadur")
    caretaker = _register(client, "Sita Sharma")
    _subscribe(patient["id"], "UTC", "never-registered-on-web")

    client.put(
        "/api/users/me",
        json={"timezone": "Asia/Kathmandu"},
        headers=_auth(patient),
    )

    resp = client.post(
        "/api/medicines",
        json={
            "name": "Metformin",
            "dosage": "500mg",
            "frequency": "daily",
            "start_date": "2020-01-01",
            "taking_times": '["07:00"]',
        },
        headers=_auth(patient),
    )
    assert resp.status_code == 200, resp.text

    code = client.post("/api/care/invites", headers=_auth(patient)).json()["code"]
    assert client.post(
        "/api/care/invites/redeem", json={"code": code}, headers=_auth(caretaker)
    ).status_code == 200

    links = client.get(
        "/api/care/links?role=caretaker", headers=_auth(caretaker)
    ).json()["links"]
    assert links[0]["next_dose_timezone"] == "Asia/Kathmandu"
