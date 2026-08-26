# Ayuvo Web — Design System (Phase 1 deliverable)

Date: 2026-08-14. Stack: Next.js 16, React 19, Tailwind CSS v4 (`@theme` in
`app/globals.css`), `lucide-react`, `recharts`.

Sources, in order: `mobile/DESIGN.md` (the shipped, reconciled source of truth) →
`mobile/design-system/ayuvo/MASTER.md` → `front/design-system/ayuvo-web/MASTER.md`
(generated 2026-08-14). The generated web master is the base; every deviation is
in §8. No raw hex and no ad-hoc spacing in a component file, ever — tokens only.

---

## 1. Colour — primitives

| Token | Hex | Used for |
|---|---|---|
| `cyan-600` | `#0891B2` | focus rings only (3.58:1 non-text; fails AA as text/bg) |
| `cyan-700` | `#0E7490` | **primary** — filled actions, links, active nav (5.36:1 on white) |
| `cyan-800` | `#155E75` | primary pressed state |
| `cyan-dark` | `#5CD3EC` | dark-mode primary |
| `ink-900` | `#0F2B33` | onSurface |
| `ink-700` | `#4A6670` | onSurfaceVariant |
| `paper` | `#FBFCFD` | light surface (near-neutral, cool) |
| `card` | `#FFFFFF` | light card surface |
| `slate` | `#C3D4DA` | hairlines, dividers |
| `night` | `#0F1417` | dark surface |
| `night-card` | `#161D21` | dark card surface |
| `night-slate` | `#2E3E45` | dark hairlines |

## 2. Semantic roles

### Light

| Role | Hex | Contrast | Use |
|---|---|---|---|
| `surface` | `#FBFCFD` | — | app background |
| `surface-card` | `#FFFFFF` | — | cards, rows, inputs |
| `on-surface` | `#0F2B33` | 14.46:1 | body text |
| `on-surface-variant` | `#4A6670` | 5.97:1 | labels, captions, secondary |
| `primary` | `#0E7490` | 5.36:1 w/ white | actions, links |
| `on-primary` | `#FFFFFF` | — | |
| `focus-ring` | `#0891B2` | 3.58:1 non-text | focus outline |
| `outline` | `#C3D4DA` | 1.49:1 (hairline) | borders |
| `error` | `#B91C1C` | 6.30:1 | destructive, validation |

### Dark (selected, not flipped)

| Role | Hex | Contrast |
|---|---|---|
| `surface` | `#0F1417` | — |
| `surface-card` | `#161D21` | — |
| `on-surface` | `#E6EEF1` | 15.77:1 |
| `on-surface-variant` | `#9DB2BA` | 8.40:1 |
| `primary` | `#5CD3EC` | 10.58:1 on surface |
| `on-primary` | `#00323E` | 7.85:1 on primary |
| `error` | `#FF8A8A` | 8.17:1 |
| `focus-ring` | `#5CD3EC` | ≥3:1 non-text on dark |
| `outline` | `#2E3E45` | hairline on `#161D21` |

### Status — three states, never colour alone

Colour says urgency; a glyph says direction; the band name stays as text.

| State | Light text | Light container | Dark text | Dark container | Glyph |
|---|---|---|---|---|---|
| `ok` in range | `#046A4E` 6.44:1 | `#E3F6EE` | `#4ADBA4` | `#0C2A20` | — |
| `caution` borderline | `#8A4B08` 6.62:1 | `#FDF0DC` | `#F0B252` | `#2E2009` | `ArrowUp`/`ArrowDown` (lucide, 14px) |
| `alert` outside | `#B91C1C` 6.30:1 | `#FDE7E7` | `#FF8A8A` | `#33140F` | `ArrowUp`/`ArrowDown` (lucide, 14px) |

`ok` carries no glyph — calm by default. Direction is *trend*, not mere value:
the glyph points toward the band the value moved into (the 5 analyzers on vitals
already know this; `lib/status.ts` will formalise it).

Status colours are reserved: **never** used for chart series or actions.

### Chart series — fixed order, never cycled

| Slot | Light | Dark |
|---|---|---|
| 1 | `#0891B2` | `#0A98BA` |
| 2 | `#7C3AED` | `#9363FF` |
| 3 | `#DB2777` | `#F60281` |
| 4 | `#2563EB` | `#4581FE` |

Legend shown for any chart with ≥2 series. Only BP has two series.

## 3. Type

Faces loaded with `next/font/google` (self-hosted at build — PWA offline-safe):
- **Figtree** — display face, Latin only. Subsets: `latin`.
- **Noto Sans** — body, full Devanagari. Subsets: `latin`, `devanagari`.
- Nepali headings fall back to Noto Sans (Figtree has no Devanagari).

| Style | Size/line | Weight | Tracking | Face | Use |
|---|---|---|---|---|---|
| `display` | 32/40 | 600 | −0.5 | Figtree | hero number, once per screen |
| `headline` | 24/32 | 600 | −0.3 | Figtree | screen title |
| `title-lg` | 20/28 | 600 | −0.2 | Figtree | card / sheet title |
| `title` | 16/24 | 600 | 0 | Figtree | list row title |
| `body` | 16/24 | 400 | 0 | Noto Sans | body, form fields (min 16px) |
| `body-sm` | 14/20 | 400 | 0 | Noto Sans | secondary body |
| `caption` | 12/16 | 400 | 0.1 | Noto Sans | timestamps, captions |
| `label` | 14/20 | 600 | 0.1 | Figtree | buttons, chips |
| `eyebrow` | 11/16 | 600 | 0.5 | Figtree | eyebrows, uppercase |
| `numeric-lg` | 28/34 | 600 | −0.5 | Figtree + tnum | the reading on a tile |
| `numeric` | 16/22 | 600 | 0 | Figtree + tnum | table figures, dose times |

**Every number on a data screen gets `tabular-nums`** (Tailwind utility), so
columns align and live values don't jitter.

## 4. Spacing — 4pt

| Token | px | Use |
|---|---|---|
| `xxs` | 2 | icon-to-label inside a chip |
| `xs` | 4 | tight pairs |
| `sm` | 8 | inside chips, between chips |
| `md` | 12 | list-row vertical padding |
| `lg` | 16 | **screen gutter**, card padding |
| `xl` | 24 | between sections |
| `xxl` | 32 | above a screen's first section |
| `xxxl` | 48 | empty-state breathing room |

Tailwind map: `space-1 = xs(4)` … so component code uses named tokens
(`p-lg`, `gap-sm`) from the `@theme` below, never bare numbers. Interactive
targets ≥ 44px, ≥ 8px between interactive elements.

## 5. Shape, elevation, motion

**Radius**: `sm` 8 (buttons, inputs, chips) · `md` 12 (cards) · `lg` 20 (dialogs,
sheets) · `full` (chips, range-bar track, avatars).

**Elevation**: cards are flat with a hairline border, no shadow. Shadows only for
things that float:

| Token | Value | Use |
|---|---|---|
| `shadow-float` | `0 2px 8px rgba(15,43,51,0.12)` | FAB |
| `shadow-pop` | `0 8px 24px rgba(15,43,51,0.16)` | dialogs, dropdowns, mobile menu |

Same tokens in dark (black-based alpha reads on `#0F1417`; a light tint would be
invisible — departure from mobile's "surface tint", which has no web equivalent).

**Motion** (CSS only — no gsap/framer):

| Token | ms | Curve | Use |
|---|---|---|---|
| `fast` | 120 | easeOut | press, chip toggle |
| `base` | 200 | easeInOut | expand, fade |
| `slow` | 280 | easeOut | panel in |
| `exit` | 160 | easeIn | anything leaving |

No bounce, no parallax, no `translateY` hover lifts. `prefers-reduced-motion`
collapses all transitions to zero (`@media (prefers-reduced-motion: reduce)`).

## 6. The signature — RangeBar

```
Blood pressure                                  128/82 mmHg
        ┌───────────────────────────────────┐
   ─────┤███████████████████████████████████├──▲──────
        └───────────────────────────────────┘
        90                                140       180
                    ▲ Elevated
```

Spec (web): 4px track, `full` radius, track colour = `outline` at 40%; **normal
band** = filled segment in `primary` at 25% opacity (never status green — the
band is a reference, not a verdict); **marker** = 12px dot in `on-surface` with a
2px `surface-card` ring, positioned by value (clamped to the track); min/max
labels `caption` + `tabular-nums` under the ends, band name + status chip beside
the value.

Appears in exactly three places — vitals tiles, lab findings rows, shaded normal
band behind trend lines — and nowhere else.

## 7. Component inventory

All tokens only; implemented as new files (frozen `components/button.tsx` /
`components/card.tsx` untouched).

| Component | Spec |
|---|---|
| `Button` | variants: primary (cyan-700, `on-primary`), secondary (1px `primary` border, `primary` text), ghost (no fill, `primary`), destructive (`error` bg / outlined `error`); radius `sm`; height 44 (sm 36); `label` type; loading state replaces label with spinner; disabled 40% opacity; focus = `focus-ring` 2px ring |
| `Card` | `surface-card`, radius `md`, hairline `outline`, padding `lg`, no shadow; variant `padding-none` for list rows |
| `Input` | label `label`, field `body` 16px (prevents iOS zoom), bg `surface-card`, radius `sm`, `outline` border, `focus-ring` 2px on focus; hint `caption`; error text always visible below field, `error` colour |
| `StatusChip` | status container + status text + optional direction glyph; radius `full`; `label` type; **never** colour alone |
| `RangeBar` | §6 |
| `Skeleton` | pulsing block, `outline` at 40% opacity, no shimmer sweep; shapes the result it replaces |
| `EmptyState` | icon (lucide), one line saying what the screen is for, one action that fills it |
| `Dialog` | overlay `rgba(0,0,0,0.5)`, panel radius `lg`, `shadow-pop`, title `title-lg` + body; focus trapped; used for destructive confirmations |
| `ListRow` | row: title `title`, meta `body-sm` variant, trailing status chip / value `numeric`; hairline divider |

**Three states, every async surface**: loading = skeleton shaped like the result;
empty = what the screen is for + the one action; error = what failed + Retry —
never "Something went wrong". 401 is not an error state: route to sign-in with a
message.

## 8. Deliberate departures

### From the generated web master (`front/design-system/ayuvo-web/MASTER.md`)

| Departure | Why |
|---|---|
| Primary cyan-600 `#0891B2` → cyan-700 `#0E7490` | white on cyan-600 is 3.68:1, fails AA for button labels |
| Background `#ECFEFF` → `#FBFCFD` | a cyan-tinted field competes with the data |
| Accent green `#059669` demoted to status | green already means "in range" here; never a CTA |
| Atkinson Hyperlegible → Figtree + Noto Sans | mobile pairing (DESIGN.md §3); Noto is the only Devanagari-capable option — the app ships Nepali |
| Neumorphism style block ignored | contradicts the healthcare palette in the same file; soft inner shadows on a health record read as decoration |
| "Hero + Testimonials + CTA" pattern ignored | constraint: no fabricated testimonials; the hero carries a real artifact instead |
| GSAP scroll-reveal ignored | constraint: no new dependencies; CSS-level subtle motion only |
| Shadowed cards → flat + hairline | shadows on every card vanish in dark mode and read as 2016 Material |
| No `translateY(-2px)` hovers | layout-shifting hovers are forbidden by the master's own anti-patterns |
| Added tabular figures, status scale, chart palette | the generated system has none; this product is mostly numbers |

### From mobile (`mobile/DESIGN.md`)

| Departure | Why |
|---|---|
| Bottom sheets → Dialog / floating panel | sheets exist on phones; on web the equivalent is a modal or dropdown — same radius `lg`, same elevation |
| Thumb-reach rule → 44px targets + primary action visible without scroll | web has no thumb; the rule becomes target size and action placement |
| `FontFeature.tabularFigures()` → `tabular-nums` | same intent, CSS mechanism |
| Dark elevation "surface tint" → `shadow-pop` with black-based alpha | web has no elevation-tint affordance; a black-based shadow reads on `#0F1417` |

## 9. `@theme` translation (globals.css, Phase 2)

```css
@import "tailwindcss";
@custom-variant dark (&:where(.dark, .dark *));

@theme {
  /* fonts */
  --font-sans: "Noto Sans", ...;       /* body — full Devanagari */
  --font-display: "Figtree", ...;      /* headings — Latin only */

  /* light surface + text */
  --color-surface: #FBFCFD;
  --color-surface-card: #FFFFFF;
  --color-on-surface: #0F2B33;
  --color-on-surface-variant: #4A6670;
  --color-outline: #C3D4DA;

  /* primary */
  --color-primary: #0E7490;
  --color-on-primary: #FFFFFF;
  --color-primary-pressed: #155E75;
  --color-focus-ring: #0891B2;

  /* status */
  --color-ok: #046A4E;   --color-ok-container: #E3F6EE;
  --color-caution: #8A4B08; --color-caution-container: #FDF0DC;
  --color-alert: #B91C1C; --color-alert-container: #FDE7E7;
  --color-error: #B91C1C;

  /* chart series (light) */
  --color-series-1: #0891B2; --color-series-2: #7C3AED;
  --color-series-3: #DB2777; --color-series-4: #2563EB;

  /* spacing (4pt, named) */
  --spacing-xxs: 2px; --spacing-xs: 4px; --spacing-sm: 8px;
  --spacing-md: 12px; --spacing-lg: 16px; --spacing-xl: 24px;
  --spacing-xxl: 32px; --spacing-xxxl: 48px;

  /* radius */
  --radius-sm: 8px; --radius-md: 12px; --radius-lg: 20px;

  /* elevation — floating things only */
  --shadow-float: 0 2px 8px rgba(15,43,51,0.12);
  --shadow-pop: 0 8px 24px rgba(15,43,51,0.16);

  /* motion */
  --ease-out: cubic-bezier(0.16, 1, 0.3, 1);
  --ease-in-out: cubic-bezier(0.45, 0, 0.55, 1);
  --ease-in: cubic-bezier(0.55, 0, 1, 0.45);
  --duration-fast: 120ms; --duration-base: 200ms;
  --duration-slow: 280ms; --duration-exit: 160ms;
}

/* dark — selected values, not flips */
.dark {
  --color-surface: #0F1417; --color-surface-card: #161D21;
  --color-on-surface: #E6EEF1; --color-on-surface-variant: #9DB2BA;
  --color-outline: #2E3E45;
  --color-primary: #5CD3EC; --color-on-primary: #00323E;
  --color-primary-pressed: #7DDEF1; --color-focus-ring: #5CD3EC;
  --color-ok: #4ADBA4; --color-ok-container: #0C2A20;
  --color-caution: #F0B252; --color-caution-container: #2E2009;
  --color-alert: #FF8A8A; --color-alert-container: #33140F;
  --color-error: #FF8A8A;
  --color-series-1: #0A98BA; --color-series-2: #9363FF;
  --color-series-3: #F60281; --color-series-4: #4581FE;
}
```

Notes: Tailwind v4 emits `@theme` vars on `:root`; the `.dark` block re-declares
them on the `.dark` class, so `bg-surface-card` etc. flip automatically. The old
`.dark .bg-gray-*` scope-override block stays until a page is migrated, then is
deleted progressively (Phase 2 → 4). `tabular-nums`, `max-sm:` etc. come from
Tailwind's own utilities.

## 10. Review checklist — every phase

- [ ] No raw hex in components; tokens only; no ad-hoc padding
- [ ] No emojis as icons — lucide-react only
- [ ] 44px targets, 8px spacing between interactive elements
- [ ] 3 states on every async surface; 401 → sign-in, not an error
- [ ] Light + dark verified; ≥4.5:1 text contrast; focus visible; reduced-motion
- [ ] Numbers tabular; charts use the series palette, legend when ≥2 series,
      status colours never used for series
- [ ] en/ne: Devanagari rendering verified (Noto Sans)
- [ ] Caretaker scope named on screen; `scopedUrl` everywhere; server diff zero