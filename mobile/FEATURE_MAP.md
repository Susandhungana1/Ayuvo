# MediStore — Feature Map (Phase 1 recon)

Every user-facing surface in `front/app/`, the endpoints behind it, and the fields
it renders. Compiled by reading `AGENTS.md`, `RUN.md`, every `server/app/api/*.py`,
`server/app/models/models.py`, `server/app/core/*`, and every `front/app/**/page.tsx`
plus the components they mount.

Phase 1 produced this map with `server/` untouched. Two approved backend fixes and
one crash fix have since shipped locally — see `BACKEND_NOTES.md §0–§2` — and the
seven `front/` bugs in §7 are fixed. `python -m pytest -q` → **147 passed**. Nothing
is deployed.

**Phase 3 (foundation) is built.** Auth is done end to end — register, sign in, the
2FA challenge, forgot/reset, sign out, session restore, and a 401 anywhere ending the
session with a reason. Every other row below is navigable and says which phase builds
it; none of them shows invented data. The screens the auth flow added that the web has
no equivalent for (the 2FA challenge, "paste your reset code") are marked **new** in
§2 and now exist.

---

## 0. How to read this

- **Endpoints** are written as the backend defines them, not as the web app calls
  them. Where the web app calls them wrongly, that is recorded in §7.
- **Fields shown** is what the current UI actually renders, so the Flutter port has a
  parity target rather than a guess.
- **Mobile delta** is where the Flutter screen should deliberately differ, with the
  reason.
- Response shapes come from the Pydantic models in each router. Field names are
  copied verbatim — do not re-derive them.

---

## 1. Global contract facts

| Fact | Detail |
|---|---|
| Base URL | local `http://127.0.0.1:3001`; Android emulator `http://10.0.2.2:3001`; prod `https://medistore-api-vwyr.onrender.com` |
| Auth | `Authorization: Bearer <jwt>`; HS256, `sub` = user id, **7-day expiry, no refresh** |
| Login | `POST /api/auth/login` — **form-encoded** `username`/`password`, TOTP in `client_secret` |
| 2FA signal | 401 + header `X-2FA-Required: true` → prompt for code, resubmit |
| 401 anywhere | session is dead → clear secure storage, route to sign-in with a message |
| User id | `#hosNNN` — contains `#`. Percent-encode into every URL. One chokepoint only. |
| Caretaker scope | medicines **only** (list/create/update/delete/restore/interactions/audit). Never vitals, reports, documents, chat. |
| Feature flag | `GET /health` → `{status, database, email, caretaker}`. `caretaker:false` ⇒ all `/api/care/*` return 404. |
| Files | report files and document attachments are auth-gated binaries. Fetch bytes with the Bearer header, render `Image.memory` / write to a temp file for the PDF viewer. `Image.network` will 401. |
| Rate limits | register 5/min, login 10/min, forgot-password 3/min (per IP); care invite 10/day and redeem 5/hour (per user) |

### 1.1 Timestamp serialisation — a real trap

Most timestamps are stored with `datetime.utcnow()` (naive UTC) and serialised with
`str(dt)` or bare Pydantic ISO, i.e. **no `Z`, no offset**:

```
"2026-08-06 09:14:22.841913"   medicines.created_at, vitals.measured_at/created_at,
                                intake.recorded_at, timeline.date, search.date
"2026-08-07T09:14:22"          share.expires_at
```

Two lookalikes that are **not** naive UTC and must not be shifted:
`appointment_date` (the client sends naive *local* and the server stores it verbatim)
and `report_date` / `checkup_date` (date-only values — format them as plain dates).

`DateTime.parse` in Dart reads those as **local**, which in Asia/Kathmandu is 5h45m
wrong. `front/lib/datetime.ts` now corrects this on the web side (§7.6); Dart needs
its own equivalent. The Flutter client must parse these as UTC
(`DateTime.parse(s.replaceFirst(' ', 'T') + 'Z')` — do it once, in a shared decoder)
and render local. This is a deliberate divergence from `front/`, and it is the correct
behaviour.

The **only** fields that already carry `Z` are `care_links.created_at`,
`care_invites.expires_at` and `medicine_audit.created_at` — they go through
`app/core/care.py::utc_iso`.

`medicines.start_date` / `end_date` are plain `"YYYY-MM-DD"` **strings** compared
lexically server-side. Keep them strings; do not round-trip through `DateTime`.

### 1.2 Sending datetimes — will 500 the server if you get it wrong

`AppointmentCreate.appointment_must_be_future` does `v <= datetime.now()`. If the
client sends a **timezone-aware** ISO string (`...Z` or `+05:45`), Pydantic produces
an aware datetime and the comparison raises `TypeError` → **500**, not a validation
error. Send a naive local datetime (`2026-08-12T10:30:00`), exactly as the web's
`datetime-local` input does.

Same discipline for `VitalSignCreate.measured_at` (naive UTC, or omit and let the
server stamp it) and `report_date` (naive, date-only is fine).

---

## 2. Screen inventory

Status is the plan; **Built** marks what exists in `mobile/lib` today.

| Web route | Flutter destination | Status |
|---|---|---|
| `/` (signed in) | **Home** tab | **built** (phase 4) |
| `/dashboard` | folded into Home + Settings | **built** (phase 4, restructured — no link grid; the bottom bar does that job) |
| `/medicines` | **Medicines** tab | **built** (phase 4) |
| `/vitals` | **Vitals** tab | **built** (phase 4) |
| `/reports` | **Reports** tab | **built** (phase 4) |
| `/documents` | Documents (from Account) | **built** (phase 4, a child route so the bottom bar stays) |
| `/appointments` | Appointments (from Account) | **built** (phase 5) |
| `/timeline` | Timeline | **built** (phase 6) |
| `/search` | Search (global) | **built** (phase 6, deep-links to the thing itself) |
| `/emergency` | Emergency ID (from Account) | **built** (phase 5) |
| `/share` | Sharing (from Account) | **built** (phase 5) |
| `/nearby` | Nearby care (`flutter_map`) | **built** (phase 6) |
| ChatBot widget (global) | AI assistant screen | **built** (phase 6, a screen not a bubble) |
| `/settings/caretakers` | Settings → Caretakers | **built** (phase 6, flag-gated) |
| `/care/[patientId]` | Caretaker → patient medicines | **built** (phase 6, flag-gated) |
| `/doctor/appointments` | Doctor inbox | **built** (phase 5, on `/status/by-doctor` — see §7.1) |
| `/doctor/availability` | Availability editor | **built** (phase 5, rewritten) |
| `/doctor` registration | Doctor profile (from Account) | **built** (phase 5, new — the web has no such page) |
| — | **Settings → Language, theme, reminders** | **built** (phase 6, new — no web equivalent) |
| — | **Settings → Profile** | new (`/api/users/me` has no web page) — phase 8 |
| — | **Settings → Two-factor** | new (`/api/auth/2fa/*` has no web page) — phase 8 |
| — | Sign-in **2FA challenge** | **built** (phase 3; web login can't complete a 2FA account) |
| `PeopleICareFor` on `/dashboard` | Home → People I care for | **built** (phase 6, flag-gated, invisible without links) |
| `/share/[token]` | — | **stays web** (public) |
| `/share/qr-code/[token]` | — | **stays web** (public) |
| `/emergency/id/[userId]` | — | **stays web** (public) |
| `/auth/reset-password` | app gets a "paste your code" screen; page stays | both |
| `/about` `/contact` `/blog` `/blog/[id]` | — | **stays web** (marketing) |

Bottom navigation, as built: **Home · Medicines · Vitals · Reports · Account**.
Everything else lives behind Account, in three groups rather than one list of
eleven — *your record* (appointments, documents, timeline, search), *help*
(assistant, nearby, sharing, emergency ID), and *your account* (caretakers, when
the flag is on; settings). Doctors get a three-item shell: **Appointments ·
Availability · Account**, and their Account holds the doctor profile and
settings only.

---

## 3. Auth

### 3.1 Register — `front/app/auth/register/page.tsx`
- `POST /api/auth/register` — JSON `{name, email, password}`, password ≥ 8, email
  regex-validated server-side and lowercased.
- → `{id, name, email, role, token}`. 400 `"Email already registered"`.
- Web stores `token` + the whole response as `user` in localStorage. Flutter: JWT in
  `flutter_secure_storage`; the profile can live in a Riverpod provider hydrated from
  `GET /api/auth/me`.
- Fields shown: name, email, password, confirm password (client-side match check).

### 3.2 Sign in — `front/app/auth/login/page.tsx`
- `POST /api/auth/login` — `application/x-www-form-urlencoded`:
  `username=<email>&password=<pw>` (+ `client_secret=<6-digit>` when 2FA is on).
- → `{id, name, email, role, token}`.
- 401 + `X-2FA-Required: true` ⇒ show the code screen and resubmit the same
  credentials with `client_secret`. 401 without the header ⇒ bad credentials.
- **The web app does not implement this.** It never sends `client_secret`, so a user
  who enables 2FA cannot sign in on the web at all. The Flutter app is the first
  client to complete this flow.
- Web supports `?next=` return-to. Flutter equivalent: go_router redirect remembers
  the attempted location.

### 3.3 Forgot / reset — `front/app/auth/forgot-password`, `/auth/reset-password`
- `POST /api/auth/forgot-password` `{email}` → always
  `{"message": "If an account exists for that email, a reset link has been sent."}`
  (deliberately non-enumerable; also returns 200 when the mail send failed).
- `POST /api/auth/reset-password` `{token, new_password}` → `{message}`; 400 for
  invalid/expired/used. TTL 30 minutes, single use, newest token invalidates older.
- The email contains both a link (`{frontend_url}/auth/reset-password?token=…`) **and**
  the bare token, so the app only needs a paste-the-code screen. The web page stays —
  it is the link target. The web page already accepts a pasted whole-URL and extracts
  the token; copy that leniency.

### 3.4 Two-factor — no web UI exists
- `GET /api/auth/2fa/status` → `{enabled}`
- `POST /api/auth/2fa/setup` → `{secret, otpauth_url, qr_code_data_uri}` — 400 if
  already enabled. Secret is stored but **not active** until verified.
- `POST /api/auth/2fa/verify` `{code}` → `{enabled: true}`
- `POST /api/auth/2fa/disable` `{code}` → `{enabled: false}` — requires a valid code.
- Fields to show: the QR (a `data:image/png;base64` URI — decode and `Image.memory`),
  the base32 secret as copyable text, a 6-digit code field.

### 3.5 Session end
- `GET /api/auth/me` → `{id, name, email, role}` — used to validate a stored token at
  launch. Not called by the web app.
- No refresh token. On 401: wipe storage, `go('/sign-in')`, show
  "Your session expired — please sign in again."

---

## 4. Patient screens

### 4.1 Home — `front/app/page.tsx` (signed-in branch)
| Endpoint | Use |
|---|---|
| `GET /api/medicines` | today's medicines + next-dose countdown |
| `GET /api/vitals?limit=20` | latest reading tiles + trend chart |

Fields shown:
- **Latest vitals tiles** from `vitals[0]`: BP `systolic/diastolic`, `heart_rate`,
  `blood_sugar` (rounded), `temperature` (1dp, °C), `oxygen_saturation` (%),
  `weight` (1dp, kg). Each tile carries a locally-computed status chip — the
  thresholds live in the frontend, not the API (see §4.3).
- **Trend chart** over the last 20 readings, series switchable
  bp / hr / sugar / temp / spo2 / weight.
- **Next dose**: nearest future `taking_times` entry across active medicines →
  `{name, time, remaining}` recomputed every 30 s.
- **Today's medicines**: active by `start_date <= today <= end_date`; each dose chip
  greyed + struck through once its clock time has passed.
- Quick links to Appointments / Reports / Medicines.

Mobile delta: this is the real dashboard; `/dashboard`'s link grid is a web nav
crutch and should not be ported as a screen. Its one live element,
`PeopleICareFor`, moves to §6.1.

### 4.2 Medicines — `front/app/medicines/page.tsx` + `components/medicine-manager.tsx`
| Endpoint | Notes |
|---|---|
| `GET /api/medicines[?patient_id=]` | `{medicines:[…]}`, newest first, `deleted_at IS NULL` |
| `POST /api/medicines[?patient_id=]` | body `{name, dosage, frequency, start_date, end_date?, taking_times?, notes?}` |
| `PUT /api/medicines/{id}[?patient_id=]` | all fields optional; **`null` means "leave unchanged"** — you cannot clear a field |
| `DELETE /api/medicines/{id}[?patient_id=]` | soft delete → `{message}` |
| `POST /api/medicines/{id}/restore[?patient_id=]` | 400 if not deleted |
| `GET /api/medicines/interactions[?patient_id=]` | `{interactions:[{drug_a,drug_b,severity,description}], checked_count}` — active meds only |
| `GET /api/medicines/audit[?patient_id=&limit=]` | `{entries:[{id:int, actor_id, actor_name, medicine_id?, medicine_name?, action, created_at(Z), by_caretaker}]}` |
| `POST /api/medicines/{id}/intake` | **self only, no `patient_id`** — `{scheduled_time:"08:00", status:"taken"\|"snoozed"\|"skipped"}` |
| `GET /api/medicines/intake/log?limit=` | self only, ≤500, newest first — **unused by the web app** |

`MedicineResponse`: `{id, name, dosage, frequency, start_date, end_date?,
taking_times?, notes?, created_at?}`.

`taking_times` is a **JSON array encoded as a string**: `"[\"08:00\",\"20:00\"]"`.
Decode on read, encode on write, `null` when empty. Malformed values must degrade to
`[]`, never throw (`app/core/doses.py::parse_times` does exactly this server-side).

Fields shown: name, dosage, frequency, taking-time chips, start date, end date,
notes, Remove. Drug-interaction banner above the list, severity-coloured
(severe/moderate/minor) with the "educational check only" disclaimer — keep that
disclaimer verbatim.

The web page also has an "Enable & test reminders" button
(`GET /api/push/vapid-public-key` → `POST /api/push/subscribe` → `POST /api/push/test`).
That is browser Web Push; the Flutter app replaces it with
`flutter_local_notifications` scheduled from `taking_times` (phase 6) and must **not**
call `/api/push/subscribe` — it expects a browser subscription shape.

Missing from the web UI, present in the API, worth building: **edit** (`PUT`),
**soft-deleted list + restore** for the patient's own list, and the **adherence log**
(`/intake/log`).

`components/medicine-alarm.tsx` is mounted app-wide and is the behavioural spec for
reminders: 10-minute grace window, per-day de-dupe key `medId-time-date`, Taken /
Snooze-10m actions, `POST …/intake` on each action, a re-alarm timer after snooze.

### 4.3 Vitals — `front/app/vitals/page.tsx`
| Endpoint | Notes |
|---|---|
| `GET /api/vitals?limit=&offset=` | `limit ≤ 200`, default 50; ordered `measured_at` desc |
| `POST /api/vitals` | all seven metrics optional, `notes?`, `measured_at?` |
| `DELETE /api/vitals/{id}` | |

`VitalSignResponse`: `{id, blood_pressure_systolic?, blood_pressure_diastolic?,
heart_rate?, weight?, blood_sugar?, temperature?, oxygen_saturation?, notes?,
measured_at, created_at}`.

**Reference ranges are client-side only** — port them exactly (`front/app/vitals/page.tsx:38-135`):

| Metric | Bands |
|---|---|
| BP | `<90/60` Low · `≤120/80` Normal · `≤129/80` Elevated · `≤139/89` Stage 1 · `≤179/119` Stage 2 · else Crisis |
| HR | `<60` Low · `≤100` Normal · `≤120` Mild High · else High |
| Blood sugar (mg/dL) | `<70` Low · `≤100` Normal · `≤125` Prediabetic · `≤180` High · else Very High |
| Temp (°C) | `<35` Hypothermia · `<36` Low · `≤37.2` Normal · `≤38` Mild Fever · `≤39` Fever · else High Fever |
| SpO₂ | `≥95` Normal · `≥90` Mild Low · `≥80` Low · else Critical |
| Weight | no band — "Recorded" |

Note the web's own inconsistency: the summary strip says "Sugar Normal 3.9-5.6"
(mmol/L) while the analyser and the form label use mg/dL. Use mg/dL throughout.

Charts: one line chart, metric selector, BP as two series. Read the `dataviz` skill
before implementing these in `fl_chart` (phase 1.5 / 4).

Voice dictation on the notes field (`Web Speech API` → `speech_to_text`).

Server-side gap to guard client-side: `POST /api/vitals` accepts a body with every
field null and stores an empty row. Require at least one metric in the form.

### 4.4 Reports — `front/app/reports/page.tsx`
| Endpoint | Notes |
|---|---|
| `GET /api/reports` | full list, newest first — **returns `extracted_text` and `ai_report_text` for every report** |
| `POST /api/reports` | multipart: `file`, `report_type`, `notes?`, `report_date?`, `hospital?`, `doctor_name?`; 10 MB cap; **synchronous OCR + 2 LLM calls** |
| `GET /api/reports/trends` | cross-report lab series |
| `GET /api/reports/{id}` | same shape as a list item — unused by the web |
| `GET /api/reports/{id}/file` | binary, `Content-Type` from `file_content_type`, `Content-Disposition: inline` |
| `GET /api/reports/{id}/lab-analysis` | parsed lab findings |
| `POST /api/reports/{id}/explain` | plain-language explanation (Groq); 400 if no OCR text, 503 if no key |
| `GET /api/reports/{id}/ai-report` | `{report}` — unused by the web (list already carries `ai_report_text`) |
| `GET /api/reports/ai-summary` | `{summary}` over the newest 5 reports — **no page calls it**; only a dead Next proxy references it |
| `DELETE /api/reports/{id}` | also deletes the report's share links and the stored blob |

`ReportResponse`: `{id, report_type, report_date?, file_name, notes?, result_summary?,
extracted_text?, ai_report_text?, document_id?, doctor_name?, hospital?}`.
`doctor_name`/`hospital` fall back to the linked `MedicalDocument` when unset.

`report_type` enum: `BLOOD_TEST · URINE_TEST · STOOL_TEST · XRAY · MRI · CT_SCAN ·
ECG · ULTRASOUND · LAB_REPORT · OTHERS`. The web's upload dropdown offers only eight
and sends the literal `"OTHER"` (not `OTHERS`) as its default — which the server
accepts because `report_type` arrives as a `Form(str)` and is never validated against
the enum. Send real enum values from Flutter.

`GET /trends` → `{series:[{name, unit, reference_range, points:[{date, value, status}],
first_value, last_value, change, percent_change?, direction:"up"|"down"|"flat",
latest_status:"HIGH"|"LOW"|"NORMAL"}]}`. Only tests with ≥2 data points appear;
abnormal series sort first.

`GET /{id}/lab-analysis` → `{overall:"NORMAL"|"ABNORMAL"|"NO_DATA", total,
abnormal_count, findings:[{name, value, unit, status, reference_range, category}]}`.
Categories: Blood Count, Metabolic, Lipids, Kidney, Electrolytes, Liver, Thyroid,
Vitamins. 22 analytes, listed in `server/app/core/lab_analysis.py`.

Fields shown per card: type, report date, file name, notes, and six actions —
View · Lab Values · Explain Simply · Digital Report · Download PDF · Delete.

- **View** fetches the blob with the auth header and shows it in a modal (PDF in an
  iframe, images inline). Flutter: authenticated byte fetch → `Image.memory` or a
  temp file for the PDF viewer.
- **Digital Report** (`components/DigitizedReport.tsx`) is pure client rendering of
  `ai_report_text`: it splits the AI's dashed-rule sections, pulls pipe-tables out,
  flags rows containing "high/low/above/below/elevated/decreased" and prints an
  official-looking document with patient name, id, email, blood type. Port as a
  read-only screen + `printing` share sheet.
- **Download PDF** (`lib/reportPdf.ts`, jsPDF) enriches with `lab-analysis` findings
  and falls back gracefully if that call fails. Flutter: `pdf` + `printing`.

Mobile delta: upload is the slowest call in the product (OCR then two 60 s-timeout
LLM calls). Give it a real progress screen, a long dio timeout, and never a bare
spinner. See BACKEND_NOTES for the async-processing proposal.

### 4.5 Documents — `front/app/documents/page.tsx`
| Endpoint | Notes |
|---|---|
| `GET /api/documents` | `{documents:[…]}`, `checkup_date` desc |
| `POST /api/documents` | `{hospital, location?, doctor_name?, department?, description?}` |
| `GET /api/documents/{id}` | single |
| `DELETE /api/documents/{id}` | **hard** delete, cascades attachments and their blobs |
| `POST /api/documents/{id}/files` | multipart `file`, 10 MB cap |
| `GET /api/documents/{id}/files` | `{files:[{id, name, file_type}]}` |
| `GET /api/documents/{id}/files/{file_id}?inline=` | binary; content-type guessed from the filename extension |

`DocumentResponse`: `{id, hospital, location?, doctor_name?, department?,
description?, checkup_date}`.

`checkup_date` is accepted on create (added in `BACKEND_NOTES.md §2`). Omitted, or
sent as `""`, the row is stamped `utcnow()` as before. Legacy rows therefore carry
their upload date, not the visit date — render them with a plain-date formatter and
don't imply more precision than exists.

`GET /api/documents` used to 500 on every call (`BACKEND_NOTES.md §0`); it works now,
and phase 4 is the first client to exercise it. Create, list, attach-list and the
cascading delete all round-trip against local Postgres in `test/live_backend_test.dart`,
including `checkup_date` sent as a plain `YYYY-MM-DD` and read back unshifted.

`file_type` is always written as `"OTHER"` by the upload path even though the
`FileType` enum has four values.

Fields shown: hospital (title), doctor, department, location, date, description,
expandable attachment list with View, Delete.

### 4.6 Appointments — `front/app/appointments/page.tsx`
| Endpoint | Notes |
|---|---|
| `GET /api/appointments` | own appointments, `appointment_date` asc |
| `GET /api/doctors/doctors` | **verified doctors only** → `{doctors:[{id, nmid, degree, specialty?, verified, user_id, name}]}` |
| `GET /api/doctors/availability/{doctor_id}` | that doctor's weekly windows (`doctor_id` is `Doctor.id`, a UUID) |
| `GET /api/appointments/available-slots/{doctor_id}?date=<iso>&duration_minutes=30` | `{doctor_id, doctor_name, available_slots:[{start_time, end_time}]}` |
| `POST /api/appointments` | see §1.2 for the datetime trap |
| `PUT /api/appointments/{id}` | full replace, same body as create — **no web UI** |
| `DELETE /api/appointments/{id}` | hard delete |

`AppointmentResponse`: `{id, title, description?, doctor_id?, doctor_name?, hospital?,
appointment_date, duration_minutes, status, reason?, reminder_sent}`.
Status enum `PENDING · CONFIRMED · CANCELLED · COMPLETED`. Booking with a
`doctor_id` yields `CONFIRMED`; a free-text doctor yields `PENDING`.

Booking rules enforced server-side: the doctor must exist, the slot must sit fully
inside an `is_available` window for that weekday, and must not overlap a
`PENDING`/`CONFIRMED` appointment → else 400 "The requested time slot is not
available."

**The web never calls `available-slots` or `availability/{doctor_id}`.** It offers a
free `datetime-local` field and surfaces the 400 after the fact. The Flutter flow
should be the one the API was built for: pick doctor → pick date → fetch slots →
tap a slot. That is a pure client-side improvement, no backend change needed.

Fields shown: title, status pill, doctor, hospital, date/time, reason, Add to
Calendar (`lib/ics.ts` → an `.ics` download; Flutter: `add_2_calendar` or an ICS
share), Cancel. A success modal echoes title, doctor, datetime and the appointment id.

**Built (phase 5)** — `features/appointments/`. Coming up / Earlier, split on the
phone's clock. The booking sheet has the two paths the API implies: a listed
doctor (pick doctor → pick a date → tap a slot from `available-slots`) and
"Somewhere else" (free text plus a date-time picker), and it does not pretend
the second one books anybody. Past slots are filtered client-side because the
server's future check runs in the server's zone, 5h45m behind Kathmandu.
`add_2_calendar` was not used: `calendar_invite.dart` writes the `.ics` itself
and hands it to the share sheet, in floating time so it matches what
`appointment_date` actually means — see `KNOWN_ISSUES.md` P5-5.

**Correction to the note above:** "must not overlap a `PENDING`/`CONFIRMED`
appointment" is what the code intends and not what it does. `is_slot_available`
inspects one arbitrary earlier row, so a doctor with two appointments can be
double-booked. Proven locally; `BACKEND_NOTES.md` §11.

---

## 5. Doctor screens

### 5.1 Doctor inbox — `front/app/doctor/appointments/page.tsx`
- `GET /api/appointments/doctor/my-appointments` — requires `role` in
  `{DOCTOR, ADMIN}` **and** an existing `Doctor` profile, else 403/404.
- `PATCH /api/appointments/{id}/status` — **`status` is a query parameter**
  (`?status=CONFIRMED`), because `AppointmentStatus` is a bare enum in the signature,
  not a Pydantic body model.
- Fields shown: title, status pill, date, duration, reason; Accept / Reject on
  `PENDING`, Mark Completed on `CONFIRMED`.
- **Use `PATCH /api/appointments/{id}/status/by-doctor?status=`** — the plain
  `/status` route authorises the patient and 404s for a doctor. See §7.1.

**Built (phase 5)** — `features/doctors/presentation/doctor_inbox_screen.dart`,
on `/status/by-doctor`, verified against a local doctor account (the plain
`/status` returns 404, `/status/by-doctor` returns 200).

**But "Waiting on you" can never fill.** A booking that carries a `doctor_id` is
created `CONFIRMED`, and `my-appointments` only returns bookings that carry one —
so `PENDING` is unreachable, and Accept/Reject with it. The same is true of the
web page's `PENDING` branch. `KNOWN_ISSUES.md` P5-1, `BACKEND_NOTES.md` §10.

### 5.2 Availability — `front/app/doctor/availability/page.tsx`
- `GET /api/doctors/availability` — my own windows (role-gated).
- `POST /api/doctors/availability` — `{day_of_week, start_time, end_time,
  slot_duration_minutes=30, is_available=true}`; 400 on overlap within a weekday.
- `PUT /api/doctors/availability/{avail_id}` — partial.
- `DELETE /api/doctors/availability/{avail_id}`.
- `AvailabilityResponse`: `{id, day_of_week, start_time, end_time,
  slot_duration_minutes, is_available}`. Times serialise as `"09:00:00"`.
- Fields shown: seven day cards, each with its window and Add/Edit/Remove; a modal
  with start and end time pickers.
- The web page called the wrong endpoint until §7.2; build against
  `GET /api/doctors/availability`.
- `slot_duration_minutes` is never exposed by the web editor even though it drives
  slot generation. Expose it in Flutter.

**Built (phase 5)** — `availability_screen.dart`. Seven day cards; each window
shows its hours, its slot length and a pause switch on `is_available` (paused
reads "Paused — nobody can book this", because an invisible boolean is how a
doctor loses a week). `slot_duration_minutes` is exposed, as planned. Moving a
window to another weekday deletes and recreates, because `PUT` cannot change
`day_of_week` — and `PUT` skips the overlap check `POST` runs, so an edit can
make a diary the create path would have refused. `BACKEND_NOTES.md` §13.

### 5.3 Doctor profile
- `POST /api/doctors/doctors` `{nmid, degree, specialty?}` and
  `GET /api/doctors/doctors/me` exist and have **no web UI at all** —
  `ADD_DOCTOR_GUIDE.txt` documents creating a doctor with `curl` plus two manual
  `psql` updates (`users.role='DOCTOR'`, `doctors.verified=true`).
- Flutter should at least render `GET /doctors/me` and offer `POST` when it 404s, so
  a doctor can self-serve step 4. Steps 2 and 5 stay operator actions — role
  elevation and verification must not be self-service.

**Built (phase 5)** — `doctor_profile_screen.dart`, exactly that: renders the
registration when it exists, offers the form when `GET /doctors/me` 404s, and
says plainly that role elevation and verification are somebody else's to do
rather than showing a button that cannot work. Unverified registrations say so;
`GET /doctors/doctors` hides them from patients, which was confirmed live.
Once registered the three fields cannot be corrected — there is no `PUT`.
`BACKEND_NOTES.md` §12.

---

## 6. Caretaker (flag-gated on `/health.caretaker`)

### 6.1 People I care for — `front/components/people-i-care-for.tsx` (on `/dashboard`)
- `GET /api/care/links?role=caretaker` → `{links:[CareLinkResponse]}`
- `POST /api/care/invites/redeem` `{code}` → the new link
- `PATCH /api/care/links/{link_id}` `{notify}` — mute/unmute, caretaker side only

`CareLinkResponse`: `{id, user_id, name, created_at(Z), notify, medicine_count?,
next_dose_name?, next_dose_local?, next_dose_is_today?, next_dose_timezone?}`.

`next_dose_local` is the **patient's wall clock** (`"08:00"`). Render it verbatim.
Passing it through a `DateTime` would re-express it in the caretaker's zone and show
a time neither party acts on. Append "(their time)" only when
`next_dose_timezone != <device zone>` — the web does exactly this.

Renders nothing but a quiet "+ Caring for someone? Enter their code" link when the
user has no links. Preserve that: the app must not grow a caretaker section for
people who aren't caretakers.

**Built (phase 6)** — `care/presentation/people_i_care_for.dart`, on Home. Three
levels of quiet, in order: the flag is off ⇒ the widget renders `SizedBox.shrink()`
and **no request is made**; the flag is on and there are no links ⇒ one text button;
there are links ⇒ the section. A failure renders nothing at all rather than an error
card, because this is a bonus on somebody else's dashboard. `nextDoseLabel` renders
`next_dose_local` verbatim and appends "(their time)" only when the zones differ,
comparing conservatively — `DateTime.timeZoneName` is an abbreviation and the server
sends an IANA id, so the comparison errs towards showing the note. A redundant
"(their time)" is harmless; a missing one is a wrong time.

### 6.2 Patient medicines — `front/app/care/[patientId]/page.tsx`
- `GET /api/care/links?role=caretaker`, matched on `user_id`, to confirm access and
  get the patient's display name.
- Then the medicines endpoints of §4.2 with `?patient_id=<encoded>`.
- A persistent amber banner names whose list this is — deliberately not the app's
  primary colour, so a caretaker can never mistake it for their own medicines. Port
  that idea (a distinct scope banner, `AppBar` tint, and the patient's name in the
  title).
- 403 mid-session = the link was revoked → leave the screen with a message.
- **Never cache another person's medicines to disk.** `medicine-manager.tsx` skips its
  offline cache whenever `patientId` is set, so their data does not outlive the link.
  Carry that rule into the Hive/Drift cache.
- No vitals/reports/documents/chat is rendered **or fetched** here.

**Built (phase 6)** — `care_medicines_screen.dart`, which is deliberately thin: it
resolves the link, then hands off to the same `MedicinesScreen` a patient uses, with
`patientId` set. One list implementation, one set of behaviours, no second copy to
drift. What it adds is the scope: a caution-coloured app bar and a banner that does
not scroll away, both naming the patient. Access is checked twice on purpose — this
screen matches the id against the caller's own links so it can name whose list it is
and refuse to open when the link is gone, and `resolve_medicine_scope` is the one
that actually decides. Its 403 arrives mid-session through
`MedicinesScreen.onScopeLost`, which leaves the screen with a message. Nothing on it
fetches anything but medicines, and `offline_cache.dart` refuses to write a
patient-scoped entry to disk at all.

### 6.3 My caretakers — `front/app/settings/caretakers/page.tsx`
- `POST /api/care/invites` → `{code:"XXXX-XXXX", expires_at(Z)}` — **shown exactly
  once**, only the hash is stored. 15-minute TTL, max 5 caretakers, 10 codes/day.
- `GET /api/care/links?role=patient`
- `DELETE /api/care/links/{link_id}` — either party may revoke
- `GET /api/medicines/audit` — filtered to `by_caretaker == true`
- `POST /api/medicines/{id}/restore` — offered beside a caretaker's `delete` entry

Behaviour worth porting: the issued code survives navigation (web keeps it in
`sessionStorage` with the caretaker count at issue time, and drops it once a new link
appears, i.e. once it has been redeemed); a live countdown; an explicit "this can't be
shown again" warning. In Flutter, keep it in memory in a Riverpod provider — **not** in
secure storage, and not on disk.

Error taxonomy already worked out in `front/lib/care.ts` and worth mirroring
one-for-one: `SessionExpired` (401), `CareAccessRevoked` (403),
`CareFeatureOff` (404 on a `/api/care/` path), generic. "Not available on your
account" is the wrong message for an unreachable API.

**Built (phase 6)** — `caretakers_screen.dart`. The code is held in
`issuedInviteProvider`, in memory: the server keeps only a SHA-256 hash, so it exists
there or nowhere. Not secure storage — a 15-minute code does not belong in the
keystore beside a bearer token — and not on disk. It survives leaving the screen,
counts down to the second in tabular figures, and drops itself the moment it expires
*or* a new caretaker appears, because a code that has been redeemed must not still be
on screen being read aloud. The ticker only runs while a code is showing.

The taxonomy is mirrored in `care_repository.dart` as `CareFailure`, with the 401
left to `ApiClient` (which ends the session, so no screen has to). §7's own tests
cover all four: `care_test.dart` asserts 403 → revoked, 404 → featureOff, 400 →
the server's own words, 500 → an ordinary `ApiException`.

The Account tile is hidden entirely when `/health` says the feature is off, but
`/more/caretakers` still resolves — reached directly it explains that the server
needs `CARETAKER_ENABLED=true` rather than showing an empty list.

---

## 7. Bugs found in the current web app — all fixed

Recorded here as the reasoning behind the Flutter behaviour, and because the same
mistakes are easy to repeat. All seven were fixed in `front/` (commit `89dca20`) and
the two that needed backend support in `ea2687d` / `84cebee`. Plus one more that only
surfaced under test: **`GET /api/documents` returned 500 on every call** — see
`BACKEND_NOTES.md §0`.

### 7.1 Doctors cannot change an appointment's status — **fixed**
`PATCH /api/appointments/{id}/status` (`server/app/api/appointments.py:342-372`)
authorises with `appointment.user_id != current_user.id → 404`. `user_id` is the
**patient** who booked it. A doctor is never the owner, so Accept / Reject / Mark
Completed always 404s for the only role the UI offers them to. The web compounds this
by sending `{status}` as a JSON body when the server reads a query parameter — a 422
before the 404 is even reached.

Nothing on the client can fix the ownership check, so this needed the additive
backend route in `BACKEND_NOTES.md §1`. Both halves are now fixed: the server has
`PATCH /{id}/status/by-doctor`, and the page calls it with the status in the query
string. **Flutter can build the doctor inbox fully functional in phase 5.**

### 7.2 The availability editor asked the wrong server for the wrong thing — **fixed**
`front/app/doctor/availability/page.tsx` called
`GET /api/doctors/availability/${user.id}` — passing the **user** id (`#hos014`) where
a `Doctor.id` UUID is expected, unencoded, so the `#` truncated the path anyway
(verified: that request 404s). It now calls `GET /api/doctors/availability`, which
resolves the doctor from the token. Save and delete now surface their errors too — an
overlapping window was rejected by the server and silently dropped by the page.
**Write the Flutter screen against `GET /api/doctors/availability`.**

### 7.3 Document attachments were opened without the auth header — **fixed**
`front/app/documents/page.tsx` put the API URL straight into `<img src>` /
`<iframe src>`, which sends no `Authorization` header → 401 on every preview. It now
fetches the bytes with the header and passes a blob URL, revoked on close.
**In Flutter: fetch bytes through the authenticated client — the same rule as §1.**

### 7.4 `checkup_date` was collected and discarded — **fixed**
The field is now declared on `DocumentCreate` (`BACKEND_NOTES.md §2`), with `""`
treated as an omission so the existing form cannot start 422ing. `front/` needed no
change; it was already sending the value. **Flutter can offer a real checkup date.**

### 7.5 Share links listed expired ones as live — **fixed**
`GET /api/share` returns every row the user owns, expired included; the page printed
"Expires: <past date>" beside a live Revoke button. Expired links are now badged and
dimmed, and the button reads "Remove". **Do the same in Flutter — the API will not
filter them for you.**

### 7.6 Naive-UTC timestamps rendered as local — **fixed**
See §1.1. `front/lib/datetime.ts` now pins them to UTC, with `formatPlainDate` for
date-only values that would otherwise shift a day west of Greenwich. Deliberately
**not** applied to `appointment_date` (naive *local*, client-sent, so `new Date` is
already right) nor to the caretaker timestamps (already carry a real `Z`).
**Port that same three-way distinction into the Dart decoder.**

### 7.7 `PUT /api/medicines/{id}` cannot clear a field — **nothing to fix**
`None` means "unchanged", so an end date or note cannot be removed once set. `front/`
has no medicine edit form at all, so there was no affordance to disable. **Flutter
must not grow one** — offer edit, but not clearing, until the API supports it.

---

## 8. Endpoint coverage matrix

`✓` = a Flutter screen owns it · `web` = stays in Next.js · `—` = intentionally unused

| Endpoint | Owner |
|---|---|
| `POST /api/auth/register` | ✓ Register |
| `POST /api/auth/login` | ✓ Sign-in (+ 2FA challenge) |
| `GET /api/auth/me` | ✓ launch token check |
| `POST /api/auth/forgot-password` · `reset-password` | ✓ Forgot / paste-code |
| `GET|POST /api/auth/2fa/{status,setup,verify,disable}` | ✓ Settings → Two-factor (new) |
| `GET|PUT /api/users/me` | ✓ Settings → Profile (new) |
| `GET|POST /api/documents`, `GET|DELETE /{id}`, `POST|GET /{id}/files`, `GET /{id}/files/{fid}` | ✓ Documents |
| `POST|GET /api/reports`, `GET /{id}`, `DELETE /{id}`, `/{id}/file`, `/{id}/ai-report`, `/{id}/lab-analysis`, `POST /{id}/explain`, `/trends` | ✓ Reports |
| `GET /api/reports/ai-summary` | ✓ Home "AI health summary" card (new use of an existing endpoint) |
| `POST|GET /api/appointments`, `PUT|DELETE /{id}`, `/available-slots/{doctor_id}` | ✓ Appointments |
| `PATCH /api/appointments/{id}/status` | ✓ Appointments — the *patient's* route (cancel) |
| `PATCH /api/appointments/{id}/status/by-doctor` | ✓ Doctor inbox (§7.1) |
| `GET /api/appointments/doctor/my-appointments` | ✓ Doctor inbox |
| `POST|GET /api/doctors/doctors`, `GET /doctors/me` | ✓ Doctor profile (new) |
| `POST|GET /api/doctors/availability`, `GET /availability/{doctor_id}`, `PUT|DELETE /availability/{id}` | ✓ Availability editor + booking |
| `GET|POST /api/medicines`, `PUT|DELETE /{id}`, `POST /{id}/restore`, `/interactions`, `/audit` | ✓ Medicines (+ caretaker scope) |
| `POST /api/medicines/{id}/intake`, `GET /intake/log` | ✓ Reminders + adherence (new UI) |
| `GET|POST /api/vitals`, `DELETE /{id}` | ✓ Vitals |
| `GET|PUT /api/emergency/profile`, `POST /contacts`, `DELETE /contacts/{id}` | ✓ Emergency ID |
| `GET /api/emergency/public/{user_id}` | web (QR target) |
| `GET /api/share`, `POST /{report_id}`, `POST /qr-code`, `DELETE /{token}` | ✓ Share links |
| `GET /api/share/{token}`, `/qr-code/{token}`, `/{token}/ai-report`, `/{token}/lab-analysis`, `/{token}/explain` | web (public recipients) |
| `POST /api/care/invites`, `/invites/redeem`, `GET /links`, `PATCH|DELETE /links/{id}` | ✓ Caretakers · People I care for — **built, flag-gated, §6** |
| `GET /api/timeline` | ✓ Timeline — **built, paged at 40, §9.1** |
| `GET /api/search` | ✓ Search — **built, §9.2**; returns deleted medicines, `BACKEND_NOTES.md` §15 |
| `POST /api/chatbot` | ✓ Health assistant — **built, §9.6** |
| `GET /api/push/vapid-public-key`, `POST /subscribe`, `/test`, `/unsubscribe` | — browser-only; **replaced by `flutter_local_notifications`**, which cannot reach a caretaker (`BACKEND_NOTES.md` §8) |
| `POST /api/push/run-tick` | — operator cron |
| `GET /health` | ✓ startup flag check |

---

## 9. Remaining screens

### 9.1 Timeline — `GET /api/timeline?limit=&offset=` (`limit ≤ 200`)
`{events:[{type, id, title, description?, date}], total}` with
`type ∈ report | medicine | appointment | vital`. Titles arrive pre-formatted
(`"Report: bloods.pdf"`, `"Medicine: Aspirin"`, `"Appointment: Checkup"`,
`"Vitals Check"`) and vital descriptions are a pre-joined
`"BP: 120/80, HR: 72, Weight: 70kg"` string. The web groups by local date and draws a
rail with a per-type icon and colour. Note the server loads **all** rows and paginates
in Python — keep the page size modest.

**Built (phase 6)** — `features/timeline/`, paged at 40 with "Show older". Two
decisions worth naming. The titles arrive pre-formatted, so `TimelineEvent.headline`
strips the server's `"Report: "` prefix: the badge already says the type, and a row
that says it twice reads as a mistake. And the rail is drawn as a positioned line
*behind* the card rather than as a stretched Row child — a `Row` with
`CrossAxisAlignment.stretch` inside a scroll view has no height to stretch to, and
`IntrinsicHeight` would measure every card twice for a decoration. The four kinds
take the four validated chart series colours, never the reserved status ones: a
report is not "good" or "critical". A failed "Show older" leaves the rows already on
screen alone and reports separately — they are still true.

### 9.2 Search — `GET /api/search?q=` (min length 1)
`{query, results:[{type, id, title, snippet?, date?}], total}`;
`type ∈ report | medicine | document`. Case-insensitive substring match over report
type/notes/summary/OCR text/filename, medicine name/dosage/frequency/notes, and
document hospital/doctor/department/description/location. Snippets are truncated to
200 chars server-side. No pagination, no ranking — results are grouped by kind in the
order the server scans them. Deep-link each result to its detail screen (the web can
only manage `/reports?highlight=` and dumps medicine/document hits on the list page).

**Built (phase 6)** — `features/search/`, debounced at 350 ms with a generation
token so a slow answer to "asp" cannot land on top of the answer to "aspirin". The
previous results stay on screen at half opacity while the next query runs, because a
list that blanks on every keystroke is unreadable. Every kind deep-links to the thing
itself: a report opens `ReportDetailScreen`, a visit opens the Documents list with
that card already expanded (`DocumentsScreen.highlightId`, added for this), and a
medicine opens its edit sheet.

**Two traps found here.** The query goes through `ScopedUrl` — not for scoping, but
because a search for `#hos` interpolated raw truncates at the `#` and silently
searches for nothing. And `GET /api/search` does **not** filter soft-deleted
medicines the way it filters documents, so a medicine hit may not be in the list at
all; tapping one says it was removed and offers Restore. `BACKEND_NOTES.md` §15.

### 9.3 Emergency ID — `front/app/emergency/page.tsx`
`GET|PUT /api/emergency/profile`, `POST /api/emergency/contacts`,
`DELETE /api/emergency/contacts/{id}`.
`{blood_type?, allergies?, medical_conditions?, emergency_contacts:[{id, name,
relationship, phone, email?}]}`. Blood type is a fixed list
(A±, B±, AB±, O±). `PUT` treats `null` as "unchanged", so send `""` to clear a field.

Renders a printable ID card (blood type, allergies, conditions, contacts) and a QR of
`{web origin}/emergency/id/{percent-encoded user id}` — that page stays on the web,
because a paramedic scanning it will not have the app. The app renders the QR
(`qr_flutter`), copies the link, and can share it.

**Built (phase 5)** — `features/emergency/`. The card leads with blood type,
allergies are chips rather than prose, and each contact offers a `tel:` tap. An
empty profile says the QR would show a stranger a blank page instead of showing
a QR that does. The repository always sends all three profile fields, empty
string included, so clearing an allergy actually clears it — the `null` rule
above is the whole reason, and there is a test named after it. The percent
encoding matters: `testUser.id` is `#hos014`, and interpolated raw everything
after the `#` becomes a fragment the server never sees.

### 9.4 Share links — `front/app/share/page.tsx`
`GET /api/reports` + `GET /api/share`; `POST /api/share/{report_id}` and
`POST /api/share/qr-code` (both accept `?expires_hours=`, default 24);
`DELETE /api/share/{token}`. `{links:[{token, report_id, expires_at}]}` — `report_id`
is the sentinel `"__ALL_REPORTS__"` for a whole-record link. Shows the resulting
`{web origin}/share/{token}` or `/share/qr-code/{token}` URL as text + QR + copy.
`POST /qr-code` 400s with "Nothing to share" when the account is empty.

**Built (phase 5)** — `features/sharing/`. A whole-record card that names what a
stranger would actually see ("every report, every medicine, and your emergency
details"), a per-report list, and the live/expired split the API will not do for
you. Revoking says what it does to whoever is already holding the link. Expired
rows get Remove rather than Revoke, and no Show — a QR for a dead link is worse
than no QR.

### 9.5 Nearby care — `front/components/NearbyMap.tsx`
No MediStore endpoint. Device geolocation (fallback Kathmandu 27.7172, 85.324),
Overpass API for `amenity=hospital|clinic|pharmacy` within 4 km (three mirrors tried
in order), OSM tiles, up to 40 results sorted by haversine distance, pin colours
red/blue/green, and a Directions link. Flutter: `flutter_map` + `geolocator`, keep the
"© OpenStreetMap contributors" attribution (ODbL) and the mirror fallback.

**Built (phase 6)** — `features/nearby/`. Overpass goes through its **own** dio with
no interceptors: it is a third-party origin that must never see a MediStore bearer,
and a 401 from a busy mirror must never be able to sign anyone out. All three mirrors
are tried in order, 429 and 504 are treated as "try the next one" rather than as
errors, and if every one refuses the map still renders with the user's own pin and
says the data service is busy. Location failure and Overpass failure are separate
fields for the same reason — a denied permission still gives a usable map centred on
Kathmandu. Pins carry a letter as well as a colour (H/C/P), because three pin colours
on a busy map is exactly where a colour-blind reader is left guessing. The
attribution is required by the ODbL and is not decoration.

### 9.6 AI assistant — `front/components/ChatBot.tsx`
`POST /api/chatbot` `{messages:[{role, content}]}` → `{reply}`. Auth required; 500
when `GROQ_API_KEY` is unset, 502 on an upstream error. The **whole history is resent
each turn** and nothing is persisted server-side — the app should keep the transcript
locally and cap what it sends. Voice input via `speech_to_text`. Never render this
inside a caretaker context.

**Built (phase 6)** — `features/assistant/`, a full screen rather than the web's
floating bubble: a bubble over a medicine list is a desktop pattern that covers what
you were reading. Reached from Account only, and never from the caretaker screens.

The transcript lives in a `NotifierProvider` — it survives switching tabs and dies
with the process. Nothing written to disk, and nothing to delete later. What goes
back up is capped at 12 turns, because there is no thread id and an unbounded
transcript grows the request until Groq refuses it on token count and the assistant
silently stops working. The app's own error bubbles are excluded from that history:
feeding "Network error" to the model as though it had said it is nonsense.

The two failures are told apart. A 500 carrying "Groq API key not configured" means
this deployment has no key and retrying cannot help — the composer is replaced by an
explanation rather than left there to fail again. A 502 means Groq itself refused,
and Retry is offered on the failed turn (which re-asks without duplicating the
question). The disclaimer sits above the conversation, not below it, and does not
dismiss.

### 9.7 Settings (new screen; the web has no settings page)
Profile (`GET|PUT /api/users/me` — `{name?, address?, city?, latitude?, longitude?}`;
note `latitude`/`longitude` are write-only, never returned, and empty strings are
ignored by the `if user_data.x:` guards) · Two-factor (§3.4) · Theme (web keeps
`theme` in localStorage with a `prefers-color-scheme` fallback) · Language (`en`/`ne`,
`lang` in localStorage) · Caretakers (§6.3) · Sign out.

**Built (phase 6), in part** — `features/settings/`: Language, Appearance and Dose
reminders, plus Caretakers and Sign out reachable from Account. All three settings
are per-device and stored in a JSON file, not on the server: `PUT /api/users/me` has
no column for any of them, and a phone in Nepali beside a tablet in English is a
reasonable thing to want. Profile editing and two-factor setup are **not** here —
they are account operations, they are phase 8, and mixing "how the app looks" with
"change my password" makes both harder to find.

The reminders switch is where the notification permission is asked for, because that
is the moment the user has just said they want reminders. Asking on first launch is
the prompt everybody refuses.

### 9.8 Localisation
`front/lib/i18n.tsx` has exactly **17 keys, all navigation** — every other string in
the product is hard-coded English. Carrying over "every existing string" therefore
means: port those 17 `nav.*` keys to ARB, and write `ne` translations for the rest as
new work. Scope that honestly when phase 6 is planned.

**Built (phase 6), and scoped honestly** — `flutter_localizations` + `gen-l10n`, with
`lib/l10n/app_en.arb` and `app_ne.arb` checked in beside the generated Dart so the
analyzer and CI see the same file. The 17 `nav.*` keys are carried over with the
web's own Nepali wording, and the ARB grew to about 90: the bottom bar, Account,
Settings and the five phase 6 screens. `untranslated.json` is empty — the two files
are in step.

Everything else in the product is still an English literal, which is precisely the
coverage the web has. It is written up as `KNOWN_ISSUES.md` **P6-1**, along with the
other half of the problem: I wrote the Nepali, and a native speaker has not read it.

---

## 10. Evidence

Phase 1 recon ran with `server/` frozen — `git diff --stat -- server/` was empty and
the suite was 130 passed. The approved fixes then landed in their own commits:

```
ea2687d  Stop the documents list from 500ing on every call        server/ + tests
84cebee  Give doctors a route that can actually change a status   server/ + tests
89dca20  Fix the web app's broken calls and its off-by-a-timezone clocks   front/

$ cd server && python -m pytest -q
147 passed in 31.68s          # 130 before, +17 new

$ cd front && npx tsc --noEmit
(clean)

$ npx eslint app components lib
78 problems (63 errors, 15 warnings)   # baseline 79 / 63 / 16 — no new problems
```

Verified against local Postgres on a throwaway account, not just the SQLite suite:
register → form-encoded login → document create (omitted / blank / back-dated date)
→ **document list, which used to 500** → doctor promotion → availability → slot
lookup → booking → status change through the new route, refused through the old one.
All 18 web routes compile and serve 200 with no errors in the dev log.

**Not verified:** a click-through in a real browser against the changed backend. Next
16 allows one dev server per directory and yours holds the lock on port 3000 against
the API on 3001, which is still running pre-change code. Restart that uvicorn and your
existing tab picks everything up.

Local toolchain: Flutter 3.44.8 / Dart 3.12.2 on the stable channel. `adb` is not on
`PATH`, so device targets need checking before phase 3.
