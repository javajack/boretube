package com.rakesh.boretube.agent.android

import android.content.Context
import android.media.AudioManager
import android.os.Build
import com.rakesh.boretube.agent.core.SelfAdb
import com.rakesh.boretube.agent.core.SoundPath
import com.rakesh.boretube.agent.core.SoundPolicy
import com.rakesh.boretube.agent.core.TvShell
import com.rakesh.boretube.agent.core.VolumeState

/**
 * Drives STREAM_MUSIC. Primary path: AudioManager.adjustStreamVolume (verified on
 * the VU3: ADJUST_MUTE/UNMUTE are explicit and idempotent, ADJUST_LOWER/RAISE
 * step by one). Runtime self-test: the first adjust is read back (dumpsys audio
 * over self-ADB when available, else AudioManager); if it didn't take effect the
 * agent switches to the ADB key path for good, persisted in [AgentStore.soundPath]
 * and reported in /v1/status `soundPath`.
 */
class SoundController(ctx: Context, private val shell: Shell, private val store: AgentStore) {
    private val am = ctx.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    private val stream = AudioManager.STREAM_MUSIC

    val path: SoundPath get() = store.soundPath

    /** Cheap in-app read (correct on the VU3). */
    fun read(): VolumeState? = try {
        VolumeState(
            level = am.getStreamVolume(stream),
            min = if (Build.VERSION.SDK_INT >= 28) am.getStreamMinVolume(stream) else 0,
            max = am.getStreamMaxVolume(stream),
            muted = am.isStreamMute(stream),
        )
    } catch (_: Exception) {
        null
    }

    /** Panel truth for the self-test: dumpsys over self-ADB, else AudioManager. */
    private fun readTruth(): VolumeState? {
        if (shell.state == SelfAdb.ok) {
            try {
                TvShell.parseVolume(shell.run(TvShell.VOLUME_COMMAND, urgent = true).stdout)?.let { return it }
            } catch (_: Exception) {
            }
        }
        return read()
    }

    private fun selfTest(before: VolumeState?, expect: SoundPolicy.Expect) {
        if (store.soundPath != SoundPath.untested) return
        Thread.sleep(150)
        val verdict = SoundPolicy.verdict(before, readTruth(), expect) ?: return
        // Without self-ADB the read-back is AudioManager's own view; still the
        // best signal available (verified to match the panel on the VU3).
        store.soundPath = verdict
    }

    fun setMuted(muted: Boolean): Boolean {
        if (store.soundPath == SoundPath.adbKeys) return keysSetMuted(muted)
        val before = read()
        am.adjustStreamVolume(stream, if (muted) AudioManager.ADJUST_MUTE else AudioManager.ADJUST_UNMUTE, 0)
        selfTest(before, if (muted) SoundPolicy.Expect.MUTED else SoundPolicy.Expect.UNMUTED)
        if (store.soundPath == SoundPath.adbKeys) return keysSetMuted(muted)
        return read()?.muted == muted
    }

    /** Steps down to [maxLevel]. */
    fun clampTo(maxLevel: Int): Boolean = stepTo(maxLevel)

    fun setPercent(pct: Int): Boolean {
        val v = read() ?: return false
        return stepTo(v.levelForPercent(pct), allowUp = true)
    }

    private fun stepTo(target: Int, allowUp: Boolean = false): Boolean {
        val start = read() ?: return false
        if (start.level == target || (!allowUp && start.level < target)) return true
        if (store.soundPath == SoundPath.adbKeys) return keysStepTo(start, target)
        val down = start.level > target
        val dir = if (down) AudioManager.ADJUST_LOWER else AudioManager.ADJUST_RAISE
        am.adjustStreamVolume(stream, dir, 0)
        if (down) selfTest(start, SoundPolicy.Expect.LOWER)
        if (store.soundPath == SoundPath.adbKeys) return keysStepTo(read() ?: start, target)
        for (i in 0 until 100) {
            val v = read() ?: return false
            if (if (down) v.level <= target else v.level >= target) return true
            am.adjustStreamVolume(stream, dir, 0)
        }
        return false
    }

    // ── ADB key path (tv_ops.dart: the TV only honours key events, mute is a toggle) ──

    private fun keysSetMuted(muted: Boolean): Boolean {
        if (shell.state != SelfAdb.ok) return false
        val parts = TvShell.sections(shell.run(TvShell.setMutedCommand(muted), urgent = true).stdout)
        var after = TvShell.parseVolume(parts.getOrElse(2) { "" })
        if (after != null && after.muted != muted && parts.getOrElse(1) { "" }.contains("sent")) {
            after = TvShell.parseVolume(shell.run(TvShell.LATE_VOLUME_COMMAND, urgent = true).stdout) ?: after
        }
        return after?.muted == muted
    }

    private fun keysStepTo(v: VolumeState, target: Int): Boolean {
        if (shell.state != SelfAdb.ok) return false
        val n = (v.level - target)
        if (n == 0) return true
        val key = if (n > 0) "KEYCODE_VOLUME_DOWN" else "KEYCODE_VOLUME_UP"
        val keys = List(kotlin.math.abs(n).coerceAtMost(100)) { key }
        val parts = TvShell.sections(shell.run(TvShell.keysThenVolumeCommand(keys), urgent = true).stdout)
        val after = TvShell.parseVolume(parts.getOrElse(2) { "" })
        return after != null && (if (n > 0) after.level <= target else after.level >= target)
    }
}
