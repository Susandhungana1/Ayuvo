# Backend notes

**Status.** §1 and §2 were approved and are **shipped locally** (not deployed).
§3–§15 remain deferred until the app produces evidence. A third fix — a 500 in
`GET /api/documents` — was found while testing §2 and is described in §0.

**As of the end of phase 6 the list is complete**: §1–§15 are everything six phases
of building against this API turned up. Phase 7 is where you approve some subset of
it. Five are proven against a running server rather than read off the source —
§11 (two patients given the same slot), §15 (search returns deleted medicines),
§10 (a booking is confirmed on the doctor's behalf, so `PENDING` is unreachable),
§7 (a caretaker is shown the wrong medicine at the wrong time on the wrong day),
and the answer written into §8 (local reminders cover the patient and cannot reach
a caretaker).

**Opening phase 7 closed the two entries that said "measure this first."** §3 asked
for the payload it saves and now has it — 86% of the list, but only ≈172 KB at 30
reports, so it is **downgraded**. §7 asked for its symptom to be observed and now has
it, and the symptom is not the one this file claimed: it is not a shifted clock, it
is the wrong dose. §7 is **upgraded to high** and is the only item here that makes a
shipped screen state something false. Neither of those edits touched `server/`.

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
list endpoint returns every report with both, to render cards that show only type,
date, filename, notes and `result_summary`.

**Proposal.** An optional `?include_text=false` on `GET /api/reports`, defaulting to
`true` so today's callers are unchanged. With it, `extracted_text` and
`ai_report_text` come back `null`; the detail screen fetches
`GET /api/reports/{id}` (which already exists and returns the full shape).

- **Blast radius:** one optional query parameter; default reproduces today exactly.
- **Migration:** none.
- **`front/` affected:** no — it never sends the parameter.

**Measured, and it downgrades this item.** Phase 4 asked for a number before
proposing this for real. Taken from the three real reports in the local database
(`select length(extracted_text), length(ai_report_text) from medical_reports`):

| Per report | Bytes |
|---|---|
| `ai_report_text` | 4 661 – 5 752 (avg 5 234) |
| `extracted_text` | 36 – 701 (avg 479) |
| everything the card actually renders | ≈ 900 incl. `result_summary` ≈ 730 |

So the suppressible text is **≈ 5.7 KB per report, 86% of the list payload**, and
`ai_report_text` alone is 92% of that. But the absolute number is an order of
magnitude below what this entry originally claimed: 30 reports is **≈ 172 KB**, not
"several MB". That is one second on a bad connection, not a broken screen.
`thumbnail` and `file_content` are *not* in `ReportResponse`, which is what keeps it
small — the OCR text is the only bulk on the wire.

**And it is not a server-only change.** `report_detail_screen.dart:32` deliberately
reads the report out of the list rather than refetching, precisely because the list
already carried every field. Suppressing the text means that screen needs a
`GET /api/reports/{id}` fetch with its own loading and error states. Two-sided work
for 150 KB. **Priority: low** — recorded as correct but not worth phase-7 budget
unless an account gets far bigger than any on this machine.

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

## 7. The server cannot learn a mobile user's timezone — **proved live, and worse than written**

**Problem.** `app/core/doses.py::patient_timezone` infers the zone from the newest
row in `push_subscriptions` — a **browser** Web Push subscription. A patient who only
ever uses the Flutter app has no such row, so the server treats them as UTC. In Nepal
that is 5h45m of error, and for this app it is not an edge case: a mobile-only
patient can never have a push-subscription row, so UTC is what they always get.

**The symptom this entry originally claimed was wrong.** It said the caretaker card
"reports a UTC wall clock". It does not: `next_dose_local` is
`slot.strftime("%H:%M")` where the slot is built from a `taking_times` string
(`doses.py:114`), so the *string* is verbatim and correct whatever the zone. The
timezone only decides **which** slot is next — which makes it worse, not better,
because a plausible-looking time is harder to distrust than an obviously shifted one.
What the UTC fallback actually corrupts is the choice of slot, the medicine named
beside it, and `next_dose_is_today`.

**Proved against the running local backend, 2026-08-08.** Two throwaway accounts,
two medicines, a real care link, read back through `GET /api/care/links?role=caretaker`
(the rows were deleted afterwards):

```
UTC now  2026-08-08 14:03
NPT now  2026-08-08 19:48   ← the patient's actual wall clock

caretaker's card:   Amlodipine at 17:00, next_dose_is_today = true, timezone "UTC"
the patient's own phone, from the same taking_times:
                    Metformin at 07:00, tomorrow
```

Wrong medicine, wrong time, wrong day — and wrong in the dangerous direction. The
card points a caretaker at a dose that passed nearly three hours ago and labels it
as still to come. A caretaker who acts on that prompts a second Amlodipine.

**No client can fix this.** The mitigation this entry used to recommend does not
work. A caretaker's phone knows its own zone and the patient's `taking_times`, but
it does not know and cannot learn **the patient's zone** — nothing in any response
carries it except `next_dose_timezone`, which is the wrong value being explained.
Without that, "is 07:00 still ahead for them?" is unanswerable. The mobile app
therefore renders the server's answer verbatim, which is the documented rule
(`README.md`) and is now known to render a wrong answer
(`KNOWN_ISSUES.md` P7-1).

**Proposal.** A nullable `users.timezone` column, settable through the existing
`PUT /api/users/me` as one more optional field, with `patient_timezone` preferring it
and falling back to the push-subscription lookup exactly as today.

- **Blast radius:** one optional request field, one new column, one changed lookup
  order that is a strict fallback (unset column ⇒ identical behaviour).
- **Migration:** yes — nullable column, `_ADD_COLUMNS`, production first.
- **`front/` affected:** no.
- **Priority: high**, raised from medium. Not for the missing column itself but for
  what it makes a live screen say. It is also cheap: one nullable column, one
  optional field on a route that already accepts a partial body, and a lookup order
  that is a strict fallback. Every existing web user keeps the push-subscription
  answer they have today.
- **The one design question in it.** A timezone is weak location data. `PUT
  /api/users/me` is the right place (the user owns the row), it must stay optional
  and unset-by-default, and it must not go anywhere near a log or Sentry. The app
  would send `flutter_timezone`'s identifier once at sign-in — the same string it
  already uses locally to schedule reminders.

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

**Phase 6 answer: it is enough for the patient and not for anyone else.** Built and
shipped in `core/notifications/`: the next seven days of doses are scheduled in the
device's named timezone whenever the app is opened, rebuilt from scratch on every
sync so an edited dose time cannot leave a stale alarm, capped at 120 so Android's
per-app alarm ceiling is never approached, and re-registered after a reboot by
`ScheduledNotificationBootReceiver`. No backend change was needed for any of it.
Three things it cannot do, all of which are this proposal:

1. **Survive a reinstall or a new phone.** The alarms are device state.
2. **Survive eight days of the app not being opened.** The window only rolls forward
   when something opens it.
3. **Reach a caretaker at all.** This is the sharp one. `CareLink.notify` exists, the
   app exposes it as a bell on each client card, and `reminder_scheduler.py` honours
   it — over Web Push, which an Android caretaker does not have. So a caretaker
   using the mobile app receives nothing, and the toggle they can see changes a
   column with no observable effect (`KNOWN_ISSUES.md` P6-3).

The caretaker's own device *could* schedule from the patient's medicine list it is
allowed to read, and I did not do it: it would mean holding another person's dose
times on the caretaker's phone, which is exactly the disk copy
`offline_cache.dart` refuses to make for the same data. Server-side fan-out is the
right place for it.

On the payload question raised above — the local notification does name the medicine
("Time for Amlodipine · 5 mg"), matching what `_payload` already sends over Web Push.
That is defensible for something that never leaves the device and is a separate
decision for something that crosses a network. Do not copy it into FCM without
asking.

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

**Phase 6 raises this from "low" to "the timeline specifically".** `/api/timeline`
is now a screen somebody scrolls, and it already takes `limit`/`offset` — so the
client pages at 40 and the wire stays small. What does not stay small is the work:
`timeline.py` runs four unbounded `SELECT`s, concatenates them in Python, sorts the
list, and *then* slices. Pressing "Show older" re-reads the entire account to hand
back the next forty rows, so the cost per page grows with the record and the last
page is the most expensive one. Pushing the slice into SQL changes no request and no
response shape; it is the one item in this section with a user-visible symptom
waiting at the end of it.

---

## 10. A booking made with a doctor is confirmed on that doctor's behalf

`create_appointment` (`app/api/appointments.py:206`):

```python
status = AppointmentStatus.CONFIRMED if appt_data.doctor_id else AppointmentStatus.PENDING
```

and `GET /appointments/doctor/my-appointments` selects on
`Appointment.doctor_id == doctor.id`. Together those two lines make `PENDING`
unreachable in any inbox: an appointment that is pending has no doctor to show
it to, and one that has a doctor is already accepted. `AppointmentStatus.PENDING`
exists, the `/status/by-doctor` route that phase 5 shipped can set it, and the
mobile inbox renders a "Waiting on you" section for it — but nothing a patient
does in either client can put an appointment there.

That also means a doctor's diary fills up without their consent. Anyone who can
see a free slot can take it.

**Proposal.** A `DOCTOR_CONFIRMS_BOOKINGS` env flag, default `false`. When true,
`create_appointment` sets `PENDING` regardless of `doctor_id`; the doctor accepts
or rejects through the route that already exists. Surface the flag on `/health`
next to `caretaker`.

- **Blast radius:** none while the flag is off — the response shape, the status
  codes and the default behaviour are byte-identical to today.
- **Migration:** none. `PENDING` is already in the enum and already stored.
- **`front/` affected:** only if the flag is turned on, and then only for the
  better. `front/app/doctor/appointments/page.tsx` already renders a `PENDING`
  badge and already shows Accept and Reject for it, and since the §1 fix it
  calls `/status/by-doctor`, so those buttons work. Today that whole branch is
  unreachable for the same reason the mobile one is. Turning the flag on is what
  makes the web app's existing doctor UI do something.
- **Priority: high.** It is the difference between a booking system and a
  calendar that strangers can write to. It is also the one item on this list
  where the client code on **both** ends is already written and waiting.

---

## 11. Two patients can be given the same slot

`is_slot_available` (`app/api/appointments.py:174`) selects every appointment for
the doctor starting before the requested end, then inspects exactly one of them:

```python
overlapping = db.exec(
    select(Appointment).where(and_(
        Appointment.doctor_id == doctor_id,
        Appointment.appointment_date < appt_end,
    ))
).first()          # <-- no ORDER BY, no loop
```

With one appointment on file the check is correct, which is why it looks right in
a demo. With two it inspects an arbitrary row — in practice the oldest, whose end
is long past — concludes the slot is free, and lets the booking through.

Reproduced against local Postgres on 2026-08-07: a doctor with one past
appointment accepted three bookings into the same 10:00–10:30 slot, all `200`.
The rows were deleted afterwards. Interestingly `available-slots` gets this right
— it runs a correct per-slot check, and 10:00 was absent from the diary the whole
time it was triple-booked. So the two code paths disagree with each other.

**Proposal.** Replace `.first()` with a bounded overlap predicate evaluated in
SQL — `appointment_date < appt_end AND appointment_date + duration > appt_start`,
status in (`PENDING`, `CONFIRMED`) — and take a row lock (or a unique partial
index on `(doctor_id, appointment_date)` for confirmed rows) so two concurrent
requests cannot both pass. Same 400, same message, same shape.

- **Blast radius:** a request that is *currently* wrongly accepted starts
  returning the 400 it should always have returned. No shape or status change.
- **Migration:** only if the index route is chosen.
- **`front/` affected:** no — it already handles this 400.
- **Priority: high.** A client cannot fix this: the check has to be atomic and
  it has to be server-side.

---

## 12. A doctor cannot correct their own registration

`POST /api/doctors` refuses with `400 "Doctor profile already exists"` and there
is no `PUT` or `PATCH`. `nmid`, `degree` and `specialty` are therefore
write-once; a typo needs an operator with `psql`. This is different in kind from
`verified`, which *should* need an operator.

**Proposal.** `PUT /api/doctors/me` accepting the same three fields, doctor-role
only, scoped to the caller's own row. Editing any of them resets
`verified = false` — a practitioner who changes the number they were verified
against has to be verified again, which keeps the policy intact while making the
data correctable.

- **Blast radius:** new route only.
- **Migration:** none.
- **`front/` affected:** no.
- **Priority: medium.** It is one screen away in the mobile app and the screen
  currently has to explain why it cannot help.

---

## 13. `PUT /availability/{id}` skips the overlap check that `POST` runs

`POST /api/availability` refuses a window that overlaps an existing one on the
same day (`app/api/availability.py:161`). `PUT /availability/{id}` applies
whatever it is given (`:262`), so an edit can produce exactly the overlap the
create path exists to prevent. It also cannot change `day_of_week` — moving
Monday's hours to Tuesday means delete and recreate, and the delete is the
destructive half of a pair with no transaction around it.

Neither path checks that the end is after the start: `AvailabilityCreate` has no
validator, and `17:00–09:00` is accepted by both. `slot_generation` then yields
nothing for that window, so the doctor is silently unbookable on that day. The
mobile client validates end-after-start in the form before sending; nothing on
the server does.

**Proposal.** Run the overlap check in the update path, add an end-after-start
validator to both schemas, and let the update body carry `day_of_week`. The
first two make the routes stricter, which is the direction that can break a
caller — but the only bodies they would newly reject are ones that corrupt or
silently disable the diary.

- **Blast radius:** a `200` becomes a `400` for a body that should never have
  been accepted. A real, if narrow, behaviour change — flagged, not hidden.
- **Migration:** none. Existing bad rows are left alone; the check is on writes.
- **`front/` affected:** the web availability editor posts and updates the same
  fields, so a user who *today* saves an overlapping edit would start seeing an
  error. It has an error path for the create case already, since `POST` can
  return this 400 now.
- **Priority: medium.**

---

## 14. `/health` does not say where the web app lives

The mobile app builds every QR code — the emergency ID card and every share link
— against `--dart-define=WEB_BASE_URL`, defaulting to `http://localhost:3000`. A
release built without that define ships QR codes that resolve to nothing, and
nothing detects it until somebody scans one. The server already knows the answer:
`FRONTEND_URL` is in its own environment, and it puts that host into password
reset emails.

**Proposal.** Add `"frontend_url"` to the `GET /health` payload, alongside
`caretaker` and `email`. The client reads it once at startup and prefers it over
the compiled-in default.

- **Blast radius:** one added key on an unauthenticated endpoint. Additive; no
  existing key changes.
- **Is it PII?** No — it is a public hostname the app is already sending users
  to, not user data. It reveals which frontend a deployment serves, which the
  CORS allowlist already reveals.
- **Migration:** none.
- **`front/` affected:** no.
- **Priority: low**, and it is a convenience: making the dart-define mandatory
  at build time solves the same problem with no backend change at all. Recorded
  because the runtime answer is strictly more robust — it survives the frontend
  moving.

---

## 15. `GET /api/search` returns medicines the user has deleted

`app/api/search.py` scans three tables. Two of them respect the soft delete and one
does not:

```python
# documents — filtered
select(MedicalDocument)
    .where(MedicalDocument.user_id == current_user.id)
    .where(MedicalDocument.deleted_at.is_(None))     # line 98

# medicines — not filtered
select(Medicine)
    .where(Medicine.user_id == current_user.id)      # lines 70-74
    .order_by(Medicine.created_at.desc())
```

So a medicine a patient removed keeps appearing in search results forever, while a
visit they removed does not. It is inconsistent with `GET /api/medicines`, which
does filter, and inconsistent with the file's own treatment of documents four
functions down.

**Proved live, not inferred.** `live_backend_test.dart` creates a medicine, deletes
it, confirms it is gone from `GET /api/medicines`, and then finds it in
`GET /api/search`:

```
phase 6, signed in a soft-deleted medicine still turns up in search   ✓
```

**Proposal.** One line — `.where(Medicine.deleted_at.is_(None))` — to match the
documents branch.

- **Blast radius:** one route, and only rows that are already hidden everywhere else.
- **Migration:** none.
- **`front/` affected:** yes, and favourably. `front/app/search/page.tsx` links a
  medicine hit to `/medicines`, where the row is absent — a dead end today.
- **Client-side first:** done, and it is the best the client can do. The app cannot
  tell a deleted medicine from one the list has not loaded, so tapping such a hit
  says the medicine was removed and offers **Restore**, which works because the row
  is soft-deleted and `POST /{id}/restore` will bring it back. That turns a confusing
  dead end into something useful, and it is still the wrong default: a patient who
  deliberately removed a medicine should not have to keep seeing it.
- **Note the asymmetry cuts the other way too.** If search *should* surface retired
  medicines on purpose — "what was I on last year?" — then the fix is to say so, with
  a badge on the row and the same treatment for documents. Either answer is fine.
  What is not fine is the two tables disagreeing by accident.

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
