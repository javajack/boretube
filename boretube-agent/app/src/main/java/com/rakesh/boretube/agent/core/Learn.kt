package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.time.temporal.IsoFields
import kotlin.random.Random

/** `rules.learning` (agent 1.4.0+): brain breaks. Absent = off. */
@Serializable
data class LearningRules(
    val enabled: Boolean = false,
    /** CBSE class: 0 = KG … 7. */
    val grade: Int = 1,
    /** en | hi | enHi (English text, Hindi voice and a Hindi line) */
    val lang: String = "en",
    /** Read questions aloud. */
    val voice: Boolean = true,
    val perBreak: Int = 3,
    /** manual | hopping | every */
    val trigger: String = "manual",
    /** trigger every: minutes of playing video between breaks. */
    val everyMin: Int = 30,
) {
    fun validate() {
        require(grade in 0..Maths.MAX_GRADE) { "learning.grade must be 0..${Maths.MAX_GRADE}" }
        require(lang in LANGS) { "learning.lang must be en|hi|enHi" }
        require(perBreak in 1..5) { "learning.perBreak must be 1..5" }
        require(trigger in TRIGGERS) { "learning.trigger must be manual|hopping|every" }
        require(everyMin in 5..240) { "learning.everyMin must be 5..240" }
    }

    companion object {
        val LANGS = setOf("en", "hi", "enHi")
        val TRIGGERS = setOf("manual", "hopping", "every")
    }
}

/** A missed fact waiting to come back (Leitner box 1..5). */
@Serializable
data class Fact(val key: String, val box: Int = 1, val dueAt: Long)

@Serializable
data class SkillStat(
    /** Right answers (guesses excluded). */
    val right: Int = 0,
    /** Days (ISO) with a right answer, most recent last, at most 5. */
    val days: List<String> = emptyList(),
    val wrongRun: Int = 0,
)

@Serializable
data class WeekLog(
    /** ISO week, e.g. 2026-W44. */
    val week: String = "",
    val breaks: Int = 0,
    val right: Int = 0,
    val learned: Int = 0,
    /** Right answers per skill this week (for "getting stronger"). */
    val skillRight: Map<String, Int> = emptyMap(),
)

/** What the TV remembers about the child: survives restarts (AgentStore). */
@Serializable
data class LearnState(
    /** The class the rung was set for (-1 = never set). */
    val grade: Int = -1,
    val rung: Int = 0,
    val stats: Map<String, SkillStat> = emptyMap(),
    val facts: List<Fact> = emptyList(),
    val week: WeekLog = WeekLog(),
)

/** Spaced repetition, promotion/demotion and the round mix. Pure. */
object Learner {
    private const val DAY = 24 * 60 * 60_000L
    /** Box 1..5 → wait before asking again. */
    val INTERVALS_MS = longArrayOf(10 * 60_000L, DAY, 3 * DAY, 7 * DAY, 21 * DAY)
    const val GUESS_MS = 800L
    const val MAX_FACTS = 200

    fun weekOf(day: LocalDate): String =
        "${day.get(IsoFields.WEEK_BASED_YEAR)}-W${"%02d".format(day.get(IsoFields.WEEK_OF_WEEK_BASED_YEAR))}"

    /** Puts the child on [grade]'s first rung when the parent picks a new class; keeps the facts. */
    fun forGrade(s: LearnState, grade: Int): LearnState =
        if (s.grade == grade) s else s.copy(grade = grade, rung = Maths.firstRung(grade))

    fun isGuess(ms: Long) = ms < GUESS_MS

    fun record(s: LearnState, q: Question, correct: Boolean, ms: Long, now: Long, today: LocalDate): LearnState {
        val guess = isGuess(ms)
        val d = today.toString()
        // Facts: a miss (re)starts at box 1; a real right answer moves it up, past box 5 it graduates.
        val existing = s.facts.firstOrNull { it.key == q.key }
        val facts = when {
            !correct -> s.facts.filter { it.key != q.key } + Fact(q.key, 1, now + INTERVALS_MS[0])
            existing != null && !guess -> {
                val box = existing.box + 1
                if (box > INTERVALS_MS.size) s.facts.filter { it.key != q.key }
                else s.facts.map { if (it.key == q.key) Fact(q.key, box, now + INTERVALS_MS[box - 1]) else it }
            }
            else -> s.facts
        }.takeLast(MAX_FACTS)
        val st = s.stats[q.skill] ?: SkillStat()
        val st2 = when {
            correct && !guess -> st.copy(right = st.right + 1, days = (st.days.filter { it != d } + d).takeLast(5), wrongRun = 0)
            correct -> st
            else -> st.copy(wrongRun = st.wrongRun + 1)
        }
        var rung = s.rung
        var stats = s.stats + (q.skill to st2)
        val cur = Maths.LADDER.getOrNull(rung)
        if (cur != null && cur.id == q.skill && s.grade >= 0) {
            if (st2.right >= PROMOTE_RIGHT && st2.days.size >= PROMOTE_DAYS && rung < Maths.maxRung(s.grade)) {
                rung++
            } else if (st2.wrongRun >= DEMOTE_WRONG && rung > Maths.minRung(s.grade)) {
                rung--
                stats = stats + (q.skill to st2.copy(wrongRun = 0))
            }
        }
        val wk = weekOf(today).let { w -> if (s.week.week == w) s.week else WeekLog(w) }
        val week = if (correct && !guess) wk.copy(right = wk.right + 1, skillRight = wk.skillRight + (q.skill to (wk.skillRight[q.skill] ?: 0) + 1)) else wk
        return s.copy(rung = rung, stats = stats, facts = facts, week = week)
    }

    /** A finished round: one more break this week, [learned] new things. */
    fun roundDone(s: LearnState, learned: Int, today: LocalDate): LearnState {
        val wk = weekOf(today).let { w -> if (s.week.week == w) s.week else WeekLog(w) }
        return s.copy(week = wk.copy(breaks = wk.breaks + 1, learned = wk.learned + learned))
    }

    /** The skill with the most right answers this week, or null. */
    fun stronger(s: LearnState, today: LocalDate): String? =
        s.week.takeIf { it.week == weekOf(today) }?.skillRight?.maxByOrNull { it.value }?.key?.let { Maths.skill(it)?.title }

    /**
     * [n] questions: an easy warm-up from the rung below, then the current
     * skill, then facts due to come back, topped up with the current skill.
     * No key twice in a round.
     */
    fun plan(s: LearnState, n: Int, now: Long, r: Random): List<Question> {
        val rung = s.rung.coerceIn(0, Maths.LADDER.lastIndex)
        val cur = Maths.LADDER[rung]
        val below = Maths.LADDER[(rung - 1).coerceAtLeast(if (s.grade >= 0) Maths.minRung(s.grade) else 0)]
        val out = mutableListOf<Question>()
        fun add(q: Question?) { if (q != null && out.size < n && out.none { it.key == q.key }) out += q }
        fun fresh(sk: Skill): Question? = (1..8).map { sk.next(r) }.firstOrNull { c -> out.none { it.key == c.key } }
        if (n >= 2) add(fresh(below))
        add(fresh(cur))
        for (f in s.facts.filter { it.dueAt <= now }.sortedBy { it.dueAt }) add(Maths.fromKey(f.key, r))
        var guard = 0
        while (out.size < n && guard++ < 20) add(fresh(cur))
        return out
    }

    const val PROMOTE_RIGHT = 3
    const val PROMOTE_DAYS = 2
    const val DEMOTE_WRONG = 3
}

/** One answered question in a round. */
data class Answered(val q: Question, val picked: Int, val correct: Boolean, val ms: Long, val followUp: Boolean)

/** What the quiz window shows. */
sealed class QuizScreen {
    /** [index] of [of] main questions; a follow-up keeps the index of the question it follows. */
    data class Ask(val q: Question, val index: Int, val of: Int, val followUp: Boolean) : QuizScreen()
    data class Right(val q: Question, val index: Int, val of: Int) : QuizScreen()
    data class Learn(val q: Question, val picked: Int, val index: Int, val of: Int) : QuizScreen()
    data class Done(val rows: List<Answered>, val right: Int, val learned: Int) : QuizScreen()
}

/**
 * A brain-break round: Ask → Right → next, or Ask → Learn → an easier
 * follow-up (once) → next. Always reaches Done: there is no way to fail out.
 */
class BrainBreakSession(
    private val questions: List<Question>,
    private val easier: (Question) -> Question?,
) {
    init { require(questions.isNotEmpty()) }

    private var i = 0
    private var inFollowUp = false
    private val answered = mutableListOf<Answered>()

    var screen: QuizScreen = QuizScreen.Ask(questions[0], 0, questions.size, false)
        private set

    val results: List<Answered> get() = answered.toList()

    /** Picks option [choice] on an Ask screen ([ms] since it appeared). Ignored elsewhere. */
    fun answer(choice: Int, ms: Long): QuizScreen {
        val a = screen as? QuizScreen.Ask ?: return screen
        val ok = choice == a.q.answer
        answered += Answered(a.q, choice, ok, ms, a.followUp)
        screen = if (ok) QuizScreen.Right(a.q, a.index, a.of) else QuizScreen.Learn(a.q, choice, a.index, a.of)
        return screen
    }

    /** Leaves a Right/Learn screen. */
    fun next(): QuizScreen {
        when (val s = screen) {
            is QuizScreen.Learn -> {
                if (!inFollowUp) {
                    val f = easier(s.q)
                    if (f != null) {
                        inFollowUp = true
                        screen = QuizScreen.Ask(f, s.index, s.of, true)
                        return screen
                    }
                }
                advance()
            }
            is QuizScreen.Right -> advance()
            else -> {}
        }
        return screen
    }

    private fun advance() {
        inFollowUp = false
        i++
        screen = if (i < questions.size) QuizScreen.Ask(questions[i], i, questions.size, false) else done()
    }

    private fun done(): QuizScreen.Done {
        val main = answered.filter { !it.followUp }
        return QuizScreen.Done(main, main.count { it.correct }, main.count { !it.correct })
    }

    /** "3 questions: 2 right, 1 learned" for the journal. */
    fun summary(): String {
        val main = answered.filter { !it.followUp }
        return "${questions.size} questions: ${main.count { it.correct }} right, ${main.count { !it.correct }} learned"
    }
}

/** Minutes of playing video since the last brain break (trigger `every`). Guard thread only. */
class PlayClock {
    var playedMs = 0L
        private set
    private var last: Long? = null

    /** Adds the time since the previous step while [playing] (a long gap, e.g. a sleeping agent, counts as at most 5 s). */
    fun step(playing: Boolean, nowElapsed: Long): Long {
        val l = last
        last = nowElapsed
        if (playing && l != null) playedMs += (nowElapsed - l).coerceIn(0, MAX_STEP_MS)
        return playedMs
    }

    fun reset() { playedMs = 0 }

    companion object { const val MAX_STEP_MS = 5_000L }
}

/** Whether a brain break may open now. Pure. */
object BrainBreakGate {
    /** Null = go; otherwise why not (journal / action detail). */
    fun refuse(
        learning: LearningRules?,
        mode: Mode,
        breakActive: Boolean,
        cooldownRunning: Boolean,
        showing: Boolean,
        overlayAllowed: Boolean,
    ): String? = when {
        learning == null || !learning.enabled -> "brain breaks are off"
        mode != Mode.normal -> "agent ${mode.name}"
        showing -> "a brain break is already on screen"
        breakActive -> "a break is running"
        cooldownRunning -> "a video cool-down is running"
        !overlayAllowed -> "no overlay permission"
        else -> null
    }
}

/** `status.learning` (1.4.0+). */
@Serializable
data class LearningDoc(
    val enabled: Boolean,
    val showing: Boolean = false,
    val trigger: String = "manual",
    val grade: Int? = null,
    /** The child's current rung (skill title). */
    val skill: String? = null,
    /** ok | noHindi | unavailable | off | starting */
    val voice: String = "off",
    val week: WeekDoc = WeekDoc(),
    /** The skill with the most right answers this week. */
    val stronger: String? = null,
    /** trigger every: minutes of video since the last brain break. */
    val playedMin: Int? = null,
)

@Serializable
data class WeekDoc(val breaks: Int = 0, val right: Int = 0, val learned: Int = 0)
