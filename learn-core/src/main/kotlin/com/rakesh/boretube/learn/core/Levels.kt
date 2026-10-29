package com.rakesh.boretube.learn.core

import java.time.LocalDate
import kotlin.random.Random

/** How a level plays (boretube Learn). */
enum class Format {
    quickfire, catch, pairs, build,
    /** A statement, and a big True or False. */
    truefalse,
    /** Tiles to put in order, first to last. */
    order,
    /** One thing at a time into the left or right basket (two shared options). */
    sort,
}

data class LevelResult(
    val state: LearnState,
    /** Stars this time, 1..3 (accuracy only). */
    val stars: Int,
    /** Best stars ever on this skill. */
    val bestStars: Int,
    /** The skill became mastered with this level (a sticker). */
    val newlyMastered: Boolean,
    /** The first missed main question, to name on the done screen. */
    val toPractise: Question?,
    /** Main questions answered right, of [total] (follow-ups don't count). */
    val right: Int = 0,
    val total: Int = 0,
)

/** A level: [LEVEL_SIZE] questions on one skill, in one format. Pure. */
object Levels {
    const val LEVEL_SIZE = 8

    /** The format for this play of [skillId]: its formats in rotation, one per play. */
    fun formatFor(skillId: String, plays: Int = 0, catalog: Catalog = Catalog.MATHS): Format {
        val f = catalog.skill(skillId)?.formats ?: return Format.quickfire
        return f[plays.mod(f.size)]
    }

    /** Formats that take more doing with a remote (spec P2b §2): a treat now and then, never the diet. */
    val SPECIAL = setOf(Format.sort, Format.order)

    /**
     * The format for the child's next play of [skillId]. A skill's first play
     * is always a plain format (quick-fire, catch, pairs, true or false);
     * Sort and Order come at most every third play (every fourth in KG and
     * Class 1), never twice running, and not right after one went badly
     * ([LearnState.easyNext]).
     */
    fun formatFor(skillId: String, s: LearnState, catalog: Catalog = Catalog.MATHS): Format {
        val f = catalog.skill(skillId)?.formats ?: return Format.quickfire
        val plays = s.plays[skillId] ?: 0
        val plain = f.filter { it !in SPECIAL }
        val special = f.filter { it in SPECIAL }
        if (special.isEmpty() || plain.isEmpty()) return f[plays.mod(f.size)]
        val every = if (s.grade in 0..1) 4 else 3
        val turn = plays % every == every - 1 && skillId !in s.easyNext
        return if (turn) special[(plays / every).mod(special.size)] else plain[(plays - plays / every).mod(plain.size)]
    }

    /**
     * Facts of [skillId] that are due come first, then fresh questions. Keys
     * are distinct while the skill has enough of them; a small skill repeats,
     * but never the same key twice in a row.
     */
    fun plan(
        s: LearnState,
        skillId: String,
        n: Int = LEVEL_SIZE,
        now: Long,
        r: Random,
        catalog: Catalog = Catalog.MATHS,
        format: Format? = null,
    ): List<Question> {
        val skill = catalog.skill(skillId) ?: return emptyList()
        if (format == Format.sort && skill is GenSkill) return skill.sortSet(n, tierOf(s, skillId), r)
        val out = mutableListOf<Question>()
        for (f in s.facts.filter { it.dueAt <= now && it.key.startsWith("$skillId:") }.sortedBy { it.dueAt }) {
            if (out.size < n) catalog.fromKey(f.key, r)?.takeIf { fits(it, format) }?.let { out += it }
        }
        val seen = out.map { it.key }.toMutableSet()
        val tier = tierOf(s, skillId)
        // Mostly the child's tier, with a stretch or two from the next one.
        val stretchFrom = if (tier < skill.tiers) n - STRETCH else n
        var tries = 0
        while (out.size < n && tries < n * 40) {
            tries++
            val t = if (out.size >= stretchFrom) tier + 1 else tier
            val q = skill.next(r, t, format)
            val fresh = q.key !in seen
            val allowRepeat = tries > n * 20 && out.lastOrNull()?.key != q.key
            if (fresh || allowRepeat) {
                out += q
                seen += q.key
            }
        }
        return out
    }

    /** The tier [skillId] is on for this child (1 until they earn more). */
    fun tierOf(s: LearnState, skillId: String): Int = s.tiers[skillId] ?: 1

    /** Whether a question rebuilt from a due fact suits [format]. */
    fun fits(q: Question, format: Format?): Boolean = when (format) {
        Format.order -> q.order != null
        Format.truefalse -> q.options == listOf("True", "False")
        Format.sort -> q.options.size == 2 && q.order == null
        null -> q.order == null
        else -> q.order == null && q.options != listOf("True", "False")
    }

    /** 3 stars moves a skill up a tier, 1 star moves it down. */
    fun nextTier(current: Int, stars: Int, max: Int): Int = when {
        stars >= 3 -> (current + 1).coerceAtMost(max)
        stars <= 1 -> (current - 1).coerceAtLeast(1)
        else -> current
    }.coerceIn(1, maxOf(1, max))

    /** Three options for Catch: the answer and the first two mistakes, reshuffled. */
    fun forCatch(q: Question, r: Random): Question {
        if (q.options.size <= 3) return q
        val wrong = q.options.filterIndexed { i, _ -> i != q.answer }.take(2)
        val opts = (wrong + q.answerText).shuffled(r)
        return q.copy(options = opts, answer = opts.indexOf(q.answerText))
    }

    /** 1 star for finishing, 2 from 60% right, 3 from 85%. */
    fun stars(right: Int, total: Int): Int {
        if (total <= 0) return 1
        val p = right.toDouble() / total
        return when {
            p >= 0.85 -> 3
            p >= 0.6 -> 2
            else -> 1
        }
    }

    /** Records every answer, then the stars (best kept) and mastery. */
    fun finish(
        s: LearnState,
        skillId: String,
        results: List<Answered>,
        today: LocalDate,
        now: Long = today.toEpochDay() * DAY_MS,
        catalog: Catalog = Catalog.MATHS,
        /** The format played: a bad Sort or Order level makes the next one plain. */
        format: Format? = null,
    ): LevelResult {
        var st = s
        for (a in results) st = Learner.record(st, a.q, a.correct, a.ms, now, today)
        val main = results.filter { !it.followUp }
        val stars = stars(main.count { it.correct }, main.size)
        val best = maxOf(stars, st.stars[skillId] ?: 0)
        val newly = Learner.isMastered(st, skillId) && skillId !in st.mastered
        st = st.copy(
            stars = st.stars + (skillId to best),
            mastered = if (newly) st.mastered + skillId else st.mastered,
            plays = st.plays + (skillId to (st.plays[skillId] ?: 0) + 1),
            tiers = catalog.skill(skillId)?.tiers?.takeIf { it > 1 }?.let { max ->
                st.tiers + (skillId to nextTier(tierOf(st, skillId), stars, max))
            } ?: st.tiers,
            easyNext = when {
                format in SPECIAL && stars <= 1 -> st.easyNext + skillId
                format != null && format !in SPECIAL -> st.easyNext - skillId
                else -> st.easyNext
            },
        )
        return LevelResult(st, stars, best, newly, main.firstOrNull { !it.correct }?.q, main.count { it.correct }, main.size)
    }

    /** Pairs: [PAIRS] facts whose card faces (the sum and the answer) are all different. */
    fun pairsFor(s: LearnState, skillId: String, now: Long, r: Random, catalog: Catalog = Catalog.MATHS): List<Question> {
        val out = mutableListOf<Question>()
        val faces = HashSet<String>()
        var tries = 0
        for (q in plan(s, skillId, PAIRS * 6, now, r, catalog)) {
            if (out.size == PAIRS || tries++ > 200) break
            val f = listOf(pairPrompt(q), q.answerText)
            if (f.none { it in faces } && f[0] != f[1]) { out += q; faces += f }
        }
        val skill = catalog.skill(skillId)
        while (out.size < PAIRS && skill != null && tries++ < 400) {
            val q = skill.next(r)
            val f = listOf(pairPrompt(q), q.answerText)
            if (f.none { it in faces } && f[0] != f[1]) { out += q; faces += f }
        }
        return out
    }

    /** The question side of a Pairs card: "7 × 8 = ?" → "7 × 8". */
    fun pairPrompt(q: Question): String = q.prompt.removeSuffix(" = ?").removeSuffix("= ?").trim()

    /** Build: [BUILDS] different two-digit numbers to make from tens and ones (place value). */
    fun buildTargets(s: LearnState, now: Long, r: Random): List<Question> {
        val out = mutableListOf<Question>()
        var tries = 0
        for (q in plan(s, "placeValue", BUILDS * 4, now, r)) {
            if (out.size == BUILDS || tries++ > 100) break
            if (out.none { it.key == q.key }) out += q
        }
        return out
    }

    fun buildTarget(q: Question): Int = q.key.substringAfter(':').toInt()

    const val PAIRS = 6
    const val BUILDS = 5
    /** Questions from the next tier in a level, when there is one. */
    const val STRETCH = 2
    private const val DAY_MS = 86_400_000L
}
