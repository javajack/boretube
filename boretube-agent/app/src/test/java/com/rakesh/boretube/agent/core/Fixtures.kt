package com.rakesh.boretube.agent.core

import java.time.ZoneId
import java.time.ZonedDateTime

object Fixtures {
    val ZONE: ZoneId = ZoneId.of("Asia/Kolkata")

    /** 2026-10-26 is a Monday. */
    fun at(day: Int, hh: Int, mm: Int = 0): ZonedDateTime = ZonedDateTime.of(2026, 10, day, hh, mm, 0, 0, ZONE)

    val profileJson: String by lazy {
        Fixtures::class.java.classLoader!!.getResource("sony-bravia-vu3.json")!!.readText()
    }
    val profile: DeviceProfile by lazy { DeviceProfile.parse(profileJson) }

    /** `dumpsys audio | grep -A8 -- '- STREAM_MUSIC:'` captured on the VU3. */
    fun volumeOut(level: Int, muted: Boolean) = """
        - STREAM_MUSIC:
           Muted: $muted
           Muted Internally: false
           Min: 0
           Max: 100
           streamVolume:$level
           Current: 2 (speaker): $level, 8 (headphone): 25, 400 (hdmi): 25, 40000000 (default): 25
           Devices: speaker(2)
           Volume Group: AUDIO_STREAM_MUSIC
    """.trimIndent()

    fun pmList(vararg pkgs: String) = pkgs.joinToString("\n") { "package:$it" }

    fun snapshot(all: Set<String>, installed: Set<String>, disabled: Set<String> = emptySet()) =
        PackageSnapshot(all, installed, disabled)
}

/**
 * A scripted TV: keeps package states and answers the commands the agent sends,
 * so executors can be tested end to end on the JVM.
 */
class FakeTv(
    states: Map<String, AppState>,
    var ttsVersion: String = "googletts.google-speech-apk_20251028.02_p2.827711934",
    var ttsUpdated: Boolean = false,
    var a11y: String = "com.gathin.tvhome/com.gathin.tvhome.HomeKeyService",
    var a11yEnabled: String = "1",
) : ShellPort {
    val state = states.toMutableMap()
    val commands = mutableListOf<String>()

    override fun run(cmd: String): ShellResult {
        commands += cmd
        if (cmd == PackageSnapshot.COMMAND) {
            val all = state.filterValues { it != AppState.absent }.keys
            val installed = state.filterValues { it == AppState.enabled || it == AppState.disabled }.keys
            val disabled = state.filterValues { it == AppState.disabled }.keys
            return ShellResult(
                listOf(all, installed, disabled).joinToString("\n---\n") { s -> s.joinToString("\n") { "package:$it" } },
            )
        }
        if (cmd == TvShell.packageVersionCommand(TvShell.TTS_PACKAGE)) {
            val flags = if (ttsUpdated) "[ SYSTEM HAS_CODE UPDATED_SYSTEM_APP ]" else "[ SYSTEM HAS_CODE ]"
            return ShellResult("    versionName=$ttsVersion\n    pkgFlags=$flags\n    User 0: ceDataInode=1 installed=true hidden=false\n")
        }
        if (cmd == TvShell.SPEECH_ROLLBACK_COMMAND) {
            ttsUpdated = false
            ttsVersion = "googletts.google-speech-apk_20251028.02_p2.827711934"
            return ShellResult("Success")
        }
        if (cmd == TvShell.LAUNCHER_COMMAND) {
            return ShellResult("priority=0\ncom.google.android.apps.tv.launcherx/.MainActivity\n---\n$a11y\n---\n$a11yEnabled\n")
        }
        if (cmd.startsWith("settings put secure enabled_accessibility_services '")) {
            a11y = cmd.substringAfter("'").substringBefore("'")
            if (cmd.contains("accessibility_enabled 1")) a11yEnabled = "1"
            return ShellResult("")
        }
        if (cmd.startsWith("settings delete secure enabled_accessibility_services")) {
            a11y = "null"
            if (cmd.contains("accessibility_enabled 0")) a11yEnabled = "0"
            return ShellResult("")
        }
        Regex("^pm disable-user --user 0 (\\S+)$").matchEntire(cmd)?.let {
            state[it.groupValues[1]] = AppState.disabled; return ShellResult("disabled")
        }
        Regex("^pm enable (\\S+)$").matchEntire(cmd)?.let {
            state[it.groupValues[1]] = AppState.enabled; return ShellResult("enabled")
        }
        Regex("^pm uninstall -k --user 0 (\\S+)$").matchEntire(cmd)?.let {
            state[it.groupValues[1]] = AppState.notInstalled; return ShellResult("Success")
        }
        Regex("^cmd package install-existing (\\S+)$").matchEntire(cmd)?.let {
            state[it.groupValues[1]] = AppState.enabled; return ShellResult("installed")
        }
        return ShellResult("", "unknown command", 1)
    }
}
