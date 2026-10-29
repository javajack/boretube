package com.rakesh.boretube.learn.speech

import android.content.Context
import android.speech.tts.TextToSpeech
import android.util.Log
import java.util.Locale

/**
 * Read-aloud with the TV's own text-to-speech (en-IN, or hi-IN when asked and
 * installed; English otherwise). Nothing here throws to the caller.
 */
class TtsSpeaker(ctx: Context) : Speaker {
    @Volatile private var ready = false
    @Volatile var hindiAvailable = false
        private set
    private var pending: Pair<String, Boolean>? = null
    private val tts: TextToSpeech = TextToSpeech(ctx.applicationContext) { status ->
        ready = status == TextToSpeech.SUCCESS
        hindiAvailable = ready && runCatching { tts.isLanguageAvailable(HINDI) >= TextToSpeech.LANG_AVAILABLE }.getOrDefault(false)
        pending?.let { (t, h) -> pending = null; say(t, h) }
    }

    override fun say(text: String, hindi: Boolean) {
        if (!ready) { pending = text to hindi; return }
        try {
            tts.language = if (hindi && hindiAvailable) HINDI else ENGLISH
            tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "learn")
        } catch (e: Exception) {
            Log.w(TAG, "tts failed", e)
        }
    }

    override fun hindiReady(): Boolean = !ready || hindiAvailable

    override fun stop() {
        runCatching { tts.stop() }
    }

    fun shutdown() {
        runCatching { tts.shutdown() }
    }

    companion object {
        private const val TAG = "BoretubeLearnTts"
        private val HINDI = Locale("hi", "IN")
        private val ENGLISH = Locale("en", "IN")
    }
}
