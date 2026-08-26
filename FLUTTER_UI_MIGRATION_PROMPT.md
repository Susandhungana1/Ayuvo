# Master Prompt — Rebuild the Ayuvo UI as a Flutter mobile app

> Paste everything below the line into a fresh agent session opened at the repo root
> (`/Users/susandhungana/Desktop/Projects/finalyear`).

---

## Role

You are building a new **Flutter mobile app** (`mobile/`) that replaces the existing
Next.js web UI (`front/`) for Ayuvo, a personal digital health record app. The
Python/FastAPI backend in `server/` already works, is deployed, and holds real user
data. Your job is UI + client only.

## Hard constraints — read these twice

1. **The backend may be changed, but only additively, only when it makes the mobile
   app materially better, and only in phase 7 with my written approval.** Phases 1–6
   run with `server/` frozen. The full protocol is in *Changing the backend safely*
   below — read it before you touch a single file there. The governing rule: the
   deployed Next.js app and every existing client must keep working, unchanged,
   against your modified backend.
2. **Do not delete or break `front/`.** It stays deployed, still calls these
   endpoints, and still serves things the mobile app cannot (see *Scope boundary*).
   Build the app alongside it, in a new `mobile/` directory.
3. **No mock data.** `front/constants/index.ts` is full of `MOCK_REPORTS`,
   `MOCK_USERS`, `MOCK_BLOG_POSTS` — that is not a pattern to copy. Every screen binds
   to a real endpoint or shows a real empty state.
4. Never hardcode tokens, API keys, or a user's data. The API base URL comes from
   `--dart-define`, defaulting to local dev.
5. **Local only. Nothing reaches production without my explicit say-so.** Do not push,
   do not merge, do not open a PR, do not deploy, and do not run any migration or
   script against the production database or Render — not even a "safe" or `--dry-run`
   one. Commit locally on a feature branch if you like; publishing is my call alone.
   Where this document describes the production migration and Render env-var steps,
   those are instructions for *me* to run later — write them into your report, do not
   execute them. Develop against local Postgres and `http://127.0.0.1:3001` only.
6. Never weaken the security posture to make a screen easier: caretaker authorization
   stays in the one chokepoint (`resolve_medicine_scope` in `server/app/core/care.py`),
   `patient_id` is still read from the query string only, medicine deletes stay soft,
   and Sentry keeps `send_default_pii=False`.

## Scope boundary — what stays on the web

Some pages are public URLs opened by people who do not have the app installed. These
**stay in the Next.js app** and are out of scope:

- `front/app/share/[token]` — a doctor opens a shared report link in a browser.
- `front/app/emergency/id/[userId]` — scanned from a QR code by a stranger/paramedic.
- `front/app/auth/reset-password` — the target of the password-reset email
  (`settings.frontend_url` is baked into the mail body by `server/app/api/auth.py`).
- Marketing pages: `about`, `contact`, `blog`.

The Flutter app **creates and manages** share links and the emergency profile, and
shows/copies the resulting URL — a browser page is the right medium for a recipient
who does not have the app, and no backend change makes that untrue.

Password reset already works without any change: the mail contains both a link and the
raw code, and `POST /api/auth/reset-password` accepts a pasted token, so the app just
needs a "paste your code" screen. Adding App Links / Universal Links so the emailed
link opens the app when installed is a legitimate improvement — but it must keep
working in a plain browser for everyone else, so the web page stays and the link
format does not change.

## The backend, precisely

Base URLs:
- local: `http://127.0.0.1:3001` (run: `cd server && python -m uvicorn main:app --reload --port 3001`)
- prod: `https://medistore-api-vwyr.onrender.com` (this hostname is *not* derivable
  from `render.yaml`; do not "fix" it)
- Android emulator reaches local host as `http://10.0.2.2:3001`.

### Auth
- `POST /api/auth/register` — **JSON** `{name, email, password}` (password ≥ 8) →
  `{id, name, email, role, token}`.
- `POST /api/auth/login` — **OAuth2 form-encoded**, not JSON:
  `username=<email>&password=<pw>`, and when 2FA is on, the 6-digit TOTP code goes in
  the **`client_secret`** field. A 401 carrying header `X-2FA-Required: true` means
  "prompt for the code and resubmit". Rate limited 10/min. Smuggling a TOTP code
  through `client_secret` is ugly; a JSON login route with a proper `totp_code` field
  is a fair addition — but the form-encoded route stays exactly as it is, because
  `front/` and FastAPI's `OAuth2PasswordBearer(tokenUrl=...)` both depend on it.
- Token is a 7-day HS256 JWT, sent as `Authorization: Bearer <token>`. There is no
  refresh token: after seven days the user is signed out. Adding refresh is a
  reasonable proposal (put it in `BACKEND_NOTES.md`); until it is approved, handle
  expiry gracefully rather than working around it.
- `GET /api/auth/me`, and 2FA at `/api/auth/2fa/{status,setup,verify,disable}`
  (`setup` returns `secret`, `otpauth_url`, `qr_code_data_uri`).
- `POST /api/auth/forgot-password` (3/min) and `POST /api/auth/reset-password`.
- A 401 on any call means the session is dead → clear storage, route to sign-in with a
  message. Never leave the user on a dead screen.

### Route map (prefix → paths)
- `/api/users` — `GET /me`, `PUT /me`
- `/api/documents` — `POST ""`, `GET ""`, `GET /{id}`, `DELETE /{id}`,
  `POST|GET /{id}/files`, `GET /{id}/files/{file_id}`
- `/api/reports` — `POST ""`, `GET ""`, `GET /ai-summary`, `GET /trends`,
  `GET|DELETE /{id}`, `GET /{id}/file`, `GET /{id}/ai-report`,
  `GET /{id}/lab-analysis`, `POST /{id}/explain`
- `/api/appointments` — `POST ""`, `GET ""`, `PUT /{id}`, `PATCH /{id}/status`,
  `DELETE /{id}`, `GET /available-slots/{doctor_id}?date=YYYY-MM-DD`,
  `GET /doctor/my-appointments`
- `/api/doctors` — `POST|GET /doctors`, `GET /doctors/me`, `POST|GET /availability`,
  `GET /availability/{doctor_id}`, `PUT|DELETE /availability/{avail_id}`
- `/api/medicines` — `GET ""`, `POST ""`, `PUT|DELETE /{id}`, `POST /{id}/restore`,
  `POST /{id}/intake`, `GET /intake/log`, `GET /interactions`, `GET /audit`
- `/api/vitals` — `GET ""`, `POST ""`, `DELETE /{id}`
- `/api/emergency` — `GET|PUT /profile`, `POST /contacts`, `DELETE /contacts/{id}`,
  `GET /public/{user_id}`
- `/api/share` — `GET ""`, `POST /{report_id}`, `GET|DELETE /{token}`,
  `POST /qr-code`, `GET /qr-code/{token}`, plus `/{token}/ai-report`,
  `/{token}/lab-analysis`, `/{token}/explain`
- `/api/care` — `POST /invites`, `POST /invites/redeem`, `GET /links`,
  `PATCH|DELETE /links/{link_id}`
- `/api/timeline` — `GET ""`; `/api/search` — `GET ""`; `/api/chatbot` — `POST ""`
- `/api/push` — web-push only; see *Notifications*
- `GET /health` — returns `{status, database, email, caretaker}`; the `caretaker` flag
  tells you whether `/api/care/*` is live. Check it at startup and hide the caretaker
  UI when it is `false` (it returns 404 when disabled).

Read the router file before wiring each feature — `server/app/api/<name>.py` is the
contract. Do not guess field names; the Pydantic response models are right there. When
you extend one, extend it: new optional fields and new routes, never a changed shape.

### Two traps that will silently corrupt behaviour

1. **User ids contain `#`** (e.g. `#hos014`). Interpolated raw into a URL, `#` starts
   the fragment, the `patient_id` query param arrives empty, and the server quietly
   scopes the request to the *caller's own* records — a caretaker's edit lands on their
   own medicine list. Always percent-encode: `Uri.encodeQueryComponent(patientId)`, or
   build with `Uri(queryParameters: {...})`. Mirror the single-chokepoint discipline of
   `front/lib/care.ts` (`scopedUrl`) — one function builds every patient-scoped URL,
   nothing else.
2. **Caretaker scope is medicines-only.** A care link grants medicine read/write and
   reminders for that patient — nothing else. Never render vitals, reports, documents,
   or the AI chat inside a caretaker context.

### Files and images need the auth header
Report files (`GET /api/reports/{id}/file`) and document attachments are BLOBs served
behind auth. `Image.network` will 401 — fetch bytes through the authenticated HTTP
client and render with `Image.memory`, or pass explicit headers. Same for PDF preview
and download/share.

## Changing the backend safely

Backend changes are permitted where they clearly improve the mobile app. They are not
permitted as a shortcut around a client-side problem you have not tried to solve. The
test for every proposed change: *does this make the product better, and can the
existing web app keep running against it with zero edits?*

**Timing is part of the protocol.** This section governs phase 7 only. Through phases
1–6 the rules below still tell you what will eventually be acceptable — use them to
write good proposals into `BACKEND_NOTES.md` — but you implement none of it until the
app works and I have approved the list.

### Allowed (additive)
- **New endpoints** alongside existing ones — e.g. a JSON `POST /api/auth/login/json`
  that wraps the same logic as the form-encoded one, a mobile-shaped dashboard
  aggregate that returns in one call what the dashboard currently assembles from five,
  or FCM device registration next to the existing web-push subscribe.
- **New optional query parameters** with defaults that reproduce today's behaviour
  exactly — pagination (`?limit=&cursor=`), field selection, `?since=` for delta sync.
  Omitting the parameter must return what it returns today.
- **New optional response fields.** Adding a key is safe; renaming, removing, retyping,
  or changing the meaning of an existing one is not.
- **New tables**, and **new nullable columns** on existing tables.
- **New settings/feature flags** in `server/app/core/config.py`, defaulting to the
  current behaviour (`False` / empty), surfaced in `/health` the way `caretaker` and
  `email` already are.
- **Performance and correctness fixes** that leave the contract identical: N+1 query
  removal, indexes, thumbnail generation, gzip, ETag/`Cache-Control` for offline sync,
  sensible rate-limit ceilings for a phone that legitimately retries.

### Forbidden
- Changing or removing an existing route, its request shape, its response shape, its
  status codes, or its auth requirements — `front/` calls all of these in production.
- Dropping columns or tables; non-nullable columns without a default; destructive
  backfills.
- Loosening auth, CORS beyond what's needed, or the caretaker scope rules.
- Editing the caretaker chokepoint's semantics, or comparing user ids by hand anywhere
  outside it.
- Putting health data or PII into logs, Sentry, error strings, or push payloads.

### Schema changes — the deploy order that is not optional
Startup runs `SQLModel.metadata.create_all()`, which **creates missing tables but
never adds columns to existing ones**. A new column that ships without a migration
makes every query touching it 500 in production.

1. Add the column to `server/app/models/models.py` **and** to the `_ADD_COLUMNS` list
   in `server/scripts/migrate_schema.py`. Keep that script idempotent — it uses
   `ADD COLUMN IF NOT EXISTS` and must stay safe to run twice.
2. Verify it **against your local database only** — dry-run, apply, run it twice to
   prove idempotency:
   ```bash
   cd server
   python -m scripts.migrate_schema --dry-run
   python -m scripts.migrate_schema
   ```
   The production run (`DATABASE_URL='<prod-url>' python -m scripts.migrate_schema`,
   dry-run first) **must happen before the code that reads the column ships** — but I
   run it, not you. Put the exact command in your report; do not execute it.
3. Deployment is mine to trigger. New behaviour lands behind a flag defaulting off, so
   that shipping the code and enabling it stay separate acts.
4. Write the rollback in the PR description: for additive changes it is "revert the
   code; the nullable column can stay".

### Environment variables — the trap that already bit this project
**Adding a variable to `render.yaml` does not create it on the running service.**
Render applies that file when the service is created from the blueprint, not on
subsequent pushes. Every new setting must *also* be added by hand in
Render → medistore-api → Environment, or the code deploys while the variable stays
absent and the app silently uses its default — which is how `CARETAKER_ENABLED` read
`false` in production for an hour while the blueprint said `"true"`. Surface every new
flag in `/health` so verifying it is one curl:
```bash
curl -s https://medistore-api-vwyr.onrender.com/health
```

### Tests and evidence for any backend change
- `server/tests/` already covers auth, care scope, care medicines, notifications, CORS,
  health, reports, OCR, email. Run the whole suite before and after:
  `cd server && python -m pytest -q`. A red test you did not make red is a stop sign.
- Every new endpoint ships with tests, including the authorization-failure path.
- Add a regression test proving the **old** call still behaves identically — that is
  the evidence that `front/` is unharmed.
- Before reporting done, run `git diff -- server/` and walk me through each hunk with
  its justification. Do not bury backend edits inside a "Flutter screens" commit; they
  go in their own commits with messages that say why.
- Smoke-test the deployed web app against the changed backend (login, dashboard,
  medicines, reports) and say in your report that you did.

Collect anything you *wanted* to change but decided against, plus anything still
awkward from the client side, in `mobile/BACKEND_NOTES.md` — proposal, rationale,
blast radius — so the calls stay visible rather than accumulating silently.

## Screens to build

Port every user-facing surface in `front/app/` (read each `page.tsx` for the real
behaviour before designing its replacement):

**Patient:** dashboard · medicines (+ intake logging, alarms, drug-interaction
warnings, soft-deleted/restore) · vitals (+ trends charts) · reports (upload, AI
summary, lab analysis, "explain this") · documents + attachments · appointments
(browse doctors → availability → slots → book) · timeline · search · emergency profile
& contacts + QR · share links · nearby (map) · AI chatbot · settings (profile, 2FA,
theme, language, caretakers)

**Doctor role:** doctor profile, availability editor, `doctor/appointments` inbox with
status changes. Role comes from the login response (`role`); gate navigation on it.

**Caretaker:** "people I care for" list, redeem invite code, per-patient medicine view
(`front/app/care/[patientId]`) — feature-flagged on `/health`.

## Platform equivalents for browser-only pieces

| Web now | Flutter |
|---|---|
| Web Push (VAPID, `/api/push/*`) | Start with `flutter_local_notifications` + timezone scheduling driven from the medicine schedule — it covers reminders without server work. The existing endpoints expect a *browser* subscription, so do not repurpose them: if you need server-driven delivery (caretaker fan-out, reminders that survive reinstall), add **new** FCM routes beside them and teach `server/app/core/reminder_scheduler.py` to fan out to both channels, behind a flag defaulting off, with `ReminderDelivery.channel` recording which was used. Never put medicine names or health details in a push payload. |
| PWA offline cache (`front/lib/offlineCache.ts`) | local cache (Hive/Drift/sqflite) with a stale-while-revalidate read path |
| Leaflet map (`nearby`) | `flutter_map` |
| jsPDF (`front/lib/reportPdf.ts`) | `pdf` + `printing` |
| `qrcode.react` | `qr_flutter` to render, `mobile_scanner` to redeem codes |
| Web Speech API (`useSpeechRecognition`) | `speech_to_text` |
| `front/lib/i18n.tsx` (`en` / `ne`) | `flutter_localizations` + ARB; carry over both languages and every existing string |
| localStorage `token` / `user` | `flutter_secure_storage` for the JWT; never SharedPreferences |

## Architecture

- Flutter 3.x, Dart 3, Material 3, null-safe, `flutter_lints` clean.
- State: **Riverpod** (v2, code-gen off unless you want it). One approach, used
  everywhere — no mixed Bloc/Provider/setState soup.
- Networking: **dio** with an auth interceptor (attach Bearer, catch 401 → sign out),
  a single `ApiClient`, and typed models via **freezed** + `json_serializable`. Every
  endpoint gets a repository method; widgets never build URLs.
- Routing: **go_router**, with an auth-aware redirect and a role-aware shell.
- Layout: feature-first — `lib/features/<feature>/{data,domain,presentation}`,
  shared bits in `lib/core/`.
- **Keep iOS parity even though you cannot build or test it.** Only Android is
  runnable on this machine (Xcode is incomplete), so iOS correctness has to come from
  discipline rather than verification. That means: choose plugins that support both
  platforms; declare every required `Info.plist` key as you add the feature that needs
  it — `NSCameraUsageDescription` (QR scanning), `NSPhotoLibraryUsageDescription` and
  file access (report/document upload), plus notification setup for
  `flutter_local_notifications`; request permissions through a cross-platform path
  rather than assuming Android's model; and never put Android-only code outside a
  `Platform.isAndroid` branch. Keep an `iOS parity` section in `mobile/README.md`
  listing what was configured but never executed, so the first real iOS build has a
  checklist instead of a surprise.
- Every async surface has three real states: loading (skeleton, not a bare spinner),
  empty (explains what to do next), error (says what failed and offers retry).

## Design direction

The current UI reads as sloppy and generic; the point of this rewrite is that it
should not. **Do not improvise a palette.** Stock Material 3 defaults with an invented
accent colour is the exact failure mode we are escaping — it is not sloppy, it is
anonymous, which is no better. Choose deliberately, from the design skills installed
on this machine, then write the choice down and build to it.

### The design pass — run this at phase 1.5, before any screen exists

Do this after recon and before the foundation phase. Retrofitting tokens across twenty
finished screens never fully happens; the theme must precede the widgets.

1. **`ui-ux-pro-max`** — the primary source. These flags are verified against the
   installed skill:
   ```bash
   S=~/.claude/skills/ui-ux-pro-max/scripts/search.py
   python3 $S "healthcare medical app" --domain color
   python3 $S "health tracking mobile" --domain style
   python3 $S "medical dashboard" --domain typography
   python3 $S "patient records mobile app" --domain product
   # full system, written to a file you can iterate on:
   python3 $S "calm trustworthy healthcare mobile app" --design-system \
     --project-name Ayuvo --format markdown --persist --output-dir mobile/
   ```
   `--variance`, `--motion` and `--density` (1–10) tune the generated system; state
   the values you chose and why. The output is CSS variables and Markdown, so
   **translate it by hand** into a single Flutter `AppTheme`: a seeded `ColorScheme`
   for light *and* dark, `TextTheme`, and a `ThemeExtension` for anything M3 has no
   slot for. Record the token mapping in `DESIGN.md` so CSS names and Dart names stay
   reconcilable.
2. **The Flutter guideline set in that same skill** — 52 rules across Widgets, State,
   Layout, Lists, Navigation, Async, Theming, Animation, Forms, Performance,
   Accessibility, each with a good/bad code example and a severity. Query it by
   category, and use it as the review checklist at the end of *every* phase:
   ```bash
   python3 $S "theming" --stack flutter
   python3 $S "state management" --stack flutter
   python3 $S "lists performance" --stack flutter
   ```
3. **`frontend-design`** — aesthetic direction, so the result reads as chosen rather
   than templated.
4. **`design-system`** — three-layer tokens (primitive → semantic → component). Map the
   component layer onto Flutter component themes (`CardTheme`, `FilledButtonThemeData`,
   `InputDecorationTheme`), not onto per-widget constructor arguments.
5. **`dataviz`** — read before writing a single chart for vitals trends or report
   analytics. It is medium-agnostic, so apply its rules through `fl_chart`.
6. **`design`** — at phase 6 only: app icon, splash, Play Store graphics.
7. **Do not invoke `ui-styling`.** It is shadcn/Radix/Tailwind — web only, and
   irrelevant to Dart.

Optionally, before committing to a direction, mock the three highest-stakes screens
(dashboard, medicines, report detail) as HTML to compare looks quickly. Treat those as
a look-and-feel decision only — HTML's layout model is not Flutter's, and a mockup
that reads well can be awkward as widgets. Never translate one literally.

### The deliverable

`mobile/DESIGN.md`: the chosen palette (light + dark, with contrast ratios checked),
type scale, 4pt spacing scale, elevation/radius rules, motion durations, and the
component inventory (cards, list rows, chips, sheets, empty states, skeletons). Then
build to it — no ad-hoc padding numbers and no raw hex in widget files, ever.

Aim for a calm, legible health app: generous spacing, one accent colour used
sparingly, data-dense screens (vitals, medicines) that stay scannable, thumb-reachable
primary actions, bottom navigation for the 4–5 core destinations, everything else
behind a profile/settings route. Respect system dark mode and text scaling.

## Phases — stop and report at each checkpoint

1. **Recon.** Read `AGENTS.md`, `RUN.md`, every `server/app/api/*.py`, and each
   `front/app/**/page.tsx`. Produce `mobile/FEATURE_MAP.md`: every screen → endpoints
   it calls → fields it shows. Start `mobile/BACKEND_NOTES.md` as a **deferred** list —
   record backend changes worth making, but implement none of them yet. Checkpoint:
   show me the feature map before writing code.
2. **Design pass (1.5).** Run the design pipeline above; deliver `mobile/DESIGN.md`
   and the `AppTheme` translation. Checkpoint: I approve the direction before screens
   are built.
3. **Foundation.** Scaffold `mobile/`, apply the theme, ApiClient + interceptor, secure
   storage, go_router, auth flow (register, login, 2FA challenge, forgot/reset,
   logout). Checkpoint: I can sign in against local backend on a real device/emulator.
4. **Core patient features.** Dashboard, medicines + intake, vitals + trends, reports,
   documents.
5. **Scheduling & sharing.** Appointments, doctor availability, doctor role screens,
   share links, emergency profile + QR.
6. **Extras.** Timeline, search, chatbot, nearby map, caretaker flows (flag-gated),
   local notifications, offline cache, i18n en/ne.
7. **Backend pass — the only phase that may touch `server/`.** By now you have a
   working app and evidence instead of predictions. Bring me the finished
   `BACKEND_NOTES.md`: each proposal with rationale, blast radius, migration need, and
   whether `front/` is affected. **I approve the list before you implement any of it.**
   Then implement only what I approved, under the protocol above, in its own commits
   with its own tests. Anything unapproved stays client-side.
8. **Polish & handover.** Empty/error states, accessibility pass, `mobile/README.md`
   (run instructions, dart-defines, build commands), and a final `BACKEND_NOTES.md`
   recording what shipped, what was rejected, and the migration/env steps an operator
   must perform.

**Phases 1–6 run with the backend frozen.** At every checkpoint in that range,
`git diff --stat -- server/` must be empty, and you state that it is. This is
deliberate: it forces each problem to be attempted client-side first, so the phase-7
list contains changes you proved you need rather than changes that looked convenient
on day one. Nothing in phases 1–6 is blocked by the freeze — reminders work through
`flutter_local_notifications`, and a 7-day session expiry is handled gracefully rather
than refreshed.

If something genuinely cannot be built client-side, do not stall and do not
improvise: build everything around it, record the blocker in `BACKEND_NOTES.md`, and
raise it with me immediately rather than waiting for phase 7.

## Verification — evidence, not assertions

- Run against the local backend with a real account you register yourself. For each
  screen: load, create, edit, delete, and the 401 path.
- `flutter analyze` clean; widget tests for auth flow and at least one data-bound
  screen; unit tests for the scoped-URL builder proving `#hos014` survives encoding.
- Screens match `DESIGN.md`: no raw hex, no ad-hoc padding, dark mode verified, and a
  pass against `data/stacks/flutter.csv` at the end of each phase.
- `cd server && python -m pytest -q` green — the whole suite, not the files you
  touched. Run it in phases 1–6 too: it is how you prove the freeze held.
- `git diff -- server/` reported at every checkpoint — empty through phase 6, and from
  phase 7 walked hunk by hunk with each change justified.
- The **local** web app (`cd front && npm run dev`, port 3000) still works against your
  changed local backend: sign in, dashboard, medicines, reports. State that you
  checked. This is the regression test that protects production without touching it.
- `curl -s http://127.0.0.1:3001/health` shows every new flag reading what you expect,
  and the report lists — as instructions for me, not actions you took — the env vars to
  add **by hand in the Render dashboard** and the migration to run **before** deploy.
- Report honestly: what works, what is stubbed, what failed. If a screen is
  incomplete, say so plainly rather than reporting the phase done.

## Environment notes

- Local DB is now local Postgres; `server/.env` has the prod URL commented beneath it.
  Do not point local dev at prod data — and never run a migration against prod as a
  test.
- `SQLModel.metadata.create_all()` never adds columns to an existing table. Every new
  column goes through `scripts/migrate_schema.py`, applied to production before the
  code that reads it ships.
- Mobile clients send no `Origin` header, so CORS does not apply to them. You should
  not need to touch `CORSMiddleware` or `VERCEL_ORIGIN_REGEX` in `server/main.py`; if
  you think you do, you have a different bug.
- slowapi rate limits are per-route (`5/minute` register, `10/minute` login,
  `3/minute` forgot-password). A mobile retry/refresh loop can trip these — fix the
  client's retry behaviour first, and only raise a ceiling with a reason.
