# Tubby's Town: deep and wide content (P2b)

Date: 2026-10-30. This extends the Learn design spec (`2026-10-29-boretube-learn-design.md`). Its §5 (visual system) and §6 (sound) stay binding.

## Why

The written banks feel thin and too easy:
- 2 English and 2 EVS skills per class, about 26 questions each, 834 in total;
- Maths has 20 generated rungs;
- four formats.

The user asked for:
- **depth**: medium and complex questions, not only simple ones;
- **width**: more skill tracks per class;
- **streaks**: longer runs, with rewards;
- **variety**: more formats;
- **volume**: about 100× the questions.

## Decisions (made with the user, 2026-10-30)

| Question | Decision |
|---|---|
| Who reviews ~80,000 questions? | **Nobody item by item.** The user owns playing; Claude owns quality. Every question is machine-checked (§6), and generators are built from curated tables, never free text. The old "only reviewed packs ship" rule still holds for the hand-written packs. Generated skills ship when their checks pass. |
| What does "streaks" mean? | **Both.** More skill tracks per class, *and* a Streak run: an endless run that gets harder, with milestone rewards. |
| Look and feel | **Today's theme, tokens, Tubby and sounds are the reference.** New screens reuse them and must look at home next to Quick-fire, Pairs and Build. No generic UI. |
| Several children on one TV | **Players** (the user, 2026-10-30). Up to 6 per install, each with an animal avatar, a class, a language and their own `progress-<id>.json`. The first player keeps `progress.json`, so the existing child carries over. Switching player or class is ▲ then OK from town. |
| Independent of the phone | **Everything happens on the TV** (the user, 2026-10-30). Players, class, language, sounds and removing a player are all set on the TV (town header, Settings). The phone only installs and updates the app; there's no runtime link. This replaces the Learn spec's "the parent picks class and language on the phone". |
| TV Guard | **Untouched.** The maths ladder (`Maths.LADDER`) and its rung indexes stay exactly as they are; brain breaks depend on them. New maths skills are separate generated skills used only by the Learn app. |

## 1. Model

- **`Question.tier`:** 1 is easy, 2 medium, 3 hard.
  - A child's tier per skill lives in `LearnState.tiers`.
  - A 3-star level moves the tier up by one; a 1-star level moves it down.
  - A level is mostly the current tier, with up to 2 "stretch" questions from the next tier.
- **`GenSkill`** (in `learn-core`, `Gen.kt`): `Template`s over a grid of seeds, built from data tables.
  - Keys are `<skill>:<template>:<seed…>`, so spaced repetition rebuilds the exact question.
  - `all()` walks every question, for tests and the volume report.
- **Data tables:** JSON in `boretube-learn/app/src/main/assets/content/data/`, loaded once into `LearnData` and handed to the generators.
- **Pack banks** (the hand-written JSON) stay as they are, as extra skills.

## 2. Formats

| Format | How it plays (remote) | Question shape |
|---|---|---|
| quickfire (have) | ←→↑↓, OK | 2–4 options |
| catch (have) | catch the falling answer | 3 short options |
| pairs (have) | flip cards | distinct prompt and answer |
| build (have) | tens and ones | place value |
| **truefalse** | a statement card; ← True, → False | options `["True","False"]` |
| **order** | press tiles first to last; each gets a number; Back undoes | `order` = items in order, 3–5 items |
| **sort** | one card at a time drops in; ← left basket, → right basket; 8 cards | 2 options, the same pair across the level |

**Mix (the user, 2026-10-30):** Sort and Order take more doing with a remote, so they're a treat, not the diet:
- a skill's first play is always plain (quick-fire, catch, pairs, true or false);
- Sort and Order come at most every 3rd play, and every 4th in KG and Class 1;
- they're never twice running, and never right after one went badly (1 star → `LearnState.easyNext`);
- every generated skill must have a plain template (GenChecks).

Odd one out, fill the gap, compare (> < =), missing letter and story problems are question *kinds* inside quickfire. Each is styled by its prompt, not a new screen.

**Streak run** (one per land, on the land screen):
- Questions are mixed from the child's path, starting at tier 1.
- Every 5 in a row moves up a tier, and the run ends at the third miss.
- Milestones at 5, 10, 20, 30 and 50 get a flame, a sound and a line from Tubby.
- The best run per land is kept in `LearnState.bestRuns`.

## 3. Skill map

Per class there are about 10 English skills, 10 EVS/Science skills, and 4–8 extra maths skills on top of the ladder, each with tiers. The research note in this session (NCERT Learning Outcomes 2017; JM, MR, MM, SN, OWW, GP, PV, CU textbooks; IXL grade lists) is the source. Skill ids are `<subject><class>.<name>`, e.g. `en3.irregPast`, `ev5.foodChain`, `sc7.acidBase`, `ma4.factors`.

Skills that need renderers (angles, cubes, circuits, nets) or audio-only prompts are out of scope for now.

## 4. Data tables (content/data)

All strings use **Indian/British English**: colour, centre, metre, -ise, maths, mum, full stop. Use ₹, lakh and crore, and metric units.

- **`lexicon.json`:** `{"words":[{"w","lvl"(0..7),"pos":[...],"cat"?,"plural"?,"past"?,"pp"?,"ing"?,"comp"?,"sup"?,"opp"?,"syn":[]?,"rhyme"?,"syl","count"?(true|false),"an"?(true if "an")}]}`, about 1,500 headwords.
  - `opp` and `syn` are single-sense and safe for children.
- **`english.json`:** curated tables.
  - irregular verbs, irregular plurals and irregular comparatives;
  - gender pairs, collective nouns, homophones (with frames), similes, one-word substitutions;
  - compound words, prefix/suffix words, confusables, phrasal verbs, roots, idioms and collocations;
  - **sentence frames** for grammar: is/are/am, pronouns, prepositions, question words, conjunctions, sentence types, end punctuation, subject–verb agreement, tense frames, much/many, question tags, active/passive, reported speech, conditionals and relative pronouns. Each frame has its answer and its wrong choices.
- **`evs.json`:**
  - animals (~220), plants (~120), foods (~180), objects and materials (~220);
  - helpers, transport, the body and senses, houses;
  - India (36 states/UTs), festivals, seasons and months;
  - a `contested` flag on rows to keep out of category questions (tomato, bat, whale…).
- **`science.json`:** scenario tables:
  - mixture → separation; substance → acid/base/neutral; change → physical/chemical;
  - heat transfer; motion type; nutrient sources; deficiency diseases; magnetic and conductor materials; transparent/translucent/opaque;
  - states of water; space; plant and animal processes in order; moon phases; metals and non-metals;
  - every row carries `src` (NCERT book and chapter).

## 5. Volume target

- **At least 85,000 distinct generated questions across English and EVS/Science** (100× today's 834). Maths gets more on top.
- Every generated skill has at least 200 questions, at least 2 tiers, and all its questions pass §6.
- `GenVolumeTest` prints the per-skill counts and fails below target.

## 6. Checks (every question, in unit tests)

1. **Options:** 2–4 distinct, the answer present, and no option equal to the answer ignoring case.
2. **truefalse:** options exactly True/False. **sort:** exactly 2 options, the same pair within a template. **order:** 3–5 distinct items, with `options` a permutation of `order`.
3. **Explanation:** one sentence of 12 words or fewer, ending in a full stop, with no jargon words.
4. **Prompt:** at most 90 characters, and at most 140 for a story problem. **Options:** at most 24 characters, and at most 12 for Catch skills.
5. **Spelling:** no US spellings, checked against a blocklist (color, center, meter, -ize forms, mom, math).
6. **Repeats:** no duplicate keys, and no duplicate (prompt, answer) pairs within a skill.
7. **Data checks:** antonyms symmetric where both words are listed, never equal to a synonym, and `contested` rows never used in category questions.

## 7. Delight (the user, 2026-10-30)

"Make the interaction more delightful, like commercial games, with white-hat tricks." The wrong-answer screen "falls flat".

**Learn moment (wrong answer):**
1. The picked option shakes softly and fades.
2. The right answer slides into the middle and grows.
3. The explanation types in phrase by phrase, and the key phrase (the answer, or the number/word that matters) is highlighted with a drawn underline in the land's colour.
4. Tubby leans in with a thinking pose. A soft "aha" chime plays when the highlight lands.
5. The easier follow-up says "Try this one" with a gentle bounce.

**In play:**
- **Combo:** 3, 5 and 8 right in a row get a small flame that grows on the progress bar, with a rising pitch on the right-answer sound.
- **Anticipation:** a short beat before stars land, then each star pops in turn with its own note.
- **Variable delight (never pay-to-win):** sometimes Tubby does a different dance, and a rare golden star appears on a perfect level.
- **The Streak run** has a flame counter, milestones at 5/10/20/30/50, and a best-run ribbon on the land.

**Never:** no timers that punish, no loss aversion ("you'll lose your streak!"), no nagging to come back, no fake scarcity. Missing is always safe: the learn moment teaches, it never scolds. Reduce-motion keeps every state visible without the motion.

## 8. Discovery (the user, 2026-10-30)

"Make people discover the rich stuff, and resurface features and classes now and then."

- **Town header:** who's playing (avatar), their class (change), Settings (a cog). ▲ reaches it from the lands.
- **"Today in Tubby's Town"** (▼ from the lands): three cards from `Discover.today`, the same all day and rotating daily:
  - practice that's due always leads;
  - then, spread across lands: a land not visited yet, a Streak run never tried (or "beat your best"), a skill new for this class, a peek at the next class, and "remember this one?" for a mastered skill.

## 9. Festivals (the user, 2026-10-30)

"Animate screens for festivals for a few days, not one fixed day, so it's easy to maintain; research the next 5 years."

- `Seasons` (learn-core `Delights.kt`) shows each festival for a window around its main day, such as Diwali from Dhanteras to Bhai Dooj, or Navratri from night 1 to Dussehra. Where windows overlap, the nearest main day wins.
- Moving dates run from 2026 to 2031 (`COVERED_UNTIL`): drikpanchang.com (New Delhi), cross-checked with calendarlabs and the Government of India's 2027 holiday lists. Eid dates are the expected ones (±1 day); the window absorbs that.
- `FestivalsTest` fails from 2030 onward, so the table gets its next five years with a year to spare.
- **The town dresses up (`ui/Festive.kt`).** A slow backdrop moves behind the cards and garlands and lamps sit in the margins. They never cover a card or a word.
  - Diwali: diyas, a toran and twinkles.
  - Holi: colour puffs.
  - Sankranti and Independence Day: kites, with bunting for Independence Day.
  - Navratri, Ganesh, Onam, Rakhi and Janmashtami: a marigold toran.
  - Eid: lanterns and twinkles.
  - Christmas: snow and twinkles.
  - New Year and Children's Day: balloons.
