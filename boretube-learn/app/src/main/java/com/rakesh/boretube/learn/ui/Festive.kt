package com.rakesh.boretube.learn.ui

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.core.Seasons.Decor
import kotlin.math.PI
import kotlin.math.sin

/*
 * Festival decorations for the town (spec P2b §8): a backdrop that moves
 * slowly behind the cards, and a frame in the screen's safe margins (a toran
 * or bunting along the top, diyas along the bottom). Flat shapes from the
 * palette; nothing ever covers a card or a word. Infinite transitions, so
 * tests stay idle.
 */

private val Marigold = Color(0xFFFF9F1C)
private val Saffron = Color(0xFFFF9933)
private val IndiaGreen = Color(0xFF138808)
private val Navy = Color(0xFF000080)
private val Clay = Color(0xFFB4532A)
private val HoliPink = Color(0xFFFF5FA2)

/** The moving layer behind the town's content. */
@Composable
fun FestiveBackdrop(decor: Set<Decor>, modifier: Modifier = Modifier) {
    if (decor.none { it in BACKDROP }) return
    val t by rememberInfiniteTransition(label = "festive").animateFloat(
        0f, 1f, infiniteRepeatable(tween(14_000, easing = LinearEasing), RepeatMode.Restart), label = "festive",
    )
    Canvas(modifier.fillMaxSize().testTag("festive-backdrop")) {
        if (Decor.puffs in decor) puffs(t)
        if (Decor.kites in decor) kites(t)
        if (Decor.balloons in decor) balloons(t)
        if (Decor.snow in decor) snow(t)
        if (Decor.twinkles in decor) twinkles(t)
        if (Decor.lanterns in decor) lanterns(t)
    }
}

/** Garlands and lamps in the screen's margins, above everything (they sit where nothing else is). */
@Composable
fun FestiveFrame(decor: Set<Decor>, modifier: Modifier = Modifier) {
    if (decor.none { it in FRAME }) return
    val t by rememberInfiniteTransition(label = "frame").animateFloat(
        0f, 1f, infiniteRepeatable(tween(2_400, easing = LinearEasing), RepeatMode.Restart), label = "frame",
    )
    Canvas(modifier.fillMaxSize().testTag("festive-frame")) {
        if (Decor.toran in decor) toran(t)
        if (Decor.bunting in decor) bunting(t)
        if (Decor.diyas in decor) diyas(t)
    }
}

private val BACKDROP = setOf(Decor.puffs, Decor.kites, Decor.balloons, Decor.snow, Decor.twinkles, Decor.lanterns)
private val FRAME = setOf(Decor.toran, Decor.bunting, Decor.diyas)

private fun wave(t: Float, phase: Float) = sin((t + phase) * 2f * PI.toFloat())

/** Marigold garland in swags across the top margin, with mango leaves at each tie. */
private fun DrawScope.toran(t: Float) {
    val swags = 8
    val w = size.width / swags
    val top = 6.dp.toPx()
    val dip = 26.dp.toPx()
    for (s in 0 until swags) {
        for (k in 0..10) {
            val f = k / 10f
            val x = s * w + f * w
            val y = top + dip * 4f * f * (1f - f)
            drawCircle(if (k % 2 == 0) Marigold else Palette.sunflower, 6.5f.dp.toPx(), Offset(x, y))
        }
        // A mango-leaf pair hanging from each tie, swaying a little.
        val lx = s * w
        rotate(6f * wave(t, s * 0.13f), Offset(lx, top)) {
            for (d in listOf(-1f, 1f)) {
                val p = Path().apply {
                    moveTo(lx, top)
                    quadraticBezierTo(lx + d * 9.dp.toPx(), top + 14.dp.toPx(), lx + d * 3.dp.toPx(), top + 30.dp.toPx())
                    quadraticBezierTo(lx + d * 0.5f.dp.toPx(), top + 14.dp.toPx(), lx, top)
                }
                drawPath(p, Palette.mintInk)
            }
        }
    }
}

/** Saffron, white and green pennants on a string across the top margin. */
private fun DrawScope.bunting(t: Float) {
    val n = 18
    val w = size.width / n
    val top = 8.dp.toPx()
    drawLine(Palette.muted, Offset(0f, top), Offset(size.width, top), 1.5f.dp.toPx())
    for (i in 0 until n) {
        val c = when (i % 3) { 0 -> Saffron; 1 -> Palette.card; else -> IndiaGreen }
        val x = i * w + w * 0.15f
        val sway = 2.dp.toPx() * wave(t, i * 0.09f)
        val p = Path().apply {
            moveTo(x, top)
            lineTo(x + w * 0.7f, top)
            lineTo(x + w * 0.35f + sway, top + 30.dp.toPx())
            close()
        }
        drawPath(p, c)
        if (i % 3 == 1) {
            drawPath(p, Palette.hairline, style = Stroke(1.dp.toPx()))
            drawCircle(Navy, 3.dp.toPx(), Offset(x + w * 0.35f, top + 10.dp.toPx()), style = Stroke(1.dp.toPx()))
        }
    }
}

/** Clay diyas along the bottom margin, their flames flickering out of step. */
private fun DrawScope.diyas(t: Float) {
    val n = 14
    val w = size.width / n
    val base = size.height - 10.dp.toPx()
    for (i in 0 until n) {
        val cx = i * w + w / 2f
        val bowl = Path().apply {
            moveTo(cx - 16.dp.toPx(), base - 10.dp.toPx())
            quadraticBezierTo(cx, base + 8.dp.toPx(), cx + 16.dp.toPx(), base - 10.dp.toPx())
            close()
        }
        drawPath(bowl, Clay)
        val flick = 1f + 0.12f * wave(t, i * 0.37f)
        val fh = 18.dp.toPx() * flick
        val flame = Path().apply {
            moveTo(cx, base - 10.dp.toPx() - fh)
            quadraticBezierTo(cx + 7.dp.toPx(), base - 14.dp.toPx(), cx, base - 10.dp.toPx())
            quadraticBezierTo(cx - 7.dp.toPx(), base - 14.dp.toPx(), cx, base - 10.dp.toPx() - fh)
        }
        drawPath(flame, Palette.sunflower)
        drawCircle(Palette.coral, 2.5f.dp.toPx(), Offset(cx, base - 13.dp.toPx()))
    }
}

/** Soft colour clouds drifting up and across, behind the cards. */
private fun DrawScope.puffs(t: Float) {
    val colours = listOf(HoliPink, Palette.sky, Palette.sunflower, Palette.mint, Palette.lavender, Palette.coral)
    for (i in 0 until 12) {
        val p = ((t + i / 12f) % 1f)
        val x = size.width * ((i * 0.37f + p * 0.3f) % 1f)
        val y = size.height * (1f - p)
        val r = (40 + (i % 4) * 18).dp.toPx() * (0.6f + 0.4f * p)
        drawCircle(colours[i % colours.size].copy(alpha = 0.26f * (1f - p * 0.5f)), r, Offset(x, y))
    }
}

/** Kites bobbing in the sky with their tails. */
private fun DrawScope.kites(t: Float) {
    val colours = listOf(Palette.coral, Palette.sky, Palette.sunflower, Palette.mint, Palette.lavender)
    for (i in 0 until 5) {
        // The right half of the sky, clear of Tubby's greeting on the left.
        val cx = size.width * (0.52f + i * 0.1f) + 18.dp.toPx() * wave(t, i * 0.2f)
        val cy = size.height * (0.035f + 0.025f * (i % 2)) + 8.dp.toPx() * wave(t * 2f, i * 0.31f)
        val s = 22.dp.toPx()
        rotate(12f * wave(t, i * 0.17f), Offset(cx, cy)) {
            val p = Path().apply { moveTo(cx, cy - s); lineTo(cx + s * 0.75f, cy); lineTo(cx, cy + s * 1.1f); lineTo(cx - s * 0.75f, cy); close() }
            drawPath(p, colours[i].copy(alpha = 0.75f))
            drawLine(Palette.muted.copy(alpha = 0.4f), Offset(cx, cy + s * 1.1f), Offset(cx - 14.dp.toPx(), cy + s * 2.4f), 1.5f.dp.toPx(), StrokeCap.Round)
        }
    }
}

/** Balloons rising slowly from the bottom. */
private fun DrawScope.balloons(t: Float) {
    val colours = listOf(Palette.coral, Palette.sky, Palette.sunflower, Palette.mint, Palette.lavender, HoliPink)
    for (i in 0 until 8) {
        val p = (t + i / 8f) % 1f
        val x = size.width * (0.06f + i * 0.125f) + 14.dp.toPx() * wave(t * 3f, i * 0.2f)
        val y = size.height * (1.1f - p * 1.2f)
        val c = colours[i % colours.size].copy(alpha = 0.5f)
        drawOval(c, Offset(x - 16.dp.toPx(), y - 20.dp.toPx()), Size(32.dp.toPx(), 40.dp.toPx()))
        drawLine(Palette.muted.copy(alpha = 0.3f), Offset(x, y + 20.dp.toPx()), Offset(x, y + 48.dp.toPx()), 1.dp.toPx())
    }
}

/** Gentle snowfall. */
private fun DrawScope.snow(t: Float) {
    for (i in 0 until 40) {
        val p = (t * 1.5f + i / 40f) % 1f
        val x = size.width * ((i * 0.618f) % 1f) + 10.dp.toPx() * wave(t * 4f, i * 0.1f)
        val y = size.height * p
        drawCircle(Palette.sky.copy(alpha = 0.38f), (2 + i % 3).dp.toPx(), Offset(x, y))
    }
}

/** Little four-point stars that twinkle in turn. */
private fun DrawScope.twinkles(t: Float) {
    for (i in 0 until 16) {
        val x = size.width * ((i * 0.381f + 0.05f) % 1f)
        val y = size.height * ((i * 0.233f + 0.08f) % 0.45f)
        val a = 0.25f + 0.35f * (0.5f + 0.5f * wave(t * 3f, i * 0.29f))
        val r = (5 + i % 3 * 2).dp.toPx()
        val p = Path().apply {
            moveTo(x, y - r); quadraticBezierTo(x, y, x + r, y); quadraticBezierTo(x, y, x, y + r)
            quadraticBezierTo(x, y, x - r, y); quadraticBezierTo(x, y, x, y - r); close()
        }
        drawPath(p, Palette.sunflower.copy(alpha = a))
    }
}

/** Lanterns hanging from the top, swaying. */
private fun DrawScope.lanterns(t: Float) {
    val colours = listOf(Palette.sunflower, Palette.coral, Palette.mint)
    for (i in 0 until 6) {
        // Hung across the right half, clear of the greeting.
        val ax = size.width * (0.5f + i * 0.09f)
        val len = (10 + (i % 3) * 12).dp.toPx()
        rotate(5f * wave(t * 2f, i * 0.23f), Offset(ax, 0f)) {
            drawLine(Palette.muted.copy(alpha = 0.4f), Offset(ax, 0f), Offset(ax, len), 1.dp.toPx())
            drawRoundRect(colours[i % 3].copy(alpha = 0.55f), Offset(ax - 12.dp.toPx(), len), Size(24.dp.toPx(), 32.dp.toPx()), CornerRadius(8.dp.toPx()))
            drawRect(Palette.ink.copy(alpha = 0.35f), Offset(ax - 8.dp.toPx(), len - 3.dp.toPx()), Size(16.dp.toPx(), 4.dp.toPx()))
        }
    }
}

