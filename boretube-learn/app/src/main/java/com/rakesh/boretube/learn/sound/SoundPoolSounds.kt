package com.rakesh.boretube.learn.sound

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import android.os.SystemClock

/**
 * Sounds through a [SoundPool]: every file is loaded up front, so a tap
 * sounds at once. Effects play at [VOLUME] so the read-aloud voice stays on
 * top (spec §6: effects sit 6 dB under speech).
 */
class SoundPoolSounds(ctx: Context, private val enabled: () -> Boolean) : Sounds {
    private val pool = SoundPool.Builder()
        .setMaxStreams(6)
        .setAudioAttributes(
            AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_GAME)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build(),
        )
        .build()
    private val ids: Map<Sfx, Int> = Sfx.entries.associateWith { s ->
        val res = ctx.resources.getIdentifier(s.res, "raw", ctx.packageName)
        if (res == 0) 0 else pool.load(ctx, res, 1)
    }
    private val gate = TickGate(TICK_GAP_MS)

    override fun play(s: Sfx) {
        if (!enabled()) return
        val id = ids[s] ?: 0
        if (id != 0) pool.play(id, VOLUME, VOLUME, 1, 0, 1f)
    }

    override fun tick(s: Sfx) {
        if (gate.allow(SystemClock.uptimeMillis())) play(s)
    }

    fun release() = pool.release()

    companion object {
        const val VOLUME = 0.5f
        const val TICK_GAP_MS = 120L
    }
}
