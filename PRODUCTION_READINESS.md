# Production Readiness Audit — MediStore

## Web Frontend (Vercel)

### BLOCKERS

| # | Issue | File | Fix |
|---|-------|------|-----|
| 1 | **9 security vulnerabilities** (1 critical, 6 high) — Next.js 16.2.1 has SSRF, DoS, cache confusion CVEs | `front/package.json` | Run `cd front && npm audit fix --force` to upgrade Next.js to 16.3.1+ |
| 2 | **No `.env` or `.env.example`** — app silently falls back to `http://127.0.0.1:3001` if `NEXT_PUBLIC_API_URL` is missing | `front/` | Create `front/.env.example` with `NEXT_PUBLIC_API_URL=` |
| 3 | **No `robots.txt`** — search engines will index all routes including sensitive ones | `front/public/` | Add `front/public/robots.txt` |
| 4 | **No `sitemap.xml`** — no SEO crawl structure | `front/public/` | Add `front/public/sitemap.xml` |

### SHOULD FIX

| # | Issue | File | Fix |
|---|-------|------|-----|
| 5 | **No Open Graph / Twitter card metadata** — social sharing shows no preview | `front/app/layout.tsx` | Add `openGraph` and `twitter` to `metadata` export |
| 6 | **No `engines` field** in package.json — Node version not pinned | `front/package.json` | Add `"engines": { "node": ">=18" }` |
| 7 | **28 `console.error` calls** — acceptable but noisy in production | Various pages | Consider a logger abstraction that strips in production |

### ALREADY GOOD

- TypeScript compiles with zero errors
- Build produces 33 pages successfully
- No hardcoded secrets
- No `console.log` statements
- Service worker properly configured (offline support, push notifications)
- PWA manifest generated from `app/manifest.ts`
- All required icons exist (192, 512, maskable, apple-touch-icon)
- `offline.html` exists
- No TODO/FIXME/HACK comments

---

## Mobile App (Play Store)

### BLOCKERS

| # | Issue | File | Fix |
|---|-------|------|-----|
| 1 | **Release signed with debug key** — Play Store will reject | `mobile/android/app/build.gradle.kts:37` | Create a release keystore, add `signingConfigs` block, use it for release builds. See [Android signing guide](https://developer.android.com/studio/publish/app-signing#sign-up) |
| 2 | **No adaptive icons** — no `mipmap-anydpi-v26/` directory. Play Store requires adaptive icons for Android 8+ | `mobile/android/app/src/main/res/` | Generate `ic_launcher_foreground.png` + `ic_launcher_background.png` + XML definitions in `mipmap-anydpi-v26/` |

### SHOULD FIX

| # | Issue | File | Fix |
|---|-------|------|-----|
| 3 | **Default white splash screen** — no branding | `mobile/android/app/src/main/res/drawable/launch_background.xml` | Add `flutter_native_splash` package or custom drawable with MediStore logo |
| 4 | **`file_picker: ^12.0.0-beta.7`** — beta dependency in production | `mobile/pubspec.yaml:46` | Upgrade to stable release when available, or pin with known-good version |
| 5 | **No ProGuard keep rules** — third-party libs may break if R8 strips needed classes | `mobile/android/app/` | Add `proguard-rules.pro` with keep rules for packages like `com.google.android.gms`, `io.flutter.embedding` |

### ALREADY GOOD

- No hardcoded secrets or API keys
- API URL configurable via `--dart-define=API_BASE_URL=...`
- Cleartext traffic blocked in release builds (only allowed in debug)
- All permissions justified (INTERNET, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, LOCATION)
- No `print()` calls — all use `debugPrint` (stripped in release)
- No TODO/FIXME in Dart code
- Font assets all present and correctly referenced
- Application ID consistent across all configs (`com.medistore.medistore`)

---

## Backend (Render)

### ALREADY GOOD

- All 218 tests pass
- Soft-deleted medicines filtered in all endpoints
- Share endpoints now filter `deleted_at IS NULL`
- JWT auth properly implemented
- Feature flags visible at `/health`

### MONITORING

- No automated health check alerts configured
- No error tracking (Sentry, etc.) — recommend adding for production

---

## Quick Fix Commands

```bash
# 1. Fix frontend vulnerabilities
cd front && npm audit fix --force

# 2. Create .env.example
echo "NEXT_PUBLIC_API_URL=" > front/.env.example

# 3. Add robots.txt
cat > front/public/robots.txt << 'EOF'
User-agent: *
Allow: /
Disallow: /api/
Disallow: /auth/
EOF

# 4. Mobile: Generate release keystore
keytool -genkey -v -keystore ~/medistore-release.keystore \
  -alias medistore -keyalg RSA -keysize 2048 -validity 10000
```

---

## Priority Order

1. **Mobile: Create release signing keystore** — blocker for Play Store
2. **Mobile: Generate adaptive icons** — blocker for Play Store
3. **Frontend: `npm audit fix`** — security vulnerabilities
4. **Frontend: Add `robots.txt`** — prevent indexing of sensitive routes
5. **Frontend: Add Open Graph metadata** — social sharing previews
6. **Mobile: Custom splash screen** — branding
7. **Frontend: Add `sitemap.xml`** — SEO
