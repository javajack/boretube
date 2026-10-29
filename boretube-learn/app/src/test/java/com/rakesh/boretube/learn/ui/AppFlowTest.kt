package com.rakesh.boretube.learn.ui

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
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Learner
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.data.ProgressRepo
import com.rakesh.boretube.learn.data.SettingsRepo
import com.rakesh.boretube.learn.sound.RecordingSounds
import com.rakesh.boretube.learn.speech.Speaker
import com.rakesh.boretube.learn.ui.level.LevelPlan
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDate
import kotlin.random.Random

@OptIn(ExperimentalTestApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1280dp-h800dp-xhdpi")
class AppFlowTest {
    @get:Rule val rule = createComposeRule()
    private var clock = 10_000L
    private val now = 1_800_000_000_000L
    private val today = LocalDate.parse("2026-10-29")

    private class MemProgress(var s: LearnState = LearnState()) : ProgressRepo {
        var saves = 0
        override fun load() = s
        override fun save(s: LearnState) { this.s = s; saves++ }
    }

    private class MemSettings(var s: LearnSettings = LearnSettings()) : SettingsRepo {
        override fun get() = s
        override fun put(s: LearnSettings) { this.s = s }
    }

    private val progress = MemProgress()
    private val settings = MemSettings()
    private var exited = false

    private fun start() {
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) {
                DesignFrame {
                    LearnApp(progress, settings, RecordingSounds(), Speaker.Silent, Random(7), now = { now }, today = { today }, hour = { 18 }, onExit = { exited = true })
                }
            }
        }
    }

    private fun key(k: Key) = rule.onRoot().performKeyInput { pressKey(k) }
    private fun settle(ms: Long = 400) { rule.waitForIdle(); clock += ms; rule.mainClock.advanceTimeBy(ms); rule.waitForIdle() }
    private fun ok() { settle(); key(Key.DirectionCenter); settle(50) }

    @Test fun firstRunThenTownThenALevelThenDoneThenTown() {
        start()
        rule.onNodeWithText("Which class are you in?").assertExists()
        rule.onRoot().captureRoboImage("src/test/screenshots/first_run.png")
        repeat(3) { key(Key.DirectionRight) } // KG → Class 3
        ok()
        rule.onNodeWithText("Which language?").assertExists()
        ok() // English
        assertEquals(LearnSettings(grade = 3, lang = "en", set = true), settings.s)
        rule.onNodeWithText("Tubby's Town").assertExists()
        ok() // Number Bazaar
        rule.onNodeWithText("Number Bazaar").assertExists()
        ok() // the current level
        val state = Learner.forGrade(LearnState(), 3)
        val plan = LevelPlan.build(state, "tablesLow", now, Random(7))
        for (q in plan) {
            repeat(q.answer) { key(Key.DirectionRight) }
            ok()
            settle(1_200)
        }
        rule.onNodeWithText("Level done!").assertExists()
        assertEquals(3, progress.s.stars["tablesLow"])
        assertTrue(progress.saves >= 1)
        key(Key.DirectionRight)
        ok() // Back to town
        rule.onNodeWithText("Tubby's Town").assertExists()
        settle()
        key(Key.Back)
        assertTrue(exited)
    }

    @Test fun aReturningChildSkipsFirstRun() {
        settings.s = LearnSettings(grade = 2, set = true)
        start()
        rule.onNodeWithText("Tubby's Town").assertExists()
        rule.onNodeWithTag("land-bazaar").assertExists()
    }
}
