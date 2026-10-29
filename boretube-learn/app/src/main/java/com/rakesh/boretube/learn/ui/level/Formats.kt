package com.rakesh.boretube.learn.ui.level

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
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
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.core.Question
import com.rakesh.boretube.learn.ui.Gap
import com.rakesh.boretube.learn.ui.Motion
import com.rakesh.boretube.learn.ui.Palette
import com.rakesh.boretube.learn.ui.Radii
import com.rakesh.boretube.learn.ui.Safe
import com.rakesh.boretube.learn.ui.Text
import com.rakesh.boretube.learn.ui.TypeScale
import com.rakesh.boretube.learn.ui.selectedRing

/** The statement's size: big for a short claim, smaller for a sentence. */
private fun statementSize(t: String) = when {
    t.length <= 24 -> TypeScale.s55
    t.length <= 60 -> TypeScale.s43
    else -> TypeScale.s34
}

/** A card that lands with a little spring each time [key] changes. */
@Composable
private fun landing(key: Any): Float {
    val s = remember(key) { Animatable(0.9f) }
    LaunchedEffect(key) { s.animateTo(1f, spring(Spring.DampingRatioMediumBouncy, Spring.StiffnessMediumLow)) }
    return s.value
}

/**
 * True or false: the statement on a card, two big answers below. ◀ ▶ moves,
 * OK chooses. [right] is the answer's index while the "Yes!" shows.
 */
@Composable
fun TrueFalseBody(q: Question, index: Int, of: Int, followUp: Boolean, sel: Int, right: Int?) {
    val land = landing(q.key)
    Column(
        Modifier.fillMaxSize().padding(horizontal = Safe.x, vertical = Safe.y).testTag(if (right == null) "ask" else "right"),
        verticalArrangement = Arrangement.spacedBy(Gap.f21),
    ) {
        Header(q, index, of, followUp, null, prompt = "True or false?")
        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
            Box(
                Modifier
                    .graphicsLayer { scaleX = land; scaleY = land; rotationZ = (1f - land) * -12f }
                    .widthIn(max = 980.dp)
                    .clip(RoundedCornerShape(Radii.r34))
                    .background(Palette.card)
                    .border(1.dp, Palette.hairline, RoundedCornerShape(Radii.r34))
                    .padding(horizontal = Gap.f55, vertical = Gap.f34)
                    .testTag("statement"),
                contentAlignment = Alignment.Center,
            ) {
                BasicText(
                    q.prompt,
                    style = Text.display(statementSize(q.prompt)).copy(textAlign = TextAlign.Center),
                    maxLines = 3,
                )
            }
        }
        Row(Modifier.fillMaxWidth().height(144.dp), horizontalArrangement = Arrangement.spacedBy(Gap.f34)) {
            for ((i, label) in q.options.withIndex()) {
                val isRight = right != null && i == right
                val dim = right != null && !isRight
                val selected = right == null && i == sel
                val shape = RoundedCornerShape(Radii.r21)
                val fade by animateFloatAsState(if (dim) 0.35f else 1f, tween(Motion.flip), label = "dim")
                Box(Modifier.weight(1f).fillMaxHeight()) {
                    Box(
                        Modifier
                            .fillMaxSize()
                            .alpha(fade)
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
                        val ink = if (selected) Palette.cream else Palette.ink
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(Gap.f13)) {
                            TrueFalseMark(i == 0, if (selected) Palette.cream else if (i == 0) Palette.mintInk else Palette.coralInk, Modifier.size(44.dp))
                            BasicText(label, style = Text.display(TypeScale.s55).copy(color = ink))
                        }
                    }
                    if (isRight) Burst(q.key, Modifier.matchParentSize())
                }
            }
        }
        Hint("◀ True · False ▶ · OK to choose", "▲ hear it again")
    }
}

/** A tick for True, a cross for False, drawn. */
@Composable
private fun TrueFalseMark(isTrue: Boolean, color: Color, modifier: Modifier) {
    Canvas(modifier) {
        val k = size.width / 24f
        val w = 3.2f * k
        if (isTrue) {
            drawLine(color, Offset(5f * k, 12.5f * k), Offset(9.5f * k, 17f * k), w, StrokeCap.Round)
            drawLine(color, Offset(9.5f * k, 17f * k), Offset(19f * k, 7.5f * k), w, StrokeCap.Round)
        } else {
            drawLine(color, Offset(6f * k, 6f * k), Offset(18f * k, 18f * k), w, StrokeCap.Round)
            drawLine(color, Offset(18f * k, 6f * k), Offset(6f * k, 18f * k), w, StrokeCap.Round)
        }
    }
}

/**
 * Sort: a card drops in between two baskets; ◀ sends it left, ▶ right.
 * [placed] is the side it went to while the "Yes!" shows (null while
 * asking). [counts] are the cards already sorted into each basket.
 */
@Composable
fun SortBody(q: Question, index: Int, of: Int, followUp: Boolean, placed: Int?, counts: Pair<Int, Int>) {
    val drop = remember(q.key) { Animatable(-260f) }
    LaunchedEffect(q.key) { drop.animateTo(0f, spring(Spring.DampingRatioLowBouncy, Spring.StiffnessLow)) }
    val slide by animateFloatAsState(
        when (placed) { 0 -> -1f; 1 -> 1f; else -> 0f },
        tween(Motion.sheet, easing = FastOutSlowInEasing),
        label = "slide",
    )
    val left = q.options.getOrElse(0) { "" }
    val rightLabel = q.options.getOrElse(1) { "" }
    Column(
        Modifier.fillMaxSize().padding(horizontal = Safe.x, vertical = Safe.y).testTag(if (placed == null) "ask" else "right"),
        verticalArrangement = Arrangement.spacedBy(Gap.f21),
    ) {
        Header(q, index, of, followUp, null, prompt = "$left or $rightLabel?")
        Row(Modifier.weight(1f).fillMaxWidth(), verticalAlignment = Alignment.Bottom, horizontalArrangement = Arrangement.spacedBy(Gap.f34)) {
            SortBasket(left, counts.first, glow = placed == 0, side = -1, Modifier.weight(1f))
            Box(Modifier.weight(1.2f).fillMaxHeight(), contentAlignment = Alignment.TopCenter) {
                Box(
                    Modifier
                        .padding(top = Gap.f34)
                        .graphicsLayer {
                            translationY = drop.value.dp.toPx() + slide * slide * 120.dp.toPx()
                            translationX = slide * 330.dp.toPx()
                            val s = 1f - 0.35f * kotlin.math.abs(slide)
                            scaleX = s; scaleY = s
                            rotationZ = slide * 8f
                        }
                        .widthIn(min = 300.dp, max = 460.dp)
                        .clip(RoundedCornerShape(Radii.r34))
                        .background(if (placed != null) Palette.mint else Palette.card)
                        .border(1.dp, Palette.hairline, RoundedCornerShape(Radii.r34))
                        .padding(horizontal = Gap.f34, vertical = Gap.f34)
                        .testTag("sort-card"),
                    contentAlignment = Alignment.Center,
                ) {
                    BasicText(q.prompt, style = Text.display(questionSize(q.prompt)).copy(textAlign = TextAlign.Center), maxLines = 3)
                }
            }
            SortBasket(rightLabel, counts.second, glow = placed == 1, side = 1, Modifier.weight(1f))
        }
        Hint("◀ into $left · into $rightLabel ▶", "▲ hear it again")
    }
}

@Composable
private fun SortBasket(label: String, count: Int, glow: Boolean, side: Int, modifier: Modifier) {
    val lift by animateFloatAsState(if (glow) 1f else 0f, spring(Spring.DampingRatioMediumBouncy), label = "lift")
    val shape = RoundedCornerShape(topStart = Radii.r13, topEnd = Radii.r13, bottomStart = Radii.r34, bottomEnd = Radii.r34)
    Column(
        modifier.graphicsLayer { translationY = -lift * 13.dp.toPx(); scaleX = 1f + 0.04f * lift; scaleY = 1f + 0.04f * lift },
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Gap.f13),
    ) {
        // Cards already in: a little stack peeking over the rim.
        Box(Modifier.height(55.dp).fillMaxWidth(), contentAlignment = Alignment.BottomCenter) {
            for (i in 0 until count.coerceAtMost(6)) {
                Box(
                    Modifier
                        .graphicsLayer { translationY = -i * 6.dp.toPx(); rotationZ = (if (i % 2 == 0) -4f else 5f) * side }
                        .size(150.dp, 34.dp)
                        .clip(RoundedCornerShape(Radii.r8))
                        .background(if (i % 2 == 0) Palette.cream else Palette.card)
                        .border(1.dp, Palette.hairline, RoundedCornerShape(Radii.r8)),
                )
            }
        }
        Box(
            Modifier
                .fillMaxWidth()
                .height(200.dp)
                .clip(shape)
                .background(if (glow) Palette.mint else Palette.sunflowerSoft)
                .testTag(if (side < 0) "basket-left" else "basket-right"),
            contentAlignment = Alignment.Center,
        ) {
            Canvas(Modifier.fillMaxSize()) {
                val weave = if (glow) Palette.mintInk.copy(alpha = 0.25f) else Palette.sunflowerInk.copy(alpha = 0.18f)
                for (y in listOf(0.84f, 0.93f)) drawLine(weave, Offset(size.width * 0.1f, size.height * y), Offset(size.width * 0.9f, size.height * y), 4.dp.toPx())
                drawLine(Palette.ink, Offset(0f, 2.dp.toPx()), Offset(size.width, 2.dp.toPx()), 5.dp.toPx(), StrokeCap.Round)
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                BasicText(if (side < 0) "◀" else "▶", style = Text.body(TypeScale.s26, FontWeight.Bold).copy(color = Palette.sunflowerInk))
                BasicText(label, style = Text.display(if (label.length <= 8) TypeScale.s43 else TypeScale.s34).copy(textAlign = TextAlign.Center), maxLines = 2)
            }
        }
    }
}

/**
 * Put in order: numbered slots at the top fill as tiles are placed; the
 * tiles left wait below. ◀ ▶ picks a tile, OK places it, Back takes the last
 * one back. [right] shows the whole order in mint.
 */
@Composable
fun OrderBody(q: Question, index: Int, of: Int, followUp: Boolean, placed: List<Int>, sel: Int, right: Boolean, wrongShake: Any?) {
    val n = q.options.size
    val left = q.options.indices.filter { it !in placed }
    Column(
        Modifier.fillMaxSize().padding(horizontal = Safe.x, vertical = Safe.y).testTag(if (!right) "ask" else "right"),
        verticalArrangement = Arrangement.spacedBy(Gap.f34),
    ) {
        Header(q, index, of, followUp, "First to last")
        Box(Modifier.fillMaxWidth()) {
            Row(Modifier.fillMaxWidth().height(144.dp).shake(wrongShake), horizontalArrangement = Arrangement.spacedBy(Gap.f21)) {
                for (slot in 0 until n) {
                    val item = placed.getOrNull(slot)
                    val shape = RoundedCornerShape(Radii.r21)
                    val pop = remember(item) { Animatable(if (item == null) 1f else 0.8f) }
                    LaunchedEffect(item) { if (item != null) pop.animateTo(1f, spring(Spring.DampingRatioMediumBouncy, Spring.StiffnessMedium)) }
                    Box(
                        Modifier
                            .weight(1f)
                            .fillMaxHeight()
                            .graphicsLayer { scaleX = pop.value; scaleY = pop.value }
                            .testTag("slot-$slot"),
                    ) {
                        if (item == null) {
                            Canvas(Modifier.fillMaxSize()) {
                                drawRoundRect(
                                    Palette.outline,
                                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(Radii.r21.toPx()),
                                    style = Stroke(3.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(14.dp.toPx(), 10.dp.toPx()))),
                                )
                            }
                            BasicText("${slot + 1}", style = Text.display(TypeScale.s43).copy(color = Palette.outline), modifier = Modifier.align(Alignment.Center))
                        } else {
                            Box(
                                Modifier.fillMaxSize().clip(shape).background(if (right) Palette.mint else Palette.ink).padding(Gap.f13),
                                contentAlignment = Alignment.Center,
                            ) {
                                BasicText(
                                    q.options[item],
                                    style = Text.display(orderSize(q.options[item])).copy(color = if (right) Palette.ink else Palette.cream, textAlign = TextAlign.Center),
                                    maxLines = 2,
                                )
                            }
                            Box(
                                Modifier.align(Alignment.TopStart).padding(Gap.f8).size(34.dp).clip(CircleShape).background(Palette.sunflower),
                                contentAlignment = Alignment.Center,
                            ) { BasicText("${slot + 1}", style = Text.body(TypeScale.s18, FontWeight.ExtraBold)) }
                        }
                    }
                }
            }
            if (right) Burst(q.key, Modifier.matchParentSize(), reach = 89.dp)
        }
        Spacer(Modifier.weight(1f))
        Row(Modifier.fillMaxWidth().height(144.dp), horizontalArrangement = Arrangement.spacedBy(Gap.f21)) {
            for (i in 0 until n) {
                val waiting = i in left
                val selected = !right && waiting && left.getOrNull(sel) == i
                val shape = RoundedCornerShape(Radii.r21)
                val fade by animateFloatAsState(if (waiting) 1f else 0f, tween(Motion.flip), label = "fade")
                Box(
                    Modifier
                        .weight(1f)
                        .fillMaxHeight()
                        .alpha(fade)
                        .selectedRing(selected, shape, primary = true, scale = 1.06f)
                        .clip(shape)
                        .background(if (selected) Palette.ink else Palette.card)
                        .border(1.dp, if (selected) Color.Transparent else Palette.hairline, shape)
                        .padding(Gap.f13)
                        .testTag("order-tile-$i"),
                    contentAlignment = Alignment.Center,
                ) {
                    BasicText(
                        q.options[i],
                        style = Text.display(orderSize(q.options[i])).copy(color = if (selected) Palette.cream else Palette.ink, textAlign = TextAlign.Center),
                        maxLines = 2,
                    )
                }
            }
        }
        Hint("◀ ▶ pick · OK to place · Back takes one back", "▲ hear it again")
    }
}

private fun orderSize(t: String) = when {
    t.length <= 4 -> TypeScale.s55
    t.length <= 9 -> TypeScale.s34
    t.length <= 16 -> TypeScale.s26
    else -> TypeScale.s21
}

/** The right order, numbered, for the learn moment: each chip pops in turn. */
@Composable
fun OrderAnswer(order: List<String>, shownUpTo: Int, modifier: Modifier = Modifier) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(Gap.f13), verticalAlignment = Alignment.CenterVertically) {
        for ((i, item) in order.withIndex()) {
            val on = i < shownUpTo
            val s by animateFloatAsState(if (on) 1f else 0.6f, spring(Spring.DampingRatioMediumBouncy), label = "chip")
            Row(
                Modifier
                    .graphicsLayer { scaleX = s; scaleY = s; alpha = if (on) 1f else 0f }
                    .clip(RoundedCornerShape(Radii.r21))
                    .background(Palette.card)
                    .border(2.dp, Palette.sunflower, RoundedCornerShape(Radii.r21))
                    .padding(horizontal = Gap.f13, vertical = Gap.f8),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(Gap.f8),
            ) {
                Box(Modifier.size(30.dp).clip(CircleShape).background(Palette.sunflower), contentAlignment = Alignment.Center) {
                    BasicText("${i + 1}", style = Text.body(TypeScale.s18, FontWeight.ExtraBold))
                }
                BasicText(item, style = Text.display(if (order.size >= 5 || item.length > 10) TypeScale.s21 else TypeScale.s26), maxLines = 1)
            }
        }
    }
}
