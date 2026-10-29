package com.rakesh.boretube.learn.ui

import android.content.Context
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.pressKey
import androidx.test.core.app.ApplicationProvider
import com.github.takahirom.roborazzi.captureRoboImage
import com.rakesh.boretube.learn.core.Fact
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.data.Player
import com.rakesh.boretube.learn.data.PlayersStore
import com.rakesh.boretube.learn.data.ProgressStore
import com.rakesh.boretube.learn.data.SettingsStore
import com.rakesh.boretube.learn.sound.RecordingSounds
import com.rakesh.boretube.learn.speech.Speaker
import com.rakesh.boretube.learn.world.Discover
import com.rakesh.boretube.learn.world.Discovery
import com.rakesh.boretube.learn.world.World
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDate
import kotlin.random.Random

/** Several children on one TV, switching class, and "Today in Tubby's Town" (spec P2b §8). */
@OptIn(ExperimentalTestApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1280dp-h800dp-xhdpi")
class PlayersFlowTest {
    @get:Rule val rule = createComposeRule()
    @get:Rule val tmp = TemporaryFolder()
    private var clock = 10_000L
    private val today = LocalDate.parse("2026-10-30")
    private val ctx = ApplicationProvider.getApplicationContext<Context>()
    private val prefs = ctx.getSharedPreferences("learn-test", Context.MODE_PRIVATE).also { it.edit().clear().commit() }

    private fun key(k: Key) = rule.onRoot().performKeyInput { pressKey(k) }
    private fun settle(ms: Long = 400) { rule.waitForIdle(); clock += ms; rule.mainClock.advanceTimeBy(ms); rule.waitForIdle() }
    private fun ok() { settle(); key(Key.DirectionCenter); settle(50) }

    private fun start(players: PlayersStore, world: World = World.MATHS) {
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) {
                DesignFrame {
                    LearnApp(
                        ProgressStore(tmp.root), SettingsStore(prefs), RecordingSounds(), Speaker.Silent, Random(7),
                        today = { today }, hour = { 10 }, world = world, players = players, onExit = {},
                    )
                }
            }
        }
    }

    @Test fun theOneChildFromBeforeBecomesTheFirstPlayerAndKeepsTheirProgress() {
        SettingsStore(prefs).put(LearnSettings(grade = 4, lang = "en", set = true))
        ProgressStore(tmp.root).save(LearnState(grade = 4, stars = mapOf("add10" to 3)))
        val players = PlayersStore(prefs, tmp.root)
        val p1 = players.all().single()
        assertEquals(Player("p1", "lion", 4, "en"), p1)
        assertEquals(3, players.progress("p1").load().stars["add10"])
        assertEquals(LearnState(), players.progress("p2").load())
    }

    @Test fun aSecondChildJoinsWithTheirOwnClassAndStars() {
        SettingsStore(prefs).put(LearnSettings(grade = 4, set = true))
        ProgressStore(tmp.root).save(LearnState(grade = 4, stars = mapOf("add10" to 3)))
        val players = PlayersStore(prefs, tmp.root)
        start(players)
        rule.onNodeWithText("Class 4").assertExists()
        key(Key.DirectionUp)
        settle()
        rule.onRoot().captureRoboImage("src/test/screenshots/town_players.png")
        ok() // Who's playing
        rule.onNodeWithTag("who-screen").assertExists()
        key(Key.DirectionRight) // New player
        ok()
        rule.onNodeWithTag("avatar-screen").assertExists()
        rule.onRoot().captureRoboImage("src/test/screenshots/avatar.png")
        ok() // the first free animal
        ok() // KG
        ok() // English
        val second = players.all()
        assertEquals(2, second.size)
        assertEquals(0, second[1].grade)
        assertEquals("p2", players.activeId())
        rule.onNodeWithText("KG").assertExists()
        // Back to the first child: their class and stars are still theirs.
        key(Key.DirectionUp)
        ok()
        rule.onRoot().captureRoboImage("src/test/screenshots/who.png")
        key(Key.DirectionLeft) // the cursor starts on the child playing now (p2)
        ok()
        assertEquals("p1", players.activeId())
        rule.onNodeWithText("Class 4").assertExists()
        rule.onNodeWithText("3 stars").assertExists()
    }

    @Test fun changingClassIsTwoPressesAway() {
        SettingsStore(prefs).put(LearnSettings(grade = 2, set = true))
        val players = PlayersStore(prefs, tmp.root)
        start(players)
        key(Key.DirectionUp)
        key(Key.DirectionRight)
        ok()
        rule.onNodeWithTag("class-screen").assertExists()
        rule.onRoot().captureRoboImage("src/test/screenshots/class_change.png")
        key(Key.DirectionRight)
        ok()
        assertEquals(3, players.active()!!.grade)
        rule.onNodeWithText("Class 3").assertExists()
    }

    @Test fun todaysCardsLeadWithPracticeAndRotateByDay() {
        val world = World.MATHS
        val s = LearnState(grade = 3, facts = listOf(Fact("tablesHigh:7:8", 1, 0)))
        val cards = Discover.today(s, world, 3, today)
        assertEquals(3, cards.size)
        assertEquals(Discovery.Kind.practise, cards.first().kind)
        assertEquals("tablesHigh", cards.first().skill)
        // A fresh child is pointed at a Streak run or something new.
        val fresh = Discover.today(LearnState(grade = 3), world, 3, today)
        assertTrue(fresh.any { it.kind == Discovery.Kind.run || it.kind == Discovery.Kind.newSkill || it.kind == Discovery.Kind.visit })
        // Same day, same cards; the days differ.
        assertEquals(fresh, Discover.today(LearnState(grade = 3), world, 3, today))
        val week = (0L..6L).map { Discover.today(LearnState(grade = 3), world, 3, today.plusDays(it)) }.toSet()
        assertTrue(week.size > 1)
    }
}

/** Settings live on the TV: language, sounds, removing a player. */
@OptIn(ExperimentalTestApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1280dp-h800dp-xhdpi")
class SettingsOnTvTest {
    @get:Rule val rule = createComposeRule()
    @get:Rule val tmp = TemporaryFolder()
    private var clock = 10_000L
    private val ctx = ApplicationProvider.getApplicationContext<Context>()
    private val prefs = ctx.getSharedPreferences("learn-test2", Context.MODE_PRIVATE).also { it.edit().clear().commit() }

    private fun key(k: Key) = rule.onRoot().performKeyInput { pressKey(k) }
    private fun settle(ms: Long = 400) { rule.waitForIdle(); clock += ms; rule.mainClock.advanceTimeBy(ms); rule.waitForIdle() }
    private fun ok() { settle(); key(Key.DirectionCenter); settle(50) }

    @Test fun languageSoundsAndRemovingAPlayerAllHappenOnTheTv() {
        SettingsStore(prefs).put(LearnSettings(grade = 3, set = true))
        val players = PlayersStore(prefs, tmp.root)
        players.all()
        players.put(Player("p2", "panda", 1))
        players.progress("p2").save(LearnState(grade = 1, stars = mapOf("add10" to 2)))
        players.setActive("p2")
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) {
                DesignFrame {
                    LearnApp(ProgressStore(tmp.root), SettingsStore(prefs), RecordingSounds(), Speaker.Silent, Random(7),
                        today = { LocalDate.parse("2026-10-30") }, hour = { 10 }, players = players, onExit = {})
                }
            }
        }
        key(Key.DirectionUp)
        key(Key.DirectionRight)
        key(Key.DirectionRight)
        ok()
        rule.onNodeWithTag("settings-screen").assertExists()
        key(Key.DirectionRight) // language → हिन्दी
        settle()
        assertEquals("hi", players.active()!!.lang)
        key(Key.DirectionDown)
        ok() // sounds off
        assertEquals(false, SettingsStore(prefs).get().sounds)
        key(Key.DirectionDown)
        ok()
        rule.onNodeWithText("Press OK again to remove").assertExists()
        rule.onRoot().captureRoboImage("src/test/screenshots/settings.png")
        ok()
        assertEquals(listOf("p1"), players.all().map { it.id })
        assertTrue(!java.io.File(tmp.root, "progress-p2.json").exists())
        rule.onNodeWithText("Class 3").assertExists()
    }
}
