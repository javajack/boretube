package com.rakesh.boretube.learn.sound

/** Records what would have played (tests). */
class RecordingSounds(
    private val enabled: () -> Boolean = { true },
    private val onPlay: (Sfx) -> Unit = {},
) : Sounds {
    val played = mutableListOf<Sfx>()

    override fun play(s: Sfx) {
        if (!enabled()) return
        played += s
        onPlay(s)
    }

    override fun tick(s: Sfx) = play(s)
}
