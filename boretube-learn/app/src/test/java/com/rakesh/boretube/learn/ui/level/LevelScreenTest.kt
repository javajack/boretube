package com.rakesh.boretube.learn.ui.level

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
import com.rakesh.boretube.learn.core.Question
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.RecordingSounds
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.speech.Speaker
import androidx.compose.runtime.CompositionLocalProvider
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
class LevelScreenTest {
    @get:Rule val rule = createComposeRule()
    private val now = 1_800_000_000_000L
    private val sounds = RecordingSounds()
    private var done: List<Answered>? = null
    private var left = false
    private var clock = 10_000L

    private fun start(skill: String, grade: Int = 3) {
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) { DesignFrame {
                LevelScreen(skill, LearnState(grade = grade), LearnSettings(grade = grade, set = true), sounds, Speaker.Silent, Random(3), now,
                    onDone = { done = it }, onLeave = { left = true })
            } }
        }
    }

    private fun expected(skill: String, grade: Int = 3): List<Question> = LevelPlan.build(LearnState(grade = grade), skill, now, Random(3))

    private fun key(k: Key) = rule.onRoot().performKeyInput { pressKey(k) }

    /** Waits out the OK grace (system clock) and any screen timers (compose clock). */
    private fun settle(ms: Long = 400) {
        rule.waitForIdle() // let effects of the last key start before time moves
        clock += ms
        rule.mainClock.advanceTimeBy(ms)
        rule.waitForIdle()
    }

    private fun pick(index: Int) {
        repeat(index) { key(Key.DirectionRight) }
        settle()
        key(Key.DirectionCenter)
    }

    @Test fun okRightAfterAScreenChangeIsIgnored() {
        start("clock")
        key(Key.DirectionCenter)
        rule.onNodeWithText("1 of 8").assertExists()
        rule.onNodeWithTag("ask").assertExists()
    }

    @Test fun aMissShowsTheLearnMomentThenAnEasierOne() {
        start("clock")
        val q = expected("clock").first()
        pick((q.answer + 1) % q.options.size)
        rule.onNodeWithTag("learn-moment").assertExists()
        rule.onNodeWithText(q.explain).assertExists()
        assertTrue(Sfx.miss in sounds.played)
        settle()
        key(Key.DirectionCenter)
        rule.onNodeWithText("Now try this one").assertExists()
    }

    @Test fun eightRightAnswersFinishTheLevel() {
        start("clock")
        val plan = expected("clock")
        for ((i, q) in plan.withIndex()) {
            rule.onNodeWithText("${i + 1} of 8").assertExists()
            pick(q.answer)
            settle(1_200)
        }
        assertEquals(8, done?.size)
        assertTrue(done!!.all { it.correct && !it.followUp })
        assertTrue(Sfx.right_5 in sounds.played)
    }

    @Test fun backAsksBeforeLeaving() {
        start("clock")
        key(Key.Back)
        rule.onNodeWithText("Leave this level?").assertExists()
        settle()
        key(Key.DirectionCenter) // Stay is the default
        rule.onNodeWithText("Leave this level?").assertDoesNotExist()
        assertFalse(left)
        key(Key.Back)
        key(Key.DirectionRight)
        settle()
        key(Key.DirectionCenter)
        assertTrue(left)
    }

    @Test fun catchHasThreeLanesAndTheBasketMoves() {
        start("tablesLow")
        val q = expected("tablesLow").first()
        assertEquals(3, q.options.size)
        rule.onNodeWithTag("lane-2").assertExists()
        rule.onNodeWithTag("basket-0").assertExists()
        key(Key.DirectionRight)
        rule.onNodeWithTag("basket-1").assertExists()
        assertTrue(Sfx.catch_move in sounds.played)
        key(Key.DirectionLeft)
        pick(q.answer)
        assertTrue(Sfx.catch_right in sounds.played)
    }

    @Test fun aBrokenSpeakerNeverStopsTheLevel() {
        val broken = object : Speaker {
            override fun say(text: String, hindi: Boolean) = throw IllegalStateException("no TTS engine")
            override fun stop() {}
        }
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) { DesignFrame {
                LevelScreen("count10", LearnState(grade = 0), LearnSettings(grade = 0, lang = "hi", set = true), sounds, broken, Random(3), now,
                    onDone = { done = it }, onLeave = { left = true })
            } }
        }
        val q = LevelPlan.build(LearnState(grade = 0), "count10", now, Random(3)).first()
        key(Key.DirectionUp)
        pick(q.answer)
        rule.onNodeWithTag("right").assertExists()
    }

    @Test fun screenshots() {
        start("tablesLow")
        rule.onRoot().captureRoboImage("src/test/screenshots/level_catch.png")
    }

    @Test fun screenshotQuickfireAndLearn() {
        start("clock")
        rule.onRoot().captureRoboImage("src/test/screenshots/level_quickfire.png")
        val q = expected("clock").first()
        pick((q.answer + 1) % q.options.size)
        rule.onRoot().captureRoboImage("src/test/screenshots/level_learn.png")
    }
}
