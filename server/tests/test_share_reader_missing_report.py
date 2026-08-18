"""Regression tests for the single-report reader on records that aren't there.

`GET /api/share/{token}` serves one report, looked up by the link's report_id.
A whole-record link has no report_id, so pasting a QR token at this route sent
a NULL primary key into db.get and reached `get_report_bytes(None)` — an
unhandled AttributeError surfaced to the recipient as a 500. SQLAlchemy was
already warning about it ("fully NULL primary key identity cannot load any
object").

Deleting a report is *not* another route to that crash, though it looks like
one: delete_report revokes the report's share links first, so the link is gone
before the reader can miss its report. That ordering is load-bearing and easy
to lose in a refactor, so it is pinned here too.
"""

import uuid

from sqlmodel import Session, select

from app.core.config import engine
from app.models.models import MedicalReport

FILE_BYTES = b"COMPLETE BLOOD COUNT\nHemoglobin 13.5 g/dL\n"


def _register(client):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": "Owner", "email": email, "password": "supersecret1"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["token"]


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _upload(client, token):
    resp = client.post(
        "/api/reports",
        files={"file": ("cbc.txt", FILE_BYTES, "text/plain")},
        data={"report_type": "BLOOD_TEST", "notes": "routine"},
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


def test_deleting_a_report_revokes_its_share_links(client):
    """The reader never has to face a missing report, because the link goes first."""
    owner = _register(client)
    report_id = _upload(client, owner)

    share = client.post(f"/api/share/{report_id}", headers=_auth(owner))
    assert share.status_code == 200, share.text
    share_token = share.json()["token"]

    # Readable while the report exists.
    assert client.get(f"/api/share/{share_token}").status_code == 200

    assert client.delete(
        f"/api/reports/{report_id}", headers=_auth(owner)
    ).status_code == 200

    # 404 from the link lookup, not a 500 from a dangling report_id.
    resp = client.get(f"/api/share/{share_token}")
    assert resp.status_code == 404, f"expected 404, got {resp.status_code}"
    assert resp.json()["detail"] == "Share link not found"


def test_whole_record_token_is_rejected_by_the_single_report_reader(client):
    """`/api/share/{token}` has no report to serve for an all-reports link."""
    owner = _register(client)
    _upload(client, owner)

    qr = client.post("/api/share/qr-code", headers=_auth(owner))
    assert qr.status_code == 200, qr.text
    share_token = qr.json()["token"]

    resp = client.get(f"/api/share/{share_token}")
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Invalid share link"
    # The route that *can* serve it still does (PIN included — whole-record
    # shares are now PIN-protected).
    pin = qr.json()["pin"]
    assert pin is not None
    assert client.get(f"/api/share/qr-code/{share_token}?pin={pin}").status_code == 200


def test_report_reassigned_away_from_the_sharer_is_not_served(client):
    """Defence in depth: the link may not outlive the sharer's ownership."""
    owner = _register(client)
    other = _register(client)
    report_id = _upload(client, owner)

    share_token = client.post(
        f"/api/share/{report_id}", headers=_auth(owner)
    ).json()["token"]

    with Session(engine) as db:
        report = db.exec(
            select(MedicalReport).where(MedicalReport.id == report_id)
        ).first()
        # Whoever `other` is, the row no longer belongs to the sharer.
        report.user_id = client.get("/api/users/me", headers=_auth(other)).json()["id"]
        db.add(report)
        db.commit()

    assert client.get(f"/api/share/{share_token}").status_code == 404
