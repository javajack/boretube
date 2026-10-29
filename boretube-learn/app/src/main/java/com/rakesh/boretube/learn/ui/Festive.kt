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
import androidx.compose.ui.graphics.drawscope.scale
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
private val Kumkum = Color(0xFFD62828)
private val PineGreen = Color(0xFF1E7B4F)
private val Peacock = Color(0xFF0F7C8C)
private val WarmWhite = Color(0xFFFFE9B0)

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
        if (Decor.crescent in decor) crescent()
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
        if (Decor.toran in decor) toran(t, listOf(Marigold, Palette.sunflower))
        if (Decor.redToran in decor) toran(t, listOf(Kumkum, Palette.sunflower))
        if (Decor.garbaToran in decor) toran(t, listOf(Palette.coral, Palette.sunflower, Palette.mint, Palette.lavender, Palette.sky))
        if (Decor.bunting in decor) bunting(t)
        if (Decor.fairyLights in decor) lights(t, listOf(Kumkum, Palette.sunflower, IndiaGreen, Palette.sky))
        if (Decor.warmLights in decor) lights(t, listOf(Palette.sunflower, Marigold))
        if (Decor.rakhis in decor) rakhis(t)
        if (Decor.matki in decor) matkis(t)
        if (Decor.diyas in decor) diyas(t)
        if (Decor.modaks in decor) modaks()
        if (Decor.dandiya in decor) dandiyas(t)
        if (Decor.pookalam in decor) pookalams(t)
        if (Decor.xmasTree in decor) xmasTree(t)
    }
}

private val BACKDROP = setOf(Decor.puffs, Decor.kites, Decor.balloons, Decor.snow, Decor.twinkles, Decor.lanterns, Decor.crescent)
private val FRAME = setOf(
    Decor.toran, Decor.redToran, Decor.garbaToran, Decor.bunting, Decor.diyas, Decor.fairyLights, Decor.warmLights,
    Decor.rakhis, Decor.matki, Decor.modaks, Decor.dandiya, Decor.pookalam, Decor.xmasTree,
)

private fun wave(t: Float, phase: Float) = sin((t + phase) * 2f * PI.toFloat())

/** A flower garland in swags across the top margin (marigold, kumkum-red or garba colours), mango leaves at each tie. */
private fun DrawScope.toran(t: Float, flowers: List<Color>) {
    val swags = 8
    val w = size.width / swags
    val top = 6.dp.toPx()
    val dip = 26.dp.toPx()
    for (s in 0 until swags) {
        for (k in 0..10) {
            val f = k / 10f
            val x = s * w + f * w
            val y = top + dip * 4f * f * (1f - f)
            drawCircle(flowers[(k + s) % flowers.size], 6.5f.dp.toPx(), Offset(x, y))
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
        drawCircle(Palette.sky.copy(alpha = 0.5f), (3 + i % 3 * 2).dp.toPx(), Offset(x, y))
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

/** A string of round bulbs drooping across the top margin, blinking in turn. */
private fun DrawScope.lights(t: Float, colours: List<Color>) {
    val n = 26
    val w = size.width / n
    val top = 6.dp.toPx()
    val wire = Path()
    for (i in 0..n) {
        val x = i * w
        val y = top + 10.dp.toPx() * (if (i % 2 == 0) 0f else 1f)
        if (i == 0) wire.moveTo(x, y) else wire.lineTo(x, y)
    }
    drawPath(wire, Palette.muted.copy(alpha = 0.6f), style = Stroke(1.5f.dp.toPx()))
    for (i in 0 until n) {
        val x = i * w + w / 2f
        val y = top + 5.dp.toPx() + 12.dp.toPx()
        val on = ((t * 4f).toInt() + i) % 3 != 0
        val c = colours[i % colours.size]
        if (on) drawCircle(c.copy(alpha = 0.3f), 11.dp.toPx(), Offset(x, y))
        drawOval(if (on) c else c.copy(alpha = 0.45f), Offset(x - 5.dp.toPx(), y - 7.dp.toPx()), Size(10.dp.toPx(), 14.dp.toPx()))
        drawRect(Palette.muted, Offset(x - 3.dp.toPx(), y - 11.dp.toPx()), Size(6.dp.toPx(), 4.dp.toPx()))
    }
}

/** Rakhi threads: a red-and-gold thread along the top with a round flower rakhi every so often. */
private fun DrawScope.rakhis(t: Float) {
    val top = 16.dp.toPx()
    drawLine(Kumkum, Offset(0f, top), Offset(size.width, top), 3.dp.toPx())
    drawLine(Palette.sunflower, Offset(0f, top + 3.dp.toPx()), Offset(size.width, top + 3.dp.toPx()), 1.5f.dp.toPx())
    val n = 9
    for (i in 0 until n) {
        val cx = size.width * (i + 0.5f) / n
        val r = 14.dp.toPx()
        rotate(15f * wave(t, i * 0.11f), Offset(cx, top)) {
            for (k in 0 until 8) {
                val a = k * PI.toFloat() / 4f
                drawCircle(if (k % 2 == 0) Palette.coral else Palette.sunflower, 6.dp.toPx(), Offset(cx + r * 0.75f * kotlin.math.cos(a), top + r * 0.75f * sin(a)))
            }
            drawCircle(Palette.sunflowerInk, 6.dp.toPx(), Offset(cx, top))
            drawCircle(Palette.sunflower, 3.dp.toPx(), Offset(cx, top))
        }
    }
}

/** Matki pots hanging from the top on strings, decorated, with a peacock feather. */
private fun DrawScope.matkis(t: Float) {
    val n = 6
    for (i in 0 until n) {
        val ax = size.width * (0.47f + i * 0.09f)
        val len = (8 + (i % 2) * 8).dp.toPx()
        rotate(5f * wave(t * 0.5f, i * 0.21f), Offset(ax, 0f)) {
            drawLine(Palette.muted.copy(alpha = 0.6f), Offset(ax, 0f), Offset(ax, len), 1.5f.dp.toPx())
            val cy = len + 14.dp.toPx()
            drawCircle(Clay, 14.dp.toPx(), Offset(ax, cy))
            drawRect(Clay, Offset(ax - 7.dp.toPx(), len - 1.dp.toPx()), Size(14.dp.toPx(), 6.dp.toPx()))
            drawLine(Palette.sunflower, Offset(ax - 12.dp.toPx(), cy - 2.dp.toPx()), Offset(ax + 12.dp.toPx(), cy - 2.dp.toPx()), 2.dp.toPx())
            drawCircle(Palette.card, 2.dp.toPx(), Offset(ax, cy + 5.dp.toPx()))
        }
    }
    // A peacock feather in the left margin.
    val fx = 38.dp.toPx()
    val fy = 8.dp.toPx()
    drawLine(Peacock, Offset(fx, fy + 42.dp.toPx()), Offset(fx + 6.dp.toPx(), fy), 2.dp.toPx(), StrokeCap.Round)
    drawOval(IndiaGreen.copy(alpha = 0.8f), Offset(fx - 6.dp.toPx(), fy - 4.dp.toPx()), Size(24.dp.toPx(), 30.dp.toPx()))
    drawOval(Peacock, Offset(fx - 1.dp.toPx(), fy + 2.dp.toPx()), Size(14.dp.toPx(), 18.dp.toPx()))
    drawCircle(Navy, 4.dp.toPx(), Offset(fx + 6.dp.toPx(), fy + 11.dp.toPx()))
}

/** Modaks along the bottom margin, the sweet Ganpati loves. */
private fun DrawScope.modaks() {
    val n = 14
    val w = size.width / n
    val base = size.height - 8.dp.toPx()
    for (i in 0 until n) {
        val cx = i * w + w / 2f
        val body = Path().apply {
            moveTo(cx, base - 30.dp.toPx())
            cubicTo(cx + 6.dp.toPx(), base - 24.dp.toPx(), cx + 16.dp.toPx(), base - 12.dp.toPx(), cx + 14.dp.toPx(), base - 4.dp.toPx())
            lineTo(cx - 14.dp.toPx(), base - 4.dp.toPx())
            cubicTo(cx - 16.dp.toPx(), base - 12.dp.toPx(), cx - 6.dp.toPx(), base - 24.dp.toPx(), cx, base - 30.dp.toPx())
            close()
        }
        drawPath(body, Palette.sunflowerSoft)
        drawPath(body, Palette.sunflowerInk.copy(alpha = 0.85f), style = Stroke(1.6f.dp.toPx()))
        for (k in -1..1) drawLine(Palette.sunflowerInk.copy(alpha = 0.7f), Offset(cx, base - 28.dp.toPx()), Offset(cx + k * 9.dp.toPx(), base - 5.dp.toPx()), 1.dp.toPx())
        drawOval(Palette.hairline, Offset(cx - 18.dp.toPx(), base - 5.dp.toPx()), Size(36.dp.toPx(), 6.dp.toPx()))
    }
}

/** Pairs of dandiya sticks crossed along the bottom margin, tapping together in turn. */
private fun DrawScope.dandiyas(t: Float) {
    val n = 12
    val w = size.width / n
    val base = size.height - 6.dp.toPx()
    val colours = listOf(Palette.coral, Palette.mint, Palette.lavender, Palette.sunflower, Palette.sky)
    for (i in 0 until n) {
        val cx = i * w + w / 2f
        val tap = 3.dp.toPx() * wave(t * 2f, i * 0.17f)
        for ((k, d) in listOf(-1f, 1f).withIndex()) {
            val from = Offset(cx - d * (14.dp.toPx() + tap), base)
            val to = Offset(cx + d * (14.dp.toPx() + tap), base - 36.dp.toPx())
            drawLine(colours[(i + k) % colours.size], from, to, 4.5f.dp.toPx(), StrokeCap.Round)
            // A bright grip near the bottom of each stick.
            val g = Offset(from.x + (to.x - from.x) * 0.18f, from.y + (to.y - from.y) * 0.18f)
            drawCircle(Palette.sunflowerInk, 3.dp.toPx(), g)
        }
    }
}

/** Pookalam: a flower-petal circle in each bottom corner, turning slowly. */
private fun DrawScope.pookalams(t: Float) {
    val r = 32.dp.toPx()
    for (c in listOf(Offset(44.dp.toPx(), size.height - 40.dp.toPx()), Offset(size.width - 44.dp.toPx(), size.height - 40.dp.toPx()))) {
        rotate(t * 30f, c) {
            val rings = listOf(Palette.coral to 1f, Palette.sunflower to 0.78f, Palette.mint to 0.56f, Marigold to 0.36f)
            for ((colour, f) in rings) drawCircle(colour, r * f, c)
            for (k in 0 until 12) {
                val a = k * PI.toFloat() / 6f
                drawCircle(Palette.card, 3.dp.toPx(), Offset(c.x + r * 0.67f * kotlin.math.cos(a), c.y + r * 0.67f * sin(a)))
            }
            drawCircle(Palette.lavender, r * 0.16f, c)
        }
    }
}

/** A small decorated Christmas tree in the bottom-right corner, its baubles blinking. */
private fun DrawScope.xmasTree(t: Float) {
    val cx = size.width - 60.dp.toPx()
    val base = size.height - 4.dp.toPx()
    scale(1.7f, Offset(cx, base)) { tree(t, cx, base) }
}

private fun DrawScope.tree(t: Float, cx: Float, base: Float) {
    drawRect(Clay, Offset(cx - 4.dp.toPx(), base - 10.dp.toPx()), Size(8.dp.toPx(), 10.dp.toPx()))
    for ((k, w) in listOf(30f, 24f, 17f).withIndex()) {
        val y = base - 10.dp.toPx() - k * 14.dp.toPx()
        val p = Path().apply {
            moveTo(cx - w.dp.toPx(), y)
            lineTo(cx + w.dp.toPx(), y)
            lineTo(cx, y - 22.dp.toPx())
            close()
        }
        drawPath(p, PineGreen)
    }
    val baubles = listOf(Offset(-14f, -16f), Offset(10f, -20f), Offset(-6f, -32f), Offset(12f, -40f), Offset(-10f, -48f))
    for ((i, b) in baubles.withIndex()) {
        val on = ((t * 4f).toInt() + i) % 2 == 0
        drawCircle(if (i % 2 == 0) Kumkum else Palette.sunflower, (if (on) 3.5f else 2.5f).dp.toPx(), Offset(cx + b.x.dp.toPx(), base + b.y.dp.toPx()))
    }
    val st = Offset(cx, base - 62.dp.toPx())
    drawCircle(Palette.sunflower, 5.dp.toPx(), st)
}

/** A thin crescent moon high on the right, for Eid. */
private fun DrawScope.crescent() {
    val c = Offset(size.width * 0.44f, 26.dp.toPx())
    drawCircle(Palette.sunflower.copy(alpha = 0.9f), 16.dp.toPx(), c)
    drawCircle(Palette.canvas, 14.dp.toPx(), Offset(c.x + 7.dp.toPx(), c.y - 4.dp.toPx()))
}

