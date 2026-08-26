# Ayuvo - Personal Digital Health Store

FastAPI backend for the Ayuvo web application.

## Naming: Ayuvo (renamed from MediStore, Aug 2026)

The product is now **Ayuvo**. Domains were renamed in Aug 2026:

| Service | Current | Legacy alias (kept as redirect) |
|---|---|---|
| API (Render) | `ayuvo-api-vwyr.onrender.com` | `medistore-api-vwyr.onrender.com` |
| Web (Vercel) | `ayuvo-health.vercel.app` | `medistore-health.vercel.app` |
| Share readers | `ayuvo-share-*.vercel.app` | `medistore-share-*.vercel.app` |
| Flutter web | `front-ayuvo-app.vercel.app` | `front-medistore-app.vercel.app` |

Infrastructure that still carries `medistore` and is CORRECT (contains data):

| Identifier | Why it stays |
|---|---|
| `medistore-files` | S3 bucket (contains data) |
| `medistore-57598` | Firebase project ID |

Renamed in code: package `ayuvo`, app id `com.ayuvo.health`, all UI strings,
emails, PDFs, ICS UIDs, storage keys, channel IDs, CORS regex, sitemap.

**Firebase note:** `google-services.json` deliberately contains BOTH
`com.ayuvo.health` and the legacy `com.medistore.medistore` client entries so
FCM works under the existing project. Creating a dedicated `ayuvo-health`
Firebase project (and swapping in its google-services.json +
serviceAccountKey.json) is a pending manual step.

## Quick Start

### Prerequisites
1. PostgreSQL installed locally (via Homebrew: `brew install postgresql@18`)
2. Node.js installed (for frontend)

### Run Full Stack

```bash
# Terminal 1: Frontend
cd front && npm run dev

# Terminal 2: Backend (new terminal)
cd server && pip install -r requirements.txt && python -m uvicorn main:app --reload --port 3001
```

### Database Setup

```bash
# Start PostgreSQL (if not running)
brew services start postgresql@18

# Create the database and user (one-time setup)
psql postgres -c "CREATE USER healthtracker WITH PASSWORD 'password';"
psql postgres -c "CREATE DATABASE healthtracker OWNER healthtracker;"
```

## Environment (.env)

Required in `server/.env`:
```
DATABASE_URL=postgresql://healthtracker:password@localhost:5432/healthtracker
JWT_SECRET=your_jwt_secret_min_32_chars_long_key_here
OPENROUTER_API_KEY=your_openrouter_api_key
N8N_WEBHOOK_URL=http://localhost:5678/webhook
```

## User ID Format

User IDs are generated in format `#hosXXX` where:
- `hos` = hospital prefix (constant)
- `XXX` = sequential enrollment number (001, 002, 003, ...)

## Backend (FastAPI)

### API Endpoints

| Prefix | Endpoints |
|--------|----------|
| `/api/auth` | POST register, POST login, GET me |
| `/api/users` | GET me, PUT me |
| `/api/documents` | POST, GET, GET/{id}, DELETE/{id}, POST/{id}/files |
| `/api/reports` | POST, GET, GET/{id}, GET/{id}/file, GET /{id}/lab-analysis, GET /trends |
| `/api/appointments` | POST, GET, PUT/{id}, DELETE/{id}, PATCH/{id}/status, GET /available-slots/{doctor_id} |
| `/api/doctors` | POST /doctors, GET /doctors, GET /doctors/me, POST /availability, GET /availability, PUT /availability/{id}, DELETE /availability/{id} |

| `/api/share` | POST /{report_id}, GET /{token}, DELETE /{token}, POST /qr-code (whole record, returns 6-digit `pin`), GET /qr-code/{token}?pin= (401 without/with wrong PIN), GET /{token}/lab-analysis |

### Appointment Workflow

1. **Patient views available doctors**: `GET /api/doctors/doctors`
2. **Patient checks doctor availability**: `GET /api/doctors/availability/{doctor_id}`
3. **Patient gets available time slots**: `GET /api/appointments/available-slots/{doctor_id}?date=YYYY-MM-DD`
4. **Patient books appointment**: `POST /api/appointments`
5. **System validates slot is still available** (prevents double-booking)

### Doctor Availability Setup

1. Doctor registers/logs in
2. Doctor creates profile: `POST /api/doctors/doctors`
3. Doctor sets availability: `POST /api/doctors/availability`

## Data Storage

- **Files stored in database** as BLOBs (BYTEA)
- `medical_files.content` - document attachments
- `medical_reports.file_content` - report files

## Caretaker links

A caretaker is an ordinary user account — there is no role column and no
separate signup. A patient issues a short-lived code from
`/settings/caretakers`; whoever redeems it becomes their caretaker.

The link grants exactly two things: medicine reminders for that patient, and
read/write on that patient's medicines. It grants nothing else — vitals,
documents, reports and AI are unreachable through it.

- Gate: `CARETAKER_ENABLED` (default `false`). While off, `/api/care/*` returns
  404 and cross-account medicine scope is refused outright.
- Authorization lives in one place: `resolve_medicine_scope` in
  `app/core/care.py`. Every medicine endpoint routes through it. Do not compare
  user ids by hand anywhere else.
- `patient_id` is read from the **query string only**, never a request body.
- **User ids contain `#`** (`#hos014`). Always percent-encode them into URLs —
  unencoded, the value is truncated into a URL fragment and the request
  silently scopes to the caller's own records. The frontend must go through
  `scopedUrl` in `front/lib/care.ts`.
- Medicine deletes are soft (`medicines.deleted_at`); every read filters
  `deleted_at IS NULL`.

## Production URLs

| | URL |
|---|---|
| Frontend (Vercel) | https://ayuvo-health.vercel.app |
| API (Render) | https://ayuvo-api-vwyr.onrender.com |

**The API hostname is not derivable from `render.yaml`.** The blueprint declares
`name: ayuvo-api`, but Render appended a random suffix when it created the
service, so the live host is `ayuvo-api-vwyr`. Worse, `*.onrender.com` is a
wildcard: the wrong hostname still resolves in DNS and then hangs until timeout
instead of failing fast, which reads exactly like a suspended service. Do not
conclude the backend is down from a timeout plus a successful DNS lookup —
check the URL first.

If it changes, recover it from Vercel's `NEXT_PUBLIC_API_URL`, or from the
deployed bundle:

```bash
curl -s https://ayuvo-health.vercel.app/dashboard \
  | grep -oE '/_next/static/[^"]+\.js' | sort -u \
  | while read c; do curl -s "https://ayuvo-health.vercel.app$c"; done \
  | grep -oE 'https://[a-z0-9-]+\.onrender\.com' | sort -u
```

## Deploying

Push to `main` — Render and Vercel both auto-deploy from it.

**Adding an env var to `render.yaml` does not create it on the running
service.** Render applies that file's variables when the service is created
from the blueprint, not on subsequent pushes. Add the key by hand in
Render > ayuvo-api > Environment as well, or the code deploys while the
variable stays absent and the app quietly uses its default — which is how
`CARETAKER_ENABLED` read `false` in production for an hour while the blueprint
said `"true"`.

Feature flags are visible at `/health` (`caretaker`, `email`) precisely so this
is one curl to check rather than a guess:

```bash
curl -s https://ayuvo-api-vwyr.onrender.com/health
```

Schema changes need care: startup runs `SQLModel.metadata.create_all()`, which
creates missing *tables* but never adds columns to existing ones. A new column
must go through `scripts/migrate_schema.py`, **run against production before the
code that reads it ships** — otherwise every query touching that column 500s.

```bash
cd server
DATABASE_URL='<prod-url>' python -m scripts.migrate_schema --dry-run
DATABASE_URL='<prod-url>' python -m scripts.migrate_schema
```

## Notes

- Frontend UI may be changed. (This previously read "DO NOT modify frontend
  UI"; the caretaker feature ships its own pages, so the restriction was
  removed rather than left contradicting the codebase.)
- Backend runs on port 3001
- Frontend runs on port 3000
- All medical data linked to User.id (#hosXXX format)
- User IDs are sequential starting from #hos001