"""Document creation, with the checkup date it always meant to record.

`checkup_date` is a new optional field. The tests that matter most here are the
ones proving its absence changes nothing: front/ was posting the field into a
model that didn't declare it, so both "omitted" and "empty string" have to keep
behaving exactly as they did.
"""

from datetime import datetime, timedelta

from sqlmodel import Session

from app.core.config import engine
from app.models.models import MedicalDocument


def test_checkup_date_is_honoured_when_supplied(auth_client):
    client, _ = auth_client
    resp = client.post(
        "/api/documents",
        json={"hospital": "Bir Hospital", "checkup_date": "2019-04-17T00:00:00"},
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["checkup_date"].startswith("2019-04-17")

    with Session(engine) as db:
        doc = db.get(MedicalDocument, resp.json()["id"])
        assert doc.checkup_date.date() == datetime(2019, 4, 17).date()


def test_date_only_string_is_accepted(auth_client):
    """front/ sends the raw value of an <input type="date">."""
    client, _ = auth_client
    resp = client.post(
        "/api/documents", json={"hospital": "Patan Hospital", "checkup_date": "2020-11-02"}
    )
    assert resp.status_code == 200, resp.text
    assert resp.json()["checkup_date"].startswith("2020-11-02")


# --- Regression: callers that don't send the field are unaffected ---


def test_omitted_checkup_date_still_stamps_now(auth_client):
    client, _ = auth_client
    before = datetime.utcnow() - timedelta(seconds=5)

    resp = client.post("/api/documents", json={"hospital": "Teaching Hospital"})
    assert resp.status_code == 200, resp.text

    with Session(engine) as db:
        doc = db.get(MedicalDocument, resp.json()["id"])
        assert doc.checkup_date is not None
        assert doc.checkup_date >= before


def test_empty_checkup_date_is_treated_as_omitted(auth_client):
    """An empty date input must not turn a working request into a 422."""
    client, _ = auth_client
    before = datetime.utcnow() - timedelta(seconds=5)

    resp = client.post("/api/documents", json={"hospital": "Norvic", "checkup_date": ""})
    assert resp.status_code == 200, resp.text

    with Session(engine) as db:
        doc = db.get(MedicalDocument, resp.json()["id"])
        assert doc.checkup_date >= before


def test_the_rest_of_the_shape_is_unchanged(auth_client):
    client, _ = auth_client
    resp = client.post(
        "/api/documents",
        json={
            "hospital": "Grande",
            "location": "Kathmandu",
            "doctor_name": "Ram Sharma",
            "department": "Cardiology",
            "description": "Follow-up",
        },
    )
    assert resp.status_code == 200, resp.text
    body = resp.json()
    assert body["hospital"] == "Grande"
    assert body["location"] == "Kathmandu"
    assert body["doctor_name"] == "Ram Sharma"
    assert body["department"] == "Cardiology"
    assert body["description"] == "Follow-up"
    assert set(body) == {
        "id", "hospital", "location", "doctor_name", "department",
        "description", "checkup_date",
    }


def test_garbage_date_is_still_a_validation_error(auth_client):
    client, _ = auth_client
    resp = client.post(
        "/api/documents", json={"hospital": "Grande", "checkup_date": "not-a-date"}
    )
    assert resp.status_code == 422


def test_list_documents_returns_the_documents(auth_client):
    """Regression: this endpoint 500'd on every call.

    `DocumentResponse.model_validate(doc)` was handed an ORM object without
    from_attributes, so pydantic rejected it. front/ swallows the failure and
    renders "No medical records yet", which is why nobody noticed.
    """
    client, _ = auth_client
    created = client.post("/api/documents", json={"hospital": "Bir Hospital"})
    assert created.status_code == 200, created.text

    listing = client.get("/api/documents")
    assert listing.status_code == 200, listing.text
    assert created.json()["id"] in [d["id"] for d in listing.json()["documents"]]


def test_list_orders_by_checkup_date_desc(auth_client):
    """Back-dating a document sorts it correctly, which is the point of the field."""
    client, _ = auth_client
    client.post("/api/documents", json={"hospital": "Old visit", "checkup_date": "2015-01-01"})
    client.post("/api/documents", json={"hospital": "Recent visit", "checkup_date": "2024-01-01"})

    docs = client.get("/api/documents").json()["documents"]
    hospitals = [d["hospital"] for d in docs if d["hospital"] in ("Old visit", "Recent visit")]
    assert hospitals == ["Recent visit", "Old visit"]
