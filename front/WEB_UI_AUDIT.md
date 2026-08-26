# Ayuvo Web UI — Audit & Baseline (Phase 0)

Date: 2026-08-14. Scope: `front/` Next.js app (https://medistore-health.vercel.app),
redesign per `WEB_UI_REDESIGN_PROMPT.md`. Backend (`server/`) frozen; share reader
(https://medistore-share-beige.vercel.app) frozen.

## 1. Share reader deploy source (checkpoint-0 item) — VERIFIED

Fetched `https://medistore-share-beige.vercel.app/` (2026-08-14):

- The response is the **Flutter web bootstrap** (`flutter_bootstrap.js`, `<base href>`
  comment, `manifest.json`, title `ayuvo`), not a Next.js build.
- Conclusion: **the reader deploys from the Flutter app (`mobile/`), not from this
  repo's `front/` code.** Changes to `front/app/globals.css` therefore cannot alter
  the deployed reader's rendering.
- Consequence: the new design tokens in `globals.css` need **no scoping** for the
  deployed reader. The protected `front/app/share/**` files and their transitive
  imports stay byte-identical anyway (contractual invariant, and they mirror the
  Flutter reader's behaviour).
- Caveat noted: if the reader were ever redeployed from `front/`, the freeze list in
  §3 is the invariant that keeps it stable.

Also observed while fetching the main app's production HTML: `theme-color #2563EB`,
old palette live, `font-sans` system stack, `bg-blue-600` ChatBot FAB — consistent
with the "AI-sloppy" audit below.

## 2. Page inventory (28 `page.tsx` files)

In-scope (25): all except the 3 protected share pages. Key = current structure →
what reads as sloppy → planned change.

### 2.1 Landing / public

| Page | Structure | Sloppy | Plan |
|---|---|---|---|
| `/` (home) | navbar → hero (eyebrow "Secure & Private", H1, 2 CTAs) → 3-card grid → CTA band; footer. Public when logged out; shows dashboard-ish content when logged in | Stock template hero, no artifact from the product's world, "Join others who trust Ayuvo" copy, 3 interchangeable cards | Replace with a real artifact: live data-drawn vitals preview using the range-bar grammar (only for logged-in; logged-out shows an illustrative range-bar composition), problem statement, single strong CTA; keep bilingual toggle |
| `/about` | Static prose sections | Generic company page | Typography pass, brand voice, real facts (no invented stats) |
| `/contact` | Form + info | Generic | Form polish, error/empty/loading states |
| `/blog` + `/blog/[id]` | List with search/filter chips (MOCK_BLOG_POSTS), card grid; detail page | `components/ui/card` used here; Unsplash images; dated placeholder | Restyle via new Card/Input/Badge primitives; keep MOCK_BLOG_POSTS (static content, allowed — not fake user data) |

### 2.2 Auth

| Page | Structure | Sloppy | Plan |
|---|---|---|---|
| `/auth/login` | Card form; `?next=` safe redirect; OAuth2 form flow incl. 2FA/TOTP stage | Blue-600 focus rings, system font | Redesign on new tokens; **preserve `?next=` logic and 2FA stage exactly** |
| `/auth/register` | Two-step (account → profile) | Same as login | Same |
| `/auth/forgot-password`, `/auth/reset-password` | Simple forms | Same | Same |

### 2.3 Patient core

| Page | Structure | Sloppy | Plan |
|---|---|---|---|
| `/dashboard` | Greeting, vitals summary chips (inline analyzers), quick actions, recent reports, PeopleICareFor | Per-vital inline colors, no reference bands, emoji-ish status | Range bars in summary tiles, `lib/status.ts` shared analysis, status chips with labels |
| `/vitals` | Log form + per-vital cards with trend charts (recharts), 5 inline analyzers (BP 6 bands, HR 4, Sugar 5, Temp 6, SpO2 4) | Private colour per band, legend impossible to hold, no normal band shown, raw hex chart colors | One status scale (ok/caution/alert + glyph + label), range bar with normal band, shaded normal band behind trend lines, tabular numerals |
| `/medicines` | MedicineManager: list/add form/taking times/soft delete; interactions panel; adherence via alarm | Blue-50 time chips, red-50 interaction blocks, bare `Loading…` | New primitives; 3-state async surfaces; status chips for interactions; keep soft-delete/restore and audit hooks |
| `/reports` | Upload, list (DigitizedReport), AI summary, generateReportPdf, cacheGet/cacheSet | Mixed old/new components | Restyle non-protected parts; report rows with status chips; keep DigitizedReport + reportPdf frozen |
| `/documents` | Upload/list/delete with file chips | Generic | Restyle; empty/error states |

### 2.4 Scheduling

| Page | Structure | Sloppy | Plan |
|---|---|---|---|
| `/appointments` | Browse doctors → availability → available slots → book; own appointments list; .ics download (lib/ics.ts) | Stock blue buttons, plain lists | Redesign booking flow; slot chips; keep double-booking validation server-side |
| `/doctor/appointments` | Doctor's appointment list with status PATCH | Plain table | Table rows per design; status chips (3 states) |
| `/doctor/availability` | Weekly availability CRUD (day/time/slot) | Plain | Restyle; keep PUT/DELETE semantics |

### 2.5 Emergency

| Page | Structure | Sloppy | Plan |
|---|---|---|---|
| `/emergency` | Profile edit + contacts + public URL + QR | Generic forms | Restyle; keep QR share |
| `/emergency/id/[userId]` | **Chromeless public page** (inline styles, red `#7f1d1d`), opened by strangers scanning a QR | Inline styles, no tokens | Keep chromeless & shareable; restyle with tokens but stay public/no-auth; not part of the reader freeze |

### 2.6 Rest

| Page | Structure | Sloppy | Plan |
|---|---|---|---|
| `/timeline` | Mixed-type event feed with **emoji icons** (📄💊📅❤️📌) | Emoji as icons | lucide icons per event type, status chips, tabular dates |
| `/search` | Full-text search across records, grouped results | Plain | Restyle; 3 states |
| `/nearby` | Leaflet map + Overpass API list; divIcon markers with raw hex (#dc2626/#2563eb/#059669) | Raw hex, busy marker pins | Token-based marker palette (status scale or fixed series), clean list rows |
| `/settings/caretakers` | Invite code (createInvite, shown once 15 min), caretaker list, audit trail (listAudit), restore soft-deleted medicines (restoreMedicine), revoke (revokeLink) | Plain tables | Restyle; keep one-time code display, revoke/restore flows, CareAccessRevoked handling |
| `/shared-with-me` | Claimed shares management via lib/shares (protected) — claims on my records, received shares, withdraw/drop | Plain | Restyle around frozen lib/shares |
| `/care/[patientId]` | Caretaker medicine manager for a patient; revoke banner when link dies | Shares MedicineManager | Redesign MedicineManager once, both pages inherit; keep caretaker-only scope, scopedUrl, no caching of others' data |

### 2.7 Protected (never touched) — see §3 for the full list

`/share`, `/share/[token]`, `/share/qr-code/[token]` — the share reader pages
(management + reader). Byte-identical.

## 3. Protected-file baseline (SHA-256, 2026-08-14)

| File | SHA-256 |
|---|---|
| `front/app/share/page.tsx` | `09B79104720E5465C33F35280D342875F5DB98EBB1C2B91B4239B6EE1272483D` |
| `front/app/share/[token]/page.tsx` | `11AA204278D745342464BB69AE0B6B0A83505B3BE23E223F4F6784C3BED1FB8B` |
| `front/app/share/qr-code/[token]/page.tsx` | `36D267986FEA0B00BCB82A588E48188677773D6F8ABAD3C38B0EAF55B7FF7251` |
| `front/components/button.tsx` | `DE01A1FA0FCA4C1991C61C634046C12FC60635776CE66AA5E0F96BDF87B3268D` |
| `front/components/card.tsx` | `AC68B20CB853E8C96F65A0C2B895DE9104F51AA8D9E3335DA73E8598D9B64941` |
| `front/components/DigitizedReport.tsx` | `99DFEFB630725F7B242685F22CDCA2BC4920885F8B239452199747A463184311` |
| `front/components/ShareTargetChooser.tsx` | `55AA410E62435671E78B61F7817CC760529D08B6E70980F455A25107BA5A4F65` |
| `front/components/ClaimShareButton.tsx` | `BADA3D3A224E542B8EB4CA224721E80F7D23075D14D100010BC4A823A9467CB9` |
| `front/components/kept-by-others.tsx` | `CCEC12BE0DE7EB6E4C96D5133B79B013199AE17831D62266E605280B84AA722B` |
| `front/components/hide-on-share.tsx` | `4AFF060276D57D8F3FE4BA0D5655C7318E515BF6DF5531CF89BE584AE03052A8` |
| `front/lib/datetime.ts` | `B004893C5CDC13333D5DCF18AE17754010D8F1478B40696F913ED92CCA70DEBD` |
| `front/lib/shares.ts` | `98793895CABDE8ED1629F75A0EB07BDFD22CFE31E4E96E5EFF769C3DFE8924A2` |
| `front/lib/reportPdf.ts` | `A01706EA5CC0BE93015E18ADAFA63ECAD6723A0F30CBF621CBD39DC7A31B4624` |
| `front/app/api/share/route.ts` | legacy relative proxy (`/api/share` GET); **treated as frozen** — part of the share surface, zero redesign value |

Also frozen by convention: `front/lib/care.ts` API surface (read-only client used by
both frozen and redesignable pages — may be **imported**, never edited).

## 4. Component inventory

| Component | Used by | Status |
|---|---|---|
| `components/button.tsx`, `components/card.tsx` | App pages **and** protected share pages | FROZEN. New primitives replace them for non-reader pages |
| `components/ui/button.tsx` | All app pages (via `components/ui/*`) | Real primitive (Phase 2). Old `components/button.tsx` frozen for the reader |
| `components/ui/card.tsx` | All app pages | Real primitive (Phase 2). Old `components/card.tsx` frozen for the reader |
| `components/input.tsx` | — (0 importers after Phase 5) | DELETED (Phase 6); replaced by `components/ui/input.tsx` everywhere |
| `components/badge.tsx` | blog | Redesigned (Phase 3) |
| `components/navbar.tsx`, `footer.tsx` | layout | Redesigned (Phase 0/2); session via store (Phase 6) |
| `components/theme-toggle.tsx`, `language-toggle.tsx` | navbar | Redesigned (Phase 2); external-store theme (Phase 6) |
| `components/ChatBot.tsx` | layout | Redesigned (Phase 0): lucide icons, tokens; session via store (Phase 6) |
| `components/medicine-manager.tsx` | `/medicines`, `/care/[patientId]` | Redesign in place (both callers inherit) |
| `components/medicine-alarm.tsx` | layout (`MedicineAlarm`) + `/medicines` (`ensurePushSubscription`) | Renders nothing; notification/audio logic — no visual redesign, keep byte-behaviour |
| `components/people-i-care-for.tsx` | `/dashboard` | Redesigned (Phase 4): ui primitives, lucide Bell/BellOff, tokens, scopedUrl links |
| `components/pwa-register.tsx` | layout | No visual surface; keep |
| `components/NearbyMap.tsx` | `/nearby` | Redesigned (Phase 5); raw hex markers → brand constants |
| `components/FormalReportView.tsx` | — (orphan, only self-reference) | DELETED (Phase 6) — no importers |
| `components/blog/blog-card.tsx`, `blog-list.tsx` | `/blog` | Redesignable |
| Protected: `DigitizedReport`, `ShareTargetChooser`, `ClaimShareButton`, `kept-by-others`, `hide-on-share` | share pages | FROZEN |

## 5. Shared logic (read-only or redesignable)

- `lib/care.ts` — caretaker client + `scopedUrl` + `authHeaders` + error classes.
  **Never edit** (transitive dependency of frozen pages: `ClaimShareButton`).
  All caretaker-scoped URLs MUST go through `scopedUrl` (the `#` in `#hos014`
  truncates URLs into fragments otherwise).
- `lib/shares.ts`, `lib/datetime.ts`, `lib/reportPdf.ts` — frozen (§3).
- `lib/i18n.tsx` — en/ne dictionary (currently 17 nav keys); redesignable, extendable.
- `lib/offlineCache.ts` — IndexedDB cache used by medicines/reports/vitals; keep,
  may be imported by new code.
- `lib/ics.ts` — `.ics` download for appointments; keep.
- `lib/useSpeechRecognition.ts` — Web Speech API hook for ChatBot; keep.
- `lib/utils.ts` — cn() helper.
- `constants/index.ts` — `MOCK_BLOG_POSTS` (used by blog). `MOCK_REPORTS`,
  `MOCK_USERS` were unused and were **deleted** in Phase 6.

## 6. Known issues & blockers (recorded, see WEB_UI_REDESIGN_ISSUES.md)

- **pytest cannot run on this machine**: only Python 3.14 installed
  (`C:\Python314`); `psycopg2-binary` and `pydantic-core` have no 3.14 wheels and
  the Rust build fails. Backend health is proven via `git diff --stat -- server/`
  empty + code review instead. Flagged at checkpoint; suite must be run by the
  user before anything deploys.
- No emojis as icons (timeline), no raw hex outside tokens/chart constants
  (vitals charts, NearbyMap markers, emergency public page).

## 7. Redesign entry points (Phase 2+)

1. `globals.css` — token layer via Tailwind v4 `@theme` (light + dark),
   `tabular-nums` utility, focus rings, reduced-motion collapse.
2. `next/font/google` — Figtree (latin) + Noto Sans (latin+devanagari).
3. New primitives: Button, Card, Input, StatusChip, RangeBar, Skeleton,
   EmptyState, Dialog — new files so frozen `components/button.tsx` / `card.tsx`
   stay untouched; replace dead `components/ui/*` after confirming blog migrated.
4. `lib/status.ts` — extract the 5 inline analyzers into one band engine that
   drives every chip and range bar.
5. layout.tsx (fonts, chrome), manifest themeColor → `#0E7490`.