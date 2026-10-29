package com.rakesh.boretube.learn.ui

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.assertCountEquals
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.pressKey
import com.github.takahirom.roborazzi.captureRoboImage
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.LevelResult
import com.rakesh.boretube.learn.core.Maths
import com.rakesh.boretube.learn.sound.RecordingSounds
import com.rakesh.boretube.learn.sound.Sfx
import org.junit.Assert.assertEquals
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
class DoneScreenTest {
    @get:Rule val rule = createComposeRule()
    private val sounds = RecordingSounds()
    private var clock = 10_000L
    private var picked = ""
    private val practise = Maths.fromKey("tablesHigh:7:8", Random(1))!!

    private fun start(r: LevelResult) {
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) {
                DesignFrame { DoneScreen(r, "Tables of 6, 7, 8 and 9", sounds, onAnother = { picked = "another" }, onTown = { picked = "town" }) }
            }
        }
    }

    private fun settle(ms: Long) { rule.waitForIdle(); clock += ms; rule.mainClock.advanceTimeBy(ms); rule.waitForIdle() }

    @Test fun starsCountInWithASoundEach() {
        start(LevelResult(LearnState(), 2, 3, false, practise, right = 6, total = 8))
        settle(2_000)
        rule.onAllNodesWithTag("star-full").assertCountEquals(2)
        rule.onAllNodesWithTag("star-empty").assertCountEquals(1)
        assertTrue(sounds.played.containsAll(listOf(Sfx.star_1, Sfx.star_2, Sfx.level_done_bazaar)))
        assertTrue(Sfx.star_3 !in sounds.played)
        rule.onNodeWithText("6 of 8 right · Tables of 6, 7, 8 and 9").assertExists()
    }

    @Test fun aStickerOnlyWhenTheSkillIsNewlyMastered() {
        start(LevelResult(LearnState(), 3, 3, true, null, right = 8, total = 8))
        rule.onNodeWithTag("sticker").assertExists()
        rule.onNodeWithText("One to practise", substring = true).assertDoesNotExist()
    }

    @Test fun thePractiseLineNamesTheMissedFact() {
        start(LevelResult(LearnState(), 2, 2, false, practise, right = 6, total = 8))
        rule.onNodeWithTag("sticker").assertDoesNotExist()
        rule.onNodeWithText("One to practise: 7 × 8 = 56", substring = true).assertExists()
    }

    @Test fun playAnotherIsTheDefaultAndBackToTownIsBeside() {
        start(LevelResult(LearnState(), 3, 3, false, null, right = 8, total = 8))
        rule.onNodeWithTag("done-another").assert(SemanticsMatcher.expectValue(FocusedKey, true))
        settle(400)
        rule.onRoot().performKeyInput { pressKey(Key.DirectionCenter) }
        assertEquals("another", picked)
        rule.onRoot().performKeyInput { pressKey(Key.DirectionRight) }
        rule.onNodeWithTag("done-town").assert(SemanticsMatcher.expectValue(FocusedKey, true))
        settle(400)
        rule.onRoot().performKeyInput { pressKey(Key.DirectionCenter) }
        assertEquals("town", picked)
    }

    @Test fun screenshot() {
        start(LevelResult(LearnState(), 2, 3, true, practise, right = 6, total = 8))
        settle(2_000)
        rule.onRoot().captureRoboImage("src/test/screenshots/done.png")
    }
}
