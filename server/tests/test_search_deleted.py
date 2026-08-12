"""§15: /api/search must not return medicines the user has deleted.

Search scanned three tables; two respected the soft delete and one did not, so
a medicine a patient removed kept appearing in search results forever while a
deleted visit did not. One line aligns it with `GET /api/medicines` and with the
documents branch of the same file.
"""

import uuid


def _register(client, name="Someone"):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": name, "email": email, "password": "supersecret1"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["token"], resp.json()["id"]


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _add_medicine(client, token, name):
    resp = client.post(
        "/api/medicines",
        json={
            "name": name,
            "dosage": "500mg",
            "frequency": "daily",
            "start_date": "2020-01-01",
            "notes": "searchable-marker",
        },
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


def _search(client, token, q):
    resp = client.get(f"/api/search?q={q}", headers=_auth(token))
    assert resp.status_code == 200, resp.text
    return resp.json()["results"]


def test_a_deleted_medicine_stops_appearing_in_search(client):
    token, _ = _register(client, "Patient")
    med_id = _add_medicine(client, token, "Amlodipine")

    assert _search(client, token, "amlodipine") != []

    resp = client.delete(f"/api/medicines/{med_id}", headers=_auth(token))
    assert resp.status_code == 200, resp.text

    # Gone from the list…
    assert client.get("/api/medicines", headers=_auth(token)).json()["medicines"] == []
    # …and gone from search.
    assert _search(client, token, "amlodipine") == []


def test_a_live_medicine_still_appears_in_search(client):
    token, _ = _register(client, "Patient")
    _add_medicine(client, token, "Metformin")

    results = _search(client, token, "metformin")
    assert results, "a live medicine must stay searchable"
    assert results[0]["type"] == "medicine"


def test_a_deleted_document_stops_appearing_in_search(client):
    """The documents branch already filtered deleted_at; pin that behaviour."""
    token, user_id = _register(client, "Patient")

    resp = client.post(
        "/api/documents",
        json={
            "hospital": "Teaching Hospital",
            "description": "searchable-marker",
        },
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text
    doc_id = resp.json()["id"]

    assert client.delete(f"/api/documents/{doc_id}", headers=_auth(token)).status_code == 200
    assert _search(client, token, "searchable-marker") == []
