# Ayuvo — mobile

The Flutter client for Ayuvo, replacing the Next.js UI in `../front`. The
backend in `../server` is unchanged by this app and stays the contract: read
`../server/app/api/<name>.py` before wiring a feature, and `FEATURE_MAP.md` for
what each screen calls.

Design decisions and their measurements live in `DESIGN.md`. Backend changes
worth making — proposed, rejected, or shipped — live in `BACKEND_NOTES.md`.
Everything a phase found and did not fix lives in `KNOWN_ISSUES.md`, which is
the list to read before trusting any part of this app.

## Running it

```bash
# 1. the backend, in another terminal
cd ../server && python -m uvicorn main:app --reload --port 3001

# 2. the app
flutter run                                        # local dev backend
flutter run --dart-define=API_BASE_URL=https://…   # any other backend
```

Two build-time settings, both `--dart-define`, both with local defaults:

| Define | Default | What it is |
|---|---|---|
| `API_BASE_URL` | local dev server | On Android that means `http://10.0.2.2:3001` — the emulator's alias for your machine, not `127.0.0.1`, which on a phone means the phone. |
| `WEB_BASE_URL` | `http://localhost:3000` | Where the **web** app lives. Every QR code the app draws — the emergency ID and every share link — points at it, because the people scanning them do not have this app. |

See `lib/core/config/env.dart`. **A release build must set `WEB_BASE_URL`.**
Nothing detects a wrong one; the QR codes just resolve to nothing on somebody
else's phone (`KNOWN_ISSUES.md` P5-7).

Cleartext HTTP to those addresses is permitted in **debug builds only**, via
`android/app/src/debug/res/xml/network_security_config.xml`. A release build
still refuses plain http everywhere.

The design system has its own entry point, so it can be reviewed on a device
without signing in:

```bash
flutter run -t lib/dev/design_gallery.dart
```

## Tests

```bash
flutter analyze                     # must be clean
flutter test                        # unit + widget, offline, no server needed

# the client against a running local backend — registers throwaway accounts
flutter test test/live_backend_test.dart --dart-define=LIVE_BACKEND=true

# the real app on a real device, against a running local backend
flutter test integration_test/sign_in_test.dart -d <device>
```

`flutter test` never touches the network: the two suites that do are opt-in
(`--dart-define`) or live under `integration_test/`. If `flutter devices` can't
see your emulator, export `ANDROID_HOME` first — the SDK here is at
`/opt/homebrew/share/android-commandlinetools`.

## Code generation

Models use freezed + json_serializable. After editing anything with a
`part '*.freezed.dart'`:

```bash
dart run build_runner build
```

Strings use `gen_l10n`. After editing `lib/l10n/app_*.arb`:

```bash
flutter gen-l10n
```

Both sets of generated files are committed, so a fresh clone builds without
running either. `lib/l10n/untranslated.json` is the gap report — it should stay
`{}`, and an entry in it means `app_ne.arb` has fallen behind `app_en.arb`.

## Layout

```
lib/
  core/
    cache/      the offline read path — stale-while-revalidate, one owner per entry
    config/     Env — the API base URL and the web app's, nothing else
    l10n/       context.l10n, over the ARB files generated into lib/l10n/
    network/    ApiClient (bearer, 401, form login), ApiException, ScopedUrl
    notifications/  dose reminders, scheduled on the device
    session/    who is signed in; restore, sign out, seven-day expiry
    settings/   language, theme and reminders — per device, never on the server
    storage/    the keystore the token lives in, and the file store everything
                non-secret lives in
    health/     GET /health, including the caretaker feature flag
    router/     go_router: auth-aware redirect, role-aware shells
    theme/      the design system — the only file with a raw colour in it
    widgets/    RangeBar, StatusChip, CardHeader, LinkCard/QrPanel,
                FormSheet, Skeleton, EmptyState, ErrorView
  features/<feature>/{data,domain,presentation}
  l10n/         app_en.arb, app_ne.arb, and the generated AppL10n
  dev/          the design gallery (not part of the app)
```

Five rules that are load-bearing rather than stylistic:

- **`ScopedUrl` is the only thing that may build a patient-scoped URL.** Ids
  contain `#`; interpolated raw, the id vanishes and the server quietly returns
  the *caller's* records. Tested in `test/scoped_url_test.dart`.
- **Caretaker scope is medicines-only.** Never render vitals, reports,
  documents or the assistant in a caretaker context.
- **A `Row` does not clip an oversized child, it overflows.** Any header that
  pairs text with a badge goes through `CardHeader`, which caps the badge at
  half the line so neither side can run off the screen at large text sizes.
  Eight of these have been shipped broken and caught by the two
  `phase*_text_scale_test.dart` files. A new screen without one of those tests
  should be assumed broken.
- **Never write another person's data to disk.** `offline_cache.dart` refuses a
  patient-scoped entry outright, and every entry it does write is stamped with
  the account it belongs to — a read by anyone else deletes the file rather
  than rendering it. A care link can be revoked at any moment and a cached copy
  would outlive the permission that justified it.
- **A dose time from `/api/care/links` is the patient's wall clock, not an
  instant.** Render `next_dose_local` verbatim. Parsing `"08:00"` into a
  `DateTime` re-expresses it in the caretaker's timezone and shows a time
  neither party acts on.

## What works today (end of phase 6)

**Account.** Sign in, sign out, register, the two-factor challenge,
forgot/reset password, session restore across launches, and a 401 anywhere
ending the session with a reason.

**Home.** A real dashboard: the next dose with a countdown, today's schedule
with a Taken button on each row, the latest reading as judged tiles, and a
"get started" pair that disappears once there is data. Two requests, shared
with the tabs.

**Medicines.** The list split into current and finished, add and edit with dose
times, soft delete with a working Undo, the interaction check with its
disclaimer and its checked-count, the change history and the intake log.

**Vitals.** Record a reading, every metric judged against the same reference
ranges the web app uses, a trend chart per metric with the normal band drawn
behind it, and a hard delete that says it is permanent.

**Reports.** Upload a photo or a PDF with real progress, the tracked-value
strip across reports, lab values, the plain-language explanation on request,
the formal report and its PDF export, and delete. Actions OCR made impossible
are absent with a reason rather than offered and refused.

**Documents.** Visits with their attachments — add, attach, view, delete.
Reached from Account, and the bottom bar stays put.

**Appointments.** What is coming up and what already happened, booking either
with a listed doctor — pick a date, tap a free slot the server offered — or
somewhere else entirely by typing the name. Reschedule, cancel, delete, and an
`.ics` invite through the share sheet.

**Sharing.** A link to your whole record or to one report, with a window you
choose, shown as a URL and a QR. Live and expired links are never shown as the
same thing, and revoking says what it does to whoever is already holding one.

**Emergency ID.** Blood type, allergies, conditions and the people to phone, as
a card and as a QR a paramedic can scan without this app installed. Each contact
is one tap to call.

**Timeline.** Everything on the record in one story, grouped by day, paged forty
at a time. Each row says its kind once — in a coloured badge, not also in the
title the server pre-formatted.

**Search.** One box over reports, medicines and visits, debounced, grouped by
kind, and deep-linked: a report opens the report, a visit opens its card already
expanded, a medicine opens its edit sheet.

**Health assistant.** A full screen rather than a floating bubble, with voice
input where the phone has a recogniser. The transcript stays in memory and is
never written anywhere; what goes back to the server is capped at twelve turns,
because the whole conversation is resent each time. A server with no AI key says
so instead of failing on every question.

**Nearby care.** Hospitals, clinics and pharmacies within 4 km on an
OpenStreetMap map, nearest first, each one tappable through to directions. Works
without a location permission — it centres on Kathmandu and says so.

**Caretakers.** Issue a code, read it out, watch it count down; see who holds
one, what they have changed, and undo a deletion. On the other side: the people
you care for, on your own dashboard, with their next dose in *their* clock — and
a medicines-only screen for each, marked so it can never be mistaken for your
own list.

**Reminders.** A notification at each dose time, scheduled on the phone for the
next seven days and rebuilt whenever the list or the setting changes. Off by
default; the permission is asked for at the moment the switch goes on.

**Offline.** Medicines and vitals are saved locally and shown immediately while
the app checks for changes behind them. If the check fails the saved copy stays
and the dashboard says how old it is.

**Language.** English and Nepali, switchable in Settings without a restart —
covering navigation, Account, Settings and the phase 6 screens. The rest of the
app is still English (`KNOWN_ISSUES.md` P6-1).

**For doctors.** A separate three-tab shell: the appointment inbox, on the route
that actually works for a doctor, a weekly availability editor with slot length
and a pause switch per window, and an Account holding registration and settings.
Registration explains the two steps only an operator can do rather than offering
buttons that cannot work.

There is no mock data anywhere in this app, by design.

Known gaps are in `KNOWN_ISSUES.md`. The five that matter most today: a doctor's
inbox can never show a request to accept, because the server confirms bookings
on their behalf (P5-1); two patients tapping the same slot at the same moment
both get it (P5-2); reminders live on one phone and never reach a caretaker
(P6-2); a dose marked taken does not survive a restart (P4-1); and **nothing in
this app has been run on a real device since phase 3** — which now includes the
map, the GPS, the notifications and the microphone (P4-2, P5-8, P6-11).

## iOS parity

Only Android is runnable on this machine (Xcode is incomplete), so everything
below is configured and reasoned about but **never executed**. First real iOS
build should check them in order:

| Configured | Where | Never verified |
|---|---|---|
| `NSAllowsLocalNetworking` for local dev over http | `ios/Runner/Info.plist` | that a simulator reaches `127.0.0.1:3001` |
| Keychain storage, `first_unlock_this_device`, no iCloud copy | `lib/core/storage/session_store.dart` | that the token survives a relaunch on iOS |
| Cupertino page transitions on iOS | `lib/core/theme/app_theme.dart` | how the back-swipe feels with the shell |
| Display name `Ayuvo` | `ios/Runner/Info.plist` | the home-screen label |
| `NSCameraUsageDescription` — photographing a printed report | `ios/Runner/Info.plist` | that the prompt appears and the wording reads sensibly |
| `NSPhotoLibraryUsageDescription` — choosing an existing scan | `ios/Runner/Info.plist` | the same, plus that `file_picker` reaches iCloud Drive |
| `Printing.sharePdf` for the formal report | `digital_report_screen.dart` | the iOS share sheet at all — this has never been opened on either platform |
| `NSLocationWhenInUseUsageDescription` — the nearby map | `ios/Runner/Info.plist` | that the prompt appears, and that a refusal really does fall back to Kathmandu rather than hanging |
| `NSMicrophoneUsageDescription` + `NSSpeechRecognitionUsageDescription` — voice input | `ios/Runner/Info.plist` | that iOS asks for **both**, and that `speech_to_text` reports unavailable rather than throwing when either is refused |
| `LSApplicationQueriesSchemes` — `tel`, `maps`, `comgooglemaps` | `ios/Runner/Info.plist` | that `canLaunchUrl` returns true for an emergency contact's number. Without the entry iOS answers false and the tap silently does nothing |
| Darwin notification settings, permission requested on demand not at launch | `lib/core/notifications/reminders.dart` | that a reminder actually fires, and that `requestPermissions` is reached from the settings switch rather than on first run |
| Named-timezone scheduling via `flutter_timezone` | same | that the identifier iOS returns is one the `timezone` database knows |

**Android is no better verified for phase 6.** The manifest gained
`POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, both location permissions,
`RECORD_AUDIO`, the two `flutter_local_notifications` receivers and `<queries>`
entries for `tel:`/`https:`/speech; `build.gradle.kts` gained core-library
desugaring, which that plugin requires. None of it has been run. See
`KNOWN_ISSUES.md` P6-11.
