package com.rakesh.boretube.learn.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import kotlin.random.Random

/** Tiers, the new formats' level plans, and the Streak run (spec P2b). */
class DepthTest {
    private val words = listOf("ant", "bee", "cat", "dog", "eel", "fox", "goat", "hen", "ibis", "jay")

    private val skill = GenSkill(
        id = "en9.test", grade = 1, subject = "english", title = "Test", badge = "T",
        templates = listOf(
            Template("first", 1, intArrayOf(words.size)) { p, r ->
                val w = words[p[0]]
                gq("First letter of $w?", Opt.of(w.take(1), listOf("z", "q", "x"), r)!!, "It starts with ${w.take(1)}.")
            },
            Template("tf", 2, intArrayOf(words.size, 2), Format.truefalse) { p, _ ->
                val w = words[p[0]]
                val claim = if (p[1] == 0) w.length else w.length + 1
                gq("\"$w\" has $claim letters.", Opt.trueFalse(p[1] == 0), "$w has ${w.length} letters.")
            },
            Template("basket", 2, intArrayOf(words.size), Format.sort) { p, _ ->
                val w = words[p[0]]
                gq(w, Opt.baskets("Short", "Long", w.length <= 3), "$w has ${w.length} letters.")
            },
            Template("abc", 3, intArrayOf(words.size - 3), Format.order) { p, r ->
                val items = words.subList(p[0], p[0] + 4)
                gq("Put in ABC order", items.shuffled(r) to 0, "A comes before b.", order = items)
            },
        ),
    )
    private val catalog = Catalog(listOf(skill))
    private val now = 1_800_000_000_000L

    @Test fun formatsComeFromTheTemplateKinds() {
        assertEquals(listOf(Format.quickfire, Format.truefalse, Format.sort, Format.order), skill.formats)
        assertEquals(3, skill.tiers)
    }

    @Test fun eachFormatGetsItsOwnKindOfQuestion() {
        val s = LearnState(tiers = mapOf(skill.id to 2))
        val tf = Levels.plan(s, skill.id, 6, now, Random(1), catalog, Format.truefalse)
        assertTrue(tf.all { it.options == listOf("True", "False") })
        val sort = Levels.plan(s, skill.id, 6, now, Random(2), catalog, Format.sort)
        assertEquals(6, sort.size)
        assertTrue(sort.all { it.options == listOf("Short", "Long") })
        val order = Levels.plan(LearnState(tiers = mapOf(skill.id to 3)), skill.id, 4, now, Random(3), catalog, Format.order)
        assertTrue(order.isNotEmpty() && order.all { it.order != null && it.options.sorted() == it.order!!.sorted() })
        val quick = Levels.plan(LearnState(), skill.id, 8, now, Random(4), catalog, Format.quickfire)
        assertTrue(quick.all { it.order == null && it.options != listOf("True", "False") })
    }

    @Test fun levelsAreMostlyTheChildsTierWithAStretch() {
        val plan = Levels.plan(LearnState(), skill.id, 8, now, Random(5), catalog, null)
        assertEquals(8, plan.size)
        assertTrue(plan.take(6).all { it.tier == 1 })
        assertTrue(plan.drop(6).all { it.tier == 2 })
    }

    @Test fun threeStarsMoveUpOneStarMovesDown() {
        assertEquals(2, Levels.nextTier(1, 3, 3))
        assertEquals(3, Levels.nextTier(3, 3, 3))
        assertEquals(1, Levels.nextTier(2, 1, 3))
        assertEquals(2, Levels.nextTier(2, 2, 3))
        val qs = Levels.plan(LearnState(), skill.id, 8, now, Random(6), catalog, Format.quickfire)
        val right = qs.map { Answered(it, it.answer, true, 2000, false) }
        val res = Levels.finish(LearnState(), skill.id, right, LocalDate.of(2026, 10, 30), catalog = catalog)
        assertEquals(2, res.state.tiers[skill.id])
        // The ladder has one tier: nothing recorded.
        val m = Levels.plan(LearnState(), "add10", 8, now, Random(7))
        val mr = Levels.finish(LearnState(), "add10", m.map { Answered(it, it.answer, true, 2000, false) }, LocalDate.of(2026, 10, 30))
        assertNull(mr.state.tiers["add10"])
    }

    @Test fun keysRebuildAndEasierStaysTheSameKind() {
        val r = Random(8)
        repeat(30) {
            val q = skill.next(r, 1 + it % 3, null)
            assertEquals(q.prompt, skill.build(q.key, Random(1))!!.prompt)
        }
        val tf = skill.next(r, 2, Format.truefalse)
        val easier = skill.easier(tf, r)!!
        assertEquals(listOf("True", "False"), easier.options)
        assertNull(skill.build("en9.test:nope:1", r))
        assertNull(skill.build("en9.test:first:99", r))
    }

    @Test fun aStreakRunClimbsEndsAtThreeMissesAndKeepsTheBest() {
        var run = Run("garden")
        val reached = mutableListOf<Int>()
        repeat(10) { val (n, m) = Runs.answer(run, true); run = n; m?.let { reached += it } }
        assertEquals(listOf(5, 10), reached)
        assertEquals(3, run.tier)
        run = Runs.answer(run, false).first
        assertEquals(0, run.streak)
        assertEquals(2, run.tier)
        assertEquals(10, run.best)
        run = Runs.answer(Runs.answer(run, false).first, false).first
        assertTrue(run.over)
        assertEquals(run, Runs.answer(run, true).first)
        val s = Runs.finish(LearnState(), run)
        assertEquals(10, s.bestRuns["garden"])
        assertFalse(Runs.isRecord(s, run))
        assertTrue(Runs.next(Run("garden", tier = 3), listOf(skill), Random(9))!!.order == null)
    }
}
