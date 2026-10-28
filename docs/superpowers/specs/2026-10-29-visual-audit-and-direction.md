# Visual audit and direction (2026-10-29)

**User verdict:** the mockups' design, colour, shape and visual organisation were better. The implemented app still "feels like AI slop".

**Method:** a hallmark-style audit of the real-device screenshots and all goldens against the approved mockups (`scratchpad/design/project/*.dc.html`, https://claude.ai/artifact/9XWrafgyMGLGomYHRED9M5). This document is binding for the visual rework. Functionality and backends are unchanged.

## Findings: 4 critical · 6 major · 3 minor

**Critical**

1. **The icon-tile card is the only component.** Settings has ~15 identical white bordered cards (pastel squircle icon + title + subtitle + trailing control), Routines 8, Better TV 6. This is the dominant AI tell.
   - At most 1–2 surfaces per screen.
   - Lists are plain rows on the canvas with 1 px warm hairlines (`#EADFD1`) and 20 px inline icons in ink or muted colour.
   - Icon tiles only for top-level navigation entries (Better TV's three destinations) and the hero.
2. **An eyebrow on every section** (uppercase tracked labels).
   - Remove them all.
   - Where a group needs a name, use a sentence-case Bricolage 18/700 heading with ≥24 px above it.
   - No uppercase tracking anywhere except inside the TV-card preview.
3. **The brand vanishes in dark mode.**
   - Cream light is the identity and the default, whatever the system setting.
   - Theme options: Light (default) / Bedtime dark after sunset / Always dark. "Follow phone" moves to the bottom of the list as an option and is not the default.
   - Migrate existing installs that never chose a theme to Light.
4. **Same template on every screen** (page title + subtitle + card stack). Each screen gets its own composition (§ Per-screen).

**Major**

5. **Oversized, chunky controls.** Pause 60 dp, duration chips 40 dp, quick actions one compact row of 4 (≤ 64 dp tall), switches standard size, steppers inline (− 5 +) at text size.
6. **2 px outlines everywhere.** 1 px hairlines or tonal fills; selected states use tint plus ink text, not thick borders.
7. **Settings info dump.** Settings = Your TVs · Look · Parent PIN · Notifications · Help. Advanced, capabilities, ADB key, baseline, debug and poll interval live on their own Advanced page.
8. **Beige segmented control for everything.** Use a radio list (one line per option) or 2–4 compact chips. Never a 2×2 segmented grid.
9. **Wordy helper text.** One line max under any control. The rest goes behind an ⓘ sheet.
10. **The TV card is plain text** (agent overlay). Build the mock: Tubby (mood by reason), Bricolage-like bold headline, soft navy radial gradient, dots, sub-line, "set by your family with boretube" footer.

**Minor**

- No emoji in UI chrome (☕ in the pill).
- The plan progress is a single thin bar plus "4 of 6", not segmented bars.
- Remove the big circle stepper buttons.

## Per-screen composition

- **Home (hero-led).** Header row (TV switcher + avatar). One sky-tinted hero surface (now playing, volume, status sentence, mode badge). Coral Pause TV at 60 dp. Quiet duration chips. One row of 4 compact quick actions with no card behind them. "Today" as plain lines on the canvas (no card). The plan as a slim card only until complete. Nudges as a slim inline banner, not a card.
- **Routines (day timeline).**
  - **Hero:** a 24-hour ribbon for today showing bedtime and quiet windows as sunflower bands, a "now" marker, and "TV time 2 h · Volume ≤ 30%" as a summary line.
  - **Presets:** a compact chip row.
  - **Rules:** plain rows on the canvas (Bedtime and quiet hours, Daily TV time, Allowed apps, Video hopping, Volume, Keep it silent, How the TV says no, Tonight only). Each row shows its current value on the right and opens a focused bottom sheet editor.
  - **Saving:** a slim ink save bar appears only when something changed.
  - **Without Always On:** "Lock for a while" is the hero and a sheet, with the Always On preview as one slim row.
- **Better TV (status report).** A big Tubby plus "All good" or "2 things to fix" headline (Bricolage 28) with Fix button(s), then ONE checklist list (hairlines). Three destination rows (YouTube without Shorts, Clean TV, Apps) with small icon tiles. The Always On dark ink surface is the only card. "Put the TV back the way it was" is a quiet text button at the bottom.
- **Settings (plain grouped list).** iOS/Things-like: group headings in sentence case, rows with hairlines, chevrons, almost no icons. Advanced goes on its own page.

## Copy and product changes carried in this pass

- The **Shorts** card becomes **Video hopping**, with modes Off / Gentle nudge (close + friendly card) / Cool-down (close + video apps closed 10 min) / Just tell me (report).
  - Rules doc: `shorts.mode` values map off→off, nudge→block, cooldown→cooldown, report→report.
  - Keep `budget` readable but not offered.
- **Today line:** "Video hopping stopped N× today" (from the journal).
- **Status sentence:** "YouTube without Shorts" instead of "Shorts off" unless hopping mode is on, in which case "Hopping guard on".
- **End-after chip:** when `remainingMs` > cap, show "In 45 min (55 left in this video)".

## Proportion system: one ratio for everything (user direction, 2026-10-29)

Everything below is derived from φ = 1.618 and its square root √φ ≈ 1.272. **Nothing is sized by eye.** Each value lives as a named token in `lib/ui/tokens.dart`, and screens reference tokens only.

- **Spacing (Fibonacci): 4 · 8 · 13 · 21 · 34 · 55.**
  - 13 is the gap inside a component.
  - 21 is between related components.
  - 34 is between sections.
  - 55 is around the hero.
  - Screen gutter: 21.
- **Type (√φ modular scale from 13):** 13 caption · 16.5 body · 21 headline · 26.5 title · 34 display · 43 hero numerals (countdown/clock) · 55 TV-card headline.
  - Bricolage for ≥ 21, Figtree below.
  - Line-height 1.3 on display, 1.5 on body.
- **Component heights (φ steps):** 34 small chip/badge · 44 secondary control (min touch 48 with padding) · 55 row / tile · 89 primary hero action band (Pause TV visual band; the button itself is 55–60).
  - A primary is φ× a secondary, and a secondary is φ× a chip. The hierarchy is visible by size alone.
- **Widths and proportions:**
  - The hero surface aspect is ≈ 1.618:1.
  - Split layouts are 61.8% / 38.2% (e.g. hero text vs TV illustration).
  - Equal siblings are equal width (quick-action row: 4 equal cells; chips: equal width in a row).
- **Radii (φ steps, reduced):** 8 chip · 13 control and row surface · 21 hero and sheet top.
- **Symmetry and alignment:**
  - Everything snaps to the 21 gutter and a 4-column grid.
  - Icons are optically centred (24 in a 44 control).
  - Text baselines in a row align.
  - Trailing values right-align to one edge across a list.
  - No orphaned single-width items in a row.
- **Hierarchy per screen:** exactly **one** primary (coral) action, ≤ 3 secondary actions at φ⁻¹ visual weight, everything else tertiary (text buttons, rows).
- **Motion (durations on φ steps): 120 · 200 · 320 · 520 ms.**
  - 120: press feedback (scale 0.97, opacity).
  - 200: state flips (tile → muted).
  - 320: sheets and hero state changes (calm → paused), easing `easeOutCubic` in, `easeInCubic` out.
  - 520: only the pause "dimming" and Tubby falling asleep.
  - List entrance stagger 34 ms, max 5 items.
  - No bounce on UI. No animate-on-scroll. Reduced motion → 120 ms crossfades.
  - Numbers tween over 320 ms with tabular figures.
