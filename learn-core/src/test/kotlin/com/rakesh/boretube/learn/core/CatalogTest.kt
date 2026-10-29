package com.rakesh.boretube.learn.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.random.Random

class CatalogTest {
    private val now = 1_800_000_000_000L

    private fun item(i: Int, picture: String? = null) = Item(
        id = "w$i", q = "Which word names a thing?", options = listOf("cat$i", "run", "big", "soft"), answer = 0,
        explain = "A naming word names a thing: cat$i.", picture = picture,
    )

    private val pack = Pack(
        id = "english-1", subject = "english", grade = 1, reviewed = Reviewed("parent", "2026-10-29"),
        skills = listOf(PackSkillDoc("en1.naming", "Naming words", "EN-1.07", "Aa", listOf("quickfire", "catch"), List(12) { item(it) })),
    )

    @Test fun mathsCatalogKeepsTheLadder() {
        assertEquals(Maths.LADDER.size, Catalog.MATHS.sources.size)
        assertEquals("maths", Catalog.MATHS.skill("tablesHigh")!!.subject)
        assertEquals("tablesHigh:7:8", Catalog.MATHS.fromKey("tablesHigh:7:8", Random(1))!!.key)
    }

    @Test fun packSkillsMakeQuestionsAndRebuildFromKeys() {
        val c = Catalog.of(listOf(pack))
        val s = c.skill("en1.naming")!!
        assertEquals(1, s.grade)
        assertEquals("english", s.subject)
        val q = s.next(Random(3))
        assertTrue(q.key.startsWith("en1.naming:w"))
        assertEquals(q.answerText, c.fromKey(q.key, Random(9))!!.answerText)
        assertTrue(q.answerText.startsWith("cat"))
        assertEquals(q.answerText, q.fact)
        assertNull(c.fromKey("en1.naming:nope", Random(1)))
        val e = c.easierThan(q, Random(2))!!
        assertTrue(e.key != q.key && e.skill == "en1.naming")
        assertEquals(listOf("en1.naming"), c.bySubject("english").map { it.id })
    }

    @Test fun formatsRotateWithPlays() {
        assertEquals(Format.catch, Levels.formatFor("tablesHigh", 0))
        assertEquals(Format.pairs, Levels.formatFor("tablesHigh", 1))
        assertEquals(Format.catch, Levels.formatFor("tablesHigh", 2))
        assertEquals(Format.build, Levels.formatFor("placeValue", 0))
        assertEquals(Format.quickfire, Levels.formatFor("placeValue", 1))
        assertEquals(Format.quickfire, Levels.formatFor("clock", 5))
        val c = Catalog.of(listOf(pack))
        assertEquals(Format.catch, Levels.formatFor("en1.naming", 1, c))
    }

    @Test fun finishCountsPlays() {
        val q = Maths.fromKey("tablesHigh:7:8", Random(1))!!
        val r = Levels.finish(LearnState(), "tablesHigh", List(8) { Answered(q, q.answer, true, 2_000, false) }, java.time.LocalDate.parse("2026-10-29"))
        assertEquals(1, r.state.plays["tablesHigh"])
    }

    @Test fun pairsAreSixFactsWithDistinctFaces() {
        repeat(50) { seed ->
            val p = Levels.pairsFor(LearnState(), "tablesHigh", now, Random(seed))
            assertEquals(6, p.size)
            val faces = p.flatMap { listOf(Levels.pairPrompt(it), it.answerText) }
            assertEquals("seed $seed: $faces", 12, faces.toSet().size)
        }
        assertEquals("7 × 8", Levels.pairPrompt(Maths.fromKey("tablesHigh:7:8", Random(1))!!))
    }

    @Test fun buildTargetsAreDistinctTwoDigitNumbers() {
        val t = Levels.buildTargets(LearnState(), now, Random(4))
        assertEquals(5, t.size)
        assertEquals(5, t.map { it.key }.toSet().size)
        assertTrue(t.all { it.skill == "placeValue" })
        assertEquals(47, Levels.buildTarget(Maths.fromKey("placeValue:47", Random(1))!!))
    }

    @Test fun planUsesTheCatalog() {
        val c = Catalog.of(listOf(pack))
        val p = Levels.plan(LearnState(), "en1.naming", 8, now, Random(5), c)
        assertEquals(8, p.size)
        assertTrue(p.all { it.skill == "en1.naming" })
        assertEquals(8, p.map { it.key }.toSet().size)
    }

    @Test fun validatorCatchesBadPacks() {
        assertTrue(PackValidator.check(pack, pictures = setOf("cat")).isEmpty())
        val bad = pack.copy(skills = listOf(pack.skills[0].copy(items = listOf(
            item(1).copy(answer = 4),
            item(2).copy(options = listOf("a", "a", "b")),
            item(3).copy(explain = "This explanation is far too long for a child of this age to read."),
            item(4).copy(explain = "Two sentences. Not one."),
            item(5, picture = "unicorn"),
        ))))
        val errs = PackValidator.check(bad, pictures = setOf("cat"))
        for (needle in listOf("answer index", "options repeat", "12 words", "one sentence", "unknown picture", "at least 12 items")) {
            assertTrue("$needle in $errs", errs.any { needle in it })
        }
        assertNotNull(PackValidator.check(pack.copy(subject = "art"), emptySet()).firstOrNull { "subject" in it })
    }
}
