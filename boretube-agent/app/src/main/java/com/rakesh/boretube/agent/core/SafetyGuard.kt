package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable

enum class Mode { normal, paused, safe;
    companion object {
        fun parse(s: String?): Mode? = values().firstOrNull { it.name == s }
    }
}

enum class Risk { low, high }

/** Persisted safety state. */
@Serializable
data class SafetyState(
    val mode: Mode = Mode.normal,
    val modeReason: String = "",
    /** Wall-clock times of recent boots (newest last). */
    val boots: List<Long> = emptyList(),
    val lastBootId: String = "",
    val bootCount: Int = 0,
    val approvedFingerprint: String? = null,
)

/**
 * §R safety: modes, the boot-loop guard (3 boots within 15 min → safe mode) and
 * the build-fingerprint gate for high-risk watchdog writes. Pure.
 */
object SafetyGuard {
    const val BOOT_LOOP_COUNT = 3
    const val BOOT_LOOP_WINDOW_MS = 15 * 60_000L

    /**
     * Records one boot (idempotent per [bootId]: BOOT_COMPLETED and
     * LOCKED_BOOT_COMPLETED and a service restart all report the same boot).
     * Enters safe mode when [BOOT_LOOP_COUNT] boots fall within the window.
     */
    fun recordBoot(s: SafetyState, bootId: String, now: Long): SafetyState {
        if (bootId == s.lastBootId) return s
        val boots = (s.boots + now).filter { now - it < BOOT_LOOP_WINDOW_MS }.takeLast(10)
        var next = s.copy(boots = boots, lastBootId = bootId, bootCount = s.bootCount + 1)
        if (boots.size >= BOOT_LOOP_COUNT && s.mode != Mode.safe) {
            next = next.copy(mode = Mode.safe, modeReason = "boot loop: ${boots.size} boots in 15 min")
        }
        return next
    }

    fun setMode(s: SafetyState, mode: Mode, reason: String): SafetyState {
        // Leaving safe mode by hand forgets the boot burst so it doesn't re-trip at once.
        val boots = if (s.mode == Mode.safe && mode != Mode.safe) emptyList() else s.boots
        return s.copy(mode = mode, modeReason = reason, boots = boots)
    }

    fun approveBuild(s: SafetyState, fingerprint: String): SafetyState = s.copy(approvedFingerprint = fingerprint)

    fun buildApproved(s: SafetyState, current: String?): Boolean =
        current != null && current.isNotEmpty() && s.approvedFingerprint == current

    /** Reported as `buildChangedSinceApproval`: true also when never approved. */
    fun buildChangedSinceApproval(s: SafetyState, current: String?): Boolean = !buildApproved(s, current)

    /** Rules are enforced only in normal mode. */
    fun canEnforce(s: SafetyState): Boolean = s.mode == Mode.normal

    /**
     * Watchdog writes: none in paused/safe. Low-risk ops run on any build;
     * high-risk ops (cleanup re-apply, launcher fix) only on an approved build.
     */
    fun canWrite(s: SafetyState, risk: Risk, currentFingerprint: String?): Boolean = when {
        s.mode != Mode.normal -> false
        risk == Risk.low -> true
        else -> buildApproved(s, currentFingerprint)
    }
}
