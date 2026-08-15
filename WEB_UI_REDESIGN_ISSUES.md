# MediStore Web Redesign — Known Issues & Blockers

Open issues found during the redesign (WEB_UI_REDESIGN_PROMPT.md). Anything
unfixable or deferred goes here, with the reason. This file is honest reporting,
not a defect backlog for the product.

## 1. Backend pytest suite cannot run on this machine (BLOCKER — verification only)

- Symptom: `python -m pytest -q` → `No module named pytest`. Installing
  `server/requirements.txt` fails on `psycopg2-binary` (no Python 3.14 wheel) and
  `pydantic-core` (Rust build fails with the 3.14 toolchain).
- Environment: Windows, only Python 3.14 at `C:\Python314`, no venv, no other
  interpreter available.
- Impact: the redesign's verification contract ("`cd server && python -m pytest -q`
  green at every checkpoint") cannot be executed here. The backend is treated as
  frozen and its health is proven by:
  - `git diff --stat -- server/` empty at every checkpoint, and
  - code review of any interaction (none expected — the frontend only consumes the
    existing API surface).
- Resolution: the user runs the suite once on a Python 3.12/3.13 machine before
  anything ships. Until then this stays open.

## 2. Protected-file hash baseline

- The 13 protected files are hashed (SHA-256) in `front/WEB_UI_AUDIT.md` §3.
  Baseline taken 2026-08-14 on branch `share-claims-and-reminder-perf`, clean
  working tree. The 14th protected path, `front/app/api/share/route.ts`, has no
  hash row — it is verified via `git status` instead (still clean).
- If any checkpoint diff shows a changed hash, stop and investigate before
  proceeding (possible accidental edit, or a legitimately approved change).

## 3. Share reader deploy source — resolved, not an issue

- Verified the deployed reader (medistore-share-beige.vercel.app) is a **Flutter
  web build**, not Next.js. `globals.css` changes are safe for it. (Full finding in
  WEB_UI_AUDIT.md §1.) The `front/app/share/**` freeze still stands as the
  contractual invariant.

## 4. Deferred surfaces (expected)

- The 3 share reader pages and their transitive imports stay byte-identical; any
  visual inconsistency between the reader and the redesigned app is intentional
  and out of scope.
- `components/medicine-alarm.tsx` and `components/pwa-register.tsx` render
  nothing visible; no visual pass needed.

## 5. Lint baseline was already broken (Phase 2 finding)

- `cd front && npm run lint` reports **62 errors + 15 warnings** on the *untouched*
  baseline (2026-08-14, clean tree). The bulk are the newer React Compiler-era
  rules from `eslint-config-next` (16.x): `react-hooks/set-state-in-effect`
  (~25), `react-hooks/immutability` (~10), `@typescript-eslint/no-explicit-any`
  (~10), `react/no-unescaped-entities` (~6), plus `react-hooks/refs`.
- They exist in files this task has never touched — including the **frozen**
  share pages (`share/[token]`, `share/page`, `share/qr-code/[token]`,
  `DigitizedReport.tsx`).
- Consequence: "npm run lint clean" (Phase 7 contract) is **unachievable without
  touching frozen files**. Plan:
  - Every non-frozen file gets its errors fixed as its page migrates (Phase 3→6).
  - Frozen files keep their pre-existing errors, byte-identical. If a clean
    `npm run lint` is required for the deploy pipeline, the config must
    explicitly `ignore` the frozen paths (user decision) — or the rule set must
    be relaxed repo-wide (not this task's call).
- New Phase 2 code (`components/ui/*`, navbar, footer, ChatBot, blog-card,
  globals.css, layout) introduced **zero** new lint errors; build is green.

## 6. Candidates flagged during audit (decide, don't silently keep)

- `components/FormalReportView.tsx` — orphaned (no importer). **RESOLVED: deleted
  in Phase 6** (no importers; build confirmed).
- `constants/index.ts` — `MOCK_REPORTS`, `MOCK_USERS` unused. **RESOLVED: deleted
  in Phase 6** (no importers repo-wide; build confirmed). `MOCK_BLOG_POSTS` stays
  (used by blog).
- `front/app/api/share/route.ts` — legacy relative proxy; the app now prefixes
  `API_URL` directly in `lib/shares.ts`. **OPEN (user decision):** keeping it
  frozen (share surface); flag to user as removable if the reader no longer
  needs it.

## 7. Dead UI removed in Phase 3 (resolved, recorded)

- `app/contact/page.tsx` had a "Send Message" form whose submit button was
  `type="button"` with no handler — dead UI per contract. Replaced with a
  functional `mailto:` card plus a "what to include" card. (2026-08-14)
- `app/blog/[id]/page.tsx` social-share sidebar (Twitter/Facebook/Linkedin/
  Share2 buttons) had no handlers and no share URLs — removed. `prose`
  classes dropped in favour of hand-styled token paragraphs. Article bodies
  were Lorem ipsum placeholder → rewritten as real content per post in
  `constants/index.ts` (`content` field). Bottom CTA linked to non-existent
  `/register` and `/login` routes → fixed to `/auth/*`.
- Phase 3 pages (home, auth ×4, about, contact, blog ×2, blog-card/list,
  badge, `lib/status.ts`): zero new lint errors; build green; server diff
  empty; protected hashes unchanged.

## 8. TOTP login stage implemented (Phase 3)

- Backend (unchanged): `server/app/api/auth.py` login returns 401 with header
  `X-2FA-Required` when a TOTP-enabled user omits the code; the code rides in
  the OAuth2 form's `client_secret` field.
- Frontend: the old login page had **no** handling for this — a 2FA user saw
  the raw "TOTP code required" error. The redesigned page implements the
  two-step: on `X-2FA-Required` it switches to a 6-digit code stage and retries
  with `client_secret`. Wire format and `?next=` safe-redirect logic preserved
  exactly.

## 9. Phase 4 complete (patient core surfaces)

- Migrated to `components/ui/*` + tokens: dashboard, vitals, medicines,
  reports, documents, timeline, `medicine-manager`, `people-i-care-for`.
- Vitals: inline analyzers replaced by the shared `lib/status.ts` engine;
  trend chart now shades the normal band and uses the series palette (BP =
  series 1+2 with legend); history rows carry StatusChip + band text; legend
  row fixed an inconsistency (sugar "3.9-5.6" mmol/L vs "70-100 mg/dL" —
  normalized to mg/dL).
- Reports: raw overlay modals replaced by the `Dialog` primitive (Esc + scroll
  lock); lab-finding/HIGH/LOW/NORMAL colors mapped to StatusChip; upload form,
  trends tiles and action buttons tokenized; cache/offline fallback logic
  preserved 1:1 (offline flag now set only when a cached copy is actually
  shown, same as before).
- Medicines: reminders strip emojis replaced with lucide (Bell/CheckCircle2);
  all reminder logic (permission gating, iOS Home Screen guidance, test push)
  untouched. Medicine cards, interaction severity colours, time chips
  tokenized. `medicine-manager` still routes every request through `scopedUrl`
  and never caches for caretaker views.
- Timeline: emoji event icons (📄💊📅❤️📌) replaced with lucide; type colors
  now use the series palette.
- Dashboard: link cards now carry lucide icons; caretaker section ("People I
  care for") restyled; `care:notice` banner tokenized. Dead `uploading` state
  in documents removed.
- All 8 files lint-clean (the newer react-hooks rules required the fetch
  helpers to be pure and setState to happen after `await` inside effect-scoped
  async blocks — behavior unchanged); build green; server diff empty;
  protected hashes verified.

## 10. Phase 5 complete (scheduling & remaining pages)

- Migrated to `components/ui/*` + tokens: appointments, emergency,
  shared-with-me, search, nearby (page + `NearbyMap`), doctor/appointments,
  doctor/availability, settings/caretakers, care/[patientId].
- Appointments: success overlay replaced by the `Dialog` primitive;
  status badges map to StatusChip (CONFIRMED/COMPLETED = ok, PENDING =
  caution, CANCELLED = alert); booking form selects/textarea tokenized; ICS
  download and cancel-with-confirm flows untouched (wire format
  `appointment_date + ':00'` preserved).
- Doctor pages: day cards use ok/outline tokens; modal replaced by Dialog;
  the two hard-won fixes are preserved as comments and code: GET
  `/availability` (no id) resolves "my own windows" from the token (never
  `/availability/{user.id}`), and the status PATCH goes to
  `/status/by-doctor?status=...` (query string, doctor-of-record route).
- Emergency: medical-info form, contacts and QR sections tokenized; the
  fixed high-contrast light-red emergency ID card and the white QR box stay
  inline-styled (deliberate, both themes); `alert()`/`confirm()` kept.
  Public reader `/emergency/id/[userId]` left untouched (fully
  inline-styled printed card, same artifact as the preview).
- Shared-with-me: list/detail/report rows tokenized; share semantics
  unchanged (frozen reference, withdrawn reporting, live resolution).
- Search: input is now uncontrolled with a `key` remount (browser
  back/forward re-syncs it) and the query is read from FormData; "searching"
  is derived from a `loadedFor` state instead of a loading flag — the
  synchronous setState-in-effect lint rule drove both changes.
- NearbyMap: marker/legend colors moved to brand tokens (hospital alert red,
  clinic primary cyan, pharmacy ok green); geolocation lazy-initialized so
  the effect only ever sets state inside the subscription callbacks.
- Caretakers settings: invite code card, caretaker rows and audit list
  tokenized (caution amber for the one-time code note); the mount fetch was
  inlined with a cancelled flag (duplicating `load`'s error handling) to
  satisfy react-hooks v6 while `load` stays for the retry/restore buttons.
- Care page: amber caretaker banner moved to caution tokens (semantics
  preserved; comment kept and updated).
- New react-hooks v6 pattern added to the playbook: sync setState in effect
  bodies is flagged even without component-scope helpers — derive from lazy
  state initializers (nearby), subscription callbacks (NearbyMap), or
  derived state (search `loadedFor`).
- Verified: all 10 touched files lint-clean; `npm run build` green;
  `git diff --stat -- server/` empty; 13/13 protected SHA-256 hashes match
  the audit baseline (`/api/share/route.ts` covered by git status, clean).

## 11. Phase 6 complete (polish & cross-cutting)

- Full sweep confirmed: every non-frozen page/component now imports
  `components/ui/*` and uses semantic tokens. The only remaining raw gray /
  colour-utility usage is inside the frozen share surface (by contract) plus
  three intentional raw-hex sites: the fixed high-contrast emergency ID card,
  the white QR quiet zone, and NearbyMap's Leaflet marker constants (brand
  palette).
- `globals.css` dark-mode scope-overrides were trimmed (Phase 6 mandate):
  the block is now exactly the set of classes the frozen reader uses
  (neutrals, red/amber/green/emerald/teal/sky/blue tints). Rose/orange/yellow/
  indigo/purple, `hover:bg-gray-50`, the `.dark input/textarea/select`
  catch-all, and unused text shades (e.g. red-900, amber-700) were deleted —
  all migrated pages use tokens and need none of them.
- Deleted dead code: `components/input.tsx` (old input, 0 importers after
  Phase 5), `components/FormalReportView.tsx` (orphan), and the unused
  `MOCK_REPORTS`/`MOCK_USERS` exports in `constants/index.ts` (§6). All had
  no importers; build confirmed.
- React-hooks v6 lint fixed across the chrome with `useSyncExternalStore`
  (the designed tool for DOM/localStorage bootstrap, also hydration-safe via
  server snapshots — replacing the previously-flagged mount effects):
  - New `lib/session.ts`: token+user read from localStorage, subscribed by
    navbar and ChatBot (`storage` + `localStorageUpdated` events).
  - `theme-toggle`: reads the `.dark` class via store + `themechange`
    event; no more mounted flag.
  - `lib/i18n.tsx`: language via store + `langchange` event; the remaining
    effect only syncs `<html lang>` (external-system update, allowed).
  - `lib/useSpeechRecognition.ts`: ref write moved into an effect; browser
    support via store with no-op subscription.
  - ChatBot: session via store; "close panel on logout" deferred with
    `setTimeout(0)` so the setState lands after the render that observed the
    login change (behaviour preserved).
  - `medicine-alarm` `any` removed (typed webkitAudioContext).
- Full `npm run lint`: 13 problems (8 errors, 5 warnings) remaining, ALL in
  frozen share files (`share/*` + DigitizedReport warning) — the accepted
  baseline from §5, down from 62 errors + 15 warnings. Every non-frozen file
  is clean.
- Blog category chips and the auth-page logo `+` now use `text-on-primary`
  (the token) instead of `text-white` + the dark override.
- i18n: no page copy was localized before or after the redesign (only nav
  keys exist in the dictionary) — nothing lost; Devanagari rendering is
  guaranteed by the Noto Sans `devanagari` subset in layout.tsx.
- Responsive/accessibility verified at code level: breakpoint grids on all
  migrated pages, 44px+ targets in primitives, focus rings on interactive
  primitives, `prefers-reduced-motion` collapse in globals (all animation
  duration 0.01ms). Visual screenshot verification was not possible (no
  browser tooling in this environment) — flagged honestly for the user's
  review pass.
- Phase 6 caretaker-flows item closed: the two surfaces are
  `care/[patientId]` (Phase 5) and the dashboard's `people-i-care-for`
  component (Phase 4) — both tokenized, lucide icons, scopedUrl links,
  caretaker views uncached. There is no standalone `people-i-care-for` page
  in the app; the prompt's phrasing refers to this component.

## 12. Phase 7 — verification status

- `npm run lint`: clean except frozen-file baseline (§5, §11).
- `npm run build`: green, 33 routes.
- `git diff --stat -- server/`: empty. `git status --porcelain -- server/`:
  empty. Protected `/api/share/route.ts`: clean.
- Protected-file hashes: 13/13 match the §3 baseline.
- Not executable in this environment (flagged): pytest suite (Python 3.14
  wheel build blocker, §1), local-backend smoke (backend cannot run here for
  the same reason), browser screenshots light+dark at 375/768/1024/1440, and
  a live caretaker redeem. These are the user's runbook items before deploy
  (deploy steps are written, never executed).
