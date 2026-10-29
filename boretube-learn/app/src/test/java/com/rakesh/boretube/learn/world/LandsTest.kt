package com.rakesh.boretube.learn.world

import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Maths
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LandsTest {
    @Test fun bazaarHoldsTheMathsLadderGardenAndTrailAreEmptyInP1() {
        assertEquals(Maths.LADDER.map { it.id }, Lands.of(LandId.bazaar).skills)
        assertTrue(Lands.of(LandId.garden).skills.isEmpty())
        assertTrue(Lands.of(LandId.trail).skills.isEmpty())
    }

    @Test fun thePathIsTheClassWindow() {
        val path = Lands.path(Lands.of(LandId.bazaar), grade = 4)
        assertEquals("tablesLow", path.first())
        assertEquals("decimals", path.last())
        assertTrue(path.size in 3..12)
        for (g in 0..7) assertTrue("class $g", Lands.path(Lands.of(LandId.bazaar), g).size in 3..12)
    }

    @Test fun progressCountsMasteredAndNamesTheNext() {
        val s = LearnState(grade = 4, rung = Maths.indexOf("tablesHigh"), mastered = listOf("tablesLow", "money"))
        val p = Lands.progress(s, Lands.of(LandId.bazaar), 4)
        assertEquals(2, p.mastered)
        assertEquals(Lands.path(Lands.of(LandId.bazaar), 4).size, p.total)
        assertEquals("tablesHigh", p.next)
        assertEquals(0, Lands.progress(s, Lands.of(LandId.garden), 4).total)
    }

    @Test fun everySkillHasABadge() {
        for (sk in Maths.LADDER) assertTrue(sk.id, Lands.badge(sk.id).isNotBlank())
    }
}
