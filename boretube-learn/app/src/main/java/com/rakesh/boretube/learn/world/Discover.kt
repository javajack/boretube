package com.rakesh.boretube.learn.world

import com.rakesh.boretube.learn.core.LearnState
import java.time.LocalDate
import kotlin.random.Random

/** Something worth trying today, and what OK on it does. */
data class Discovery(
    val kind: Kind,
    val land: LandId,
    /** The picture or badge on the card. */
    val title: String,
    val line: String,
    /** The skill to play, or null for a land's Streak run. */
    val skill: String?,
) {
    enum class Kind { practise, newSkill, run, beatBest, peek, remember, visit }
}

/**
 * "Today in Tubby's Town" (spec P2b §8): three cards that bring the rich
 * stuff to the surface and rotate day by day, so a child keeps finding
 * Streak runs, skills they haven't tried, the next class and old favourites.
 * Facts due to come back always lead. Pure: same day, same cards.
 */
object Discover {
    fun today(s: LearnState, world: World, grade: Int, day: LocalDate, n: Int = 3): List<Discovery> {
        val r = Random(day.toEpochDay() * 31 + grade)
        val out = mutableListOf<Discovery>()
        fun add(d: Discovery?) { if (d != null && out.size < n && out.none { it.skill == d.skill && it.kind == d.kind }) out += d }
        val lands = world.lands.filter { it.skills.isNotEmpty() }

        // Practice that's due leads: spaced repetition works only if it comes back.
        val due = s.facts.filter { it.dueAt <= day.plusDays(1).toEpochDay() * DAY_MS }.map { it.key.substringBefore(':') }
            .firstOrNull { world.catalog.skill(it) != null }
        if (due != null) {
            val k = s.facts.count { it.key.startsWith("$due:") }
            add(Discovery(Discovery.Kind.practise, world.landOf(due).id, world.title(due), if (k == 1) "1 thing to practise" else "$k things to practise", due))
        }

        val pool = mutableListOf<Discovery>()
        for (land in lands) {
            val path = world.path(land, grade)
            val own = path.filter { world.catalog.skill(it)?.grade == grade }
            own.filter { (s.plays[it] ?: 0) == 0 }.shuffled(r).take(2).forEach {
                pool += Discovery(Discovery.Kind.newSkill, land.id, world.title(it), "New for you", it)
            }
            val best = s.bestRuns[land.id.name] ?: 0
            pool += if (best == 0) Discovery(Discovery.Kind.run, land.id, "Streak run", "How many in a row?", null)
            else Discovery(Discovery.Kind.beatBest, land.id, "Beat $best in a row", "Streak run", null)
            land.skills.filter { world.catalog.skill(it)?.grade == grade + 1 && (s.plays[it] ?: 0) == 0 }.shuffled(r).firstOrNull()?.let {
                pool += Discovery(Discovery.Kind.peek, land.id, world.title(it), "Peek at ${gradeLabel(grade + 1)}", it)
            }
            s.mastered.filter { it in land.skills }.shuffled(r).firstOrNull()?.let {
                pool += Discovery(Discovery.Kind.remember, land.id, world.title(it), "Remember this one?", it)
            }
            if (land.skills.sumOf { s.plays[it] ?: 0 } == 0) {
                world.progress(s, land, grade).next?.let { pool += Discovery(Discovery.Kind.visit, land.id, land.name, "Not visited yet", it) }
            }
        }
        // Not-yet-visited lands and untried things first, then a daily shuffle of the rest.
        val first = pool.filter { it.kind == Discovery.Kind.visit || it.kind == Discovery.Kind.run }.shuffled(r)
        val rest = pool.filter { it !in first }.shuffled(r)
        val seenLands = mutableSetOf<LandId>()
        // Spread across lands while there's choice.
        for (d in first + rest) if (d.land !in seenLands || out.size + 1 >= n) { val before = out.size; add(d); if (out.size > before) seenLands += d.land }
        for (d in first + rest) add(d)
        return out
    }

    private fun gradeLabel(g: Int) = if (g == 0) "KG" else "Class $g"
    private const val DAY_MS = 86_400_000L
}
