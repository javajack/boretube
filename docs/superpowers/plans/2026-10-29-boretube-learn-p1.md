# boretube Learn P1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. **Tick boxes in this file as tasks land and commit the tick with the task,** so a later session can resume.

**Goal:** A first playable boretube Learn on the TV: Tubby's Town, the Number Bazaar path, Quick-fire and Catch maths levels with the learn moment and Level done, saved progress, the core sounds. The phone installs it.

**Architecture:**
- The engine (ladder, Leitner, sessions) moves from TV Guard into a standalone Kotlin/JVM build, `learn-core`.
- Both `boretube-agent` and the new `boretube-learn` Android TV app consume it through `includeBuild`.
- The Learn app is Compose for TV with token-only styling. Progress is a JSON file owned by the app (the provider and the TV Guard link come in P2).
- The phone bundles `learn.apk` and installs it with the same push-and-verify path as TV Guard.

**Tech stack:**
- Kotlin 1.9.24, AGP 8.5.2, JDK 17 (`~/development/jdk-17`).
- Compose BOM 2024.06.00, Compose compiler 1.5.14, `androidx.tv:tv-material:1.0.0`, `androidx.activity:activity-compose:1.9.0`.
- kotlinx-serialization 1.6.3, Robolectric 4.12.2, Roborazzi 1.26.0.
- Flutter 3.41 for the phone.

**Spec:** `docs/superpowers/specs/2026-10-29-boretube-learn-design.md` (§0 decisions, §5 visual and §6 sound are binding).

## Global constraints

- **Package** `com.rakesh.boretube.learn`. The core package is `com.rakesh.boretube.learn.core`.
- **Signing:** release builds are signed with the agent key: `../boretube-agent/keystore/keystore.properties` → `agent-release.jks`, alias `boretube-agent`. Cert sha256 `a833b38182d99ad47ec945e73234b312d787136cf8ac8a4039c33e9522a58bc0`.
- **SDK:** minSdk 26, compileSdk 34, targetSdk 34.
- **Tokens:**
  - spacing 4 · 8 · 13 · 21 · 34 · 55 · 89 dp;
  - type 18 · 21 · 26 · 34 · 43 · 55 · 89 · 144 sp;
  - radii 8 · 13 · 21 · 34;
  - motion 120 · 200 · 320 · 520 ms;
  - colours: canvas `#FFF4E4`, card `#FFFFFF`, hairline `#EADFD1`, ink `#1C1D3A`, muted `#5B5C78`, coral `#FF6B4A`, sunflower `#FFB020`, mint `#1FBF8F`, sky `#3A8DFF`, lavender `#8C7CFF`;
  - land tints: bazaar `#FFE1A6`, garden `#CDEFE0`, trail `#D6E8FF`.
- **Focus:** the focused item is scaled 1.04–1.15 with a two-ring outline: a 5 dp gap in the canvas colour, then a 5 dp ink (or coral for the primary). One focus at a time; default focus goes to the likely next action.
- **Copy:** never "Wrong" or "Fail". Use "Almost!", "Let's learn this one", "Level done!". Never invent a child's name.
- **Sound:** C major pentatonic. Micro sounds 50–300 ms, celebrations ≤ 2 s. Rate limit: focus ticks no more often than every 120 ms. Effects mute under `sounds=false`.
- **Input:** a 350 ms input grace after each screen change. Volume keys pass through.
- **No laptop `adb install` on the user's TV.** The user installs TV apps through the phone (memory: agent-updates-via-phone).
- **Builds:** `export JAVA_HOME=~/development/jdk-17 PATH=~/development/jdk-17/bin:$PATH`.

## Review focus

1. **A child mashes OK during screen changes** and should never answer the next question by accident. The 350 ms grace and `repeatCount > 0` are ignored (Task 7 test).
2. **A level on a skill with fewer than 8 distinct facts** (e.g. `biggest10` at KG) must still produce 8 questions without an infinite loop or duplicates in a row (Task 2 test).
3. **A corrupt or missing progress file** after a power cut. The app must start with empty progress, not crash, and keep a `.bak` (Task 4 test).
4. **The TV has no TTS engine, or no Hindi voice.** Questions still show and the level still plays (Task 8 test, with a fake speaker).
5. **Catch needs exactly 3 options from 4-option questions,** and the right answer must always be kept (Task 2 test).

---

### Task 1: Extract `learn-core`; TV Guard stays green

**Files:**
- Create: `learn-core/settings.gradle.kts`, `learn-core/build.gradle.kts`, `learn-core/gradle/` (copy the wrapper from the agent)
- Move: `boretube-agent/app/src/main/java/com/rakesh/boretube/agent/core/Maths.kt` → `learn-core/src/main/kotlin/com/rakesh/boretube/learn/core/Maths.kt`
- Split: `boretube-agent/.../core/Learn.kt`:
  - the engine part (`Fact`, `SkillStat`, `WeekLog`, `LearnState`, `Learner`, `Answered`, `QuizScreen`, `BrainBreakSession`) → `learn-core/.../Learn.kt`;
  - the agent part (`LearningRules`, `PlayClock`, `BrainBreakGate`, `LearningDoc`, `WeekDoc`) stays in the agent at `core/Learning.kt`.
- Move: the engine tests in `LearnTest.kt` → `learn-core/src/test/kotlin/.../LearnTest.kt`. `rulesValidateLearning` and `actionsValidate` stay in the agent as `LearningRulesTest.kt`.
- Modify: `boretube-agent/settings.gradle` (includeBuild), `boretube-agent/app/build.gradle` (dependency), and every agent file that uses the moved types (imports): `GuardController.kt`, `BrainBreakWindow.kt`, `QuizView.kt`, `AgentStore.kt`, `MediaGuard.kt` if needed.

**Interfaces:**
- Produces, in package `com.rakesh.boretube.learn.core`: `Maths`, `Skill`, `Question`, `Visual`, `Fact`, `SkillStat`, `WeekLog`, `LearnState`, `Learner`, `Answered`, `QuizScreen`, `BrainBreakSession`. Their signatures are unchanged from TV Guard 1.4.1.
- Maven coordinates: `com.rakesh.boretube:learn-core:1.0`.

- [x] **Step 1: Create the build.** Write `learn-core/settings.gradle.kts`:

```kotlin
rootProject.name = "learn-core"
dependencyResolutionManagement { repositories { mavenCentral() } }
```

and `learn-core/build.gradle.kts`:

```kotlin
plugins {
    kotlin("jvm") version "1.9.24"
    kotlin("plugin.serialization") version "1.9.24"
}
group = "com.rakesh.boretube"
version = "1.0"
kotlin { jvmToolchain(17) }
dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.6.3")
    testImplementation("junit:junit:4.13.2")
}
```

Copy the wrapper: `cp -r boretube-agent/gradle boretube-agent/gradlew learn-core/`.

- [x] **Step 2: Move the code.** Use `git mv` for `Maths.kt`. Create the engine `Learn.kt` in core and change the package line to `com.rakesh.boretube.learn.core`. In the agent, keep `core/Learning.kt` with the agent types, and add `import com.rakesh.boretube.learn.core.*` where needed. `LearnState` must stay `@Serializable`: the agent persists it.

- [x] **Step 3: Wire it up.** Agent `settings.gradle`:

```groovy
includeBuild('../learn-core') {
    dependencySubstitution { substitute module('com.rakesh.boretube:learn-core') using project(':') }
}
```

In `app/build.gradle` dependencies: `implementation 'com.rakesh.boretube:learn-core:1.0'`.

- [x] **Step 4: Run both suites.**

```bash
cd learn-core && ./gradlew -q test && cd ../boretube-agent && ./gradlew -q testReleaseUnitTest assembleRelease
```

Expected: all green. The engine tests now run in learn-core, and the agent's 153 minus the moved ones plus `LearningRulesTest` pass.

- [x] **Step 5: Commit.** `git commit -m "learn-core: the learning engine as a shared Kotlin build; TV Guard uses it"`.

---

### Task 2: Levels in `learn-core`: an 8-question plan, Catch options, stars, mastery

**Files:**
- Create: `learn-core/src/main/kotlin/com/rakesh/boretube/learn/core/Levels.kt`
- Modify: `learn-core/.../Learn.kt` (`LearnState` gains `stars` and `mastered`)
- Test: `learn-core/src/test/kotlin/.../LevelsTest.kt`

**Interfaces:**
- Produces:
  - `enum class Format { quickfire, catch }`
  - `object Levels`, with:
    - `fun plan(s: LearnState, skillId: String, n: Int = 8, now: Long, r: Random): List<Question>`
    - `fun forCatch(q: Question, r: Random): Question`
    - `fun stars(right: Int, total: Int): Int`
    - `fun formatFor(skillId: String): Format`
    - `fun finish(s: LearnState, skillId: String, results: List<Answered>, today: LocalDate): LevelResult`
  - `data class LevelResult(val state: LearnState, val stars: Int, val bestStars: Int, val newlyMastered: Boolean, val toPractise: Question?)`
  - On `LearnState`: `stars: Map<String, Int> = emptyMap()` and `mastered: List<String> = emptyList()`
  - `fun Learner.isMastered(s: LearnState, skillId: String): Boolean`: true when `stats[skillId].right >= 3 && days.size >= 2`.

- [x] **Step 1: Write the failing tests.**

```kotlin
class LevelsTest {
    private val now = 1_800_000_000_000L
    private val day = LocalDate.parse("2026-10-29")

    @Test fun planHasEightQuestionsEvenForSmallSkills() {
        for (id in listOf("biggest10", "count10", "tablesHigh", "fractions")) {
            val p = Levels.plan(LearnState(grade = 0), id, 8, now, Random(1))
            assertEquals(id, 8, p.size)
            assertTrue(id, p.all { it.skill == id })
            assertTrue("no repeat back to back in $id", p.zipWithNext().none { (a, b) -> a.key == b.key })
        }
    }

    @Test fun dueFactsOfThisSkillComeFirst() {
        val s = LearnState(facts = listOf(Fact("tablesHigh:7:8", 1, now - 1)))
        assertEquals("tablesHigh:7:8", Levels.plan(s, "tablesHigh", 8, now, Random(2)).first().key)
    }

    @Test fun catchKeepsTheAnswerAndTwoMistakes() {
        repeat(200) { i ->
            val q = Maths.skill("tablesHigh")!!.next(Random(i))
            val c = Levels.forCatch(q, Random(i))
            assertEquals(3, c.options.size)
            assertEquals(q.answerText, c.answerText)
            assertTrue(c.options.all { it in q.options })
        }
    }

    @Test fun starsForAccuracyOnly() {
        assertEquals(1, Levels.stars(0, 8))
        assertEquals(1, Levels.stars(4, 8))
        assertEquals(2, Levels.stars(5, 8))
        assertEquals(2, Levels.stars(6, 8))
        assertEquals(3, Levels.stars(7, 8))
        assertEquals(3, Levels.stars(8, 8))
    }

    @Test fun finishKeepsBestStarsAndMarksMastery() {
        var s = LearnState(grade = 4, rung = Maths.indexOf("tablesHigh"))
        val q = Maths.fromKey("tablesHigh:7:8", Random(1))!!
        val all = List(8) { Answered(q, q.answer, true, 2_000, false) }
        s = Levels.finish(s, "tablesHigh", all, day).state
        val r2 = Levels.finish(s, "tablesHigh", all.mapIndexed { i, a -> if (i < 4) a.copy(correct = false) else a }, day.plusDays(1))
        assertEquals(1, r2.stars)
        assertEquals(3, r2.bestStars)
        assertTrue(r2.newlyMastered)
        assertTrue("tablesHigh" in r2.state.mastered)
        assertFalse(Levels.finish(r2.state, "tablesHigh", all, day.plusDays(2)).newlyMastered)
    }

    @Test fun formatsAlternateSensibly() {
        assertEquals(Format.catch, Levels.formatFor("tablesHigh"))
        assertEquals(Format.quickfire, Levels.formatFor("clock"))
        assertEquals(Format.quickfire, Levels.formatFor("fractions"))
    }
}
```

`finish` records each answer through `Learner.record` (same day), computes stars from main answers (`!followUp`), keeps the best per skill, appends to `mastered` when `isMastered` turns true, and picks `toPractise` as the first main answer that was wrong.

- [x] **Step 2: Run them and watch them fail.** `cd learn-core && ./gradlew -q test --tests '*LevelsTest*'`. Expected: compile errors (`Levels` not defined).

- [x] **Step 3: Implement `Levels.kt`.**

```kotlin
package com.rakesh.boretube.learn.core

import java.time.LocalDate
import kotlin.random.Random

enum class Format { quickfire, catch }

data class LevelResult(
    val state: LearnState, val stars: Int, val bestStars: Int,
    val newlyMastered: Boolean, val toPractise: Question?,
)

/** A level: 8 questions on one skill, in one format; stars for accuracy only. */
object Levels {
    /** Catch suits number answers; clocks, pies and text answers play as Quick-fire. */
    private val QUICKFIRE_ONLY = setOf("clock", "fractions", "decimals", "count10", "biggest10")

    fun formatFor(skillId: String): Format = if (skillId in QUICKFIRE_ONLY) Format.quickfire else Format.catch

    /** Due facts of [skillId] first, then fresh ones; never the same key twice in a row. */
    fun plan(s: LearnState, skillId: String, n: Int = 8, now: Long, r: Random): List<Question> {
        val skill = Maths.skill(skillId) ?: return emptyList()
        val out = mutableListOf<Question>()
        for (f in s.facts.filter { it.dueAt <= now && it.key.startsWith("$skillId:") }.sortedBy { it.dueAt }) {
            if (out.size < n) Maths.fromKey(f.key, r)?.let { out += it }
        }
        val seen = out.map { it.key }.toMutableSet()
        var tries = 0
        while (out.size < n && tries++ < n * 20) {
            val q = skill.next(r)
            val fresh = q.key !in seen
            val notBackToBack = out.lastOrNull()?.key != q.key
            if (fresh || (tries > n * 10 && notBackToBack)) { out += q; seen += q.key }
        }
        return out
    }

    /** Three options for Catch: the answer plus the first two mistakes, reshuffled. */
    fun forCatch(q: Question, r: Random): Question {
        if (q.options.size <= 3) return q
        val wrong = q.options.filterIndexed { i, _ -> i != q.answer }.take(2)
        val opts = (wrong + q.answerText).shuffled(r)
        return q.copy(options = opts, answer = opts.indexOf(q.answerText))
    }

    fun stars(right: Int, total: Int): Int {
        if (total <= 0) return 1
        val p = right.toDouble() / total
        return when { p >= 0.85 -> 3; p >= 0.6 -> 2; else -> 1 }
    }

    fun finish(s: LearnState, skillId: String, results: List<Answered>, today: LocalDate): LevelResult {
        var st = s
        val now = today.toEpochDay() * 86_400_000L
        for (a in results) st = Learner.record(st, a.q, a.correct, a.ms, now, today)
        val main = results.filter { !it.followUp }
        val stars = stars(main.count { it.correct }, main.size)
        val best = maxOf(stars, st.stars[skillId] ?: 0)
        val nowMastered = Learner.isMastered(st, skillId)
        val newly = nowMastered && skillId !in st.mastered
        st = st.copy(
            stars = st.stars + (skillId to best),
            mastered = if (newly) st.mastered + skillId else st.mastered,
        )
        return LevelResult(st, stars, best, newly, main.firstOrNull { !it.correct }?.q)
    }
}
```

(7 of 8 is 0.875, so it gets 3 stars; 5 of 8 is 0.625, so 2 stars; 4 of 8 is 0.5, so 1 star. This matches the tests.) Add `fun isMastered(s: LearnState, skillId: String)` to `Learner`, reusing `PROMOTE_RIGHT` and `PROMOTE_DAYS`. Add the two `LearnState` fields with defaults; old JSON still parses.

- [x] **Step 4: Run all learn-core tests.** Expected: PASS.

- [x] **Step 5: Commit.** `git commit -m "learn-core: levels (8-question plan, Catch options, stars, mastery)"`.

---

### Task 3: The Learn app shell: build, tokens, fonts, theme, focus ring, Tubby

**Files:**
- Create: `boretube-learn/{settings.gradle,build.gradle,gradle.properties,gradlew,gradle/}` (wrapper copied from the agent), `boretube-learn/app/build.gradle`
- Create: `app/src/main/AndroidManifest.xml`, `res/drawable/banner.xml` (320×180 vector: cream ground, Tubby, "Learn"), `res/values/strings.xml`
- Create: `res/font/bricolage.ttf` (copy `boretube-agent/app/src/main/assets/fonts/BricolageGrotesque-Variable.ttf`), `res/font/figtree.ttf` (copy `boretube-mobile/assets/fonts/Figtree-Variable.ttf`); OFL licence texts go in `assets/licenses/`
- Create: `app/src/main/java/com/rakesh/boretube/learn/ui/Tokens.kt`, `Theme.kt`, `Focus.kt` (the `focusRing` modifier), `Tubby.kt` (Compose Canvas port of the agent's `Tubby.kt`)
- Create: `MainActivity.kt` (the app with one state-driven `when` over `Screen`)
- Test: `app/src/test/java/.../ui/FocusRingTest.kt` (Robolectric + compose ui-test)

**Interfaces:**
- Produces:
  - `object Gap { f4, f8, f13, f21, f34, f55, f89 }` (Dp)
  - `object TypeScale { s18 … s144 }` (TextUnit)
  - `object Radii { r8, r13, r21, r34 }`
  - `object Motion { press = 120, flip = 200, sheet = 320, slow = 520 }` (Int ms)
  - `object Palette { canvas, card, hairline, ink, muted, coral, sunflower, mint, sky, lavender, bazaar, garden, trail }`
  - `val Display: FontFamily` (Bricolage 800 via `FontVariation.weight(800)`) and `val Body: FontFamily` (Figtree)
  - `fun Modifier.focusRing(shape: Shape, primary: Boolean = false, scale: Float = 1.04f): Modifier`: tracks focus, animates scale over `Motion.press`, draws the two rings
  - `@Composable fun Tubby(mood: TubbyMood, modifier: Modifier)` with `enum class TubbyMood { calm, cheer, think, asleep }`. Antennae and legs are ink on daylight grounds.
  - `sealed interface Screen { object Town; data class Land(val land: LandId); data class Level(val skillId: String); data class Done(val result: LevelResult, val skillId: String) }`

- [x] **Step 1: Write the Gradle files.** Top level: same plugin versions as the agent, plus `id 'org.jetbrains.kotlin.plugin.serialization'`. `settings.gradle` has `includeBuild('../learn-core')` with the same substitution as Task 1. `app/build.gradle`:
  - signing config read from `../boretube-agent/keystore/keystore.properties` (path: `rootProject.file('../boretube-agent/keystore/' + props['storeFile'].replace('keystore/',''))`);
  - `buildFeatures { compose true }` and `composeOptions { kotlinCompilerExtensionVersion '1.5.14' }`;
  - dependencies:
    - `platform('androidx.compose:compose-bom:2024.06.00')`, `androidx.compose.ui:ui`, `androidx.compose.foundation:foundation`, `androidx.tv:tv-material:1.0.0`, `androidx.activity:activity-compose:1.9.0`;
    - `com.rakesh.boretube:learn-core:1.0`, kotlinx-serialization-json 1.6.3;
    - tests: `junit 4.13.2`, `org.robolectric:robolectric:4.12.2`, `androidx.compose.ui:ui-test-junit4`, `androidx.compose.ui:ui-test-manifest`, `io.github.takahirom.roborazzi:roborazzi:1.26.0` and `roborazzi-compose:1.26.0`;
    - `testOptions { unitTests.includeAndroidResources = true }`.

- [x] **Step 2: Write the manifest.**
  - `<uses-feature android:name="android.software.leanback" android:required="false"/>` and touchscreen required false.
  - The application has `android:banner="@drawable/banner"`.
  - The activity is exported, with intent filters for MAIN plus LEANBACK_LAUNCHER and MAIN plus LAUNCHER, `screenOrientation="landscape"`, and the theme `@android:style/Theme.DeviceDefault.NoActionBar`.

- [x] **Step 3: Write the failing focus-ring test.**

```kotlin
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1280dp-h720dp-xhdpi")
class FocusRingTest {
    @get:Rule val rule = createComposeRule()
    @Test fun onlyTheFocusedItemIsMarked() {
        rule.setContent {
            Row { repeat(3) { i -> Box(Modifier.testTag("b$i").size(100.dp).focusRing(RoundedCornerShape(Radii.r21)).focusable()) } }
        }
        rule.onNodeWithTag("b1").requestFocus()
        rule.waitForIdle()
        rule.onNodeWithTag("b1").assert(SemanticsMatcher.expectValue(FocusedKey, true))
        rule.onNodeWithTag("b0").assert(SemanticsMatcher.expectValue(FocusedKey, false))
    }
}
```

`FocusedKey` is a `SemanticsPropertyKey<Boolean>` that `focusRing` sets. It's for tests and accessibility.

- [x] **Step 4: Implement the tokens, theme, `focusRing` and Tubby.** `focusRing` uses `onFocusChanged` and `animateFloatAsState(if (focused) scale else 1f, tween(Motion.press))`, then `graphicsLayer { scaleX = s; scaleY = s }`. When focused, a `drawWithContent` draws a 5 dp canvas-coloured outline and then a 5 dp ink or coral outline outside the bounds. Port Tubby's geometry from `boretube-agent/.../android/Tubby.kt` (viewBox 120×110) onto a `Canvas`, with ink for the antennae and legs.

- [x] **Step 5: Run.** `./gradlew -q testReleaseUnitTest assembleRelease`. Expected: PASS, and the APK signs with cert a833b381…: `apksigner verify --print-certs`.

- [x] **Step 6: Commit.** `git commit -m "boretube-learn: app shell, tokens, focus ring, Tubby"`.

---

### Task 4: ProgressStore and settings

**Files:**
- Create: `app/src/main/java/com/rakesh/boretube/learn/data/ProgressStore.kt`, `Settings.kt`
- Test: `app/src/test/java/.../data/ProgressStoreTest.kt` (plain JVM; the store takes a `File` dir)

**Interfaces:**
- Produces:
  - `class ProgressStore(dir: File)` with `fun load(): LearnState` and `fun save(s: LearnState)`. Saves are atomic: write `progress.json.tmp`, rename the old file to `.bak`, then rename the temp file. `load` falls back to `.bak`, then to `LearnState()`.
  - `data class LearnSettings(val grade: Int = 1, val lang: String = "en", val sounds: Boolean = true, val music: Boolean = true, val set: Boolean = false)`
  - `class SettingsStore(prefs: SharedPreferences)` with `get(): LearnSettings` and `put(LearnSettings)`.

- [x] **Step 1: Write the failing tests.**

```kotlin
class ProgressStoreTest {
    @get:Rule val tmp = TemporaryFolder()
    @Test fun roundTrips() {
        val st = ProgressStore(tmp.root)
        val s = LearnState(grade = 3, rung = 9, stars = mapOf("tablesLow" to 2))
        st.save(s)
        assertEquals(s, ProgressStore(tmp.root).load())
    }
    @Test fun corruptFileFallsBackToBackup() {
        val st = ProgressStore(tmp.root)
        st.save(LearnState(grade = 2)); st.save(LearnState(grade = 3))
        File(tmp.root, "progress.json").writeText("{garbage")
        assertEquals(2, ProgressStore(tmp.root).load().grade)
    }
    @Test fun nothingSavedIsEmptyProgress() {
        assertEquals(LearnState(), ProgressStore(tmp.root).load())
        File(tmp.root, "progress.json").writeText("")
        assertEquals(LearnState(), ProgressStore(tmp.root).load())
    }
}
```

- [x] **Step 2: Run them and watch them fail.**
- [x] **Step 3: Implement.** Use `Json { ignoreUnknownKeys = true; encodeDefaults = true }`.
- [x] **Step 4: Run them and watch them pass.**
- [x] **Step 5: Commit.** `git commit -m "boretube-learn: progress store with backup, settings"`.

---

### Task 5: The core sounds: synth script, SoundBank, catalogue test

**Files:**
- Create: `boretube-learn/tools/sfx.py`, which renders OGG files to `app/src/main/res/raw/` with numpy and ffmpeg
- Create: `app/src/main/res/raw/LICENSES.md` ("Rendered by tools/sfx.py; © boretube, CC0")
- Create: `app/src/main/java/com/rakesh/boretube/learn/sound/SoundBank.kt`, `Sfx.kt`
- Test: `app/src/test/java/.../sound/SfxCatalogTest.kt`

**Interfaces:**
- Produces:
  - `enum class Sfx(val res: String)` with values `select`, `back`, `focus_bazaar`, `focus_garden`, `focus_trail`, `q_show`, `right_1`…`right_5`, `miss`, `learn_open`, `followup_win`, `catch_drop`, `catch_move`, `catch_right`, `catch_miss`, `star_1`…`star_3`, `level_done_bazaar`, `enter_bazaar`
  - `class SoundBank(ctx: Context, enabled: () -> Boolean)` with `fun play(s: Sfx)`, `fun right(streak: Int)` (clamped to 1..5) and `fun release()`. It's backed by `SoundPool` (maxStreams 6), with every sound loaded in `init`. A focus tick plays only if at least 120 ms have passed since the last one.

- [x] **Step 1: Write `sfx.py`.** It covers these sounds:
  - a pentatonic note table: C5 523.25, D5 587.33, E5 659.25, G5 783.99, A5 880, then C6 and up;
  - `marimba(f, dur)`: a sine plus a 4× partial, with an exponential decay;
  - `bell(f)`: inharmonic partials 1, 2.76 and 5.4;
  - `pop`: a pitch drop from 900 to 300 Hz over 60 ms;
  - `whoosh`: band-passed noise with a sweep;
  - `tick`: a 25 ms marimba at G6 for the bazaar, a bell at E6 for the garden, and a woodblock at C6 for the trail;
  - `right_n`: two marimba notes going up, starting at pentatonic step n;
  - `miss`: two soft sine notes going down (A4 → E4) with a slow attack, never a buzz;
  - fanfares are arpeggios of at most 1.8 s;
  - all normalised to -18 LUFS (RMS approximation) with 5 ms fade in and out.

  It writes a WAV per sound, then runs `ffmpeg -y -i x.wav -c:a libvorbis -q:a 4 x.ogg`. Run `python3 tools/sfx.py`. Expected: 25 `.ogg` files, under 400 KB in total.

- [x] **Step 2: Write the failing catalogue test.**

```kotlin
@RunWith(RobolectricTestRunner::class)
class SfxCatalogTest {
    @Test fun everySoundHasAFile() {
        val ctx = ApplicationProvider.getApplicationContext<Context>()
        for (s in Sfx.entries) assertTrue(s.res, ctx.resources.getIdentifier(s.res, "raw", ctx.packageName) != 0)
    }
    @Test fun rightClampsToFive() { assertEquals(Sfx.right_5, Sfx.right(9)); assertEquals(Sfx.right_1, Sfx.right(0)) }
}
```

- [x] **Step 3: Implement `Sfx` (with `companion fun right(n)`) and `SoundBank`.**
- [x] **Step 4: Run them and watch them pass.**
- [x] **Step 5: Commit.** `git commit -m "boretube-learn: core sounds (own synth) and SoundBank"`.

---

### Task 6: The Town and the Land path

**Files:**
- Create: `app/src/main/java/com/rakesh/boretube/learn/world/Lands.kt`, which maps each land to its subject, tint, motif and skills (Bazaar: `Maths.LADDER`; Garden and Trail: empty in P1)
- Create: `ui/TownScreen.kt` (mock artboard 1), `ui/LandScreen.kt` (artboard 2), `ui/Scenes.kt` (the three land scenes drawn on a Canvas, ported from the mock SVGs)
- Test: `app/src/test/java/.../ui/TownScreenTest.kt`, `LandScreenTest.kt`, plus Roborazzi screenshots in `app/src/test/screenshots/`

**Interfaces:**
- Consumes: `LearnState`, `Learner`, `Maths`, `Levels`, Task 3's tokens and `focusRing`, Task 5's `SoundBank`.
- Produces:
  - `enum class LandId { bazaar, garden, trail }`
  - `data class LandInfo(val id: LandId, val name: String, val subject: String, val tint: Color, val skills: List<String>)`
  - `fun landProgress(s: LearnState, l: LandInfo, grade: Int): LandProgress(mastered, total, next: String?)`, which walks the grade's window `Maths.minRung..Maths.maxRung`
  - `@Composable fun TownScreen(state: LearnState, settings: LearnSettings, sounds: SoundBank, onLand: (LandId) -> Unit)`
  - `@Composable fun LandScreen(land: LandInfo, state: LearnState, settings: LearnSettings, sounds: SoundBank, onPlay: (String) -> Unit, onBack: () -> Unit)`

- [x] **Step 1: Write the failing tests.**

```kotlin
@RunWith(RobolectricTestRunner::class) @Config(qualifiers = "w1280dp-h720dp-xhdpi")
class TownScreenTest {
    @get:Rule val rule = createComposeRule()
    @Test fun bazaarIsFocusedAndOpens() {
        var opened: LandId? = null
        rule.setContent { TownScreen(LearnState(grade = 4), LearnSettings(grade = 4, set = true), FakeSounds()) { opened = it } }
        rule.onNodeWithTag("land-bazaar").assert(SemanticsMatcher.expectValue(FocusedKey, true))
        rule.onRoot().performKeyInput { pressKey(Key.DirectionCenter) }
        assertEquals(LandId.bazaar, opened)
    }
    @Test fun gardenSaysComingSoonInP1() {
        rule.setContent { TownScreen(LearnState(), LearnSettings(set = true), FakeSounds()) {} }
        rule.onNodeWithText("New levels coming soon").assertExists()
    }
    @Test fun screenshot() { rule.setContent { TownScreen(LearnState(grade = 4, stars = mapOf("tablesLow" to 3)), LearnSettings(grade = 4, set = true), FakeSounds()) {} }; rule.onRoot().captureRoboImage("src/test/screenshots/town.png") }
}
```

`LandScreenTest` covers four things:
- the current rung's node is focused;
- ◀ ▶ walks the path;
- OK calls `onPlay(skillId)`;
- Back calls `onBack`; plus a screenshot.

`FakeSounds` is a `SoundBank` stand-in. Make `SoundBank` an interface `Sounds` with the real `SoundPoolSounds`.

- [x] **Step 2: Run them and watch them fail.**
- [x] **Step 3: Implement both screens to match the mocks.**
  - **Town:** 3 equal cards, 440 tall, radius 34. Each has a scene 250 tall, the name in Bricolage 34, the subject line, and "Next: …". The header has Tubby, "Tubby's Town" at 43, and the greeting by time of day ("Good morning!", "Good afternoon!", "Good evening!"). Garden and Trail show "New levels coming soon", stay focusable, and on OK say "Coming soon" with a gentle `back` sound instead of entering.
  - **Land:** the left panel is 470 dp wide; the dotted path is a Canvas cubic through node centres; nodes are 89 dp. Styles: done nodes are sunflower with a ✓ and stars, the current node is coral at 1.15 scale, open nodes are cream with a hairline.
  - Focus plays `focus_<land>` and OK plays `select`.
- [x] **Step 4: Run the tests and look at the screenshots.** Open `src/test/screenshots/*.png` and compare them with the mock artboards; fix any mismatch before you go on.
- [x] **Step 5: Commit.** `git commit -m "boretube-learn: Tubby's Town and the Number Bazaar path"`.

---

### Task 7: A level: Quick-fire and Catch, the learn moment, the input grace

**Files:**
- Create: `ui/level/LevelScreen.kt` (hosts a `BrainBreakSession` over `Levels.plan`), `ui/level/QuickFire.kt`, `ui/level/Catch.kt`, `ui/level/LearnMoment.kt`, `ui/level/Visuals.kt` (mangoes, dots, pies, clock as composables; port the geometry from the agent's `QuizView`)
- Create: `ui/level/InputGrace.kt`: `Modifier.onRemoteKeys(graceMs = 350, onLeft, onRight, onOk, onBack)` ignores OK for 350 ms after `resetKey` changes and ignores repeats
- Test: `app/src/test/java/.../ui/level/LevelScreenTest.kt` plus screenshots

**Interfaces:**
- Consumes: `Levels.plan`, `Levels.forCatch`, `Levels.formatFor`, `BrainBreakSession`, `QuizScreen`, `Sounds`, the `Speaker` from Task 8 (pass in `Speaker.Silent` for tests).
- Produces: `@Composable fun LevelScreen(skillId: String, state: LearnState, settings: LearnSettings, sounds: Sounds, speaker: Speaker, random: Random, onDone: (List<Answered>) -> Unit, onLeave: () -> Unit)`.

- [x] **Step 1: Write the failing tests.**

```kotlin
@Test fun okRightAfterAScreenChangeIsIgnored() {
    var picks = 0
    rule.mainClock.autoAdvance = false
    rule.setContent { LevelScreen("tablesLow", LearnState(grade = 3), LearnSettings(grade = 3, set = true), FakeSounds(), Speaker.Silent, Random(3), onDone = {}, onLeave = {}) }
    rule.onRoot().performKeyInput { pressKey(Key.DirectionCenter) }   // within 350 ms
    rule.mainClock.advanceTimeBy(400)
    rule.onNodeWithTag("progress").assertTextEquals("1 of 8")
}
@Test fun aMissShowsTheLearnMomentThenAnEasierOne() { /* pick a wrong tile (index != answer, computed from the plan with the same Random seed), assert tag "learn-moment" shows the explain text, OK → tag "ask-followup" */ }
@Test fun eightAnswersFinishTheLevel() { /* answer all 8 right via keys with clock advances; assert onDone called with 8 main results */ }
@Test fun backAsksBeforeLeaving() { /* Back → "Leave this level?" with Stay focused; OK on Stay keeps the level */ }
@Test fun catchHasThreeLanesAndTheBasketMoves() { /* tablesHigh → tags lane-0..2; ◀ ▶ moves "basket" lane index; OK catches the lane's answer */ }
```

(In the code, write these bodies out fully. The seeded `Random` fixes which tile is right, so `val q = Levels.plan(state, id, 8, now, Random(3)).first()` gives the expected answer index.)

- [x] **Step 2: Run them and watch them fail.**
- [x] **Step 3: Implement.**
  - **Quick-fire** (daylight version of the brain-break layout):
    - the question top left at 89 (fit down to 55), and "n of 8" with a thin bar top right;
    - 4 tiles in one row, 144 tall (233 for pies), white with the hairline; the focused tile is ink with cream text;
    - a decorative timer bar fills over 20 s, then just stays full (nothing happens).
  - **Catch** (mock artboard 4): 3 lanes on the bazaar tint.
    - The balls fall with `Animatable` over 3.2 s and rest at the bottom.
    - The basket (Tubby) moves between lanes (120 ms). OK catches the ball in the basket's lane.
    - Sounds: `catch_drop` when the balls start, `catch_move` on each move, `catch_right` or `catch_miss` on the catch.
  - **Right:** `sounds.right(streak)`, a tile flash to mint for 200 ms, then the next question after 900 ms.
  - **Miss:** `miss`, then the learn moment (`learn_open`): the fact with the answer in sunflower, "You picked X" struck through, the explanation in Figtree 34, the learn visual, and **Got it**. The follow-up uses `followup_win` when it's right.
  - Back opens the leave sheet.
- [x] **Step 4: Run them, watch them pass, and look at the screenshots** (compare with mock artboard 4).
- [x] **Step 5: Commit.** `git commit -m "boretube-learn: Quick-fire and Catch levels with the learn moment"`.

---

### Task 8: Read aloud and Level done

**Files:**
- Create: `speech/Speaker.kt`: `interface Speaker { fun say(text: String, hindi: Boolean); fun stop(); object Silent : Speaker }` and `TtsSpeaker(ctx)` (en-IN or hi-IN with a fallback to English; reports `hindiAvailable`)
- Move: the `speakable()` text conversion → `learn-core/.../Speakable.kt` (tests move with it). The agent's `BrainBreakWindow` calls the core version.
- Create: `ui/DoneScreen.kt` (mock artboard 3)
- Test: `DoneScreenTest.kt`, `learn-core SpeakableTest.kt`

**Interfaces:**
- Consumes: `Levels.finish`, `LevelResult`.
- Produces: `@Composable fun DoneScreen(result: LevelResult, skillTitle: String, sounds: Sounds, onAnother: () -> Unit, onTown: () -> Unit)`.

- [x] **Step 1: Write the failing tests.**
  - **`SpeakableTest`:** `"7 × 8 = 56"` gives `"7 times 8 is 56"` in English and `"7 गुणा 8 बराबर 56"` in Hindi.
  - **`DoneScreenTest`:**
    - **Play another** has the default focus;
    - 2 stars render as 2 filled and 1 outline (tags);
    - the sticker card appears only when `newlyMastered`;
    - the practise line appears when `toPractise != null`;
    - a screenshot.
  - **The level without TTS:** a `Speaker` that throws on `say` must not stop the level. Wrap calls in `runCatching`; test with a `ThrowingSpeaker`.
- [x] **Step 2: Run them and watch them fail.**
- [x] **Step 3: Implement.**
  - The stars count in one at a time (`star_1..3`, 320 ms apart), then `level_done_bazaar`.
  - P1 sticker card: a sticker for each mastered skill. P1 ships one generic "Peacock" art for every skill, with the skill title as the line; distinct art comes in P2.
  - Questions are spoken when shown if `settings.lang != "en"` or the grade is ≤ 1. Otherwise only ▲ "hear it again" speaks.
- [x] **Step 4: Run them and watch them pass.**
- [x] **Step 5: Commit.** `git commit -m "boretube-learn: read aloud and Level done"`.

---

### Task 9: Wire the app together and add the first-run picker

**Files:**
- Modify: `MainActivity.kt`. It holds a `Screen` state, `ProgressStore`, `SettingsStore`, `SoundPoolSounds` and `TtsSpeaker`. It saves after each `Levels.finish` and handles Back on Town (finishes the activity).
- Create: `ui/FirstRunScreen.kt`: Tubby, "Which class are you in?" with 8 chips in 2 rows of 4 (KG, Class 1…Class 7), then the language (3 tiles), then "Let's go!". It shows only while `!settings.set`.
- Test: `AppFlowTest.kt`: first run → Town → Bazaar → a level → Done → Town, with an in-memory store.

- [x] **Step 1: Write the failing flow test.**
- [x] **Step 2: Run it and watch it fail.**
- [x] **Step 3: Implement.**
- [x] **Step 4: Run it, watch it pass, and build the release APK.** Run `./gradlew -q testReleaseUnitTest assembleRelease`, then `apksigner verify --print-certs app/build/outputs/apk/release/app-release.apk`. Expected: cert a833b381…
- [x] **Step 5: Commit.** `git commit -m "boretube-learn: app flow and first-run class picker"`.

---

### Task 10: The phone bundles Learn and installs it from Better TV

**Files:**
- Create: `boretube-mobile/assets/learn/manifest.json` and `boretube-mobile/assets/learn/boretube-learn.apk`; add `- assets/learn/` to `pubspec.yaml`
- Create: `boretube-mobile/lib/learn/learn_installer.dart`. It reuses `AgentInstaller.pushCommands` (make it a top-level `apkPushCommands`) and the same steps: push, sha256 check, `pm install -r`, verify `dumpsys package`. It journals through `TvOps`.
- Modify: `boretube-mobile/lib/screens/better_tv_tab.dart`. Add a destination row, **Learning app**: "Tubby's Town, maths levels", with Install, Update (bundled newer) or Open (`monkey -p com.rakesh.boretube.learn 1`). It needs Home mode (ADB).
- Test: `test/learn/learn_installer_test.dart` (fake ADB, like the agent installer tests), `test/widget/better_tv_test.dart` (the row's states), plus goldens

**Interfaces:**
- Produces:
  - `class LearnBundle { LearnManifest manifest; Uint8List apk; static Future<LearnBundle> load([AssetBundle?]) }`
  - `class LearnInstaller { Future<LearnDiagnosis> diagnose(); Stream<SetupStep> install(); Future<bool> open(); }`
  - `enum LearnInstallState { missing, current, updateAvailable }` (not `LearnState`, which is the Kotlin progress type)

- [ ] **Step 1: Write the failing installer tests:** the happy path; a damaged copy fails and cleans up; a signature mismatch gives plain words; diagnose reads `versionName`.
- [ ] **Step 2: Run them and watch them fail.**
- [ ] **Step 3: Implement it, copy the APK and write the manifest** (sha256 from `sha256sum`, cert from `apksigner`).
- [ ] **Step 4: Run `flutter analyze` and `flutter test`; update goldens for Better TV.**
- [ ] **Step 5: Commit.** `git commit -m "Phone: bundle boretube Learn and install it from Better TV"`.

---

### Task 11: Device run on the VU3, the knowledge base, and the spec status

- [ ] **Step 1:** Build and install the phone app (`flutter build apk --release`, then `adb -s <phone> install -r`). Ask the user to tap **Install** on the Learning app row.
- [ ] **Step 2:** The user opens Learn from the TV home screen. Verify by watching `adb logcat` and taking screenshots with `adb exec-out screencap -p` (read-only on the TV):
  1. the first-run picker;
  2. the Town, and focus on the Bazaar;
  3. the path;
  4. a Catch level, including the basket;
  5. a miss, the learn moment and the follow-up;
  6. Level done with stars;
  7. the sounds are audible and pleasant at normal TV volume, and none are harsh;
  8. Back from the Town exits.
- [ ] **Step 3:** Restart the TV only with the user's OK, then confirm the progress persisted.
- [ ] **Step 4:** Add a "Learn app on the VU3 (verified)" section to `docs/knowledge/sony-bravia-vu3.md`, tick P1 in spec §11, update `AGENTS.md` (map rows for `learn-core/` and `boretube-learn/`) and the README. Commit and offer to push.
