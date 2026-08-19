"""Report CRUD + storage tests.

Verify the Phase 0 change end to end: uploaded bytes go to object storage (not
the DB blob column), come back byte-identical on download, an audit-log row is
written, and delete removes both DB row and stored object.
"""

from sqlmodel import Session, select

from app.core.config import engine
from app.core import storage
from app.models.models import MedicalReport, AuditLog


FILE_BYTES = b"COMPLETE BLOOD COUNT\nHemoglobin 13.5 g/dL\n"


def _upload(client):
    return client.post(
        "/api/reports",
        files={"file": ("cbc.txt", FILE_BYTES, "text/plain")},
        data={"report_type": "BLOOD_TEST", "notes": "routine"},
    )


def test_upload_stores_bytes_in_object_storage_not_db(auth_client):
    client, _ = auth_client
    resp = _upload(client)
    assert resp.status_code == 200, resp.text
    report_id = resp.json()["id"]

    with Session(engine) as db:
        report = db.get(MedicalReport, report_id)
        assert report.storage_key, "expected a storage key"
        assert report.file_content is None, "bytes must not be inlined in the DB"
        # The bytes are actually in storage and match what we uploaded.
        assert storage.read_file(report.storage_key) == FILE_BYTES


def test_download_returns_uploaded_bytes_and_audits(auth_client):
    client, _ = auth_client
    report_id = _upload(client).json()["id"]

    dl = client.get(f"/api/reports/{report_id}/file")
    assert dl.status_code == 200
    assert dl.content == FILE_BYTES

    with Session(engine) as db:
        logs = db.exec(
            select(AuditLog).where(
                AuditLog.action == "report.file.read",
                AuditLog.resource_id == report_id,
            )
        ).all()
        assert len(logs) >= 1


def test_list_and_delete_report_removes_object(auth_client):
    client, _ = auth_client
    report_id = _upload(client).json()["id"]

    listing = client.get("/api/reports")
    assert listing.status_code == 200
    assert any(r["id"] == report_id for r in listing.json()["reports"])

    with Session(engine) as db:
        key = db.get(MedicalReport, report_id).storage_key

    assert client.delete(f"/api/reports/{report_id}").status_code == 200

    # DB row gone
    with Session(engine) as db:
        assert db.get(MedicalReport, report_id) is None
    # Stored object gone
    try:
        storage.read_file(key)
        assert False, "storage object should have been deleted"
    except FileNotFoundError:
        pass


def test_cannot_access_other_users_report(auth_client, client):
    owner, _ = auth_client
    report_id = _upload(owner).json()["id"]

    # A second, unrelated user
    import uuid

    email = f"other_{uuid.uuid4().hex[:8]}@example.com"
    reg = client.post(
        "/api/auth/register",
        json={"name": "Other", "email": email, "password": "supersecret1"},
    )
    other_token = reg.json()["token"]

    resp = client.get(
        f"/api/reports/{report_id}/file",
        headers={"Authorization": f"Bearer {other_token}"},
    )
    assert resp.status_code == 404

def _with_extracted_text(report_id: str, text: str):
    """Give a report OCR text directly (the background task would do this)."""
    with Session(engine) as db:
        report = db.get(MedicalReport, report_id)
        report.extracted_text = text
        report.ocr_status = "DONE"
        db.add(report)
        db.commit()


# --- background OCR ----------------------------------------------------------

def test_upload_returns_pending_then_background_task_finishes(auth_client):
    """The response returns immediately with ocr_status PENDING; the extract
    task runs before the TestClient hands back, and a follow-up read sees the
    terminal state. A .txt is not an image/PDF, so it resolves to FAILED."""
    client, _ = auth_client
    resp = _upload(client)
    assert resp.status_code == 200, resp.text
    assert resp.json()["ocr_status"] == "PENDING"

    with Session(engine) as db:
        report = db.get(MedicalReport, resp.json()["id"])
        assert report.ocr_status in ("DONE", "FAILED")
        assert report.extracted_text is None  # txt ignored by the extractor

    listing = client.get("/api/reports")
    got = next(r for r in listing.json()["reports"] if r["id"] == resp.json()["id"])
    assert got["ocr_status"] == "FAILED"


# --- manual lab-value corrections --------------------------------------------

def test_put_lab_values_corrects_findings_and_persists(auth_client):
    client, _ = auth_client
    report_id = _upload(client).json()["id"]
    _with_extracted_text(
        report_id, "HEMOGLOBIN 13.5 g/dL\nFasting glucose 98 mg/dL"
    )

    resp = client.put(
        f"/api/reports/{report_id}/lab-values",
        json={"overrides": {"Hemoglobin": {"value": 9.5, "unit": "g/dL"}}},
    )
    assert resp.status_code == 200, resp.text
    hb = next(f for f in resp.json()["findings"] if f["name"] == "Hemoglobin")
    assert hb["value"] == 9.5
    assert hb["status"] == "LOW"
    assert resp.json()["overall"] == "ABNORMAL"
    assert resp.json()["abnormal_count"] == 1

    # Persisted: a fresh lab-analysis read applies the correction too.
    again = client.get(f"/api/reports/{report_id}/lab-analysis")
    hb = next(f for f in again.json()["findings"] if f["name"] == "Hemoglobin")
    assert hb["value"] == 9.5
    assert hb["status"] == "LOW"

    # The untouched glucose finding still reads normal.
    g = next(f for f in again.json()["findings"] if f["name"] == "Glucose (Fasting)")
    assert g["value"] == 98
    assert g["status"] == "NORMAL"


def test_put_lab_values_merges_across_calls(auth_client):
    """Clients send only the finding they corrected. Two successive calls must
    accumulate, not wipe the earlier correction."""
    client, _ = auth_client
    report_id = _upload(client).json()["id"]
    _with_extracted_text(
        report_id, "HEMOGLOBIN 13.5 g/dL\nPlatelet count 250 x10^9/L"
    )

    first = client.put(
        f"/api/reports/{report_id}/lab-values",
        json={"overrides": {"Hemoglobin": {"value": 9.5}}},
    )
    assert first.status_code == 200, first.text

    second = client.put(
        f"/api/reports/{report_id}/lab-values",
        json={"overrides": {"Platelets": {"value": 600}}},
    )
    assert second.status_code == 200, second.text
    assert second.json()["abnormal_count"] == 2

    # Both corrections survived the second write.
    again = client.get(f"/api/reports/{report_id}/lab-analysis")
    hb = next(f for f in again.json()["findings"] if f["name"] == "Hemoglobin")
    pl = next(f for f in again.json()["findings"] if f["name"] == "Platelets")
    assert hb["value"] == 9.5
    assert hb["status"] == "LOW"
    assert pl["value"] == 600
    assert pl["status"] == "HIGH"


def test_put_lab_values_validates_analyte_and_unit(auth_client):
    client, _ = auth_client
    report_id = _upload(client).json()["id"]

    bad_name = client.put(
        f"/api/reports/{report_id}/lab-values",
        json={"overrides": {"Not A Test": {"value": 1}}},
    )
    assert bad_name.status_code == 400

    bad_unit = client.put(
        f"/api/reports/{report_id}/lab-values",
        json={"overrides": {"Hemoglobin": {"value": 12, "unit": "mmol/L"}}},
    )
    assert bad_unit.status_code == 400

    # An empty unit means "keep the OCR'd one" — a client that cleared the
    # unit field must not be rejected, and the stored correction keeps the
    # parsed unit.
    _with_extracted_text(report_id, "HEMOGLOBIN 13.5 g/dL")
    empty_unit = client.put(
        f"/api/reports/{report_id}/lab-values",
        json={"overrides": {"Hemoglobin": {"value": 12, "unit": ""}}},
    )
    assert empty_unit.status_code == 200
    hb = next(f for f in empty_unit.json()["findings"] if f["name"] == "Hemoglobin")
    assert hb["unit"] == "g/dL"


def test_shared_lab_analysis_honours_corrections(auth_client):
    client, _ = auth_client
    report_id = _upload(client).json()["id"]
    _with_extracted_text(report_id, "HEMOGLOBIN 13.5 g/dL")

    client.put(
        f"/api/reports/{report_id}/lab-values",
        json={"overrides": {"Hemoglobin": {"value": 9.5}}},
    )
    token = client.post(f"/api/share/{report_id}").json()["token"]

    shared = client.get(f"/api/share/{token}/lab-analysis")
    assert shared.status_code == 200
    hb = shared.json()["findings"][0]
    assert hb["value"] == 9.5
    assert hb["status"] == "LOW"


def test_put_lab_values_requires_ownership(auth_client, client):
    import uuid

    owner, _ = auth_client
    report_id = _upload(owner).json()["id"]

    email = f"other_{uuid.uuid4().hex[:8]}@example.com"
    other_token = client.post(
        "/api/auth/register",
        json={"name": "Other", "email": email, "password": "supersecret1"},
    ).json()["token"]
    resp = client.put(
        f"/api/reports/{report_id}/lab-values",
        headers={"Authorization": f"Bearer {other_token}"},
        json={"overrides": {"Hemoglobin": {"value": 9.5}}},
    )
    assert resp.status_code == 404
