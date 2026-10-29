# boretube Learn: a learning app for kids on the TV

- **Date:** 2026-10-29.
- **Status:** approved in chat (the core loop, mocks, build, content and sound). Implementation is in progress; see §11.
- **Mocks** (they set the look): https://claude.ai/artifact/TPc5tE9skQtZXzftKTMXjH (private canvas "boretube Learn", 7 artboards).
- **Related:**
  - brain breaks spec `2026-10-29-brain-break-design.md`, shipped in TV Guard 1.4.1;
  - the visual rules in `2026-10-29-visual-audit-and-direction.md`; the φ proportion system there applies here too.

> **For a future session:** read §0, then §11 to see what's done, then the plan in `docs/superpowers/plans/2026-10-29-boretube-learn-p1.md`. The rules in §5 (visual) and §6 (sound) are binding.

## 0. Decisions (settled; don't reopen without the user)

| Question | Decision |
|---|---|
| Why does a child open it? | **Fun for its own sake.** It never earns or spends video time. |
| Subjects in version 1 | **Maths, English and EVS/Science.** Maths is generated; English and EVS are written banks. |
| Time | **Unlimited.** No cap, and it doesn't count toward daily TV time. TV Guard's bedtime, Break and Allowed apps still apply, because it's an ordinary app. |
| Where | **A separate Android TV app**, `com.rakesh.boretube.learn`, with its own launcher tile. It works offline and without TV Guard. |
| Toolkit | **Kotlin + Jetpack Compose for TV** (`androidx.tv`). |
| Engine | **One shared Kotlin module, `learn-core`**, used by both this app and TV Guard (brain breaks). |
| Progress | **Owned by the Learn app.** Shared with TV Guard through a signature-protected ContentProvider; one child, one record. |
| Content | **Written by Claude, checked by machine, reviewed by a person.** Only reviewed packs ship. |
| Who uses it | **One child per TV** in version 1. The parent picks class (KG–7) and language (en / hi / enHi) on the phone. |

## 1. Product

- **The world:** "Tubby's Town" with three lands.

  | Land | Subject | Colour | What grows |
  |---|---|---|---|
  | **Number Bazaar** | Maths | sunflower `#FFE1A6` | stalls light up, kites go up |
  | **Word Garden** | English | mint `#CDEFE0` | flowers bloom, birds arrive |
  | **Nature Trail** | EVS | sky `#D6E8FF` | animals, a river, a rangoli at the end |

  Each land is a **path of levels**, one per skill. The path starts at the parent's class; one class up and one class down are open too.
- **A level:** about 3 minutes and 8 questions, in one **format**.

  | Format | How it plays | Version |
  |---|---|---|
  | Quick-fire | One question after another; the timer bar is only for show, and running out of time just moves on | P1 |
  | Catch | Answers fall in 3 lanes; ◀ ▶ moves the basket; answers that reach the bottom wait there | P1 |
  | Build | Tens and ones, or letter tiles | P2 |
  | Pairs | A 4×3 grid of flip cards | P2 |
  | Story | Illustrated pages read aloud, then 3 questions | P4 |

- **Pass or learn.** Like brain breaks: a miss shows the one-line *why*, then an easier question the child can win. **Nobody fails a level.**
  - **Stars, 1 to 3:** for accuracy only (≥ 60%, ≥ 80%, 100%), never for speed. A replay keeps the best result.
- **Rewards with no tricks.**
  - **Stickers:** one per mastered skill.
  - **The town grows** as skills are mastered.
  - **Never:** coins, ads, purchases, loot boxes or streaks.
- **Mystery box:** each day's review level. Facts that are due, across subjects, using the same Leitner boxes as brain breaks.
- **By age:**

  | Classes | How it plays |
  |---|---|
  | KG–1 | Every question is read aloud and no reading is needed; mostly Pairs and Catch |
  | 2–4 | A mix of formats |
  | 5–7 | More text, Story, and harder Build |

- **Stopping points:** after each level, **Play another** or **Back to town**. The town is the calm place to stop.
- **Phone (Boretube 2):** a Learning page with:
  - progress per subject, stickers, and skills getting stronger;
  - class and language;
  - sounds and music on/off;
  - install, update and remove.

## 2. Architecture

```
learn-core/        (new) pure Kotlin/JVM: Skill, Question, Maths ladder, Learner (Leitner), round planner,
                   BrainBreakSession, content-pack model + validator. No Android imports. Unit-tested.
boretube-learn/    (new) Android TV app: Compose for TV, SoundPool, TextToSpeech, ProgressStore, ProgressProvider.
boretube-agent/    uses learn-core (includeBuild); brain breaks read/write progress via the provider when
                   Learn is installed, else keep their own LearnState (today's behaviour).
content/           (new) JSON packs + pictures + review pages.
boretube-mobile/   installs/updates Learn (like TV Guard), Learning page, settings.
```

- **Gradle:** `learn-core` is a standalone Gradle build, consumed through `includeBuild("../learn-core")` and dependency substitution in both Android builds.
  - JDK 17.
  - Package `com.rakesh.boretube.learn.core`.
  - The engine's code moves from `boretube-agent/.../core/Maths.kt` and `Learn.kt`.
  - The agent keeps its API types: `LearningRules` and `LearningDoc` stay in the agent.
- **Signing:**
  - The Learn app is signed with the **agent key** (`~/.boretube/keys/agent-release.jks`), so signature permissions work.
  - The phone bundles `learn.apk` plus a manifest (sha256, cert) next to the agent.
- **ProgressProvider:** `content://com.rakesh.boretube.learn.progress`.
  - `/state`: read and write. It needs the signature permission `com.rakesh.boretube.learn.permission.PROGRESS`.
  - `/summary`: read only, with `android.permission.DUMP`, so the phone can read it through `adb shell content query`.
- **Migration:** the first time TV Guard finds the provider, it offers its own LearnState; the Learn app merges it in, keeping the higher box and the newer due date per fact. After that, TV Guard reads and writes through the provider. If Learn is uninstalled, TV Guard falls back to its own state.
- **Settings:** class, language, sounds and music.
  - With TV Guard, they come from `rules.learning`, extended with optional `sounds` and `music` (both default true).
  - Without TV Guard, the phone writes them over ADB with `content call ... set` (DUMP-protected).
- **TV Guard integration:**
  - Allowed apps: the phone adds `com.rakesh.boretube.learn` to the allowlist when Learn is installed.
  - Learn is never a "video app": it isn't in `COOLDOWN_PACKAGES`, and hopping isn't detected on it.

## 3. Screens (match the mocks)

**1. Town (home).**
- **Header:** Tubby, "Tubby's Town", and a time-of-day greeting. Never invent a child's name; use one only if the parent set it.
- **Right of the header:** chips for **Mystery box · N** and **Stickers · N**.
- **The lands:** three equal land cards (scene, name, "Subject · x of y skills", "Next: …").
- **Remote:** ◀ ▶ moves between cards; ▲ reaches the chips.

**2. Land path.**
- **Left panel** (38.2% of the width, tinted in the land's colour): breadcrumb, land name, class path, progress bar, a skills and stars count, and a card for the focused level (name, format, question count, about how long, stars so far).
- **Right:** a dotted winding path through the level nodes. Done nodes are sunflower with stars; the current node is coral, scaled to 1.15 with an ink focus ring; open nodes are cream.
- **Remote:** ◀ ▶ walks the path.

**3. A level.** The format screen. Every format shows:
- the question top left, in Bricolage, as large as fits (89 → 55);
- "n of 8" with a thin progress bar top right;
- the format body;
- a one-line remote hint at the bottom.

**4. Learn moment.** The brain-break learn screen, restyled for daylight: the fact with the answer highlighted, "You picked X" struck through, the why (one sentence), a picture, and **Got it**.

**5. Level done.** Tubby cheers; the stars count in; the sticker card if one was earned; one line about a fact to practise; **Play another** (focused) and **Back to town**.

**6. Sticker book.** A 6-column grid. Collected stickers sit on white cards; empty slots are dashed and named after the skill that earns them. ▼ scrolls.

**7. Mystery box.** A level of mixed due facts with a gift-box intro (P2).

**8. First run (no settings yet).** A 3-step class/language picker on the TV, with "Ask a grown-up" and Tubby. Settings from the phone override it.

## 4. Content packs

- **One file per subject and class:**

  ```
  content/<subject>/<class>.json  (class: kg, 1..7)
  ```

- **Pack shape:**

  ```json
  {"id":"english-1","subject":"english","grade":1,"version":1,
   "reviewed":{"by":"","at":""},
   "skills":[{"id":"en1.naming","title":"Naming words","outcome":"EN-1.07","formats":["pairs","quickfire"],
     "items":[{"id":"en1.naming.cat","q":"Which one is a naming word?","options":["cat","run","big","soft"],
       "answer":0,"explain":"A naming word names a thing: cat.","picture":"cat","speak":"Which one is a naming word?"}]}]}
  ```

- **`outcome`:** the NCERT learning-outcome code, e.g. `EN-1.07` is our index into `content/outcomes.md`. That index lists each outcome with its source chapter.
- **Validator** (in `learn-core`, run as a unit test over all packs):
  - 2–4 distinct options, with the answer present;
  - the explanation is one sentence of ≤ 12 words (`Maths.wordCount`) with no jargon (the brain-break list);
  - every picture id exists in the library;
  - item ids are unique;
  - each skill has at least 12 items;
  - the class word-list check is a warning, not a failure.
- **Review:** `content/review/<pack>.html` is generated with every item, its answer and its why.
  - When the user approves a pack, `reviewed.by` and `reviewed.at` are set.
  - **The app loads only reviewed packs.** A debug build flag loads unreviewed packs for testing.
- **Pictures:** `content/pictures/*.svg` are flat illustrations in the mock style (2–4 fills, no gradients, no outlines thicker than 3 px, from the brand palette). They're converted to VectorDrawables at build time. P3 needs about 150 to start.

## 5. Visual system (binding, to avoid "AI slop")

- **Tokens** live in `boretube-learn/.../ui/Tokens.kt`. Screens reference tokens only, never raw values.
  - **Spacing** (Fibonacci): 4 · 8 · 13 · 21 · 34 · 55 · 89 (TV scale).
  - **Type** (Bricolage Grotesque 700/800 for display; Figtree for UI): 18 · 21 · 26 · 34 · 43 · 55 · 89 · 144.
  - **Radii:** 8 · 13 · 21 · 34.
  - **Motion:** 120 · 200 · 320 · 520 ms.
- **Colours:**
  - canvas `#FFF4E4`, card `#FFFFFF` with a 1 px `#EADFD1` hairline;
  - ink `#1C1D3A`, muted `#5B5C78`;
  - coral `#FF6B4A` (focus and primary), sunflower `#FFB020` (stars and done), mint `#1FBF8F`, sky `#3A8DFF`, lavender `#8C7CFF`;
  - land tints as in §1.
  - **No red, no gradients, no glassmorphism, no drop shadows** except the focus ring.
- **Focus** (the remote is everything):
  - The focused item is **scaled 1.04–1.15** with a **two-ring outline**: a 5 px gap in the canvas colour, then a 5 px ink or coral ring.
  - Focus moves are animated over 120 ms.
  - Exactly one focus is visible at a time, and focus is never lost after a screen change.
  - Default focus goes to the most likely next action.
- **Layout:**
  - Content stays inside a 5% TV-safe margin. The design grid is 1280×720 dp, scaled.
  - Splits are 61.8 / 38.2. Siblings in a row are equal widths, with no orphans.
  - **At most one** coral primary per screen.
- **Language:** warm and short, in second person. Empty states teach. Never say "Wrong" or "Fail"; use "Almost!", "Let's learn this one", "Level done!".
- **Pictures over words** below Class 2. Every question is read aloud there.
- **Forbidden:**
  - emoji in the UI;
  - generic Material cards;
  - identical card stacks on every screen;
  - uppercase tracked eyebrows;
  - lorem ipsum or invented stats;
  - placeholder icons in shipped screens;
  - a progress spinner where content can show at once (the app is offline).
- **Self-check before a screen counts as done:**
  1. It matches its mock artboard.
  2. The focus path is tested.
  3. A screenshot test passes at 1080p and 720p.
  4. There is no hard-coded colour or size.

## 6. Sound (binding)

**Rules**
- **One scale:** C major pentatonic, so overlapping sounds never clash.
- **Lengths:** micro-sounds 50–300 ms; celebrations ≤ 2 s.
- **Loudness:** normalised to -18 LUFS, with effects 6 dB under the read-aloud voice. Effects and music duck when TTS speaks.
- **Never punishing:** no buzzer and no ticking.
- **Rate limit:** the focus tick plays at most every 120 ms.
- **Each land has its own timbre:**
  - Bazaar: marimba plus tabla taps;
  - Garden: bells plus birds;
  - Trail: wood blocks plus water drops.
- **Off switches:**
  - "Sounds" and "Music" settings;
  - TV Guard `alwaysMute` makes the app silent;
  - the system volume is respected.
- **Engine:** effects use `SoundPool`, with every file preloaded at start. Music uses `ExoPlayer`/`MediaPlayer` loops at -12 dB, only on the town and path screens.

**Catalogue** (file ids live in `boretube-learn/src/main/res/raw/`; a test asserts every id exists):

| id | moment |
|---|---|
| `focus_<land>` | focus moved (soft tick tuned per land) |
| `select` | OK, a round pop |
| `back` | back, a falling whoosh |
| `enter_<land>` | entering a land: a whoosh up plus a 3-note motif |
| `q_show` | a new question, a light chime |
| `right_1..right_5` | right answer, a rising 2-note; climbs with right answers in a row, resets quietly |
| `miss` | wrong answer, a soft falling 2-note "hmm" |
| `learn_open` | the learn screen, a gentle bell |
| `followup_win` | winning the easier follow-up, a warm 3-note chord |
| `catch_drop` | answers drop, a soft whistle |
| `catch_move` | basket move, a swish |
| `catch_right` | a plop plus sparkle |
| `catch_miss` | a soft boing |
| `build_ten` | tens rod, a low wooden clack |
| `build_one` | ones cube, a light click |
| `build_undo` | take one away, a reverse pop |
| `build_hit` | target reached, a ding |
| `card_flip` | a paper flip |
| `pair_match` | a two-tone pling plus sparkle |
| `card_back` | a soft flip back |
| `page_turn` | Story page turn |
| `star_1..star_3` | stars counting in, rising |
| `level_done_<land>` | a 2 s fanfare |
| `sticker` | a shimmer, then a pop |
| `town_grow` | a wind chime |
| `box_open` | a gift rustle plus sparkle |
| `music_<land>` | a 60 s loop; `music_town_dusk` and `music_town_festive` are variants |

**Sources**
- Chimes, ticks and notes are rendered by our own synth script, `boretube-learn/tools/sfx.py`, so we own them by construction.
- Clacks, flips and rustles come from CC0 packs (Kenney), with licences in `res/raw/LICENSES.md`.
- Music is simple loops we compose and render.
- **Budget:** ≤ 1.5 MB of OGG.

## 7. Remote input

- **Keys:**
  - D-pad and OK only, plus Back (up one level; leaving a level asks "Leave this level?" with Stay focused).
  - Media keys are ignored.
  - Volume keys pass through.
- **No hold-to-act and no double-press.** A 350 ms input grace applies after each screen change, as in brain breaks.
- **Pairs:** a 4×3 grid with arrow navigation and wrap-around off.

## 8. Phone

- **Better TV** gains a **Learning app** row: install, update and remove, like TV Guard. It uses `TvOps` and is journaled and restorable.
- **The Learning page:**
  - per subject: skills mastered out of the total, and stars;
  - stickers;
  - "Getting stronger";
  - settings (class, language, sounds, music).
- **Summary source:** the TV Guard API when Always On is present, otherwise `adb shell content query`.

## 9. Testing

- **learn-core:** unit tests (moved from the agent, plus the pack validator over every pack).
- **Learn app:**
  - Compose UI tests for focus traversal on every screen;
  - Roborazzi screenshot tests per screen;
  - the sound catalogue test.
- **Agent:** every existing test passes after the extraction, plus a provider client test with a fake.
- **Phone:** widget and golden tests for the Learning page and the install row.
- **Device run on the VU3** for each phase.

## 10. Not in version 1

- multiple children
- recorded voices
- online sync
- buying content
- screen-time rewards
- voice answers
- the kid launcher (a separate piece)

## 11. Phases and status (update this as work lands)

- [ ] **P1:**
  - extract `learn-core` (agent green);
  - the Learn app shell: tokens, fonts, Tubby, the Town, the Land path, Quick-fire and Catch for maths, the learn moment, Level done;
  - ProgressStore;
  - the core sounds (`select`, `back`, `focus_*`, `q_show`, `right_*`, `miss`, `learn_open`, `followup_win`, `catch_*`, `star_*`, `level_done_bazaar`);
  - the phone bundles Learn and installs it from Better TV, the same way as TV Guard. The user installs TV apps through the phone, never with laptop `adb install`.
- [ ] **P2:**
  - Build and Pairs, the sticker book, the Mystery box;
  - the full sound set and music;
  - ProgressProvider plus the TV Guard link and migration;
  - phone update and remove polish.
- [ ] **P3:** English and EVS packs for KG–7 (review pages; the user reviews them), plus the picture library.
- [ ] **P4:** Story levels, the phone Learning page, and settings without TV Guard.
