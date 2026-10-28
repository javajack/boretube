package com.rakesh.boretube.agent.android

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.os.Build
import android.os.Process
import com.rakesh.boretube.agent.core.SelfAdb
import com.rakesh.boretube.agent.core.TvShell

/**
 * Foreground app from UsageStatsManager.queryEvents (ACTIVITY_RESUMED), polled
 * at 1 s. No accessibility service (it would break the launcher's Home helper
 * and volume-hold repeat). Falls back to `dumpsys activity activities` over
 * self-ADB when usage access is missing (the VU3 resets it on reboot).
 */
class ForegroundWatcher(private val ctx: Context, private val shell: Shell) {
    private val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
    private val appOps = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager

    @Volatile var foreground: String? = null
        private set
    private var queriedTo = 0L
    private var lastShellRead = 0L

    fun usageAccessAllowed(): Boolean {
        val mode = if (Build.VERSION.SDK_INT >= 29) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Polls; returns the current foreground package (null if unknown). */
    fun poll(now: Long = System.currentTimeMillis()): String? {
        if (usageAccessAllowed()) {
            val from = if (queriedTo == 0L) now - 6 * 3600_000L else queriedTo - 2_000
            try {
                val ev = usm.queryEvents(from, now)
                val e = UsageEvents.Event()
                var latest: String? = null
                while (ev.hasNextEvent()) {
                    ev.getNextEvent(e)
                    if (e.eventType == RESUMED) latest = e.packageName
                }
                queriedTo = now
                if (latest != null) foreground = latest
                if (foreground != null) return foreground
            } catch (_: Exception) {
            }
        }
        // Fallback: dumpsys over self-ADB, at most every 2 s.
        if (shell.state == SelfAdb.ok && now - lastShellRead >= 2_000) {
            lastShellRead = now
            try {
                foreground = TvShell.parseTopResumed(shell.run(TvShell.FOREGROUND_COMMAND, urgent = true).stdout)
            } catch (_: Exception) {
            }
        }
        return foreground
    }

    /** After the agent sent HOME, assume Home until the next event says otherwise. */
    fun assume(pkg: String?) {
        foreground = pkg
    }

    /** True when queryEvents actually returns events (verifies usage access after a re-grant). */
    fun usageEventsWork(now: Long = System.currentTimeMillis()): Boolean = try {
        val ev = usm.queryEvents(now - 24 * 3600_000L, now)
        ev.hasNextEvent()
    } catch (_: Exception) {
        false
    }

    companion object {
        /** UsageEvents.Event.ACTIVITY_RESUMED (== MOVE_TO_FOREGROUND, value 1). */
        private const val RESUMED = 1
    }
}
