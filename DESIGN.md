# DESIGN.md — Visual Direction & Design System

## Identity & Aesthetic Reference
- **Reference**: [BitChord](https://github.com/kushagrasinghx/BitChord) (Apple Music-inspired modern mobile client).
- **Core Philosophy**: Clean, confident minimalism. Hierarchy driven by typography, whitespace, and tonal contrast rather than decorative clutter, heavy gradients, or floating drop-shadows.
- **Dials**:
  - `ENERGY`: **2 (Balanced)** — Calm, focused, and professional with crisp contrast and confident typography.
  - `RHYTHM`: **2 (Consistent with clear hierarchy)** — Inset grouped surfaces, consistent spacing scale, distinctive summary cards.
  - `MOTION`: **2 (Purposeful transitions)** — Smooth modal sheets, subtle tap states, no perpetual pulsing or looping animations.

## Color Palette (R-29: Max 2-3 Core + 1 Accent)
- **Background / Surface**:
  - Light: Clean neutral `#F8F9FA` / `#FFFFFF`.
  - Dark: Deep ink `#0E0D12` / `#16151D`.
- **Cards & Inset Groups**:
  - Light: Pure White `#FFFFFF` with hairline outline `#E5E7EB`.
  - Dark: Elevated dark surface `#1C1B24` with hairline outline `#2B2936`.
- **Accent**:
  - Dynamic Material You / BitChord tuned accent: `#7C5CFF` (Light) / `#9E8CFC` (Dark).
  - Purposeful application: Key interactive CTA, active navigation tab, primary metrics.
- **Financial Status Colors**:
  - Income (Money in): Emerald `#059669` (Light) / `#34D399` (Dark).
  - Outcome (Money out): Crimson `#DC2626` (Light) / `#F87171` (Dark).
- **Text Hierarchy**:
  - Primary: `#111827` (Light) / `#F3F4F6` (Dark) — High legibility (contrast > 10:1).
  - Secondary: `#6B7280` (Light) / `#9CA3AF` (Dark) — WCAG AA compliant (contrast > 4.5:1).

## Surfaces & Frosted Glass (R-10 Dose Cap)
- **Dose Cap**: At most 1-2 frosted elements on screen (Top Bar & Bottom Navigation Bar).
- **Treatment**: `BackdropFilter` with `ImageFilter.blur(sigmaX: 18, sigmaY: 18)` over a semi-transparent surface (`surface.withValues(alpha: 0.75)`).
- All cards and content containers remain solid matte surfaces.

## Typography (R-06)
- Clear sans-serif hierarchy with Apple Music-like weight progression:
  - Display / Hero Figures: 28–32sp, `FontWeight.w800`
  - Section Headers / Titles: 18–20sp, `FontWeight.w700`
  - Body Text & Row Titles: 15–16sp, `FontWeight.w500`
  - Captions, Timestamps & Labels: 12–13sp, `FontWeight.w400` / `w500`

## Components & Layout (R-05, R-11, R-14)
- **Inset Grouped Lists**: Multi-item lists sit together inside a single continuous card container with hairline inset dividers, eliminating repetitive individual card boxes.
- **Border Radius**: Defined scale:
  - Small: `10.0` (chips, badge pills)
  - Medium: `14.0` (inputs, buttons)
  - Card / Group: `18.0` (inset grouped cards)
  - Sheet / Modal: `24.0` (bottom sheets)
- **Navigation**: Clean frosted bottom navigation bar or prominent top segmented controls; no clunky hamburger drawers for primary actions.
