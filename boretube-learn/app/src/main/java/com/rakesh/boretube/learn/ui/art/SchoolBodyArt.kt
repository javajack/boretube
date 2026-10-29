package com.rakesh.boretube.learn.ui.art

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.drawscope.translate
import com.rakesh.boretube.learn.ui.Palette
import kotlin.math.cos
import kotlin.math.sin

/** Picture library: the body (outside and inside), shapes (flat and solid), school, kitchen, clothes, tools and science. Same rules as ui/Pictures.kt (100×100 grid, flat fills from the palette). */
internal val schoolBodyArt: Map<String, DrawScope.() -> Unit> = mapOf(
    // body
    "foot" to { foot() }, "mouth" to { mouth() }, "leg" to { leg() }, "tongue" to { tongue() }, "skin" to { skin() },
    // body inside
    "heart" to { heart() }, "lungs" to { lungs() }, "brain" to { brain() }, "stomach" to { stomach() }, "bone" to { bone() }, "muscle" to { muscle() },
    // shapes
    "circle" to { circle() }, "square" to { square() }, "triangle" to { triangle() }, "rectangle" to { rectangle() }, "oval" to { oval() }, "diamond" to { diamond() },
    "cube" to { cube() }, "cone" to { cone() }, "cylinder" to { cylinder() }, "sphere" to { sphere() },
    // school
    "pen" to { pen() }, "eraser" to { eraser() }, "sharpener" to { sharpener() }, "ruler" to { ruler() }, "crayon" to { crayon() },
    "blackboard" to { blackboard() }, "schoolbag" to { schoolbag() }, "notebook" to { notebook() }, "globe" to { globe() }, "map" to { map() },
    // kitchen
    "plate" to { plate() }, "glass" to { glass() }, "bowl" to { bowl() }, "pot" to { pot() }, "pan" to { pan() }, "kettle" to { kettle() },
    "knife" to { knife() }, "fork" to { fork() }, "stove" to { stove() }, "fridge" to { fridge() }, "pressurecooker" to { pressureCooker() }, "tawa" to { tawa() },
    // clothes
    "dress" to { dress() }, "skirt" to { skirt() }, "shorts" to { shorts() }, "frock" to { frock() }, "saree" to { saree() }, "kurta" to { kurta() },
    "jacket" to { jacket() }, "sweater" to { sweater() }, "raincoat" to { raincoat() }, "gloves" to { gloves() }, "scarf" to { scarf() },
    // tools
    "saw" to { saw() }, "screwdriver" to { screwdriver() }, "spade" to { spade() }, "axe" to { axe() }, "needle" to { needle() },
    "thread" to { thread() }, "rope" to { rope() }, "torch" to { torch() },
    // science
    "bulb" to { bulb() }, "battery" to { battery() }, "wire" to { wire() }, "switch" to { switch() }, "testtube" to { testTube() },
    "beaker" to { beaker() }, "magnifier" to { magnifier() }, "compass" to { compass() }, "prism" to { prism() }, "mirror" to { mirror() },
    "thermometer" to { thermometer() },
)

// The shared extras from ui/Pictures.kt, plus a few named tones for depth and materials.
private val Brown = Color(0xFF8A5A00)
private val Grey = Color(0xFF9AA3B5)
private val Pink = Color(0xFFFFB3A6)
private val SkinLine = Color(0xFFE8907E)
private val Flesh = Color(0xFFFF8C8C)
private val FleshDark = Color(0xFFE0606A)
private val CoralDark = Color(0xFFD9502F)
private val SunDark = Color(0xFFD98A00)
private val SkyDark = Color(0xFF2563C4)
private val SkyLight = Color(0xFF9CC4FF)
private val MintLight = Color(0xFF8EE3C6)
private val LavDark = Color(0xFF6A58E0)
private val LavLight = Color(0xFFB8AEFF)
private val Steel = Color(0xFFC9D0DC)
private val SteelDark = Color(0xFF6E7890)
private val Board = Color(0xFF2E6B4F)
private val Copper = Color(0xFFE08A3C)
private val CopperDark = Color(0xFFA85E1E)
private val Wood = Color(0xFFD9A55B)

private inline fun path(block: Path.() -> Unit): Path = Path().apply(block)
private fun DrawScope.fill(c: Color, block: Path.() -> Unit) = drawPath(Path().apply(block), c)
private fun DrawScope.stroke(c: Color, w: Float, block: Path.() -> Unit) =
    drawPath(Path().apply(block), c, style = Stroke(w, cap = StrokeCap.Round, join = StrokeJoin.Round))
private fun DrawScope.line(c: Color, x1: Float, y1: Float, x2: Float, y2: Float, w: Float) =
    drawLine(c, Offset(x1, y1), Offset(x2, y2), w, StrokeCap.Round)
private fun DrawScope.rrect(c: Color, x: Float, y: Float, w: Float, h: Float, r: Float) =
    drawRoundRect(c, Offset(x, y), Size(w, h), CornerRadius(r))
private fun DrawScope.rect(c: Color, x: Float, y: Float, w: Float, h: Float) = drawRect(c, Offset(x, y), Size(w, h))
private fun DrawScope.oval(c: Color, x: Float, y: Float, w: Float, h: Float) = drawOval(c, Offset(x, y), Size(w, h))
private fun DrawScope.dot(c: Color, x: Float, y: Float, r: Float) = drawCircle(c, r, Offset(x, y))
private val C = Offset(50f, 50f)

// ---------------------------------------------------------------- body

private fun DrawScope.foot() {
    // A right footprint, toes up.
    fill(Pink) {
        moveTo(50f, 94f); cubicTo(62f, 94f, 68f, 86f, 68f, 74f); cubicTo(68f, 62f, 72f, 52f, 72f, 42f)
        cubicTo(72f, 32f, 62f, 28f, 52f, 28f); cubicTo(40f, 28f, 32f, 34f, 32f, 44f)
        cubicTo(32f, 54f, 40f, 58f, 40f, 66f); cubicTo(40f, 72f, 34f, 76f, 34f, 82f); cubicTo(34f, 90f, 42f, 94f, 50f, 94f); close()
    }
    dot(Pink, 40f, 20f, 9f); dot(Pink, 54f, 15f, 6f); dot(Pink, 63.5f, 17.5f, 5.5f); dot(Pink, 70.5f, 23f, 5f); dot(Pink, 75f, 30.5f, 4.5f)
}

private fun DrawScope.mouth() {
    val opening = path { moveTo(20f, 48f); cubicTo(36f, 44f, 64f, 44f, 80f, 48f); cubicTo(70f, 66f, 30f, 66f, 20f, 48f); close() }
    fill(Palette.coral) {
        moveTo(10f, 46f); cubicTo(22f, 36f, 36f, 32f, 50f, 38f); cubicTo(64f, 32f, 78f, 36f, 90f, 46f); cubicTo(80f, 74f, 20f, 74f, 10f, 46f); close()
    }
    drawPath(opening, Color(0xFF8E2A1A))
    clipPath(opening) {
        oval(Pink, 36f, 53f, 28f, 14f)
        fill(Palette.cream) { moveTo(18f, 46f); lineTo(82f, 46f); lineTo(82f, 52f); cubicTo(62f, 50f, 38f, 50f, 18f, 52f); close() }
    }
}

private fun DrawScope.leg() {
    rrect(Palette.sky, 30f, 4f, 36f, 18f, 4f)
    fill(Pink) {
        moveTo(34f, 18f); lineTo(62f, 18f); lineTo(62f, 46f); cubicTo(62f, 52f, 64f, 56f, 62f, 60f); lineTo(60f, 80f)
        cubicTo(60f, 82f, 62f, 82f, 66f, 82f); cubicTo(80f, 82f, 86f, 84f, 86f, 89f); cubicTo(86f, 92f, 84f, 93f, 80f, 93f)
        lineTo(42f, 93f); cubicTo(38f, 93f, 38f, 90f, 38f, 86f); lineTo(40f, 78f); cubicTo(34f, 68f, 32f, 58f, 36f, 48f); close()
    }
}

private fun DrawScope.tongue() {
    oval(Palette.coral, 16f, 12f, 68f, 36f)
    val inside = path { addOval(Rect(24f, 18f, 76f, 42f)) }
    drawPath(inside, Color(0xFF8E2A1A))
    clipPath(inside) { rect(Palette.cream, 24f, 18f, 52f, 6f) }
    fill(Color(0xFFFF8FA3)) { moveTo(32f, 30f); lineTo(68f, 30f); lineTo(68f, 64f); cubicTo(68f, 90f, 32f, 90f, 32f, 64f); close() }
    line(Color(0xFFE0607A), 50f, 40f, 50f, 66f, 3f)
}

private fun DrawScope.skin() {
    rotate(-30f, C) {
        rrect(Pink, 6f, 34f, 88f, 32f, 16f)
        for ((x, y) in listOf(16f to 44f, 24f to 56f, 30f to 42f, 70f to 44f, 78f to 56f, 86f to 46f)) line(SkinLine, x, y, x + 3f, y - 3f, 2f)
        rrect(Color(0xFFF3C58F), 40f, 28f, 20f, 44f, 6f)
        rrect(Palette.outline, 43f, 40f, 14f, 20f, 3f)
        for ((x, y) in listOf(47f to 45f, 53f to 45f, 47f to 55f, 53f to 55f)) dot(Color(0xFFD9A55B), x, y, 1.4f)
    }
}

// ---------------------------------------------------------------- body inside

private fun DrawScope.heart() {
    rrect(Palette.sky, 26f, 12f, 11f, 30f, 5.5f)
    stroke(CoralDark, 10f) { moveTo(46f, 36f); cubicTo(44f, 12f, 70f, 6f, 72f, 28f) }
    line(CoralDark, 52f, 16f, 51f, 6f, 5f); line(CoralDark, 60f, 13f, 62f, 5f, 5f)
    fill(Palette.coral) {
        moveTo(50f, 30f); cubicTo(40f, 22f, 18f, 26f, 20f, 48f); cubicTo(22f, 66f, 42f, 80f, 56f, 92f)
        cubicTo(70f, 78f, 84f, 62f, 82f, 46f); cubicTo(80f, 30f, 62f, 24f, 50f, 30f); close()
    }
    line(CoralDark, 54f, 42f, 60f, 70f, 3f)
    oval(Pink, 28f, 38f, 9f, 16f)
}

private fun DrawScope.lungs() {
    val lung = Color(0xFFFF9EAE)
    val left = path {
        moveTo(44f, 34f); cubicTo(30f, 26f, 14f, 40f, 14f, 66f); cubicTo(14f, 84f, 26f, 90f, 36f, 86f); cubicTo(44f, 82f, 46f, 76f, 46f, 66f); lineTo(46f, 40f); close()
    }
    drawPath(left, lung)
    scaleX(-1f) { drawPath(left, lung) }
    val pipe = FleshDark
    line(pipe, 50f, 10f, 50f, 42f, 8f)
    for (y in listOf(16f, 23f, 30f, 37f)) line(Pink, 47f, y, 53f, y, 2f)
    stroke(pipe, 5f) { moveTo(50f, 42f); lineTo(40f, 50f); lineTo(32f, 62f) }
    stroke(pipe, 5f) { moveTo(50f, 42f); lineTo(60f, 50f); lineTo(68f, 62f) }
    stroke(pipe, 3f) { moveTo(40f, 50f); lineTo(28f, 50f) }
    stroke(pipe, 3f) { moveTo(60f, 50f); lineTo(72f, 50f) }
    stroke(pipe, 3f) { moveTo(36f, 56f); lineTo(38f, 72f) }
    stroke(pipe, 3f) { moveTo(64f, 56f); lineTo(62f, 72f) }
}

private inline fun DrawScope.scaleX(sx: Float, block: DrawScope.() -> Unit) {
    drawContext.transform.scale(sx, 1f, C); block(); drawContext.transform.scale(1f / sx, 1f, C)
}

private fun DrawScope.brain() {
    val pink = Color(0xFFFFA3B5)
    val dark = Color(0xFFF07F96)
    rrect(dark, 52f, 64f, 12f, 26f, 6f)
    oval(dark, 58f, 60f, 28f, 20f)
    for ((x, y, r) in listOf(Triple(28f, 40f, 16f), Triple(44f, 30f, 17f), Triple(62f, 30f, 17f), Triple(76f, 44f, 14f), Triple(24f, 58f, 13f), Triple(50f, 52f, 22f), Triple(70f, 58f, 12f))) dot(pink, x, y, r)
    val fold = dark
    stroke(fold, 3f) { moveTo(26f, 32f); quadraticBezierTo(36f, 40f, 28f, 50f) }
    stroke(fold, 3f) { moveTo(44f, 20f); quadraticBezierTo(52f, 32f, 42f, 40f); quadraticBezierTo(36f, 48f, 46f, 56f) }
    stroke(fold, 3f) { moveTo(62f, 20f); quadraticBezierTo(56f, 32f, 64f, 40f) }
    stroke(fold, 3f) { moveTo(82f, 42f); quadraticBezierTo(70f, 46f, 74f, 56f) }
    stroke(fold, 3f) { moveTo(18f, 60f); quadraticBezierTo(30f, 56f, 36f, 64f) }
    stroke(fold, 3f) { moveTo(54f, 48f); quadraticBezierTo(62f, 54f, 58f, 64f) }
}

private fun DrawScope.stomach() {
    val c = Color(0xFFFF9478)
    fill(c) {
        moveTo(40f, 6f); lineTo(52f, 6f); lineTo(52f, 22f)
        cubicTo(78f, 16f, 90f, 46f, 80f, 68f); cubicTo(70f, 90f, 40f, 92f, 28f, 80f)
        lineTo(16f, 82f); lineTo(14f, 70f); lineTo(28f, 66f)
        cubicTo(40f, 72f, 56f, 64f, 56f, 50f); cubicTo(56f, 38f, 42f, 36f, 40f, 24f); close()
    }
    stroke(Palette.coral, 3f) { moveTo(62f, 34f); quadraticBezierTo(72f, 46f, 68f, 62f) }
    stroke(Palette.coral, 3f) { moveTo(70f, 30f); quadraticBezierTo(80f, 46f, 76f, 66f) }
    stroke(Palette.coral, 3f) { moveTo(40f, 80f); quadraticBezierTo(56f, 82f, 66f, 74f) }
}

private fun DrawScope.bone() {
    rotate(35f, C) {
        for ((col, d) in listOf(Palette.outline to 3f, Palette.cream to 0f)) {
            rrect(col, 43f - d, 24f, 14f + 2 * d, 54f, 7f)
            dot(col, 40f, 20f, 10f + d); dot(col, 59f, 21f, 8f + d)
            dot(col, 41f, 81f, 10f + d); dot(col, 59f, 81f, 10f + d)
        }
    }
}

private fun DrawScope.muscle() {
    // A flexed arm in a short sleeve: the bicep bulges.
    fill(Pink) {
        moveTo(14f, 60f); cubicTo(20f, 40f, 50f, 32f, 60f, 48f); lineTo(60f, 32f); lineTo(84f, 30f)
        cubicTo(86f, 52f, 86f, 70f, 80f, 80f); cubicTo(74f, 90f, 44f, 88f, 14f, 88f); close()
    }
    fill(Flesh) { moveTo(18f, 58f); cubicTo(24f, 42f, 50f, 36f, 58f, 50f); cubicTo(48f, 62f, 32f, 64f, 18f, 58f); close() }
    stroke(FleshDark, 2.5f) { moveTo(28f, 50f); quadraticBezierTo(38f, 45f, 48f, 49f) }
    dot(Pink, 72f, 22f, 15f)
    for (y in listOf(15f, 22f, 29f)) line(SkinLine, 58f, y, 66f, y, 2.5f)
    rrect(Palette.sky, 6f, 56f, 14f, 34f, 4f)
}

// ---------------------------------------------------------------- shapes

private fun DrawScope.circle() = dot(Palette.coral, 50f, 50f, 38f)
private fun DrawScope.square() = rrect(Palette.sky, 16f, 16f, 68f, 68f, 4f)
private fun DrawScope.triangle() = fill(Palette.sunflower) { moveTo(50f, 12f); lineTo(92f, 84f); lineTo(8f, 84f); close() }
private fun DrawScope.rectangle() = rrect(Palette.mint, 6f, 28f, 88f, 44f, 4f)
private fun DrawScope.oval() = oval(Palette.lavender, 8f, 24f, 84f, 52f)
private fun DrawScope.diamond() = fill(Palette.coral) { moveTo(50f, 8f); lineTo(82f, 50f); lineTo(50f, 92f); lineTo(18f, 50f); close() }

private fun DrawScope.cube() {
    fill(Palette.sunflowerSoft) { moveTo(50f, 12f); lineTo(86f, 30f); lineTo(50f, 48f); lineTo(14f, 30f); close() }
    fill(Palette.sunflower) { moveTo(14f, 30f); lineTo(50f, 48f); lineTo(50f, 90f); lineTo(14f, 72f); close() }
    fill(SunDark) { moveTo(50f, 48f); lineTo(86f, 30f); lineTo(86f, 72f); lineTo(50f, 90f); close() }
}

private fun DrawScope.cone() {
    val base = Rect(20f, 70f, 80f, 90f)
    fill(Palette.coral) { moveTo(50f, 10f); lineTo(20f, 80f); arcTo(base, 180f, -180f, false); close() }
    fill(CoralDark) { moveTo(50f, 10f); lineTo(69.3f, 87.7f); arcTo(base, 50f, -50f, false); close() }
}

private fun DrawScope.cylinder() {
    val bottom = Rect(24f, 72f, 76f, 88f)
    fill(Palette.mint) { moveTo(24f, 24f); lineTo(24f, 80f); arcTo(bottom, 180f, -180f, false); lineTo(76f, 24f); close() }
    fill(Palette.mintInk) { moveTo(62f, 24f); lineTo(62f, 87.1f); arcTo(bottom, 62.6f, -62.6f, false); lineTo(76f, 24f); close() }
    oval(MintLight, 24f, 16f, 52f, 16f)
}

private fun DrawScope.sphere() {
    oval(Palette.hairline, 22f, 84f, 56f, 9f)
    val ball = path { addOval(Rect(14f, 10f, 86f, 82f)) }
    drawPath(ball, LavDark)
    clipPath(ball) { dot(Palette.lavender, 44f, 41f, 34f) }
    dot(LavLight, 36f, 32f, 9f)
}

// ---------------------------------------------------------------- school

private fun DrawScope.pen() {
    rotate(-35f, C) {
        rrect(Palette.sky, 24f, 42f, 50f, 16f, 3f)
        rect(Palette.ink, 72f, 43f, 8f, 14f)
        fill(Grey) { moveTo(80f, 44f); lineTo(93f, 50f); lineTo(80f, 56f); close() }
        rrect(Palette.ink, 8f, 41f, 28f, 18f, 4f)
        rrect(Grey, 12f, 37f, 22f, 5f, 2.5f)
        rect(Grey, 12f, 37f, 4f, 6f)
    }
}

private fun DrawScope.eraser() {
    translate(-5f, 4f) {
        rotate(-20f, C) {
            fill(Color(0xFFFFD0C7)) { moveTo(16f, 44f); lineTo(24f, 34f); lineTo(70f, 34f); lineTo(62f, 44f); close() }
            fill(SkyLight) { moveTo(62f, 44f); lineTo(70f, 34f); lineTo(94f, 34f); lineTo(86f, 44f); close() }
            fill(SkyDark) { moveTo(86f, 44f); lineTo(94f, 34f); lineTo(94f, 60f); lineTo(86f, 70f); close() }
            rect(Pink, 16f, 44f, 46f, 26f)
            rect(Palette.sky, 62f, 44f, 24f, 26f)
        }
    }
    dot(Pink, 30f, 84f, 2.5f); dot(Pink, 38f, 88f, 2f)
}

private fun DrawScope.sharpener() {
    rrect(Palette.sky, 42f, 30f, 48f, 42f, 6f)
    rrect(Grey, 46f, 23f, 40f, 9f, 2f)
    dot(SteelDark, 80f, 27.5f, 2.5f)
    rect(SkyDark, 42f, 64f, 48f, 8f)
    dot(Palette.ink, 58f, 50f, 10f)
    rect(Palette.sunflower, 6f, 44f, 32f, 12f)
    rect(Pink, 2f, 44f, 6f, 12f)
    fill(Wood) { moveTo(38f, 44f); lineTo(56f, 50f); lineTo(38f, 56f); close() }
    fill(Palette.ink) { moveTo(50f, 48f); lineTo(56f, 50f); lineTo(50f, 52f); close() }
    stroke(Wood, 4f) { moveTo(48f, 86f); quadraticBezierTo(56f, 78f, 64f, 86f); quadraticBezierTo(70f, 92f, 78f, 84f) }
}

private fun DrawScope.ruler() {
    rotate(-30f, C) {
        rrect(Palette.sunflowerSoft, 6f, 36f, 88f, 28f, 3f)
        for (i in 0..16) {
            val x = 12f + i * 4.75f
            val h = if (i % 4 == 0) 12f else if (i % 2 == 0) 8f else 5f
            line(Palette.sunflowerInk, x, 36f, x, 36f + h, 1.6f)
        }
    }
}

private fun DrawScope.crayon() {
    rotate(-35f, C) {
        fill(Palette.coral) { moveTo(72f, 40f); lineTo(86f, 45f); quadraticBezierTo(90f, 50f, 86f, 55f); lineTo(72f, 60f); close() }
        rrect(Palette.coral, 12f, 38f, 62f, 24f, 4f)
        rect(CoralDark, 24f, 38f, 42f, 24f)
        line(Palette.cream, 28f, 38f, 28f, 62f, 2f); line(Palette.cream, 62f, 38f, 62f, 62f, 2f)
        stroke(Palette.cream, 2f) { moveTo(34f, 50f); quadraticBezierTo(40f, 42f, 46f, 50f); quadraticBezierTo(52f, 58f, 58f, 50f) }
    }
}

private fun DrawScope.blackboard() {
    line(Brown, 22f, 70f, 14f, 94f, 5f); line(Brown, 78f, 70f, 86f, 94f, 5f)
    rrect(Brown, 8f, 14f, 84f, 60f, 4f)
    rect(Board, 13f, 19f, 74f, 48f)
    rect(Palette.sunflowerInk, 8f, 70f, 84f, 6f)
    stroke(Palette.cream, 2.5f) { moveTo(22f, 52f); lineTo(32f, 32f); lineTo(42f, 52f); close() }
    drawCircle(Palette.cream, 8f, Offset(60f, 38f), style = Stroke(2.5f))
    stroke(Palette.cream, 2.5f) { moveTo(52f, 58f); quadraticBezierTo(58f, 52f, 64f, 58f); quadraticBezierTo(70f, 64f, 78f, 56f) }
    rrect(Palette.cream, 62f, 66f, 12f, 4f, 1.5f)
}

private fun DrawScope.schoolbag() {
    drawArc(CoralDark, 180f, 180f, false, Offset(38f, 8f), Size(24f, 24f), style = Stroke(5f))
    rrect(Palette.coral, 20f, 20f, 60f, 72f, 14f)
    fill(CoralDark) { moveTo(20f, 46f); lineTo(20f, 34f); quadraticBezierTo(20f, 20f, 34f, 20f); lineTo(66f, 20f); quadraticBezierTo(80f, 20f, 80f, 34f); lineTo(80f, 46f); quadraticBezierTo(50f, 54f, 20f, 46f); close() }
    rrect(Palette.sunflower, 30f, 58f, 40f, 26f, 6f)
    line(Palette.cream, 34f, 64f, 66f, 64f, 2f)
    rect(Palette.sunflowerSoft, 32f, 44f, 6f, 10f); rect(Palette.sunflowerSoft, 62f, 44f, 6f, 10f)
}

private fun DrawScope.notebook() {
    rrect(Palette.cream, 28f, 16f, 58f, 76f, 4f)
    drawRoundRect(Palette.outline, Offset(28f, 16f), Size(58f, 76f), CornerRadius(4f), style = Stroke(2f))
    rrect(Palette.sky, 24f, 12f, 56f, 76f, 4f)
    rrect(Palette.cream, 38f, 26f, 32f, 16f, 3f)
    line(Palette.muted, 43f, 31f, 65f, 31f, 2f); line(Palette.muted, 43f, 37f, 58f, 37f, 2f)
    for (i in 0 until 8) {
        val y = 18f + i * 9f
        dot(Palette.canvas, 30f, y, 2f)
        line(SteelDark, 18f, y, 30f, y, 3f)
    }
}

private fun DrawScope.globe() {
    drawArc(Grey, 110f, 200f, false, Offset(16f, 6f), Size(68f, 68f), style = Stroke(4f, cap = StrokeCap.Round))
    rect(Brown, 47f, 72f, 6f, 12f)
    rrect(Brown, 30f, 82f, 40f, 9f, 4.5f)
    val ball = path { addOval(Rect(22f, 12f, 78f, 68f)) }
    drawPath(ball, Palette.sky)
    clipPath(ball) {
        fill(Palette.mint) { moveTo(30f, 22f); cubicTo(40f, 14f, 52f, 20f, 48f, 30f); cubicTo(44f, 40f, 34f, 36f, 30f, 44f); cubicTo(24f, 40f, 22f, 28f, 30f, 22f); close() }
        fill(Palette.mint) { moveTo(54f, 36f); cubicTo(64f, 30f, 76f, 36f, 72f, 46f); cubicTo(68f, 56f, 62f, 64f, 56f, 60f); cubicTo(52f, 54f, 48f, 42f, 54f, 36f); close() }
        oval(Palette.mint, 34f, 52f, 12f, 8f)
    }
}

private fun DrawScope.map() {
    val a = Color(0xFFA6E3C9); val b = Color(0xFF7FD3B0)
    fill(a) { moveTo(12f, 22f); lineTo(38f, 30f); lineTo(38f, 86f); lineTo(12f, 78f); close() }
    fill(b) { moveTo(38f, 30f); lineTo(62f, 22f); lineTo(62f, 78f); lineTo(38f, 86f); close() }
    fill(a) { moveTo(62f, 22f); lineTo(88f, 30f); lineTo(88f, 86f); lineTo(62f, 78f); close() }
    stroke(Palette.sky, 4f) { moveTo(12f, 50f); quadraticBezierTo(26f, 44f, 38f, 56f); quadraticBezierTo(50f, 66f, 62f, 54f); quadraticBezierTo(76f, 44f, 88f, 60f) }
    for (i in 0 until 4) { val x = 20f + i * 10f; line(Palette.coral, x, 72f - i * 3f, x + 4f, 70f - i * 3f, 2.5f) }
    fill(Palette.coral) { moveTo(72f, 46f); cubicTo(64f, 36f, 64f, 26f, 72f, 26f); cubicTo(80f, 26f, 80f, 36f, 72f, 46f); close() }
    dot(Palette.cream, 72f, 32f, 3f)
}

// ---------------------------------------------------------------- kitchen

private fun DrawScope.plate() {
    oval(SkyLight, 8f, 28f, 84f, 46f)
    oval(Palette.trail, 10f, 29f, 80f, 42f)
    oval(Palette.card, 22f, 37f, 56f, 26f)
}

private fun DrawScope.glass() {
    val body = path { moveTo(26f, 14f); lineTo(74f, 14f); lineTo(68f, 88f); lineTo(32f, 88f); close() }
    drawPath(body, Palette.trail)
    clipPath(body) { rect(SkyLight, 0f, 40f, 100f, 60f) }
    drawPath(body, Palette.sky, style = Stroke(3f, join = StrokeJoin.Round))
    line(Palette.card, 34f, 22f, 37f, 78f, 3f)
}

private fun DrawScope.bowl() {
    rrect(CoralDark, 36f, 80f, 28f, 8f, 3f)
    fill(Palette.coral) { moveTo(10f, 44f); lineTo(90f, 44f); cubicTo(90f, 70f, 72f, 84f, 50f, 84f); cubicTo(28f, 84f, 10f, 70f, 10f, 44f); close() }
    oval(CoralDark, 10f, 36f, 80f, 16f)
    oval(Color(0xFFFFA48E), 14f, 39f, 72f, 10f)
    stroke(Palette.cream, 3f) { moveTo(18f, 58f); quadraticBezierTo(50f, 68f, 82f, 58f) }
}

private fun DrawScope.pot() {
    rrect(Palette.ink, 6f, 50f, 16f, 7f, 3.5f); rrect(Palette.ink, 78f, 50f, 16f, 7f, 3.5f)
    rrect(Grey, 18f, 40f, 64f, 46f, 8f)
    rect(Steel, 26f, 46f, 6f, 34f)
    fill(SteelDark) { moveTo(16f, 44f); cubicTo(18f, 24f, 82f, 24f, 84f, 44f); close() }
    rrect(Palette.ink, 43f, 22f, 14f, 9f, 4f)
}

private fun DrawScope.pan() {
    rotate(-10f, C) {
        rrect(Palette.ink, 64f, 49f, 32f, 8f, 4f)
        oval(Palette.ink, 6f, 34f, 62f, 40f)
        oval(Color(0xFF3A3C5C), 6f, 30f, 62f, 38f)
        oval(Palette.muted, 12f, 35f, 50f, 28f)
    }
}

private fun DrawScope.kettle() {
    drawArc(Palette.ink, 180f, 180f, false, Offset(30f, 18f), Size(40f, 40f), style = Stroke(5f))
    fill(Palette.sky) { moveTo(30f, 72f); lineTo(8f, 46f); lineTo(16f, 42f); lineTo(36f, 58f); close() }
    fill(Palette.sky) { moveTo(30f, 44f); lineTo(70f, 44f); cubicTo(84f, 60f, 84f, 86f, 74f, 88f); lineTo(26f, 88f); cubicTo(16f, 86f, 16f, 60f, 30f, 44f); close() }
    oval(SkyDark, 30f, 39f, 40f, 10f)
    dot(Palette.ink, 50f, 38f, 4f)
    stroke(SkyDark, 3f) { moveTo(22f, 70f); quadraticBezierTo(50f, 76f, 78f, 70f) }
}

private fun DrawScope.knife() {
    rotate(-40f, C) {
        rrect(Brown, 8f, 43f, 32f, 14f, 6f)
        dot(Palette.cream, 18f, 50f, 2f); dot(Palette.cream, 30f, 50f, 2f)
        rect(SteelDark, 39f, 42f, 5f, 16f)
        fill(Steel) { moveTo(44f, 43f); lineTo(80f, 43f); cubicTo(92f, 43f, 94f, 53f, 86f, 56f); lineTo(44f, 57f); close() }
        line(Palette.card, 48f, 47f, 80f, 47f, 2f)
    }
}

private fun DrawScope.fork() {
    rotate(30f, C) {
        rrect(Grey, 45f, 46f, 10f, 48f, 5f)
        fill(Grey) { moveTo(36f, 28f); lineTo(64f, 28f); quadraticBezierTo(64f, 44f, 54f, 48f); lineTo(46f, 48f); quadraticBezierTo(36f, 44f, 36f, 28f); close() }
        for (i in 0 until 4) rrect(Grey, 36f + i * 8f, 6f, 4f, 26f, 2f)
    }
}

private fun DrawScope.stove() {
    fill(Palette.ink) { moveTo(16f, 52f); lineTo(84f, 52f); lineTo(94f, 68f); lineTo(6f, 68f); close() }
    rect(Grey, 6f, 68f, 88f, 16f)
    dot(Palette.ink, 30f, 76f, 4.5f); dot(Palette.ink, 70f, 76f, 4.5f)
    rect(Palette.ink, 10f, 84f, 6f, 4f); rect(Palette.ink, 84f, 84f, 6f, 4f)
    for (cx in listOf(32f, 68f)) {
        oval(Palette.muted, cx - 13f, 54f, 26f, 9f)
        for (k in -2..2) {
            val x = cx + k * 5f; val h = if (k == 0) 18f else if (k == -1 || k == 1) 15f else 11f
            fill(Palette.sky) { moveTo(x - 3f, 58f); quadraticBezierTo(x - 3f, 58f - h * 0.6f, x, 58f - h); quadraticBezierTo(x + 3f, 58f - h * 0.6f, x + 3f, 58f); close() }
        }
        oval(Palette.lavender, cx - 8f, 55f, 16f, 5f)
    }
}

private fun DrawScope.fridge() {
    rrect(SkyLight, 26f, 6f, 48f, 86f, 6f)
    line(Palette.card, 26f, 34f, 74f, 34f, 2.5f)
    rrect(SteelDark, 32f, 18f, 4f, 12f, 2f); rrect(SteelDark, 32f, 40f, 4f, 22f, 2f)
    rect(Palette.ink, 30f, 92f, 6f, 4f); rect(Palette.ink, 64f, 92f, 6f, 4f)
    dot(Palette.coral, 62f, 48f, 4f); rrect(Palette.sunflower, 54f, 60f, 10f, 8f, 2f)
}

private fun DrawScope.pressureCooker() {
    rrect(Palette.ink, 60f, 48f, 32f, 7f, 3.5f)
    rrect(Grey, 12f, 44f, 54f, 44f, 10f)
    rect(Steel, 20f, 50f, 6f, 32f)
    oval(SteelDark, 10f, 38f, 58f, 12f)
    rrect(Palette.ink, 38f, 36f, 56f, 7f, 3.5f)
    rrect(Palette.ink, 34f, 22f, 10f, 14f, 3f)
    dot(Palette.ink, 39f, 20f, 4f)
    stroke(Palette.hairline, 3f) { moveTo(36f, 14f); quadraticBezierTo(32f, 9f, 37f, 4f) }
    stroke(Palette.hairline, 3f) { moveTo(44f, 14f); quadraticBezierTo(40f, 9f, 45f, 4f) }
}

private fun DrawScope.tawa() {
    line(Palette.ink, 80f, 54f, 94f, 48f, 6f)
    oval(Palette.ink, 6f, 34f, 78f, 40f)
    oval(Color(0xFF3A3C5C), 6f, 31f, 78f, 40f)
    oval(Color(0xFFF2C77E), 22f, 37f, 46f, 26f)
    for ((x, y) in listOf(34f to 46f, 48f to 42f, 56f to 52f, 40f to 56f)) oval(SunDark, x, y, 5f, 3f)
}

// ---------------------------------------------------------------- clothes

private fun DrawScope.dress() {
    line(LavDark, 42f, 8f, 42f, 22f, 3f); line(LavDark, 58f, 8f, 58f, 22f, 3f)
    fill(Palette.lavender) {
        moveTo(38f, 20f); quadraticBezierTo(50f, 26f, 62f, 20f); lineTo(60f, 40f); cubicTo(70f, 56f, 80f, 76f, 84f, 94f)
        lineTo(16f, 94f); cubicTo(20f, 76f, 30f, 56f, 40f, 40f); close()
    }
    rect(LavDark, 39f, 38f, 22f, 5f)
    line(LavDark, 44f, 50f, 34f, 90f, 2f); line(LavDark, 56f, 50f, 66f, 90f, 2f)
}

private fun DrawScope.skirt() {
    fill(Palette.sky) { moveTo(30f, 30f); lineTo(70f, 30f); lineTo(88f, 84f); lineTo(12f, 84f); close() }
    rrect(SkyDark, 28f, 22f, 44f, 10f, 2f)
    for (k in -2..2) if (k != 0) line(SkyDark, 50f + k * 8f, 32f, 50f + k * 16f, 82f, 2f)
    dot(Palette.card, 50f, 27f, 2.5f)
}

private fun DrawScope.shorts() {
    fill(Palette.mint) { moveTo(20f, 28f); lineTo(80f, 28f); lineTo(88f, 80f); lineTo(56f, 80f); lineTo(50f, 50f); lineTo(44f, 80f); lineTo(12f, 80f); close() }
    rrect(Palette.mintInk, 20f, 20f, 60f, 10f, 2f)
    line(Palette.mintInk, 50f, 30f, 50f, 46f, 2f)
    stroke(Palette.mintInk, 2f) { moveTo(24f, 32f); quadraticBezierTo(28f, 42f, 36f, 32f) }
    stroke(Palette.mintInk, 2f) { moveTo(76f, 32f); quadraticBezierTo(72f, 42f, 64f, 32f) }
}

private fun DrawScope.frock() {
    oval(Palette.coral, 22f, 16f, 22f, 18f); oval(Palette.coral, 56f, 16f, 22f, 18f)
    for (i in 0..8) dot(Palette.sunflowerSoft, 18f + i * 8f, 84f, 5f)
    fill(Palette.coral) { moveTo(36f, 14f); lineTo(42f, 14f); quadraticBezierTo(50f, 22f, 58f, 14f); lineTo(64f, 14f); lineTo(62f, 44f); lineTo(88f, 84f); lineTo(12f, 84f); lineTo(38f, 44f); close() }
    fill(Palette.sunflowerSoft) { moveTo(40f, 14f); quadraticBezierTo(50f, 36f, 60f, 14f); quadraticBezierTo(50f, 24f, 41f, 14f); close() }
    rect(Palette.sunflower, 38f, 42f, 24f, 5f)
    fill(Palette.sunflower) { moveTo(50f, 44.5f); lineTo(39f, 38f); lineTo(39f, 51f); close() }
    fill(Palette.sunflower) { moveTo(50f, 44.5f); lineTo(61f, 38f); lineTo(61f, 51f); close() }
    dot(Palette.sunflowerInk, 50f, 44.5f, 3f)
}

private fun DrawScope.saree() = scale(1.15f, Offset(50f, 54f)) { sareeFigure() }

private fun DrawScope.sareeFigure() {
    val green = Palette.mintInk; val gold = Palette.sunflower
    dot(Palette.ink, 50f, 13f, 10f); dot(Palette.ink, 59f, 9f, 5f)
    dot(Pink, 50f, 16f, 8f)
    rect(Pink, 47f, 22f, 6f, 6f)
    rrect(Pink, 28f, 30f, 8f, 28f, 4f); rrect(Pink, 64f, 30f, 8f, 28f, 4f)
    rrect(Palette.coral, 36f, 27f, 28f, 16f, 6f)
    fill(green) { moveTo(36f, 42f); lineTo(64f, 42f); lineTo(70f, 94f); lineTo(30f, 94f); close() }
    for (x in listOf(44f, 48f, 52f)) line(Palette.mint, x, 56f, x - 2f, 92f, 1.6f)
    rect(gold, 30f, 89f, 40f, 5f)
    fill(green) { moveTo(36f, 46f); lineTo(64f, 27f); lineTo(70f, 34f); lineTo(70f, 76f); lineTo(62f, 76f); lineTo(62f, 40f); lineTo(42f, 54f); close() }
    stroke(gold, 3f) { moveTo(38f, 50f); lineTo(64f, 31f) }
    rect(gold, 62f, 72f, 8f, 4f)
}

private fun DrawScope.kurta() {
    fill(Palette.sunflower) {
        moveTo(36f, 12f); lineTo(64f, 12f); lineTo(82f, 26f); lineTo(88f, 62f); lineTo(78f, 64f); lineTo(70f, 36f)
        lineTo(70f, 94f); lineTo(30f, 94f); lineTo(30f, 36f); lineTo(22f, 64f); lineTo(12f, 62f); lineTo(18f, 26f); close()
    }
    rect(SunDark, 43f, 8f, 14f, 6f)
    rect(SunDark, 48f, 14f, 4f, 28f)
    for (y in listOf(20f, 28f, 36f)) dot(Palette.cream, 50f, y, 1.8f)
    line(SunDark, 30f, 80f, 30f, 94f, 2f); line(SunDark, 70f, 80f, 70f, 94f, 2f)
}

private fun DrawScope.jacket() {
    fill(Brown) {
        moveTo(36f, 14f); lineTo(64f, 14f); lineTo(80f, 22f); lineTo(90f, 76f); lineTo(78f, 78f); lineTo(72f, 42f)
        lineTo(72f, 88f); lineTo(28f, 88f); lineTo(28f, 42f); lineTo(22f, 78f); lineTo(10f, 76f); lineTo(20f, 22f); close()
    }
    val dark = Color(0xFF5E3D00)
    fill(dark) { moveTo(36f, 14f); lineTo(50f, 30f); lineTo(42f, 40f); lineTo(32f, 18f); close() }
    fill(dark) { moveTo(64f, 14f); lineTo(50f, 30f); lineTo(58f, 40f); lineTo(68f, 18f); close() }
    line(Palette.sunflower, 50f, 30f, 50f, 88f, 2.5f)
    rect(dark, 28f, 82f, 44f, 6f)
    line(dark, 34f, 60f, 44f, 60f, 3f); line(dark, 56f, 60f, 66f, 60f, 3f)
}

private fun DrawScope.sweater() {
    fill(Palette.coral) {
        moveTo(40f, 16f); quadraticBezierTo(50f, 24f, 60f, 16f); lineTo(76f, 20f); lineTo(90f, 70f); lineTo(78f, 74f); lineTo(70f, 44f)
        lineTo(70f, 86f); lineTo(30f, 86f); lineTo(30f, 44f); lineTo(22f, 74f); lineTo(10f, 70f); lineTo(24f, 20f); close()
    }
    stroke(CoralDark, 4f) { moveTo(40f, 17f); quadraticBezierTo(50f, 26f, 60f, 17f) }
    rect(CoralDark, 30f, 78f, 40f, 8f)
    rotate(-15f, Offset(16f, 72f)) { rect(CoralDark, 9f, 66f, 13f, 7f) }
    rotate(15f, Offset(84f, 72f)) { rect(CoralDark, 78f, 66f, 13f, 7f) }
    stroke(Palette.cream, 3f) { moveTo(30f, 54f); for (i in 1..8) lineTo(30f + i * 5f, if (i % 2 == 1) 48f else 54f) }
}

private fun DrawScope.raincoat() {
    fill(Palette.sunflower) {
        moveTo(36f, 26f); lineTo(64f, 26f); lineTo(78f, 32f); lineTo(88f, 74f); lineTo(78f, 76f); lineTo(70f, 50f)
        lineTo(76f, 92f); lineTo(24f, 92f); lineTo(30f, 50f); lineTo(22f, 76f); lineTo(12f, 74f); lineTo(22f, 32f); close()
    }
    dot(Palette.sunflower, 50f, 22f, 15f)
    oval(SunDark, 41f, 14f, 18f, 18f)
    line(SunDark, 50f, 38f, 50f, 92f, 2f)
    for (y in listOf(48f, 62f, 76f)) dot(Palette.ink, 56f, y, 2.5f)
    for ((x, y) in listOf(12f to 18f, 86f to 14f, 90f to 40f)) fill(Palette.sky) { moveTo(x, y - 6f); quadraticBezierTo(x + 4f, y, x + 4f, y + 2f); quadraticBezierTo(x + 4f, y + 6f, x, y + 6f); quadraticBezierTo(x - 4f, y + 6f, x - 4f, y + 2f); quadraticBezierTo(x - 4f, y, x, y - 6f); close() }
}

private fun DrawScope.glove(dx: Float, mirror: Boolean, c: Color, cuff: Color) {
    val m = if (mirror) -1f else 1f
    fun X(x: Float) = dx + m * x
    val left = minOf(X(-12f), X(12f))
    rrect(c, left, 38f, 24f, 34f, 9f)
    for ((i, h) in listOf(24f, 28f, 26f, 20f).withIndex()) {
        val fx = X(-12f + i * 6.4f + 2.6f)
        rrect(c, fx - 2.8f, 44f - h, 5.6f, h + 6f, 2.8f)
    }
    val t = path { moveTo(X(-10f), 54f); lineTo(X(-22f), 44f); lineTo(X(-26f), 48f); lineTo(X(-12f), 66f); close() }
    drawPath(t, c)
    rrect(cuff, left - 1f, 70f, 26f, 14f, 3f)
}

private fun DrawScope.gloves() {
    glove(32f, false, Palette.lavender, LavDark)
    glove(68f, true, Palette.lavender, LavDark)
}

private fun DrawScope.scarf() {
    // A knitted scarf looped as if round a neck, both ends hanging.
    drawOval(Palette.sky, Offset(26f, 10f), Size(48f, 20f), style = Stroke(12f))
    rotate(-12f, Offset(58f, 30f)) {
        rrect(Palette.sky, 49f, 28f, 17f, 58f, 3f)
        for (y in listOf(48f, 60f, 72f)) rect(Palette.cream, 49f, y, 17f, 5f)
        for (i in 0..4) line(Palette.sky, 51f + i * 3.2f, 86f, 51f + i * 3.2f, 93f, 1.8f)
    }
    rotate(10f, Offset(42f, 30f)) {
        rrect(SkyDark, 34f, 28f, 17f, 50f, 3f)
        for (y in listOf(42f, 54f, 66f)) rect(Palette.cream, 34f, y, 17f, 5f)
        for (i in 0..4) line(SkyDark, 36f + i * 3.2f, 78f, 36f + i * 3.2f, 85f, 1.8f)
    }
}

// ---------------------------------------------------------------- tools

private fun DrawScope.saw() {
    rotate(-30f, C) {
        val teeth = path {
            moveTo(30f, 36f); lineTo(92f, 46f); lineTo(92f, 54f)
            var x = 92f
            while (x > 32f) { lineTo(x - 2.5f, 58.5f - (92f - x) * 0.08f + 3f); x -= 5f; lineTo(x, 55f + (92f - x) * 0.12f) }
            lineTo(30f, 64f); close()
        }
        drawPath(teeth, Steel)
        line(Grey, 32f, 62f, 90f, 54f, 2f)
        rrect(Palette.coral, 6f, 32f, 28f, 36f, 10f)
        rrect(Palette.card, 13f, 42f, 12f, 16f, 5f)
    }
}

private fun DrawScope.screwdriver() {
    rotate(-40f, C) {
        rect(Grey, 44f, 47f, 40f, 6f)
        rect(SteelDark, 82f, 45f, 8f, 10f)
        rect(Palette.ink, 40f, 44f, 6f, 12f)
        rrect(Palette.coral, 8f, 39f, 34f, 22f, 9f)
        for (y in listOf(45f, 50f, 55f)) line(CoralDark, 14f, y, 36f, y, 2f)
    }
}

private fun DrawScope.spade() {
    rotate(20f, C) {
        rect(Brown, 47f, 12f, 6f, 40f)
        rrect(Brown, 37f, 6f, 26f, 7f, 3.5f)
        rect(SteelDark, 44f, 46f, 12f, 10f)
        fill(Grey) { moveTo(32f, 54f); lineTo(68f, 54f); lineTo(68f, 74f); quadraticBezierTo(68f, 86f, 50f, 96f); quadraticBezierTo(32f, 86f, 32f, 74f); close() }
        rect(Steel, 36f, 58f, 5f, 18f)
    }
}

private fun DrawScope.axe() {
    stroke(Brown, 8f) { moveTo(30f, 92f); quadraticBezierTo(44f, 50f, 56f, 12f) }
    fill(Grey) { moveTo(46f, 14f); lineTo(64f, 18f); quadraticBezierTo(76f, 8f, 84f, 10f); quadraticBezierTo(92f, 30f, 82f, 48f); quadraticBezierTo(74f, 38f, 62f, 36f); lineTo(44f, 30f); close() }
    stroke(Steel, 4f) { moveTo(84f, 14f); quadraticBezierTo(89f, 30f, 82f, 44f) }
}

private fun DrawScope.needle() {
    stroke(Palette.coral, 3f) { moveTo(73f, 22f); cubicTo(92f, 30f, 66f, 54f, 70f, 70f); cubicTo(74f, 86f, 46f, 94f, 40f, 82f) }
    fill(Grey) { moveTo(16f, 88f); lineTo(70f, 18f); quadraticBezierTo(80f, 14f, 78f, 24f); lineTo(16f, 88f); close() }
    line(Grey, 16f, 88f, 74f, 20f, 3f)
    rotate(-50f, Offset(73f, 22f)) { oval(Palette.card, 70f, 20.5f, 6f, 3f) }
    line(Palette.coral, 70f, 24f, 76f, 21f, 2.5f)
}

private fun DrawScope.thread() {
    stroke(Palette.coral, 3f) { moveTo(64f, 44f); cubicTo(80f, 48f, 76f, 64f, 86f, 70f); quadraticBezierTo(92f, 74f, 90f, 84f) }
    rrect(Palette.coral, 32f, 24f, 34f, 52f, 2f)
    for (i in 0..8) line(CoralDark, 33f, 28f + i * 5.6f, 65f, 30f + i * 5.6f, 1.5f)
    rrect(Wood, 24f, 14f, 50f, 11f, 4f)
    rrect(Wood, 24f, 75f, 50f, 11f, 4f)
    oval(Brown, 42f, 16f, 14f, 6f)
}

private fun DrawScope.rope() {
    val rope = Color(0xFFD9A55B)
    val spiral = path {
        val turns = 4.0
        var first = true
        var t = 0.0
        while (t <= turns * 2 * Math.PI) {
            val r = 6.0 + (32.0 - 6.0) * t / (turns * 2 * Math.PI)
            val x = (48.0 + r * cos(t)).toFloat(); val y = (48.0 + r * sin(t)).toFloat()
            if (first) { moveTo(x, y); first = false } else lineTo(x, y)
            t += 0.08
        }
        lineTo(88f, 80f); lineTo(92f, 92f)
    }
    drawPath(spiral, rope, style = Stroke(7.5f, cap = StrokeCap.Round, join = StrokeJoin.Round))
    drawPath(spiral, Brown, style = Stroke(7.5f, pathEffect = PathEffect.dashPathEffect(floatArrayOf(1.6f, 4.4f))))
}

private fun DrawScope.torch() {
    rotate(-30f, C) {
        fill(Palette.sunflowerSoft) { moveTo(74f, 38f); lineTo(100f, 26f); lineTo(100f, 74f); lineTo(74f, 62f); close() }
        rrect(Palette.sky, 6f, 42f, 50f, 16f, 4f)
        fill(Palette.ink) { moveTo(54f, 41f); lineTo(70f, 34f); lineTo(70f, 66f); lineTo(54f, 59f); close() }
        rect(Palette.sunflower, 70f, 34f, 5f, 32f)
        rrect(Palette.coral, 26f, 38f, 10f, 5f, 2f)
        for (x in listOf(12f, 16f, 20f)) line(SkyDark, x, 44f, x, 56f, 1.6f)
    }
}

// ---------------------------------------------------------------- science

private fun DrawScope.bulb() {
    for (a in listOf(-150.0, -120.0, -90.0, -60.0, -30.0)) {
        val r = Math.toRadians(a)
        line(Palette.sunflower, 50f + 32f * cos(r).toFloat(), 38f + 32f * sin(r).toFloat(), 50f + 42f * cos(r).toFloat(), 38f + 42f * sin(r).toFloat(), 4f)
    }
    fill(Palette.sunflowerSoft) { moveTo(36f, 54f); lineTo(64f, 54f); lineTo(60f, 70f); lineTo(40f, 70f); close() }
    dot(Palette.sunflowerSoft, 50f, 38f, 24f)
    line(Palette.muted, 45f, 68f, 45f, 44f, 2f); line(Palette.muted, 55f, 68f, 55f, 44f, 2f)
    stroke(Palette.coral, 2.5f) { moveTo(45f, 44f); lineTo(47f, 38f); lineTo(49f, 44f); lineTo(51f, 38f); lineTo(53f, 44f); lineTo(55f, 38f) }
    rect(Grey, 40f, 70f, 20f, 16f)
    for (y in listOf(74f, 79f, 84f)) line(SteelDark, 40f, y, 60f, y - 2f, 2f)
    rrect(Palette.ink, 45f, 85f, 10f, 6f, 2f)
}

private fun DrawScope.battery() {
    rrect(Grey, 43f, 10f, 14f, 10f, 2f)
    rrect(Palette.sunflower, 30f, 18f, 40f, 72f, 6f)
    rrect(Palette.ink, 30f, 42f, 40f, 48f, 6f)
    rect(Palette.ink, 30f, 42f, 40f, 10f)
    line(Palette.ink, 50f, 25f, 50f, 37f, 3.5f); line(Palette.ink, 44f, 31f, 56f, 31f, 3.5f)
    line(Palette.cream, 44f, 76f, 56f, 76f, 3.5f)
}

private fun DrawScope.wire() {
    stroke(Palette.coral, 5f) { moveTo(26f, 48f); quadraticBezierTo(10f, 54f, 12f, 76f) }
    stroke(Palette.ink, 5f) { moveTo(74f, 52f); quadraticBezierTo(90f, 46f, 88f, 24f) }
    line(Copper, 12f, 76f, 12f, 84f, 3f); line(Copper, 88f, 24f, 88f, 16f, 3f)
    for (i in 0 until 7) {
        val x = 26f + i * 7f
        drawArc(CopperDark, -90f, 180f, false, Offset(x, 28f), Size(12f, 44f), style = Stroke(3.5f))
    }
    for (i in 0 until 7) {
        val x = 26f + i * 7f
        drawArc(Copper, 90f, 180f, false, Offset(x + 3f, 28f), Size(12f, 44f), style = Stroke(3.5f))
    }
}

private fun DrawScope.switch() {
    rrect(Grey, 16f, 16f, 68f, 68f, 10f)
    rrect(Palette.card, 19f, 19f, 62f, 62f, 8f)
    rrect(Steel, 36f, 28f, 28f, 46f, 5f)
    rrect(Grey, 36f, 28f, 28f, 23f, 5f)
    rect(Grey, 36f, 45f, 28f, 6f)
    line(Palette.card, 50f, 34f, 50f, 42f, 3f)
    dot(Palette.coral, 50f, 23.5f, 2.5f)
}

private fun DrawScope.testTube() {
    rotate(20f, C) {
        val tube = path { moveTo(41f, 12f); lineTo(59f, 12f); lineTo(59f, 78f); arcTo(Rect(41f, 69f, 59f, 87f), 0f, 180f, false); close() }
        drawPath(tube, Palette.trail)
        clipPath(tube) { rect(Palette.lavender, 0f, 54f, 100f, 50f) }
        dot(LavLight, 46f, 72f, 2.5f); dot(LavLight, 53f, 64f, 2f)
        drawPath(tube, Palette.sky, style = Stroke(2.5f))
        rrect(Palette.sky, 37f, 8f, 26f, 6f, 3f)
    }
}

private fun DrawScope.beaker() {
    val body = path { moveTo(22f, 14f); lineTo(74f, 14f); lineTo(72f, 20f); lineTo(72f, 82f); quadraticBezierTo(72f, 88f, 66f, 88f); lineTo(34f, 88f); quadraticBezierTo(28f, 88f, 28f, 82f); lineTo(28f, 22f); close() }
    drawPath(body, Palette.trail)
    clipPath(body) { rect(Palette.mint, 0f, 50f, 100f, 50f) }
    drawPath(body, Palette.sky, style = Stroke(3f, join = StrokeJoin.Round))
    for ((i, y) in listOf(30f, 42f, 54f, 66f, 78f).withIndex()) line(if (y > 50f) Palette.cream else Palette.sky, 60f, y, if (i % 2 == 0) 70f else 66f, y, 2f)
    dot(MintLight, 40f, 70f, 3f); dot(MintLight, 48f, 60f, 2f)
}

private fun DrawScope.magnifier() {
    rotate(45f, Offset(70f, 70f)) { rrect(Brown, 62f, 62f, 34f, 13f, 6.5f) }
    rotate(45f, Offset(60f, 60f)) { rect(Palette.ink, 58f, 56f, 8f, 8f) }
    dot(Palette.ink, 42f, 42f, 28f)
    dot(Palette.trail, 42f, 42f, 22f)
    drawArc(Palette.card, 200f, 70f, false, Offset(28f, 28f), Size(28f, 28f), style = Stroke(4f, cap = StrokeCap.Round))
}

private fun DrawScope.compass() {
    drawCircle(Grey, 6f, Offset(50f, 10f), style = Stroke(3f))
    dot(Palette.sky, 50f, 54f, 38f)
    dot(Palette.cream, 50f, 54f, 31f)
    for (i in 0 until 8) {
        val a = Math.toRadians(i * 45.0)
        val r1 = if (i % 2 == 0) 23f else 26f
        line(if (i % 2 == 0) Palette.ink else Palette.muted, 50f + r1 * cos(a).toFloat(), 54f + r1 * sin(a).toFloat(), 50f + 29f * cos(a).toFloat(), 54f + 29f * sin(a).toFloat(), 2.5f)
    }
    fill(Palette.coral) { moveTo(50f, 30f); lineTo(57f, 54f); lineTo(43f, 54f); close() }
    fill(Grey) { moveTo(43f, 54f); lineTo(57f, 54f); lineTo(50f, 78f); close() }
    dot(Palette.ink, 50f, 54f, 3.5f)
}

private fun DrawScope.prism() {
    line(Palette.muted, 4f, 64f, 38f, 52f, 3f)
    val colours = listOf(Palette.coral, Palette.sunflower, Palette.mint, Palette.sky, Palette.lavender)
    for ((i, c) in colours.withIndex()) {
        line(c, 62f, 50f + i * 1.5f, 96f, 42f + i * 9f, 4f)
    }
    val tri = path { moveTo(50f, 16f); lineTo(82f, 78f); lineTo(18f, 78f); close() }
    drawPath(tri, Palette.trail)
    drawPath(tri, Palette.sky, style = Stroke(2.5f, join = StrokeJoin.Round))
    line(Palette.card, 44f, 34f, 34f, 56f, 3f)
}

private fun DrawScope.mirror() {
    rrect(Palette.lavender, 44f, 62f, 12f, 32f, 6f)
    oval(Palette.lavender, 20f, 6f, 60f, 66f)
    oval(Palette.trail, 26f, 12f, 48f, 54f)
    line(Palette.card, 36f, 36f, 48f, 22f, 4f)
    line(Palette.card, 40f, 46f, 58f, 26f, 3f)
}

private fun DrawScope.thermometer() {
    rotate(20f, C) {
        rrect(Grey, 39f, 6f, 22f, 76f, 11f)
        rrect(Palette.card, 42f, 9f, 16f, 72f, 8f)
        dot(Grey, 50f, 80f, 14f)
        dot(Palette.coral, 50f, 80f, 11f)
        rect(Palette.coral, 47f, 34f, 6f, 46f)
        for (i in 0 until 7) line(Palette.muted, 54f, 16f + i * 8f, if (i % 2 == 0) 58f else 56f, 16f + i * 8f, 1.6f)
    }
}
