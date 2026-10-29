package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.runtime.Composable
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
import kotlin.math.cos
import kotlin.math.sin

/**
 * The picture library for written banks (spec §4): flat shapes from the
 * palette on a 100×100 grid, 2–4 fills, no outlines thicker than 3. Bank
 * items name a picture by id; [ids] is what the validator accepts.
 */
object Pictures {
    private val art: Map<String, DrawScope.() -> Unit> = mapOf(
        "sun" to { sun() }, "moon" to { moon() }, "star" to { star() }, "cloud" to { cloud() }, "rain" to { rain() },
        "tree" to { tree() }, "flower" to { flower() }, "leaf" to { leaf() }, "seed" to { seed() },
        "apple" to { apple() }, "mango" to { mango() }, "banana" to { banana() }, "carrot" to { carrot() }, "egg" to { egg() },
        "fish" to { fish() }, "cat" to { cat() }, "dog" to { dog() }, "cow" to { cow() }, "bird" to { bird() }, "ant" to { ant() },
        "ball" to { ball() }, "cup" to { cup() }, "book" to { book() }, "pencil" to { pencil() }, "house" to { house() },
        "car" to { car() }, "bus" to { bus() }, "boat" to { boat() }, "drop" to { drop() }, "fire" to { fire() },
        "eye" to { eye() }, "ear" to { ear() }, "nose" to { nose() }, "hand" to { hand() }, "tooth" to { tooth() },
    )

    val ids: Set<String> get() = art.keys

    fun draw(scope: DrawScope, id: String) {
        val f = art[id] ?: return
        val k = scope.size.minDimension / 100f
        scope.scale(k, k, pivot = Offset.Zero) { f() }
    }
}

@Composable
fun PictureArt(id: String, modifier: Modifier = Modifier) {
    Canvas(modifier.aspectRatio(1f)) { Pictures.draw(this, id) }
}

private val Brown = Color(0xFF8A5A00)
private val Grey = Color(0xFF9AA3B5)
private val Pink = Color(0xFFFFB3A6)

private fun DrawScope.sun() {
    for (i in 0 until 8) {
        val a = Math.toRadians(i * 45.0)
        drawLine(Palette.sunflower, Offset(50f + 30f * cos(a).toFloat(), 50f + 30f * sin(a).toFloat()), Offset(50f + 44f * cos(a).toFloat(), 50f + 44f * sin(a).toFloat()), 6f, StrokeCap.Round)
    }
    drawCircle(Palette.sunflower, 24f, Offset(50f, 50f))
}

private fun DrawScope.moon() {
    drawCircle(Palette.sunflowerSoft, 34f, Offset(50f, 50f))
    drawCircle(Palette.canvas, 30f, Offset(66f, 40f))
}

private fun DrawScope.star() {
    val p = Path()
    for (i in 0 until 10) {
        val r = if (i % 2 == 0) 42f else 18f
        val a = Math.toRadians(-90.0 + i * 36.0)
        val x = 50f + r * cos(a).toFloat()
        val y = 52f + r * sin(a).toFloat()
        if (i == 0) p.moveTo(x, y) else p.lineTo(x, y)
    }
    p.close()
    drawPath(p, Palette.sunflower)
}

private fun DrawScope.cloud() {
    drawCircle(Palette.trail, 20f, Offset(34f, 56f))
    drawCircle(Palette.trail, 26f, Offset(56f, 46f))
    drawCircle(Palette.trail, 18f, Offset(74f, 58f))
    drawRoundRect(Palette.trail, Offset(18f, 56f), Size(72f, 20f), CornerRadius(10f))
}

private fun DrawScope.rain() {
    cloud()
    for (x in listOf(30f, 50f, 70f)) drawLine(Palette.sky, Offset(x, 82f), Offset(x - 4f, 94f), 4f, StrokeCap.Round)
}

private fun DrawScope.tree() {
    drawRect(Brown, Offset(44f, 56f), Size(12f, 38f))
    drawCircle(Palette.mint, 30f, Offset(50f, 40f))
    drawCircle(Palette.mintInk, 12f, Offset(38f, 34f))
}

private fun DrawScope.flower() {
    drawLine(Palette.mintInk, Offset(50f, 56f), Offset(50f, 96f), 5f)
    for (i in 0 until 6) {
        val a = Math.toRadians(i * 60.0)
        drawCircle(Palette.coral, 13f, Offset(50f + 16f * cos(a).toFloat(), 40f + 16f * sin(a).toFloat()))
    }
    drawCircle(Palette.sunflower, 10f, Offset(50f, 40f))
}

private fun DrawScope.leaf() {
    val p = Path().apply { moveTo(20f, 80f); cubicTo(20f, 30f, 60f, 14f, 86f, 16f); cubicTo(86f, 50f, 64f, 82f, 20f, 80f); close() }
    drawPath(p, Palette.mint)
    drawLine(Palette.mintInk, Offset(20f, 80f), Offset(76f, 26f), 3f, StrokeCap.Round)
}

private fun DrawScope.seed() {
    drawOval(Brown, Offset(30f, 40f), Size(40f, 28f))
    drawPath(Path().apply { moveTo(50f, 40f); quadraticBezierTo(48f, 20f, 64f, 14f) }, Palette.mint, style = Stroke(4f, cap = StrokeCap.Round))
}

private fun DrawScope.apple() {
    drawCircle(Palette.coral, 30f, Offset(40f, 58f))
    drawCircle(Palette.coral, 30f, Offset(60f, 58f))
    drawLine(Brown, Offset(50f, 30f), Offset(54f, 16f), 4f, StrokeCap.Round)
    drawOval(Palette.mint, Offset(54f, 16f), Size(20f, 10f))
}

private fun DrawScope.mango() {
    drawOval(Palette.sunflower, Offset(18f, 24f), Size(64f, 66f))
    drawOval(Palette.mint, Offset(46f, 10f), Size(22f, 12f))
}

private fun DrawScope.banana() {
    drawPath(Path().apply { moveTo(16f, 30f); quadraticBezierTo(40f, 92f, 88f, 64f); quadraticBezierTo(46f, 70f, 28f, 26f); close() }, Palette.sunflower)
    drawLine(Brown, Offset(16f, 30f), Offset(22f, 22f), 4f, StrokeCap.Round)
}

private fun DrawScope.carrot() {
    drawPath(Path().apply { moveTo(34f, 30f); lineTo(66f, 30f); lineTo(50f, 94f); close() }, Palette.coral)
    drawLine(Palette.mint, Offset(50f, 30f), Offset(40f, 10f), 5f, StrokeCap.Round)
    drawLine(Palette.mint, Offset(50f, 30f), Offset(60f, 10f), 5f, StrokeCap.Round)
}

private fun DrawScope.egg() {
    drawOval(Palette.cream, Offset(28f, 14f), Size(44f, 72f))
    drawOval(Palette.outline, Offset(28f, 14f), Size(44f, 72f), style = Stroke(3f))
}

private fun DrawScope.fish() {
    drawOval(Palette.sky, Offset(14f, 32f), Size(58f, 36f))
    drawPath(Path().apply { moveTo(70f, 50f); lineTo(90f, 34f); lineTo(90f, 66f); close() }, Palette.sky)
    drawCircle(Palette.cream, 4f, Offset(30f, 46f))
}

private fun DrawScope.cat() {
    drawPath(Path().apply { moveTo(22f, 40f); lineTo(28f, 14f); lineTo(44f, 30f); close() }, Palette.sunflower)
    drawPath(Path().apply { moveTo(78f, 40f); lineTo(72f, 14f); lineTo(56f, 30f); close() }, Palette.sunflower)
    drawCircle(Palette.sunflower, 32f, Offset(50f, 56f))
    drawCircle(Palette.ink, 4f, Offset(39f, 52f))
    drawCircle(Palette.ink, 4f, Offset(61f, 52f))
    drawPath(Path().apply { moveTo(44f, 64f); quadraticBezierTo(50f, 70f, 56f, 64f) }, Palette.ink, style = Stroke(3f, cap = StrokeCap.Round))
}

private fun DrawScope.dog() {
    drawCircle(Brown, 30f, Offset(50f, 54f))
    drawOval(Palette.ink, Offset(14f, 28f), Size(18f, 36f))
    drawOval(Palette.ink, Offset(68f, 28f), Size(18f, 36f))
    drawCircle(Palette.cream, 4f, Offset(40f, 48f))
    drawCircle(Palette.cream, 4f, Offset(60f, 48f))
    drawOval(Palette.ink, Offset(43f, 58f), Size(14f, 10f))
}

private fun DrawScope.cow() {
    drawOval(Palette.cream, Offset(20f, 22f), Size(60f, 64f))
    drawOval(Palette.ink, Offset(26f, 30f), Size(18f, 16f))
    drawOval(Pink, Offset(32f, 62f), Size(36f, 22f))
    drawCircle(Palette.ink, 3.5f, Offset(42f, 72f))
    drawCircle(Palette.ink, 3.5f, Offset(58f, 72f))
    drawLine(Brown, Offset(28f, 24f), Offset(18f, 12f), 5f, StrokeCap.Round)
    drawLine(Brown, Offset(72f, 24f), Offset(82f, 12f), 5f, StrokeCap.Round)
}

private fun DrawScope.bird() {
    drawOval(Palette.lavender, Offset(20f, 36f), Size(56f, 40f))
    drawCircle(Palette.lavender, 16f, Offset(70f, 38f))
    drawPath(Path().apply { moveTo(84f, 38f); lineTo(96f, 42f); lineTo(84f, 46f); close() }, Palette.sunflower)
    drawCircle(Palette.ink, 3f, Offset(74f, 34f))
    drawLine(Palette.ink, Offset(44f, 76f), Offset(44f, 88f), 3f)
    drawLine(Palette.ink, Offset(54f, 76f), Offset(54f, 88f), 3f)
}

private fun DrawScope.ant() {
    for (x in listOf(28f, 50f, 72f)) drawCircle(Palette.ink, if (x == 50f) 10f else 13f, Offset(x, 52f))
    for (x in listOf(40f, 50f, 60f)) {
        drawLine(Palette.ink, Offset(x, 52f), Offset(x - 8f, 74f), 3f, StrokeCap.Round)
        drawLine(Palette.ink, Offset(x, 52f), Offset(x + 8f, 30f), 3f, StrokeCap.Round)
    }
}

private fun DrawScope.ball() {
    drawCircle(Palette.coral, 36f, Offset(50f, 50f))
    drawArc(Palette.cream, -40f, 80f, false, Offset(14f, 14f), Size(72f, 72f), style = Stroke(6f))
    drawArc(Palette.cream, 140f, 80f, false, Offset(14f, 14f), Size(72f, 72f), style = Stroke(6f))
}

private fun DrawScope.cup() {
    drawRoundRect(Palette.sky, Offset(24f, 30f), Size(42f, 52f), CornerRadius(8f))
    drawArc(Palette.sky, -90f, 180f, false, Offset(56f, 40f), Size(26f, 28f), style = Stroke(6f))
    drawLine(Palette.outline, Offset(36f, 22f), Offset(40f, 12f), 3f, StrokeCap.Round)
    drawLine(Palette.outline, Offset(50f, 22f), Offset(54f, 12f), 3f, StrokeCap.Round)
}

private fun DrawScope.book() {
    drawRoundRect(Palette.coral, Offset(18f, 22f), Size(32f, 58f), CornerRadius(4f))
    drawRoundRect(Palette.sky, Offset(50f, 22f), Size(32f, 58f), CornerRadius(4f))
    drawLine(Palette.cream, Offset(50f, 22f), Offset(50f, 80f), 3f)
}

private fun DrawScope.pencil() {
    rotate(-35f, Offset(50f, 50f)) {
        drawRect(Palette.sunflower, Offset(24f, 42f), Size(48f, 16f))
        drawPath(Path().apply { moveTo(72f, 42f); lineTo(88f, 50f); lineTo(72f, 58f); close() }, Palette.cream)
        drawRect(Pink, Offset(16f, 42f), Size(8f, 16f))
    }
}

private fun DrawScope.house() {
    drawRect(Palette.cream, Offset(24f, 46f), Size(52f, 40f))
    drawPath(Path().apply { moveTo(16f, 48f); lineTo(50f, 16f); lineTo(84f, 48f); close() }, Palette.coral)
    drawRect(Brown, Offset(44f, 62f), Size(14f, 24f))
}

private fun DrawScope.car() {
    drawRoundRect(Palette.coral, Offset(12f, 46f), Size(76f, 26f), CornerRadius(8f))
    drawRoundRect(Palette.coral, Offset(28f, 30f), Size(42f, 22f), CornerRadius(8f))
    drawRect(Palette.trail, Offset(34f, 34f), Size(30f, 14f))
    drawCircle(Palette.ink, 9f, Offset(30f, 74f))
    drawCircle(Palette.ink, 9f, Offset(70f, 74f))
}

private fun DrawScope.bus() {
    drawRoundRect(Palette.sunflower, Offset(10f, 26f), Size(80f, 48f), CornerRadius(8f))
    for (x in listOf(18f, 38f, 58f)) drawRect(Palette.trail, Offset(x, 34f), Size(16f, 14f))
    drawCircle(Palette.ink, 8f, Offset(28f, 76f))
    drawCircle(Palette.ink, 8f, Offset(72f, 76f))
}

private fun DrawScope.boat() {
    drawPath(Path().apply { moveTo(14f, 62f); lineTo(86f, 62f); lineTo(74f, 82f); lineTo(26f, 82f); close() }, Brown)
    drawLine(Palette.ink, Offset(50f, 62f), Offset(50f, 16f), 3f)
    drawPath(Path().apply { moveTo(52f, 18f); lineTo(80f, 56f); lineTo(52f, 56f); close() }, Palette.cream)
    drawRect(Palette.sky, Offset(0f, 84f), Size(100f, 8f))
}

private fun DrawScope.drop() {
    drawPath(Path().apply { moveTo(50f, 12f); cubicTo(70f, 40f, 80f, 54f, 80f, 64f); cubicTo(80f, 82f, 66f, 92f, 50f, 92f); cubicTo(34f, 92f, 20f, 82f, 20f, 64f); cubicTo(20f, 54f, 30f, 40f, 50f, 12f); close() }, Palette.sky)
}

private fun DrawScope.fire() {
    drawPath(Path().apply { moveTo(50f, 10f); cubicTo(74f, 34f, 82f, 52f, 78f, 68f); cubicTo(74f, 86f, 60f, 92f, 50f, 92f); cubicTo(36f, 92f, 22f, 84f, 22f, 66f); cubicTo(22f, 48f, 40f, 40f, 50f, 10f); close() }, Palette.coral)
    drawOval(Palette.sunflower, Offset(38f, 56f), Size(24f, 32f))
}

private fun DrawScope.eye() {
    drawOval(Palette.cream, Offset(10f, 30f), Size(80f, 40f))
    drawOval(Palette.outline, Offset(10f, 30f), Size(80f, 40f), style = Stroke(3f))
    drawCircle(Palette.sky, 16f, Offset(50f, 50f))
    drawCircle(Palette.ink, 7f, Offset(50f, 50f))
}

private fun DrawScope.ear() {
    drawOval(Pink, Offset(28f, 14f), Size(44f, 72f))
    drawArc(Brown, 200f, 200f, false, Offset(38f, 26f), Size(24f, 40f), style = Stroke(4f, cap = StrokeCap.Round))
}

private fun DrawScope.nose() {
    drawPath(Path().apply { moveTo(50f, 16f); cubicTo(56f, 40f, 70f, 60f, 70f, 70f); cubicTo(70f, 82f, 30f, 82f, 30f, 70f); cubicTo(30f, 60f, 44f, 40f, 50f, 16f); close() }, Pink)
    drawCircle(Brown, 4f, Offset(42f, 72f))
    drawCircle(Brown, 4f, Offset(58f, 72f))
}

private fun DrawScope.hand() {
    drawRoundRect(Pink, Offset(28f, 46f), Size(44f, 44f), CornerRadius(14f))
    for ((i, h) in listOf(32f, 40f, 38f, 30f).withIndex()) drawRoundRect(Pink, Offset(30f + i * 10.5f, 46f - h), Size(9f, h + 8f), CornerRadius(4.5f))
    drawRoundRect(Pink, Offset(14f, 54f), Size(22f, 10f), CornerRadius(5f))
}

private fun DrawScope.tooth() {
    drawPath(Path().apply { moveTo(26f, 24f); cubicTo(40f, 14f, 60f, 14f, 74f, 24f); cubicTo(80f, 44f, 72f, 60f, 68f, 88f); lineTo(58f, 88f); lineTo(50f, 64f); lineTo(42f, 88f); lineTo(32f, 88f); cubicTo(28f, 60f, 20f, 44f, 26f, 24f); close() }, Palette.cream)
    drawPath(Path().apply { moveTo(26f, 24f); cubicTo(40f, 14f, 60f, 14f, 74f, 24f) }, Palette.outline, style = Stroke(3f))
}
