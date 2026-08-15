# MediStore Website UI Redesign Prompt

## Objective
Redesign the MediStore **web frontend** (`/front`) to match the **mobile app's design language** (Flutter app in `/mobile`) while maintaining full functionality, web responsiveness, and zero breaking changes to backend APIs or app functionality.

---

## Design Reference: Mobile App Design System

### Colors (from `/mobile/lib/core/theme/app_tokens.dart`)

| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| **Primary (Cyan)** | `#0E7490` (cyan700) | `#5CD3EC` (cyanDark) | Buttons, links, active states, focus rings |
| **Primary Focus** | `#0891B2` (cyan600) | `#5CD3EC` | Focus rings only (3:1 non-text) |
| **Surface** | `#FBFCFD` (paper) | `#0F1417` (night) | Page background |
| **Card** | `#FFFFFF` (card) | `#161D21` (nightCard) | Card backgrounds |
| **Muted** | `#EEF3F5` (muted) | `#1E272C` (nightMuted) | Subtle backgrounds, hover states |
| **Outline** | `#C3D4DA` (slate) | `#32424A` (nightOutline) | Borders, dividers |
| **Ink** | `#0F2B33` (ink900) | `#E6EEF1` (nightInk) | Primary text |
| **Ink Variant** | `#4A6670` (ink500) | `#9DB2BA` (nightInkVariant) | Secondary text |
| **Status OK** | `#046A4E` / `#E3F6EE` | `#4ADBA4` / `#0C2A20` | Normal vitals, success |
| **Status Caution** | `#8A4B08` / `#FDF0DC` | `#F0B252` / `#2E2009` | Elevated vitals, warnings |
| **Status Alert** | `#B91C1C` / `#FDE7E7` | `#FF8A8A` / `#33140F` | Critical vitals, errors |

### Typography (from `/mobile/lib/core/theme/app_theme.dart`)

| Role | Font | Weights |
|------|------|---------|
| **Headings** | Figtree | 600 (semibold) |
| **Body** | Noto Sans | 400 (regular), 500 (medium) |
| **Devanagari Fallback** | Noto Sans Devanagari | — |
| **Numeric (Tabular)** | Figtree | 600, tabular figures |

### Spacing & Radius (4pt scale)

| Token | Value |
|-------|-------|
| xs | 4px |
| sm | 8px |
| md | 12px |
| lg | 16px (screen gutter, card padding) |
| xl | 24px |
| xxl | 32px |
| xxxl | 48px |
| Radius sm | 8px |
| Radius md | 12px |
| Radius lg | 20px |
| Radius full | 999px (pills) |

### Motion

| Token | Duration | Curve |
|-------|----------|-------|
| fast | 120ms | easeOutCubic |
| base | 200ms | easeInOut |
| slow | 280ms | easeInOut |
| exit | 160ms | easeIn |

### Touch Targets
- Minimum: 44×44px
- Standard: 48×48px

---

## Current Web State (Baseline)

- **Primary**: `#2563EB` (blue) → **Change to cyan `#0E7490`**
- **Fonts**: System stack → **Change to Figtree + Noto Sans**
- **Logo**: Blue square with white "+" → **Redesign to match app**
- **Components**: Tailwind + custom components in `/front/components/`
- **Pages**: 28 pages in `/front/app/`
- **API**: All calls go to `http://127.0.0.1:3001` (backend unchanged)

---

## Phased Implementation Plan

### Phase 0: Foundation & Design Tokens (No Visual Changes Yet)
**Goal**: Establish design token system in CSS matching mobile app exactly.

**Tasks**:
1. Create `/front/app/design-tokens.css` with all mobile app tokens as CSS custom properties
2. Update `/front/app/globals.css` to import and use design tokens
3. Add Figtree + Noto Sans fonts (self-hosted or Google Fonts with `display=swap`)
4. Verify: `npm run build` passes, no console errors, all pages render identically

**Acceptance Criteria**:
- [ ] All colors match mobile app tokens exactly (light + dark)
- [ ] Typography scale matches mobile app
- [ ] Spacing scale matches 4pt system
- [ ] Dark mode works via `.dark` class on `<html>`
- [ ] Zero visual regression on all 28 pages

**Rollback**: Git commit before Phase 1

---

### Phase 1: Logo & Navbar Redesign
**Goal**: New logo matching mobile app brand; responsive navbar.

**Tasks**:
1. Design new logo mark (SVG) using cyan primary, medical cross/plus motif
2. Create responsive logo component: `Logo.tsx` with variants (full, mark-only, small)
3. Update `/front/components/navbar.tsx`:
   - Replace current logo with new `Logo` component
   - Ensure mobile hamburger menu works
   - Verify dropdown "More" menu positioning
   - Test search expand/collapse on desktop
4. Update favicon, manifest icons, apple-touch-icon to new logo

**Acceptance Criteria**:
- [ ] Logo renders correctly at all sizes (16px–512px)
- [ ] Navbar responsive: mobile (<640px), tablet (640–1024px), desktop (>1024px)
- [ ] All nav links work (including doctor-specific routes)
- [ ] Theme toggle, language toggle, search, logout all functional
- [ ] No layout shift on logo load (use `width`/`height` or `aspect-ratio`)

**Error Handling**:
- If font fails to load: fallback to system stack gracefully
- If SVG logo fails: fallback to text "MediStore" with cyan color

---

### Phase 2: Global Component Library Overhaul
**Goal**: All shared components use new design tokens.

**Components to Update** (in `/front/components/`):
- `button.tsx` — primary, outline, ghost variants using cyan tokens
- `card.tsx` — card background, border, radius tokens
- `footer.tsx` — colors, spacing, typography
- `theme-toggle.tsx` — icon colors, transitions
- `language-toggle.tsx` — styling
- `hide-on-share.tsx` — no visual change
- `pwa-register.tsx` — no visual change
- `medicine-alarm.tsx` — alarm styling, cyan accent
- `ChatBot.tsx` — chat bubble colors, input styling
- `ShareTargetChooser.tsx` — modal styling
- `NearbyMap.tsx` — map container styling
- `DigitizedReport.tsx` — report card styling
- `FormalReportView.tsx` — print styles
- `people-i-care-for.tsx` — caretaker card styling
- `kept-by-others.tsx` — shared record styling
- `ClaimShareButton.tsx` — button styling

**Tasks**:
1. Replace all hardcoded colors with design token CSS variables
2. Update border-radius to use token values (sm/md/lg/full)
3. Update spacing to use token scale
4. Update typography to use Figtree/Noto Sans
5. Ensure dark mode works for every component

**Acceptance Criteria**:
- [ ] Storybook/visual regression: all components render correctly in light/dark
- [ ] All interactive states (hover, focus, active, disabled) work
- [ ] Focus visible outlines use cyan600 focus ring token
- [ ] No console errors or warnings

**Error Handling**:
- Document any component that breaks in `/front/UNKNOWN_ERRORS.md` with:
  - Component name
  - Error message
  - Root cause
  - Fix applied (or workaround)

---

### Phase 3: Public Pages (Landing, Auth, About, Contact, Blog)
**Goal**: Public-facing pages match new design.

**Pages**:
- `/` (landing) — `front/app/page.tsx` (public section)
- `/auth/login` — `front/app/auth/login/page.tsx`
- `/auth/register` — `front/app/auth/register/page.tsx`
- `/auth/forgot-password` — `front/app/auth/forgot-password/page.tsx`
- `/auth/reset-password` — `front/app/auth/reset-password/page.tsx`
- `/about` — `front/app/about/page.tsx`
- `/contact` — `front/app/contact/page.tsx`
- `/blog` — `front/app/blog/page.tsx`
- `/blog/[id]` — `front/app/blog/[id]/page.tsx`

**Tasks**:
1. Update all hardcoded colors to design tokens
2. Update typography, spacing, border-radius
3. Ensure forms use new input styling (focus rings, labels)
4. Verify responsive layouts (mobile-first)
5. Test auth flows end-to-end

**Acceptance Criteria**:
- [ ] Landing page hero, features, CTA sections render correctly
- [ ] Auth forms: validation, error states, loading states work
- [ ] Password reset flow works (email → link → form → success)
- [ ] Blog pages readable, responsive
- [ ] No horizontal overflow on any viewport

**Error Handling**:
- Log any API integration issues in `UNKNOWN_ERRORS.md`

---

### Phase 4: Authenticated Dashboard & Core Feature Pages
**Goal**: Main app pages for logged-in users.

**Pages** (Patient):
- `/dashboard` — `front/app/dashboard/page.tsx`
- `/medicines` — `front/app/medicines/page.tsx`
- `/vitals` — `front/app/vitals/page.tsx`
- `/reports` — `front/app/reports/page.tsx`
- `/reports/[id]` — `front/app/reports/[id]/page.tsx`
- `/appointments` — `front/app/appointments/page.tsx`
- `/documents` — `front/app/documents/page.tsx`
- `/timeline` — `front/app/timeline/page.tsx`
- `/search` — `front/app/search/page.tsx`
- `/emergency` — `front/app/emergency/page.tsx`
- `/emergency/id/[userId]` — `front/app/emergency/id/[userId]/page.tsx`
- `/nearby` — `front/app/nearby/page.tsx`
- `/settings/caretakers` — `front/app/settings/caretakers/page.tsx`
- `/care/[patientId]` — `front/app/care/[patientId]/page.tsx`

**Pages** (Doctor):
- `/dashboard` (doctor view)
- `/doctor/appointments` — `front/app/doctor/appointments/page.tsx`
- `/doctor/availability` — `front/app/doctor/availability/page.tsx`

**Pages** (Share):
- `/share` — `front/app/share/page.tsx`
- `/share/[token]` — `front/app/share/[token]/page.tsx`
- `/share/qr-code/[token]` — `front/app/share/qr-code/[token]/page.tsx`
- `/shared-with-me` — `front/app/shared-with-me/page.tsx`

**Tasks**:
1. Update all pages to use design tokens
2. Fix any layout issues from token changes (spacing, sizing)
3. Ensure charts (recharts) use chart color tokens
4. Verify data fetching, loading skeletons, error states
5. Test all CRUD operations (create, read, update, delete)
6. Verify responsive tables, cards, grids

**Acceptance Criteria**:
- [ ] All pages load without console errors
- [ ] All user flows work: add medicine, record vital, upload report, book appointment, share record
- [ ] Charts render with correct colors (cyan series, status bands)
- [ ] Tables responsive (horizontal scroll on mobile)
- [ ] Modals/drawers use new styling
- [ ] PWA install prompt works
- [ ] Medicine alarm component functional

**Error Handling**:
- Any broken API integration → `UNKNOWN_ERRORS.md`
- Any chart rendering issues → document and fix
- Any layout breakage → fix with token-compliant CSS

---

### Phase 5: API Routes & Middleware
**Goal**: Ensure Next.js API routes (`/front/app/api/**`) work with new design.

**Routes**:
- `/api/auth/*` — proxy to backend
- `/api/appointments` — proxy
- `/api/doctors` — proxy
- `/api/documents` — proxy
- `/api/reports` — proxy
- `/api/share` — proxy

**Tasks**:
1. Verify all proxies forward requests correctly
2. Check CORS headers (backend handles CORS, but verify)
3. Ensure error responses render with new styling

---

### Phase 6: Cross-Browser & Accessibility Audit
**Goal**: Production-ready quality.

**Tasks**:
1. Test in Chrome, Firefox, Safari (desktop + mobile)
2. Run Lighthouse: Performance, Accessibility, Best Practices, SEO ≥ 90
3. Keyboard navigation: all interactive elements reachable
4. Screen reader: NVDA/VoiceOver test key flows
5. Color contrast: all text meets WCAG AA (4.5:1 normal, 3:1 large)
6. Reduced motion: `prefers-reduced-motion` respected
7. Print styles: reports, emergency ID print correctly

**Acceptance Criteria**:
- [ ] Lighthouse scores ≥ 90 all categories
- [ ] Zero accessibility violations (axe-core)
- [ ] All focus states visible
- [ ] No layout shift (CLS < 0.1)

---

### Phase 7: Final Integration Testing
**Goal**: End-to-end verification.

**Test Scenarios**:
1. **New user**: Register → verify email → login → add medicine → set reminder → verify push
2. **Existing user**: Login → record vitals → view trends → upload report → share with doctor
3. **Doctor**: Login → set availability → view appointments → confirm/reject
4. **Caretaker**: Redeem code → view patient medicines → receive reminders
5. **Share flow**: Create share link → open in incognito → view records → claim to account
6. **Emergency ID**: Generate → print → scan QR → view public profile
7. **PWA**: Install → offline → open → verify cached data
8. **Dark mode**: Toggle → verify all pages → persist across sessions
9. **Language**: Toggle Nepali/English → verify i18n
10. **Responsive**: Test 320px, 768px, 1024px, 1440px, 1920px

**Acceptance Criteria**:
- [ ] All 10 scenarios pass without errors
- [ ] Backend API unchanged (no modifications to `/server`)
- [ ] Mobile app (`/mobile`) completely unaffected
- [ ] No regression in existing functionality

---

## Error Tracking: `UNKNOWN_ERRORS.md`

Create `/front/UNKNOWN_ERRORS.md` with this template:

```markdown
# Unknown Errors During UI Redesign

## Template
### [Date] - [Component/Page] - [Error Type]
**Error**: [Exact error message]
**Location**: [file:line]
**Root Cause**: [Analysis]
**Fix Applied**: [Solution or workaround]
**Status**: [Fixed / Workaround / Blocked]
**Related PR/Commit**: [Link if applicable]
```

Log ANY unexpected issue here immediately.

---

## Constraints & Guardrails

| Constraint | Enforcement |
|------------|-------------|
| **No backend changes** | `/server` directory is read-only |
| **No mobile app changes** | `/mobile` directory is read-only |
| **No API contract changes** | All fetch calls use same endpoints/params |
| **No functionality loss** | Every feature working pre-redesign must work post-redesign |
| **Responsive required** | Mobile-first, test 320px–1920px |
| **Dark mode required** | All pages, all components |
| **Accessibility required** | WCAG AA minimum |
| **Performance budget** | LCP < 2.5s, CLS < 0.1, TBT < 200ms |

---

## Deliverables

1. **Updated `/front`** with complete redesign
2. **`/front/UNKNOWN_ERRORS.md`** documenting all issues encountered
3. **Git commits** per phase (squashable for clean history)
4. **Verification checklist** (this document) signed off per phase

---

## Success Metrics

- ✅ All 218 backend tests still pass
- ✅ All frontend pages render without console errors
- ✅ All 10 E2E test scenarios pass
- ✅ Lighthouse ≥ 90 all categories
- ✅ Zero accessibility violations
- ✅ Visual match to mobile app design language
- ✅ Full responsiveness 320px–1920px
- ✅ Dark mode complete
- ✅ PWA functional
- ✅ Zero backend changes
- ✅ Zero mobile app changes