package com.rakesh.boretube.learn.speech

/** Reads text aloud. Implementations must never throw into the UI; callers still wrap them. */
interface Speaker {
    fun say(text: String, hindi: Boolean)
    fun stop()

    /** A Hindi voice is installed (otherwise Hindi text would come out garbled). */
    fun hindiReady(): Boolean = true

    object Silent : Speaker {
        override fun say(text: String, hindi: Boolean) {}
        override fun stop() {}
    }
}

/** Speaks without ever breaking the level (no TTS engine, no Hindi voice…). */
fun Speaker.safeSay(text: String, hindi: Boolean) {
    runCatching { say(text, hindi) }
}
