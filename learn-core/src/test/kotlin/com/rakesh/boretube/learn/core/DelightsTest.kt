package com.rakesh.boretube.learn.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class DelightsTest {
    private fun q(fact: String, answer: String = "56", explain: String = "Seven eights make fifty-six.") = Question(
        key = "k:1", skill = "k", prompt = "7 × 8 = ?", promptHi = null, spoken = "", spokenHi = null,
        options = listOf(answer, "54"), answer = 0, fact = fact, explain = explain,
    )

    @Test fun cheerAddsTheFactOnlyWhenItSaysMore() {
        assertEquals("Yes! 7 × 8 = 56", Cheer.right(q("7 × 8 = 56"), combo = 1, seq = 0))
        assertEquals("You got it!", Cheer.right(q("56"), combo = 1, seq = 1))
        assertEquals("Three in a row!", Cheer.right(q("7 × 8 = 56"), combo = 3, seq = 0))
        assertTrue(Cheer.isDidYouKnow(3) && !Cheer.isDidYouKnow(2) && !Cheer.isDidYouKnow(0))
    }

    @Test fun seasonsAndGreetings() {
        assertEquals("diwali", Seasons.of(LocalDate.parse("2026-11-08"))?.id)
        assertEquals("republic", Seasons.of(LocalDate.parse("2027-01-26"))?.id)
        assertEquals("monsoon", Seasons.of(LocalDate.parse("2026-07-10"))?.id)
        assertNull(Seasons.of(LocalDate.parse("2026-03-15")))
        assertEquals("Good morning! Where shall we go?", Cheer.greeting(9, LocalDate.parse("2026-03-15")))
        assertEquals("Good evening! You mastered Magnets. What next?", Cheer.greeting(19, LocalDate.parse("2026-03-15"), "Magnets"))
    }

    @Test fun ranksRiseWithTiers() {
        assertEquals("Magnets: you're now a Ranger!", Ranks.rankUp("Magnets", 1, 2))
        assertEquals("Magnets: you're now an Expert!", Ranks.rankUp("Magnets", 2, 3))
        assertNull(Ranks.rankUp("Magnets", 2, 2))
    }

    @Test fun theChestOpensOnTheThirdDayAndNeverTakesAnythingAway() {
        val pool = listOf("tiger", "kite", "rocket")
        val mon = LocalDate.parse("2026-11-02")
        var s = LearnState()
        s = Chest.played(s, mon, pool)
        s = Chest.played(s, mon, pool) // the same day counts once
        assertEquals(1, Chest.status(s, mon).days)
        s = Chest.played(s, mon.plusDays(2), pool)
        assertFalse(Chest.status(s, mon).open)
        s = Chest.played(s, mon.plusDays(4), pool)
        val st = Chest.status(s, mon.plusDays(4))
        assertTrue(st.open)
        assertTrue(st.treasure in pool)
        // A fourth day doesn't open it twice; next week starts fresh, the treasure stays.
        s = Chest.played(s, mon.plusDays(5), pool)
        assertEquals(1, s.treasures.size)
        assertEquals(0, Chest.status(s, mon.plusDays(7)).days)
        assertEquals(1, s.treasures.size)
    }
}
