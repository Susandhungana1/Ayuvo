"""Step 2: care link endpoints — invite, redeem, list, mute, revoke.

The feature flag is off by default, so `caretaker_on` turns it on for the
duration of a test. Rate limiting is disabled globally in conftest to keep
other suites deterministic; `rate_limited` re-enables it just for the tests
that assert on it.
"""

import uuid

import pytest
from fastapi.testclient import TestClient

import main
from app.core.config import settings
from app.core.ratelimit import limiter


@pytest.fixture
def caretaker_on():
    settings.caretaker_enabled = True
    yield
    settings.caretaker_enabled = False


@pytest.fixture
def rate_limited():
    """Re-enable slowapi and clear its buckets, so counts start from zero."""
    limiter.enabled = True
    limiter.reset()
    yield
    limiter.enabled = False
    limiter.reset()


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


@pytest.fixture
def patient(client):
    return _register(client, "Ram Bahadur")


@pytest.fixture
def caretaker(client):
    return _register(client, "Sita Sharma")


def _issue(client, patient) -> str:
    resp = client.post("/api/care/invites", headers=_auth(patient))
    assert resp.status_code == 200, resp.text
    return resp.json()["code"]


def _redeem(client, caretaker, code):
    return client.post(
        "/api/care/invites/redeem", json={"code": code}, headers=_auth(caretaker)
    )


def _link(client, patient, caretaker):
    resp = _redeem(client, caretaker, _issue(client, patient))
    assert resp.status_code == 200, resp.text
    return resp.json()


# --- Feature flag ---


def test_endpoints_are_hidden_while_flag_is_off(client, patient):
    """Steps 1-4 ship before the UI exists; the feature must be invisible."""
    assert client.post("/api/care/invites", headers=_auth(patient)).status_code == 404
    assert client.get("/api/care/links", headers=_auth(patient)).status_code == 404


# --- Invite / redeem happy path ---


def test_invite_returns_a_grouped_code(client, caretaker_on, patient):
    body = client.post("/api/care/invites", headers=_auth(patient)).json()
    code = body["code"]
    assert len(code) == 9 and code[4] == "-"
    assert not (set(code.replace("-", "")) & set("ILOU"))
    assert body["expires_at"]


def test_timestamps_are_marked_utc(client, caretaker_on, patient, caretaker):
    """Naive timestamps are read as local time by the browser, which makes a
    15-minute code render as already expired east of Greenwich."""
    invite = client.post("/api/care/invites", headers=_auth(patient)).json()
    assert invite["expires_at"].endswith("Z")

    link = _redeem(client, caretaker, invite["code"]).json()
    assert link["created_at"].endswith("Z")

    listed = client.get(
        "/api/care/links?role=patient", headers=_auth(patient)
    ).json()["links"]
    assert listed[0]["created_at"].endswith("Z")


def test_redeem_creates_a_link(client, caretaker_on, patient, caretaker):
    body = _link(client, patient, caretaker)
    assert body["user_id"] == patient["id"]
    assert body["name"] == "Ram Bahadur"
    assert body["notify"] is True


def test_redeem_accepts_a_pasted_lowercase_code(client, caretaker_on, patient, caretaker):
    code = _issue(client, patient)
    assert _redeem(client, caretaker, f"  {code.lower()}  ").status_code == 200


def test_issuing_a_second_code_invalidates_the_first(
    client, caretaker_on, patient, caretaker
):
    first = _issue(client, patient)
    _issue(client, patient)
    resp = _redeem(client, caretaker, first)
    assert resp.status_code == 400
    assert resp.json()["detail"] == "That code isn't valid. Ask for a new one."


# --- Redeem failures ---


def test_wrong_and_used_codes_give_the_same_error(
    client, caretaker_on, patient, caretaker
):
    """No oracle: a wrong code must be indistinguishable from a spent one."""
    code = _issue(client, patient)
    assert _redeem(client, caretaker, code).status_code == 200

    used = _redeem(client, caretaker, code)
    wrong = _redeem(client, caretaker, "ZZZZ-ZZZZ")
    assert used.status_code == wrong.status_code == 400
    assert used.json()["detail"] == wrong.json()["detail"]


def test_expired_code_matches_the_generic_error(client, caretaker_on, patient, caretaker):
    from datetime import datetime, timedelta

    from sqlmodel import Session, select

    from app.core.config import engine
    from app.models.models import CareInvite

    code = _issue(client, patient)
    with Session(engine) as db:
        invite = db.exec(
            select(CareInvite).where(CareInvite.patient_id == patient["id"])
        ).first()
        invite.expires_at = datetime.utcnow() - timedelta(minutes=1)
        db.add(invite)
        db.commit()

    resp = _redeem(client, caretaker, code)
    assert resp.status_code == 400
    assert resp.json()["detail"] == "That code isn't valid. Ask for a new one."


def test_self_redeem_is_rejected(client, caretaker_on, patient):
    resp = _redeem(client, patient, _issue(client, patient))
    assert resp.status_code == 400
    assert "your own code" in resp.json()["detail"]


def test_already_linked_is_reported_clearly(client, caretaker_on, patient, caretaker):
    _link(client, patient, caretaker)
    resp = _redeem(client, caretaker, _issue(client, patient))
    assert resp.status_code == 400
    assert "already a caretaker" in resp.json()["detail"]


# --- Caps ---


def test_patient_caretaker_cap_is_enforced(client, caretaker_on, patient):
    from app.core import care as care_mod

    for _ in range(care_mod.MAX_CARETAKERS_PER_PATIENT):
        _link(client, patient, _register(client, "Helper"))

    resp = client.post("/api/care/invites", headers=_auth(patient))
    assert resp.status_code == 400
    assert "maximum" in resp.json()["detail"]


# --- Listing ---


def test_list_shows_each_side_of_the_link(client, caretaker_on, patient, caretaker):
    _link(client, patient, caretaker)

    mine = client.get(
        "/api/care/links?role=patient", headers=_auth(patient)
    ).json()["links"]
    assert [l["name"] for l in mine] == ["Sita Sharma"]

    theirs = client.get(
        "/api/care/links?role=caretaker", headers=_auth(caretaker)
    ).json()["links"]
    assert [l["name"] for l in theirs] == ["Ram Bahadur"]
    # Client cards carry a medicine summary; patient-side rows do not.
    assert theirs[0]["medicine_count"] == 0
    assert mine[0]["medicine_count"] is None


def test_list_exposes_no_contact_details(client, caretaker_on, patient, caretaker):
    _link(client, patient, caretaker)
    body = client.get("/api/care/links?role=caretaker", headers=_auth(caretaker)).text
    assert patient["email"] not in body


def test_mutual_caretaking(client, caretaker_on, patient, caretaker):
    """Two family members each caring for the other."""
    _link(client, patient, caretaker)
    _link(client, caretaker, patient)

    for user in (patient, caretaker):
        assert len(
            client.get("/api/care/links?role=patient", headers=_auth(user)).json()["links"]
        ) == 1
        assert len(
            client.get("/api/care/links?role=caretaker", headers=_auth(user)).json()["links"]
        ) == 1


# --- Mute ---


def test_caretaker_can_mute_a_client(client, caretaker_on, patient, caretaker):
    link = _link(client, patient, caretaker)
    resp = client.patch(
        f"/api/care/links/{link['id']}", json={"notify": False}, headers=_auth(caretaker)
    )
    assert resp.status_code == 200
    assert resp.json()["notify"] is False


def test_patient_cannot_mute_their_own_caretaker(client, caretaker_on, patient, caretaker):
    link = _link(client, patient, caretaker)
    resp = client.patch(
        f"/api/care/links/{link['id']}", json={"notify": False}, headers=_auth(patient)
    )
    assert resp.status_code == 404


# --- Revoke ---


@pytest.mark.parametrize("revoker", ["patient", "caretaker"])
def test_either_party_can_revoke(client, caretaker_on, patient, caretaker, revoker):
    link = _link(client, patient, caretaker)
    actor = patient if revoker == "patient" else caretaker

    assert client.delete(
        f"/api/care/links/{link['id']}", headers=_auth(actor)
    ).status_code == 200

    assert client.get(
        "/api/care/links?role=caretaker", headers=_auth(caretaker)
    ).json()["links"] == []


def test_stranger_cannot_revoke(client, caretaker_on, patient, caretaker):
    link = _link(client, patient, caretaker)
    stranger = _register(client, "Nosy")
    assert client.delete(
        f"/api/care/links/{link['id']}", headers=_auth(stranger)
    ).status_code == 404


def test_revoked_pair_can_link_again(client, caretaker_on, patient, caretaker):
    """The unique index is partial, so a revoked row must not block a new link."""
    link = _link(client, patient, caretaker)
    client.delete(f"/api/care/links/{link['id']}", headers=_auth(patient))
    assert _redeem(client, caretaker, _issue(client, patient)).status_code == 200


# --- Rate limits ---


def test_redeem_rate_limit_trips_after_five_attempts(
    client, caretaker_on, rate_limited, patient, caretaker
):
    codes = [_issue(client, patient) for _ in range(6)]
    statuses = [_redeem(client, caretaker, c).status_code for c in codes]
    # Five attempts are answered normally; the sixth is throttled.
    assert statuses[:5] == [400] * 5
    assert statuses[5] == 429


def test_redeem_limit_is_per_user_not_per_ip(
    client, caretaker_on, rate_limited, patient
):
    """Two housemates behind one NAT must not exhaust each other's budget."""
    first, second = _register(client, "A"), _register(client, "B")
    for _ in range(5):
        _redeem(client, first, "ZZZZ-ZZZZ")

    assert _redeem(client, first, "ZZZZ-ZZZZ").status_code == 429
    assert _redeem(client, second, "ZZZZ-ZZZZ").status_code == 400


def test_next_dose_is_the_patients_wall_clock(client, caretaker_on, patient, caretaker):
    """A caretaker abroad must see when the *patient* takes the dose, so the
    time is sent as a clock string rather than an instant to be localised."""
    import json

    from sqlmodel import Session

    from app.core.config import engine
    from app.models.models import PushSubscription

    with Session(engine) as db:
        db.add(
            PushSubscription(
                user_id=patient["id"],
                endpoint=f"https://push.example/tz-{patient['id']}",
                p256dh="p",
                auth="a",
                timezone="Asia/Kathmandu",
            )
        )
        db.commit()

    client.post(
        "/api/medicines",
        json={
            "name": "Metformin",
            "dosage": "500mg",
            "frequency": "daily",
            "start_date": "2020-01-01",
            "taking_times": json.dumps(["08:00"]),
        },
        headers=_auth(patient),
    )
    _link(client, patient, caretaker)

    card = client.get(
        "/api/care/links?role=caretaker", headers=_auth(caretaker)
    ).json()["links"][0]

    assert card["next_dose_name"] == "Metformin"
    assert card["next_dose_local"] == "08:00"
    assert card["next_dose_timezone"] == "Asia/Kathmandu"
    assert isinstance(card["next_dose_is_today"], bool)
