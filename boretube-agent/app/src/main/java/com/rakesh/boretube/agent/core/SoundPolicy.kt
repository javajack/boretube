package com.rakesh.boretube.agent.core

enum class SoundPath { untested, audioManager, adbKeys;
    companion object {
        fun parse(s: String?): SoundPath = values().firstOrNull { it.name == s } ?: untested
    }
}

/**
 * Runtime self-test for the sound path. The agent first tries
 * AudioManager.adjustStreamVolume; after the adjust it reads the panel state
 * back (dumpsys audio over self-ADB when available, else AudioManager). If the
 * state didn't change the way it should, it switches to the ADB key path for
 * good (persisted) and records it in status.
 */
object SoundPolicy {
    /**
     * Verdict after an AudioManager adjust. [expect] tells what the adjust should
     * have done to [before]. Returns the path to keep, or null when the reading
     * can't tell (no reading, or nothing to change).
     */
    fun verdict(before: VolumeState?, after: VolumeState?, expect: Expect): SoundPath? {
        if (after == null) return null
        return when (expect) {
            Expect.MUTED -> if (after.muted) SoundPath.audioManager else SoundPath.adbKeys
            Expect.UNMUTED -> if (!after.muted) SoundPath.audioManager else SoundPath.adbKeys
            Expect.LOWER -> {
                if (before == null || before.level <= before.min) null
                else if (after.level < before.level) SoundPath.audioManager else SoundPath.adbKeys
            }
        }
    }

    enum class Expect { MUTED, UNMUTED, LOWER }

    /** Key presses to step from [v] down to [maxLevel] (capped at 100), as tv_ops volumeStep. */
    fun clampKeys(v: VolumeState, maxLevel: Int): List<String> {
        val n = (v.level - maxLevel).coerceIn(0, 100)
        return List(n) { "KEYCODE_VOLUME_DOWN" }
    }
}
