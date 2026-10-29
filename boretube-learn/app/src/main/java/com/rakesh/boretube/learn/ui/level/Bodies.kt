package com.rakesh.boretube.learn.ui.level

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.core.Question
import com.rakesh.boretube.learn.core.Visual
import com.rakesh.boretube.learn.ui.Gap
import com.rakesh.boretube.learn.ui.Motion
import com.rakesh.boretube.learn.ui.Palette
import com.rakesh.boretube.learn.ui.ProgressBar
import com.rakesh.boretube.learn.ui.Radii
import com.rakesh.boretube.learn.ui.Safe
import com.rakesh.boretube.learn.ui.Text
import com.rakesh.boretube.learn.ui.Tubby
import com.rakesh.boretube.learn.ui.TubbyMood
import com.rakesh.boretube.learn.ui.TypeScale
import com.rakesh.boretube.learn.ui.selectedRing

/** The question, as big as it fits: 89 for "7 × 8 = ?", smaller for words. */
private fun questionSize(t: String): TextUnit = when {
    t.length <= 12 -> TypeScale.s89
    t.length <= 22 -> TypeScale.s55
    else -> TypeScale.s43
}

@Composable
private fun Header(q: Question, index: Int, of: Int, followUp: Boolean, sub: String?) {
    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(Gap.f4)) {
            if (followUp) BasicText("Now try this one", style = Text.body(TypeScale.s21, FontWeight.Bold).copy(color = Palette.coralInk))
            BasicText(q.prompt, style = Text.display(questionSize(q.prompt)), maxLines = 1)
            sub?.let { BasicText(it, style = Text.muted()) }
        }
        Column(Modifier.width(233.dp).padding(top = Gap.f21), horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(Gap.f8)) {
            BasicText("${index + 1} of $of", style = Text.body(TypeScale.s21, FontWeight.SemiBold))
            ProgressBar((index + 1) / of.toFloat(), Palette.coral, track = Palette.hairline)
        }
    }
}

@Composable
private fun Hint(left: String, right: String?) {
    Row(Modifier.fillMaxWidth()) {
        BasicText(left, style = Text.muted(), modifier = Modifier.weight(1f))
        right?.let { BasicText(it, style = Text.muted()) }
    }
}

@Composable
private fun Tick(color: Color, modifier: Modifier) {
    Canvas(modifier) {
        val k = size.width / 24f
        val p = Path().apply { moveTo(5f * k, 12.5f * k); lineTo(9.5f * k, 17f * k); lineTo(19f * k, 7.5f * k) }
        drawPath(p, color, style = Stroke(3f * k, cap = StrokeCap.Round))
    }
}

/**
 * Quick-fire: the question top left, answer tiles in one row. [right] is the
 * answer's index while the "Yes!" shows (null while asking).
 */
@Composable
fun QuickFireBody(q: Question, index: Int, of: Int, followUp: Boolean, sel: Int, right: Int?, voice: Boolean) {
    val pies = (q.visual as? Visual.Pies)?.fractions
    Column(
        Modifier.fillMaxSize().padding(horizontal = Safe.x, vertical = Safe.y).testTag(if (right == null) "ask" else "right"),
        verticalArrangement = Arrangement.spacedBy(Gap.f21),
    ) {
        Header(q, index, of, followUp, if (pies != null) "Same-size pizzas. Pick the bigger share." else null)
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            when (val v = q.visual) {
                is Visual.Objects -> Mangoes(v.count)
                is Visual.Clock -> ClockFace(v.hour, v.minute, Modifier.fillMaxHeight().aspectRatio(1f))
                else -> {}
            }
        }
        Row(Modifier.fillMaxWidth().height(if (pies != null) 233.dp else 144.dp), horizontalArrangement = Arrangement.spacedBy(Gap.f34)) {
            q.options.forEachIndexed { i, label ->
                val isRight = right != null && i == right
                val dim = right != null && !isRight
                val selected = right == null && i == sel
                val shape = RoundedCornerShape(Radii.r21)
                val fill by animateFloatAsState(if (dim) 0.35f else 1f, tween(Motion.flip), label = "dim")
                Box(
                    Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .alpha(fill)
                        .selectedRing(selected || isRight, shape, primary = true, scale = 1.06f)
                        .clip(shape)
                        .background(
                            when {
                                isRight -> Palette.mint
                                selected -> Palette.ink
                                else -> Palette.card
                            },
                        )
                        .border(1.dp, if (selected || isRight) Color.Transparent else Palette.hairline, shape)
                        .testTag("tile-$i"),
                    contentAlignment = Alignment.Center,
                ) {
                    val ink = when {
                        isRight -> Palette.ink
                        selected -> Palette.cream
                        else -> Palette.ink
                    }
                    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Gap.f13)) {
                        val frac = pies?.firstOrNull { "${it.first}/${it.second}" == label }
                        if (frac != null) Pie(frac.first, frac.second, Modifier.size(110.dp), empty = if (selected) Palette.muted else Palette.hairline, line = if (selected) Palette.ink else Palette.card)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (isRight) { Tick(ink, Modifier.size(40.dp)); Spacer(Modifier.width(Gap.f8)) }
                            BasicText(label, style = Text.display(if (label.length > 5) TypeScale.s34 else if (pies != null) TypeScale.s43 else TypeScale.s55).copy(color = ink), maxLines = 1)
                        }
                    }
                }
            }
        }
        Hint("◀ ▶ to move · OK to choose", if (voice) "▲ hear it again" else null)
    }
}

/**
 * Catch: answers fall in three lanes and wait at the bottom; ◀ ▶ moves Tubby's
 * basket, OK catches the answer above it.
 */
@Composable
fun CatchBody(q: Question, index: Int, of: Int, followUp: Boolean, lane: Int, right: Int?) {
    Column(
        Modifier.fillMaxSize().padding(horizontal = Safe.x, vertical = Gap.f34).testTag(if (right == null) "ask" else "right"),
        verticalArrangement = Arrangement.spacedBy(Gap.f21),
    ) {
        Header(q, index, of, followUp, "Catch the answer")
        Row(Modifier.weight(1f).fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Gap.f34)) {
            q.options.forEachIndexed { i, label ->
                BoxWithConstraints(
                    Modifier.weight(1f).fillMaxHeight().clip(RoundedCornerShape(Radii.r34)).background(Palette.cream).testTag("lane-$i"),
                ) {
                    val rest = maxHeight - BALL - BASKET_H - Gap.f13
                    val fall = remember(q.key) { Animatable(-BALL.value) }
                    LaunchedEffect(q.key) {
                        fall.animateTo(rest.value, tween(FALL_MS + i * 260, easing = FastOutSlowInEasing))
                    }
                    val isRight = right != null && i == right
                    val dim = right != null && !isRight
                    Box(
                        Modifier
                            .align(Alignment.TopCenter)
                            .offset(y = fall.value.dp)
                            .size(BALL)
                            .alpha(if (dim) 0.35f else 1f)
                            .clip(CircleShape)
                            .background(if (isRight) Palette.mint else BALL_COLORS[i % BALL_COLORS.size]),
                        contentAlignment = Alignment.Center,
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            if (isRight) Tick(Palette.ink, Modifier.size(34.dp))
                            BasicText(label, style = Text.display(if (label.length > 3) TypeScale.s43 else TypeScale.s55), maxLines = 1)
                        }
                    }
                    if (i == lane) Basket(Modifier.align(Alignment.BottomCenter).padding(bottom = Gap.f13).testTag("basket-$i"))
                }
            }
        }
        Hint("◀ ▶ move Tubby's basket · OK to catch", "No rush: the answers wait at the bottom")
    }
}

private val BALL = 144.dp
private val BASKET_H = 110.dp
private const val FALL_MS = 2_400
private val BALL_COLORS = listOf(Palette.sunflower, Palette.trail, Palette.garden)

@Composable
private fun Basket(modifier: Modifier) {
    Canvas(modifier.size(200.dp, BASKET_H)) {
        val k = size.width / 200f
        scale(k, k, pivot = Offset.Zero) {
            drawLine(Palette.ink, Offset(84f, 12f), Offset(78f, 2f), 4f, StrokeCap.Round)
            drawLine(Palette.ink, Offset(116f, 12f), Offset(122f, 2f), 4f, StrokeCap.Round)
            drawRoundRect(Palette.sky, Offset(70f, 10f), Size(60f, 34f), CornerRadius(12f))
            drawCircle(Palette.cream, 4f, Offset(90f, 26f))
            drawCircle(Palette.cream, 4f, Offset(110f, 26f))
            drawPath(Path().apply { moveTo(20f, 40f); lineTo(180f, 40f); lineTo(160f, 100f); lineTo(40f, 100f); close() }, Palette.sunflowerInk)
            drawLine(Palette.ink, Offset(20f, 40f), Offset(180f, 40f), 6f, StrokeCap.Round)
            drawLine(Palette.sunflowerSoft, Offset(40f, 60f), Offset(160f, 60f), 4f)
            drawLine(Palette.sunflowerSoft, Offset(50f, 80f), Offset(150f, 80f), 4f)
        }
    }
}

/** A miss: the fact with the answer picked out, what they chose, the one-line why, a picture, Got it. */
@Composable
fun LearnMoment(q: Question, picked: Int) {
    Column(
        Modifier.fillMaxSize().background(Palette.canvas).padding(horizontal = Safe.x, vertical = Safe.y).testTag("learn-moment"),
        verticalArrangement = Arrangement.spacedBy(Gap.f21),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Tubby(TubbyMood.think, Modifier.width(66.dp))
            Spacer(Modifier.width(Gap.f21))
            BasicText("Almost! Let's learn this one.", style = Text.display(TypeScale.s34))
        }
        Row(Modifier.weight(1f).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Gap.f55)) {
            Column(Modifier.weight(0.618f), verticalArrangement = Arrangement.spacedBy(Gap.f21)) {
                val ans = q.answerText
                val fact = buildAnnotatedString {
                    if (q.fact.endsWith(ans)) {
                        append(q.fact.removeSuffix(ans))
                        withStyle(SpanStyle(color = Palette.sunflowerInk)) { append(ans) }
                    } else {
                        withStyle(SpanStyle(color = Palette.sunflowerInk)) { append(q.fact) }
                    }
                }
                BasicText(fact, style = Text.display(if (q.fact.length <= 12) TypeScale.s89 else TypeScale.s55), maxLines = 1)
                val pick = q.options.getOrNull(picked) ?: ""
                BasicText(
                    buildAnnotatedString {
                        append("You picked ")
                        withStyle(SpanStyle(textDecoration = TextDecoration.LineThrough)) { append(pick) }
                    },
                    style = Text.muted(TypeScale.s26),
                )
                BasicText(q.explain, style = Text.body(TypeScale.s34, FontWeight.Medium).copy(lineHeight = TypeScale.s43), maxLines = 3)
            }
            Box(Modifier.weight(0.382f), contentAlignment = Alignment.Center) {
                val v = q.learnVisual
                if (v != null) QuestionVisual(v, Modifier.height(300.dp), numbered = true)
                else Tubby(TubbyMood.think, Modifier.width(220.dp))
            }
        }
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            BasicText("We'll ask this one again soon.", style = Text.muted(), modifier = Modifier.weight(1f))
            Box(
                Modifier
                    .height(89.dp)
                    .selectedRing(true, RoundedCornerShape(Radii.r21), primary = true)
                    .clip(RoundedCornerShape(Radii.r21))
                    .background(Palette.ink)
                    .padding(horizontal = Gap.f55),
                contentAlignment = Alignment.Center,
            ) { BasicText("Got it", style = Text.display(TypeScale.s34).copy(color = Palette.cream)) }
        }
    }
}

/** "Leave this level?": Stay is the default; Leave on the right. */
@Composable
fun LeaveSheet(sel: Int) {
    Box(Modifier.fillMaxSize().background(Palette.ink.copy(alpha = 0.45f)), contentAlignment = Alignment.Center) {
        Column(
            Modifier.width(620.dp).clip(RoundedCornerShape(Radii.r34)).background(Palette.card).padding(Gap.f55),
            verticalArrangement = Arrangement.spacedBy(Gap.f21),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Tubby(TubbyMood.calm, Modifier.width(89.dp))
            BasicText("Leave this level?", style = Text.display(TypeScale.s43))
            BasicText("Stars only count when a level is finished.", style = Text.muted())
            Row(horizontalArrangement = Arrangement.spacedBy(Gap.f34)) {
                for ((i, label) in listOf("Stay", "Leave").withIndex()) {
                    val shape = RoundedCornerShape(Radii.r21)
                    Box(
                        Modifier
                            .width(200.dp)
                            .height(89.dp)
                            .selectedRing(sel == i, shape, primary = i == 0, gap = Palette.card)
                            .clip(shape)
                            .background(if (sel == i) Palette.ink else Palette.canvas),
                        contentAlignment = Alignment.Center,
                    ) { BasicText(label, style = Text.display(TypeScale.s34).copy(color = if (sel == i) Palette.cream else Palette.ink)) }
                }
            }
        }
    }
}
