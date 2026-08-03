"""Step 3: medicine endpoints under caretaker scope.

The containment tests matter most here: a care link grants medicines and
nothing else, and it grants them for exactly one patient.
"""

import uuid

import pytest
from fastapi.testclient import TestClient

from app.core.config import settings


@pytest.fixture
def caretaker_on():
    settings.caretaker_enabled = True
    yield
    settings.caretaker_enabled = False


def _register(client: TestClient, name: str = "User") -> dict:
    email = f"{uuid.uuid4().hex[:10]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": name, "email": email, "password": "supersecret1"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()


def _auth(user: dict) -> dict:
    return {"Authorization": f"Bearer {user['token']}"}


def _link(client, patient, caretaker) -> str:
    code = client.post("/api/care/invites", headers=_auth(patient)).json()["code"]
    resp = client.post(
        "/api/care/invites/redeem", json={"code": code}, headers=_auth(caretaker)
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


def _add_medicine(client, user, name="Metformin", patient_id=None, **kw):
    params = {"patient_id": patient_id} if patient_id else {}
    body = {
        "name": name,
        "dosage": "500mg",
        "frequency": "daily",
        "start_date": "2020-01-01",
        **kw,
    }
    return client.post("/api/medicines", json=body, params=params, headers=_auth(user))


@pytest.fixture
def pair(client, caretaker_on):
    """A linked patient and caretaker."""
    patient = _register(client, "Ram Bahadur")
    caretaker = _register(client, "Sita Sharma")
    _link(client, patient, caretaker)
    return patient, caretaker


# --- Normal patient behaviour is unchanged ---


def test_patient_flow_without_patient_id_is_unaffected(client, caretaker_on):
    patient = _register(client)
    assert _add_medicine(client, patient).status_code == 200
    meds = client.get("/api/medicines", headers=_auth(patient)).json()["medicines"]
    assert [m["name"] for m in meds] == ["Metformin"]


# --- Caretaker CRUD within scope ---


def test_caretaker_can_read_and_write_patient_medicines(client, pair):
    patient, caretaker = pair
    created = _add_medicine(client, caretaker, patient_id=patient["id"])
    assert created.status_code == 200

    # The row belongs to the patient, never the caretaker.
    assert client.get("/api/medicines", headers=_auth(caretaker)).json()["medicines"] == []
    assert len(
        client.get("/api/medicines", headers=_auth(patient)).json()["medicines"]
    ) == 1

    med_id = created.json()["id"]
    updated = client.put(
        f"/api/medicines/{med_id}",
        json={"dosage": "850mg"},
        params={"patient_id": patient["id"]},
        headers=_auth(caretaker),
    )
    assert updated.status_code == 200
    assert updated.json()["dosage"] == "850mg"

    assert client.delete(
        f"/api/medicines/{med_id}",
        params={"patient_id": patient["id"]},
        headers=_auth(caretaker),
    ).status_code == 200
    assert client.get("/api/medicines", headers=_auth(patient)).json()["medicines"] == []


# --- Containment ---


def test_caretaker_cannot_reach_an_unlinked_patient(client, pair):
    _, caretaker = pair
    stranger = _register(client, "Stranger")
    _add_medicine(client, stranger)

    resp = client.get(
        "/api/medicines", params={"patient_id": stranger["id"]}, headers=_auth(caretaker)
    )
    assert resp.status_code == 403


def test_cross_object_reference_is_rejected(client, caretaker_on):
    """The attack the scope check alone would miss: a caretaker pairs the
    patient_id they legitimately hold with a medicine_id belonging to someone
    else. The link check passes; the ownership check must not."""
    caretaker = _register(client, "Caretaker")
    victim = _register(client, "Victim")
    client_patient = _register(client, "Real Client")
    _link(client, client_patient, caretaker)

    victims_med = _add_medicine(client, victim, name="Warfarin").json()["id"]

    attack = client.put(
        f"/api/medicines/{victims_med}",
        json={"dosage": "999mg"},
        params={"patient_id": client_patient["id"]},
        headers=_auth(caretaker),
    )
    assert attack.status_code == 404

    delete_attack = client.delete(
        f"/api/medicines/{victims_med}",
        params={"patient_id": client_patient["id"]},
        headers=_auth(caretaker),
    )
    assert delete_attack.status_code == 404

    # The victim's row is untouched.
    still = client.get("/api/medicines", headers=_auth(victim)).json()["medicines"]
    assert still[0]["dosage"] == "500mg"


def test_revoked_link_403s_every_medicine_endpoint(client, pair):
    patient, caretaker = pair
    med_id = _add_medicine(client, caretaker, patient_id=patient["id"]).json()["id"]

    link_id = client.get(
        "/api/care/links?role=caretaker", headers=_auth(caretaker)
    ).json()["links"][0]["id"]
    client.delete(f"/api/care/links/{link_id}", headers=_auth(patient))

    pid = {"patient_id": patient["id"]}
    assert client.get("/api/medicines", params=pid, headers=_auth(caretaker)).status_code == 403
    assert client.get("/api/medicines/interactions", params=pid, headers=_auth(caretaker)).status_code == 403
    assert client.get("/api/medicines/audit", params=pid, headers=_auth(caretaker)).status_code == 403
    assert _add_medicine(client, caretaker, patient_id=patient["id"]).status_code == 403
    assert client.put(
        f"/api/medicines/{med_id}", json={"dosage": "1g"}, params=pid, headers=_auth(caretaker)
    ).status_code == 403
    assert client.delete(
        f"/api/medicines/{med_id}", params=pid, headers=_auth(caretaker)
    ).status_code == 403


@pytest.mark.parametrize(
    "path",
    [
        "/api/vitals",
        "/api/documents",
        "/api/reports",
        "/api/emergency/profile",
        "/api/timeline",
        "/api/search?q=test",
    ],
)
def test_care_link_grants_nothing_outside_medicines(client, pair, path):
    """A care link must not widen into vitals, documents, reports or AI.

    Passing patient_id to these routes must never return the patient's data:
    either the parameter is ignored (the caretaker sees their own, empty view)
    or the route rejects it. What must not happen is the patient's rows coming
    back.
    """
    patient, caretaker = pair

    # Give the patient something to leak.
    client.post(
        "/api/vitals",
        json={"heart_rate": 123, "notes": "patient-private-marker"},
        headers=_auth(patient),
    )

    sep = "&" if "?" in path else "?"
    resp = client.get(f"{path}{sep}patient_id={patient['id']}", headers=_auth(caretaker))
    assert resp.status_code in (200, 403, 404, 422)
    if resp.status_code == 200:
        assert "patient-private-marker" not in resp.text
        assert "123" not in resp.text


def test_blank_patient_id_is_refused_not_treated_as_self(client, pair):
    """User ids contain '#'. A URL built without percent-encoding truncates the
    value into a fragment and the parameter arrives empty — which must fail
    loudly rather than quietly retargeting the write at the caller's own list."""
    _, caretaker = pair
    resp = client.post(
        "/api/medicines?patient_id=",
        json={
            "name": "Misrouted",
            "dosage": "1mg",
            "frequency": "daily",
            "start_date": "2020-01-01",
        },
        headers=_auth(caretaker),
    )
    assert resp.status_code == 400
    assert client.get("/api/medicines", headers=_auth(caretaker)).json()["medicines"] == []


def test_patient_id_in_body_is_ignored(client, pair):
    """Scope comes from the query string only; a body field must not steer it."""
    patient, caretaker = pair
    resp = client.post(
        "/api/medicines",
        json={
            "name": "Injected",
            "dosage": "1mg",
            "frequency": "daily",
            "start_date": "2020-01-01",
            "patient_id": patient["id"],
            "user_id": patient["id"],
        },
        headers=_auth(caretaker),
    )
    assert resp.status_code == 200
    # It landed on the caretaker's own list, not the patient's.
    assert client.get("/api/medicines", headers=_auth(patient)).json()["medicines"] == []
    assert len(
        client.get("/api/medicines", headers=_auth(caretaker)).json()["medicines"]
    ) == 1


# --- Soft delete & restore ---


def test_delete_is_soft_and_restorable(client, pair):
    patient, caretaker = pair
    med_id = _add_medicine(client, caretaker, patient_id=patient["id"]).json()["id"]
    client.delete(
        f"/api/medicines/{med_id}",
        params={"patient_id": patient["id"]},
        headers=_auth(caretaker),
    )
    assert client.get("/api/medicines", headers=_auth(patient)).json()["medicines"] == []

    restored = client.post(f"/api/medicines/{med_id}/restore", headers=_auth(patient))
    assert restored.status_code == 200
    meds = client.get("/api/medicines", headers=_auth(patient)).json()["medicines"]
    assert [m["name"] for m in meds] == ["Metformin"]


def test_deleted_medicine_is_not_updatable(client, pair):
    patient, caretaker = pair
    med_id = _add_medicine(client, caretaker, patient_id=patient["id"]).json()["id"]
    client.delete(f"/api/medicines/{med_id}", headers=_auth(patient))
    assert client.put(
        f"/api/medicines/{med_id}", json={"dosage": "1g"}, headers=_auth(patient)
    ).status_code == 404


# --- Audit ---


def test_patient_sees_caretaker_activity(client, pair):
    patient, caretaker = pair
    med_id = _add_medicine(client, caretaker, patient_id=patient["id"]).json()["id"]
    client.delete(
        f"/api/medicines/{med_id}",
        params={"patient_id": patient["id"]},
        headers=_auth(caretaker),
    )

    entries = client.get("/api/medicines/audit", headers=_auth(patient)).json()["entries"]
    assert [e["action"] for e in entries] == ["delete", "create"]
    assert all(e["by_caretaker"] for e in entries)
    assert all(e["actor_name"] == "Sita Sharma" for e in entries)
    assert entries[0]["medicine_name"] == "Metformin"


def test_patient_own_changes_are_not_flagged_as_caretaker(client, pair):
    patient, _ = pair
    _add_medicine(client, patient, name="Aspirin")
    entries = client.get("/api/medicines/audit", headers=_auth(patient)).json()["entries"]
    assert entries[0]["by_caretaker"] is False


def test_caretaker_audit_view_is_limited_to_their_own_actions(client, caretaker_on):
    patient = _register(client, "Patient")
    first = _register(client, "First Caretaker")
    second = _register(client, "Second Caretaker")
    _link(client, patient, first)
    _link(client, patient, second)

    _add_medicine(client, first, name="FromFirst", patient_id=patient["id"])
    _add_medicine(client, second, name="FromSecond", patient_id=patient["id"])

    seen = client.get(
        "/api/medicines/audit",
        params={"patient_id": patient["id"]},
        headers=_auth(second),
    ).json()["entries"]
    assert [e["medicine_name"] for e in seen] == ["FromSecond"]

    # The patient sees both.
    all_entries = client.get(
        "/api/medicines/audit", headers=_auth(patient)
    ).json()["entries"]
    assert {e["medicine_name"] for e in all_entries} == {"FromFirst", "FromSecond"}


def test_audit_timestamps_are_marked_utc(client, pair):
    patient, caretaker = pair
    _add_medicine(client, caretaker, patient_id=patient["id"])
    entries = client.get("/api/medicines/audit", headers=_auth(patient)).json()["entries"]
    assert entries[0]["created_at"].endswith("Z")
