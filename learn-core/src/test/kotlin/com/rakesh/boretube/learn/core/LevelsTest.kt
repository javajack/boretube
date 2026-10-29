package com.rakesh.boretube.learn.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import kotlin.random.Random

class LevelsTest {
    private val now = 1_800_000_000_000L
    private val day = LocalDate.parse("2026-10-29")

    @Test fun planHasEightQuestionsEvenForSmallSkills() {
        for (id in listOf("biggest10", "count10", "next20", "tablesHigh", "fractions", "clock")) {
            val p = Levels.plan(LearnState(grade = 0), id, 8, now, Random(1))
            assertEquals(id, 8, p.size)
            assertTrue(id, p.all { it.skill == id })
            assertTrue("no repeat back to back in $id", p.zipWithNext().none { (a, b) -> a.key == b.key })
        }
    }

    @Test fun unknownSkillPlansNothing() {
        assertTrue(Levels.plan(LearnState(), "nope", 8, now, Random(1)).isEmpty())
    }

    @Test fun dueFactsOfThisSkillComeFirst() {
        val s = LearnState(facts = listOf(Fact("divide:7:8", 1, now - 1), Fact("tablesHigh:7:8", 1, now - 1)))
        val p = Levels.plan(s, "tablesHigh", 8, now, Random(2))
        assertEquals("tablesHigh:7:8", p.first().key)
        assertTrue(p.none { it.key == "divide:7:8" })
    }

    @Test fun catchKeepsTheAnswerAndTwoMistakes() {
        repeat(300) { i ->
            val q = Maths.skill("tablesHigh")!!.next(Random(i))
            val c = Levels.forCatch(q, Random(i))
            assertEquals(3, c.options.size)
            assertEquals(q.answerText, c.answerText)
            assertTrue(c.options.all { it in q.options })
            assertEquals(3, c.options.toSet().size)
        }
        // Three-option questions are left as they are.
        val f = Maths.fromKey("fractions:3:4:2:3", Random(1))!!
        assertEquals(f, Levels.forCatch(f, Random(1)))
    }

    @Test fun starsForAccuracyOnly() {
        assertEquals(1, Levels.stars(0, 8))
        assertEquals(1, Levels.stars(4, 8))
        assertEquals(2, Levels.stars(5, 8))
        assertEquals(2, Levels.stars(6, 8))
        assertEquals(3, Levels.stars(7, 8))
        assertEquals(3, Levels.stars(8, 8))
        assertEquals(1, Levels.stars(0, 0))
    }

    @Test fun finishKeepsBestStarsAndMarksMasteryOnce() {
        var s = LearnState(grade = 4, rung = Maths.indexOf("tablesHigh"))
        val q = Maths.fromKey("tablesHigh:7:8", Random(1))!!
        val all = List(8) { Answered(q, q.answer, true, 2_000, false) }
        val r1 = Levels.finish(s, "tablesHigh", all, day)
        assertEquals(3, r1.stars)
        assertFalse("one day is not mastery", r1.newlyMastered)
        s = r1.state
        val half = all.mapIndexed { i, a -> if (i < 4) a.copy(picked = (q.answer + 1) % 4, correct = false) else a }
        val r2 = Levels.finish(s, "tablesHigh", half, day.plusDays(1))
        assertEquals(1, r2.stars)
        assertEquals(4, r2.right)
        assertEquals(8, r2.total)
        assertEquals(3, r2.bestStars)
        assertEquals(3, r2.state.stars["tablesHigh"])
        assertTrue(r2.newlyMastered)
        assertTrue("tablesHigh" in r2.state.mastered)
        assertEquals(q.key, r2.toPractise?.key)
        val r3 = Levels.finish(r2.state, "tablesHigh", all, day.plusDays(2))
        assertFalse(r3.newlyMastered)
        assertNull(r3.toPractise)
        assertEquals(1, r3.state.mastered.count { it == "tablesHigh" })
    }

    @Test fun followUpsDontCountTowardStars() {
        val q = Maths.fromKey("tablesHigh:7:8", Random(1))!!
        val main = List(8) { Answered(q, q.answer, true, 2_000, false) }
        val follow = List(3) { Answered(q, (q.answer + 1) % 4, false, 2_000, true) }
        assertEquals(3, Levels.finish(LearnState(grade = 4), "tablesHigh", main + follow, day).stars)
    }

    @Test fun formatsFitTheAnswers() {
        assertEquals(Format.catch, Levels.formatFor("tablesHigh"))
        assertEquals(Format.catch, Levels.formatFor("add10"))
        assertEquals(Format.quickfire, Levels.formatFor("clock"))
        assertEquals(Format.quickfire, Levels.formatFor("fractions"))
        assertEquals(Format.quickfire, Levels.formatFor("count10"))
    }

    @Test fun oldProgressJsonStillParses() {
        val old = """{"grade":3,"rung":9,"stats":{},"facts":[],"week":{}}"""
        val s = kotlinx.serialization.json.Json { ignoreUnknownKeys = true }.decodeFromString(LearnState.serializer(), old)
        assertTrue(s.stars.isEmpty() && s.mastered.isEmpty())
    }
}
