package com.rakesh.boretube.learn.ui.level

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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.core.Answered
import com.rakesh.boretube.learn.core.Catalog
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Levels
import com.rakesh.boretube.learn.core.Question
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds
import com.rakesh.boretube.learn.ui.FitText
import com.rakesh.boretube.learn.ui.Gap
import com.rakesh.boretube.learn.ui.LocalUptime
import com.rakesh.boretube.learn.ui.Palette
import com.rakesh.boretube.learn.ui.PictureArt
import com.rakesh.boretube.learn.ui.Radii
import com.rakesh.boretube.learn.ui.RemoteKey
import com.rakesh.boretube.learn.ui.Safe
import com.rakesh.boretube.learn.ui.Text
import com.rakesh.boretube.learn.ui.TypeScale
import com.rakesh.boretube.learn.ui.remote
import com.rakesh.boretube.learn.ui.selectedRing
import kotlinx.coroutines.delay
import kotlin.random.Random

/** One card: which pair it belongs to and whether it's the answer side. */
data class PairCard(val pair: Int, val answer: Boolean, val face: String)

object PairsBoard {
    const val COLS = 4

    /** Two cards per question (the sum, the answer), shuffled. Pure: same seed, same board. */
    fun deal(questions: List<Question>, r: Random): List<PairCard> =
        questions.flatMapIndexed { i, q -> listOf(PairCard(i, false, Levels.pairPrompt(q)), PairCard(i, true, q.answerText)) }.shuffled(r)
}

/**
 * Pairs (mock artboard 6): a 4×3 board of face-down cards. Arrows move, OK
 * flips; a match stays up with a tick, a mismatch flips back after a beat.
 * A fact counts as right only if neither of its cards was in a mismatch.
 */
@Composable
fun PairsLevel(
    skillId: String,
    state: LearnState,
    sounds: Sounds,
    random: Random,
    now: Long,
    catalog: Catalog = Catalog.MATHS,
    onDone: (List<Answered>) -> Unit,
    onLeave: () -> Unit,
) {
    val questions = remember(skillId) { Levels.pairsFor(state, skillId, now, random, catalog) }
    val board = remember(skillId) { PairsBoard.deal(questions, random) }
    if (questions.size < 2) {
        LaunchedEffect(Unit) { onLeave() }
        return
    }
    val uptime = LocalUptime.current
    val startedAt = remember { uptime() }
    var sel by remember { mutableIntStateOf(0) }
    val up = remember { mutableStateListOf<Int>() }
    val matched = remember { mutableStateListOf<Int>() }
    val missed = remember { mutableStateListOf<Int>() }
    var busy by remember { mutableStateOf(false) }
    var leaving by remember { mutableStateOf(false) }
    var leaveSel by remember { mutableIntStateOf(0) }

    // Two up: a match stays, a mismatch flips back after a beat.
    LaunchedEffect(up.toList()) {
        if (up.size < 2) return@LaunchedEffect
        val (a, b) = up[0] to up[1]
        if (board[a].pair == board[b].pair) {
            matched += board[a].pair
            sounds.play(Sfx.pair_match)
            up.clear()
        } else {
            busy = true
            sounds.play(Sfx.miss)
            for (c in listOf(a, b)) if (board[c].pair !in missed) missed += board[c].pair
            delay(FLIP_BACK_MS)
            up.clear()
            sounds.play(Sfx.card_back)
            busy = false
        }
    }

    // Its own effect: clearing `up` above restarts that one.
    LaunchedEffect(matched.size) {
        if (matched.size < questions.size) return@LaunchedEffect
        delay(DONE_DELAY_MS)
        val ms = (uptime() - startedAt) / questions.size
        onDone(questions.mapIndexed { i, q -> Answered(q, q.answer, i !in missed, ms, false) })
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Palette.garden)
            .remote(leaving) { key ->
                if (leaving) {
                    when (key) {
                        RemoteKey.Left, RemoteKey.Right -> leaveSel = 1 - leaveSel
                        RemoteKey.Ok -> if (leaveSel == 0) leaving = false else { sounds.play(Sfx.back); onLeave() }
                        RemoteKey.Back -> leaving = false
                        else -> return@remote false
                    }
                    return@remote true
                }
                val n = board.size
                when (key) {
                    RemoteKey.Left -> if (sel % PairsBoard.COLS > 0) { sel--; sounds.tick(Sfx.focus_garden) }
                    RemoteKey.Right -> if (sel % PairsBoard.COLS < PairsBoard.COLS - 1 && sel + 1 < n) { sel++; sounds.tick(Sfx.focus_garden) }
                    RemoteKey.Up -> if (sel - PairsBoard.COLS >= 0) { sel -= PairsBoard.COLS; sounds.tick(Sfx.focus_garden) }
                    RemoteKey.Down -> if (sel + PairsBoard.COLS < n) { sel += PairsBoard.COLS; sounds.tick(Sfx.focus_garden) }
                    RemoteKey.Ok -> if (!busy && sel !in up && board[sel].pair !in matched && up.size < 2) {
                        sounds.play(Sfx.card_flip)
                        up += sel
                    }
                    RemoteKey.Back -> { leaving = true; leaveSel = 0; sounds.play(Sfx.back) }
                }
                true
            },
    ) {
        Column(Modifier.fillMaxSize().padding(horizontal = Safe.x, vertical = Gap.f34), verticalArrangement = Arrangement.spacedBy(Gap.f21)) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Bottom) {
                BasicText("Match each one to its answer", style = Text.display(TypeScale.s43), modifier = Modifier.weight(1f), maxLines = 1)
                BasicText("${matched.size} of ${questions.size} pairs", style = Text.body(TypeScale.s21, FontWeight.SemiBold))
            }
            Column(Modifier.weight(1f).fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(Gap.f34, Alignment.CenterVertically)) {
                for (row in board.indices.chunked(PairsBoard.COLS)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Gap.f34)) {
                        for (i in row) Card(board[i], i == sel && !leaving, i in up, board[i].pair in matched, Modifier.weight(1f).testTag("card-$i"))
                    }
                }
            }
            val waiting = up.singleOrNull()?.let { board[it].face }
            Row(Modifier.fillMaxWidth()) {
                BasicText("Arrows to move · OK to flip", style = Text.muted().copy(color = Palette.mintInk), modifier = Modifier.weight(1f))
                if (waiting != null) BasicText("\"$waiting\" is waiting for its match", style = Text.muted().copy(color = Palette.mintInk))
            }
        }
        if (leaving) LeaveSheet(leaveSel)
    }
}

@Composable
private fun Card(card: PairCard, selected: Boolean, up: Boolean, matched: Boolean, modifier: Modifier) {
    val shape = RoundedCornerShape(Radii.r21)
    val showFace = up || matched
    Box(
        modifier
            .height(144.dp)
            .alpha(if (matched) 0.55f else 1f)
            .selectedRing(selected, shape, scale = 1.06f, gap = Palette.garden)
            .clip(shape)
            .background(
                when {
                    matched -> Palette.cream
                    up -> Palette.card
                    else -> Palette.mint
                },
            )
            .then(if (up && !matched) Modifier.border(3.dp, Palette.mint, shape) else Modifier),
        contentAlignment = Alignment.Center,
    ) {
        if (showFace) {
            if (card.face.startsWith("pic:")) PictureArt(card.face.removePrefix("pic:"), Modifier.size(96.dp))
            else FitText(card.face, Text.display(TypeScale.s43), Modifier.fillMaxSize().padding(Gap.f13), maxLines = 2)
            if (matched) Box(Modifier.align(Alignment.TopEnd).padding(Gap.f13)) { BasicText("✓", style = Text.display(TypeScale.s26).copy(color = Palette.mintInk)) }
        } else {
            CardBack(Modifier.size(55.dp))
        }
    }
}

private const val FLIP_BACK_MS = 900L
private const val DONE_DELAY_MS = 700L

/** The card back (mock): a soft leaf, lighter than the card. */
@Composable
private fun CardBack(modifier: Modifier) {
    androidx.compose.foundation.Canvas(modifier) {
        val k = size.minDimension / 40f
        val leaf = androidx.compose.ui.graphics.Path().apply {
            moveTo(20f * k, 6f * k); cubicTo(30f * k, 12f * k, 30f * k, 28f * k, 20f * k, 34f * k)
            cubicTo(10f * k, 28f * k, 10f * k, 12f * k, 20f * k, 6f * k); close()
        }
        drawPath(leaf, androidx.compose.ui.graphics.Color(0xFFA8E3C9))
        drawLine(Palette.mint, androidx.compose.ui.geometry.Offset(20f * k, 10f * k), androidx.compose.ui.geometry.Offset(20f * k, 32f * k), 2f * k)
    }
}
