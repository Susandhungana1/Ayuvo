"""Test harness.

Runs the app against a throwaway SQLite database and a temp local storage dir,
so tests need no Postgres and touch no real patient data. Environment variables
are set BEFORE importing app modules because config.py builds the DB engine and
reads settings at import time.
"""

import os
import tempfile

# Point config at a temp SQLite DB + temp storage dir before anything imports it.
_TMP = tempfile.mkdtemp(prefix="medistore-test-")
os.environ["DATABASE_URL"] = f"sqlite:///{os.path.join(_TMP, 'test.db')}"
os.environ["STORAGE_BACKEND"] = "local"
os.environ["STORAGE_LOCAL_DIR"] = os.path.join(_TMP, "storage")
os.environ["ENVIRONMENT"] = "development"
os.environ["JWT_SECRET"] = "test_secret_key_that_is_definitely_long_enough_1234"

import pytest
from fastapi.testclient import TestClient
from sqlmodel import SQLModel

import main
from app.core.config import engine
from app.core.ratelimit import limiter


@pytest.fixture(scope="session", autouse=True)
def _prepare_db():
    # Fresh schema for the whole test session.
    SQLModel.metadata.create_all(engine)
    # Rate limiting would make repeated auth calls flaky; disable it in tests.
    limiter.enabled = False
    yield
    SQLModel.metadata.drop_all(engine)


@pytest.fixture
def client():
    return TestClient(main.app)


@pytest.fixture
def auth_client(client):
    """A TestClient with a registered+logged-in user and its bearer token."""
    import uuid

    email = f"user_{uuid.uuid4().hex[:8]}@example.com"
    resp = client.post(
        "/api/auth/register",
        json={"name": "Test User", "email": email, "password": "supersecret1"},
    )
    assert resp.status_code == 200, resp.text
    token = resp.json()["token"]
    client.headers.update({"Authorization": f"Bearer {token}"})
    return client, email