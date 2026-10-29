package com.rakesh.boretube.learn.core

import java.time.LocalDate
import java.time.MonthDay

/**
 * White-hat delight (spec P2b §7): what Tubby says, seasonal themes, rank
 * names for tiers and the weekly treasure chest. Pure, so the TV and the
 * tests agree. Nothing here punishes a missed day: a chest only ever fills.
 */
object Cheer {
    private val WORDS = listOf("Yes!", "You got it!", "Brilliant!", "Spot on!", "Super!", "Well done!", "Shabash!", "Correct!")

    /** Tubby's line for a right answer: combo milestones first, else praise plus the fact when it adds something. */
    fun right(q: Question, combo: Int, seq: Int): String = when (combo) {
        3 -> "Three in a row!"
        5 -> "Five in a row! You're on fire!"
        8 -> "Eight in a row! Amazing!"
        else -> {
            val w = WORDS[Math.floorMod(seq, WORDS.size)]
            val f = q.fact.trim()
            if (f.isNotEmpty() && !f.equals(q.answerText, ignoreCase = true) && f.length <= FACT_MAX && !f.startsWith("pic:")) "$w $f" else w
        }
    }

    /** A fact the child missed before, now right. */
    const val COMEBACK = "You got it this time!"

    /** "Did you know?" uses the question's own explanation. */
    fun didYouKnow(q: Question): String? = q.explain.trim().takeIf { it.isNotEmpty() }

    /** Every [DYK_EVERY]th right answer in a level shows the explanation as a "Did you know?". */
    fun isDidYouKnow(rights: Int): Boolean = rights > 0 && rights % DYK_EVERY == 0

    /** The town greeting: the time of day, a festival or season, and a nod to the last thing mastered. */
    fun greeting(hour: Int, day: LocalDate, lastMastered: String? = null): String {
        val hello = when (hour) {
            in 5..11 -> "Good morning!"
            in 12..16 -> "Good afternoon!"
            else -> "Good evening!"
        }
        val theme = Seasons.of(day)
        return when {
            // A festival or season speaks for itself (the header has room for one short line).
            theme != null -> theme.line
            lastMastered != null -> "$hello You mastered $lastMastered. What next?"
            else -> "$hello Where shall we go?"
        }
    }

    const val FACT_MAX = 40
    const val DYK_EVERY = 3
}

/**
 * Festivals and seasons Tubby notices (spec P2b §8). A festival shows for a
 * window of days around it (not one day), so a child who plays the day
 * before or after still sees the town dressed up, and the table only needs a
 * look once every few years. Moving festivals are dated through
 * [COVERED_UNTIL]; a test fails a year before that runs out.
 */
object Seasons {
    /** Decorations the town draws for a theme. */
    enum class Decor {
        toran, redToran, garbaToran, bunting, diyas, puffs, kites, balloons, snow, twinkles, lanterns, crescent,
        fairyLights, warmLights, rakhis, matki, modaks, dandiya, pookalam, xmasTree,
    }

    data class Theme(val id: String, val line: String, val pic: String, val decor: Set<Decor> = emptySet())

    /** A festival on [dates]: shown from [before] days ahead until [after] days after each (or until [until]'s date). */
    private class Festival(val theme: Theme, val dates: List<LocalDate>, val before: Int, val after: Int, val until: List<LocalDate>? = null) {
        fun covers(day: LocalDate): Boolean = dates.withIndex().any { (k, d) ->
            val end = until?.getOrNull(k) ?: d
            !day.isBefore(d.minusDays(before.toLong())) && !day.isAfter(end.plusDays(after.toLong()))
        }
    }

    private fun d(vararg s: String) = s.map(LocalDate::parse)

    /** The last year the moving dates below cover. */
    const val COVERED_UNTIL = 2031

    /**
     * The main day of each moving festival, 2026–2031 (India, New Delhi):
     * drikpanchang.com cross-checked with calendarlabs and the Government of
     * India holiday lists (2027); 2029–2031 from drikpanchang. Eid dates are
     * the expected ones (±1 day with the moon sighting; the window absorbs
     * it). Research of 2026-10-30.
     */
    private val DATES: Map<String, List<LocalDate>> = mapOf(
        "sankranti" to d("2026-01-14", "2027-01-14", "2028-01-15", "2029-01-14", "2030-01-14", "2031-01-15"),
        "holi" to d("2026-03-04", "2027-03-22", "2028-03-11", "2029-03-01", "2030-03-20", "2031-03-09"),
        "eidfitr" to d("2026-03-21", "2027-03-10", "2028-02-27", "2029-02-15", "2030-02-05", "2031-01-25"),
        "eidadha" to d("2026-05-28", "2027-05-17", "2028-05-06", "2029-04-25", "2030-04-14", "2031-04-03"),
        "rakhi" to d("2026-08-28", "2027-08-17", "2028-08-05", "2029-08-23", "2030-08-13", "2031-08-02"),
        "janmashtami" to d("2026-09-04", "2027-08-25", "2028-08-13", "2029-09-01", "2030-08-21", "2031-08-09"),
        "ganesh" to d("2026-09-14", "2027-09-04", "2028-08-23", "2029-09-11", "2030-09-01", "2031-09-20"),
        "onam" to d("2026-08-26", "2027-09-12", "2028-09-01", "2029-08-22", "2030-09-09", "2031-08-30"),
        "navratri" to d("2026-10-11", "2027-09-30", "2028-09-19", "2029-10-08", "2030-09-28", "2031-10-17"),
        "dussehra" to d("2026-10-20", "2027-10-09", "2028-09-27", "2029-10-16", "2030-10-06", "2031-10-25"),
        "diwali" to d("2026-11-08", "2027-10-29", "2028-10-17", "2029-11-05", "2030-10-26", "2031-11-14"),
        "gurpurab" to d("2026-11-24", "2027-11-14", "2028-11-02", "2029-11-21", "2030-11-10", "2031-11-28"),
    )

    private val MOVING = listOf(
        Festival(Theme("diwali", "Happy Diwali! Tubby lit diyas.", "diya", setOf(Decor.diyas, Decor.toran, Decor.twinkles)), DATES.getValue("diwali"), 2, 2),
        Festival(Theme("holi", "Happy Holi! So many colours!", "pichkari", setOf(Decor.puffs)), DATES.getValue("holi"), 1, 2),
        Festival(Theme("navratri", "Navratri! Time for garba!", "drum", setOf(Decor.garbaToran, Decor.dandiya)), DATES.getValue("navratri"), 0, 0, DATES.getValue("dussehra").map { it.minusDays(1) }),
        Festival(Theme("dussehra", "Happy Dussehra!", "flower", setOf(Decor.toran, Decor.twinkles)), DATES.getValue("dussehra"), 0, 1),
        Festival(Theme("ganesh", "Ganpati Bappa Morya!", "ladoo", setOf(Decor.redToran, Decor.modaks)), DATES.getValue("ganesh"), 1, 3),
        Festival(Theme("eidfitr", "Eid Mubarak! Sweet seviyan!", "lantern", setOf(Decor.lanterns, Decor.crescent, Decor.twinkles)), DATES.getValue("eidfitr"), 1, 2),
        Festival(Theme("eidadha", "Eid Mubarak!", "lantern", setOf(Decor.warmLights, Decor.crescent, Decor.twinkles)), DATES.getValue("eidadha"), 1, 2),
        Festival(Theme("rakhi", "Happy Raksha Bandhan!", "giftbox", setOf(Decor.rakhis)), DATES.getValue("rakhi"), 1, 0),
        Festival(Theme("janmashtami", "Happy Janmashtami!", "flute", setOf(Decor.matki)), DATES.getValue("janmashtami"), 1, 1),
        Festival(Theme("onam", "Happy Onam! Pookalam time!", "rangoli", setOf(Decor.toran, Decor.pookalam)), DATES.getValue("onam"), 2, 1),
        Festival(Theme("gurpurab", "Happy Gurpurab!", "diya", setOf(Decor.warmLights, Decor.diyas)), DATES.getValue("gurpurab"), 1, 1),
        Festival(Theme("sankranti", "Happy Sankranti! Kites up!", "kite", setOf(Decor.kites)), DATES.getValue("sankranti"), 1, 1),
    )

    /** Same date every year: (month-day, days before, days after). */
    private val FIXED = listOf(
        Triple(MonthDay.of(12, 31), 0, 1) to Theme("newyear", "Happy New Year!", "balloon", setOf(Decor.balloons, Decor.twinkles)),
        Triple(MonthDay.of(1, 26), 1, 0) to Theme("republic", "Happy Republic Day!", "star", setOf(Decor.bunting)),
        Triple(MonthDay.of(8, 15), 1, 0) to Theme("independence", "Happy Independence Day!", "kite", setOf(Decor.bunting, Decor.kites)),
        Triple(MonthDay.of(10, 2), 0, 0) to Theme("gandhi", "It's Gandhi Jayanti today.", "flower"),
        Triple(MonthDay.of(11, 14), 0, 0) to Theme("children", "Happy Children's Day!", "balloon", setOf(Decor.balloons)),
        Triple(MonthDay.of(12, 25), 2, 1) to Theme("christmas", "Merry Christmas!", "star", setOf(Decor.fairyLights, Decor.snow, Decor.xmasTree)),
    )

    fun of(day: LocalDate): Theme? {
        // Two windows can overlap (Onam and Ganesh in 2028): the one whose main day is nearest wins.
        MOVING.filter { it.covers(day) }.minByOrNull { f -> f.dates.minOf { kotlin.math.abs(it.toEpochDay() - day.toEpochDay()) } }?.let { return it.theme }
        for ((w, theme) in FIXED) {
            val (md, before, after) = w
            for (y in listOf(day.year - 1, day.year, day.year + 1)) {
                val at = md.atYear(y)
                if (!day.isBefore(at.minusDays(before.toLong())) && !day.isAfter(at.plusDays(after.toLong()))) return theme
            }
        }
        return when (day.monthValue) {
            7, 8 -> Theme("monsoon", "Rainy days! Learn inside?", "rain")
            12, 1 -> Theme("winter", "Chilly! Warm up your brain.", "sweater")
            in 4..6 -> Theme("summer", "Sunny days! Stay cool.", "sun")
            else -> null
        }
    }

    /** The moving festivals' dates, by id (tests check the table). */
    internal val table: Map<String, List<LocalDate>> get() = DATES
    internal val ids: Set<String> get() = DATES.keys

}

/** Friendly names for a skill's tiers. */
object Ranks {
    private val NAMES = listOf("Explorer", "Ranger", "Expert")

    fun of(tier: Int): String = NAMES[(tier - 1).coerceIn(0, NAMES.lastIndex)]

    /** "Magnets: you're now a Ranger!" when the tier went up, else null. */
    fun rankUp(title: String, before: Int, after: Int): String? =
        if (after > before) "$title: you're now ${article(of(after))} ${of(after)}!" else null

    private fun article(w: String) = if (w.first().lowercaseChar() in "aeiou") "an" else "a"
}

/**
 * The weekly treasure chest: play on [GOAL] different days in a week and it
 * opens with a picture for the sticker book. Missing days never takes
 * anything away; a new week simply starts a new chest.
 */
object Chest {
    const val GOAL = 3

    data class Status(val days: Int, val goal: Int, val open: Boolean, val treasure: String?)

    fun status(s: LearnState, day: LocalDate): Status {
        val week = Learner.weekOf(day)
        val days = s.playDays.count { runCatching { Learner.weekOf(LocalDate.parse(it)) == week }.getOrDefault(false) }
        val i = s.chestWeeks.indexOf(week)
        return Status(days.coerceAtMost(GOAL), GOAL, i >= 0, s.treasures.getOrNull(i))
    }

    /**
     * Notes that the child played on [day]. When this makes the week's
     * [GOAL]th day, the chest opens with a picture from [pool] they don't
     * have yet (chosen by the week, so it's stable).
     */
    fun played(s: LearnState, day: LocalDate, pool: List<String>): LearnState {
        val d = day.toString()
        val days = if (d in s.playDays) s.playDays else (s.playDays + d).takeLast(KEEP_DAYS)
        var st = s.copy(playDays = days)
        val week = Learner.weekOf(day)
        if (week in st.chestWeeks || status(st, day).days < GOAL) return st
        val fresh = pool.filter { it !in st.treasures }.ifEmpty { pool }
        val pick = fresh.getOrNull(Math.floorMod(week.hashCode(), maxOf(1, fresh.size))) ?: return st
        st = st.copy(chestWeeks = st.chestWeeks + week, treasures = st.treasures + pick)
        return st
    }

    private const val KEEP_DAYS = 14
}
