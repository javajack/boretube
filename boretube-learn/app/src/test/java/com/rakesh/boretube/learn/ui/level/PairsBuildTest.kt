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
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Levels
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.RecordingSounds
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.speech.Speaker
import com.rakesh.boretube.learn.ui.DesignFrame
import com.rakesh.boretube.learn.ui.LocalUptime
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import kotlin.random.Random

@OptIn(ExperimentalTestApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1280dp-h800dp-xhdpi")
class PairsBuildTest {
    @get:Rule val rule = createComposeRule()
    private val now = 1_800_000_000_000L
    private val sounds = RecordingSounds()
    private var clock = 10_000L
    private var done: List<Answered>? = null
    private var sel = 0

    private fun key(k: Key) = rule.onRoot().performKeyInput { pressKey(k) }
    private fun settle(ms: Long = 400) { rule.waitForIdle(); clock += ms; rule.mainClock.advanceTimeBy(ms); rule.waitForIdle() }
    private fun ok() { settle(); key(Key.DirectionCenter); settle(50) }

    /** Moves the selection on the 4×3 board from [sel] to [to]. */
    private fun moveTo(to: Int) {
        val (r0, c0) = sel / 4 to sel % 4
        val (r1, c1) = to / 4 to to % 4
        repeat(maxOf(0, r1 - r0)) { key(Key.DirectionDown) }
        repeat(maxOf(0, r0 - r1)) { key(Key.DirectionUp) }
        repeat(maxOf(0, c1 - c0)) { key(Key.DirectionRight) }
        repeat(maxOf(0, c0 - c1)) { key(Key.DirectionLeft) }
        sel = to
    }

    private fun pairs() {
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) {
                DesignFrame { PairsLevel("tablesHigh", LearnState(grade = 4), sounds, Random(5), now, onDone = { done = it }, onLeave = {}) }
            }
        }
    }

    /** The screen picks the facts and deals from one random source; so does this. */
    private fun board(): List<PairCard> {
        val r = Random(5)
        return PairsBoard.deal(Levels.pairsFor(LearnState(grade = 4), "tablesHigh", now, r), r)
    }

    @Test fun matchingAllPairsFinishesAndAMismatchCountsAsLearned() {
        pairs()
        val b = board()
        assertEquals(12, b.size)
        // One mismatch on pair 0's question card and pair 1's answer card.
        val q0 = b.indexOfFirst { it.pair == 0 && !it.answer }
        val a1 = b.indexOfFirst { it.pair == 1 && it.answer }
        moveTo(q0); ok(); moveTo(a1); ok()
        assertTrue(Sfx.miss in sounds.played)
        settle(1_000) // they flip back
        for (p in 0 until 6) {
            moveTo(b.indexOfFirst { it.pair == p && !it.answer }); ok()
            moveTo(b.indexOfFirst { it.pair == p && it.answer }); ok()
            settle(300)
        }
        settle(1_500)
        val r = done!!
        assertEquals(6, r.size)
        assertFalse(r[0].correct)
        assertFalse(r[1].correct)
        assertTrue(r.drop(2).all { it.correct })
        assertTrue(Sfx.pair_match in sounds.played)
        assertTrue(Sfx.card_flip in sounds.played)
    }

    @Test fun pairsScreenshot() {
        pairs()
        val b = board()
        moveTo(b.indexOfFirst { it.pair == 0 && !it.answer }); ok()
        moveTo(b.indexOfFirst { it.pair == 0 && it.answer }); ok()
        settle(300)
        moveTo(b.indexOfFirst { it.pair == 2 && it.answer }); ok()
        rule.onRoot().captureRoboImage("src/test/screenshots/level_pairs.png")
    }

    private fun build() {
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) {
                DesignFrame { BuildLevel(LearnState(grade = 2), sounds, Speaker.Silent, LearnSettings(grade = 2, set = true), Random(6), now, onDone = { done = it }, onLeave = {}) }
            }
        }
    }

    @Test fun buildMakesFiveNumbersFromTensAndOnes() {
        build()
        val targets = Levels.buildTargets(LearnState(grade = 2), now, Random(6))
        for ((i, q) in targets.withIndex()) {
            val n = Levels.buildTarget(q)
            rule.onNodeWithText("Make $n").assertExists()
            // + Ten is selected first.
            repeat(n / 10) { ok() }
            key(Key.DirectionRight)
            repeat(n % 10) { ok() }
            rule.onNodeWithTag("so-far").assertExists()
            repeat(2) { key(Key.DirectionRight) } // Done
            if (i == 0 && n % 10 < 9) {
                // Make one too many first, then take it away.
                key(Key.DirectionLeft); key(Key.DirectionLeft); ok()
                key(Key.DirectionRight); ok()
                key(Key.DirectionRight)
            }
            ok()
            settle(1_200)
        }
        assertEquals(5, done?.size)
        assertTrue(done!!.all { it.correct })
        assertTrue(sounds.played.containsAll(listOf(Sfx.build_ten, Sfx.build_one, Sfx.build_undo, Sfx.build_hit)))
    }

    @Test fun aWrongBuildTeachesIt() {
        build()
        val n = Levels.buildTarget(Levels.buildTargets(LearnState(grade = 2), now, Random(6)).first())
        repeat(3) { key(Key.DirectionRight) }
        ok() // Done with nothing made
        rule.onNodeWithTag("learn-moment").assertExists()
        rule.onNodeWithText("You made 0", substring = true).assertExists()
        rule.onNodeWithText("$n is ", substring = true).assertExists()
    }

    @Test fun buildScreenshot() {
        build()
        repeat(4) { ok() }
        key(Key.DirectionRight)
        repeat(5) { ok() }
        rule.onRoot().captureRoboImage("src/test/screenshots/level_build.png")
    }
}
