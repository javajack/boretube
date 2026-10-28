package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable

/** An extra journal step the phone can pass in (its own ADB journal) for undoBoretube. */
@Serializable
data class ExternalStep(val op: String, val target: String, val ok: Boolean = true)

@Serializable
data class RestorePlan(val target: String, val steps: List<PlannedOp>, val notes: List<String>)

/**
 * §R restore planner (pure). Lists exact steps first; the executor journals each.
 * Never plans a write to a never-touch package. Removing the agent is the last
 * step and is left to the phone (it runs `pm uninstall com.rakesh.boretube.agent`
 * over its own ADB), so the agent can answer and journal before it disappears.
 */
object RestorePlanner {
    const val UNDO = "undoBoretube"
    const val STOCK = "stock"

    private fun enable(pkg: String, why: String) =
        PlannedOp("enableApp", pkg, TvShell.enableCommand(pkg, true), Risk.low, TvShell.enableCommand(pkg, false), why)

    private fun installExisting(pkg: String, why: String) =
        PlannedOp("installExisting", pkg, TvShell.installExistingCommand(pkg), Risk.low, TvShell.removeForUserCommand(pkg), why)

    private val removeAgent = PlannedOp(
        "removeAgent", TvShell.AGENT_PACKAGE, "pm uninstall ${TvShell.AGENT_PACKAGE}", Risk.low,
        why = "run by the phone over ADB after this restore",
    )

    /** Brings [pkg] back to enabled-for-user-0, if it isn't. */
    private fun bringBack(pkg: String, snap: PackageSnapshot, why: String): PlannedOp? = when (snap.state(pkg)) {
        AppState.disabled -> enable(pkg, why)
        AppState.notInstalled -> installExisting(pkg, why)
        else -> null
    }

    fun undoBoretube(
        profile: DeviceProfile?,
        journal: List<JournalEntry>,
        external: List<ExternalStep>,
        snap: PackageSnapshot,
    ): RestorePlan {
        val guard = PackageGuard(profile)
        val notes = mutableListOf<String>()
        val writes = journal.filter { it.ok }.map { ExternalStep(it.op, it.target) } + external.filter { it.ok }
        val steps = mutableListOf<PlannedOp>()
        val seen = mutableSetOf<String>()
        for (w in writes.asReversed()) {
            val t = w.target
            if (t in seen || !TvShell.isValidPackage(t)) continue
            val undoable = w.op in setOf("disableApp", "applyCleanup", "stockYouTubeOff")
            if (!undoable) continue
            seen += t
            if (guard.isProtected(t)) { notes += "$t is never-touch; skipped"; continue }
            bringBack(t, snap, "undo ${w.op}")?.let { steps += it }
        }
        if (journal.any { it.ok && it.op == "speechRollback" }) {
            notes += "speech rollback is not undone: Play will update speech services by itself"
        }
        steps += removeAgent
        return RestorePlan(UNDO, steps, notes)
    }

    fun backToStock(
        profile: DeviceProfile,
        snap: PackageSnapshot,
        launcher: LauncherHealth?,
        alsoRemoveLauncherHelper: Boolean,
    ): RestorePlan {
        val guard = PackageGuard(profile)
        val notes = mutableListOf<String>()
        val steps = mutableListOf<PlannedOp>()
        val targets = Watchdog.cleanupTargets(profile) +
            listOfNotNull(profile.stockYouTube?.pkg) + (profile.stockYouTube?.companions ?: emptyList())
        for (pkg in targets.distinct()) {
            if (guard.isProtected(pkg)) { notes += "$pkg is never-touch; skipped"; continue }
            bringBack(pkg, snap, "back to stock")?.let { steps += it }
        }
        notes += "speech services: no action; Play updates them"
        val ls = profile.launcher
        if (alsoRemoveLauncherHelper && ls != null && launcher != null && launcher.helperEnabled) {
            val keep = launcher.a11yServices.filter {
                TvShell.normalizeComponent(it) != TvShell.normalizeComponent(ls.a11yService)
            }
            if (keep.all { TvShell.isValidComponent(it) }) {
                val cmd = if (keep.isEmpty())
                    "settings delete secure enabled_accessibility_services && settings put secure accessibility_enabled 0"
                else "settings put secure enabled_accessibility_services '${keep.joinToString(":")}'"
                steps += PlannedOp(
                    "removeLauncherHelper", ls.a11yService, cmd, Risk.high,
                    undo = "settings put secure enabled_accessibility_services '${launcher.rawServices}'",
                    why = "HOME resolves back to ${TvShell.LAUNCHERX}",
                )
            }
        } else if (!alsoRemoveLauncherHelper) {
            notes += "custom launcher left alone"
        }
        steps += removeAgent
        return RestorePlan(STOCK, steps, notes)
    }
}
