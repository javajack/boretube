package com.rakesh.boretube.agent.android

import android.content.Context
import android.graphics.PixelFormat
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.tts.TextToSpeech
import android.util.Log
import android.view.WindowManager
import com.rakesh.boretube.learn.core.BrainBreakSession
import com.rakesh.boretube.learn.core.Question
import com.rakesh.boretube.learn.core.QuizScreen
import com.rakesh.boretube.learn.core.Speakable
import java.util.Locale

/**
 * One brain-break round on screen: a focusable full-screen overlay window
 * ([QuizView]) that owns the remote until the round is done, plus read-aloud
 * (Android TextToSpeech). Main thread only; [Host] callbacks arrive on it too.
 * Fails open: if the window can't be added, [Host.closed] reports why and
 * nothing is blocked.
 */
class BrainBreakWindow(private val ctx: Context, private val host: Host) {

    interface Host {
        fun answered(q: Question, correct: Boolean, ms: Long)
        /** The round ended: [done] is null when it was cut short ([why]). */
        fun closed(done: QuizScreen.Done?, summary: String, why: String)
    }

    private val wm = ctx.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private val main = Handler(Looper.getMainLooper())
    private var view: QuizView? = null
    private var session: BrainBreakSession? = null
    private var lang = "en"
    private var voice = false
    private var tts: TextToSpeech? = null
    @Volatile private var ttsReady = false
    /** ok | noHindi | unavailable | starting | off | untested (no round with voice yet). */
    @Volatile var voiceStatus: String = "untested"
        private set
    @Volatile var showing = false
        private set

    fun allowed(): Boolean = Settings.canDrawOverlays(ctx)

    /** Opens the quiz (posted to the main thread). */
    fun open(s: BrainBreakSession, lang: String, voice: Boolean) = main.post {
        if (view != null) return@post
        this.lang = lang
        this.voice = voice
        session = s
        try {
            val v = QuizView(ctx, lang, voiceHint = voice, listener = listener)
            val lp = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                // Focusable on purpose: the quiz owns the remote until the round is done.
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.OPAQUE,
            )
            lp.title = "boretube brain break"
            wm.addView(v, lp)
            v.requestFocus()
            view = v
            showing = true
            v.show(s.screen, emptyList())
            if (voice) startTts() else voiceStatus = "off"
            speakScreen(s.screen)
        } catch (e: Exception) {
            Log.w(TAG, "brain break window failed", e)
            removeNow()
            host.closed(null, s.summary(), "window failed: ${e.javaClass.simpleName}")
        }
    }

    /** Closes the quiz without finishing (phone `endBrainBreak`, agent stop). */
    fun close(why: String) = main.post {
        val s = session ?: return@post
        removeNow()
        host.closed(null, s.summary(), why)
    }

    private val listener: QuizView.Listener = object : QuizView.Listener {
        override fun onPick(choice: Int, ms: Long) {
            val s = session ?: return
            val ask = s.screen as? QuizScreen.Ask ?: return
            val next = s.answer(choice, ms)
            host.answered(ask.q, choice == ask.q.answer, ms)
            render(next)
            if (next is QuizScreen.Right) main.postDelayed(autoNext, RIGHT_MS)
        }

        override fun onNext() {
            main.removeCallbacks(autoNext)
            val s = session ?: return
            if (s.screen is QuizScreen.Done) { finish(); return }
            render(s.next())
        }

        override fun onReplay() {
            session?.screen?.let { speakScreen(it) }
        }
    }

    private val autoNext: Runnable = Runnable { listener.onNext() }

    private var countdown = 0
    private val tick = object : Runnable {
        override fun run() {
            countdown--
            view?.countdown = countdown
            if (countdown <= 0) finish() else main.postDelayed(this, 1_000)
        }
    }

    private fun render(sc: QuizScreen) {
        val s = session ?: return
        view?.show(sc, s.results.filter { !it.followUp }.map { it.correct })
        speakScreen(sc)
        if (sc is QuizScreen.Done) {
            countdown = DONE_SECONDS
            view?.countdown = countdown
            main.removeCallbacks(tick)
            main.postDelayed(tick, 1_000)
        }
    }

    private fun finish() {
        val s = session ?: return
        val done = s.screen as? QuizScreen.Done
        removeNow()
        host.closed(done, s.summary(), "done")
    }

    private fun removeNow() {
        main.removeCallbacks(autoNext)
        main.removeCallbacks(tick)
        tts?.stop()
        val v = view
        view = null
        session = null
        showing = false
        if (v != null) try { wm.removeView(v) } catch (_: Exception) {}
    }

    // ── read aloud ──

    private fun startTts() {
        if (tts != null) return
        voiceStatus = "starting"
        tts = TextToSpeech(ctx.applicationContext) { status ->
            ttsReady = status == TextToSpeech.SUCCESS
            voiceStatus = when {
                !ttsReady -> "unavailable"
                lang != "en" && !hindiAvailable() -> "noHindi"
                else -> "ok"
            }
            main.post { session?.screen?.let { speakScreen(it) } }
        }
    }

    private fun hindiAvailable(): Boolean = try {
        (tts?.isLanguageAvailable(HINDI) ?: TextToSpeech.LANG_NOT_SUPPORTED) >= TextToSpeech.LANG_AVAILABLE
    } catch (_: Exception) {
        false
    }

    private fun speakScreen(sc: QuizScreen) {
        if (!voice || !ttsReady) return
        val hindi = lang != "en" && voiceStatus == "ok"
        val text = when (sc) {
            is QuizScreen.Ask -> if (hindi) sc.q.spokenHi ?: sc.q.spoken else sc.q.spoken
            is QuizScreen.Right -> (if (hindi) "शाबाश! " else "Yes! ") + Speakable.of(sc.q.fact, hindi)
            // The why is English only for now; in Hindi, say the fact.
            is QuizScreen.Learn -> if (hindi) Speakable.of(sc.q.fact, true) else Speakable.of(sc.q.explain, false)
            is QuizScreen.Done -> if (hindi) "बहुत बढ़िया! ब्रेन ब्रेक पूरा हुआ।" else "Brain break done!"
        }
        try {
            tts?.language = if (hindi) HINDI else ENGLISH
            tts?.speak(text, TextToSpeech.QUEUE_FLUSH, null, "bb")
        } catch (e: Exception) {
            Log.w(TAG, "tts failed", e)
        }
    }

    /** Releases read-aloud (agent stop). */
    fun shutdown() = main.post {
        removeNow()
        tts?.shutdown()
        tts = null
        ttsReady = false
    }

    companion object {
        private const val TAG = "BoretubeBrainBreak"
        const val RIGHT_MS = 1_600L
        const val DONE_SECONDS = 5
        private val HINDI = Locale("hi", "IN")
        private val ENGLISH = Locale("en", "IN")
    }
}
