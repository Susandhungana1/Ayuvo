# HealthTracker - Personal Digital Health Tracker

FastAPI backend for the HealthTracker web application.

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
| `/api/reports` | POST, GET, GET/{id}, GET/{id}/file, GET /ai-summary |
| `/api/appointments` | POST, GET, PUT/{id}, DELETE/{id}, PATCH/{id}/status, GET /available-slots/{doctor_id} |
| `/api/doctors` | POST /doctors, GET /doctors, GET /doctors/me, POST /availability, GET /availability, PUT /availability/{id}, DELETE /availability/{id} |

| `/api/share` | POST /{report_id}, GET /{token}, DELETE /{token} |

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

## Notes

- DO NOT modify frontend UI
- Backend runs on port 3001
- Frontend runs on port 3000
- All medical data linked to User.id (#hosXXX format)
- User IDs are sequential starting from #hos001