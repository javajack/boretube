package com.rakesh.boretube.learn.ui

import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.pressKey
import androidx.compose.ui.input.key.Key
import com.github.takahirom.roborazzi.captureRoboImage
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.RecordingSounds
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.world.LandId
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowSystemClock
import java.time.Duration

@OptIn(ExperimentalTestApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1280dp-h800dp-xhdpi")
class TownScreenTest {
    @get:Rule val rule = createComposeRule()
    private val settings = LearnSettings(grade = 4, set = true)

    private fun ok() {
        ShadowSystemClock.advanceBy(Duration.ofMillis(400))
        rule.onRoot().performKeyInput { pressKey(Key.DirectionCenter) }
    }

    @Test fun bazaarIsSelectedAndOpens() {
        var opened: LandId? = null
        val sounds = RecordingSounds()
        rule.setContent { DesignFrame { TownScreen(LearnState(grade = 4), settings, sounds, hour = 18) { opened = it } } }
        rule.onNodeWithTag("land-bazaar").assert(SemanticsMatcher.expectValue(FocusedKey, true))
        ok()
        assertEquals(LandId.bazaar, opened)
        assertTrue(Sfx.select in sounds.played)
    }

    @Test fun gardenIsComingSoonInP1() {
        var opened: LandId? = null
        val sounds = RecordingSounds()
        rule.setContent { DesignFrame { TownScreen(LearnState(), settings, sounds, hour = 10) { opened = it } } }
        rule.onRoot().performKeyInput { pressKey(Key.DirectionRight) }
        rule.onNodeWithTag("land-garden").assert(SemanticsMatcher.expectValue(FocusedKey, true))
        assertTrue(Sfx.focus_garden in sounds.played)
        ok()
        assertNull(opened)
        rule.onNodeWithText("Tubby is still building this land.").assertExists()
    }

    @Test fun greetingFollowsTheClock() {
        rule.setContent { DesignFrame { TownScreen(LearnState(), settings, RecordingSounds(), hour = 9) {} } }
        rule.onNodeWithText("Good morning! Where shall we go?").assertExists()
    }

    @Test fun screenshot() {
        rule.setContent {
            DesignFrame {
                TownScreen(LearnState(grade = 4, rung = 11, stars = mapOf("tablesLow" to 3, "money" to 2), mastered = listOf("tablesLow", "money")), settings, RecordingSounds(), hour = 18) {}
            }
        }
        rule.onRoot().captureRoboImage("src/test/screenshots/town.png")
    }
}
