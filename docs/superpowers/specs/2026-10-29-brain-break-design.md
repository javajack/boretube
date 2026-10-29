# Brain break: a learning gate on the TV (piece 1 of the kid-friendly TV)

Date: 2026-10-29. Status: approved in chat (four sections). Mockups: https://claude.ai/artifact/Ljo6aMX4Aa2rU3n1gJw5Pq (private canvas, "boretube Brain Break").

## Scope and decomposition

The kid-friendly TV splits into four pieces. Each gets its own spec and build:

1. **This spec: the brain-break gate with maths only.**
2. Content packs: EVS, science, English, Hindi, and picture and voice banks.
3. When it shows: researched once the UX works.
4. The kid launcher.

**The product is reusable.** It isn't tuned to one family: the parent picks the **class** (KG to Class 7, about ages 4–12) and the **language** (English, Hindi, or English text with a Hindi voice). For this version, one child per TV.

## 1. Architecture and the loop

- **Where it lives.** A focusable `TYPE_APPLICATION_OVERLAY` window inside **TV Guard** (Kotlin), drawn natively on a Canvas like `TvCardView`.
  - It is not a launcher feature, because the launcher only appears when the child presses Home.
  - It reuses TV Guard's watchdog, permission self-heal, phone pairing and rules document.
- **The engine is plain Kotlin** in `core/learn/`, with no Android imports, and is unit-tested on the laptop.
- **Opening a break:**
  - TV Guard pauses the followed media session (media-session transport controls; fallback `input keyevent MEDIA_PAUSE`), then shows the quiz.
  - Back, media keys and arrow keys are swallowed by the window. Home goes to the launcher underneath, but the overlay stays on top.
- **A round is N questions** (default 3, 1–5).
  - **Right:** sparkle, then the next question.
  - **Wrong:** a "learn it" screen. It shows the right answer with a one-line *why*, then an easier follow-up from the rung below, so the child ends on a win. The missed fact is queued to come back.
- **Ending a round.**
  - The **Done** screen shows a summary and then resumes the video: OK, or by itself after 5 s.
  - **Even 0 out of N gets through after the learn steps.** The gate takes time and attention, but it is never a wall.
  - Only finishing the round, or the phone (`endBrainBreak`), closes it.
- **Fail open.** If the overlay can't be shown (no overlay permission, a crash), nothing is blocked and the journal records why.

## 2. The TV UX (see the mockups)

- **Look.** Navy ground `#12132A`, cream text, Bricolage Grotesque headlines. Tubby sits top left. Progress dots run top right.
- **Answer tiles.** 4 answers (3 for comparisons) in **one row**, so a 6-year-old only needs left, right and OK. The focused tile is cream with a coral ring and scaled to 1.06.
  - **Right:** the tile turns mint with a tick, Tubby cheers, and "Yes!" appears with the full fact.
  - **Wrong:** "Almost! Let's learn this one." The answer is shown in sunflower beside the trick, plus a picture where one helps (a dot grid for tables). The line "This one comes back tomorrow" appears, with a "Got it" button. **Red is never used.**
- **Pictures:** objects to count (mangoes), a dot array, pies, a clock face.
- **Questions read aloud** with Android TextToSpeech, in `en-IN` or `hi-IN`.
  - **No Hindi voice on the TV:** fall back to English and report it in `status.learning.voice`.
  - **Voice answers are deferred.** A floating overlay can't own the remote mic reliably, so the "say it" hint is not shown in this version.
- **TV-safe:** content stays inside a 5% margin. The design is 1280×720, scaled.

## 3. Question engine

- **Skill ladder,** from NCERT learning outcomes. Each skill has a class.

  | Class | Skills |
  |---|---|
  | KG | count to 10, which is more |
  | 1 | add and subtract within 10, count to 20 |
  | 2 | add past 10 (make 10), place value, add within 100 |
  | 3 | tables 2–5 and 10, money, time |
  | 4 | tables 6–9, division facts, multiply 2-digit × 1-digit |
  | 5 | fractions (compare, half of), decimals compare |
  | 6 | percentages, negative numbers |
  | 7 | one-step equations |

- **The child's position.** The parent's class sets the starting rung. The engine moves at most one class up or down from it:
  - **Promotion:** 3 non-guess correct answers in a skill, on at least 2 different days.
  - **Demotion:** 3 wrong in a row.
- **Generators.** Each returns `Question(key, skill, prompt, promptHi?, spoken, spokenHi?, options, answer, explain, visual?)`.
  - **Wrong options come from real mistakes**, not random numbers: a neighbouring multiple (7×7 or 7×9 for 7×8), off by one, swapped digits, adding instead of subtracting.
- **Explanation rule (the user's direction):** **one sentence, at most 12 words**, a trick or a picture, in plain words for that class.
  - The lint test counts words containing a letter or digit, and bans jargon such as *commutative* or *numerator*.
  - Tables tricks:
    - ×2: "double it"
    - ×4: "double, then double again"
    - ×5: "half of ×10"
    - ×9: "×10, take away one"
    - ×10: "put a zero on the end"
    - even multipliers: "half of it, doubled"
    - otherwise: "one less, plus one more"
- **Spaced repetition** (Leitner, boxes 1–5).
  - A fact enters the queue when it's answered wrong. Right moves it up a box; wrong sends it back to box 1.
  - Box intervals: 10 min, 1 d, 3 d, 7 d, 21 d.
  - After box 5 it graduates and leaves the queue. At most 200 facts are kept.
- **Round mix:** an easy warm-up (the rung below), then the current skill, then any facts that are due, filling the rest with the current skill.
- **Guess detection:** an answer under 800 ms never promotes a fact or a skill.
- **State** (`LearnState`: rung, per-skill stats, facts, week log) is stored by `AgentStore` on the TV and survives restarts.

## 4. Settings, triggers, API

- **Rules document gains `learning`** (optional; absent means off):

  ```json
  {"learning": {"enabled": true, "grade": 3, "lang": "en|hi|enHi", "voice": true,
                "perBreak": 3, "trigger": "manual|hopping|every", "everyMin": 30}}
  ```

  - `grade` 0 means KG; the range is 0–7.
  - `perBreak` is 1–5; `everyMin` is 5–240.
- **Triggers:**
  - `manual`: only from the phone.
  - `hopping`: replaces the shorts/hopping action while learning is on. A detected hopping session opens a brain break instead of closing the app.
  - `every`: after `everyMin` minutes of playing video since the last break.

  A running Break, bedtime or cool-down always takes priority: no quiz then.
- **API additions:**
  - **Actions:** `POST /v1/action {action:"brainBreak"}` (start now) and `{action:"endBrainBreak"}`.
  - **Status:**

    ```json
    "learning": {"enabled", "showing", "trigger", "grade", "skill",
                 "voice": "ok|noHindi|off", "week": {"breaks", "right", "learned"},
                 "stronger"}
    ```

    `stronger` is the skill most improved this week.
  - **Journal:** each round adds a `brainBreak` entry ("3 questions: 2 right, 1 learned").
- **Phone app (Boretube 2):** the Routines tab gains a **Brain breaks** row that opens the screen from the mockup:
  - on or off, class, language, subjects (Maths only for now)
  - questions each time, read aloud, when it shows
  - this week
  - the single coral **Try a break on the TV now** button

  Without Always On, the row explains that brain breaks need Always On.

## 5. Testing and the device run

- **Kotlin unit tests:**
  - every generator, per class: 4 (or 3) distinct options, the answer among them, wrong options from the mistake rules;
  - the explanation lint;
  - Leitner timing;
  - round mix;
  - promotion and demotion bounds;
  - guess detection;
  - the session state machine;
  - a 10,000-question soak per class;
  - `learning` rules validation;
  - API action validation.
- **Flutter:** the rules round-trip with `learning`, a widget test and golden images for the Brain breaks screen, and the action call.
- **Device run** on the VU3 with TV Guard **1.4.0** (same key, installs as an update):
  1. "Try now" from the phone. Check left, right and OK; Back and Home can't skip it; the video pauses and resumes.
  2. The hopping trigger in SmartTube.
  3. Read-aloud in English and Hindi.
  4. A restart keeps the progress and settings.

**Out of scope:** subjects beyond maths, voice answers, the kid launcher, timing research, and scores that earn screen time.
