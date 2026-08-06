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

### P1.5-2 · Text scaling at 2.0 has never been run — **Ship**

`DESIGN.md` §3 makes "survives `MediaQuery.textScaler` at 2.0" a review item at
the end of every phase, and no phase has run it yet. No tile has a fixed height,
so the design should hold, but "should" is the word doing the work. Needs a
golden or a device pass over the auth screens and Home.

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

## Closed

Nothing yet. Entries land here with the commit that fixed them.
