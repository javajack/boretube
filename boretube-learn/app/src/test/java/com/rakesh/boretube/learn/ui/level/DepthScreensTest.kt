package com.rakesh.boretube.learn.ui.level

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.pressKey
import com.github.takahirom.roborazzi.captureRoboImage
import com.rakesh.boretube.learn.core.Answered
import com.rakesh.boretube.learn.core.Catalog
import com.rakesh.boretube.learn.core.Format
import com.rakesh.boretube.learn.core.GenSkill
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Opt
import com.rakesh.boretube.learn.core.Run
import com.rakesh.boretube.learn.core.Template
import com.rakesh.boretube.learn.core.gq
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.RecordingSounds
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.speech.Speaker
import com.rakesh.boretube.learn.ui.DesignFrame
import com.rakesh.boretube.learn.ui.LocalUptime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.random.Random

/** True or false, Sort, Order, the animated learn moment, and the Streak run (spec P2b). */
@OptIn(ExperimentalTestApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1280dp-h800dp-xhdpi")
class DepthScreensTest {
    @get:Rule val rule = createComposeRule()
    private val now = 1_800_000_000_000L
    private val sounds = RecordingSounds()
    private var done: List<Answered>? = null
    private var clock = 10_000L

    private val animals = listOf("tiger", "parrot", "frog", "cow", "eagle", "lizard", "goat", "crow", "snake", "camel")
    private val living = listOf("tiger", "neem tree", "ant", "rose", "goat", "fish")
    private val things = listOf("chair", "stone", "spoon", "kite", "bucket", "pencil")

    private fun skill(kind: Format) = GenSkill(
        id = "ev9.test", grade = 3, subject = "evs", title = "Living things", badge = "Life",
        templates = listOf(
            when (kind) {
                Format.truefalse -> Template("tf", 1, intArrayOf(animals.size, 2), Format.truefalse) { p, _ ->
                    val a = animals[p[0]]
                    val eggs = a in setOf("parrot", "frog", "eagle", "lizard", "crow", "snake")
                    val says = p[1] == 0
                    gq("A $a lays eggs.".let { if (says) it else "A $a does not lay eggs." }, Opt.trueFalse(eggs == says), "A $a ${if (eggs) "lays eggs" else "gives birth to babies"}.")
                }
                Format.sort -> Template("sort", 1, intArrayOf(living.size + things.size), Format.sort) { p, _ ->
                    val all = living + things
                    val w = all[p[0]]
                    val alive = w in living
                    gq(w, Opt.baskets("Living", "Non-living", alive), if (alive) "A $w grows, breathes and needs food." else "A $w does not grow or breathe.", fact = "$w is ${if (alive) "living" else "non-living"}")
                }
                else -> Template("cycle", 1, intArrayOf(3), Format.order) { p, r ->
                    val cycles = listOf(
                        listOf("egg", "caterpillar", "pupa", "butterfly"),
                        listOf("seed", "sprout", "plant", "flower"),
                        listOf("egg", "tadpole", "froglet", "frog"),
                    )
                    val c = cycles[p[0]]
                    gq("Put the life cycle in order", c.shuffled(r) to 0, "Each stage grows into the next one.", fact = c.joinToString(" → "), order = c)
                }
            },
            Template("t2", 2, intArrayOf(1)) { _, r -> gq("Which one is living?", Opt.of("ant", listOf("stone", "chair", "spoon"), r)!!, "An ant grows and needs food.") },
        ),
    )

    private fun key(k: Key) = rule.onRoot().performKeyInput { pressKey(k) }

    private fun settle(ms: Long = 400) {
        rule.waitForIdle()
        clock += ms
        rule.mainClock.advanceTimeBy(ms)
        rule.waitForIdle()
    }

    private fun start(kind: Format) {
        val sk = skill(kind)
        val catalog = Catalog(listOf(sk))
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) {
                DesignFrame {
                    LevelScreen(sk.id, LearnState(grade = 3), LearnSettings(grade = 3, set = true), sounds, Speaker.Silent, Random(3), now, catalog,
                        onDone = { done = it }, onLeave = {})
                }
            }
        }
        settle()
    }

    @Test fun trueOrFalse() {
        start(Format.truefalse)
        rule.onNodeWithText("True or false?").assertExists()
        rule.onNodeWithTag("statement").assertExists()
        rule.onRoot().captureRoboImage("src/test/screenshots/level_truefalse.png")
        key(Key.DirectionCenter)
        settle(60)
        rule.onRoot().captureRoboImage("src/test/screenshots/level_truefalse_answered.png")
    }

    @Test fun sortSendsCardsLeftAndRight() {
        start(Format.sort)
        rule.onNodeWithTag("basket-left").assertExists()
        rule.onNodeWithTag("basket-right").assertExists()
        rule.onRoot().captureRoboImage("src/test/screenshots/level_sort.png")
        key(Key.DirectionLeft)
        settle(200)
        assertTrue(sounds.played.contains(Sfx.sort_left))
        rule.onRoot().captureRoboImage("src/test/screenshots/level_sort_dropped.png")
    }

    @Test fun orderPlacesTilesUndoesAndChecks() {
        start(Format.order)
        rule.onNodeWithText("First to last").assertExists()
        key(Key.DirectionCenter)
        settle()
        assertTrue(sounds.played.contains(Sfx.order_1))
        rule.onNodeWithTag("slot-0").assertExists()
        rule.onRoot().captureRoboImage("src/test/screenshots/level_order.png")
        key(Key.Back)
        settle()
        assertTrue(sounds.played.contains(Sfx.build_undo))
        // Place all four in whatever order they sit: likely wrong, so the learn moment shows the right order.
        repeat(4) { key(Key.DirectionCenter); settle() }
        settle(2_500)
        rule.onRoot().captureRoboImage("src/test/screenshots/level_order_after.png")
    }

    @Test fun theLearnMomentAnimatesToItsAha() {
        val q = skill(Format.sort).next(Random(1), 1, Format.sort)
        rule.setContent { DesignFrame { LearnMoment(q, 1 - q.answer, onAha = { sounds.play(Sfx.aha) }) } }
        rule.mainClock.advanceTimeBy(300)
        rule.onRoot().captureRoboImage("src/test/screenshots/level_learn_start.png")
        rule.mainClock.advanceTimeBy(3_000)
        rule.waitForIdle()
        assertTrue(sounds.played.contains(Sfx.aha))
        rule.onNodeWithText("Aha! Here's the trick.").assertExists()
        rule.onRoot().captureRoboImage("src/test/screenshots/level_learn_aha.png")
    }

    @Test fun aStreakRunCountsAndShowsItsMilestone() {
        val sk = skill(Format.sort)
        var ended: Run? = null
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) {
                DesignFrame {
                    RunScreen("trail", "Nature Trail", listOf(sk), LearnSettings(grade = 3, set = true), sounds, Speaker.Silent, Random(5),
                        onDone = { r, _ -> ended = r }, onLeave = {})
                }
            }
        }
        settle()
        rule.onNodeWithTag("run-streak").assertExists()
        rule.onRoot().captureRoboImage("src/test/screenshots/run.png")
        assertEquals(null, ended)
    }

    @Test fun runDone() {
        rule.setContent { DesignFrame { RunDoneScreen(Run("trail", best = 12, right = 15, asked = 18, misses = 3), record = true, "Nature Trail", sounds, {}, {}) } }
        rule.mainClock.advanceTimeBy(3_000)
        rule.onNodeWithTag("run-record").assertExists()
        rule.onRoot().captureRoboImage("src/test/screenshots/run_done.png")
        assertNotNull(sounds.played.firstOrNull { it == Sfx.run_record })
    }
}
