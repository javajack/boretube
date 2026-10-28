package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable

enum class SelfAdb { ok, needsApproval, unavailable }

/** What the agent can do right now without help. */
data class PermissionState(
    val usageAccess: Boolean,
    val overlay: Boolean,
    val notifications: Boolean,
    /** Notification-listener access (media sessions with duration). Optional: dumpsys is the fallback. */
    val mediaAccess: Boolean = true,
)

@Serializable
data class HealthItem(val id: String, val status: String, val detail: String = "")

/**
 * Self-heal for grants the TV forgets: on the Sony VU3 a reboot resets the
 * GET_USAGE_STATS and SYSTEM_ALERT_WINDOW app-ops to "default". On every service
 * start, every [PERIOD_MS] and before enforcement that needs them, the agent
 * re-grants itself over self-ADB. Pure planner.
 */
object PermissionHeal {
    const val PERIOD_MS = 10 * 60_000L
    /** Minimum gap between two heals triggered by a missing permission. */
    const val RETRY_GAP_MS = 30_000L

    private const val PKG = TvShell.AGENT_PACKAGE

    val USAGE_CMD = "appops set $PKG GET_USAGE_STATS allow"
    val OVERLAY_CMD = "appops set $PKG SYSTEM_ALERT_WINDOW allow"
    val NOTIF_CMD = "pm grant $PKG android.permission.POST_NOTIFICATIONS"
    const val MEDIA_LISTENER = "$PKG/com.rakesh.boretube.agent.android.MediaListenerService"
    val MEDIA_CMD = "cmd notification allow_listener $MEDIA_LISTENER"

    /** All grant commands (also what the phone runs at install). */
    val ALL_COMMANDS = listOf(USAGE_CMD, OVERLAY_CMD, NOTIF_CMD, MEDIA_CMD)

    /**
     * Returns the commands to run now, or empty. [periodic] = service start or the
     * 10-min timer: re-run every grant (harmless). Otherwise only when something is
     * missing and the retry gap has passed. Nothing when self-ADB isn't ok.
     */
    fun plan(p: PermissionState, selfAdb: SelfAdb, lastHealAt: Long?, now: Long, periodic: Boolean): List<String> {
        if (selfAdb != SelfAdb.ok) return emptyList()
        if (periodic) return ALL_COMMANDS
        val missing = mutableListOf<String>()
        if (!p.usageAccess) missing += USAGE_CMD
        if (!p.overlay) missing += OVERLAY_CMD
        if (!p.notifications) missing += NOTIF_CMD
        if (!p.mediaAccess) missing += MEDIA_CMD
        if (missing.isEmpty()) return emptyList()
        if (lastHealAt != null && now - lastHealAt < RETRY_GAP_MS) return emptyList()
        return missing
    }

    /** The phone must re-grant over its own ADB: self-ADB can't. */
    fun phoneMustGrant(p: PermissionState, selfAdb: SelfAdb): Boolean =
        selfAdb != SelfAdb.ok && (!p.usageAccess || !p.overlay)

    /** Limited mode: self-ADB missing, or a permission missing that self-ADB can't fix. */
    fun limitedReasons(p: PermissionState, selfAdb: SelfAdb): List<String> {
        val r = mutableListOf<String>()
        if (selfAdb != SelfAdb.ok) r += "selfAdb ${selfAdb.name}"
        if (!p.usageAccess) r += "usageAccess missing"
        if (!p.overlay) r += "overlay missing"
        return r
    }

    /** `mediaAccess` health: listener (full, with duration), dumpsys fallback, or nothing. */
    fun mediaHealth(p: PermissionState, selfAdb: SelfAdb): HealthItem = when {
        p.mediaAccess -> HealthItem("mediaAccess", "ok", "notification listener: title, position, duration")
        selfAdb == SelfAdb.ok -> HealthItem("mediaAccess", "warn", "listener not allowed; dumpsys fallback (no duration); agent re-grants itself")
        else -> HealthItem("mediaAccess", "warn", "no media access: run `$MEDIA_CMD` over ADB")
    }

    fun health(p: PermissionState, selfAdb: SelfAdb): List<HealthItem> {
        val fixHint = if (selfAdb == SelfAdb.ok) "agent re-grants itself" else "phone must re-grant over ADB"
        return listOf(
            HealthItem(
                "selfAdb", if (selfAdb == SelfAdb.ok) "ok" else "warn",
                when (selfAdb) {
                    SelfAdb.ok -> "connected to localhost:5555"
                    SelfAdb.needsApproval -> "Allow USB debugging prompt on the TV (always allow)"
                    SelfAdb.unavailable -> "localhost:5555 not reachable"
                },
            ),
            HealthItem("usageAccess", if (p.usageAccess) "ok" else "error", if (p.usageAccess) "" else "GET_USAGE_STATS not allowed; $fixHint"),
            HealthItem("overlay", if (p.overlay) "ok" else "error", if (p.overlay) "" else "SYSTEM_ALERT_WINDOW not allowed; $fixHint"),
            HealthItem("notifications", if (p.notifications) "ok" else "warn", if (p.notifications) "" else "POST_NOTIFICATIONS not granted"),
        )
    }
}
