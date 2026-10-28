package com.rakesh.boretube.agent.core

/**
 * Shell commands and output parsers proven on the Sony BRAVIA VU3 by the
 * phone app (boretube-mobile/lib/ops/tv_ops.dart). Ported faithfully: keep
 * the two in sync. Pure Kotlin, no Android imports.
 */

/** Result of one shell command. */
data class ShellResult(val stdout: String, val stderr: String = "", val exitCode: Int = 0) {
    val ok: Boolean get() = exitCode == 0
}

/** Anything that can run a shell command on the TV (self-ADB, or a fake in tests). */
fun interface ShellPort {
    /** Runs [cmd]. Throws on transport failure. */
    fun run(cmd: String): ShellResult
}

enum class AppState { enabled, disabled, notInstalled, absent }

data class VolumeState(val level: Int, val min: Int, val max: Int, val muted: Boolean) {
    val percent: Int
        get() = if (max <= min) 0 else Math.round((level - min) * 100.0 / (max - min)).toInt()

    /** Level that corresponds to [pct] percent (rounded down so a cap is never exceeded). */
    fun levelForPercent(pct: Int): Int {
        val p = pct.coerceIn(0, 100)
        return min + ((max - min) * p) / 100
    }

    override fun toString(): String = "$level/$max" + if (muted) " muted" else ""
}

data class PackageVersion(
    val versionName: String,
    val updatedSystemApp: Boolean,
    val installedForUser0: Boolean? = null,
)

/** `pm list packages` -u / plain / -d in one read. */
data class PackageSnapshot(
    /** Every package on the system image or installed (`-u`). */
    val all: Set<String>,
    /** Installed for user 0. */
    val installed: Set<String>,
    val disabled: Set<String>,
) {
    fun state(pkg: String): AppState {
        if (pkg !in all && pkg !in installed) return AppState.absent
        if (pkg !in installed) return AppState.notInstalled
        if (pkg in disabled) return AppState.disabled
        return AppState.enabled
    }

    companion object {
        const val COMMAND = "pm list packages -u; echo ---; pm list packages; echo ---; pm list packages -d"

        fun parse(out: String): PackageSnapshot {
            val parts = TvShell.sections(out)
            fun at(i: Int) = if (i < parts.size) TvShell.parsePackageList(parts[i]) else emptySet()
            return PackageSnapshot(all = at(0), installed = at(1), disabled = at(2))
        }
    }
}

data class SpeechDecision(
    val needed: Boolean,
    val reason: String,
    val currentVersion: String? = null,
    val knownGood: String? = null,
) {
    val atKnownGood: Boolean get() = currentVersion != null && currentVersion == knownGood
}

data class LauncherHealth(
    val homeComponent: String?,
    val homeIsLauncher: Boolean,
    val a11yServices: List<String>,
    val helperEnabled: Boolean,
    val a11yEnabled: Boolean,
    val rawServices: String,
) {
    /** Home lands in the launcher directly, or via its a11y helper. */
    val ok: Boolean get() = homeIsLauncher || (helperEnabled && a11yEnabled)
}

object TvShell {
    const val TTS_PACKAGE = "com.google.android.tts"
    const val LAUNCHERX = "com.google.android.apps.tv.launcherx"
    const val AGENT_PACKAGE = "com.rakesh.boretube.agent"

    private val pkgPattern = Regex("^[a-zA-Z0-9_.]+$")
    private val componentPattern = Regex("^[a-zA-Z0-9_.$]+/[a-zA-Z0-9_.$]+$")
    private val sectionSplit = Regex("^---\\s*$", RegexOption.MULTILINE)

    fun isValidPackage(pkg: String): Boolean = pkgPattern.matches(pkg)
    fun isValidComponent(c: String): Boolean = componentPattern.matches(c)

    fun sections(out: String): List<String> = out.split(sectionSplit)

    // ── commands (identical to tv_ops.dart) ──

    const val VOLUME_COMMAND = "dumpsys audio | grep -A8 -- '- STREAM_MUSIC:'"
    const val FOREGROUND_COMMAND = "dumpsys activity activities | grep -m1 topResumedActivity"
    const val LAUNCHER_COMMAND = "cmd package resolve-activity --brief " +
        "-a android.intent.action.MAIN -c android.intent.category.HOME; " +
        "echo ---; settings get secure enabled_accessibility_services; " +
        "echo ---; settings get secure accessibility_enabled"
    const val SETTLE = "sleep 0.15"
    const val FINGERPRINT_COMMAND = "getprop ro.build.fingerprint"

    fun packageVersionCommand(pkg: String) = "dumpsys package ${checkPackage(pkg)}"

    fun enableCommand(pkg: String, on: Boolean) =
        if (on) "pm enable ${checkPackage(pkg)}" else "pm disable-user --user 0 ${checkPackage(pkg)}"

    fun installExistingCommand(pkg: String) = "cmd package install-existing ${checkPackage(pkg)}"
    fun removeForUserCommand(pkg: String) = "pm uninstall -k --user 0 ${checkPackage(pkg)}"
    const val SPEECH_ROLLBACK_COMMAND = "pm uninstall-system-updates $TTS_PACKAGE"

    /** am force-stop then HOME, with pid before/after so it can be verified (tv_ops stopCommand). */
    fun stopCommand(pkg: String, home: Boolean): String {
        checkPackage(pkg)
        return "${if (home) FOREGROUND_COMMAND else "true"}; echo ---; pidof $pkg; " +
            "echo ---; am force-stop $pkg && echo stopped; " +
            (if (home) "input keyevent KEYCODE_HOME && echo home; " else "") +
            "echo ---; pidof $pkg"
    }

    const val HOME_KEY_COMMAND = "input keyevent KEYCODE_HOME"

    /** One round trip: volume --- key presses (+ settle) --- volume. */
    fun keysThenVolumeCommand(keys: List<String>): String =
        "$VOLUME_COMMAND; echo ---; input keyevent ${keys.joinToString(" ")} && $SETTLE && echo sent; " +
            "echo ---; $VOLUME_COMMAND"

    /**
     * Presses mute only if the TV is in the other state (KEYCODE_VOLUME_MUTE is a
     * toggle on this TV). Never toggles blind: an unreadable state sends nothing.
     */
    fun setMutedCommand(muted: Boolean): String =
        "v=\$($VOLUME_COMMAND); echo \"\$v\"; echo ---; " +
            "echo \"\$v\" | grep -q 'Muted: ${!muted}' && " +
            "input keyevent KEYCODE_VOLUME_MUTE && $SETTLE && echo sent; " +
            "echo ---; $VOLUME_COMMAND"

    const val LATE_VOLUME_COMMAND = "sleep 0.3; $VOLUME_COMMAND"

    fun checkPackage(pkg: String): String {
        require(isValidPackage(pkg)) { "invalid package \"$pkg\"" }
        return pkg
    }

    // ── parsers ──

    fun parsePackageList(out: String): Set<String> =
        out.split('\n').map { it.trim() }.filter { it.startsWith("package:") }
            .map { it.substring("package:".length) }.toSet()

    fun parseResolvedComponent(out: String): String? =
        out.split('\n').reversed().map { it.trim() }.firstOrNull { componentPattern.matches(it) }

    /** Expands `pkg/.Cls` to `pkg/pkg.Cls` for comparisons. */
    fun normalizeComponent(c: String): String {
        val i = c.indexOf('/')
        if (i < 0) return c
        val pkg = c.substring(0, i)
        val cls = c.substring(i + 1)
        return if (cls.startsWith(".")) "$pkg/$pkg$cls" else c
    }

    fun parseA11yList(value: String): List<String> {
        val v = value.trim()
        if (v.isEmpty() || v == "null") return emptyList()
        return v.split(':').map { it.trim() }.filter { it.isNotEmpty() }
    }

    fun parseLauncherHealth(out: String, launcher: LauncherSpec?): LauncherHealth {
        val parts = sections(out)
        fun at(i: Int) = if (i < parts.size) parts[i].trim() else ""
        val home = parseResolvedComponent(at(0))
        val raw = if (at(1) == "null") "" else at(1)
        val services = parseA11yList(raw)
        val helper = launcher != null &&
            services.map(::normalizeComponent).contains(normalizeComponent(launcher.a11yService))
        return LauncherHealth(
            homeComponent = home,
            homeIsLauncher = launcher != null && home != null && home.startsWith("${launcher.pkg}/"),
            a11yServices = services,
            helperEnabled = helper,
            a11yEnabled = at(2) == "1",
            rawServices = raw,
        )
    }

    fun parsePackageVersion(out: String): PackageVersion? {
        val name = Regex("versionName=(\\S+)").find(out)?.groupValues?.get(1) ?: return null
        val flags = Regex("pkgFlags=\\[([^\\]]*)\\]").find(out)?.groupValues?.get(1)
        val user0 = Regex("User 0:[^\\n]*installed=(true|false)").find(out)
        return PackageVersion(
            versionName = name,
            updatedSystemApp = flags?.contains("UPDATED_SYSTEM_APP") ?: false,
            installedForUser0 = user0?.groupValues?.get(1)?.let { it == "true" },
        )
    }

    fun decideSpeechRollback(v: PackageVersion?, knownGood: String): SpeechDecision {
        if (v == null) {
            return SpeechDecision(false, "Speech services not found", knownGood = knownGood)
        }
        if (v.versionName == knownGood) {
            return SpeechDecision(false, "Speech services are the known-good build", v.versionName, knownGood)
        }
        if (!v.updatedSystemApp) {
            return SpeechDecision(
                false, "Factory build differs from known-good; nothing to roll back", v.versionName, knownGood,
            )
        }
        return SpeechDecision(
            true, "Updated speech services ${v.versionName} replace the known-good build", v.versionName, knownGood,
        )
    }

    fun parseVolume(out: String): VolumeState? {
        val i = out.indexOf("- STREAM_MUSIC:")
        if (i < 0) return null
        val block = out.substring(i).split(Regex("\\n\\s*\\n")).first()
        fun num(label: String): Int? =
            Regex(Regex.escape(label) + "\\s*(-?\\d+)").find(block)?.groupValues?.get(1)?.toIntOrNull()
        val level = num("streamVolume:") ?: return null
        val muted = Regex("^\\s*Muted:\\s*(true|false)", RegexOption.MULTILINE).find(block)?.groupValues?.get(1)
        return VolumeState(level = level, min = num("Min:") ?: 0, max = num("Max:") ?: 100, muted = muted == "true")
    }

    fun parseTopResumed(out: String): String? =
        Regex("u\\d+ ([a-zA-Z0-9_.]+)/").find(out)?.groupValues?.get(1)
}
