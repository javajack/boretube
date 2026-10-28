package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable

@Serializable
data class PlannedOp(
    /** stockYouTubeOff | disableApp | speechRollback | applyCleanup | fixLauncher | enableApp | stockYouTubeOn | removeLauncherHelper | removeAgent */
    val op: String,
    val target: String,
    val command: String,
    val risk: Risk,
    val undo: String? = null,
    val why: String = "",
)

@Serializable
data class WatchdogPlan(
    val ops: List<PlannedOp>,
    /** High-risk ops held until the parent approves this build. */
    val pending: List<PlannedOp>,
    val notes: List<String>,
)

data class WatchdogInput(
    val profile: DeviceProfile,
    val snapshot: PackageSnapshot,
    val tts: PackageVersion?,
    val launcher: LauncherHealth?,
    /** rules.stockYouTubeAllowed, or an active allowApp override for the stock YouTube package. */
    val stockYouTubeAllowed: Boolean,
    /** Cleanup/extras packages the watchdog keeps disabled (see [Watchdog.keepDisabled]). */
    val keepDisabled: Set<String>,
    val safety: SafetyState,
    val fingerprint: String?,
)

/**
 * Maintenance watchdog planner (pure): profile + observed package states →
 * planned ops. Low-risk ops (stock YouTube removal, speech rollback) run on any
 * build; cleanup re-apply and the launcher fix wait for an approved build
 * fingerprint. Never-touch packages are never planned (the speech rollback of
 * com.google.android.tts is the one allowed write to a protected package, as in
 * tv_ops.dart). Paused/safe modes plan nothing.
 */
object Watchdog {
    fun cleanupTargets(profile: DeviceProfile): List<String> =
        (profile.cleanup.map { it.pkg } + profile.extras.map { it.pkg }).distinct()

    /** profile.keepDisabled, else the captured set, else what is disabled right now. */
    fun keepDisabled(profile: DeviceProfile, captured: Set<String>?, snapshot: PackageSnapshot?): Set<String>? {
        profile.keepDisabled?.let { return it.toSet() }
        captured?.let { return it }
        snapshot ?: return null
        return cleanupTargets(profile).filter {
            val st = snapshot.state(it)
            st == AppState.disabled || st == AppState.notInstalled
        }.toSet()
    }

    fun plan(input: WatchdogInput): WatchdogPlan {
        val notes = mutableListOf<String>()
        if (input.safety.mode != Mode.normal) {
            return WatchdogPlan(emptyList(), emptyList(), listOf("mode ${input.safety.mode}: no watchdog writes"))
        }
        val guard = PackageGuard(input.profile)
        val p = input.profile
        val snap = input.snapshot
        val all = mutableListOf<PlannedOp>()

        // 1. Stock YouTube watchdog (low risk).
        val yt = p.stockYouTube
        if (yt != null) {
            if (input.stockYouTubeAllowed) {
                notes += "stock YouTube allowed by rules"
            } else if (guard.isProtected(yt.pkg)) {
                notes += "stock YouTube ${yt.pkg} is never-touch; skipped"
            } else {
                val st = snap.state(yt.pkg)
                if (st == AppState.enabled || st == AppState.disabled) {
                    all += PlannedOp(
                        "stockYouTubeOff", yt.pkg, TvShell.removeForUserCommand(yt.pkg), Risk.low,
                        undo = TvShell.installExistingCommand(yt.pkg), why = "stock YouTube came back ($st)",
                    )
                }
                for (c in yt.companions) {
                    if (guard.isProtected(c)) { notes += "companion $c is never-touch; skipped"; continue }
                    if (snap.state(c) == AppState.enabled) {
                        all += PlannedOp(
                            "disableApp", c, TvShell.enableCommand(c, false), Risk.low,
                            undo = TvShell.enableCommand(c, true), why = "stock YouTube companion",
                        )
                    }
                }
            }
        }

        // 2. Speech rollback (low risk; the only write allowed on the protected tts package).
        val good = p.knownGood[TvShell.TTS_PACKAGE]
        if (good != null) {
            val d = TvShell.decideSpeechRollback(input.tts, good)
            if (d.needed) {
                all += PlannedOp("speechRollback", TvShell.TTS_PACKAGE, TvShell.SPEECH_ROLLBACK_COMMAND, Risk.low, why = d.reason)
            } else {
                notes += "speech: ${d.reason}"
            }
        }

        // 3. Cleanup re-apply (high risk: OTA-gated).
        for (pkg in cleanupTargets(p)) {
            if (pkg !in input.keepDisabled) continue
            if (guard.isProtected(pkg)) { notes += "cleanup $pkg is never-touch; skipped"; continue }
            if (snap.state(pkg) == AppState.enabled) {
                all += PlannedOp(
                    "applyCleanup", pkg, TvShell.enableCommand(pkg, false), Risk.high,
                    undo = TvShell.enableCommand(pkg, true), why = "cleanup package was re-enabled",
                )
            }
        }

        // 4. Launcher health (high risk: OTA-gated settings write).
        val lh = input.launcher
        val ls = p.launcher
        if (lh != null && ls != null && ls.a11yService.isNotEmpty() && !lh.ok) {
            val fix = fixLauncherOp(lh, ls)
            if (fix != null) all += fix else notes += "launcher: a11y list has an invalid entry"
        }

        val allowed = all.filter { SafetyGuard.canWrite(input.safety, it.risk, input.fingerprint) }
        val pending = all - allowed.toSet()
        if (pending.isNotEmpty()) notes += "build ${input.fingerprint} not approved: ${pending.size} op(s) pending"
        return WatchdogPlan(allowed, pending, notes)
    }

    fun fixLauncherOp(h: LauncherHealth, spec: LauncherSpec): PlannedOp? {
        val list = h.a11yServices + if (h.helperEnabled) emptyList() else listOf(spec.a11yService)
        if (list.any { !TvShell.isValidComponent(it) }) return null
        val value = list.joinToString(":")
        val undo = if (h.rawServices.isEmpty()) "settings delete secure enabled_accessibility_services"
        else "settings put secure enabled_accessibility_services '${h.rawServices}'"
        return PlannedOp(
            "fixLauncher", spec.a11yService,
            "settings put secure enabled_accessibility_services '$value' && settings put secure accessibility_enabled 1",
            Risk.high, undo = undo, why = "Home helper not enabled",
        )
    }
}

/** Reads the TV state the planners need, through a [ShellPort]. */
object TvReader {
    fun snapshot(sh: ShellPort): PackageSnapshot = PackageSnapshot.parse(sh.run(PackageSnapshot.COMMAND).stdout)
    fun tts(sh: ShellPort): PackageVersion? =
        TvShell.parsePackageVersion(sh.run(TvShell.packageVersionCommand(TvShell.TTS_PACKAGE)).stdout)
    fun launcher(sh: ShellPort, spec: LauncherSpec?): LauncherHealth =
        TvShell.parseLauncherHealth(sh.run(TvShell.LAUNCHER_COMMAND).stdout, spec)
    fun fingerprint(sh: ShellPort): String? = sh.run(TvShell.FINGERPRINT_COMMAND).stdout.trim().ifEmpty { null }
}

/**
 * Runs planned ops one by one, re-reads to verify, and journals every step.
 * Refuses (journals ok=false) any op on a never-touch package except the speech
 * rollback, and any op on a stop/never-touch set the plan should never contain.
 */
class OpExecutor(
    private val sh: ShellPort,
    private val profile: DeviceProfile?,
    private val journal: Journal,
    private val clock: () -> Long,
) {
    private val guard = PackageGuard(profile)

    fun execute(ops: List<PlannedOp>, source: String): List<JournalEntry> {
        val out = mutableListOf<JournalEntry>()
        for (op in ops) out += executeOne(op, source)
        return out
    }

    private fun record(op: PlannedOp, before: String, after: String, ok: Boolean, source: String): JournalEntry {
        val e = JournalEntry(clock(), op.op, op.target, before, after, ok, source, op.undo)
        journal.add(e)
        return e
    }

    private fun packageOp(op: String) = op in setOf(
        "stockYouTubeOff", "stockYouTubeOn", "installExisting", "disableApp", "enableApp", "applyCleanup", "undoCleanup",
    )

    fun executeOne(op: PlannedOp, source: String): JournalEntry {
        if (packageOp(op.op) && (!TvShell.isValidPackage(op.target) || guard.isProtected(op.target))) {
            return record(op, "", "refused: protected package", false, source)
        }
        if (op.op == "removeAgent") {
            return record(op, "", "left to the phone (pm uninstall ${TvShell.AGENT_PACKAGE})", true, source)
        }
        return try {
            when (op.op) {
                "speechRollback" -> {
                    val before = TvReader.tts(sh)
                    val r = sh.run(op.command)
                    val after = TvReader.tts(sh)
                    record(op, before?.versionName ?: "?", after?.versionName ?: "?",
                        r.ok && after != null && !after.updatedSystemApp, source)
                }
                "fixLauncher", "removeLauncherHelper" -> {
                    val spec = profile?.launcher
                    val before = TvReader.launcher(sh, spec)
                    val r = sh.run(op.command)
                    val after = TvReader.launcher(sh, spec)
                    val ok = if (op.op == "fixLauncher") r.ok && after.helperEnabled && after.a11yEnabled
                    else r.ok && !after.helperEnabled
                    record(op, launcherDesc(before), launcherDesc(after), ok, source)
                }
                else -> {
                    val before = TvReader.snapshot(sh).state(op.target)
                    val r = sh.run(op.command)
                    val after = TvReader.snapshot(sh).state(op.target)
                    val ok = r.ok && when (op.op) {
                        "stockYouTubeOff" -> after == AppState.notInstalled || after == AppState.absent
                        "stockYouTubeOn", "installExisting" -> after == AppState.enabled || after == AppState.disabled
                        "disableApp", "applyCleanup" -> after == AppState.disabled
                        "enableApp", "undoCleanup" -> after == AppState.enabled
                        else -> true
                    }
                    record(op, before.name, after.name, ok, source)
                }
            }
        } catch (e: Exception) {
            record(op, "", "error: ${e.message}", false, source)
        }
    }

    private fun launcherDesc(h: LauncherHealth) = "home=${h.homeComponent} helper=${h.helperEnabled} a11y=${h.a11yEnabled}"
}
