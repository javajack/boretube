# boretube Learn P2a: Build and Pairs, Word Garden and Nature Trail

> **For agentic workers:** executed inline in the session of 2026-10-29. Tick boxes as each item lands. **Spec:** `docs/superpowers/specs/2026-10-29-boretube-learn-design.md`. Its §5 (visual) and §6 (sound) are binding. The P1 plan is `2026-10-29-boretube-learn-p1.md`.

**Scope:** "the other two games" (the user chose "Both"):
- the **Build** and **Pairs** formats in Number Bazaar;
- the **Word Garden** (English) and **Nature Trail** (EVS/Science) lands with written banks, KG–7.

**Out of scope (still P2/P4):** the ProgressProvider and TV Guard link, the Mystery box, the sticker book, music, Story levels, and the phone Learning page.

## Decisions

- **Catalogue (learn-core):**
  - `interface SkillSource { id, grade, title, badge, subject; next(r); build(key, r); easier(q, r) }`.
  - `Catalog(sources)` with `Catalog.MATHS` (the ladder only, used by TV Guard) and `Catalog.of(packs)`.
  - `Levels.plan` and `Levels.finish` take a catalogue, defaulting to MATHS.
  - Pack question keys are `<skillId>:<itemId>`.
- **Formats rotate per skill.** `LearnState.plays[skillId]` counts the plays, and `Levels.formatFor(skillId, plays)` picks from the skill's list:
  - Maths uses Catch or Quick-fire, then Pairs (facts with distinct answers);
  - `placeValue` uses Build;
  - pack skills use their own `formats` (Quick-fire and Catch only).
- **Pairs:** a 4×3 board, 6 facts with distinct prompts and answers.
  - A mismatch flips back after 900 ms with the soft `miss`.
  - Each fact counts as right only if it was matched with no mismatch involving its cards.
- **Build:** 5 targets a level, made from tens (0–9) and ones (0–9).
  - Done with the right value counts as right. Otherwise the learn moment appears ("47 is 4 tens and 7 ones.").
- **Banks:** `boretube-learn/app/src/main/assets/content/{english,evs}/{kg,1..7}.json`.
  - Two skills per class, 12 items per skill.
  - Checked by `PackValidator` (a learn-core unit test runs it over every file).
  - `tools/review.py` writes the review pages, `content/review/*.html`.
  - **The app loads a pack only when `reviewed.by` is set.** Debug builds load them all.
- **Pictures:** a small Canvas library (`ui/Pictures.kt`), ids referenced by `picture`. The validator checks the ids.

## Checklist

- [ ] learn-core: `SkillSource`, `Catalog`, the pack model and validator, `Visual.Picture`, plays, format rotation, Pairs and Build question sets (tests).
- [x] App: Build and Pairs screens with sounds (`build_*`, `card_*`, `pair_match`), wired into levels (tests and screenshots).
- [x] Banks: English and EVS KG–7 plus the review pages; the validator test runs over every pack.
- [x] App: the content repo (assets, reviewed gate), Lands from the catalogue, the picture library, Garden and Trail playable (tests and screenshots).
- [ ] Learn 0.2.0 bundled in the phone; the user reviews the banks; the user installs; a device check.
