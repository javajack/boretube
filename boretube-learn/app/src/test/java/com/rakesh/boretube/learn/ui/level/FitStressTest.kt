package com.rakesh.boretube.learn.ui.level

import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onRoot
import com.github.takahirom.roborazzi.captureRoboImage
import com.rakesh.boretube.learn.core.Question
import com.rakesh.boretube.learn.ui.DesignFrame
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/** Long answers fit their tiles, balls, cards and baskets (no mid-word breaks, nothing touching a curve). */
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1280dp-h800dp-xhdpi")
class FitStressTest {
    @get:Rule val rule = createComposeRule()

    private fun q(prompt: String, options: List<String>, order: List<String>? = null) = Question(
        key = "x:1", skill = "x", prompt = prompt, promptHi = null, spoken = prompt, spokenHi = null,
        options = options, answer = 0, fact = options[0], explain = "Because.", order = order,
    )

    @Test fun quickFireTiles() {
        rule.setContent { DesignFrame { QuickFireBody(q("Which separation method removes husk from grain using wind?", listOf("dal, rice and sabzi", "photosynthesis", "condensation", "Neither")), 0, 8, false, 1, null, voice = true) } }
        rule.onRoot().captureRoboImage("src/test/screenshots/fit_quickfire.png")
    }

    @Test fun quickFireRight() {
        rule.setContent { DesignFrame { QuickFireBody(q("Pick one", listOf("chrysanthemum", "Riya's, the boys'", "electricity", "magnetic")), 0, 8, false, 0, 0, voice = true) } }
        rule.onRoot().captureRoboImage("src/test/screenshots/fit_quickfire_right.png")
    }

    @Test fun catchBalls() {
        rule.setContent { DesignFrame { CatchBody(q("Catch the noun", listOf("sunflower", "cockroach", "a thali")), 0, 8, false, 1, null) } }
        rule.mainClock.advanceTimeBy(4_000)
        rule.onRoot().captureRoboImage("src/test/screenshots/fit_catch.png")
    }

    @Test fun sortCard() {
        rule.setContent { DesignFrame { SortBody(q("Grasshopper on a leaf", listOf("Non-renewable", "Renewable")), 0, 8, false, null, 2 to 1) } }
        rule.mainClock.advanceTimeBy(2_000)
        rule.onRoot().captureRoboImage("src/test/screenshots/fit_sort.png")
    }

    @Test fun orderTiles() {
        val o = listOf("new moon", "waxing crescent", "first quarter", "waxing gibbous", "full moon")
        rule.setContent { DesignFrame { OrderBody(q("Put the moon's phases in order", o.shuffled(kotlin.random.Random(2)), o), 0, 4, false, listOf(1), 0, right = false, wrongShake = null) } }
        rule.onRoot().captureRoboImage("src/test/screenshots/fit_order.png")
    }
}
