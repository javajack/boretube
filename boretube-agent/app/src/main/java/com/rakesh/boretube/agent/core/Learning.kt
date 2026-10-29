package com.rakesh.boretube.agent.core

import com.rakesh.boretube.learn.core.Maths
import kotlinx.serialization.Serializable

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
