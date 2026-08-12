"""§9: /api/timeline slices in SQL, not in Python.

The old handler loaded every report, medicine, appointment and vital sign for
the account, merged them, sorted in Python, and *then* sliced — so every "Show
older" tap re-read the entire account. The slice now happens in SQL (UNION ALL
+ ORDER BY + LIMIT/OFFSET). Same request, same response; these tests pin the
observable behaviour.
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


def _timeline(client, token, **params):
    resp = client.get("/api/timeline", params=params, headers=_auth(token))
    assert resp.status_code == 200, resp.text
    return resp.json()


def test_timeline_returns_events_across_tables(client):
    token, _ = _register(client, "Patient")

    resp = client.post(
        "/api/medicines",
        json={
            "name": "Amlodipine",
            "dosage": "5mg",
            "frequency": "daily",
            "start_date": "2020-01-01",
        },
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text

    body = _timeline(client, token)
    assert body["total"] >= 1
    assert any(e["type"] == "medicine" for e in body["events"])


def test_timeline_events_are_sorted_newest_first(client):
    token, _ = _register(client, "Patient")

    for name in ("First", "Second"):
        resp = client.post(
            "/api/medicines",
            json={
                "name": name,
                "dosage": "5mg",
                "frequency": "daily",
                "start_date": "2020-01-01",
            },
            headers=_auth(token),
        )
        assert resp.status_code == 200, resp.text

    dates = [e["date"] for e in _timeline(client, token)["events"]]
    assert dates == sorted(dates, reverse=True)


def test_limit_and_offset_page_the_results(client):
    token, _ = _register(client, "Patient")

    for name in ("A", "B", "C", "D", "E"):
        client.post(
            "/api/medicines",
            json={
                "name": name,
                "dosage": "5mg",
                "frequency": "daily",
                "start_date": "2020-01-01",
            },
            headers=_auth(token),
        )

    body = _timeline(client, token)
    total = body["total"]
    assert total >= 5

    page1 = _timeline(client, token, limit=2, offset=0)["events"]
    page2 = _timeline(client, token, limit=2, offset=2)["events"]
    assert len(page1) == 2
    assert len(page2) == 2
    ids1 = {e["id"] for e in page1}
    ids2 = {e["id"] for e in page2}
    assert not (ids1 & ids2), "pages must not overlap"
    assert ids1 | ids2 <= {e["id"] for e in _timeline(client, token)["events"]}


def test_total_is_the_full_count_not_the_page_size(client):
    token, _ = _register(client, "Patient")

    for name in ("A", "B", "C"):
        client.post(
            "/api/medicines",
            json={
                "name": name,
                "dosage": "5mg",
                "frequency": "daily",
                "start_date": "2020-01-01",
            },
            headers=_auth(token),
        )

    full = _timeline(client, token)
    paged = _timeline(client, token, limit=2)
    assert paged["total"] == full["total"] == 3
    assert len(paged["events"]) == 2


def test_vital_signs_appear_in_the_timeline(client):
    token, _ = _register(client, "Patient")

    resp = client.post(
        "/api/vitals",
        json={"heart_rate": 72, "weight": 68.5, "notes": "timeline-marker"},
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text

    events = _timeline(client, token)["events"]
    vital = next((e for e in events if e["type"] == "vital"), None)
    assert vital is not None
    assert "HR: 72" in vital["description"]
    assert "Weight: 68.5kg" in vital["description"]
