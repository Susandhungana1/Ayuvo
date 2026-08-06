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

`API_BASE_URL` is the only build-time setting. Left unset it picks the local
dev server, and on Android that means `http://10.0.2.2:3001` — the emulator's
alias for your machine, not `127.0.0.1`, which on a phone means the phone. See
`lib/core/config/env.dart`.

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
    config/     Env — the API base URL, and nothing else
    network/    ApiClient (bearer, 401, form login), ApiException, ScopedUrl
    session/    who is signed in; restore, sign out, seven-day expiry
    storage/    the keystore wrapper the token lives in
    health/     GET /health, including the caretaker feature flag
    router/     go_router: auth-aware redirect, role-aware shells
    theme/      the design system — the only file with a raw colour in it
    widgets/    RangeBar, StatusChip, Skeleton, EmptyState, ErrorView
  features/<feature>/{data,domain,presentation}
  dev/          the design gallery (not part of the app)
```

Two rules that are load-bearing rather than stylistic:

- **`ScopedUrl` is the only thing that may build a patient-scoped URL.** Ids
  contain `#`; interpolated raw, the id vanishes and the server quietly returns
  the *caller's* records. Tested in `test/scoped_url_test.dart`.
- **Caretaker scope is medicines-only.** Never render vitals, reports,
  documents or the assistant in a caretaker context.

## What works today (end of phase 3)

Sign in, sign out, register, the two-factor challenge, forgot/reset password,
session restore across launches, and a 401 anywhere ending the session with a
reason. Home shows the signed-in account and whether the configured backend is
answering.

Medicines, vitals, reports, documents, appointments and the rest are navigable
but say plainly which phase builds them. There is no mock data anywhere in this
app, by design.

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

Coming phases add camera (`NSCameraUsageDescription`), photo library and file
access (`NSPhotoLibraryUsageDescription`), and local notifications — each key
goes in with the feature that needs it, and gets a row here.
