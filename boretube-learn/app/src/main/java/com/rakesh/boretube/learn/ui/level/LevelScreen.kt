package com.rakesh.boretube.learn.ui.level

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
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
        // Quick-fire, Catch, True or false, Sort and Order share the pass-or-learn loop.
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
    // Order: the tiles placed so far (option indexes), and the last try for the learn moment.
    var placed by remember { mutableStateOf(listOf<Int>()) }
    var tried by remember { mutableStateOf<List<String>?>(null) }
    // Sort: which basket the card went to while the "Yes!" shows.
    var sortedTo by remember { mutableStateOf<Int?>(null) }

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
        if (next is QuizScreen.Ask) { placed = emptyList(); sortedTo = null }
    }

    fun answer(choice: Int) {
        val ask = screen as? QuizScreen.Ask ?: return
        val next = session.answer(choice, uptime() - shownAt)
        if (next is QuizScreen.Right) {
            streak++
            if (format == Format.catch) sounds.play(Sfx.catch_right)
            if (ask.followUp) sounds.play(Sfx.followup_win) else sounds.right(streak)
            if (streak in COMBO_STEPS) sounds.play(Sfx.combo)
        } else {
            streak = 0
            sounds.play(if (format == Format.catch) Sfx.catch_miss else Sfx.miss)
        }
        show(next)
    }

    /** Order: OK places the picked tile; the last one checks the whole order. */
    fun place() {
        val ask = screen as? QuizScreen.Ask ?: return
        val left = ask.q.options.indices.filter { it !in placed }
        val i = left.getOrNull(sel) ?: return
        placed = placed + i
        sounds.play(Sfx.order(placed.size))
        sel = 0
        if (placed.size == ask.q.options.size) {
            val mine = placed.map { ask.q.options[it] }
            tried = mine
            val ok = mine == ask.q.order
            val keep = placed
            answer(if (ok) ask.q.answer else (ask.q.answer + 1) % ask.q.options.size)
            if (ok) placed = keep
        }
    }

    // Sort: the cards each basket holds so far (right answers only).
    val counts = session.results.filter { it.correct }.let { r -> r.count { it.picked == 0 } to r.count { it.picked == 1 } }

    // What each new screen does by itself.
    LaunchedEffect(screen) {
        when (val s = screen) {
            is QuizScreen.Ask -> {
                sounds.play(
                    when (format) {
                        Format.catch -> Sfx.catch_drop
                        Format.truefalse -> Sfx.tf_flip
                        else -> Sfx.q_show
                    },
                )
                if (autoSpeak) speak(s)
            }
            is QuizScreen.Right -> {
                delay(if (format == Format.order) ORDER_RIGHT_MS else RIGHT_MS)
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
                    RemoteKey.Back -> if (format == Format.order && placed.isNotEmpty() && screen is QuizScreen.Ask) {
                        placed = placed.dropLast(1)
                        sel = 0
                        sounds.play(Sfx.build_undo)
                    } else { leaving = true; leaveSel = 0; sounds.play(Sfx.back) }
                    RemoteKey.Left, RemoteKey.Right -> {
                        arrowed = true
                        val ask = screen as? QuizScreen.Ask ?: return@remote true
                        if (format == Format.sort) {
                            // The card goes straight into a basket: ◀ left, ▶ right.
                            val side = if (key == RemoteKey.Left) 0 else 1
                            sounds.play(if (side == 0) Sfx.sort_left else Sfx.sort_right)
                            sortedTo = side
                            answer(side)
                            if (screen is QuizScreen.Right) sortedTo = side
                            return@remote true
                        }
                        val last = if (format == Format.order) ask.q.options.size - placed.size - 1 else ask.q.options.lastIndex
                        val n = (sel + if (key == RemoteKey.Left) -1 else 1).coerceIn(0, last.coerceAtLeast(0))
                        if (n != sel) {
                            sel = n
                            sounds.tick(if (format == Format.catch) Sfx.catch_move else Sfx.focus_bazaar)
                        }
                    }
                    RemoteKey.Up -> speak(screen)
                    RemoteKey.Ok -> {
                        val t = uptime()
                        // Order is placed with OK after OK: that's play, not mashing.
                        val mashed = format != Format.order && !arrowed && t - lastOk < MASH_MS
                        lastOk = t
                        arrowed = false
                        if (!mashed) when (screen) {
                            is QuizScreen.Ask -> when (format) {
                                Format.order -> place()
                                // Sort answers with the arrows; OK does nothing there.
                                Format.sort -> {}
                                else -> answer(sel)
                            }
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
        CompositionLocalProvider(LocalCombo provides streak) {
            when (val s = screen) {
                is QuizScreen.Ask -> when (format) {
                    Format.catch -> CatchBody(s.q, s.index, s.of, s.followUp, sel, null)
                    Format.truefalse -> TrueFalseBody(s.q, s.index, s.of, s.followUp, sel, null)
                    Format.sort -> SortBody(s.q, s.index, s.of, s.followUp, null, counts)
                    Format.order -> OrderBody(s.q, s.index, s.of, s.followUp, placed, sel, right = false, wrongShake = null)
                    else -> QuickFireBody(s.q, s.index, s.of, s.followUp, sel, null, voice = true)
                }
                is QuizScreen.Right -> when (format) {
                    Format.catch -> CatchBody(s.q, s.index, s.of, false, s.q.answer, s.q.answer)
                    Format.truefalse -> TrueFalseBody(s.q, s.index, s.of, false, s.q.answer, s.q.answer)
                    Format.sort -> SortBody(s.q, s.index, s.of, false, sortedTo ?: s.q.answer, counts)
                    Format.order -> OrderBody(s.q, s.index, s.of, false, s.q.order!!.map { s.q.options.indexOf(it) }, 0, right = true, wrongShake = null)
                    else -> QuickFireBody(s.q, s.index, s.of, false, s.q.answer, s.q.answer, voice = true)
                }
                is QuizScreen.Learn -> LearnMoment(
                    s.q, s.picked,
                    pickedOrder = if (s.q.order != null) tried else null,
                    onAha = { sounds.play(Sfx.aha) },
                )
                is QuizScreen.Done -> {}
            }
        }
        if (leaving) LeaveSheet(leaveSel)
    }
}

/** OKs closer together than this, with no arrow between, are mashing. */
const val MASH_MS = 1_000L

/** How long the "Yes!" lingers before the next question. */
const val RIGHT_MS = 900L
private const val ORDER_RIGHT_MS = 1_300L
private const val LEARN_SOUND_DELAY_MS = 260L
