package com.rakesh.boretube.learn.ui.level

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.core.Answered
import com.rakesh.boretube.learn.core.Question
import com.rakesh.boretube.learn.core.Run
import com.rakesh.boretube.learn.core.Runs
import com.rakesh.boretube.learn.core.SkillSource
import com.rakesh.boretube.learn.core.Speakable
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds
import com.rakesh.boretube.learn.speech.Speaker
import com.rakesh.boretube.learn.speech.safeSay
import com.rakesh.boretube.learn.ui.Gap
import com.rakesh.boretube.learn.ui.LocalUptime
import com.rakesh.boretube.learn.ui.Palette
import com.rakesh.boretube.learn.ui.Radii
import com.rakesh.boretube.learn.ui.RemoteKey
import com.rakesh.boretube.learn.ui.Safe
import com.rakesh.boretube.learn.ui.Text
import com.rakesh.boretube.learn.ui.Tubby
import com.rakesh.boretube.learn.ui.TubbyMood
import com.rakesh.boretube.learn.ui.TypeScale
import com.rakesh.boretube.learn.ui.remote
import com.rakesh.boretube.learn.ui.selectedRing
import kotlinx.coroutines.delay
import kotlin.random.Random

private sealed interface RunStep {
    data class Ask(val q: Question) : RunStep
    data class Right(val q: Question) : RunStep
    data class Learn(val q: Question, val picked: Int) : RunStep
}

/**
 * A Streak run (spec P2b §2): questions from the land's path, harder every
 * five in a row, until the third miss. A miss still teaches (the learn
 * moment). Milestones get a flame and a cheer. [onDone] gets the run and
 * every answer (they count for spaced repetition like any other).
 */
@Composable
fun RunScreen(
    land: String,
    landName: String,
    pool: List<SkillSource>,
    settings: LearnSettings,
    sounds: Sounds,
    speaker: Speaker,
    random: Random,
    onDone: (Run, List<Answered>) -> Unit,
    onLeave: () -> Unit,
) {
    var run by remember { mutableStateOf(Run(land)) }
    val answers = remember { mutableListOf<Answered>() }
    var step by remember { mutableStateOf<RunStep?>(Runs.next(run, pool, random)?.let { RunStep.Ask(it) }) }
    var sel by remember { mutableIntStateOf(0) }
    var milestone by remember { mutableStateOf<Int?>(null) }
    val uptime = LocalUptime.current
    var shownAt by remember { mutableLongStateOf(uptime()) }
    var leaving by remember { mutableStateOf(false) }
    var leaveSel by remember { mutableIntStateOf(0) }
    val hindi = settings.lang != "en" && speaker.hindiReady()
    val autoSpeak = settings.lang != "en" || settings.grade <= 1

    fun nextQuestion(after: Question?) {
        if (run.over) { onDone(run, answers.toList()); return }
        step = Runs.next(run, pool, random, after)?.let { RunStep.Ask(it) }
        sel = 0
        shownAt = uptime()
    }

    fun answer(q: Question, choice: Int) {
        val ok = choice == q.answer
        answers += Answered(q, choice, ok, uptime() - shownAt, followUp = false)
        val (next, reached) = Runs.answer(run, ok)
        run = next
        if (ok) {
            sounds.right(run.streak)
            if (reached != null) { milestone = reached; sounds.play(Sfx.run_milestone) }
            step = RunStep.Right(q)
        } else {
            sounds.play(Sfx.miss)
            step = RunStep.Learn(q, choice)
        }
    }

    LaunchedEffect(step) {
        when (val s = step) {
            is RunStep.Ask -> { sounds.play(Sfx.q_show); if (autoSpeak) speaker.safeSay(if (hindi) s.q.spokenHi ?: s.q.spoken else s.q.spoken, hindi) }
            is RunStep.Right -> { delay(if (milestone != null) 1_300L else 650L); milestone = null; if (step === s) nextQuestion(s.q) }
            is RunStep.Learn -> {
                delay(260)
                sounds.play(Sfx.learn_open)
                if (autoSpeak) speaker.safeSay(if (hindi) Speakable.of(s.q.fact, true) else Speakable.of(s.q.explain, false), hindi)
            }
            null -> onLeave()
        }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .remote(step to leaving) { key ->
                if (leaving) {
                    when (key) {
                        RemoteKey.Left, RemoteKey.Right -> { leaveSel = 1 - leaveSel; sounds.tick(Sfx.focus_bazaar) }
                        RemoteKey.Ok -> if (leaveSel == 0) { leaving = false; sounds.play(Sfx.select) } else { sounds.play(Sfx.back); onDone(run, answers.toList()) }
                        RemoteKey.Back -> leaving = false
                        else -> return@remote false
                    }
                    return@remote true
                }
                when (key) {
                    RemoteKey.Back -> { leaving = true; leaveSel = 0; sounds.play(Sfx.back) }
                    RemoteKey.Left, RemoteKey.Right -> {
                        val ask = step as? RunStep.Ask ?: return@remote true
                        val n = (sel + if (key == RemoteKey.Left) -1 else 1).coerceIn(0, ask.q.options.lastIndex)
                        if (n != sel) { sel = n; sounds.tick(Sfx.focus_bazaar) }
                    }
                    RemoteKey.Up -> (step as? RunStep.Ask)?.let { speaker.safeSay(it.q.spoken, false) }
                    RemoteKey.Ok -> when (val s = step) {
                        is RunStep.Ask -> answer(s.q, sel)
                        is RunStep.Learn -> nextQuestion(s.q)
                        else -> {}
                    }
                    else -> return@remote false
                }
                true
            },
    ) {
        when (val s = step) {
            is RunStep.Ask -> QuickFireBody(s.q, 0, 1, false, sel, null, voice = true) { RunHeader(s.q, run, landName) }
            is RunStep.Right -> QuickFireBody(s.q, 0, 1, false, s.q.answer, s.q.answer, voice = true) { RunHeader(s.q, run, landName) }
            is RunStep.Learn -> LearnMoment(s.q, s.picked, onAha = { sounds.play(Sfx.aha) })
            null -> {}
        }
        milestone?.let { MilestoneBanner(it) }
        if (leaving) LeaveSheet(leaveSel)
    }
}

/** The run's header: the question, the flame with the streak, and the chances left. */
@Composable
private fun RunHeader(q: Question, run: Run, landName: String) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Gap.f4)) {
            BasicText("Streak run · $landName", style = Text.body(TypeScale.s21, FontWeight.Bold).copy(color = Palette.coralInk))
            BasicText(q.prompt, style = Text.display(questionSize(q.prompt)), maxLines = if (q.prompt.length > 40) 3 else 1)
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(Gap.f8)) {
            val pop = remember { Animatable(1f) }
            LaunchedEffect(run.streak) {
                if (run.streak > 0) { pop.snapTo(1.3f); pop.animateTo(1f, spring(Spring.DampingRatioMediumBouncy, Spring.StiffnessMedium)) }
            }
            Row(
                Modifier
                    .graphicsLayer { scaleX = pop.value; scaleY = pop.value }
                    .clip(RoundedCornerShape(Radii.r21))
                    .background(Palette.ink)
                    .padding(horizontal = Gap.f21, vertical = Gap.f8)
                    .testTag("run-streak"),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Gap.f8),
            ) {
                Flame(comboLevel(run.streak).coerceAtLeast(1), Modifier.size(44.dp), if (run.streak == 0) Palette.muted else Palette.coral)
                BasicText("${run.streak}", style = Text.display(TypeScale.s43).copy(color = Palette.cream))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(Gap.f8), verticalAlignment = Alignment.CenterVertically) {
                BasicText(listOf("Easy", "Medium", "Hard")[run.tier - 1], style = Text.body(TypeScale.s18, FontWeight.Bold).copy(color = Palette.muted))
                repeat(Runs.LIVES) { i -> Heart(i < run.livesLeft, Modifier.size(26.dp).testTag(if (i < run.livesLeft) "life" else "life-gone")) }
            }
        }
    }
}

@Composable
private fun Heart(full: Boolean, modifier: Modifier) {
    val s by animateFloatAsState(if (full) 1f else 0.8f, spring(Spring.DampingRatioMediumBouncy), label = "heart")
    Canvas(modifier.graphicsLayer { scaleX = s; scaleY = s }) {
        val w = size.width
        val h = size.height
        val p = Path().apply {
            moveTo(w / 2f, h * 0.88f)
            cubicTo(w * 0.05f, h * 0.55f, w * 0.0f, h * 0.15f, w * 0.3f, h * 0.12f)
            cubicTo(w * 0.42f, h * 0.1f, w * 0.48f, h * 0.2f, w / 2f, h * 0.28f)
            cubicTo(w * 0.52f, h * 0.2f, w * 0.58f, h * 0.1f, w * 0.7f, h * 0.12f)
            cubicTo(w * 1.0f, h * 0.15f, w * 0.95f, h * 0.55f, w / 2f, h * 0.88f)
            close()
        }
        if (full) drawPath(p, Palette.coral) else drawPath(p, Palette.hairline)
    }
}

/** "10 in a row!": Tubby cheers on a sunflower ribbon over the question. */
@Composable
private fun MilestoneBanner(n: Int) {
    val inn = remember(n) { Animatable(0f) }
    LaunchedEffect(n) { inn.animateTo(1f, spring(Spring.DampingRatioMediumBouncy, Spring.StiffnessMediumLow)) }
    Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Row(
            Modifier
                .graphicsLayer { scaleX = inn.value; scaleY = inn.value; rotationZ = (1f - inn.value) * -10f }
                .clip(RoundedCornerShape(Radii.r34))
                .background(Palette.sunflower)
                .border(5.dp, Palette.ink, RoundedCornerShape(Radii.r34))
                .padding(horizontal = Gap.f55, vertical = Gap.f34)
                .testTag("milestone"),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(Gap.f34),
        ) {
            Tubby(TubbyMood.cheer, Modifier.width(110.dp))
            Column {
                BasicText("$n in a row!", style = Text.display(TypeScale.s55))
                BasicText(MILESTONE_LINES[(n / 5) % MILESTONE_LINES.size], style = Text.body(TypeScale.s26, FontWeight.Bold))
            }
            Flame(3, Modifier.size(89.dp))
        }
        Burst(n, Modifier.size(560.dp, 200.dp), reach = 144.dp)
    }
}

private val MILESTONE_LINES = listOf("You're on fire!", "Tubby is dancing!", "Unstoppable!", "Brain power!", "What a streak!")

/** The run is over: the best streak, a ribbon for a new best, then again or back. */
@Composable
fun RunDoneScreen(run: Run, record: Boolean, landName: String, sounds: Sounds, onAgain: () -> Unit, onBack: () -> Unit) {
    var sel by remember { mutableIntStateOf(0) }
    val count = remember { Animatable(0f) }
    LaunchedEffect(run) {
        delay(240)
        count.animateTo(run.best.toFloat(), tween((300 + run.best * 60).coerceAtMost(1_400)))
        sounds.play(if (record) Sfx.run_record else Sfx.run_end)
    }
    Row(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .remote(Unit) { key ->
                when (key) {
                    RemoteKey.Left, RemoteKey.Right -> { sel = 1 - sel; sounds.tick(Sfx.focus_bazaar) }
                    RemoteKey.Ok -> { sounds.play(Sfx.select); if (sel == 0) onAgain() else onBack() }
                    RemoteKey.Back -> { sounds.play(Sfx.back); onBack() }
                    else -> return@remote false
                }
                true
            }
            .padding(horizontal = Safe.x, vertical = Safe.y)
            .testTag("run-done"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Gap.f89),
    ) {
        Column(Modifier.weight(0.382f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Gap.f13)) {
            Box(contentAlignment = Alignment.Center) {
                Flame(3, Modifier.size(233.dp))
                BasicText("${count.value.toInt()}", style = Text.display(TypeScale.s89), modifier = Modifier.padding(top = Gap.f89))
            }
            BasicText("in a row", style = Text.display(TypeScale.s34))
            if (record) {
                BasicText(
                    "New best!",
                    modifier = Modifier.clip(RoundedCornerShape(Radii.r21)).background(Palette.sunflower).padding(horizontal = Gap.f21, vertical = Gap.f8).testTag("run-record"),
                    style = Text.display(TypeScale.s26),
                )
            }
        }
        Column(Modifier.weight(0.618f), verticalArrangement = Arrangement.spacedBy(Gap.f34)) {
            BasicText("Streak run done", style = Text.display(TypeScale.s55))
            BasicText("${run.right} right of ${run.asked} in $landName. Every miss was a thing learned.", style = Text.body(TypeScale.s26))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Gap.f34)) {
                RunDoneButton("Run again", sel == 0, primary = true, Modifier.weight(1f).testTag("run-again"))
                RunDoneButton("Back to the path", sel == 1, primary = false, Modifier.weight(1f).testTag("run-back"))
            }
        }
    }
}

@Composable
private fun RunDoneButton(label: String, selected: Boolean, primary: Boolean, modifier: Modifier) {
    val shape = RoundedCornerShape(Radii.r21)
    Box(
        modifier
            .height(89.dp)
            .selectedRing(selected, shape, primary = primary)
            .clip(shape)
            .background(if (selected) Palette.ink else Palette.card)
            .border(1.dp, if (selected) Palette.ink else Palette.hairline, shape)
            .padding(horizontal = Gap.f21),
        contentAlignment = Alignment.Center,
    ) { BasicText(label, style = Text.display(TypeScale.s34).copy(color = if (selected) Palette.cream else Palette.ink), maxLines = 1) }
}

