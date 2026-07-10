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