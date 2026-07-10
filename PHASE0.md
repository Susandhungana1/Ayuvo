# Phase 0 — Production Hardening: status & runbook

This tracks the Phase 0 items from [todo.md](todo.md). Items marked **Code done**
are implemented in this repo; **Ops** items need infrastructure/accounts and are
documented here as a runbook because they can't be committed as code alone.

---

## ✅ Move files off Postgres — Code done
Medical file bytes no longer live in the database.

- New abstraction: [`server/app/core/storage.py`](server/app/core/storage.py) —
  backend chosen by `STORAGE_BACKEND` (`local` default, or `s3` for AWS S3 /
  Supabase Storage / Cloudflare R2 / MinIO).
- `MedicalReport.storage_key` / `MedicalFile.storage_key` hold the object key;
  the old blob columns are kept **nullable** only so pre-migration rows still read.
- Upload / download / delete / share paths all go through storage.
- **Backfill existing rows** (idempotent):
  ```bash
  cd server
  python -m scripts.migrate_blobs_to_storage --dry-run   # preview
  python -m scripts.migrate_blobs_to_storage             # migrate
  ```
- To use S3/Supabase: set `STORAGE_BACKEND=s3`, `S3_BUCKET`, `S3_REGION`,
  `S3_ENDPOINT_URL`, `S3_ACCESS_KEY_ID` / `S3_SECRET_ACCESS_KEY`, and
  `pip install boto3`.
- **Live:** configured against **Supabase Storage** (bucket `medistore-files`,
  private, encrypted at rest by default). Round-trip (save/read/delete) verified.
  Supabase's S3 endpoint needs path-style addressing — handled automatically in
  `storage.py` whenever `S3_ENDPOINT_URL` is set.

## ✅ Access & audit log — Code done
Append-only `audit_logs` table ([`server/app/core/audit.py`](server/app/core/audit.py)).
Every report file read, document file read, share-link view, emergency-ID view,
and auth event (login / failed login / 2FA) is recorded with actor, subject,
action, resource, IP (X-Forwarded-For aware), and user-agent. Writes are
best-effort and never break the user request.

## ✅ 2FA / TOTP + rate limiting — Code done
- TOTP via `pyotp`: `POST /api/auth/2fa/setup` (returns secret + QR data-URI),
  `/2fa/verify`, `/2fa/disable`, `GET /2fa/status`. When enabled, login requires
  the 6-digit code (sent in the OAuth2 form's `client_secret` field).
- Rate limiting via `slowapi`: login `10/min`, register `5/min`, keyed by client IP.

## ✅ Secrets management — Code done
- No secrets in source. All read from env / `.env` (see
  [`server/.env.example`](server/.env.example)).
- [`server/app/core/config.py`](server/app/core/config.py) **fails fast** when
  `ENVIRONMENT=production` and `JWT_SECRET` is missing/default/too short, or
  `CORS_ORIGINS` is still `*`.

## ✅ Error monitoring + uptime — Code done (needs DSN)
- Sentry wired in [`server/main.py`](server/main.py); set `SENTRY_DSN` to enable
  (`send_default_pii=False` so patient data never leaves the app).
- `GET /health` returns app + DB readiness (503 if DB down) for an uptime check.

## ✅ Automated tests + CI — Code done
- `pytest` suite in [`server/tests/`](server/tests/) (auth, 2FA, report CRUD,
  storage, audit, ownership isolation). Runs on isolated SQLite + temp storage,
  no external services.
- GitHub Actions: [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

## ✅ Cloud Postgres — Provisioned (Supabase)
- Database is live on **Supabase Postgres**, reached via the **session pooler**
  (`aws-0-ap-northeast-1.pooler.supabase.com:5432`) with `sslmode=require`.
- Schema created with `scripts.migrate_schema` (14 tables incl. `audit_logs`,
  all Phase 0 columns). Blob backfill ran (no legacy blobs — fresh DB).
- End-to-end verified: register → upload → object in Supabase Storage → DB blob
  empty → download identical → audit row written → clean delete.
- **Remaining (ops):** enable **automated daily backups + test a restore**.
  Supabase free tier does *not* include managed PITR/daily backups — either
  upgrade to Pro (daily backups / PITR) or schedule a `pg_dump` cron to a bucket.

## ✅ Encryption at rest & in transit — Done
- **At rest:** Supabase encrypts Postgres storage and the Storage bucket by
  default (AES-256). No toggle needed.
- **In transit:** `DATABASE_URL` uses `sslmode=require`; Supabase Storage S3
  endpoint is HTTPS.

---

## ◻ Ops runbook (still needs infrastructure — not code)

### Automated backups (Postgres)
- Supabase free tier lacks managed daily backups. Either upgrade to **Pro**
  (daily backups + 7-day PITR) or run a scheduled `pg_dump` to object storage.
- **Test a restore at least once** before go-live.

### HTTPS + real domain (API host)
- Put the API behind a TLS-terminating platform (Render, Railway, Fly.io) or
  Caddy/Nginx+certbot. Force HTTPS; enable HSTS.
- On the host, set `ENVIRONMENT=production` and
  `CORS_ORIGINS=https://your-frontend-domain` (the app refuses to boot in
  production without a real JWT_SECRET and a non-`*` CORS allowlist).

### Uptime monitoring
- Point an external check (UptimeRobot / BetterStack / Pingdom free tier) at
  `GET /health` and alert on non-200.

### Error monitoring
- Set `SENTRY_DSN` on the host to activate Sentry (already wired in `main.py`).