# Known issues — the open ledger

Everything found during a phase and **not fixed in that phase**. One entry per
problem, written at the moment it was found rather than remembered at the end,
so the list is what is actually wrong with the app rather than what I recall
being wrong with it.

Backend-side problems are not restated here — they live in `BACKEND_NOTES.md`,
which is the only place a backend change may be proposed. Entries below that
depend on one link to it by section number.

**How this file is maintained**

- Every phase appends a section before it reports. A phase that found nothing
  says so; an empty section is a claim, and a missing section is a gap.
- Fixed items move to **Closed** at the bottom with the commit that closed
  them. Nothing is deleted — a ledger you can prune is a ledger you can't audit.
- Severity is about *when*, not how annoying:

  | | meaning |
  |---|---|
  | **Blocker** | a later phase cannot be finished or honestly verified until this is fixed |
  | **Ship** | must be fixed before anyone but me runs this app |
  | **Papercut** | costs time or polish; fix when work goes near it anyway |
  | **Deferred** | a decision not to fix yet, with the reason recorded |

---

## Phase 1 — Recon

Six real bugs were found in `front/` and all six were fixed (`FEATURE_MAP.md`
§7.1–§7.6). What recon found and left standing:

### P1-1 · `RUN.md` documents an endpoint that does not exist — **Papercut**

`GET /api/export` ("Download all data (ZIP)") is in the server's own docs and no
router in `server/main.py` provides it. Documentation drift, not a broken route.
Left alone because `server/` is frozen through phase 6 and this is a doc fix in
`server/`, which the freeze covers. Fix: delete the line, or build the route in
phase 7 if data export is wanted.

### P1-2 · The doctor role cannot be reached from the app — **Blocker (phase 5)**

`ADD_DOCTOR_GUIDE.txt` onboards a doctor with two manual `psql` updates
(`users.role`, `doctors.verified`). That is correct as policy — role elevation
should not be self-service — but it means the doctor shell, the appointment
inbox and the availability editor cannot be exercised end-to-end without me
hand-editing local Postgres first. Phase 5 needs a seeded local doctor account
before its checkpoint can mean anything.

### P1-3 · Naive-UTC timestamps are a per-model trap, forever — **Watch**

The API returns naive datetimes that are UTC in fact and local-looking in form
(`FEATURE_MAP.md` §1.1). Every model that parses one must append the `Z` itself,
and every model that sends one must strip it. There is no central fix — adding
`Z` server-side would shift every time the deployed web app renders, which is
why it is in the rejected list in `BACKEND_NOTES.md`. This stays a review item
on every new model in phases 4–6.

### P1-4 · Backend gaps recorded but not proposed

No change-password endpoint; no account deletion or data export; no pagination
on list endpoints; report list ships full OCR text and both AI reports; report
upload runs OCR plus two LLM calls inside the request. All in
`BACKEND_NOTES.md` §3, §4, §9 and "Gaps noticed". Nothing to do before phase 7,
and phase 7 needs written approval.

---

## Phase 1.5 — Design system

### P1.5-1 · The chosen fonts are not bundled; the app is running on system faces — **Ship**

`lib/core/theme/app_theme.dart` names `Figtree` for headings and `Noto Sans` for
body. `pubspec.yaml` declares no font assets and the project has no
`google_fonts` dependency, so Flutter silently substitutes the platform default
(Roboto on Android, SF on iOS). Every screenshot taken so far — including the
phase 3 checkpoint ones — is of the fallback, not the design.

Three consequences, only the first of which is obvious:

1. The type scale in `DESIGN.md` §3 was measured against Figtree's metrics.
   Line heights and the negative tracking on the display sizes are tuned for a
   face that is not being drawn.
2. `fontFamilyFallback: ['Noto Sans Devanagari']` is equally unbundled. Android
   usually has it as a system font; **iOS ships Kohinoor Devanagari, not Noto**,
   so the named fallback likely resolves to nothing there and Nepali text will
   be laid out by the system's own fallback chain. Nepali is a shipped
   requirement, so this is not cosmetic.
3. `FontFeature.tabularFigures()` is requested against whatever font is
   substituted. It is a request, not a guarantee, and no screen with a column of
   numbers exists yet to show whether it took.

Fix is small and the choice is real: bundle the `.ttf` files under
`assets/fonts/` and declare them (offline, deterministic, ~600 KB) or add
`google_fonts` (fetches at first run, needs network on launch). Bundling is the
right answer for a health app that should work on a bad connection. Either way
it is one edit to `pubspec.yaml` and none to the theme.

### P1.5-2 · Text scaling at 2.0 is tested per screen, not everywhere — **Ship**

`DESIGN.md` §3 makes "survives `MediaQuery.textScaler` at 2.0" a review item at
the end of every phase. It is now automated for the design gallery
(`design_review_test.dart`), the sign-in screen (`auth_flow_test.dart`), the
five screens phase 5 added (`phase5_text_scale_test.dart`) and the six phase 6
added (`phase6_text_scale_test.dart`) — both brightnesses, a 320-wide viewport,
and for phase 6 also in Nepali, whose Devanagari sets longer than the English it
replaces.

Phase 4's screens — Medicines, Vitals, Reports, Documents, Home — still have no
such test, and "should hold" is doing the work for them. **Every screen that has
been tested failed the first time it was**: phase 5's found six overflows on
five screens, phase 6's found two more on the day they were written. Assume
phase 4's would too.

### P1.5-3 · Dark mode has never been seen on a device — **Papercut**

Both themes are built and `ThemeMode.system` is wired, but every emulator run
and every screenshot has been in light. The dark palette was validated as
numbers (`DESIGN.md` §2.3, §2.6) and not as pixels.

### P1.5-4 · The flutter.csv review checklist has never been completed — **Papercut**

`DESIGN.md` §10 lists 52 rules, 16 of them High, to be run at the end of every
phase. Phase 3 followed them while building — `PopScope` not `WillPopScope`,
controllers disposed, three states on every async surface, leaf-scoped
`setState` — but nobody has walked the list and ticked it. Do it as a pass, not
from memory.

### P1.5-5 · The chart palette is validated but undrawn — **Watch**

The series colours passed `validate_palette.js` and the range bar exists in the
design gallery, but no real chart has been rendered against real data. Phase 4's
vitals trends is the first test of whether the band, the series steps and the
status arrows read correctly at phone size.

---

## Phase 3 — Foundation

### P3-1 · iOS is configured and entirely unverified — **Blocker (any iOS ship)**

Xcode is incomplete on this machine, so no iOS build has ever been attempted.
Four things are set up on reasoning alone and listed in `README.md` under *iOS
parity*: `NSAllowsLocalNetworking`, Keychain storage with
`first_unlock_this_device` and no iCloud copy, Cupertino page transitions, and
the display name. Add P1.5-1's Devanagari point to that list. First real iOS
build should walk the table top to bottom.

### P3-2 · The two-factor path has never met a real server — **Ship**

The challenge is fully implemented and unit-tested against a fake HTTP client:
a 401 carrying `X-2FA-Required: true` becomes the code step, and the code rides
in OAuth2's `client_secret` field (`BACKEND_NOTES.md` §5). None of the six live
tests exercises it, because **no client can enrol a user in 2FA** — the web app
has no UI for it either (`FEATURE_MAP.md` §3.4), so the only way to get a real
TOTP account is to write a secret into local Postgres by hand. Until that is
done, "2FA works" means "2FA works against my own stub".

### P3-3 · Password reset needs the user to copy a code out of their email — **Papercut**

`reset_password_screen.dart` asks for the 43-character token as pasted text.
That works and was a deliberate phase-3 choice, but the reset email contains a
web URL, and no Android App Link or iOS Universal Link is configured, so tapping
it opens the browser rather than the app. Fixing it is deep-link config plus a
route, not a backend change.

### P3-4 · Test timing is fixed-duration, not settled — **Papercut**

`pumpAndSettle` is unusable in this app: the loading skeleton pulses and the
submit spinner turns, so "no frames scheduled" never arrives. Every widget and
integration test therefore pumps fixed durations, including a 500 ms pump after
navigation to outlive go_router's transition — during the transition the
incoming route sits inside an `IgnorePointer` and taps hit nothing, which cost
real debugging time once already. The durations are generous but they are
wall-clock guesses; a loaded CI machine could flake them. A `pumpUntil(finder)`
helper exists in `integration_test/sign_in_test.dart` and should be lifted into
`test/support/` and used everywhere instead.

### P3-5 · Mobile tests do not run in CI — **Ship**

`.github/workflows/ci.yml` has no Flutter job. `flutter analyze` and the 72
offline tests are run by hand, which means they are run when I remember. The
offline suite needs no server and no device, so it is a cheap job to add.
(Adding it is a repo-root change, not a `server/` change, so the freeze does not
cover it — but nothing is pushed until you say so.)

### P3-6 · The integration test leaves an account behind on every run — **Papercut**

Each run registers `phase3+<timestamp>@example.com` and never removes it; the
manual screenshot pass added `phase3.shot@example.com`. Local Postgres only, but
it grows without bound and it makes the users table useless for eyeballing. No
delete-account endpoint exists (P1-4), so cleanup today is SQL. Worth a
documented `psql` one-liner in the README at minimum.

### P3-7 · A session simply ends after seven days — **Deferred**

No refresh token exists, so a signed-in user is signed out mid-week with no
warning beyond the notice on the sign-in screen. Handled as gracefully as a
client can: expiry is read from the JWT locally at launch so a dead token routes
to sign-in with a reason instead of to a screen that 401s, and a mid-session 401
ends the session exactly once however many requests are in flight. The real fix
is a backend one — `BACKEND_NOTES.md` §6 — and is phase 7 with your approval.

### P3-8 · Codegen is pinned back a major version — **Watch**

`freezed` is held at `^3.2.5`, which forces `analyzer` 10.2.0 and
`build_runner` 2.15.1. Letting pub solve freely picks `freezed 4.0.0-dev.3`, and
a dev prerelease is not what the foundation of the app should rest on. Revisit
when freezed 4 goes stable; expect a codegen migration when it does.

### P3-9 · `flutter devices` needs `ANDROID_HOME` set by hand — **Papercut**

The SDK here is at `/opt/homebrew/share/android-commandlinetools`, not the
default `~/Library/Android/sdk`, so a fresh shell cannot see a running emulator
until it is exported. Documented in `README.md`. A line in the shell profile
would end it permanently.

### P3-10 · The Home "Connection" card is scaffolding — **Watch**

It is honest — every value on it comes from a real `GET /health` — but a signed-
in patient should not be looking at server diagnostics. Phase 4 replaces it with
the real dashboard. Listed here so it cannot quietly survive into a release.

---

## Phase 4 — Core patient features

Five bugs were found *and fixed* in this phase and are in **Closed** below.
What phase 4 found and left standing:

### P4-1 · A dose marked taken un-ticks itself when the app restarts — **Ship**

`POST /api/medicines/{id}/intake` writes to `medicine_intake` and there is no
route that reads it back *per dose* — `GET /intake/log` returns a flat history
with no way to ask "was the 08:00 dose taken today". So `_DoseRow._marked` is
widget state: tick a dose, leave the tab and come back, and the Taken button is
offered again. Tapping it twice writes two rows, which the log will happily
show. The row says the mark is local rather than implying otherwise, but that
is a caption, not a fix. Needs either a query parameter on the log route or a
client-side reconciliation of today's log against today's schedule — the
second is doable without touching `server/` and is the phase 6 job when
reminders arrive. Backend option in `BACKEND_NOTES.md`.

### P4-2 · No emulator pass was run for any phase 4 screen — **Ship**

Every screen in this phase is verified by widget tests against a scripted
backend and by 17 live tests against local Postgres, and by nothing on a
device. That leaves untested: the camera and photo-library pickers (both new
permissions), `Printing.sharePdf`'s share sheet, `file_picker`'s document
picker, real scroll performance on a long report list, and whether the fl_chart
tooltip is reachable with a thumb. Everything in P1.5-2 and P1.5-3 — 2.0× text
and dark mode — is still owed for these screens too; only the dashboard has a
text-scaling test.

### P4-3 · Nothing is paginated except vitals, and vitals is capped — **Ship**

`GET /api/vitals` takes `limit`/`offset` and 422s above 200, so the app asks
for 200 and a patient with more readings than that silently sees only the
newest 200 — the chart's "N readings" line will disagree with reality. Medicines,
reports and documents have no paging at all: the client gets every row every
time. This is fine for a demo account and wrong for a real one. `BACKEND_NOTES.md`
§9; nothing to do before phase 7.

### P4-4 · The reports list downloads every report's full OCR text — **Ship**

`GET /api/reports` returns `extracted_text` *and* `ai_report_text` in full for
every row (`BACKEND_NOTES.md` §3). The list screen uses neither — it needs the
summary and the file name — but a patient with twenty scanned reports pays for
all of it on mobile data before the first card draws. The client cannot fix
this; a `?fields=` or a slimmer list schema is a phase 7 proposal.

### P4-5 · The whole file is held in memory to show it — **Watch**

Report files and attachments are auth-gated routes, so `Image.network` 401s and
every binary goes through `fileBytesProvider` as a `Uint8List`. A 10 MB scan is
10 MB of RAM while it is on screen, plus two minutes after (the keep-alive that
stops a re-download when flipping between the image and its lab values). The
server enforces a 10 MB upload cap so the worst case is bounded, and no page
holds more than one file at a time. Streaming to a temp file would be the fix
if this ever bites.

### P4-6 · Caretaker scope covers medicines and nothing else — **Decided in phase 6: it is the product**

`resolve_medicine_scope` is the one authorisation chokepoint and it guards
`/api/medicines*` only. Vitals, reports and documents have no `patient_id` at
all, so a caretaker can manage someone's prescriptions and see none of their
readings or scans. The client was built for it — the medicine providers are a
family keyed by patient id, and the vitals and reports providers deliberately
are not.

**Phase 6 decided this asymmetry is the feature, and did not propose widening
it.** "Someone can help with my pills" is a much easier thing to consent to than
"someone can read my record", and the narrower grant is what makes the code
worth handing to a neighbour. `care_medicines_screen.dart` renders medicines and
nothing else — and, as importantly, *fetches* nothing else, so another person's
vitals never reach the caretaker's device at all. There is no phase-7 proposal
to broaden the scope, and `BACKEND_NOTES.md` still lists touching the chokepoint
under **Rejected — never**.

### P4-7 · The web app labels blood sugar mmol/L and stores mg/dL — **Papercut**

`front/app/vitals/page.tsx` prints "mmol/L" on its summary strip while its own
form and its own analyser treat the number as mg/dL — a 5.5 typed as mmol/L
reads as critically low. The mobile form says mg/dL on the field, which is the
real unit and the only place a user can be warned, so the phone is right and
the browser is wrong about the same stored value. Fixing `front/` is allowed
and was out of scope here; it is a one-word change in one file.

### P4-8 · The reference ranges reproduce the web's clinical oddities — **Watch**

`vital_ranges.dart` is a branch-for-branch port, including the two places the
web is odd: the upper blood-pressure branches use `||` where the lower ones use
`&&` (so 135/95 reads Stage 1, not Stage 2), and the temperature label says the
normal band starts at 36.1 while the analyser's branch is `< 36.0`. Both are
pinned by tests with the reason in the code. Reproduced deliberately — a patient
comparing phone and browser must see the same word — but they are wrong in both
clients, and the moment `front/` is corrected these tests must be changed with
it, not after.

### P4-9 · The digital-report parser flags cells by substring — **Papercut**

`_isAbnormal` asks whether a cell contains "low", "high", "above"… so a
urinalysis whose colour is "Yellow" and a recommendation that says "Follow-up"
both come out red. Carried from `front/components/DigitizedReport.tsx` and
pinned by a test so it is a known cost rather than a surprise. A word-boundary
match would fix it in both clients; doing it in only one would make the same
report look different in each.

### P4-10 · Two backend fields are not exposed anywhere in the app — **Watch**

`MedicalReport.documentId` links a report to the visit it came from and nothing
in the UI shows the link or offers to set it; `DocumentFile.fileType` is always
`"OTHER"` because the upload path hardcodes it despite the enum having four
values. Both are read and decoded, so wiring them up later costs nothing — but
today the app is quietly ignoring a relationship the data model has.

---

## Phase 5 — Scheduling & sharing

### P5-1 · A doctor's inbox can never show a request to accept — **Ship**

`POST /api/appointments` sets `CONFIRMED` when the body carries a `doctor_id`
and `PENDING` when it does not (`server/app/api/appointments.py:206`), and
`GET /appointments/doctor/my-appointments` selects on
`Appointment.doctor_id == doctor.id`. The two rules cannot both be satisfied:
an appointment that is `PENDING` has no doctor to route it to, and one that
reaches a doctor is already accepted on the patient's behalf. So "Waiting on
you" — and Accept and Reject with it — is dead code in practice.

The screen still ships with that section, because the doctor *can* move a
booking back to `PENDING` and because the state exists in the API. But nothing
a patient does in either client produces one. Fix is a backend change (see
`BACKEND_NOTES.md` §10): book as `PENDING` and let the doctor confirm, behind a
flag so `front/` keeps its current behaviour. Do not paper over it client-side
by hiding the section — a doctor being told they have nothing to approve when
approval was never possible is the honest state.

### P5-2 · Two patients can take the same slot — **Ship** (backend)

`is_slot_available` selects every appointment for that doctor starting before
the requested end and inspects exactly one of them, via `.first()` with no
`ORDER BY` (`appointments.py:174`). With one appointment on file the check
works, which is why it looks correct in a demo. With two it inspects an
arbitrary row — in practice the oldest — and returns "free".

Reproduced against local Postgres on 2026-08-07: a doctor with one past
appointment took three bookings into the same 10:00–10:30 slot, all `200`.
Rows deleted afterwards.

The mobile client does not *expose* the hole — `available-slots` runs a correct
per-slot check, the booking sheet only offers chips it returned, and 10:00 was
correctly absent from the diary while triple-booked. So this bites two patients
tapping the same chip at the same moment, and anyone posting directly. Client
cannot fix it: the check has to be atomic and it has to be on the server.
`BACKEND_NOTES.md` §11.

### P5-3 · A doctor cannot correct their own registration — **Papercut**

`POST /api/doctors` 400s with "Doctor profile already exists" and there is no
`PUT`. A doctor who fat-fingers their NMC number or picks the wrong specialty
has to ask an operator with `psql`. The registration sheet says so rather than
pretending otherwise, but it is a gap, not a policy: unlike `verified`, none of
these three fields is a privilege. `BACKEND_NOTES.md` §12.

### P5-4 · `PUT /availability/{id}` accepts hours that `POST` refuses — **Watch**

Creating a window checks that it does not overlap an existing one and that the
end is after the start. Editing one checks neither, and cannot change
`day_of_week` at all. So the app has to delete-and-recreate to move a window to
another day, and an edit can produce exactly the overlap the create path exists
to prevent. The client validates end-after-start itself before sending; it does
**not** re-run the overlap check, because doing so client-side would be a second
source of truth for a rule the server owns. `BACKEND_NOTES.md` §13.

### P5-5 · Appointments are wall-clock, with no zone anywhere — **Watch**

`appointment_date` goes out and comes back as a naive local datetime, and an
aware one is a `500` (pinned by a live test: `AppointmentCreate`'s validator
compares against a naive `datetime.now()`). Everything downstream inherits it —
the calendar invite `calendar_invite.dart` writes is deliberately floating time,
no `Z` and no `TZID`, so importing it keeps the wall clock rather than shifting
it. That is right *today*, because it matches what the server means. It stops
being right the moment a doctor and a patient are in different zones, and the
`.ics` file is the part that will be wrong silently, in someone else's calendar
app. Blocked on `BACKEND_NOTES.md` §7 (the server cannot learn a client's
timezone).

### P5-6 · Nothing reminds anyone an appointment is coming — **Deferred**

`Appointment.reminder_sent` exists, is read by the client, and is never set by
anything. No local notification is scheduled either. Deferred to the phase that
does notifications (`BACKEND_NOTES.md` §8), not because it is small — an
appointment nobody is reminded of is most of the value of booking it — but
because a half-measure now (local notifications only, silently lost on reinstall)
would look like the feature and not be it.

### P5-7 · The QR codes point at a web app the build has to be told about — **Ship**

Both QRs — the emergency ID and every share link — encode a URL built from
`Env.webBaseUrl`, which comes from `--dart-define=WEB_BASE_URL` and defaults to
`http://localhost:3000`. A release build made without that define ships QR codes
that resolve to nothing on the scanner's phone, and the failure is invisible
until somebody actually scans one. There is no client-side check possible: the
app cannot tell a wrong-but-reachable host from a right one. Two ways out, both
for later — put `frontend_url` on `/health` and read it at runtime
(`BACKEND_NOTES.md` §14), or make the define required at build time. Until then
it is a release-checklist item, and it is written down here because a checklist
item nobody wrote down is not one.

### P5-8 · Sharing, calling and the calendar have never run on a device — **Ship**

`share_plus`, `url_launcher` (`tel:` for an emergency contact) and the `.ics`
hand-off all work in tests against a fake, and all three are exactly the kind of
thing that only fails on real hardware: an Android intent filter that is not
there, an iOS `LSApplicationQueriesSchemes` entry that is missing, a share sheet
that needs an origin rect on iPad. Same shape as P4-2 and it does not close it —
that entry is about phase 4's screens, this one is about three platform channels
phase 5 introduced.

### P5-9 · An expired share link is a row the server will not clean up — **Watch**

`GET /api/share` returns expired links with nothing marking them, so the client
decides (`ShareLink.hasExpired`, unparseable dates counted as expired — a link
we cannot read the expiry of must not be shown as live). `DELETE /api/share/{token}`
is offered as "Remove" for those rows, so a user can tidy up. Nothing does it
automatically, and a user who never opens the screen accumulates dead rows
forever. Cosmetic today; it is here because "the list gets slower the longer you
use the app" is the kind of thing that is only cheap to fix early.

### P5-10 · The doctor directory is the only way to find a doctor — **Papercut**

`GET /api/doctors/doctors` returns every verified doctor, unpaginated and
unsearchable, and the booking sheet renders the lot in a dropdown. Fine at three
doctors, unusable at three hundred. Same family as P4-3; listed separately
because this list has no cap at all, where vitals at least has one.

### P5-11 · P1-2 was worked around, not fixed

Phase 5's checkpoint needed a doctor account, so I made one the way
`ADD_DOCTOR_GUIDE.txt` says to: two `psql` updates against **local** Postgres.
The end-to-end loop is genuinely proven — unverified doctor invisible in the
directory, visible after verify, window created, slot booked, slot gone from the
diary, booking in the inbox, `/status` 404 for the doctor and
`/status/by-doctor` 200. P1-2 stays open: the app still cannot reach the role on
its own, and nobody without database access can see any of the three doctor
screens.

---

## Phase 6 — Extras

Timeline, search, the assistant, the nearby map, caretakers, local reminders,
the offline cache and `en`/`ne`. Eight things, and the honest summary is that
five of them are finished and three are the *shape* of the feature with a real
limit written down beside it.

### P6-1 · Nepali covers navigation and phase 6, and nothing else — **Ship**

`lib/l10n/app_ne.arb` has every key `app_en.arb` does — the two files are in
step, and `untranslated.json` is empty. But the ARB holds about 90 keys: the
bottom bar, Account, Settings, and the five screens this phase added. Every
other string in the product is a Dart literal in English — Medicines, Vitals,
Reports, Documents, Appointments, Sharing, Emergency ID, all three doctor
screens, every form sheet, every validation message and every error string.
Switching to Nepali therefore gives a Nepali frame around an English app.

That is the same coverage `front/lib/i18n.tsx` has (17 nav keys, everything else
hard-coded), so nothing regressed — but the brief asked to "carry over every
existing string", and the existing strings were only ever the navigation.
Finishing this is mechanical and large: roughly 400 more keys, and each one is a
sentence somebody has to write twice.

**And the translations are unreviewed.** I wrote the Nepali. It is careful, and
it is not a native speaker's. Somebody who speaks it should read
`app_ne.arb` end to end before this is shown to a patient — particularly
`caretakersBlurb` and `assistantDisclaimer`, where a clumsy phrasing is a
consent problem rather than a typo.

### P6-2 · Reminders live and die on one phone — **Deferred** (backend)

`flutter_local_notifications` schedules the next seven days of doses whenever
the app is opened, and that is genuinely all the freeze allows. Three limits
follow, none of them fixable client-side:

- **Reinstall or a new phone loses every alarm** until the app is opened again.
- **A phone that does not open MediStore for eight days runs out** of scheduled
  reminders and goes quiet, with no signal that it has.
- **A caretaker is never notified.** `reminder_scheduler.py` fans out to Web
  Push subscriptions; a caretaker on Android has none, so the patient's doses
  reach nobody but the patient.

`BACKEND_NOTES.md` §8 is the fix and now has phase 6's answer written into it.

### P6-3 · The bell on a client card mutes something a phone cannot hear — **Ship**

`PATCH /api/care/links/{id}` sets `CareLink.notify`, which controls whether
`reminder_scheduler.py` sends *that caretaker* the patient's dose reminders —
over Web Push. A caretaker using this app has no web-push subscription, so the
toggle changes a column and nothing else the caretaker can observe. The control
is real, the server honours it, and it currently has no visible effect on
mobile. It is shipped rather than hidden because it also governs what a
caretaker who *also* uses the web app receives, and because hiding it would
silently change a preference that is already set — but it is misleading, and it
should be relabelled or hidden once §8 lands and mobile actually receives
something.

### P6-4 · The lock screen says what you take — **Watch**

A dose reminder reads "Time for Amlodipine · 5 mg". That is visible to anyone
holding the phone, and it is a deliberate choice: a reminder that will not say
what to take is not a reminder, and it matches what the product already does —
`_payload` in `reminder_scheduler.py` sends "Time for Amlodipine 5 mg" over Web
Push today. Nothing leaves the device. Recorded because it is a disclosure
somebody should get to decline: a "discreet reminders" switch that shows only
"Time for a dose" is a small phase-8 addition.

### P6-5 · The offline cache covers two lists, not the app — **Watch**

Medicines and vitals are saved and served stale-while-revalidate; everything
else — reports, documents, appointments, the timeline, search — still needs the
network and shows an error card without it. That was the choice: those two are
the dashboard and the daily schedule, which is what somebody actually needs in a
lift or a hospital basement. A report list nobody can open the files of is worth
much less offline. Widening it is a per-controller change of about ten lines
each, and `cached_list.dart` exists so it stays one behaviour.

### P6-6 · The cache is plaintext JSON in app-private storage — **Watch**

`FileLocalStore` writes to the app support directory, which is sandboxed per app
on both platforms and not in the default backup set for this location. It is not
encrypted. Hive would not have been either. A rooted or jailbroken phone, or a
full-disk forensic image, reads a medicine list. The JWT is in the keystore and
stays there; this is the deliberate lower bar for a cache. Encrypting it means
a key that also has to live somewhere, which is a real design decision and not
a phase-6 one.

### P6-7 · Search finds medicines you deleted — **Ship** (backend)

`GET /api/search` filters `MedicalDocument.deleted_at` and does **not** filter
`Medicine.deleted_at` (`search.py:70-74` against `95-100`). A removed medicine
keeps turning up in results forever. Proven live — `live_backend_test.dart`
deletes one and then finds it. Client-side the app makes the best of it: the row
is tappable, and tapping says the medicine was removed and offers Restore, which
works. `BACKEND_NOTES.md` §15.

### P6-8 · The timeline reads the whole account to show forty rows — **Watch** (backend)

`timeline.py` runs four unbounded selects, concatenates, sorts in Python, then
slices. `limit` bounds the response, not the work. The client pages at 40 to
keep the response small, which helps the wire and not the database. Already in
`BACKEND_NOTES.md` §9; noted here because phase 6 is what made it a screen
somebody will scroll.

### P6-9 · The assistant forgets the conversation when the app closes — **Deferred**

The transcript lives in a Riverpod provider: it survives switching tabs and dies
with the process. Nothing is written to disk, and nothing is stored server-side
either — `chatbot.py` keeps no thread. That is a choice, not an oversight: a list
of somebody's symptoms is the most sensitive text in the product and there is no
feature here that needs it to outlive the session. If history is wanted later it
should be an explicit, deletable thing, not a side effect of a cache.

### P6-10 · The map depends on a free service that is often busy — **Watch**

Nearby care has no MediStore endpoint behind it. Tiles come from OpenStreetMap
and places from Overpass, a donated public service that rate-limits and returns
429/504 under load. Three mirrors are tried in order, the map still renders with
the user's own pin when all three refuse, and the message says the data service
is busy rather than blaming the connection. There is no fallback beyond that.
OSM's tile policy also expects an identifiable user agent; the app sends
`com.medistore.app`, and a real deployment should keep that accurate.

### P6-11 · Four new platform channels, none of them run on a device — **Ship**

Map tiles, `geolocator`, `flutter_local_notifications` and `speech_to_text` are
all wired, permission-declared on both platforms, and exercised only against
fakes. Every one of them is the kind of thing that only fails on hardware: a
notification channel that is never created, an OEM that refuses a cold GPS fix,
a recogniser that is not installed, a tile server that blocks the default agent.
The Android manifest and `Info.plist` entries added this phase — `POST_NOTIFICATIONS`,
`RECEIVE_BOOT_COMPLETED`, the two location permissions, `RECORD_AUDIO`, the boot
receiver, core-library desugaring, `NSLocationWhenInUseUsageDescription`,
`NSMicrophoneUsageDescription`, `NSSpeechRecognitionUsageDescription` — are all
unverified. Same family as P4-2 and P5-8; this does not close either.

**One of them is a fix for a phase-5 bug, also unverified:** the `<queries>`
block for `tel:` and `https:`. Without it, Android 11+ hides installed apps from
`canLaunchUrl`, so the emergency contact's phone number and the Directions link
both silently do nothing. It is in the manifest now and nobody has watched it
work.

### P6-12 · A caretaker's dashboard costs a request everyone else does not pay — **Papercut**

`PeopleICareFor` calls `GET /api/care/links?role=caretaker` on every dashboard
open, and that endpoint computes a next-dose summary per client. It is skipped
entirely when `/health` says caretakers are off, and it renders nothing when
there are no links — but a caretaker pays for it every time the app opens. Cheap
to make conditional on something cached; not worth it before anyone complains.

### P6-13 · The nearby screen has no widget test — **Papercut**

`FlutterMap` wants real tiles and a real ticker; standing one up in a widget test
means faking a tile provider and is more scaffolding than the assertion is worth.
The decoding, the distance maths, the mirror fallback and the result cap are all
covered by `nearby_test.dart` against a fake adapter, which is where the logic
lives. What is untested is the widget tree — including whether it survives 2×
text, which every other phase 6 screen is now checked for.

### P6-14 · The live suite takes a minute and leaves accounts behind — **Papercut**

`live_backend_test.dart` now registers seven throwaway accounts per run, which
trips slowapi's `5/minute` on `/api/auth/register`. `registerPatiently` waits out
the window rather than weakening the limit, so a full run takes just over a
minute and the file carries a five-minute timeout. The accounts stay in local
Postgres. Extends P3-6 rather than closing it.

---

## Closed

| Entry | Closed by | What it was |
|---|---|---|
| P1.5-5 | phase 4 | The chart palette is now drawn against real data by `VitalTrendChart`, band and series steps included. |
| P3-10 | phase 4 | The Home "Connection" card is gone; `home_screen.dart` is the real dashboard. |

**P3-4 is not closed.** The pump sequences are now one shared `settle()` in
`test/support/harness.dart` instead of being hand-written per test, so there is
a single place to tune them — but they are still fixed durations, not waits on
a condition, which is what the entry actually asks for. Phase 4 also made it
worse before making it better: `settle` had to grow to two one-second frames
because a departing FAB sits over a snackbar's action and eats the tap until
both its exit and its move animation finish. That is exactly the kind of
wall-clock guess the entry warns about.

**Found and fixed inside phase 4** — recorded here because each was a real
defect a user would have hit, not just a refactor:

| What | Where | Why it mattered |
|---|---|---|
| Every button had an infinite minimum width | `app_theme.dart` — `Size.fromHeight` sets `minWidth` to infinity | Not just "buttons are full width": a filled or outlined button inside a `Row` **crashed the screen**, because an infinite minimum width cannot be satisfied where the parent is horizontally unbounded. It took the Documents card down the moment a visit was expanded. Now a real touch-target minimum; the four places that want full width already ask for it. |
| The vitals chart asserted on a zero axis interval | `vital_trend_chart.dart` | `measured_at` defaults to `utcnow()` server-side, so two readings saved in the same second share an x, the axis span is 0, and fl_chart's assertion took the whole Vitals tab down. |
| Half a blood pressure could not be completed | `vital_form_sheet.dart` | The sheet only rebuilt when "is anything filled in" flipped, so typing the *second* number left the save button dead and "A blood pressure needs both numbers" on screen, with no way forward but clearing the field. |
| An empty reading counted as data on the dashboard | `vitals_controller.dart` | `POST /api/vitals` stores a row with every measurement null and the web app's form will send one. `latestVitalProvider` returned it, so the dashboard showed no tiles *and* hid the "Record a reading" prompt — a patient with an empty row saw nothing at all. |
| A save in flight could be swiped away | `form_sheet.dart` | Four minutes of OCR and two LLM calls would land on a sheet that had gone, leaving a report on the server and not in the list until the next refresh. |

**Found and fixed inside phase 5:**

| What | Where | Why it mattered |
|---|---|---|
| Booking a new appointment opened in "Somewhere else" mode | `book_appointment_sheet.dart` | The mode was chosen with `existing?.doctorId == null`, which is also true when `existing` is null. Every fresh booking landed on the free-text path, so a patient could not pick a listed doctor at all — the entire slot-picking flow was unreachable from the FAB. |
| A status chip could push a card's title off the screen | six `Row`s across four screens, now `CardHeader` / `SectionHeading` | A `Row` measures a non-flex child against unbounded width, so `Expanded(title) + StatusChip` does not clip the chip, it overflows the card. "Awaiting confirmation" at 2× text overflowed by 241px. Found by the new `phase5_text_scale_test.dart`, which is the only reason it was found at all. |
| The availability editor could not be corrected | `availability_screen.dart` — `AvailabilityController.update` | Named `update`, which illegally overrode `AsyncNotifier.update`. It compiled as an override and did the wrong thing. Renamed to `edit`, with the reason in a comment so it does not come back. |
| A past slot was offered for booking | `appointments_controller.dart` — `bookableSlots` | The server's "is this in the future" check runs against `datetime.now()` in the *server's* zone — UTC on Render, 5h45m behind Kathmandu. A Nepali patient booking this morning would be offered slots the server would then refuse. Filtered client-side against the phone's clock. |
| Clearing an emergency field left it unchanged | `emergency_repository.dart` | `PUT /api/emergency/profile` reads `null` as "leave alone", so a form that sends null for an emptied box makes an allergy that no longer applies impossible to remove. The repository now always sends all three fields, empty string included. Pinned by a test. |

**Found and fixed inside phase 6:**

| What | Where | Why it mattered |
|---|---|---|
| Signing out would have reset the user's language | `local_store.dart` — `clear()` → `clearPrefix()` | Preferences and the offline cache share one folder, so the blanket `clear()` I first wrote meant signing out silently put a Nepali-speaking user back into English. The store now deletes by prefix and the session controller asks for `cache.` only. |
| Clearing the cache on sign-out was a dependency cycle | `session_controller.dart` | `offlineCacheProvider` watches the session to know whose cache it is, so reading it from `signOut` threw `CircularDependencyError` — a crash on the way out of the app. It goes through `LocalStore` directly now, with the reason in a comment. |
| A wedged platform channel would have hung the medicine list | `local_store.dart` | `getApplicationSupportDirectory()` sits in front of every cached read, and an unanswered method channel never completes — it does not throw. The whole dashboard hung behind it in the test suite before a 3-second timeout was added. On a device it resolves; the timeout is there so a broken one degrades to "no cache" rather than "no app". |
| Two more 2×-text overflows | `people_i_care_for.dart`, `timeline_screen.dart` | The same `Row` rule phase 5 wrote `CardHeader` for: a `Row` hands a non-flex child unbounded width, so "Add someone" ran 45px off the heading and "APPOINTMENT" ran 32px out of its card. Found by `phase6_text_scale_test.dart` on the day it was written. |
| A `RadioListTile` group that would not compile clean | `settings_screen.dart` | `groupValue`/`onChanged` are deprecated in Flutter 3.44 in favour of a `RadioGroup` ancestor, and `flutter analyze` counts an info as an issue. Rewritten with `RadioGroup`, and the language options got a real enum rather than a nullable locale so "follow the phone" and "nothing selected" stay distinguishable. |
| The live suite tripped the server's own rate limit | `live_backend_test.dart` | Adding a seventh registration pushed the run past `5/minute` on `/api/auth/register`. The 429 is the server working; the suite now waits out the window instead, and carries a 5-minute timeout so the wait is not killed at 30 seconds. |
