package com.rakesh.boretube.learn.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.time.LocalDate
import kotlin.random.Random

class LearnTest {
    private val day = LocalDate.parse("2026-10-29")
    private val now = 1_800_000_000_000L
    private val jargon = listOf("commutative", "numerator", "denominator", "associative", "quotient", "dividend", "integer", "variable", "operand")

    private fun q(key: String) = Maths.fromKey(key, Random(1))!!

    // ── generators ──

    @Test fun everySkillSoaksCleanly() {
        val r = Random(42)
        for (s in Maths.LADDER) repeat(10_000 / Maths.LADDER.size + 50) {
            val x = s.next(r)
            val where = "${s.id} ${x.key}"
            assertTrue("$where: 3–4 options, got ${x.options}", x.options.size in 3..4)
            assertEquals("$where: options distinct ${x.options}", x.options.size, x.options.toSet().size)
            assertTrue("$where: answer index", x.answer in x.options.indices)
            assertEquals(s.id, x.skill)
            assertTrue("$where: rebuilds from its key", Maths.fromKey(x.key, Random(7))?.answerText == x.answerText)
            val words = Maths.wordCount(x.explain)
            assertTrue("$where: explanation ≤ 12 words ($words): ${x.explain}", words <= Maths.MAX_EXPLAIN_WORDS)
            assertTrue("$where: one sentence: ${x.explain}", x.explain.endsWith(".") && Regex("[.!?]\\s").find(x.explain) == null)
            for (j in jargon) assertFalse("$where: no jargon '$j'", x.explain.lowercase().contains(j))
            assertFalse("$where: no negative options below KG", s.grade < 6 && x.options.any { it.startsWith("−") })
        }
    }

    @Test fun answersAreRight() {
        assertEquals("56", q("tablesHigh:7:8").answerText)
        assertEquals("15", q("make10:9:6").answerText)
        assertEquals("83", q("add100:38:45").answerText)
        assertEquals("8", q("divide:7:8").answerText)
        assertEquals("92", q("mul21:23:4").answerText)
        assertEquals("3/4", q("fractions:3:4:2:3").answerText)
        assertEquals("Same", q("fractions:1:2:2:4").answerText)
        assertEquals("0.5", q("decimals:5:1:45:2").answerText)
        assertEquals("25", q("percent:10:250").answerText)
        assertEquals("2", q("negatives:-3:5").answerText)
        assertEquals("8", q("equations:0:7:8").answerText)
        assertEquals("13", q("equations:1:4:9").answerText)
        assertEquals("3:30", q("clock:3:30").answerText)
        assertEquals("₹35", q("money:20:10:5").answerText)
        assertEquals("4", q("placeValue:47").answerText)
        assertEquals("5", q("count10:5").answerText)
    }

    @Test fun tablesWrongOptionsAreRealMistakes() {
        val x = q("tablesHigh:7:8")
        val wrong = x.options.filterIndexed { i, _ -> i != x.answer }.map { it.toInt() }.toSet()
        // 7×7, 7×9, 8×8, swapped digits 65: three of them make the cut.
        assertTrue("wrongs $wrong", wrong.all { it in setOf(49, 63, 64, 65) })
    }

    @Test fun explanationsReadSimply() {
        assertEquals("7 × 8 is 7 × 4 doubled: 28 + 28 = 56.", q("tablesHigh:7:8").explain)
        assertEquals("Make 10 first: 9 + 1 = 10, then 5 more is 15.", q("make10:9:6").explain)
        assertEquals("0.5 is 0.50, and 50 hundredths beats 45.", q("decimals:5:1:45:2").explain)
        assertEquals("Start at −3 and move 5 steps up: you reach 2.", q("negatives:-3:5").explain)
    }

    @Test fun tablesLearnPictureSplitsTheTrick() {
        assertEquals(Visual.Dots(7, 8, 4), q("tablesHigh:7:8").learnVisual)
        assertEquals(Visual.Dots(7, 9, 8), q("tablesHigh:7:9").learnVisual)
    }

    @Test fun easierFollowUps() {
        assertEquals("tablesHigh:7:4", Maths.easierThan(q("tablesHigh:7:8"), Random(1))!!.key)
        assertEquals("tablesHigh:7:10", Maths.easierThan(q("tablesHigh:7:9"), Random(1))!!.key)
        assertEquals("tablesHigh:7:6", Maths.easierThan(q("tablesHigh:7:7"), Random(1))!!.key)
        // No own easier fact → the rung below.
        assertEquals("placeValue", Maths.easierThan(q("add100:38:45"), Random(1))!!.skill)
    }

    @Test fun ladderBoundsByClass() {
        assertEquals(0, Maths.firstRung(0))
        assertEquals("tablesLow", Maths.LADDER[Maths.firstRung(3)].id)
        assertEquals("make10", Maths.LADDER[Maths.minRung(3)].id)
        assertEquals("mul21", Maths.LADDER[Maths.maxRung(3)].id)
        assertEquals(Maths.LADDER.lastIndex, Maths.maxRung(7))
        assertEquals(0, Maths.minRung(0))
    }

    @Test fun badKeysDoNotCrash() {
        assertNull(Maths.fromKey("nope:1", Random(1)))
        assertNull(Maths.fromKey("tablesHigh:x:8", Random(1)))
    }

    // ── learner ──

    private fun fresh(grade: Int = 4) = Learner.forGrade(LearnState(), grade)

    @Test fun missQueuesTheFactForTenMinutes() {
        val s = Learner.record(fresh(), q("tablesHigh:7:8"), correct = false, ms = 3_000, now = now, today = day)
        assertEquals(listOf(Fact("tablesHigh:7:8", 1, now + 10 * 60_000)), s.facts)
    }

    @Test fun rightAnswersClimbTheBoxesAndGraduate() {
        var s = Learner.record(fresh(), q("tablesHigh:7:8"), false, 3_000, now, day)
        var t = now
        for (box in 2..5) {
            t += 60_000
            s = Learner.record(s, q("tablesHigh:7:8"), true, 3_000, t, day)
            assertEquals(box, s.facts.single().box)
            assertEquals(t + Learner.INTERVALS_MS[box - 1], s.facts.single().dueAt)
        }
        s = Learner.record(s, q("tablesHigh:7:8"), true, 3_000, t, day)
        assertTrue("graduated", s.facts.isEmpty())
    }

    @Test fun guessesNeverPromote() {
        var s = Learner.record(fresh(), q("tablesHigh:7:8"), false, 3_000, now, day)
        s = Learner.record(s, q("tablesHigh:7:8"), true, 300, now, day)
        assertEquals(1, s.facts.single().box)
        assertEquals(0, s.stats["tablesHigh"]?.right ?: 0)
    }

    @Test fun promotionNeedsThreeRightOnTwoDays() {
        var s = fresh(4)
        val start = s.rung
        val cur = Maths.LADDER[start].id
        val k = Maths.LADDER[start].next(Random(3)).key
        repeat(3) { s = Learner.record(s, q(k), true, 3_000, now, day) }
        assertEquals("same day is not enough", start, s.rung)
        s = Learner.record(s, q(k), true, 3_000, now, day.plusDays(1))
        assertEquals(start + 1, s.rung)
        assertEquals(cur, Maths.LADDER[start].id)
    }

    @Test fun demotionAfterThreeMissesButNotBelowOneClassDown() {
        var s = fresh(1)
        assertEquals(Maths.firstRung(1), s.rung)
        repeat(30) {
            val k = Maths.LADDER[s.rung].next(Random(it)).key
            s = Learner.record(s, q(k), false, 3_000, now, day)
        }
        assertEquals(Maths.minRung(1), s.rung)
        assertEquals(0, s.rung)
    }

    @Test fun promotionStopsOneClassUp() {
        var s = fresh(6)
        var d = day
        repeat(40) {
            val k = Maths.LADDER[s.rung].next(Random(it)).key
            s = Learner.record(s, q(k), true, 3_000, now, d)
            d = d.plusDays(1)
        }
        assertEquals(Maths.maxRung(6), s.rung)
    }

    @Test fun newClassResetsTheRungButKeepsFacts() {
        var s = Learner.record(fresh(4), q("tablesHigh:7:8"), false, 3_000, now, day)
        s = Learner.forGrade(s, 2)
        assertEquals(Maths.firstRung(2), s.rung)
        assertEquals(1, s.facts.size)
    }

    @Test fun roundMixWarmUpCurrentThenDueFacts() {
        var s = Learner.record(fresh(4), q("tablesLow:6:5"), false, 3_000, now, day)
        val round = Learner.plan(s, 3, now + Learner.INTERVALS_MS[0], Random(9))
        assertEquals(3, round.size)
        assertEquals(Maths.LADDER[s.rung - 1].id, round[0].skill)
        assertEquals(Maths.LADDER[s.rung].id, round[1].skill)
        assertEquals("tablesLow:6:5", round[2].key)
        assertEquals(3, round.map { it.key }.toSet().size)
        // Not due yet → topped up with the current skill.
        s = s.copy(facts = s.facts.map { it.copy(dueAt = now + 99_999_999) })
        assertTrue(Learner.plan(s, 3, now, Random(9)).drop(1).all { it.skill == Maths.LADDER[s.rung].id })
        assertEquals(1, Learner.plan(s, 1, now, Random(9)).size)
    }

    @Test fun weekLogCountsAndNamesTheStrongerSkill() {
        var s = fresh(4)
        s = Learner.record(s, q("tablesHigh:7:8"), true, 3_000, now, day)
        s = Learner.record(s, q("tablesHigh:6:8"), true, 3_000, now, day)
        s = Learner.record(s, q("divide:7:8"), false, 3_000, now, day)
        s = Learner.roundDone(s, learned = 1, today = day)
        assertEquals(WeekLog("2026-W44", 1, 2, 1, mapOf("tablesHigh" to 2)), s.week)
        assertEquals("Tables of 6, 7, 8 and 9", Learner.stronger(s, day))
        assertNull(Learner.stronger(s, day.plusDays(7)))
    }

    // ── session ──

    private fun session(vararg keys: String) =
        BrainBreakSession(keys.map { q(it) }) { Maths.easierThan(it, Random(1)) }

    @Test fun allRightGoesStraightThrough() {
        val s = session("tablesHigh:7:8", "make10:9:6")
        assertTrue(s.answer(s.q().answer, 2_000) is QuizScreen.Right)
        assertEquals(1, (s.next() as QuizScreen.Ask).index)
        s.answer(s.q().answer, 2_000)
        val d = s.next() as QuizScreen.Done
        assertEquals(2, d.right)
        assertEquals(0, d.learned)
        assertEquals("2 questions: 2 right, 0 learned", s.summary())
    }

    @Test fun aMissTeachesThenAsksAnEasierOneOnce() {
        val s = session("tablesHigh:7:8")
        val wrong = (s.q().answer + 1) % 4
        val l = s.answer(wrong, 2_000) as QuizScreen.Learn
        assertEquals(wrong, l.picked)
        val f = s.next() as QuizScreen.Ask
        assertTrue(f.followUp)
        assertEquals("tablesHigh:7:4", f.q.key)
        // Missing the follow-up too still ends the round: no second follow-up, no wall.
        s.answer((f.q.answer + 1) % 4, 2_000)
        val d = s.next() as QuizScreen.Done
        assertEquals(0, d.right)
        assertEquals(1, d.learned)
        assertEquals(1, d.rows.size)
        assertEquals(2, s.results.size)
    }

    @Test fun keysOutOfTurnAreIgnored() {
        val s = session("tablesHigh:7:8")
        assertTrue("next while asking", s.next() is QuizScreen.Ask)
        val right = s.answer(s.q().answer, 2_000)
        assertTrue("a second OK on Right", s.answer(0, 1) === right)
        val done = s.next()
        assertTrue(done is QuizScreen.Done)
        assertTrue("answer on Done", s.answer(0, 1) === done)
        assertTrue("next on Done", s.next() === done)
    }

    private fun BrainBreakSession.q(): Question = (screen as QuizScreen.Ask).q
}
