package com.rakesh.boretube.learn.ui.level

import com.rakesh.boretube.learn.core.Catalog
import com.rakesh.boretube.learn.core.Format
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Levels
import com.rakesh.boretube.learn.core.Question
import kotlin.random.Random

/** The questions a level plays, in its format (Catch gets three options). Pure: same seed, same level. */
object LevelPlan {
    fun build(
        state: LearnState,
        skillId: String,
        now: Long,
        random: Random,
        catalog: Catalog = Catalog.MATHS,
        format: Format = Levels.formatFor(skillId, state.plays[skillId] ?: 0, catalog),
    ): List<Question> {
        val plan = Levels.plan(state, skillId, Levels.LEVEL_SIZE, now, random, catalog)
        return if (format == Format.catch) plan.map { Levels.forCatch(it, random) } else plan
    }

    /** The easier follow-up after a miss, in the same format. */
    fun easier(q: Question, random: Random, catalog: Catalog = Catalog.MATHS, format: Format = Format.quickfire): Question? {
        val e = catalog.easierThan(q, random) ?: return null
        return if (format == Format.catch) Levels.forCatch(e, random) else e
    }
}
