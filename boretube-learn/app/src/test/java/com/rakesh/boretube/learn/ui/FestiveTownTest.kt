package com.rakesh.boretube.learn.ui

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Seasons
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.RecordingSounds
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDate

/** The town dressed for each kind of festival (spec P2b §8). */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1280dp-h800dp-xhdpi")
class FestiveTownTest {
    @get:Rule val rule = createComposeRule()

    private fun town(day: String, shot: String) {
        val theme = Seasons.of(LocalDate.parse(day))!!
        rule.setContent {
            DesignFrame {
                TownScreen(LearnState(grade = 3), LearnSettings(grade = 3, set = true), RecordingSounds(), hour = 18,
                    festive = theme, hello = "Good evening! ${theme.line}") {}
            }
        }
        rule.mainClock.advanceTimeBy(3_000)
        rule.onRoot().captureRoboImage("src/test/screenshots/festive_$shot.png")
    }

    @Test fun diwali() { town("2026-11-08", "diwali"); rule.onNodeWithTag("festive-frame").assertExists() }
    @Test fun holi() { town("2027-03-22", "holi"); rule.onNodeWithTag("festive-backdrop").assertExists() }
    @Test fun sankranti() = town("2028-01-15", "sankranti")
    @Test fun eid() = town("2027-03-10", "eid")
    @Test fun independence() = town("2027-08-15", "independence")
    @Test fun navratri() = town("2027-10-03", "navratri")
    @Test fun christmas() = town("2026-12-25", "christmas")
    @Test fun childrensDay() = town("2026-11-14", "children")
}
