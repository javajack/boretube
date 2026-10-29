package com.rakesh.boretube.learn.ui.level

import com.rakesh.boretube.learn.core.Format
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Levels
import com.rakesh.boretube.learn.core.Maths
import com.rakesh.boretube.learn.core.Question
import kotlin.random.Random

/** The questions a level plays, in its format (Catch gets three options). Pure: same seed, same level. */
object LevelPlan {
    fun build(state: LearnState, skillId: String, now: Long, random: Random): List<Question> {
        val plan = Levels.plan(state, skillId, Levels.LEVEL_SIZE, now, random)
        return if (Levels.formatFor(skillId) == Format.catch) plan.map { Levels.forCatch(it, random) } else plan
    }

    /** The easier follow-up after a miss, in the same format. */
    fun easier(q: Question, random: Random): Question? {
        val e = Maths.easierThan(q, random) ?: return null
        return if (Levels.formatFor(q.skill) == Format.catch) Levels.forCatch(e, random) else e
    }
}
