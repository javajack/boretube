# boretube redesign: consumer UX (P3-UX)

Date: 2026-10-29. Status: approved. Mockups: https://claude.ai/artifact/9XWrafgyMGLGomYHRED9M5 (private canvas; it sets the look, and this spec takes precedence where they differ).

**Scope.** This redesign reorganises and restyles the Flutter app (`boretube-mobile/`) for non-technical parents. Every existing feature keeps a home (§7), and the backends stay as they are (`lib/adb`, `ops`, `actions`, `agent`, `discovery`, `tv`, `providers`). The only new behaviour is (a) a background check that notifies when Always On drops, and (b) "End after this one" (§8), which is gated on a device spike.

## 1. Product framing

- **Name:** "boretube · Android TV parental controls". Tagline: *Calmer TV. Fewer fights. No Shorts.*
- **Three pillars, one per tab:**
  - **Home** (right now): Pause TV, Quiet, End app, Volume, ⋯ Make it boring / Sound back on, plus the Today strip and the plan.
  - **Routines**: Always On rules, or "Lock for a while".
  - **Better TV**: YouTube without Shorts, Clean TV, Apps, TV health, Always On, Restore.
- **Settings** sits behind the avatar.
- **Protection levels,** in parent language. These words are never "ADB", "agent" or "Cast":
  - **Remote**: Cast only.
  - **Home mode**: ADB.
  - **Always On**: TV Guard.
- **Status sentence + mode badge** are always visible. Degraded states are said in plain words, with a single button that fixes them.
- **The TV says no, not the parent:** the friendly-message style uses Tubby on the TV card. "Make it boring" is an optional trick, not the brand.

## 2. Onboarding

1. Welcome (one screen).
2. Find TV (auto: mDNS/SSDP/sweep, with manual entry).
3. **First win**: "Say hi to your TV, tap to mute it", over Cast. It needs no setup, celebrates, then offers Unmute.
4. Parent PIN (+ fingerprint).
5. "What's bugging you?": Shorts, bedtime, loud, ads, apps. The answers are stored and order the plan.

The home plan checklist is ordered by those goals:

- Control from phone ✓
- Unlock Home mode
- YouTube without Shorts
- Clean up your TV
- Set bedtime
- Turn on Always On

**Helper-switch guide (ADB):**
- It starts with a *why* card and the Restore promise.
- Then come one-action "Do this on the TV now" cards, using a mocked TV menu with the target row highlighted and a pulsing remote key.
- For the 7 OK presses there is a tap counter the parent advances.
- **Live detection** reuses `CapabilityProber` polling, and the guide moves forward on its own once ADB is detected.
- Before the approval prompt appears on the TV, the guide rehearses it ("Tick Always allow, then Allow"), then shows a pulsing "Look at your TV".
- Progress is saved per step.
- Troubleshooting branches: *I don't see that menu*, *The prompt disappeared*.
- *Skip for now* is always available; Remote still works without this step.

No jargon appears outside **Settings › Advanced**.

## 3. Home

**Layout:**
- **Top:** TV switcher (with Add TV) and the avatar.
- **Hero card:** a TV illustration with the current app's tile, the app name in Bricolage, volume, the status sentence, and the mode badge. Tapping the badge opens the **What works right now** sheet.
- **Primary:** **Pause TV**, a large coral button. Duration chips: 15m, 30m, 1h, Until bedtime (computed from the rules; hidden if there's no bedtime), and **When this ends** (§8).
- **Secondary row:** Quiet, End app, Volume (opens a slider sheet), and ⋯ (Make it boring, Sound back on).
- **Today strip:**
  - next routine ("Bedtime in 2h 10m")
  - TV time today vs the daily limit
  - Shorts or apps stopped today, from the journals
  - a link to History
- **Plan card,** until it's complete.

**States:**

| State | What the screen shows |
|---|---|
| Paused | The whole hero turns amber, with a sleeping Tubby, an mm:ss countdown in tabular Bricolage, "sound returns by itself at HH:MM", and "Kept by the TV, even if you close this app" (Always On) or "Keep this app open" (Home mode). Buttons: +15 min, End break. A "During this break" list comes from the journal. |
| Problem | A Berry banner (`role=alert`) in plain words with one fix button (Repair, Reconnect, Approve update), plus a "Still working" list. |
| Offline | "Living Room TV is off · last seen 8:14 pm". Controls are dimmed but stay visible. |
| While you were away | A lavender digest card after Always On acted while the app was closed. |

**Quick-action feel:** these keep P1 behaviour. Taps update optimistically with haptic feedback, a spinner appears only after 1.5 s, and a failure rolls back with a reason.

## 4. Routines, Better TV, Settings

**Routines with Always On:**
- Preset chips: School night, Weekend, Movie night, and Custom.
- Presets fill the existing rules document. The active preset is detected by comparing the rules with each preset.
- Cards:
  - Bedtime and quiet hours (day chips plus from/to)
  - Daily TV time
  - Allowed apps (Any / Only these / Block these, with a picker)
  - Volume limit
  - Keep it silent
  - How the TV says no (Quietly, or With a friendly message, previewing the TV card)
  - Tonight only (Allow YouTube tonight, Quiet for 30 min)
- Saving goes to the TV with a "Saved to the TV ✓" toast. A version conflict opens a friendly sheet.

**Routines without Always On:**
- **Lock for a while** is the classic lock, with all its fields; the check interval goes under Advanced options.
- It has its whitelist with "What's playing → allow".
- It shows an Always On preview card.

**Better TV:**
- Summary hero ("All good · N checks", or "N things need attention" with Fix all).
- YouTube without Shorts: the stock YouTube toggle, a SmartTube guide, and "let stock YouTube stay".
- Clean TV: a preview list in plain words, Fix, and Undo.
- Apps on your TV.
- TV health detail.
- An Always On card in dark ink: status, Pause/Resume, Hands off for now (safe mode), Check now, Repair, Uninstall, Approve update.
- **Put the TV back the way it was** (Restore TV: both targets, preview, typed confirmation, progress).

**Settings:**
- Your TVs: rename, forget, switch, add, and manual IP/ports under Advanced.
- Parent PIN and fingerprint.
- Notifications.
- Advanced: capabilities, poll interval, ADB key, allow maintenance, baseline snapshot, debug info.
- About and help.

## 5. Discovery over time

- **At most one nudge per app open,** never during an action. "Not now" backs off to 7 days, then 30 days, then never. The state is stored locally.
- **Triggers** (computed from journals and state):
  - manual pause at about the same hour 3 days running → set bedtime
  - volume lowered from the phone 3 times → volume limit
  - stock YouTube reinstalled, or Shorts stopped often → YouTube without Shorts
  - Home mode just unlocked → Clean TV
  - a routine missed while away → Always On
  - a closed app reopened 3 or more times → friendly message
  - 7 calm days → weekend preset
  - TV build changed → review
  - speech services broken → fix
  - new TV found → add
- **Empty states teach.** Routines templates; Better TV preview cards with 🔓 Unlock; History explainer.
- **ⓘ** next to terms opens a one-sentence explanation plus a "Learn more" sheet.
- **Celebrations:** confetti for a first pause, first bedtime and a calm week only. No streaks.

## 6. Visual system (tokens in `lib/ui/tokens.dart`, theme in `lib/ui/theme.dart`)

- **Fonts,** bundled as assets (OFL, no runtime fetch):
  - **Bricolage Grotesque** 700/800 for display, the hero, numbers and titles.
  - **Figtree** 400–700 for UI and body. Countdowns use tabular figures.
- **Type scale:** display 34, title 24, headline 20, body 16, label 14, caption 13. Tested at 1.3× text scale.
- **Colour (light, the default):**

  | Token | Light | Role |
  |---|---|---|
  | canvas | `#FFF8F1` | Background |
  | surface | `#FFFFFF` | Cards (border `#F0E6DA`) |
  | ink | `#1C1D3A` | Text |
  | muted | `#5B5C78` | Secondary text (≥4.5:1 on canvas) |
  | coral | `#FF6B4A` | Primary action; text on coral is white at bold sizes. Pressed state `#F05A39` |
  | sky | `#3A8DFF` | Remote / Home mode (dark text variant `#1D5FC2`) |
  | mint | `#1FBF8F` | Always On / good (`#0E7C5B` text) |
  | sunflower | `#FFB020` | Paused / bedtime (`#8A5A00` text) |
  | berry | `#E5484D` | Real problems only |
  | lavender | `#8C7CFF` | Celebrations |

- **Bedtime dark theme:** navy `#12132A` base, surfaces `#1C1D3A`, accents dimmed about 10%. It follows the system setting, with "Bedtime dark after sunset" as an option.
- Colour never carries meaning alone: it always comes with an icon and a word.
- **Radii (reduced from the mocks so nothing feels "AI soft"):**
  - cards 16
  - hero 20
  - sheets 24 (top corners only)
  - buttons 14
  - tiles 14
  - chips and badges: full pill, small elements only
  - icon tiles 10
  - inputs 12
- **Spacing:** an 8-point grid. Screen gutter 20. Touch targets ≥ 56 dp for primary actions and ≥ 48 dp elsewhere.
- **Elevation:** flat. Borders and tints carry hierarchy. Only the primary Pause button has a soft coloured shadow.
- **Icons:** Material Symbols Rounded (filled, weight 500), one family throughout. No emoji in the UI chrome.
- **Tubby mascot** (CustomPainter), in moods calm, asleep, cleaning and guard. It appears **only** in onboarding, empty states, celebrations, the paused hero and the TV card.
- **Motion:** 200–350 ms springs.
  - Pause dims the hero and Tubby falls asleep.
  - Numbers tween.
  - Reduced-motion settings are respected.
- **Haptics:** a light tick on actions and a medium "settled" when rules are saved.
- **Copy:** warm, short, second person, and specific. Errors say what happened, why, and the fix.

## 7. Preservation map

Every current feature, mapped to where it lives now:

| Current feature | New home |
|---|---|
| Now card | Home hero |
| Break | Pause TV (+ silence-only → ⋯ Quiet for a while) |
| Mute / Stop / Volume | Quiet / End app / Volume |
| Bore / Restore | ⋯ Make it boring / Sound back on |
| Recent events | Today strip and History |
| Classic lock + whitelist | Routines › Lock for a while |
| Rules editor (all fields, overrides, 409) | Routines |
| Stock YouTube toggle | Better TV › YouTube without Shorts |
| Health + Fix all | Better TV › TV health and summary |
| Apps | Better TV › Apps |
| TV Guard card (all actions) | Better TV › Always On |
| Activity / while away | History and the Home digest |
| Restore TV + baseline | Better TV and Settings › Advanced |
| Saved TVs, capabilities, poll interval, PIN, ADB key, allow maintenance | Settings |
| Lock screen | Restyled (same PinStore and biometric) |
| Notifications | Classic-lock ongoing notification with friendlier text, plus Always On alerts |

## 8. New behaviour

1. **Always On watch.** A periodic background check (Android WorkManager, about every 15 minutes, on Wi-Fi) polls each agent TV's `/v1/status`.
   - **Notify** with a local notification when the status goes healthy → down/limited/safe. Notify **once** per incident and again on recovery ("Always On is back").
   - Notifications are opt-in, with a toggle in Settings. The platform respects battery.
   - **TV power first (added 2026-10-30).** When TV Guard doesn't answer, the watch asks Cast whether the TV is in standby. Standby, a TV that is off at the wall (or a phone away from home), and a TV Guard still settling after a start never alert. Only an awake TV with a silent TV Guard counts: twice in a row.
2. **End after this one.** A duration chip, "When this ends", on Pause TV. It depends on the media-session spike.
   - **Media-session path:** if the agent can read the foreground media session (title, duration, position, state):
     - The chip shows "When this ends (about N min)".
     - When the video ends or the title changes, the agent starts a break.
     - **Cap: 45 min.**
   - **Timer path:** otherwise the chip shows "In about 20 min", with 10/20/30 choices.
   - **Labels must be honest:** never claim "when this ends" without media data.
   - The agent API gains `POST /v1/action {action:"endAfter", capMin}` and `status.media`.

## 9. Quality bar

- `flutter analyze` must report 0 issues.
- All existing tests pass, updated where the UI moved.
- New widget tests: onboarding first win, helper guide auto-advance, plan ordering by goals, nudge backoff, paused/problem/offline hero states, preset detection, and the "What works" sheet per mode.
- Goldens for every new screen, in light and dark.
- Contrast is AA throughout.
- Checked at 360 dp and 1.3× text scale.
- Verified on the real Pixel and TV before calling it done.
