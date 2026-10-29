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
import com.rakesh.boretube.learn.core.Answered
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Pack
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.RecordingSounds
import com.rakesh.boretube.learn.speech.Speaker
import com.rakesh.boretube.learn.ui.level.LevelPlan
import com.rakesh.boretube.learn.ui.level.LevelScreen
import com.rakesh.boretube.learn.world.LandId
import com.rakesh.boretube.learn.world.World
import kotlinx.serialization.json.Json
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File
import kotlin.random.Random

@OptIn(ExperimentalTestApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1280dp-h800dp-xhdpi")
class GardenTrailTest {
    @get:Rule val rule = createComposeRule()
    private val json = Json { ignoreUnknownKeys = true }
    private val packs: List<Pack> = File("src/main/assets/content").walk().filter { it.extension == "json" && it.parentFile.name != "data" }
        .map { json.decodeFromString(Pack.serializer(), it.readText()) }.toList()
    private val world = World.of(packs)
    private val now = 1_800_000_000_000L
    private var clock = 10_000L

    private fun key(k: Key) = rule.onRoot().performKeyInput { pressKey(k) }
    private fun settle(ms: Long = 400) { rule.waitForIdle(); clock += ms; rule.mainClock.advanceTimeBy(ms); rule.waitForIdle() }

    @Test fun theWorldHasThreeLandsWithClassWindows() {
        assertTrue(world.of(LandId.garden).skills.size == 16)
        assertTrue(world.of(LandId.trail).skills.size == 16)
        assertEquals(listOf("en2.opposite", "en2.plural", "en3.article", "en3.action", "en4.past", "en4.describe"), world.path(world.of(LandId.garden), 3))
        assertEquals("en0.letters", world.progress(LearnState(), world.of(LandId.garden), 0).next)
        assertEquals(world.of(LandId.trail), world.landOf("sc7.heat"))
    }

    @Test fun theGardenOpensFromTownAndShowsItsPath() {
        var opened: LandId? = null
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) {
                DesignFrame { TownScreen(LearnState(), LearnSettings(grade = 1, set = true), RecordingSounds(), 10, world) { opened = it } }
            }
        }
        rule.onNodeWithText("English · 0 of 6 skills").assertExists()
        key(Key.DirectionRight)
        settle()
        key(Key.DirectionCenter)
        assertEquals(LandId.garden, opened)
        rule.onRoot().captureRoboImage("src/test/screenshots/town_full.png")
    }

    @Test fun trailPathScreenshot() {
        rule.setContent {
            DesignFrame { LandScreen(world.of(LandId.trail), LearnState(), LearnSettings(grade = 4, set = true), RecordingSounds(), world, onPlay = {}, onBack = {}) }
        }
        rule.onNodeWithTag("node-ev4.travel").assertExists()
        rule.onRoot().captureRoboImage("src/test/screenshots/land_trail.png")
    }

    @Test fun aKgPictureQuestionAndAnEnglishLevelToTheEnd() {
        var done: List<Answered>? = null
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) {
                DesignFrame {
                    LevelScreen("ev0.body", LearnState(grade = 0), LearnSettings(grade = 0, set = true), RecordingSounds(), Speaker.Silent, Random(4), now, world.catalog,
                        onDone = { done = it }, onLeave = {})
                }
            }
        }
        rule.onRoot().captureRoboImage("src/test/screenshots/level_kg_pictures.png")
        val plan = LevelPlan.build(LearnState(grade = 0), "ev0.body", now, Random(4), world.catalog)
        for (q in plan) {
            repeat(q.answer) { key(Key.DirectionRight) }
            settle()
            key(Key.DirectionCenter)
            settle(1_200)
        }
        assertEquals(8, done?.size)
        assertTrue(done!!.all { it.correct })
    }
}
