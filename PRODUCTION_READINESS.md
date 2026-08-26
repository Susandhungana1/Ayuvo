# Production Readiness Audit — Ayuvo

Last reviewed: 2026-08-20. This file tracks what used to be blockers; the
sections below reflect the *current* state of each platform.

## Web Frontend (Vercel)

### RESOLVED (previously blockers)

| # | Issue | Status |
|---|-------|--------|
| 1 | **9 security vulnerabilities** (Next.js 16.2.1 SSRF/DoS/cache-confusion CVEs) | Fixed — deps upgraded (see commit "Security: upgrade vulnerable deps"); `npm audit` clean |
| 2 | **No `.env.example`** | Fixed — `front/.env.example` exists with `NEXT_PUBLIC_API_URL` |
| 3 | **No `robots.txt`** | Fixed — `front/public/robots.txt` exists |
| 4 | **No `sitemap.xml`** | Fixed — `front/public/sitemap.xml` exists |
| 5 | **No Open Graph / Twitter metadata** | Fixed — `front/app/layout.tsx` exports `openGraph` + `twitter` metadata |
| 6 | **No `engines` field** | Fixed — `package.json` pins `"node": ">=18"` |

### RESOLVED (previously should-fix)

| # | Issue | Status |
|---|-------|--------|
| 7 | **No Content-Security-Policy** | Fixed — nonce-based CSP added via `front/middleware.ts` (applied in production; `next dev` is skipped so HMR is unaffected) |

### ALREADY GOOD

- TypeScript compiles with zero errors
- No hardcoded secrets
- Service worker + PWA manifest + offline shell + push notifications
- All required icons (192, 512, maskable, apple-touch-icon)
- Single source for the API base URL (`lib/api.ts` exports `API_URL`; every page imports it — no more inline `process.env` copies)

---

## Mobile App (Play Store)

### RESOLVED (previously blockers)

| # | Issue | Status |
|---|-------|--------|
| 1 | **Release signed with debug key** | Fixed — `mobile/android/app/build.gradle.kts` defines a `release` signing config reading `key.properties`; the keystore + properties are local-only (gitignored), so CI/built release APKs are signed with the real key |
| 2 | **No adaptive icons** | Fixed — `mipmap-anydpi-v26/ic_launcher.xml` + `ic_launcher_round.xml` reference vector foreground (medical cross) and background (brand cyan) drawables |
| 5 | **No ProGuard keep rules** | Fixed — `proguard-rules.pro` keeps Flutter/notification/map classes; release build runs R8 (`isMinifyEnabled` + `isShrinkResources`) |

### STILL OPEN

| # | Issue | Fix |
|---|-------|-----|
| 3 | **`file_picker: ^12.0.0-beta.7`** — beta dependency in production | Upgrade to stable when available |

(The splash screen is already branded — cyan background + medical cross in
`launch_background.xml`.)

### ALREADY GOOD

- No hardcoded secrets or API keys
- API URL configurable via `--dart-define=API_BASE_URL=...` (single source in `lib/core/config/env.dart`)
- Cleartext traffic blocked in release builds
- All permissions justified
- No `print()` calls; fonts referenced correctly; application ID consistent

---

## Backend (Render)

### ALREADY GOOD

- All tests pass (218 tests on SQLite in CI)
- Soft-deleted medicines filtered in all endpoints
- JWT auth + refresh rotation + 2FA (TOTP) endpoints
- Feature flags visible at `/health`
- Hardening headers + rate limiting + audit log + storage off-Postgres

### MONITORING (RESOLVED)

- Automated **uptime alert** — `.github/workflows/uptime-alert.yml` checks
  `/health` every 15 min and opens a GitHub issue on failure (covers DB-down
  and misconfigured deploys, not just "server is up").
- **Automated restore test** — `.github/workflows/restore-test.yml` runs after
  every successful backup, decrypts and restores the dump into a throwaway
  Postgres on the runner and sanity-checks the app tables, opening an issue on
  failure.
- Sentry wired (DSN must still be set in the deployed environment).

---

## Remaining before launch

1. **Verify the two new workflows run** — trigger the restore test manually
   (`workflow_dispatch`) after the next backup and confirm it passes.
2. **Set `SENTRY_DSN`** in the Render environment.
3. **Confirm the CSP works on the deployed site** — load a logged-in page in a
   browser and check the console for CSP violations (nothing should appear).
4. **Set a branded mobile splash** — already branded (cyan + cross); polish
   pass only.