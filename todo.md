# MediStore — Production & Adoption Roadmap

Academic phase is done (examiner passed). Goal now: **ship a real mobile app** and **make it
safe + interoperable enough for hospitals to adopt.** This holds real patient data, so security,
privacy, and standards compliance move from "nice to have" to "mandatory."

Note: the old "free tools only" constraint is relaxed where production demands it (hosting,
backups, storage, monitoring). Prefer free/cheap tiers, but don't block launch on avoiding a
small paid service where it protects patient data.

## Legend
- [ ] Not started   - [~] In progress   - [x] Done

---

## Already built (foundation)
- [x] Core records: reports, medicines, vitals, documents, appointments, timeline, family
- [x] AI assist, sharing (links/QR), emergency ID, OCR, PDF, nearby-care map
- [x] PWA (installable + offline shell), dark mode, multilingual (EN/ने), responsive navbar

---

## Phase 0 — Production hardening (DO FIRST; blocks everything real)
Cannot hold real patient data until these are done.
Status & runbook: see [PHASE0.md](PHASE0.md).
- [x] **Move files off Postgres** — env-driven storage layer (`local`/`s3`), blobs now
      stored by key; backfill script `scripts/migrate_blobs_to_storage.py`.
- [~] **Cloud Postgres + automated backups** — DB **live on Supabase** (session pooler,
      schema migrated, end-to-end verified); remaining: enable daily backups + test
      restore (free tier has none — Pro or `pg_dump` cron; ops, see PHASE0.md).
- [~] **HTTPS + real domain + secrets management** — secrets done (no secrets in code, prod
      fail-fast in `config.py`); remaining: TLS proxy + domain for the API host (ops).
- [x] **Encryption at rest & in transit** — Supabase encrypts DB + Storage at rest (AES-256);
      DB uses `sslmode=require`, Storage over HTTPS.
- [x] **Access & audit log** — append-only `audit_logs` (who/when/IP) on read/share/
      emergency-ID/auth events (`app/core/audit.py`).
- [x] **2FA / TOTP** + **rate limiting** on auth (`slowapi`) — TOTP enroll/verify/disable
      + login enforcement; login 10/min, register 5/min.
- [x] **Automated tests + CI** — pytest (auth, 2FA, report CRUD, storage, audit) +
      GitHub Actions (`.github/workflows/ci.yml`).
- [x] **Error monitoring + uptime** — Sentry wired (`SENTRY_DSN`, no PII) + `GET /health`
      DB-readiness probe; remaining: set DSN + external uptime check (ops).

## Phase 1 — Mobile app
- [ ] **Wrap frontend with Capacitor** (recommended) — reuse existing Next.js UI, target iOS + Android.
      _Alt: Expo/React Native rewrite (native feel, more work) or PWA-only (no store listing)._
- [~] **Push notifications** — meds due: DONE via Web Push/VAPID (`app/api/push.py` +
      `reminder_scheduler.py`) with an app-wide alarm (sound/vibrate/Taken/Snooze + adherence log)
      that fires even when the app is closed. Remaining: appointment reminders, new-results push,
      and native FCM/APNs once wrapped with Capacitor. Needs VAPID_* env vars set (see render.yaml).
- [ ] **Biometric app lock** — Face ID / fingerprint gate on open (health data is sensitive).
- [ ] **App Store + Play Store listing** — accounts, privacy labels, screenshots, review submission.
- [ ] **Deep links** — share/emergency-ID links open the app when installed.

## Phase 2 — Hospital interoperability & multi-tenant
The gap between "my app" and "a hospital will use it."
- [ ] **HL7 FHIR support** — expose/consume FHIR resources (Patient, Observation, MedicationRequest,
      DiagnosticReport). This is THE standard hospitals integrate against. Biggest adoption lever.
- [ ] **Multi-tenant / organizations** — each hospital = a tenant; data isolation; org admin role.
- [ ] **Verified doctor & institution onboarding** — real credential/license verification workflow.
- [ ] **Role-based access control** — granular roles (patient / doctor / hospital admin / staff)
      with least-privilege permissions, beyond today's patient/doctor split.
- [ ] **Consent management** — explicit, revocable, logged patient consent for each org/doctor.
- [ ] **Import from hospital systems** — CSV/FHIR bulk import of existing patient records.

## Phase 3 — Compliance & legal (parallel with Phase 2; get help)
- [ ] **Data-protection compliance** — meet applicable law (Nepal Individual Privacy Act 2018 /
      GDPR-style principles): lawful basis, data minimization, breach process, retention policy.
- [ ] **Legal docs** — Terms of Service, Privacy Policy, Data Processing Agreement for hospitals.
- [ ] **Security review / pen-test** — before any hospital pilot.
- [ ] **BAA-equivalent agreements** with any vendor touching health data (storage, email, monitoring).

## Phase 4 — Pilot & go-to-market
- [ ] **Design partner** — land ONE hospital/clinic for a pilot; scope a narrow first integration.
- [ ] **Admin dashboard & analytics** — for the hospital: patients, usage, engagement.
- [ ] **Onboarding + support docs** — for hospital staff and patients.
- [ ] **Feedback loop + iteration** — instrument, gather, refine from the pilot.

---

## Decisions / notes
- **Mobile:** default to **Capacitor** (wrap existing Next.js) unless we choose native rewrite.
- **DB:** env-driven `DATABASE_URL` → local dev, cloud (Neon/RDS) for production. Not SQLite.
- **Files:** currently blobs in Postgres — MUST move to object storage before cloud DB (Phase 0).
- **Interoperability:** HL7 FHIR is the single most important thing for hospital adoption. Prioritize
  it over new consumer features from here on.
- **Biggest risk:** handling real patient data without compliance/security in place. Phase 0 + Phase 3
  gate any real-world use — do not onboard a hospital before them.
