---
name: Obsidian Cyber-Glass
colors:
  surface: '#10131a'
  surface-dim: '#10131a'
  surface-bright: '#363941'
  surface-container-lowest: '#0b0e15'
  surface-container-low: '#191b23'
  surface-container: '#1d1f27'
  surface-container-high: '#272a32'
  surface-container-highest: '#32353d'
  on-surface: '#e1e2ec'
  on-surface-variant: '#b9cacb'
  inverse-surface: '#e1e2ec'
  inverse-on-surface: '#2d3038'
  outline: '#849495'
  outline-variant: '#3b494b'
  surface-tint: '#00dbe9'
  primary: '#dbfcff'
  on-primary: '#00363a'
  primary-container: '#00f0ff'
  on-primary-container: '#006970'
  inverse-primary: '#006970'
  secondary: '#dcb8ff'
  on-secondary: '#480081'
  secondary-container: '#7701d0'
  on-secondary-container: '#dcb7ff'
  tertiary: '#d8ffe7'
  on-tertiary: '#003824'
  tertiary-container: '#65f2b5'
  on-tertiary-container: '#006d4a'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#7df4ff'
  primary-fixed-dim: '#00dbe9'
  on-primary-fixed: '#002022'
  on-primary-fixed-variant: '#004f54'
  secondary-fixed: '#efdbff'
  secondary-fixed-dim: '#dcb8ff'
  on-secondary-fixed: '#2c0051'
  on-secondary-fixed-variant: '#6700b5'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#10131a'
  on-background: '#e1e2ec'
  surface-variant: '#32353d'
typography:
  display:
    fontFamily: Outfit
    fontSize: 40px
    fontWeight: '700'
    lineHeight: 48px
    letterSpacing: -0.03em
  headline-lg:
    fontFamily: Outfit
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 38px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Outfit
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 30px
    letterSpacing: -0.015em
  headline-sm:
    fontFamily: Outfit
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 26px
    letterSpacing: -0.01em
  body-lg:
    fontFamily: Outfit
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
    letterSpacing: -0.005em
  body-md:
    fontFamily: Outfit
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
    letterSpacing: 0em
  body-sm:
    fontFamily: Outfit
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
    letterSpacing: 0.01em
  numeric-hero:
    fontFamily: Outfit
    fontSize: 36px
    fontWeight: '700'
    lineHeight: 40px
    letterSpacing: -0.03em
  label-code:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.06em
  label-sm:
    fontFamily: Outfit
    fontSize: 11px
    fontWeight: '600'
    lineHeight: 14px
    letterSpacing: 0.04em
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  space-2xs: 0.25rem
  space-xs: 0.5rem
  space-sm: 0.75rem
  space-md: 1rem
  space-lg: 1.25rem
  space-xl: 1.5rem
  space-2xl: 2rem
  space-3xl: 2.5rem
  margin-mobile: 1.25rem
  gutter-mobile: 0.75rem
---

## Brand & Style

This design system blends futuristic precision with minimalist restraint. Tailored for a next-generation personal wealth engine powered by conversational intelligence, the visual identity embodies absolute digital sovereignty, financial lucidity, and frictionless intelligence.

The emotional objective is commanding calm: eliminating the anxiety of traditional budgeting through an atmosphere of crystalline, high-tech control. Key characteristics include:
- **Obsidian Foundations:** Inky, deep space canvas (#0A0D14) with subtle structural dark-indigo surfaces (#121826) that absorb ambient distraction.
- **Cyber-Luminescence:** Targeted chromatic energy via high-voltage Cyan and Electric Violet, signaling synthesis, intelligence, and active financial velocity.
- **Frosted Specular Glass:** Hyper-refined translucency, inner glass bevels, and crisp micro-borders (`rgba(255, 255, 255, 0.08)`) that layer depth without introducing visual noise.
- **Instrument-Grade Clarity:** Crisp typography and delicate geometry that render numeric and conversational data with authoritative elegance.

## Colors

The palette operates strictly on dark polarity. It relies on deep obsidian depths punctuated by crystalline luminescence and semantic telemetry.

### Core Foundation
- **Canvas Base:** `#0A0D14` (Deep Obsidian) - Total backdrop, void-like and immersive.
- **Surface Elevation 1:** `#121826` (Midnight Carbon) - Structural cards, sheets, and baseline surface modules.
- **Surface Elevation 2 (Glass):** `rgba(18, 24, 38, 0.70)` - Floating elements layered with `backdrop-filter: blur(24px)`.
- **Surface Elevation 3 (Active Glass):** `rgba(255, 255, 255, 0.04)` - Inner card wells, conversational prompt modules, and input surfaces.

### Accents & Signatures
- **Primary (Electric Cyan):** `#00F0FF` (Interactive primary, system prompts, conversational focal points). Hover/Pressed state: `#00D2FF`.
- **Secondary (Electric Violet):** `#8A2BE2` (AI synthesis engine, dynamic gradients, predictive state badges). Tint: `#A855F7`. Deep: `#7B2CBF`.
- **Tertiary (Quantum Emerald):** `#10B981` (Inflows, positive net worth deltas, verified assets). Glow variant: `rgba(16, 185, 129, 0.15)`.
- **Negative (Crimson Rose):** `#F43F5E` (Outflows, velocity warnings, budget thresholds). Glow variant: `rgba(244, 63, 94, 0.15)`.

### Glass & Borders
- **Glass Stroke Standard:** `rgba(255, 255, 255, 0.08)`
- **Glass Stroke Highlight:** `rgba(255, 255, 255, 0.16)` (Top/Left inner specular edge)
- **Cyan Glow Accent:** `rgba(0, 240, 255, 0.25)` (Active states and AI conversational cues)

## Typography

The type system pairs the architectural, geometric presence of **Outfit** for headlines, prose, and conversational UI with **JetBrains Mono** for precision-driven telemetry, timestamps, currency symbols, and cryptographic tickers.

### Hierarchy Guidelines
- **Numeric & Financial Displays:** Financial totals employ `numeric-hero` with tabular numbers (`font-variant-numeric: tabular-nums`) to prevent horizontal jitter during real-time balance calculations.
- **Conversational Bubble Hierarchy:** The AI assistant uses `body-lg` in pure white (`#FFFFFF`) with balanced 1.5 line-height for effortless reading on dark backgrounds. User prompts utilize `body-md` in `#94A3B8`.
- **Metadata & Telemetry:** All transaction categories, audit states, and technical metadata default to `label-code` in uppercase tracking (`letter-spacing: 0.06em`) using JetBrains Mono.

## Layout & Spacing

The mobile layout system targets a standard 390px viewport width (iPhone standard baseline) with strict vertical rhythm and ergonomic thumb-reach zones.

### Grid & Margins
- **Device Viewport Width:** 390px fluid bounding box (`max-width: 440px` centered on larger devices).
- **Lateral Screen Padding:** `margin-mobile` (1.25rem / 20px) keeping UI cards inset from display bezels.
- **Module Separation:** Consistent vertical rhythm of `space-lg` (20px) between card modules; `space-xs` (8px) between correlated internal metadata items.

### Reach & Interaction Zones
- **Bottom Navigation / AI Command Dock:** Fixed to the bottom thumb zone with 16px bottom safe area inset. The AI chat entry floats 12px above bottom navigation.
- **Conversational Flow:** Messages cascade upwards from the bottom input dock, anchoring high-frequency user actions within comfortable reach.

## Elevation & Depth

Depth is established via optical illumination rather than heavy opaque drop shadows. The system uses layered glassmorphism, multi-point luminescence, and micro-borders.

### The Glass Surface Architecture
1. **Level 0 (Void):** Solid `#0A0D14`. Background features radial, low-opacity gradient orbs (`rgba(138, 43, 226, 0.08)` and `rgba(0, 240, 255, 0.05)`) positioned dynamically behind critical metrics or AI actions.
2. **Level 1 (Card Matrix):** Surface `#121826` with `backdrop-filter: blur(20px)` and an outer 1px border of `rgba(255, 255, 255, 0.08)`.
3. **Level 2 (Floating Conversational & Action Panels):** Background `rgba(22, 30, 48, 0.75)`, `backdrop-filter: blur(32px)`, bordered by a linear gradient stroke ranging from `rgba(255, 255, 255, 0.18)` at the top-left to `rgba(255, 255, 255, 0.02)` at the bottom-right.
4. **Level 3 (Interactive Glowing Elements):** Neon accent shadows.
   - *Primary Cyan Active:* `box-shadow: 0 0 24px -4px rgba(0, 240, 255, 0.35), 0 8px 16px -6px rgba(0, 240, 255, 0.2)`
   - *AI Violet Aura:* `box-shadow: 0 0 30px -4px rgba(138, 43, 226, 0.40)`

## Shapes

The interface embraces organic, pebble-smooth contours that balance futuristic geometry with human tactile warmth.

- **Primary Cards & Containers:** Standardized at `rounded-2xl` (16px) to `rounded-3xl` (24px). Hero net worth panels and modal sheets utilize 24px corner radii for smooth containment.
- **Interactive Controls & AI Chips:** Strictly pill-shaped (`rounded-full` / 9999px) to indicate complete affordance for tapping, filtering, and voice prompting.
- **Micro UI & Indicators:** Checkboxes, mini telemetry tags, and inline charts preserve a tight `rounded-md` (8px) radius.

## Components

### 1. Buttons
- **Primary Cyber-Action (CTA):** Pill-shaped, background `linear-gradient(135deg, #00F0FF 0%, #00B4D8 100%)`, text color `#0A0D14` (semi-bold 14px), with a persistent diffuse glow `0 0 18px rgba(0, 240, 255, 0.3)`. On press: scale transform down to `0.97` with brightness reduced to `90%`.
- **Secondary AI Action:** High-gloss translucent glass (`rgba(138, 43, 226, 0.15)`), border: `1px solid rgba(168, 85, 247, 0.4)`, text: `#FFFFFF`. On press: border surges to `#00F0FF` with an inner radial pulse.
- **Ghost Utility:** Borderless, text `#94A3B8`, icon-centric with 40x40px touch targets.

### 2. Conversational AI Assistant Elements
- **Assistant Message Shell:** Bordered container (`background: rgba(18, 24, 38, 0.85)`), top-left corner radius 4px, other corners 20px. Embedded 1px top highlight simulating overhead light. Left margin holds an animated, breathing 6px glowing Cyan-Violet status dot.
- **User Prompt Shell:** Aligned right, background `linear-gradient(135deg, #7B2CBF 0%, #5A189A 100%)`, text `#FFFFFF`, corner radius 20px with bottom-right corner 4px.
- **Streaming Cursor:** 2px wide, 14px high `#00F0FF` bar pulsing at 1Hz.

### 3. Financial Metric Cards
- Base surface `rgba(18, 24, 38, 0.8)` with frosted glass blur.
- Top-right corner includes metric delta badges:
  - **Inflow (Green):** Background `rgba(16, 185, 129, 0.12)`, text `#10B981`, pill shape, 11px JetBrains Mono.
  - **Outflow (Rose):** Background `rgba(244, 63, 94, 0.12)`, text `#F43F5E`, pill shape, 11px JetBrains Mono.
- Ambient graph: Embedded SVG sparkline under the metric using a faint glowing stroke (`#00F0FF`) with a vertical gradient fading to transparent.

### 4. Interactive Chips & Prompt Suggestions
- Height: 32px.
- Background: `rgba(255, 255, 255, 0.05)`.
- Border: `1px solid rgba(255, 255, 255, 0.1)`.
- Text: 12px `#E2E8F0`.
- Behavior: Horizontal scroll row with snap; tapping triggers an immediate conversational query injection with a quick flash of primary cyan.

### 5. Input Fields & Conversational Input Bar
- Floating dock anchored above the bottom safe area.
- Integrated voice trigger (Phosphor/Lucide microphone icon in subtle violet ring) on the right edge.
- Background: `rgba(14, 19, 31, 0.95)` with `backdrop-filter: blur(20px)` and a subtle ambient outer shadow.
- Border: `1px solid rgba(255, 255, 255, 0.12)`. When focused: border switches to a gradient border (`#00F0FF` to `#8A2BE2`) and outer cyan micro-glow.
- Placeholder text: `#64748B`.

### 6. Lists & Transaction Rows
- Dividers are eliminated in favor of 8px vertical gaps between discrete glass tile items.
- Left slot: 40x40px category icon tile (`rounded-xl`, `background: rgba(255,255,255,0.03)` with thin line icon colored according to category).
- Center: Transaction name (`Outfit 14px Medium #FFFFFF`) with timestamp/metadata (`JetBrains Mono 11px #64748B`).
- Right: Monetary balance using tabular figures (`Outfit 15px SemiBold`), colored `#10B981` with leading `+` for inflows or `#FFFFFF` with leading `-` for outflows.