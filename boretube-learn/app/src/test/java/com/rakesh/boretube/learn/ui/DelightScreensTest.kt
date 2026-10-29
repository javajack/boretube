package com.rakesh.boretube.learn.ui

import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.test.ExperimentalTestApi
import androidx.compose.ui.test.junit4.createComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performKeyInput
import androidx.compose.ui.test.pressKey
import com.github.takahirom.roborazzi.captureRoboImage
import com.rakesh.boretube.learn.core.Chest
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.LevelResult
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.RecordingSounds
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.speech.Speaker
import com.rakesh.boretube.learn.ui.level.LevelPlan
import com.rakesh.boretube.learn.ui.level.LevelScreen
import com.rakesh.boretube.learn.world.World
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.time.LocalDate
import kotlin.random.Random

/** Tubby's lines, "Did you know?", rank-ups, the treasure chest and the sticker book. */
@OptIn(ExperimentalTestApi::class)
@RunWith(RobolectricTestRunner::class)
@Config(qualifiers = "w1280dp-h800dp-xhdpi")
class DelightScreensTest {
    @get:Rule val rule = createComposeRule()
    private val sounds = RecordingSounds()
    private var clock = 10_000L
    private val now = 1_800_000_000_000L

    private fun key(k: Key) = rule.onRoot().performKeyInput { pressKey(k) }
    private fun settle(ms: Long = 400) { rule.waitForIdle(); clock += ms; rule.mainClock.advanceTimeBy(ms); rule.waitForIdle() }

    @Test fun tubbyCheersEachRightAnswerAndTheThirdIsADidYouKnow() {
        val state = LearnState(grade = 3)
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) { DesignFrame {
                LevelScreen("clock", state, LearnSettings(grade = 3, set = true), sounds, Speaker.Silent, Random(3), now, onDone = {}, onLeave = {})
            } }
        }
        val plan = LevelPlan.build(state, "clock", now, Random(3))
        for ((i, q) in plan.take(3).withIndex()) {
            repeat(q.answer) { key(Key.DirectionRight) }
            settle()
            key(Key.DirectionCenter)
            rule.waitForIdle()
            rule.onNodeWithTag(if (i == 2) "did-you-know" else "cheer").assertExists()
            if (i == 2) {
                rule.onRoot().captureRoboImage("src/test/screenshots/did_you_know.png")
                // It waits for OK rather than racing away.
                settle(1_200)
                rule.onNodeWithTag("did-you-know").assertExists()
                key(Key.DirectionCenter)
            }
            settle(1_200)
        }
        rule.onNodeWithText("4 of 8").assertExists()
    }

    @Test fun aFactMissedBeforeEarnsAComeback() {
        val first = LevelPlan.build(LearnState(grade = 3), "clock", now, Random(3)).first()
        val state = LearnState(grade = 3, facts = listOf(com.rakesh.boretube.learn.core.Fact(first.key, 1, now - 1)))
        val plan = LevelPlan.build(state, "clock", now, Random(3))
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) { DesignFrame {
                LevelScreen("clock", state, LearnSettings(grade = 3, set = true), sounds, Speaker.Silent, Random(3), now, onDone = {}, onLeave = {})
            } }
        }
        val q = plan.first()
        repeat(q.answer) { key(Key.DirectionRight) }
        settle()
        key(Key.DirectionCenter)
        rule.waitForIdle()
        // The due fact leads the level.
        assertTrue(q.key == first.key)
        rule.onNodeWithText("You got it this time!").assertExists()
        assertTrue(Sfx.followup_win in sounds.played)
    }

    @Test fun doneShowsTheSkillStickerTheRankUpAndTheOpenedChest() {
        val day = LocalDate.parse("2026-11-04")
        val st = LearnState(playDays = listOf("2026-11-02", "2026-11-03", "2026-11-04"), chestWeeks = listOf("2026-W45"), treasures = listOf("kite"))
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) { DesignFrame {
                DoneScreen(
                    LevelResult(st, 3, 3, true, null, right = 8, total = 8), "Magnets", sounds, onAnother = {}, onTown = {},
                    sticker = "magnet", rankUp = "Magnets: you're now a Ranger!", chest = Chest.status(st, day), chestOpenedNow = true,
                )
            } }
        }
        settle(3_000)
        rule.onNodeWithText("Magnet").assertExists()
        rule.onNodeWithTag("rank-up").assertExists()
        rule.onNodeWithTag("chest-open").assertExists()
        rule.onRoot().captureRoboImage("src/test/screenshots/done_chest_rank.png")
    }

    @Test fun theStickerBookShowsMasteredSkillsAndTreasures() {
        val world = World.MATHS
        val skill = world.lands.flatMap { it.skills }.first()
        val st = LearnState(mastered = listOf(skill), treasures = listOf("kite"), chestWeeks = listOf("2026-W45"), playDays = listOf("2026-11-02"))
        var back = false
        rule.setContent {
            CompositionLocalProvider(LocalUptime provides { clock }) { DesignFrame {
                StickerBookScreen(st, world, LocalDate.parse("2026-11-03"), sounds, onBack = { back = true })
            } }
        }
        rule.onAllNodesWithTag("sticker-0").fetchSemanticsNodes().let { assertTrue(it.size == 1) }
        rule.onNodeWithTag("sticker-1").assertExists()
        rule.onNodeWithText(world.title(skill)).assertExists()
        key(Key.DirectionRight)
        rule.onNodeWithText("Treasure: Kite").assertExists()
        rule.onRoot().captureRoboImage("src/test/screenshots/sticker_book.png")
        key(Key.Back)
        assertTrue(back)
    }
}

/** A mastered skill's sticker is about what was learned. */
class StickerForTest {
    @org.junit.Test fun stickersFollowTheSkill() {
        val c = com.rakesh.boretube.learn.core.Catalog(listOf(
            com.rakesh.boretube.learn.core.GenSkill("sc6.magnets", 6, "evs", "Magnets", "Mag", listOf(com.rakesh.boretube.learn.core.Template("t", 1, intArrayOf(1)) { _, r -> com.rakesh.boretube.learn.core.gq("Q", com.rakesh.boretube.learn.core.Opt.of("a", listOf("b"), r)!!, "Because.") })),
            com.rakesh.boretube.learn.core.GenSkill("en2.pasted", 2, "english", "Past tense: -ed", "ed", listOf(com.rakesh.boretube.learn.core.Template("t", 1, intArrayOf(1)) { _, r -> com.rakesh.boretube.learn.core.gq("Q", com.rakesh.boretube.learn.core.Opt.of("a", listOf("b"), r)!!, "Because.") })),
        ))
        val w = com.rakesh.boretube.learn.world.World(c)
        org.junit.Assert.assertEquals("magnet", stickerFor("sc6.magnets", w))
        org.junit.Assert.assertTrue(stickerFor("en2.pasted", w) in setOf("book", "pencil", "pen", "notebook", "crayon", "blackboard", "schoolbag", "globe"))
    }
}
