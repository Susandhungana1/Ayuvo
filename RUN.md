# HealthTracker - Project Setup Guide

## Prerequisites

- **PostgreSQL** 16+ — `brew install postgresql@18`
- **Python** 3.12+
- **Node.js** 20+

---

## Step 1: Start PostgreSQL

```bash
brew services start postgresql@18
```

One-time database setup:

```bash
psql postgres -c "CREATE USER healthtracker WITH PASSWORD 'password';"
psql postgres -c "CREATE DATABASE healthtracker OWNER healthtracker;"
```

Verify:

```bash
pg_isready
# → /tmp:5432 - accepting connections
```

---

## Step 2: Backend Setup (FastAPI)

```bash
cd server
```

Create `.env`:

```bash
cat > .env << 'EOF'
DATABASE_URL=postgresql://healthtracker:password@localhost:5432/healthtracker
JWT_SECRET=your_jwt_secret_min_32_chars_very_secure_key_here_2024
OPENROUTER_API_KEY=sk-or-v1-your_openrouter_api_key_here
GROQ_API_KEY=gsk_your_groq_api_key_here
N8N_WEBHOOK_URL=http://localhost:5678/webhook
EOF
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Start the server:

```bash
python -m uvicorn main:app --reload --port 3001
```

Tables are auto-created on startup.  
API available at **http://127.0.0.1:3001**

---

## Step 3: Frontend Setup (Next.js)

Open a **new terminal**:

```bash
cd front
npm install
npm run dev
```

App available at **http://localhost:3000**

---

## Step 4: Quick Test

### Register a Patient

```bash
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com", "password": "password123"}'
```

Response includes `token` — save it as `YOUR_TOKEN`.

### Register a Doctor

```bash
# Register as a user first
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Dr. Smith", "email": "doctor@example.com", "password": "password123"}'

# Create doctor profile (use the token from above)
curl -X POST http://localhost:3001/api/doctors/doctors \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"nmid": "MD12345", "degree": "MD", "specialty": "General"}'

# Set weekly availability
curl -X POST http://localhost:3001/api/doctors/availability \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"day_of_week": "MONDAY", "start_time": "09:00", "end_time": "17:00", "slot_duration_minutes": 30}'
```

### Book an Appointment

```bash
# List doctors
curl http://localhost:3001/api/doctors/doctors \
  -H "Authorization: Bearer YOUR_TOKEN"

# Get available slots on a date
curl "http://localhost:3001/api/appointments/available-slots/DOCTOR_ID?date=2026-07-10" \
  -H "Authorization: Bearer YOUR_TOKEN"

# Book
curl -X POST http://localhost:3001/api/appointments \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "title": "Annual Checkup",
    "doctor_id": "DOCTOR_ID",
    "appointment_date": "2026-07-10T10:00:00",
    "duration_minutes": 30,
    "reason": "Regular health checkup"
  }'
```

---

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| **Auth** | | |
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login |
| GET | `/api/auth/me` | Current user |
| **Users** | | |
| GET | `/api/users/me` | Get profile |
| PUT | `/api/users/me` | Update profile |
| **Doctors** | | |
| POST | `/api/doctors/doctors` | Create doctor profile |
| GET | `/api/doctors/doctors` | List all doctors |
| GET | `/api/doctors/me` | My doctor profile |
| POST | `/api/doctors/availability` | Set availability |
| GET | `/api/doctors/availability` | My availability |
| GET | `/api/doctors/availability/{id}` | Doctor's availability |
| PUT | `/api/doctors/availability/{id}` | Update availability slot |
| DELETE | `/api/doctors/availability/{id}` | Delete availability |
| **Appointments** | | |
| POST | `/api/appointments` | Book appointment |
| GET | `/api/appointments` | My appointments |
| PUT | `/api/appointments/{id}` | Update appointment |
| DELETE | `/api/appointments/{id}` | Cancel appointment |
| PATCH | `/api/appointments/{id}/status` | Update status |
| GET | `/api/appointments/available-slots/{doctor_id}` | Available slots |
| GET | `/api/appointments/doctor/my-appointments` | Doctor's appointments |
| **Documents** | | |
| POST | `/api/documents` | Create document |
| GET | `/api/documents` | List documents |
| GET | `/api/documents/{id}` | Get document |
| DELETE | `/api/documents/{id}` | Delete document (soft) |
| POST | `/api/documents/{id}/files` | Upload file |
| GET | `/api/documents/{id}/files/{fid}` | Download file |
| **Reports** | | |
| POST | `/api/reports` | Upload report (OCR + AI) |
| GET | `/api/reports` | List reports |
| GET | `/api/reports/{id}` | Get report |
| DELETE | `/api/reports/{id}` | Delete report |
| GET | `/api/reports/{id}/file` | Download report file |
| GET | `/api/reports/{id}/ai-report` | Get AI report |
| GET | `/api/reports/ai-summary` | AI summary of all reports |
| **Medicines** | | |
| GET | `/api/medicines` | List medicines |
| POST | `/api/medicines` | Add medicine |
| PUT | `/api/medicines/{id}` | Update medicine |
| DELETE | `/api/medicines/{id}` | Delete medicine |
| **Vitals** | | |
| GET | `/api/vitals` | List vitals |
| POST | `/api/vitals` | Log vitals |
| DELETE | `/api/vitals/{id}` | Delete vitals entry |
| **Emergency** | | |
| GET | `/api/emergency/profile` | Get emergency profile |
| PUT | `/api/emergency/profile` | Update emergency profile |
| POST | `/api/emergency/contacts` | Add emergency contact |
| DELETE | `/api/emergency/contacts/{id}` | Remove contact |
| GET | `/api/emergency/public/{user_id}` | Public emergency data |
| **Share** | | |
| GET | `/api/share` | Active share links |
| POST | `/api/share/{report_id}` | Create share link |
| GET | `/api/share/{token}` | Access shared report |
| DELETE | `/api/share/{token}` | Revoke share link |
| GET | `/api/share/qr-code` | Generate QR code |
| GET | `/api/share/qr-code/{token}` | Access shared data via QR |
| **Chatbot** | | |
| POST | `/api/chatbot` | AI health assistant (Groq) |
| **Search** | | |
| GET | `/api/search?q=...` | Full-text search |
| **Timeline** | | |
| GET | `/api/timeline` | Health timeline |
| **Export** | | |
| GET | `/api/export` | Download all data (ZIP) |

---

## Troubleshooting

### "Port 5432 already in use"

```bash
lsof -i :5432
brew services stop postgresql@18
```

### "Module not found"

```bash
pip install -r requirements.txt
```

### Database connection error

- Verify PostgreSQL: `pg_isready`
- Check `.env` exists in `server/`
- Confirm `DATABASE_URL` is correct

### "Connection refused"

- Backend must be running on port 3001
- Check backend terminal for errors

---

## Stopping

| Service | Command |
|---------|---------|
| Frontend | `Ctrl+C` |
| Backend | `Ctrl+C` |
| PostgreSQL | `brew services stop postgresql@18` |

---

## Notes

- User IDs are auto-generated as `#hos001`, `#hos002`, etc.
- Medical files are stored in the database as BYTEA (not on disk).
- Share links expire after 24 hours by default.
- OCR is supported for JPG, PNG, and PDF uploads.
- Two AI providers: **OpenRouter** (report summaries) and **Groq** (chatbot).
