# MediStore — mobile

The Flutter client for MediStore, replacing the Next.js UI in `../front`. The
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

Generated files are committed, so a fresh clone builds without running it.

## Layout

```
lib/
  core/
    config/     Env — the API base URL and the web app's, nothing else
    network/    ApiClient (bearer, 401, form login), ApiException, ScopedUrl
    session/    who is signed in; restore, sign out, seven-day expiry
    storage/    the keystore wrapper the token lives in
    health/     GET /health, including the caretaker feature flag
    router/     go_router: auth-aware redirect, role-aware shells
    theme/      the design system — the only file with a raw colour in it
    widgets/    RangeBar, StatusChip, CardHeader, LinkCard/QrPanel,
                FormSheet, Skeleton, EmptyState, ErrorView
  features/<feature>/{data,domain,presentation}
  dev/          the design gallery (not part of the app)
```

Two rules that are load-bearing rather than stylistic:

- **`ScopedUrl` is the only thing that may build a patient-scoped URL.** Ids
  contain `#`; interpolated raw, the id vanishes and the server quietly returns
  the *caller's* records. Tested in `test/scoped_url_test.dart`.
- **Caretaker scope is medicines-only.** Never render vitals, reports,
  documents or the assistant in a caretaker context.
- **A `Row` does not clip an oversized child, it overflows.** Any header that
  pairs text with a badge goes through `CardHeader`, which caps the badge at
  half the line so neither side can run off the screen at large text sizes.
  Six of these were shipped broken and caught by `phase5_text_scale_test.dart`.

## What works today (end of phase 5)

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

**For doctors.** A separate two-tab shell: the appointment inbox, on the route
that actually works for a doctor, and a weekly availability editor with slot
length and a pause switch per window. Plus registration, which explains the two
steps only an operator can do rather than offering buttons that cannot work.

Timeline, search, the assistant, nearby care and caretakers are not built yet.
There is no mock data anywhere in this app, by design.

Known gaps are in `KNOWN_ISSUES.md`. The four that matter most today: a doctor's
inbox can never show a request to accept, because the server confirms bookings
on their behalf (P5-1); two patients tapping the same slot at the same moment
both get it (P5-2); a dose marked taken does not survive a restart (P4-1); and
nothing in this app has been run on a real device since phase 3 (P4-2, P5-8).

## iOS parity

Only Android is runnable on this machine (Xcode is incomplete), so everything
below is configured and reasoned about but **never executed**. First real iOS
build should check them in order:

| Configured | Where | Never verified |
|---|---|---|
| `NSAllowsLocalNetworking` for local dev over http | `ios/Runner/Info.plist` | that a simulator reaches `127.0.0.1:3001` |
| Keychain storage, `first_unlock_this_device`, no iCloud copy | `lib/core/storage/session_store.dart` | that the token survives a relaunch on iOS |
| Cupertino page transitions on iOS | `lib/core/theme/app_theme.dart` | how the back-swipe feels with the shell |
| Display name `MediStore` | `ios/Runner/Info.plist` | the home-screen label |
| `NSCameraUsageDescription` — photographing a printed report | `ios/Runner/Info.plist` | that the prompt appears and the wording reads sensibly |
| `NSPhotoLibraryUsageDescription` — choosing an existing scan | `ios/Runner/Info.plist` | the same, plus that `file_picker` reaches iCloud Drive |
| `Printing.sharePdf` for the formal report | `digital_report_screen.dart` | the iOS share sheet at all — this has never been opened on either platform |

Local notifications arrive with reminders in phase 6; the key goes in with the
feature and gets a row here.
