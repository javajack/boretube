package com.rakesh.boretube.learn.ui.level

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.rakesh.boretube.learn.core.Answered
import com.rakesh.boretube.learn.core.BrainBreakSession
import com.rakesh.boretube.learn.core.Catalog
import com.rakesh.boretube.learn.core.Format
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Levels
import com.rakesh.boretube.learn.core.QuizScreen
import com.rakesh.boretube.learn.core.Speakable
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds
import com.rakesh.boretube.learn.speech.Speaker
import com.rakesh.boretube.learn.speech.safeSay
import com.rakesh.boretube.learn.ui.LocalUptime
import com.rakesh.boretube.learn.ui.Palette
import com.rakesh.boretube.learn.ui.RemoteKey
import com.rakesh.boretube.learn.ui.remote
import kotlinx.coroutines.delay
import kotlin.random.Random

/**
 * One level of [skillId] in the format its rotation gives this play:
 * Quick-fire and Catch run the brain-break "pass or learn" loop
 * ([QuizLevel]); Pairs and Build have their own boards. Every format
 * reaches the end and hands every answer to [onDone].
 */
@Composable
fun LevelScreen(
    skillId: String,
    state: LearnState,
    settings: LearnSettings,
    sounds: Sounds,
    speaker: Speaker,
    random: Random,
    now: Long = System.currentTimeMillis(),
    catalog: Catalog = Catalog.MATHS,
    onDone: (List<Answered>) -> Unit,
    onLeave: () -> Unit,
) {
    val format = remember(skillId) { Levels.formatFor(skillId, state.plays[skillId] ?: 0, catalog) }
    when (format) {
        Format.pairs -> PairsLevel(skillId, state, sounds, random, now, catalog, onDone, onLeave)
        Format.build -> BuildLevel(state, sounds, speaker, settings, random, now, onDone, onLeave)
        else -> QuizLevel(skillId, format, state, settings, sounds, speaker, random, now, catalog, onDone, onLeave)
    }
}

/** Quick-fire and Catch: questions one by one, a miss gives the learn moment and one easier follow-up. */
@Composable
private fun QuizLevel(
    skillId: String,
    format: Format,
    state: LearnState,
    settings: LearnSettings,
    sounds: Sounds,
    speaker: Speaker,
    random: Random,
    now: Long,
    catalog: Catalog,
    onDone: (List<Answered>) -> Unit,
    onLeave: () -> Unit,
) {
    val plan = remember(skillId) { LevelPlan.build(state, skillId, now, random, catalog, format) }
    if (plan.isEmpty()) {
        LaunchedEffect(Unit) { onLeave() }
        return
    }
    val session = remember(skillId) { BrainBreakSession(plan) { LevelPlan.easier(it, random, catalog, format) } }
    var screen by remember { mutableStateOf(session.screen) }
    var sel by remember { mutableIntStateOf(0) }
    var streak by remember { mutableIntStateOf(0) }
    val uptime = LocalUptime.current
    var shownAt by remember { mutableLongStateOf(uptime()) }
    var leaving by remember { mutableStateOf(false) }
    var leaveSel by remember { mutableIntStateOf(0) }
    // Hindi text only when the TV has a Hindi voice; otherwise the English words.
    val hindi = settings.lang != "en" && speaker.hindiReady()
    val autoSpeak = settings.lang != "en" || settings.grade <= 1
    // A steady masher: an OK within MASH_MS of the last one, with no arrow
    // between, is ignored on questions and the learn moment.
    var lastOk by remember { mutableLongStateOf(Long.MIN_VALUE / 2) }
    var arrowed by remember { mutableStateOf(false) }

    fun speak(s: QuizScreen) {
        val text = when (s) {
            is QuizScreen.Ask -> if (hindi) s.q.spokenHi ?: s.q.spoken else s.q.spoken
            is QuizScreen.Learn -> if (hindi) Speakable.of(s.q.fact, true) else Speakable.of(s.q.explain, false)
            else -> return
        }
        speaker.safeSay(text, hindi)
    }

    fun show(next: QuizScreen) {
        screen = next
        sel = 0
        shownAt = uptime()
    }

    fun answer(choice: Int) {
        val ask = screen as? QuizScreen.Ask ?: return
        val next = session.answer(choice, uptime() - shownAt)
        if (next is QuizScreen.Right) {
            streak++
            if (format == Format.catch) sounds.play(Sfx.catch_right)
            if (ask.followUp) sounds.play(Sfx.followup_win) else sounds.right(streak)
        } else {
            streak = 0
            sounds.play(if (format == Format.catch) Sfx.catch_miss else Sfx.miss)
        }
        show(next)
    }

    // What each new screen does by itself.
    LaunchedEffect(screen) {
        when (val s = screen) {
            is QuizScreen.Ask -> {
                sounds.play(if (format == Format.catch) Sfx.catch_drop else Sfx.q_show)
                if (autoSpeak) speak(s)
            }
            is QuizScreen.Right -> {
                delay(RIGHT_MS)
                if (screen === s) show(session.next())
            }
            is QuizScreen.Learn -> {
                delay(LEARN_SOUND_DELAY_MS)
                sounds.play(Sfx.learn_open)
                if (autoSpeak) speak(s)
            }
            is QuizScreen.Done -> onDone(session.results)
        }
    }

    val ground = if (format == Format.catch && screen !is QuizScreen.Learn) Palette.bazaar else Palette.canvas
    Box(
        Modifier
            .fillMaxSize()
            .background(ground)
            .remote(screen to leaving) { key ->
                if (leaving) {
                    when (key) {
                        RemoteKey.Left, RemoteKey.Right -> { leaveSel = 1 - leaveSel; sounds.tick(Sfx.focus_bazaar) }
                        RemoteKey.Ok -> if (leaveSel == 0) { leaving = false; sounds.play(Sfx.select) } else { sounds.play(Sfx.back); onLeave() }
                        RemoteKey.Back -> leaving = false
                        else -> return@remote false
                    }
                    return@remote true
                }
                when (key) {
                    RemoteKey.Back -> { leaving = true; leaveSel = 0; sounds.play(Sfx.back) }
                    RemoteKey.Left, RemoteKey.Right -> {
                        arrowed = true
                        val ask = screen as? QuizScreen.Ask ?: return@remote true
                        val n = (sel + if (key == RemoteKey.Left) -1 else 1).coerceIn(0, ask.q.options.lastIndex)
                        if (n != sel) {
                            sel = n
                            sounds.tick(if (format == Format.catch) Sfx.catch_move else Sfx.focus_bazaar)
                        }
                    }
                    RemoteKey.Up -> speak(screen)
                    RemoteKey.Ok -> {
                        val t = uptime()
                        val mashed = !arrowed && t - lastOk < MASH_MS
                        lastOk = t
                        arrowed = false
                        if (!mashed) when (screen) {
                            is QuizScreen.Ask -> answer(sel)
                            is QuizScreen.Learn -> show(session.next())
                            // "Yes!" moves on by itself.
                            else -> {}
                        }
                    }
                    else -> return@remote false
                }
                true
            },
    ) {
        when (val s = screen) {
            is QuizScreen.Ask -> if (format == Format.catch) CatchBody(s.q, s.index, s.of, s.followUp, sel, null)
                else QuickFireBody(s.q, s.index, s.of, s.followUp, sel, null, voice = true)
            is QuizScreen.Right -> if (format == Format.catch) CatchBody(s.q, s.index, s.of, false, s.q.answer, s.q.answer)
                else QuickFireBody(s.q, s.index, s.of, false, s.q.answer, s.q.answer, voice = true)
            is QuizScreen.Learn -> LearnMoment(s.q, s.picked)
            is QuizScreen.Done -> {}
        }
        if (leaving) LeaveSheet(leaveSel)
    }
}

/** OKs closer together than this, with no arrow between, are mashing. */
const val MASH_MS = 1_000L

/** How long the "Yes!" lingers before the next question. */
const val RIGHT_MS = 900L
private const val LEARN_SOUND_DELAY_MS = 260L
