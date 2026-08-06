# Backend notes

**Status.** §1 and §2 were approved and are **shipped locally** (not deployed).
§3–§9 remain deferred until the app produces evidence. A third fix — a 500 in
`GET /api/documents` — was found while testing §2 and is described in §0.

`python -m pytest -q` → **147 passed** (130 before, +17 new tests). Commits:

```
ea2687d  Stop the documents list from 500ing on every call        (§0 + §2)
84cebee  Give doctors a route that can actually change a status   (§1)
```

Nothing has been pushed or deployed. Neither change needs a migration.

Each entry: what, why, blast radius, migration, whether `front/` is affected. Items
marked **rejected** are recorded so the decision stays visible rather than being
re-litigated later.

Every proposal below obeys the additive rule: existing routes keep their paths,
request shapes, response shapes, status codes and auth requirements, so the deployed
Next.js app keeps working with zero edits.

---

## 0. `GET /api/documents` returned 500 on every call — **SHIPPED, and not on the original list**

Found while writing the §2 tests, not predicted in phase 1.

`list_documents` called `DocumentResponse.model_validate(doc)` on a
`MedicalDocument` ORM object with no `from_attributes`, so pydantic rejected the
input and the handler raised. Every other handler in the file returns the ORM
object and lets FastAPI's `response_model` convert it, which is why this was the
only one affected. `requirements.txt` pins fastapi, pydantic and sqlmodel
exactly, so production runs this same code path.

Nobody noticed because `front/app/documents/page.tsx` wraps the fetch in a
`try`/`catch` whose failure path renders "No medical records yet" — a dead
feature that looks like an empty one.

Fix: `model_validate(doc, from_attributes=True)`. The declared response model,
the status codes and the auth are all unchanged; the endpoint simply stops
raising.

- **Blast radius:** one endpoint stops 500ing. There is no caller that depends
  on it failing.
- **Migration:** none. **`front/` affected:** its Documents page starts working.
- **Why it was done without being on the approved list:** the approval covered
  §1 and §2, and this is neither. It is in the same file as §2, it is a crash
  rather than a design question, and phase 4 has to build a Documents screen
  against this endpoint. Revert with `git revert ea2687d` if you disagree —
  though that also reverts §2, which is in the same commit.

---

## 1. Doctors cannot change an appointment's status — **SHIPPED**

**Problem.** `PATCH /api/appointments/{appt_id}/status`
(`server/app/api/appointments.py:342-372`) authorises with:

```python
if not appointment or appointment.user_id != current_user.id:
    raise HTTPException(status_code=404, detail="Appointment not found")
```

`Appointment.user_id` is the **patient** who booked. A doctor is never the owner, so
every Accept / Reject / Mark-Completed a doctor attempts returns 404. The one screen
the action exists for — `front/app/doctor/appointments/page.tsx` — cannot work, and
has never worked. (It also posts `{status}` as a JSON body while the route reads a
query parameter, so it 422s before reaching the 404. That half is a client bug and is
fixed for free in Flutter.)

**Why it can't be solved client-side.** The check is server-side ownership. No request
a correct client can send makes a doctor the owner of a patient's appointment.

**Proposal (recommended).** A new route beside the existing one:

```
PATCH /api/appointments/{appt_id}/status/by-doctor?status=CONFIRMED
```

authorised as: caller has `role in {DOCTOR, ADMIN}`, has a `Doctor` profile, and
`appointment.doctor_id == that doctor.id`. Same response model. Same status codes.
Ships with tests for the happy path, a doctor who is not the doctor of record (404),
and a patient calling it (403).

**Rejected alternative.** Widening the existing route to accept the doctor of record.
Smaller diff, but it changes an existing route's auth requirements, which the
protocol forbids — and a route that silently starts accepting a second class of
caller is exactly the kind of change that is hard to review later.

- **Blast radius:** new path only; nothing existing changes.
- **Migration:** none.
- **`front/` affected:** its doctor page was fixed in the same pass to call the new
  route (commit `89dca20`), since it was sending a JSON body to a query parameter as
  well and was doubly broken.
- **Phase 5 impact:** the doctor inbox can ship fully functional.

**Verified against local Postgres**, not just SQLite tests:

| Call | Result |
|---|---|
| `PATCH /status` as doctor, JSON body — what the page used to send | `422` |
| `PATCH /status?status=` as doctor | `404` — the original bug, still there by design |
| `PATCH /status/by-doctor?status=` as the doctor of record | `200` |
| `PATCH /status/by-doctor?status=` as the patient | `403` |
| `PATCH /status?status=` as the patient who booked | `200` — unchanged |

Tests: `server/tests/test_doctor_appointments.py`, 9 cases covering the happy path,
another doctor (404), a patient (403), a DOCTOR role with no profile (404),
unauthenticated (401), and two regression tests pinning the original route's
behaviour in both directions.

---

## 2. `POST /api/documents` silently discards the checkup date — **SHIPPED**

**Problem.** `DocumentCreate` has no `checkup_date` field, so every document is
stamped `utcnow()` at upload. The web form collects a *required* checkup date and
throws it away. A record of a 2019 hospital visit uploaded today reads as today.

**Proposal.** Add `checkup_date: Optional[datetime] = None` to `DocumentCreate`; when
omitted, `utcnow()` exactly as now.

- **Blast radius:** one optional request field. Omitting it reproduces today's
  behaviour byte for byte.
- **Migration:** none — `medical_documents.checkup_date` already exists.
- **`front/` affected:** it already sends the field; before it was ignored, now it is
  honoured — an improvement, not a break. No edit was needed there.
- **The one hazard, guarded:** `front/`'s form state initialises `checkup_date` to
  `""`. An empty string is not a valid datetime, so simply declaring the field would
  have turned a working request into a 422. A `mode="before"` validator maps `""` to
  `None`, and there is a test for exactly that.

Tests: `server/tests/test_documents.py`, 8 cases — the date honoured, a date-only
string accepted, omitted still stamping now, blank treated as omitted, the response
shape unchanged (asserted key-for-key), garbage still a 422, and back-dating sorting
correctly in the list.

---

## 3. `GET /api/reports` ships the full OCR text and full AI report for every report

**Problem.** `ReportResponse` includes `extracted_text` and `ai_report_text`, and the
list endpoint returns every report with both. A user with 30 scanned reports pulls
several MB on every visit to the Reports tab, over mobile data, to render cards that
show only type, date, filename and notes.

**Proposal.** An optional `?include_text=false` on `GET /api/reports`, defaulting to
`true` so today's callers are unchanged. With it, `extracted_text` and
`ai_report_text` come back `null`; the detail screen fetches
`GET /api/reports/{id}` (which already exists and returns the full shape).

- **Blast radius:** one optional query parameter; default reproduces today exactly.
- **Migration:** none.
- **`front/` affected:** no — it never sends the parameter.
- **Evidence needed first:** measure the real payload on a populated account during
  phase 4 and put the number here before proposing it for real.

---

## 4. Report upload is synchronous through OCR and two LLM calls

**Problem.** `POST /api/reports` runs `extract_report_text` (vision OCR), then
`generate_ai_summary` (60 s timeout), then `generate_formal_ai_report` (60 s timeout)
before responding. Worst case is a two-minute request. On a phone that is a held
connection across a screen lock, a network handover, or an OS background kill.

**Proposal (large — evidence first).** Return as soon as the file is stored, with a
new nullable `medical_reports.processing_status` column
(`pending|ready|failed`, NULL treated as `ready` for every existing row), do the AI
work in a background task, and let the client poll `GET /api/reports/{id}`.

- **Blast radius:** a new optional response field and a changed *timing* contract for
  new callers only if gated behind an opt-in (`?defer_ai=true`), which is how it
  should ship. Without the flag, behaviour is unchanged.
- **Migration:** yes — new nullable column, must be added to
  `server/scripts/migrate_schema.py::_ADD_COLUMNS` and **run against production
  before the reading code deploys** (operator step, see §10).
- **`front/` affected:** no, provided the flag defaults off.
- **Client-side first:** a long dio timeout, a real progress screen and a resumable
  retry may be enough. Decide at the end of phase 4 with measurements, not now.

---

## 5. JSON login with a proper `totp_code` field

As the brief itself allows. `POST /api/auth/login/json` taking
`{email, password, totp_code?}` and wrapping the identical logic, returning the same
`TokenResponse` and the same `X-2FA-Required` signal.

- **Blast radius:** new path. The form-encoded `/api/auth/login` stays exactly as it
  is — `front/` and `OAuth2PasswordBearer(tokenUrl=...)` both depend on it.
- **Migration:** none. **`front/` affected:** no.
- **Priority: low.** Smuggling a TOTP code through `client_secret` is ugly, but it
  works and the Flutter client can do it in four lines. This is cosmetic; it should
  not consume phase-7 budget ahead of §1 or §2.
- **Phase 3 evidence:** it did take four lines
  (`features/auth/data/auth_repository.dart::login`), and the 2FA challenge round
  trip is covered by tests against both a fake and the real server. Downgrading
  this from "worth doing" to "only if the phase-7 list is otherwise empty".

---

## 6. Seven-day sessions with no refresh

Tokens last 7 days and there is no refresh path, so every user is signed out weekly.

**Proposal.** A `refresh_tokens` table plus `POST /api/auth/refresh`, with rotation
and revocation on sign-out.

- **Blast radius:** new table, new route; login's response could carry an *additional*
  optional `refresh_token` field without breaking anyone.
- **Migration:** new table — created by `create_all` on startup, so no column
  migration, but the ordering rules still apply.
- **`front/` affected:** no (it would keep ignoring the extra field).
- **Until approved:** handle expiry gracefully — 401 clears storage and routes to
  sign-in with "Your session expired". No silent retry loops; the login route is rate
  limited at 10/min and a retry storm would lock the user out.
- **Phase 3 evidence:** done, and it turned out to be two paths rather than one. A
  401 mid-session ends it once, however many requests were in flight
  (`core/network/api_client.dart`); and at launch the `exp` claim is read locally, so
  a token that ran out while the app was closed sends the user to sign-in with a
  reason instead of to a screen that 401s on load (`core/session/jwt.dart`). Both are
  tested. The remaining cost of no-refresh is exactly one sign-in a week — real, but
  not a blocker.

---

## 7. The server cannot learn a mobile user's timezone

**Problem.** `app/core/doses.py::patient_timezone` infers the zone from the newest
row in `push_subscriptions` — a **browser** Web Push subscription. A patient who only
ever uses the Flutter app has no such row, so the server treats them as UTC. Two
things go wrong: the caretaker's "next dose" card
(`care.py::_client_summary`) reports a UTC wall clock, and any server-driven reminder
fires at the wrong hour.

**Proposal.** A nullable `users.timezone` column, settable through the existing
`PUT /api/users/me` as one more optional field, with `patient_timezone` preferring it
and falling back to the push-subscription lookup exactly as today.

- **Blast radius:** one optional request field, one new column, one changed lookup
  order that is a strict fallback (unset column ⇒ identical behaviour).
- **Migration:** yes — nullable column, `_ADD_COLUMNS`, production first.
- **`front/` affected:** no.
- **Client-side mitigation that mostly works:** a caretaker can already read the
  patient's `taking_times`, which are wall-clock strings needing no timezone at all.
  The Flutter caretaker card can compute the next dose itself and only loses the
  today/tomorrow distinction. Do that first; revisit if server-driven reminders (§8)
  are ever approved.

---

## 8. FCM device registration and reminder fan-out

Only needed if reminders must survive the app being closed/reinstalled, or if
caretaker fan-out must come from the server rather than each caretaker's device.

**Proposal.** New `POST /api/push/devices` (FCM token + platform + timezone) beside
the existing web-push `subscribe`, and teach
`app/core/reminder_scheduler.py` to fan out to both channels behind a new flag
defaulting **off**, recording which was used in the existing
`ReminderDelivery.channel` column. Surface the flag in `/health`. Never put a
medicine name or any health detail in a push payload — note that
`app/core/notify.py` currently puts medicine names and caretaker names in web-push
bodies, which is a separate question worth asking before copying the pattern.

- **Blast radius:** new table, new route, flagged scheduler branch.
- **Migration:** new table only.
- **`front/` affected:** no.
- **Client-side first:** `flutter_local_notifications` with timezone scheduling covers
  reminders for the patient's own device, and a caretaker's device can schedule from
  the patient's medicine list it is already allowed to read. Phase 6 will show whether
  that is enough.

---

## 9. Pagination on the list endpoints

`GET /api/reports`, `/api/documents`, `/api/medicines`, `/api/appointments` and
`/api/share` return everything, unbounded. `/api/timeline` and `/api/search` paginate
in Python **after** loading every row.

**Proposal.** Optional `?limit=&cursor=` with defaults that return exactly what they
return today; push `/api/timeline`'s slice into SQL.

- **Blast radius:** optional parameters only.
- **Migration:** none, though `/api/timeline` would benefit from indexes.
- **`front/` affected:** no.
- **Priority: low** until an account is large enough to notice.

---

## Rejected — recorded so the decision stays visible

| Idea | Why not |
|---|---|
| Make timestamps timezone-aware (`Z` suffix) across the API | Changes the meaning of existing response fields. `front/` parses them as local today; adding `Z` would shift every rendered time in the deployed web app by the UTC offset. The Flutter client parses them as UTC itself (`FEATURE_MAP.md §1.1`). |
| Reject a `POST /api/vitals` body with every metric null | Turns a 200 into a 400 on an existing route — a status-code change. Validate in the client form instead. |
| Validate `report_type` against `MedicalReportType` on upload | Same: the web currently posts `"OTHER"`, which is not in the enum, and would start 422-ing. The Flutter client sends real enum values; the server stays permissive. |
| Filter expired links out of `GET /api/share` | Changes an existing response's contents. One line in the client instead: badge or hide rows whose `expires_at` has passed. |
| Let `PUT /api/medicines/{id}` clear a field | `None` means "unchanged" and changing that reinterprets an existing request field. A separate route just to clear `notes` is not worth it — the app hides the affordance. |
| `POST /api/documents` should soft-delete like medicines | `MedicalDocument.deleted_at` exists and `/api/search` filters on it, but `DELETE` hard-deletes. Real inconsistency, no mobile need. Leave it. |
| Fix the caretaker chokepoint / compare ids anywhere else | Never. `resolve_medicine_scope` stays the single authorisation point. |

---

## Gaps noticed, not yet proposals

- **No change-password endpoint.** A signed-in user can only change their password by
  going through the forgot-password email. Worth a `POST /api/auth/change-password`
  (current + new) eventually; not needed to ship the app.
- **No account deletion or data export.** `RUN.md` documents
  `GET /api/export` "Download all data (ZIP)" — **that route does not exist**; no
  router in `server/main.py` provides it. Documentation drift, not a backend change.
- **`ADD_DOCTOR_GUIDE.txt` requires two manual `psql` updates** (`users.role`,
  `doctors.verified`) to onboard a doctor. Correct as a policy — role elevation and
  verification should not be self-service — but it means the doctor role cannot be
  demonstrated from the app alone.

---

## Operator steps — for you to run, not me

Nothing here is needed yet; recorded now so the list is complete when something does
ship.

1. **Schema migration, production, before the reading code deploys:**
   ```bash
   cd server
   DATABASE_URL='<prod-url>' python -m scripts.migrate_schema --dry-run
   DATABASE_URL='<prod-url>' python -m scripts.migrate_schema
   ```
   Only §4 and §7 above would need this. No migration is pending today.
2. **Environment variables:** any new flag must be added **by hand** in
   Render → medistore-api → Environment. Adding it to `render.yaml` does not create
   it on the running service — that is how `CARETAKER_ENABLED` read `false` in
   production for an hour while the blueprint said `"true"`.
3. **Verify:** `curl -s https://medistore-api-vwyr.onrender.com/health` — every new
   flag must be surfaced there, the way `caretaker` and `email` already are.
4. **Deploy** is yours to trigger. New behaviour lands behind a flag defaulting off,
   so shipping the code and enabling it stay separate acts.
