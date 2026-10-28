package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable

/**
 * Break and Mute-for-N state, persisted so it survives agent and TV restarts.
 *
 * - A **break** keeps the TV closed (apps sent Home) and muted until [breakEndsAt].
 * - **Mute-for** keeps the TV muted until [muteEndsAt].
 * - [mutedByAgent] latches when the agent enforced a mute for any reason. When
 *   no reason is left (break/muteFor/override expired, rule removed) the agent
 *   unmutes **once** and clears the latch, so it never unmutes a TV it didn't mute.
 */
@Serializable
data class BreakState(
    val breakEndsAt: Long? = null,
    val muteEndsAt: Long? = null,
    val mutedByAgent: Boolean = false,
) {
    fun breakActive(now: Long) = breakEndsAt != null && now < breakEndsAt
    fun muteForActive(now: Long) = muteEndsAt != null && now < muteEndsAt

    fun startBreak(now: Long, minutes: Int): BreakState =
        copy(breakEndsAt = now + minutes.coerceIn(1, 24 * 60) * 60_000L)

    fun startMuteFor(now: Long, minutes: Int): BreakState =
        copy(muteEndsAt = now + minutes.coerceIn(1, 24 * 60) * 60_000L)

    fun endBreak(): BreakState = copy(breakEndsAt = null)

    /** `restore`: ends breaks and timed mutes (the caller unmutes). */
    fun restore(): BreakState = BreakState()

    /** Drops expired timers (keeps the latch so the once-unmute still happens). */
    fun expire(now: Long): BreakState = copy(
        breakEndsAt = breakEndsAt?.takeIf { now < it },
        muteEndsAt = muteEndsAt?.takeIf { now < it },
    )

    fun toJson(): String = AgentJson.encodeToString(serializer(), this)

    companion object {
        fun parse(text: String?): BreakState =
            if (text.isNullOrBlank()) BreakState()
            else try { AgentJson.decodeFromString(serializer(), text) } catch (_: Exception) { BreakState() }
    }
}

/** What the mute latch says to do on this tick. */
data class MuteStep(val state: BreakState, val mute: Boolean, val unmuteOnce: Boolean)

object MuteLatch {
    /**
     * [wantMute]: some active reason wants the TV muted now. Returns the new
     * state, whether to (re-)assert mute, and whether to unmute once now.
     */
    fun step(state: BreakState, now: Long, wantMute: Boolean): MuteStep {
        val s = state.expire(now)
        return when {
            wantMute -> MuteStep(s.copy(mutedByAgent = true), mute = true, unmuteOnce = false)
            s.mutedByAgent -> MuteStep(s.copy(mutedByAgent = false), mute = false, unmuteOnce = true)
            else -> MuteStep(s, mute = false, unmuteOnce = false)
        }
    }
}
