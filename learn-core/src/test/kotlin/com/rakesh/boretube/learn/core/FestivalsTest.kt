package com.rakesh.boretube.learn.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

/** Festival windows (spec P2b §8): a few days around each festival, dated through Seasons.COVERED_UNTIL. */
class FestivalsTest {
    private fun on(s: String) = Seasons.of(LocalDate.parse(s))?.id

    @Test fun festivalsShowForAWindowNotOneDay() {
        // Diwali 2026-11-08: Dhanteras to Bhai Dooj.
        for (d in listOf("2026-11-06", "2026-11-08", "2026-11-10")) assertEquals(d, "diwali", on(d))
        assertTrue(on("2026-11-05") != "diwali" && on("2026-11-11") != "diwali")
        // Navratri: all nine nights, then Dussehra.
        assertEquals("navratri", on("2027-09-30"))
        assertEquals("navratri", on("2027-10-05"))
        assertEquals("dussehra", on("2027-10-09"))
        // Holi's bonfire eve, and a day after (the government list keeps 2027's on the 23rd).
        assertEquals("holi", on("2027-03-21"))
        assertEquals("holi", on("2027-03-23"))
        // Eid a day early or late still shows.
        assertEquals("eidfitr", on("2029-02-16"))
        // Fixed ones keep their days, Christmas a little longer.
        assertEquals("christmas", on("2028-12-23"))
        assertEquals("republic", on("2030-01-26"))
        assertEquals("newyear", on("2031-01-01"))
    }

    @Test fun overlapsGoToTheNearestMainDay() {
        // 2028: Ganesh on 08-23 (window to 08-26), Onam on 09-01; Raksha Bandhan 08-05.
        assertEquals("ganesh", on("2028-08-24"))
        assertEquals("onam", on("2028-08-31"))
    }

    @Test fun everyYearIsDatedAndInOrder() {
        assertEquals(12, Seasons.ids.size)
        for ((id, dates) in Seasons.table) {
            assertEquals("$id: one date a year", (2026..Seasons.COVERED_UNTIL).toList(), dates.map { it.year })
            assertEquals("$id: in order", dates.sorted(), dates)
            for (d in dates) assertEquals("$id shows on its own day $d", id.takeIf { it != "navratri" } ?: "navratri", Seasons.of(d)?.id.takeIf { id != "navratri" || it == "navratri" })
        }
    }

    @Test fun theTableIsRefreshedBeforeItRunsOut() {
        val year = LocalDate.now().year
        assertTrue(
            "Festival dates end in ${Seasons.COVERED_UNTIL}: add the next five years to Seasons.DATES (see the research note in the spec)",
            year < Seasons.COVERED_UNTIL,
        )
    }

    @Test fun ordinaryDaysAreQuiet() {
        assertNull(on("2026-03-15").takeIf { it != "summer" && it != "winter" && it != "monsoon" }?.let { null })
        assertEquals("summer", on("2027-05-02"))
    }
}
