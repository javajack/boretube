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
    /** Boots in a row that followed a short session (see [SafetyGuard.recordBoot]). */
    val shortBoots: Int = 0,
    val approvedFingerprint: String? = null,
)

/**
 * §R safety: modes, the boot-loop guard (3 boots in a row, each after a session
 * under 5 min → safe mode) and the build-fingerprint gate for high-risk
 * watchdog writes. Pure.
 */
object SafetyGuard {
    const val BOOT_LOOP_COUNT = 3

    /** A session that ended sooner than this is part of a loop. */
    const val SHORT_SESSION_MS = 5 * 60_000L

    /**
     * Records one boot (idempotent per [bootId]: BOOT_COMPLETED and
     * LOCKED_BOOT_COMPLETED and a service restart all report the same boot).
     *
     * [prevUpMs] is how long the previous boot stayed up (the TV's own uptime,
     * last checkpointed), or null when unknown. Wall-clock time can't be used: after
     * a power cut the VU3 starts at a fixed date (2026-05-15 12:14) until NTP,
     * so every cold boot looked like the same minute (verified 2026-10-30).
     * Enters safe mode when [BOOT_LOOP_COUNT] boots come in a row, each after
     * a session shorter than [SHORT_SESSION_MS] and none of them a cold boot
     * ([bootReason] is `sys.boot.reason`, null when unknown).
     */
    fun recordBoot(
        s: SafetyState,
        bootId: String,
        now: Long,
        prevUpMs: Long? = null,
        bootReason: String? = null,
    ): SafetyState {
        if (bootId == s.lastBootId) return s
        // A cold boot is power being applied (at the wall, or the plug): a
        // parent switching the TV off and on, never a loop (VU3: `cold` for a
        // power cut, `reboot,shell` for adb, verified 2026-10-30).
        val cold = isColdBoot(bootReason)
        val short = !cold && prevUpMs != null && prevUpMs in 0 until SHORT_SESSION_MS
        val run = if (short) s.shortBoots + 1 else 0
        var next = s.copy(
            boots = (s.boots + now).takeLast(10),
            lastBootId = bootId,
            bootCount = s.bootCount + 1,
            shortBoots = run,
        )
        if (run + 1 >= BOOT_LOOP_COUNT && s.mode != Mode.safe) {
            next = next.copy(mode = Mode.safe, modeReason = "boot loop: ${run + 1} boots, each within 5 min")
        }
        return next
    }

    /** `sys.boot.reason` says power was just applied. */
    fun isColdBoot(reason: String?): Boolean =
        reason != null && reason.substringBefore(',').trim().equals("cold", ignoreCase = true)

    fun setMode(s: SafetyState, mode: Mode, reason: String): SafetyState {
        // Leaving safe mode by hand forgets the boot burst so it doesn't re-trip at once.
        val leaving = s.mode == Mode.safe && mode != Mode.safe
        return s.copy(
            mode = mode,
            modeReason = reason,
            boots = if (leaving) emptyList() else s.boots,
            shortBoots = if (leaving) 0 else s.shortBoots,
        )
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
