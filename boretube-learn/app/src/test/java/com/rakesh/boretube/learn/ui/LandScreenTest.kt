package com.rakesh.boretube.learn.ui

import androidx.compose.ui.input.key.Key
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.assert
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.pressKey
import com.github.takahirom.roborazzi.captureRoboImage
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Maths
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.RecordingSounds
import com.rakesh.boretube.learn.world.LandId
import com.rakesh.boretube.learn.world.Lands
import org.junit.Assert.assertEquals
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
class LandScreenTest {
    @get:Rule val rule = createComposeRule()
    private val land = Lands.of(LandId.bazaar)
    private val state = LearnState(grade = 4, rung = Maths.indexOf("tablesHigh"), stars = mapOf("tablesLow" to 3, "money" to 2, "clock" to 3), mastered = listOf("tablesLow", "money", "clock"))

    @Test fun theCurrentRungIsSelectedAndArrowsWalkThePath() {
        var played: String? = null
        var back = false
        rule.setContent { DesignFrame { LandScreen(land, state, LearnSettings(grade = 4, set = true), RecordingSounds(), onPlay = { played = it }, onBack = { back = true }) } }
        rule.onNodeWithTag("node-tablesHigh").assert(SemanticsMatcher.expectValue(FocusedKey, true))
        rule.onRoot().performKeyInput { pressKey(Key.DirectionRight) }
        rule.onNodeWithTag("node-divide").assert(SemanticsMatcher.expectValue(FocusedKey, true))
        ShadowSystemClock.advanceBy(Duration.ofMillis(400))
        rule.onRoot().performKeyInput { pressKey(Key.DirectionCenter) }
        assertEquals("divide", played)
        rule.onRoot().performKeyInput { pressKey(Key.Back) }
        assertTrue(back)
    }

    @Test fun leftStopsAtTheStart() {
        rule.setContent { DesignFrame { LandScreen(land, LearnState(grade = 4, rung = Maths.firstRung(3)), LearnSettings(grade = 4, set = true), RecordingSounds(), onPlay = {}, onBack = {}) } }
        val first = Lands.path(land, 4).first()
        rule.onNodeWithTag("node-$first").assert(SemanticsMatcher.expectValue(FocusedKey, true))
        rule.onRoot().performKeyInput { pressKey(Key.DirectionLeft) }
        rule.onNodeWithTag("node-$first").assert(SemanticsMatcher.expectValue(FocusedKey, true))
    }

    @Test fun screenshot() {
        rule.setContent { DesignFrame { LandScreen(land, state, LearnSettings(grade = 4, set = true), RecordingSounds(), onPlay = {}, onBack = {}) } }
        rule.onRoot().captureRoboImage("src/test/screenshots/land.png")
    }
}
