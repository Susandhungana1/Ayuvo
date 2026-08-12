"""Claimed-share tests.

A share link is a bearer token that expires. A *claim* is a signed-in recipient
keeping what the link showed them, so the access outlives the link. The
properties that matter, and that these tests pin down:

  - a claim grants nothing new — you may only keep what you can currently see,
    so an expired link cannot be claimed;
  - the snapshot never widens: reports the owner uploads afterwards stay out;
  - the snapshot is a reference, not a copy, so a deleted report disappears
    from every recipient's view;
  - the owner learns who kept their records, and can withdraw it;
  - no emergency profile (blood type, allergies, next of kin) is ever carried
    into the permanent copy.
"""

import uuid
from datetime import datetime, timedelta

from sqlmodel import Session, select

from app.core.config import engine
from app.models.models import ShareLink, MedicalReport

FILE_BYTES = b"COMPLETE BLOOD COUNT\nHemoglobin 13.5 g/dL\n"


def _register(client, name="Test User"):
    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": name, "email": email, "password": "supersecret1"},
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["token"]


def _auth(token):
    return {"Authorization": f"Bearer {token}"}


def _upload(client, token, name="cbc.txt"):
    resp = client.post(
        "/api/reports",
        files={"file": (name, FILE_BYTES, "text/plain")},
        data={"report_type": "BLOOD_TEST", "notes": "routine"},
        headers=_auth(token),
    )
    assert resp.status_code == 200, resp.text
    return resp.json()["id"]


def _share_all(client, token):
    resp = client.post("/api/share/qr-code", headers=_auth(token))
    assert resp.status_code == 200, resp.text
    return resp.json()["token"]


def _expire(share_token):
    """Backdate a link so it is past its window."""
    with Session(engine) as db:
        link = db.exec(select(ShareLink).where(ShareLink.token == share_token)).first()
        link.expires_at = datetime.utcnow() - timedelta(hours=1)
        db.add(link)
        db.commit()


def _sender_and_claim(client):
    """An owner with one report, and a recipient who has claimed the link."""
    owner = _register(client, "Owner Person")
    recipient = _register(client, "Recipient Person")
    report_id = _upload(client, owner)
    share_token = _share_all(client, owner)

    resp = client.post(f"/api/share/{share_token}/claim", headers=_auth(recipient))
    assert resp.status_code == 200, resp.text
    return owner, recipient, report_id, share_token, resp.json()["id"]


def test_claim_appears_in_recipients_received_list(client):
    _, recipient, _, _, claim_id = _sender_and_claim(client)

    resp = client.get("/api/share/received", headers=_auth(recipient))
    assert resp.status_code == 200, resp.text
    shares = resp.json()["shares"]
    assert len(shares) == 1
    assert shares[0]["id"] == claim_id
    assert shares[0]["owner_name"] == "Owner Person"
    assert shares[0]["report_count"] == 1


def test_claimed_share_survives_the_link_expiring(client):
    """The whole point: the link dies, the claim does not."""
    _, recipient, _, share_token, claim_id = _sender_and_claim(client)
    _expire(share_token)

    # The public reader is now closed...
    assert client.get(f"/api/share/qr-code/{share_token}").status_code == 410
    # ...but the recipient still has what they kept.
    resp = client.get(f"/api/share/received/{claim_id}", headers=_auth(recipient))
    assert resp.status_code == 200, resp.text
    assert len(resp.json()["reports"]) == 1


def test_expired_link_cannot_be_claimed(client):
    """You may keep what you are being shown, not resurrect a closed window."""
    owner = _register(client)
    recipient = _register(client)
    _upload(client, owner)
    share_token = _share_all(client, owner)
    _expire(share_token)

    resp = client.post(f"/api/share/{share_token}/claim", headers=_auth(recipient))
    assert resp.status_code == 410


def test_claiming_requires_a_session(client):
    owner = _register(client)
    _upload(client, owner)
    share_token = _share_all(client, owner)

    assert client.post(f"/api/share/{share_token}/claim").status_code == 401


def test_claim_is_idempotent(client):
    owner = _register(client)
    recipient = _register(client)
    _upload(client, owner)
    share_token = _share_all(client, owner)

    first = client.post(f"/api/share/{share_token}/claim", headers=_auth(recipient))
    second = client.post(f"/api/share/{share_token}/claim", headers=_auth(recipient))
    assert first.status_code == second.status_code == 200
    assert first.json()["id"] == second.json()["id"]

    listing = client.get("/api/share/received", headers=_auth(recipient)).json()
    assert len(listing["shares"]) == 1, "second save must not stack a duplicate"


def test_cannot_claim_your_own_share(client):
    owner = _register(client)
    _upload(client, owner)
    share_token = _share_all(client, owner)

    resp = client.post(f"/api/share/{share_token}/claim", headers=_auth(owner))
    assert resp.status_code == 400
    assert "your own" in resp.json()["detail"]


def test_snapshot_never_widens_to_later_uploads(client):
    """Consent was for what was on screen, not for everything to come."""
    owner, recipient, _, _, claim_id = _sender_and_claim(client)
    _upload(client, owner, name="later.txt")

    detail = client.get(
        f"/api/share/received/{claim_id}", headers=_auth(recipient)
    ).json()
    assert len(detail["reports"]) == 1, "a report uploaded after the claim leaked in"


def test_owner_deleting_a_report_withdraws_it_from_the_claim(client):
    """A reference, not a copy — deletion propagates."""
    owner, recipient, report_id, _, claim_id = _sender_and_claim(client)

    assert client.delete(
        f"/api/reports/{report_id}", headers=_auth(owner)
    ).status_code == 200

    detail = client.get(
        f"/api/share/received/{claim_id}", headers=_auth(recipient)
    ).json()
    assert detail["reports"] == []
    assert detail["withdrawn_count"] == 1


def test_claim_carries_no_emergency_profile(client):
    """The reader shows blood type and next of kin live; the kept copy must not."""
    _, recipient, _, _, claim_id = _sender_and_claim(client)

    body = client.get(
        f"/api/share/received/{claim_id}", headers=_auth(recipient)
    ).json()
    assert "emergency" not in body
    assert "user_blood_type" not in body


def test_owner_sees_who_kept_their_records(client):
    owner, _, _, _, claim_id = _sender_and_claim(client)

    resp = client.get("/api/share/claims", headers=_auth(owner))
    assert resp.status_code == 200, resp.text
    claims = resp.json()["claims"]
    assert len(claims) == 1
    assert claims[0]["id"] == claim_id
    assert claims[0]["recipient_name"] == "Recipient Person"


def test_owner_can_withdraw_a_claim(client):
    owner, recipient, _, _, claim_id = _sender_and_claim(client)

    assert client.delete(
        f"/api/share/claims/{claim_id}", headers=_auth(owner)
    ).status_code == 200

    assert client.get(
        f"/api/share/received/{claim_id}", headers=_auth(recipient)
    ).status_code == 404
    assert client.get("/api/share/received", headers=_auth(recipient)).json()["shares"] == []


def test_recipient_can_drop_a_share_from_their_own_list(client):
    _, recipient, _, _, claim_id = _sender_and_claim(client)

    assert client.delete(
        f"/api/share/received/{claim_id}", headers=_auth(recipient)
    ).status_code == 200
    assert client.get("/api/share/received", headers=_auth(recipient)).json()["shares"] == []


def test_a_stranger_cannot_read_someone_elses_claim(client):
    _, _, _, _, claim_id = _sender_and_claim(client)
    stranger = _register(client, "Nosy Person")

    assert client.get(
        f"/api/share/received/{claim_id}", headers=_auth(stranger)
    ).status_code == 404
    # Nor withdraw it: only the owner of the records may do that.
    assert client.delete(
        f"/api/share/claims/{claim_id}", headers=_auth(stranger)
    ).status_code == 404


def test_owner_cannot_read_the_claim_through_the_recipients_route(client):
    """`/received` is scoped to the recipient, even for the records' owner."""
    owner, _, _, _, claim_id = _sender_and_claim(client)

    assert client.get(
        f"/api/share/received/{claim_id}", headers=_auth(owner)
    ).status_code == 404


def test_single_report_link_claims_only_that_report(client):
    owner = _register(client, "Owner Person")
    recipient = _register(client)
    first = _upload(client, owner, name="one.txt")
    _upload(client, owner, name="two.txt")

    made = client.post(f"/api/share/{first}", headers=_auth(owner))
    assert made.status_code == 200, made.text
    share_token = made.json()["token"]

    claim = client.post(f"/api/share/{share_token}/claim", headers=_auth(recipient))
    assert claim.status_code == 200, claim.text
    assert claim.json()["kind"] == "report"
    assert claim.json()["report_count"] == 1

    detail = client.get(
        f"/api/share/received/{claim.json()['id']}", headers=_auth(recipient)
    ).json()
    assert [r["id"] for r in detail["reports"]] == [first]


def test_received_route_is_not_swallowed_by_the_token_catch_all(client):
    """`/received` is a literal path, not a share token.

    Registered above `GET /{token}` on purpose — FastAPI matches in declaration
    order, so getting this wrong turns the list endpoint into a 404 lookup for
    a share link named "received".
    """
    recipient = _register(client)
    resp = client.get("/api/share/received", headers=_auth(recipient))
    assert resp.status_code == 200
    assert resp.json() == {"shares": []}
