package com.rakesh.boretube.learn.core

import kotlin.random.Random

/**
 * A Streak run (spec P2b §2): questions mixed from a land's path, getting
 * harder every [STEP] in a row, until the third miss. Pure.
 */
data class Run(
    val land: String,
    /** Right in a row now. */
    val streak: Int = 0,
    /** The longest streak in this run. */
    val best: Int = 0,
    val misses: Int = 0,
    val tier: Int = 1,
    val right: Int = 0,
    val asked: Int = 0,
) {
    val over: Boolean get() = misses >= Runs.LIVES
    val livesLeft: Int get() = (Runs.LIVES - misses).coerceAtLeast(0)
}

object Runs {
    const val LIVES = 3
    /** Right answers in a row for the next tier. */
    const val STEP = 5
    val MILESTONES = listOf(5, 10, 20, 30, 50, 75, 100)

    /** The run after one answer, and the milestone just reached (null if none). */
    fun answer(run: Run, correct: Boolean): Pair<Run, Int?> {
        if (run.over) return run to null
        if (!correct) {
            return run.copy(streak = 0, misses = run.misses + 1, tier = (run.tier - 1).coerceAtLeast(1), asked = run.asked + 1) to null
        }
        val streak = run.streak + 1
        val tier = if (streak % STEP == 0) (run.tier + 1).coerceAtMost(3) else run.tier
        val next = run.copy(streak = streak, best = maxOf(run.best, streak), tier = tier, right = run.right + 1, asked = run.asked + 1)
        return next to streak.takeIf { it in MILESTONES }
    }

    /** The next question: a skill from [pool] at the run's tier, never [last]'s key. */
    fun next(run: Run, pool: List<SkillSource>, r: Random, last: Question? = null): Question? {
        if (pool.isEmpty()) return null
        repeat(12) {
            val sk = pool.random(r)
            val q = sk.next(r, run.tier.coerceAtMost(sk.tiers), Format.quickfire)
            if (q.key != last?.key && q.order == null) return q
        }
        return pool.random(r).next(r)
    }

    /** Keeps the land's best run. */
    fun finish(s: LearnState, run: Run): LearnState {
        val had = s.bestRuns[run.land] ?: 0
        return if (run.best > had) s.copy(bestRuns = s.bestRuns + (run.land to run.best)) else s
    }

    /** A new best for the land. */
    fun isRecord(s: LearnState, run: Run): Boolean = run.best > (s.bestRuns[run.land] ?: 0) && run.best > 0
}
