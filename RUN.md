# HealthTracker - Project Setup Guide
## Prerequisites
Before starting, ensure you have:
- PostgreSQL installed locally (via Homebrew: `brew install postgresql@18`)
- Python 3.10+ installed
- Node.js 18+ installed
---
## Step 1: Start PostgreSQL Database
1. Start PostgreSQL if it's not already running:
```bash
brew services start postgresql@18
```
2. Create the database and user (one-time setup):
```bash
psql postgres -c "CREATE USER healthtracker WITH PASSWORD 'password';"
psql postgres -c "CREATE DATABASE healthtracker OWNER healthtracker;"
```
3. Verify it's running:
```bash
pg_isready
```
You should see `/tmp:5432 - accepting connections`.
---
## Step 2: Backend Setup
1. Navigate to the server directory:
```bash
cd server
```
2. Create a `.env` file with your settings:
```bash
cat > .env << 'EOF'
DATABASE_URL=postgresql://healthtracker:password@localhost:5432/healthtracker
JWT_SECRET=your_jwt_secret_min_32_chars_very_secure_key_here_2024
OPENROUTER_API_KEY=your_openrouter_api_key_here
N8N_WEBHOOK_URL=http://localhost:5678/webhook
EOF
```
3. Install Python dependencies:
```bash
pip install -r requirements.txt
```
4. Start the backend server:
```bash
python -m uvicorn main:app --reload --port 3001
```
5. You should see:
```
Uvicorn running on http://127.0.0.1:3001
```
---
## Step 3: Frontend Setup
1. Open a new terminal
2. Navigate to the frontend directory:
```bash
cd front
```
3. Install Node.js dependencies:
```bash
npm install
```
4. Start the frontend:
```bash
npm run dev
```
5. You should see:
```
VITE ready at http://localhost:3000
```
---
## Step 4: Testing the API
### Register a User (Patient)
```bash
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com", "password": "password123"}'
```
Response:
```json
{"id": "#hos001", "name": "John Doe", "email": "john@example.com", "role": "PATIENT", "token": "eyJ..."}
```
### Register as Doctor
```bash
# First register as a user
curl -X POST http://localhost:3001/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name": "Dr. Smith", "email": "doctor@example.com", "password": "password123"}'
# Then create doctor profile (need to update role to DOCTOR in database manually)
# And set availability
curl -X POST http://localhost:3001/api/doctors/doctors \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"nmid": "MD12345", "degree": "MD", "specialty": "General"}'
```
### Book an Appointment
1. List available doctors:
```bash
curl http://localhost:3001/api/doctors/doctors \
  -H "Authorization: Bearer YOUR_TOKEN"
```
2. Check doctor availability:
```bash
curl "http://localhost:3001/api/doctors/availability/DOCTOR_ID" \
  -H "Authorization: Bearer YOUR_TOKEN"
```
3. Get available slots for a specific date:
```bash
curl "http://localhost:3001/api/appointments/available-slots/DOCTOR_ID?date=2026-05-15T00:00:00" \
  -H "Authorization: Bearer YOUR_TOKEN"
```
4. Book the appointment:
```bash
curl -X POST http://localhost:3001/api/appointments \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{
    "title": "Annual Checkup",
    "doctor_id": "DOCTOR_ID",
    "appointment_date": "2026-05-15T10:00:00",
    "duration_minutes": 30,
    "reason": "Regular health checkup"
  }'
```
---
## Common Issues & Solutions
### "Port 5432 already in use"
```bash
# Check what's using the port
lsof -i :5432
# If it's another PostgreSQL instance, stop it:
brew services stop postgresql@18
# Or find and kill the process:
kill $(lsof -ti :5432)
```
### "Module not found"
```bash
pip install -r requirements.txt
```
### "Connection refused" on API calls
- Backend must be running before making API calls
- Check backend terminal for errors
- Ensure port 3001 is not blocked by firewall
### Database connection error
- Verify PostgreSQL is running: `pg_isready`
- Check `.env` file exists in server directory
- Verify DATABASE_URL is correct
---
## API Endpoints Summary
| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/auth/register` | POST | Register new user |
| `/api/auth/login` | POST | Login user |
| `/api/auth/me` | GET | Get current user |
| `/api/users/me` | GET/PUT | Get/Update profile |
| `/api/documents` | GET/POST | List/Create documents |
| `/api/documents/{id}` | GET/DELETE | Get/Delete document |
| `/api/documents/{id}/files` | POST/GET | Upload/List files |
| `/api/reports` | GET/POST | List/Create reports |
| `/api/reports/{id}` | GET | Get report |
| `/api/reports/{id}/file` | GET | Download report file |
| `/api/reports/ai-summary` | GET | AI summary of reports |
| `/api/appointments` | GET/POST | List/Book appointments |
| `/api/appointments/{id}` | PUT/DELETE | Update/Delete appointment |
| `/api/appointments/{id}/status` | PATCH | Update status |
| `/api/appointments/available-slots/{doctor_id}` | GET | Get available slots |
| `/api/doctors/doctors` | GET | List doctors |
| `/api/doctors/availability` | GET/POST | Get/Set availability |
| `/api/doctors/availability/{doctor_id}` | GET | Get doctor availability |

| `/api/share` | GET | List active share links |
| `/api/share/{report_id}` | POST | Create share link |
| `/api/share/{token}` | GET/DELETE | Access/Revoke share |
---
## Key Features
### Report Deletion
When deleting a report, all associated share links are automatically removed.
### AI Summary
Upload medical report images (JPG, PNG) or PDFs to extract text and generate AI-powered health summaries with key findings and recommendations.
### Share Links
Share links expire after 24 hours. List all active links and revoke them anytime from /share page.
---
## Stopping the Project
1. Stop frontend: `Ctrl+C` in frontend terminal
2. Stop backend: `Ctrl+C` in backend terminal
3. Stop database: `brew services stop postgresql@18`