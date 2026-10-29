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
            theme != null -> "$hello ${theme.line}"
            lastMastered != null -> "$hello You mastered $lastMastered. What next?"
            else -> "$hello Where shall we go?"
        }
    }

    const val FACT_MAX = 40
    const val DYK_EVERY = 3
}

/** Festivals and seasons Tubby notices. Moving festivals use a dated table (update it yearly). */
object Seasons {
    data class Theme(val id: String, val line: String, val pic: String)

    private val DIWALI = listOf("2025-10-20", "2026-11-08", "2027-10-29").map(LocalDate::parse)
    private val HOLI = listOf("2026-03-04", "2027-03-22").map(LocalDate::parse)

    private val FIXED = listOf(
        MonthDay.of(1, 1) to Theme("newyear", "Happy New Year!", "star"),
        MonthDay.of(1, 26) to Theme("republic", "Happy Republic Day!", "star"),
        MonthDay.of(8, 15) to Theme("independence", "Happy Independence Day!", "kite"),
        MonthDay.of(10, 2) to Theme("gandhi", "It's Gandhi Jayanti today.", "flower"),
        MonthDay.of(11, 14) to Theme("children", "Happy Children's Day!", "balloon"),
        MonthDay.of(12, 25) to Theme("christmas", "Merry Christmas!", "star"),
    )

    fun of(day: LocalDate): Theme? {
        if (DIWALI.any { kotlin.math.abs(it.toEpochDay() - day.toEpochDay()) <= 2 }) return Theme("diwali", "Happy Diwali! Tubby lit a diya.", "diya")
        if (HOLI.any { kotlin.math.abs(it.toEpochDay() - day.toEpochDay()) <= 1 }) return Theme("holi", "Happy Holi! So many colours!", "pichkari")
        FIXED.firstOrNull { it.first == MonthDay.from(day) }?.let { return it.second }
        return when (day.monthValue) {
            7, 8 -> Theme("monsoon", "Rainy days! Shall we learn inside?", "rain")
            12, 1 -> Theme("winter", "Brrr, it's chilly! Let's warm up our brains.", "sweater")
            in 4..6 -> Theme("summer", "Hot sunny days! Stay cool and learn.", "sun")
            else -> null
        }
    }
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
