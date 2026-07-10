"""Object storage abstraction.

Phase 0: medical file blobs must live in object storage, not in Postgres.
This module exposes a tiny backend-agnostic API so the rest of the app never
cares where bytes physically live:

    key = save_file(content, original_name="scan.pdf", prefix="reports")
    data = read_file(key)
    delete_file(key)

The backend is chosen by the ``STORAGE_BACKEND`` env var:

* ``local``  (default) — writes under ``STORAGE_LOCAL_DIR`` (./storage). Zero
  setup, good for dev and self-hosting.
* ``s3``     — any S3-compatible store (AWS S3, Supabase Storage S3 endpoint,
  Cloudflare R2, MinIO). Requires ``boto3`` and the S3_* env vars.

Only the ``local`` backend is a hard dependency. ``boto3`` is imported lazily so
the app still boots without it when you are not using S3.
"""

from __future__ import annotations

import uuid
from pathlib import Path
from typing import Optional

from app.core.config import settings


def _safe_ext(original_name: Optional[str]) -> str:
    """Return a lowercase extension (with dot) we are willing to keep in a key."""
    if not original_name:
        return ""
    ext = Path(original_name).suffix.lower()
    # keep it short and alphanumeric to avoid path tricks
    if len(ext) > 12 or not ext[1:].isalnum():
        return ""
    return ext


def build_key(original_name: Optional[str] = None, prefix: str = "files") -> str:
    """Generate a fresh, collision-free storage key for a new object."""
    return f"{prefix}/{uuid.uuid4().hex}{_safe_ext(original_name)}"


class StorageBackend:
    def save(self, content: bytes, key: str, content_type: Optional[str] = None) -> str:
        raise NotImplementedError

    def read(self, key: str) -> bytes:
        raise NotImplementedError

    def delete(self, key: str) -> None:
        raise NotImplementedError


class LocalStorage(StorageBackend):
    """Stores objects on the local filesystem under a base directory."""

    def __init__(self, base_dir: str):
        self.base = Path(base_dir).resolve()
        self.base.mkdir(parents=True, exist_ok=True)

    def _path(self, key: str) -> Path:
        # Resolve and confirm the target stays inside the base dir (no ../ escapes).
        target = (self.base / key).resolve()
        if self.base not in target.parents and target != self.base:
            raise ValueError("Invalid storage key")
        return target

    def save(self, content: bytes, key: str, content_type: Optional[str] = None) -> str:
        path = self._path(key)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)
        return key

    def read(self, key: str) -> bytes:
        path = self._path(key)
        if not path.exists():
            raise FileNotFoundError(key)
        return path.read_bytes()

    def delete(self, key: str) -> None:
        path = self._path(key)
        if path.exists():
            path.unlink()


class S3Storage(StorageBackend):
    """Stores objects in any S3-compatible bucket."""

    def __init__(self):
        try:
            import boto3  # noqa: F401
        except ImportError as exc:  # pragma: no cover - depends on optional dep
            raise RuntimeError(
                "STORAGE_BACKEND=s3 requires boto3. Install with `pip install boto3`."
            ) from exc
        import boto3

        self.bucket = settings.s3_bucket
        if not self.bucket:
            raise RuntimeError("STORAGE_BACKEND=s3 requires S3_BUCKET to be set.")

        client_kwargs = {
            "region_name": settings.s3_region or None,
            "endpoint_url": settings.s3_endpoint_url or None,
        }
        # Explicit keys if provided; otherwise boto3 falls back to its default
        # credential chain (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY, IAM role…).
        if settings.s3_access_key_id and settings.s3_secret_access_key:
            client_kwargs["aws_access_key_id"] = settings.s3_access_key_id
            client_kwargs["aws_secret_access_key"] = settings.s3_secret_access_key
        # Custom (non-AWS) S3 endpoints like Supabase/MinIO require path-style
        # addressing; the default virtual-hosted style would put the bucket in
        # the hostname and fail against those providers.
        if settings.s3_endpoint_url:
            from botocore.config import Config
            client_kwargs["config"] = Config(s3={"addressing_style": "path"})

        self.client = boto3.client("s3", **client_kwargs)

    def save(self, content: bytes, key: str, content_type: Optional[str] = None) -> str:
        extra = {"ContentType": content_type} if content_type else {}
        self.client.put_object(Bucket=self.bucket, Key=key, Body=content, **extra)
        return key

    def read(self, key: str) -> bytes:
        # Normalize "missing object" to FileNotFoundError so both backends behave
        # identically (LocalStorage raises FileNotFoundError; callers catch that).
        from botocore.exceptions import ClientError
        try:
            obj = self.client.get_object(Bucket=self.bucket, Key=key)
        except ClientError as exc:
            code = exc.response.get("Error", {}).get("Code", "")
            if code in ("NoSuchKey", "404", "NotFound"):
                raise FileNotFoundError(key) from exc
            raise
        return obj["Body"].read()

    def delete(self, key: str) -> None:
        self.client.delete_object(Bucket=self.bucket, Key=key)


def _build_backend() -> StorageBackend:
    backend = (settings.storage_backend or "local").lower()
    if backend == "local":
        return LocalStorage(settings.storage_local_dir)
    if backend == "s3":
        return S3Storage()
    raise RuntimeError(f"Unknown STORAGE_BACKEND: {backend!r} (expected 'local' or 's3')")


# One shared backend instance for the process.
_backend: Optional[StorageBackend] = None


def get_backend() -> StorageBackend:
    global _backend
    if _backend is None:
        _backend = _build_backend()
    return _backend


def save_file(content: bytes, original_name: Optional[str] = None, prefix: str = "files",
              content_type: Optional[str] = None) -> str:
    """Persist ``content`` and return the storage key to save in the DB."""
    key = build_key(original_name, prefix)
    return get_backend().save(content, key, content_type)


def read_file(key: str) -> bytes:
    return get_backend().read(key)


def delete_file(key: Optional[str]) -> None:
    if not key:
        return
    try:
        get_backend().delete(key)
    except FileNotFoundError:
        pass