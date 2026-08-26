# Ayuvo — Design System

Phase 1.5 deliverable. Every screen built from here on references these tokens.
**No raw hex and no ad-hoc padding in a widget file, ever.**

Sources: `ui-ux-pro-max` (palette, type pairing, the 52-rule Flutter guideline set),
`frontend-design` (direction), `dataviz` (charts), with the generated system kept
verbatim at `design-system/ayuvo/MASTER.md` for reconciliation. Where this
document departs from that file, §9 says so and why.

---

## 1. The brief, stated

**Subject:** a personal health record for patients in Nepal — hospital ids like
`#hos014`, Bir and Patan and Grande, English and Nepali side by side.
**Audience:** an ordinary patient tracking medicines, vitals and lab reports; a
relative managing someone else's medicines; a doctor working an appointment list.
**The screen's one job:** *know what to do next about your health, and have your
records to hand when someone asks for them.*

That job is why the app is quiet. Nobody opens a health record to be delighted.
They open it because a doctor asked what they take, or because a reminder fired, or
because a number came back abnormal and they want to know whether it matters.

### The signature: the range bar

Every meaningful number in this product is judged against a band. A blood pressure
reading is not "128/82", it is "128/82, which is *elevated*". A lab result is a
value beside a reference range printed in a column next to it. That is the grammar
of the whole domain, borrowed from the paper report itself — and the current web app
throws it away, rendering a coloured pill that names a band without ever showing it.

So the one memorable element is a **range bar**: a 4dp track showing the normal
band as a filled segment, the reading as a marker on it, out-of-range values marked
by position rather than announced by colour.

```
Blood pressure                                     128/82 mmHg
        ┌───────────────────────────────────┐
   ─────┤███████████████████████████████████├──▲──────
        └───────────────────────────────────┘
        90                                140       180
                    ▲ Elevated
```

It appears in exactly three places — vitals tiles, lab findings rows, and as a
shaded normal band behind every trend line — and nowhere else. Everything around it
stays disciplined: flat cards, one accent, no gradients, no decorative motion.
**Spend the boldness once.**

### Direction against the defaults

The generated palette is medical cyan on a cyan-tinted background — correct for the
domain and, on its own, indistinguishable from every other health app. Three
deliberate moves keep it from reading as stock:

1. **The background is near-neutral, not tinted.** `#FBFCFD`, a cool off-white. A
   cyan-50 field (`#ECFEFF`) tints every card and competes with the data, which is
   the only thing on screen that should carry colour.
2. **Green is a status, never an action.** In a health app green means "this reading
   is fine". A green Save button would collide with that, so actions are cyan and
   green is reserved. One accent, used sparingly — as the brief asks.
3. **Numbers are tabular.** Every figure on a data screen uses
   `FontFeature.tabularFigures()` so columns align and a live countdown doesn't
   jitter. Small, but it is the difference between designed and templated.

---

## 2. Colour

Three layers: **primitive** (raw ramp steps) → **semantic** (role) → **component**
(mapped onto Flutter component themes, never per-widget arguments).

### 2.1 Primitives

Drawn from the `ui-ux-pro-max` healthcare palette (`Calm cyan + health green`) and
Tailwind's ramps for the neutral and status steps.

| Token | Hex | Note |
|---|---|---|
| `cyan600` | `#0891B2` | the skill's primary — kept for non-text accents |
| `cyan700` | `#0E7490` | filled actions and links (see §2.4) |
| `cyan800` | `#155E75` | pressed state |
| `cyanDark` | `#5CD3EC` | dark-mode primary |
| `emerald600` / `emerald700` | `#059669` / `#046A4E` | status: in range |
| `amber700` | `#8A4B08` | status: borderline |
| `red600` / `red700` | `#DC2626` / `#B91C1C` | status: out of range, and destructive |
| `ink900` … `ink500` | `#0F2B33` `#2C4A54` `#4A6670` | text, cool-cast neutrals |
| `paper` / `card` | `#FBFCFD` / `#FFFFFF` | light surfaces |
| `slate` | `#C3D4DA` | borders/dividers |
| `night` / `nightCard` | `#0F1417` / `#161D21` | dark surfaces |

### 2.2 Semantic roles — light

| Role | Hex | Contrast | Used for |
|---|---|---|---|
| `surface` | `#FBFCFD` | — | app background |
| `surfaceCard` | `#FFFFFF` | — | cards, sheets, list rows |
| `onSurface` | `#0F2B33` | **14.46:1** on surface | body text |
| `onSurfaceVariant` | `#4A6670` | **5.97:1** | labels, captions, secondary |
| `primary` | `#0E7490` | **5.36:1** with white | filled actions, links |
| `onPrimary` | `#FFFFFF` | | |
| `focusRing` | `#0891B2` | **3.58:1** non-text | focus / selection outline |
| `outline` | `#C3D4DA` | 1.49:1 | hairline borders |
| `error` | `#B91C1C` | **6.30:1** | destructive, validation |

### 2.3 Semantic roles — dark

Selected, not flipped. Each step is re-chosen against the dark surface.

| Role | Hex | Contrast |
|---|---|---|
| `surface` | `#0F1417` | — |
| `surfaceCard` | `#161D21` | — |
| `onSurface` | `#E6EEF1` | **15.77:1** |
| `onSurfaceVariant` | `#9DB2BA` | **8.40:1** |
| `primary` | `#5CD3EC` | **10.58:1** on surface |
| `onPrimary` | `#00323E` | **7.85:1** on primary |
| `error` | `#FF8A8A` | **8.17:1** |

### 2.4 Why primary is cyan-700 and not the skill's cyan-600

White on `#0891B2` measures **3.68:1** — it fails WCAG AA for button labels. The
generated system specifies exactly that pairing. Cyan-700 (`#0E7490`) carries the
same hue at **5.36:1**. Cyan-600 is kept for the focus ring, where the 3:1 non-text
threshold applies and it passes at 3.58:1.

### 2.5 Status — three colours and an arrow

The web app hard-codes six blood-pressure bands, four heart-rate bands, five sugar
bands, and so on — each with its own colour. That is a legend nobody can hold in
their head. Collapse it: **colour says how urgent, a glyph says which direction.**

| State | Light text | Light container | Dark text | Dark container | Glyph |
|---|---|---|---|---|---|
| `ok` — in range | `#046A4E` **6.44:1** | `#E3F6EE` **5.88:1** | `#4ADBA4` **10.56:1** | `#0C2A20` **8.74:1** | — |
| `caution` — borderline | `#8A4B08` **6.62:1** | `#FDF0DC` **6.04:1** | `#F0B252` **9.88:1** | `#2E2009` **8.44:1** | ▲ / ▼ |
| `alert` — outside range | `#B91C1C` **6.30:1** | `#FDE7E7** **5.47:1** | `#FF8A8A` **8.17:1** | `#33140F` **7.42:1** | ▲ / ▼ |

The band names the web shows (`Elevated`, `Stage 1 High`, `Hypothermia`, …) are kept
as **text**; they just stop each having a private colour. Never colour alone — every
status chip carries its label, and the range bar carries position.

Status colours are **reserved**. A chart series never uses green, amber or red.

### 2.6 Chart series — validated, not eyeballed

Assigned in fixed order, never cycled. Run through the `dataviz` validator:

| Slot | Light | Dark |
|---|---|---|
| 1 | `#0891B2` cyan | `#0A98BA` |
| 2 | `#7C3AED` violet | `#9363FF` |
| 3 | `#DB2777` pink | `#F60281` |
| 4 | `#2563EB` blue | `#4581FE` |

```
$ node scripts/validate_palette.js "#0891B2,#7C3AED,#DB2777,#2563EB" --mode light --surface "#FBFCFD"
  [PASS] Lightness band · [PASS] Chroma floor · [PASS] CVD separation (worst ΔE 15.0 deutan)
  [PASS] Normal-vision floor (ΔE 24.5) · [PASS] Contrast vs surface   → ALL CHECKS PASS

$ node scripts/validate_palette.js "#0A98BA,#9363FF,#F60281,#4581FE" --mode dark --surface "#0F1417"
  [PASS] all five                                                     → ALL CHECKS PASS
```

The dark steps were snapped to OKLCH L 0.63 (the dark band is 0.48–0.67, narrower
than light's 0.43–0.77 — hand-picked `-400` shades all failed it).

Only two charts in the product ever carry more than one series: blood pressure
(systolic + diastolic) and nothing else. Slots 3 and 4 exist so a future comparison
doesn't get invented on the spot.

---

## 3. Type

**Figtree** for headings, **Noto Sans** for body — the skill's `Medical Clean`
pairing. Noto Sans is not a default here, it is the requirement: the app ships
Nepali, and Noto is the only one of the two with Devanagari coverage. Figtree has
none, so **Nepali headings fall back to Noto Sans Devanagari** and the heading face
is Latin-only by design.

| Style | Size / line | Weight | Tracking | Face | Use |
|---|---|---|---|---|---|
| `displaySmall` | 32 / 40 | 600 | −0.5 | Figtree | a hero number, once per screen |
| `headlineMedium` | 24 / 32 | 600 | −0.3 | Figtree | screen title |
| `titleLarge` | 20 / 28 | 600 | −0.2 | Figtree | card title, sheet title |
| `titleMedium` | 16 / 24 | 600 | 0 | Figtree | list row title |
| `bodyLarge` | 16 / 24 | 400 | 0 | Noto Sans | body, form fields |
| `bodyMedium` | 14 / 20 | 400 | 0 | Noto Sans | secondary body |
| `bodySmall` | 12 / 16 | 400 | 0.1 | Noto Sans | captions, timestamps |
| `labelLarge` | 14 / 20 | 600 | 0.1 | Figtree | buttons |
| `labelSmall` | 11 / 16 | 600 | 0.5 | Figtree | eyebrows, chip text, uppercase |
| `numericLarge`¹ | 28 / 34 | 600 | −0.5 | Figtree + `tnum` | the reading on a vitals tile |
| `numericMedium`¹ | 16 / 22 | 600 | 0 | Figtree + `tnum` | table figures, dose times |

¹ In the `AppTypography` theme extension — Material 3 has no slot for "a number in a
table", and using `titleLarge` for it loses the tabular figures.

**Text scaling is honoured, not clamped.** Every screen must survive
`MediaQuery.textScaler` at 2.0; that is a review item at the end of every phase, and
the reason no tile has a fixed height.

---

## 4. Spacing — 4pt

| Token | dp | Use |
|---|---|---|
| `xxs` | 2 | icon-to-label inside a chip |
| `xs` | 4 | tight pairs |
| `sm` | 8 | inside a chip, between chips |
| `md` | 12 | list-row vertical padding |
| `lg` | 16 | **screen gutter**, card padding |
| `xl` | 24 | between sections |
| `xxl` | 32 | above a screen's first section, below its last |
| `xxxl` | 48 | empty-state vertical breathing room |

Density 6/10: `lg` gutters everywhere, `md` row rhythm on data-dense screens
(medicines, vitals history), `xl` between sections on reading screens.

Thumb reach: the primary action on any screen sits in the bottom third — a FAB, a
bottom-anchored filled button, or the last item in a bottom sheet. Never a top-right
"Save" as the only way forward.

---

## 5. Shape, elevation, motion

**Radius** — `sm` 8 (chips, inputs, buttons) · `md` 12 (cards) · `lg` 20 (bottom
sheets, dialogs) · `full` (avatars, the range-bar track).

**Elevation** — cards are **flat with a hairline border** (`outline`), not shadowed.
Shadow is reserved for things that genuinely float: bottom sheets (3), dialogs (3),
the FAB (2), a scrolled-under app bar (2). In dark mode elevation is a surface tint,
never a shadow — shadows are invisible on `#0F1417`.

**Motion** (skill dial 3/10, subtle):

| Token | ms | Curve | Use |
|---|---|---|---|
| `fast` | 120 | `easeOut` | press, ripple, chip toggle |
| `base` | 200 | `easeInOut` | expand, fade, sheet content |
| `slow` | 280 | `easeOutCubic` | route transition, sheet in |
| `exit` | 160 | `easeIn` | anything leaving — asymmetric, so back feels snappy |

No bounce, no spring, no parallax. `MediaQuery.disableAnimations` collapses every
duration to zero — checked in the accessibility pass, not assumed.

---

## 6. Component inventory

Each maps onto a Flutter **component theme**, not per-widget constructor arguments.

| Component | Theme | Spec |
|---|---|---|
| Card | `CardThemeData` | `surfaceCard`, radius `md`, hairline `outline`, elevation 0, margin 0 |
| Filled button | `FilledButtonThemeData` | `primary`/`onPrimary`, radius `sm`, height 48, `labelLarge` |
| Text button | `TextButtonThemeData` | `primary`, no fill, 44 min touch target |
| Destructive | `FilledButtonThemeData` (`.tonal` variant) | `error` container, used only for delete/revoke |
| Input | `InputDecorationTheme` | filled `surfaceCard`, radius `sm`, `outline` border, `focusRing` 2dp on focus, error text always visible |
| Chip | `ChipThemeData` | status container + status text, radius `full`, `labelSmall` |
| Bottom sheet | `BottomSheetThemeData` | radius `lg` top corners, drag handle, elevation 3 |
| Dialog | `DialogThemeData` | radius `lg`, `titleLarge` + `bodyMedium` |
| Bottom nav | `NavigationBarThemeData` | 5 destinations, `primary` indicator, always-visible labels |
| Snackbar | `SnackBarThemeData` | floating, radius `sm`, action in `primary` |
| Divider | `DividerThemeData` | `outline`, 1dp, no indent |

Plus four app-specific widgets with no Material equivalent, all theme-driven:

- **`RangeBar`** — the signature (§1). Track, normal band, marker, optional
  min/max labels.
- **`StatusChip`** — status container + label + optional direction glyph. Never
  colour alone.
- **`Skeleton`** — a shimmerless pulsing block at `outline` opacity. Loading states
  are skeletons shaped like the content, never a bare `CircularProgressIndicator`.
- **`EmptyState`** — icon, one line of what this screen is for, one action. Empty is
  an invitation to act, so the copy names the action: "Add your first medicine", not
  "No data".

### Three states, every async surface

Non-negotiable, and a review item each phase:

- **loading** — a skeleton in the shape of the result.
- **empty** — says what the screen is for and offers the one action that fills it.
- **error** — says what failed and offers Retry. Never "Something went wrong."
  A 401 is not an error state; it routes to sign-in with a message.

---

## 7. Writing

Sentence case everywhere. Active voice. A control names what happens: **Save
changes**, not Submit; **Share report**, not OK. The verb survives the whole flow —
a button that says *Revoke* produces a snackbar that says *Revoked*.

Errors do not apologise and are never vague: "Couldn't reach the server. Check your
connection and try again." Health copy carries no diagnosis — the AI surfaces keep
their disclaimers verbatim from the current product ("Educational check only —
always confirm with your doctor or pharmacist").

Caretaker context is always named on screen: "You're managing medicines for
**Ram**." A caretaker must never be able to mistake it for their own list.

---

## 8. Token mapping — CSS name → Dart name

So the generated system and the Flutter theme stay reconcilable.

| `MASTER.md` CSS var | Dart | Note |
|---|---|---|
| `--color-primary` `#0891B2` | `AppColors.focusRing` | demoted; see §2.4 |
| — | `ColorScheme.primary` `#0E7490` | added for AA |
| `--color-on-primary` | `ColorScheme.onPrimary` | |
| `--color-secondary` `#22D3EE` | *unused* | too light for anything at AA |
| `--color-accent` `#059669` | `AppStatus.ok` | re-scoped from CTA to status (§1) |
| `--color-background` `#ECFEFF` | *replaced* by `#FBFCFD` | see §1 |
| `--color-foreground` `#164E63` | `ColorScheme.onSurface` `#0F2B33` | re-stepped for 14:1 |
| `--color-muted` | `ColorScheme.surfaceContainerHighest` | |
| `--color-muted-foreground` | `ColorScheme.onSurfaceVariant` | |
| `--color-border` `#A5F3FC` | `ColorScheme.outline` `#C3D4DA` | cyan-200 was invisible as a border |
| `--color-destructive` | `ColorScheme.error` | |
| `--space-xs … --space-3xl` | `AppSpacing.xs … xxxl` | 4pt, one step denser |
| `--shadow-sm … xl` | `AppElevation` | mostly unused — see §5 |
| `--radius` (8/12/16) | `AppRadius.sm/md/lg` | |

---

## 9. Deliberate departures from the generated system

| Departure | Why |
|---|---|
| Primary cyan-700 not cyan-600 | white-on-cyan-600 is 3.68:1, below AA |
| Neutral background, not cyan-50 | a tinted field competes with the data |
| Green is status, not CTA | green already means "in range" in this domain |
| Flat cards with a hairline, not `shadow-md` | shadows on every card is 2016 Material; and they vanish in dark mode |
| No `translateY(-2px)` hover | there is no hover on a phone |
| Ignored the "Enterprise SaaS / indigo→violet gradient" style block | it contradicts the healthcare palette in the same file, and the file's own anti-patterns forbid AI purple gradients |
| Ignored the "App Store Style Landing" page pattern | this is an app, not its marketing page |
| Added tabular figures | the generated system has no opinion; data screens need it |
| Added a status scale and a chart palette | the generated system has neither, and this product is mostly numbers |

---

## 10. Review checklist — run at the end of every phase

Against `ui-ux-pro-max/data/stacks/flutter.csv` (52 rules, 16 of them High):

- [ ] `const` constructors wherever possible — **High**
- [ ] No `setState` in `build`; controllers, subscriptions and `AnimationController`s
      disposed — **High** ×3
- [ ] `ListView.builder` for every list; keys on stateful rows — **High** ×2
- [ ] `PopScope`, never the deprecated `WillPopScope` — **High**
- [ ] Every async surface handles loading **and** error, not just success — **High**
- [ ] Forms validate on submit; text controllers disposed — **High** ×2
- [ ] Rebuild scope isolated — no `setState` on a parent to change a leaf — **High**
- [ ] `Semantics` on non-obvious controls; screen-reader pass — **High** ×2
- [ ] Text scaling to 2.0 without clipping — **High**
- [ ] `Theme.of(context)` for every colour and text style — **no raw hex, no bare
      `TextStyle`, no ad-hoc padding number**
- [ ] Light **and** dark verified on every screen
- [ ] Charts: validator re-run if any series colour changed; legend present for ≥2
      series; status colours never used for a series; one y-axis only
