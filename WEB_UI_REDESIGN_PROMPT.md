# Master Prompt — Redesign the Ayuvo Web UI (`front/`)

> Paste everything below the line into a fresh agent session opened at the repo root
> (`C:\Users\user\Desktop\Medicare`).

---

## Role

You are redesigning the UI of the existing **Next.js web app** in `front/` — the
deployed site is https://medistore-health.vercel.app. It currently reads as
generic/AI-sloppy (stock Tailwind health palette, system fonts, a private colour per
status band, template landing page). Your job is to make it look deliberately
designed, calm and legible, **without touching the backend and without changing a
single pixel of the share reader** at https://medistore-share-beige.vercel.app.

A design direction already exists and is shipped: the Flutter app in `mobile/` went
through exactly this process. The web redesign must be **brand-consistent with it**,
not a new invention. Read `mobile/DESIGN.md` first; it is the source of truth.

## Hard constraints — read these twice

1. **The backend (`server/`) is frozen. Zero diff, every phase.** If any change lands
   there — accidental or otherwise — revert it immediately. If a change is ever
   deliberately approved (it is not in this prompt), it must pass the full
   `cd server && python -m pytest -q` suite and keep every existing client working
   unchanged. At every checkpoint, `git diff --stat -- server/` must be empty.
2. **The share reader (https://medistore-share-beige.vercel.app) is frozen — its UI
   and its backend.** In this repo that surface is `front/app/share/**` plus every
   module those pages import, transitively (full list in *Protected files* below).
   Those files stay **byte-identical**. The redesign therefore builds **new**
   primitives and migrates the app's other pages onto them; the reader keeps the old
   primitives. The reader calls the backend's `/api/share/*` endpoints directly, which
   is already covered by constraint 1.
   - Checkpoint-0 item: confirm where the reader deploys from. If it deploys from
     this repo's code, shared tokens in `front/app/globals.css` would alter its
     rendering — in that case the new tokens must be scoped so the reader's rendered
     output stays pixel-stable, or the change is deferred and flagged at the
     checkpoint. Never assume; verify.
3. **No mock data.** Every screen binds to a real endpoint or shows a real
   empty/error state. Nothing hardcoded, no fake testimonials/avatars/stats on the
   landing page.
4. **No new dependencies.** Icons: `lucide-react` (already installed). Fonts:
   `next/font/google` (self-hosted at build time — the app is a PWA with an offline
   cache, so a runtime Google Fonts `<link>` is forbidden). No framer-motion, no gsap,
   no new npm packages without written approval. Motion is CSS-level, subtle.
5. **Never weaken security or behaviour**: caretaker scope stays medicines-only,
   `patient_id` comes from the query string only, every patient-scoped URL goes
   through `front/lib/care.ts` (`scopedUrl`), user ids with `#` (`#hos014`) are always
   percent-encoded, medicine deletes stay soft, audit events keep firing. Redesign
   changes look, not semantics.
6. **Local only. Nothing reaches production without my explicit say-so.** Do not
   push, do not merge, do not deploy, do not run any script against the production
   database. The prod API may be used read-only for smoke tests; everything else runs
   against the local backend (`cd server && python -m uvicorn main:app --reload
   --port 3001`) and `npm run dev` (port 3000).

## The current state — what reads as AI-sloppy

Audited 2026-08-14. Fix these, don't preserve them:

- **Stock palette**: `#2563EB` primary + `#10B981` secondary — the default "health
  app" combo. `viewport.themeColor` is `#2563EB`. Nearly every surface is
  `bg-white rounded-xl border-gray-100 shadow-sm` — flat and interchangeable.
- **No typographic personality**: system font stack (the globals.css comment says
  "fully offline", but `next/font` solves that properly), no display face, no
  tabular figures on numbers (vital tiles, dose times, table figures).
- **A private colour per status band**: BP has 6 bands, heart rate 4, sugar 5,
  temperature 6, SpO2 4 — a legend nobody can hold, and the reference range is never
  shown. The colour *names* a band without ever showing where normal is.
- **Duplicate primitives**: `components/button.tsx` and the unused
  `components/ui/button.tsx` + `components/ui/card.tsx` (zero usages). Raw hex in
  chart strokes (`#ef4444`, `#3b82f6`, …). Inline SVGs and the odd text glyph
  (`&#9679;`) used as icons instead of `lucide-react`.
- **Template landing**: centered eyebrow + headline + two CTAs + three-card grid +
  CTA. No artifact from the product's own world.
- **Dark mode held together** by a huge `.dark` scope-override block in
  `globals.css` instead of design tokens.
- **Duplicated analysis helpers** (`analyzeBP/analyzeHR/analyzeSugar/analyzeTemp/
  analyzeSpO2`) inline in pages; the same band logic will be needed on vitals, home,
  reports and (possibly) documents.
- **Bilingual en/ne** exists (`lib/i18n.tsx`) but Devanagari rendering depends on the
  OS font; there is no guaranteed Devanagari-capable font.

## Design direction — one brand, two platforms

Read, in order: `mobile/DESIGN.md` → `mobile/design-system/ayuvo/MASTER.md` →
`front/design-system/ayuvo-web/MASTER.md` (generated for this task on 2026-08-14
with `ui-ux-pro-max`, variance 4 / motion 3 / density 6). The web re-verifies the
mobile decisions and documents its departures. Non-negotiable, carried from mobile:

- **Palette**: primary `#0E7490` (cyan-700 — white on it is 5.36:1, AA; the
  generated `#0891B2` fails AA and is used only for focus rings); background
  `#FBFCFD` (near-neutral — a cyan-tinted field competes with the data); cards white
  with a **hairline border** `#C3D4DA`, flat (no card shadows; shadow is reserved for
  things that float: modals, dropdowns, mobile menus). Dark: `#0F1417` / `#161D21`,
  on-surface `#E6EEF1`, primary `#5CD3EC`.
- **Green is a status, never an action.** Status = three states (ok / caution /
  alert) with a direction glyph; the band names (`Elevated`, `Stage 1`, `Hypothermia`)
  stay as text. **Never colour alone** — every status chip carries its label.
- **The signature: the range bar.** Every meaningful number is judged against a band:
  a track with the normal band as a filled segment and the reading as a marker. It
  appears in exactly three places — vitals tiles, lab findings rows, and as a shaded
  normal band behind trend lines — and nowhere else. This is the one memorable
  element; everything else stays disciplined.
- **Charts**: fixed series palette `#0891B2`, `#7C3AED`, `#DB2777`, `#2563EB` (dark:
  `#0A98BA`, `#9363FF`, `#F60281`, `#4581FE`) in fixed order, never cycled. Status
  colours are never used for a series. Only BP carries two series; legend shown for
  any chart with ≥2 series.
- **Type**: Figtree (headings — Latin only) + Noto Sans (body — full Devanagari for
  the Nepali locale), loaded via `next/font/google` with `latin` + `devanagari`
  subsets. Tabular figures (`font-variant-numeric: tabular-nums`) on every number on
  a data screen. Minimum body 16px, line-height 1.5.
- **Shape / spacing / motion**: radius sm 8 / md 12 / lg 20. 4pt spacing scale.
  Minimum 44px touch targets, 8px+ between interactive elements. Motion subtle:
  120/200/280/160ms, easeOut/inOut, exits faster than entrances, no bounce/parallax,
  `prefers-reduced-motion` collapses everything to zero.
- **Writing**: sentence case, active voice, the control names the action ("Save
  changes", not "Submit") and the verb survives the flow. Errors never apologize and
  never say "Something went wrong" — they say what failed and offer Retry. Empty
  states invite the one action that fills them ("Add your first medicine", not "No
  data"). Health copy keeps the existing AI disclaimers verbatim. Caretaker context is
  always named on screen ("You're managing medicines for Ram.").
- **Three states on every async surface**: loading = skeleton shaped like the result
  (not a bare spinner), empty = what this screen is for + the one action, error =
  what failed + Retry. A 401 routes to sign-in with a message; it is not an error
  state.
- **Landing page**: open with a real artifact from the product's world — a live,
  data-drawn preview of the dashboard/vitals (not a fake screenshot), or the range-bar
  grammar itself. Then the real problem it solves (records to hand, vitals judged
  against bands, sharing with a doctor), then CTA. No fabricated testimonials or
  ratings.
- **Old primitives stay for the reader**: the reader's files (`components/button.tsx`,
  `components/card.tsx`, …) are byte-identical. New primitives (e.g.
  `components/ui/` — which currently holds unused duplicates, or a fresh
  `components/`) replace them for every non-reader page. The `components/ui/*` dead
  duplicates may be replaced by the real design-system primitives.

## The design pass — run this in phase 1, before any screen exists

Skills are installed on this machine. Use them, then write the choice down:

```powershell
# ui-ux-pro-max — the primary source
python "C:\Users\user\.claude\skills\ui-ux-pro-max\scripts\search.py" "calm trustworthy healthcare patient records web app" --design-system --variance 4 --motion 3 --density 6 -p "Ayuvo Web" -f markdown
python "C:\Users\user\.claude\skills\ui-ux-pro-max\scripts\search.py" "status chip range indicator health data" --domain ux
python "C:\Users\user\.claude\skills\ui-ux-pro-max\scripts\search.py" "dashboard data density spacing" --domain ux
python "C:\Users\user\.claude\skills\ui-ux-pro-max\scripts\search.py" "nextjs tailwind v4 tokens" --stack nextjs
python "C:\Users\user\.claude\skills\ui-ux-pro-max\scripts\search.py" "chart legend color accessibility" --domain chart
```

The web design system was already persisted at
`front/design-system/ayuvo-web/MASTER.md` — re-run only if the direction
changes, and read the mobile master before overriding anything.

**Deliverable**: `front/WEB_DESIGN.md` — the chosen tokens translated into Tailwind
v4 `@theme` (light + dark, contrast-checked), type scale (Figtree/Noto Sans, tabular
numerals), spacing/radius/elevation/motion tables, the status scale with glyphs, the
chart palette, the range-bar spec, and the component inventory (Button, Card, Input,
StatusChip, RangeBar, Skeleton, EmptyState, Dialog, table rows). Plus a departures
table exactly like `mobile/DESIGN.md` §9 — every place the web diverges from the
generated master or from mobile, with a reason. No raw hex and no ad-hoc padding in
any component file, ever — tokens only.

## Phases — stop and report at each checkpoint

Backend frozen through **all** phases (constraint 1). At every checkpoint state
`git diff --stat -- server/` and `git diff --stat -- <protected files>` are empty.

### Phase 0 — Recon & baseline
Read `AGENTS.md`, `RUN.md`, every `front/app/**/page.tsx` and component. Produce
`front/WEB_UI_AUDIT.md`: page → current structure → what reads as sloppy → planned
change, plus the protected-file baseline (hash the files in *Protected files* so the
diff check is exact). Confirm where the share reader deploys from (constraint 2).
Run the whole pytest suite once to prove the backend is healthy before you start.
**Checkpoint: show the audit and the protected-file baseline before writing code.**

### Phase 1 — Design pass (1.5)
Run the commands above; read the three design docs; deliver `front/WEB_DESIGN.md`
and the token translation into `@theme`. **Checkpoint: I approve the direction
before any screen code exists.** Retrofitting tokens across 28 pages never fully
happens; the theme must precede the pages.

### Phase 2 — Foundation
`globals.css` tokens (light + dark, scoped per constraint 2), `next/font` Figtree +
Noto Sans, the new primitives (Button, Card, Input, StatusChip, RangeBar, Skeleton,
EmptyState, Dialog), Navbar, Footer, ChatBot chrome, `layout.tsx`, PWA manifest
accent + `viewport.themeColor`. Migrate the app's pages onto the new primitives as
you touch them (reader pages and their imports stay frozen). Delete the dead
`components/ui/*` duplicates only if nothing imports them. **Checkpoint: sign in
against the local backend and see the app chrome.**

### Phase 3 — Auth & public pages
Landing (home public state — the hero with the real artifact), `auth/login`,
`auth/register`, `auth/forgot-password`, `auth/reset-password`, `about`, `contact`,
`blog` + `blog/[id]`. Keep 2FA (TOTP) flow intact — it is wired through the OAuth2
form. **Checkpoint.**

### Phase 4 — Patient core data
`dashboard`, `vitals` (range bars + trends with shaded normal band), `medicines`
(intake logging, alarms, interaction warnings, soft-deleted/restore), `reports`
(upload, AI summary, lab analysis, explain), `documents`. Extract the band-analysis
logic into one shared module (e.g. `lib/status.ts`) and drive every status chip and
range bar from it — one legend, three colours. **Checkpoint.**

### Phase 5 — Scheduling, sharing management & the rest
`appointments` (browse doctors → availability → slots → book), doctor screens
(`doctor/appointments`, `doctor/availability`), `emergency` + the bare public
`emergency/id/[userId]` (keep it chromeless and shareable — it is not part of the
reader, but it is opened by strangers scanning a QR), `nearby` (Leaflet), `timeline`,
`search`, `settings/caretakers`, `share` **management** page (in `front/app/share/`
— frozen per constraint 2, so design its replacement only if the reader-deploy
check confirms it is safe; otherwise note and skip). **Checkpoint.**

### Phase 6 — Polish & cross-cutting
Caretaker flows (`care/[patientId]`, `people-i-care-for`), i18n en/ne copy pass on
every string (Devanagari rendering verified), empty/error/loading audit on every
async surface, accessibility pass (visible focus, 4.5:1 contrast, keyboard nav,
`prefers-reduced-motion`), dark mode verified screen by screen, responsive audit at
375 / 768 / 1024 / 1440. **Checkpoint.**

### Phase 7 — Verification & handover
`npm run lint` and `npm run build` clean. Local smoke against the local backend:
register, login, dashboard, vitals, medicines, reports, share a report, caretaker
redeem. Screenshots light + dark at all four widths. Protected-file diff report
(byte-identical proof). Final `WEB_DESIGN.md` + `WEB_UI_AUDIT.md` (what shipped,
what was deferred, why). Deploy steps are written for me, never executed by you.
**Checkpoint: walk me through the screenshots and the diff reports.**

## Verification — evidence, not assertions

- `git diff --stat -- server/` **empty** at every checkpoint, and the full
  `cd server && python -m pytest -q` suite green — the suite is how we prove the
  backend is untouched and still correct.
- `git diff --stat --` over every protected file **empty** at every checkpoint.
- `cd front && npm run lint` clean; `npm run build` clean.
- Every screen exercised against the **local** backend with a real account: load,
  create, edit, delete, and the 401 path.
- Light **and** dark verified on every screen; contrast ≥ 4.5:1 (primary on white
  included); focus states visible; reduced motion respected.
- No raw hex outside the token layer and the chart-palette constant; no ad-hoc
  padding; no emojis as icons (lucide-react only).
- Report honestly: what shipped, what was deferred (reader-frozen surfaces),
  what failed.

## Protected files — byte-identical, never edited

The share reader (https://medistore-share-beige.vercel.app) renders these. Any
change to them is a change to the reader's UI:

```
front/app/share/**                                  (all 3 pages, incl. management)
front/components/button.tsx
front/components/card.tsx
front/components/DigitizedReport.tsx
front/components/ShareTargetChooser.tsx
front/components/ClaimShareButton.tsx
front/components/kept-by-others.tsx
front/components/hide-on-share.tsx
front/lib/datetime.ts
front/lib/shares.ts
front/lib/reportPdf.ts
front/app/api/share/**                              (route handler, if the reader uses it)
```

Anything else — globals.css, layout, navbar, other components, other pages — is
redesignable **provided** the reader's transitive dependency graph above stays
intact. When in doubt, do not touch: note it at the checkpoint and ask.

## Environment notes

- Local backend: `cd server && python -m uvicorn main:app --reload --port 3001`;
  local frontend: `cd front && npm run dev` (port 3000). Prod API
  (https://medistore-api-vwyr.onrender.com) is read-only smoke-test material only.
- The API hostname is *not* derivable from `render.yaml`; do not "fix" it.
- `NEXT_PUBLIC_API_URL` in `front/.env*` controls the API base; the code defaults to
  `http://127.0.0.1:3001` (see the `API_URL` constants in the pages).
- The PWA offline cache (`front/lib/offlineCache.ts`) and service worker must keep
  working — another reason fonts are self-hosted via `next/font`.