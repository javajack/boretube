package com.rakesh.boretube.learn.ui.art

import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
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

/** Picture library: vehicles, things at home, homes, places, festivals and music. Same rules as ui/Pictures.kt (100×100 grid, flat fills from the palette). */
internal val thingsArt: Map<String, DrawScope.() -> Unit> = mapOf(
    // vehicles
    "train" to { train() }, "aeroplane" to { aeroplane() }, "bicycle" to { bicycle() }, "auto" to { auto() },
    "truck" to { truck() }, "ship" to { ship() }, "helicopter" to { helicopter() }, "rocket" to { rocket() },
    "scooter" to { scooter() }, "tractor" to { tractor() },
    // things
    "chair" to { chair() }, "table" to { table() }, "bed" to { bed() }, "clock" to { clock() }, "lamp" to { lamp() },
    "umbrella" to { umbrella() }, "bag" to { bag() }, "shoe" to { shoe() }, "hat" to { hat() }, "shirt" to { shirt() },
    "key" to { key() }, "spoon" to { spoon() }, "bottle" to { bottle() }, "phone" to { phone() }, "tv" to { tv() },
    "kite" to { kite() }, "drum" to { drum() }, "bell" to { bell() }, "scissors" to { scissors() }, "comb" to { comb() },
    "toothbrush" to { toothbrush() }, "soap" to { soap() }, "bucket" to { bucket() }, "door" to { door() },
    "window" to { window() }, "box" to { box() }, "sock" to { sock() }, "glasses" to { glasses() }, "ladder" to { ladder() },
    "candle" to { candle() }, "broom" to { broom() }, "hammer" to { hammer() }, "magnet" to { magnet() }, "stone" to { stone() },
    // homes
    "tent" to { tent() }, "igloo" to { igloo() }, "hut" to { hut() },
    // places
    "school" to { school() }, "hospital" to { hospital() }, "shop" to { shop() }, "temple" to { temple() },
    "mosque" to { mosque() }, "church" to { church() }, "gurudwara" to { gurudwara() }, "park" to { park() }, "farm" to { farm() },
    // festivals
    "diya" to { diya() }, "rangoli" to { rangoli() }, "pichkari" to { pichkari() }, "lantern" to { lantern() },
    "giftbox" to { giftbox() }, "balloon" to { balloon() },
    // music
    "guitar" to { guitar() }, "flute" to { flute() }, "tabla" to { tabla() }, "piano" to { piano() },
    "trumpet" to { trumpet() }, "dholak" to { dholak() },
)

private val Brown = Color(0xFF8A5A00)
private val Grey = Color(0xFF9AA3B5)
private val Pink = Color(0xFFFFB3A6)
/** Light wood and bamboo. */
private val Wood = Color(0xFFD39A4E)
/** Fired clay (diya). */
private val Clay = Color(0xFFD2693C)
/** Saffron for flags (tricolour, Nishan Sahib). */
private val Saffron = Color(0xFFFF9933)
private val GreyLight = Color(0xFFC6CCD8)

// ---- small drawing helpers (all on the 100×100 grid) ----

private inline fun pth(b: Path.() -> Unit) = Path().apply(b)
private inline fun DrawScope.fill(c: Color, b: Path.() -> Unit) = drawPath(pth(b), c)
private inline fun DrawScope.strokeP(c: Color, w: Float, b: Path.() -> Unit) =
    drawPath(pth(b), c, style = Stroke(w, cap = StrokeCap.Round, join = StrokeJoin.Round))
private fun DrawScope.ln(c: Color, x1: Float, y1: Float, x2: Float, y2: Float, w: Float = 3f) =
    drawLine(c, Offset(x1, y1), Offset(x2, y2), w, StrokeCap.Round)
private fun DrawScope.rr(c: Color, x: Float, y: Float, w: Float, h: Float, r: Float = 0f) =
    if (r > 0f) drawRoundRect(c, Offset(x, y), Size(w, h), CornerRadius(r)) else drawRect(c, Offset(x, y), Size(w, h))
private fun DrawScope.rrS(c: Color, x: Float, y: Float, w: Float, h: Float, r: Float, sw: Float) =
    drawRoundRect(c, Offset(x, y), Size(w, h), CornerRadius(r), style = Stroke(sw))
private fun DrawScope.ov(c: Color, x: Float, y: Float, w: Float, h: Float) = drawOval(c, Offset(x, y), Size(w, h))
private fun DrawScope.ovS(c: Color, x: Float, y: Float, w: Float, h: Float, sw: Float) = drawOval(c, Offset(x, y), Size(w, h), style = Stroke(sw))
private fun DrawScope.dot(c: Color, r: Float, x: Float, y: Float) = drawCircle(c, r, Offset(x, y))
private fun DrawScope.ring(c: Color, r: Float, x: Float, y: Float, sw: Float) = drawCircle(c, r, Offset(x, y), style = Stroke(sw))
private fun DrawScope.wheel(x: Float, y: Float, r: Float) {
    dot(Palette.ink, r, x, y)
    dot(Grey, r * 0.38f, x, y)
}

// =================================== vehicles ===================================

private fun DrawScope.train() {
    ln(Palette.ink, 4f, 88f, 96f, 88f, 3f)
    // coach (Indian blue)
    rr(Palette.ink, 58f, 32f, 38f, 7f, 3f)
    rr(Palette.sky, 60f, 36f, 34f, 42f, 4f)
    rr(Palette.cream, 64f, 44f, 11f, 12f, 2f)
    rr(Palette.cream, 79f, 44f, 11f, 12f, 2f)
    rr(Palette.sunflower, 60f, 62f, 34f, 4f)
    ln(Palette.ink, 54f, 72f, 62f, 72f, 4f)
    // engine
    rr(Palette.coral, 8f, 46f, 32f, 32f, 6f)
    rr(Palette.sunflower, 8f, 58f, 32f, 4f)
    rr(Palette.coral, 34f, 28f, 22f, 50f, 4f)
    rr(Palette.ink, 31f, 23f, 28f, 7f, 3f)
    rr(Palette.cream, 39f, 34f, 12f, 14f, 2f)
    rr(Palette.ink, 15f, 32f, 9f, 16f)
    rr(Palette.ink, 12f, 28f, 15f, 6f, 2f)
    dot(Palette.sunflowerSoft, 4f, 12f, 52f)
    fill(Palette.ink) { moveTo(8f, 72f); lineTo(2f, 86f); lineTo(14f, 86f); lineTo(14f, 72f); close() }
    for (x in listOf(20f, 34f, 48f)) wheel(x, 80f, 7f)
    for (x in listOf(70f, 86f)) wheel(x, 80f, 7f)
}

private fun DrawScope.aeroplane() {
    rotate(-12f, Offset(50f, 50f)) {
        // far wing
        fill(Palette.coralInk) { moveTo(46f, 44f); lineTo(58f, 44f); lineTo(46f, 28f); lineTo(39f, 28f); close() }
        // tail fin
        fill(Palette.coral) { moveTo(14f, 46f); lineTo(10f, 20f); lineTo(21f, 20f); lineTo(36f, 46f); close() }
        // body with a pointed nose
        fill(Palette.sky) {
            moveTo(18f, 42f); lineTo(76f, 42f); cubicTo(86f, 42f, 94f, 48f, 94f, 52f); cubicTo(94f, 56f, 86f, 61f, 76f, 61f)
            lineTo(18f, 61f); cubicTo(10f, 61f, 10f, 42f, 18f, 42f); close()
        }
        fill(Palette.trail) { moveTo(80f, 45f); cubicTo(86f, 45f, 90f, 48f, 91f, 50f); lineTo(80f, 50f); close() }
        for (i in 0 until 6) dot(Palette.cream, 2.6f, 30f + i * 8f, 49f)
        // near wing
        fill(Palette.coral) { moveTo(44f, 54f); lineTo(60f, 54f); lineTo(42f, 82f); lineTo(32f, 82f); close() }
        fill(Palette.coral) { moveTo(12f, 52f); lineTo(30f, 52f); lineTo(22f, 62f); lineTo(10f, 62f); close() }
    }
}

private fun DrawScope.bicycle() {
    translate(0f, -4f) {
        ring(Palette.ink, 17f, 26f, 66f, 4.5f)
        ring(Palette.ink, 17f, 74f, 66f, 4.5f)
        dot(Grey, 3f, 26f, 66f); dot(Grey, 3f, 74f, 66f)
        val c = Palette.coral
        ln(c, 26f, 66f, 48f, 66f, 4.5f)
        ln(c, 48f, 66f, 40f, 40f, 4.5f)
        ln(c, 26f, 66f, 40f, 40f, 4.5f)
        ln(c, 40f, 40f, 68f, 40f, 4.5f)
        ln(c, 48f, 66f, 68f, 40f, 4.5f)
        ln(c, 68f, 40f, 74f, 66f, 4.5f)
        ln(c, 68f, 40f, 65f, 30f, 4.5f)
        ln(Palette.ink, 60f, 29f, 72f, 27f, 4.5f)
        rr(Palette.ink, 31f, 33f, 17f, 6f, 3f)
        ln(Palette.ink, 43f, 73f, 53f, 59f, 3.5f)
        dot(Palette.sunflower, 4.5f, 48f, 66f)
    }
}

private fun DrawScope.auto() {
    wheel(28f, 76f, 9f)
    wheel(78f, 76f, 9f)
    // body (green) with yellow canopy on top
    fill(Palette.mint) {
        moveTo(14f, 74f); lineTo(14f, 34f); quadraticBezierTo(16f, 22f, 30f, 22f); lineTo(64f, 22f)
        quadraticBezierTo(72f, 22f, 74f, 30f); lineTo(84f, 56f); lineTo(88f, 62f); lineTo(88f, 74f); close()
    }
    fill(Palette.sunflower) {
        moveTo(14f, 42f); lineTo(14f, 34f); quadraticBezierTo(16f, 22f, 30f, 22f); lineTo(64f, 22f)
        quadraticBezierTo(72f, 22f, 74f, 30f); lineTo(78.6f, 42f); close()
    }
    // open sides
    rr(Palette.ink, 21f, 30f, 28f, 32f, 6f)
    fill(Palette.ink) { moveTo(55f, 30f); lineTo(70f, 30f); lineTo(78f, 52f); lineTo(55f, 52f); close() }
    rr(Palette.sunflower, 21f, 48f, 28f, 6f, 2f)
    rr(Palette.mintInk, 14f, 66f, 74f, 4f)
    dot(Palette.sunflowerSoft, 3.5f, 85f, 60f)
    // wheels sit in front of the body skirt
    wheel(28f, 76f, 9f)
    wheel(78f, 76f, 9f)
}

private fun DrawScope.truck() {
    rr(Palette.ink, 8f, 66f, 82f, 7f, 2f)
    rr(Palette.mint, 8f, 24f, 56f, 44f, 4f)
    ln(Palette.mintInk, 26f, 30f, 26f, 62f, 3f)
    ln(Palette.mintInk, 46f, 30f, 46f, 62f, 3f)
    fill(Palette.coral) { moveTo(66f, 68f); lineTo(66f, 36f); lineTo(78f, 36f); lineTo(90f, 52f); lineTo(90f, 68f); close() }
    fill(Palette.trail) { moveTo(70f, 40f); lineTo(77f, 40f); lineTo(85f, 52f); lineTo(70f, 52f); close() }
    dot(Palette.sunflowerSoft, 3f, 87f, 60f)
    for (x in listOf(22f, 42f, 78f)) wheel(x, 76f, 9f)
}

private fun DrawScope.ship() {
    // funnels
    rr(Palette.coral, 38f, 16f, 11f, 22f)
    rr(Palette.coral, 56f, 16f, 11f, 22f)
    rr(Palette.ink, 38f, 14f, 11f, 6f)
    rr(Palette.ink, 56f, 14f, 11f, 6f)
    // decks
    rr(Palette.trail, 28f, 34f, 44f, 12f, 2f)
    rr(Palette.trail, 18f, 44f, 66f, 16f, 2f)
    for (x in listOf(34f, 44f, 54f, 64f)) rr(Palette.sky, x - 3f, 37f, 6f, 6f, 1.5f)
    for (x in listOf(24f, 34f, 44f, 54f, 64f, 74f)) rr(Palette.sky, x - 3f, 48f, 6f, 7f, 1.5f)
    // hull
    fill(Palette.ink) { moveTo(4f, 58f); lineTo(96f, 58f); lineTo(86f, 82f); lineTo(16f, 82f); close() }
    fill(Palette.coral) { moveTo(10f, 72f); lineTo(90.2f, 72f); lineTo(86f, 82f); lineTo(16f, 82f); close() }
    for (i in 0 until 7) dot(Palette.cream, 2.5f, 20f + i * 10f, 65f)
    rr(Palette.sky, 0f, 84f, 100f, 8f)
}

private fun DrawScope.helicopter() {
    // tail
    rr(Palette.coral, 8f, 47f, 30f, 8f, 4f)
    rr(Palette.coral, 7f, 36f, 8f, 20f, 3f)
    ln(Palette.ink, 11f, 30f, 11f, 44f, 3f)
    // skids
    ln(Palette.ink, 38f, 72f, 36f, 82f, 3.5f)
    ln(Palette.ink, 62f, 72f, 64f, 82f, 3.5f)
    ln(Palette.ink, 26f, 82f, 76f, 82f, 4f)
    // cabin
    ov(Palette.coral, 26f, 36f, 52f, 40f)
    fill(Palette.trail) { moveTo(54f, 40f); cubicTo(68f, 40f, 78f, 50f, 78f, 58f); lineTo(54f, 58f); close() }
    rr(Palette.coralInk, 30f, 60f, 44f, 4f, 2f)
    // rotor
    rr(Palette.ink, 47f, 28f, 6f, 10f)
    ln(Palette.ink, 12f, 26f, 88f, 26f, 4.5f)
    dot(Palette.ink, 4f, 50f, 26f)
}

private fun DrawScope.rocket() {
    // fins
    fill(Palette.coral) { moveTo(37f, 54f); lineTo(22f, 78f); lineTo(24f, 82f); lineTo(38f, 74f); close() }
    fill(Palette.coral) { moveTo(63f, 54f); lineTo(78f, 78f); lineTo(76f, 82f); lineTo(62f, 74f); close() }
    // flame
    fill(Palette.sunflower) { moveTo(40f, 78f); quadraticBezierTo(44f, 90f, 50f, 98f); quadraticBezierTo(56f, 90f, 60f, 78f); close() }
    fill(Palette.coral) { moveTo(45f, 78f); quadraticBezierTo(47f, 86f, 50f, 90f); quadraticBezierTo(53f, 86f, 55f, 78f); close() }
    rr(Palette.ink, 41f, 72f, 18f, 7f, 2f)
    // body
    fill(Palette.sky) {
        moveTo(50f, 8f); cubicTo(64f, 20f, 66f, 40f, 63f, 74f); lineTo(37f, 74f); cubicTo(34f, 40f, 36f, 20f, 50f, 8f); close()
    }
    fill(Palette.coral) { moveTo(50f, 8f); cubicTo(56f, 13f, 60f, 20f, 62.4f, 27f); lineTo(37.6f, 27f); cubicTo(40f, 20f, 44f, 13f, 50f, 8f); close() }
    dot(Palette.cream, 8f, 50f, 44f)
    ring(Palette.ink, 8f, 50f, 44f, 3f)
    rr(Palette.ink, 48f, 58f, 4f, 16f, 2f)
}

private fun DrawScope.scooter() {
    wheel(26f, 78f, 10f)
    wheel(76f, 78f, 10f)
    // rear body
    fill(Palette.sky) {
        moveTo(46f, 74f); lineTo(46f, 58f); cubicTo(52f, 44f, 80f, 40f, 90f, 54f); cubicTo(94f, 62f, 92f, 72f, 84f, 74f); close()
    }
    rr(Palette.sky, 30f, 64f, 20f, 9f)
    // leg shield and front fender
    fill(Palette.sky) { moveTo(20f, 72f); lineTo(25f, 38f); lineTo(33f, 36f); lineTo(36f, 72f); close() }
    fill(Palette.sky) { moveTo(14f, 72f); quadraticBezierTo(26f, 58f, 38f, 72f); close() }
    rr(Palette.ink, 52f, 39f, 32f, 8f, 4f)
    ln(Palette.ink, 30f, 38f, 28f, 26f, 4f)
    ln(Palette.ink, 20f, 24f, 36f, 24f, 4.5f)
    dot(Palette.sunflower, 4f, 27f, 31f)
    dot(Palette.coral, 3f, 89f, 60f)
}

private fun DrawScope.tractor() {
    // cab
    rr(Palette.coral, 16f, 18f, 38f, 6f, 3f)
    rr(Palette.coral, 20f, 22f, 5f, 34f)
    rr(Palette.coral, 45f, 22f, 5f, 34f)
    rr(Palette.trail, 25f, 24f, 20f, 26f)
    // exhaust
    rr(Palette.ink, 72f, 28f, 5f, 20f, 2f)
    // hood
    rr(Palette.coral, 30f, 50f, 58f, 18f, 5f)
    for (y in listOf(54f, 59f, 64f)) ln(Palette.coralInk, 80f, y, 86f, y, 2f)
    dot(Palette.sunflowerSoft, 3f, 87f, 51f)
    // wheels
    dot(Palette.ink, 23f, 32f, 64f)
    dot(Grey, 10f, 32f, 64f)
    dot(Palette.sunflower, 4f, 32f, 64f)
    dot(Palette.ink, 13f, 78f, 74f)
    dot(Grey, 5f, 78f, 74f)
}

// =================================== things ===================================

private fun DrawScope.chair() {
    rr(Brown, 28f, 12f, 8f, 48f, 3f)
    rr(Brown, 64f, 12f, 8f, 48f, 3f)
    rr(Brown, 28f, 12f, 44f, 26f, 5f)
    rr(Palette.coral, 34f, 17f, 32f, 16f, 4f)
    rr(Brown, 26f, 60f, 8f, 30f, 3f)
    rr(Brown, 66f, 60f, 8f, 30f, 3f)
    rr(Palette.coral, 20f, 50f, 60f, 13f, 5f)
}

private fun DrawScope.table() {
    // a small vase on top
    rr(Palette.sky, 44f, 26f, 12f, 16f, 4f)
    ln(Palette.mintInk, 50f, 26f, 50f, 18f, 3f)
    dot(Palette.coral, 6f, 50f, 16f)
    dot(Palette.sunflower, 2.5f, 50f, 16f)
    rr(Brown, 8f, 42f, 84f, 10f, 3f)
    rr(Wood, 14f, 52f, 72f, 7f)
    rr(Brown, 14f, 52f, 8f, 36f, 2f)
    rr(Brown, 78f, 52f, 8f, 36f, 2f)
}

private fun DrawScope.bed() {
    rr(Brown, 8f, 28f, 13f, 60f, 4f)
    rr(Brown, 80f, 50f, 11f, 38f, 4f)
    rr(Brown, 16f, 66f, 68f, 10f)
    rr(Palette.sky, 18f, 54f, 64f, 14f, 3f)
    ov(Palette.cream, 20f, 42f, 26f, 15f)
    ovS(Palette.outline, 20f, 42f, 26f, 15f, 2.5f)
    rr(Palette.coral, 42f, 48f, 42f, 22f, 5f)
    rr(Palette.sunflower, 42f, 56f, 42f, 4f)
}

private fun DrawScope.clock() {
    // alarm bells and feet
    dot(Palette.sunflower, 11f, 26f, 24f)
    dot(Palette.sunflower, 11f, 74f, 24f)
    ln(Palette.ink, 34f, 80f, 26f, 92f, 5f)
    ln(Palette.ink, 66f, 80f, 74f, 92f, 5f)
    rr(Palette.ink, 46f, 14f, 8f, 8f, 2f)
    dot(Palette.coral, 34f, 50f, 54f)
    dot(Palette.cream, 27f, 50f, 54f)
    for (i in 0 until 12) {
        val a = Math.toRadians(i * 30.0)
        val r1 = if (i % 3 == 0) 19f else 21f
        ln(Palette.ink, 50f + r1 * sin(a).toFloat(), 54f - r1 * cos(a).toFloat(), 50f + 23f * sin(a).toFloat(), 54f - 23f * cos(a).toFloat(), if (i % 3 == 0) 3.5f else 2f)
    }
    ln(Palette.ink, 50f, 54f, 38f, 47f, 4.5f)
    ln(Palette.ink, 50f, 54f, 68f, 43.5f, 3.5f)
    dot(Palette.coral, 3.5f, 50f, 54f)
}

private fun DrawScope.lamp() {
    ov(Brown, 28f, 80f, 44f, 12f)
    rr(Brown, 46f, 50f, 8f, 34f, 2f)
    ov(Palette.sunflowerSoft, 40f, 50f, 20f, 10f)
    fill(Palette.sunflower) {
        moveTo(34f, 14f); lineTo(66f, 14f); quadraticBezierTo(74f, 30f, 80f, 54f); lineTo(20f, 54f); quadraticBezierTo(26f, 30f, 34f, 14f); close()
    }
    rr(Palette.coral, 21f, 48f, 58f, 6f, 3f)
    rr(Palette.coral, 33f, 14f, 34f, 5f, 2.5f)
}

private fun DrawScope.umbrella() {
    ln(Palette.ink, 50f, 50f, 50f, 84f, 4f)
    drawArc(Palette.ink, 0f, 180f, false, Offset(38f, 78f), Size(12f, 12f), style = Stroke(4f, cap = StrokeCap.Round))
    ln(Palette.ink, 50f, 14f, 50f, 7f, 4f)
    fill(Palette.coral) {
        moveTo(8f, 54f); arcTo(Rect(8f, 14f, 92f, 94f), 180f, 180f, false)
        for (i in 0 until 4) { val x = 92f - i * 21f; quadraticBezierTo(x - 10.5f, 45f, x - 21f, 54f) }
        close()
    }
    fill(Palette.sunflower) {
        moveTo(50f, 14f); quadraticBezierTo(31f, 22f, 29f, 54f); quadraticBezierTo(39.5f, 45f, 50f, 54f)
        quadraticBezierTo(60.5f, 45f, 71f, 54f); quadraticBezierTo(69f, 22f, 50f, 14f); close()
    }
}

private fun DrawScope.bag() {
    drawArc(Palette.ink, 180f, 180f, false, Offset(38f, 10f), Size(24f, 22f), style = Stroke(5f, cap = StrokeCap.Round))
    rr(Palette.coralInk, 16f, 40f, 10f, 34f, 5f)
    rr(Palette.coralInk, 74f, 40f, 10f, 34f, 5f)
    rr(Palette.coral, 22f, 20f, 56f, 70f, 16f)
    fill(Palette.coralInk) { moveTo(22f, 38f); quadraticBezierTo(22f, 20f, 40f, 20f); lineTo(60f, 20f); quadraticBezierTo(78f, 20f, 78f, 38f); quadraticBezierTo(50f, 46f, 22f, 38f); close() }
    rr(Palette.sunflower, 31f, 54f, 38f, 28f, 8f)
    ln(Palette.sunflowerInk, 37f, 62f, 63f, 62f, 2.5f)
    dot(Palette.ink, 3f, 50f, 40f)
}

private fun DrawScope.shoe() {
    translate(0f, -6f) {
        fill(Palette.coral) {
            moveTo(12f, 74f); lineTo(12f, 42f); quadraticBezierTo(12f, 34f, 22f, 34f); lineTo(34f, 34f)
            quadraticBezierTo(40f, 48f, 54f, 50f); lineTo(70f, 53f); quadraticBezierTo(90f, 57f, 90f, 70f); lineTo(90f, 74f); close()
        }
        fill(Palette.sky) { moveTo(12f, 46f); lineTo(24f, 46f); quadraticBezierTo(30f, 60f, 24f, 74f); lineTo(12f, 74f); close() }
        for (i in 0 until 3) {
            val x = 38f + i * 7f
            val iy = 34f + (x - 34f) * 0.8f
            ln(Palette.ink, x - 2f, iy + 9f, x + 4f, iy + 1f, 3f)
        }
        rr(Palette.cream, 8f, 72f, 86f, 10f, 5f)
        rrS(Palette.outline, 8f, 72f, 86f, 10f, 5f, 2.5f)
    }
}

private fun DrawScope.hat() {
    ov(Palette.sunflower, 6f, 60f, 88f, 22f)
    fill(Palette.sunflower) {
        moveTo(26f, 70f); lineTo(29f, 38f); quadraticBezierTo(50f, 16f, 71f, 38f); lineTo(74f, 70f); quadraticBezierTo(50f, 76f, 26f, 70f); close()
    }
    fill(Palette.coral) { moveTo(27.6f, 54f); quadraticBezierTo(50f, 60f, 72.4f, 54f); lineTo(73.2f, 63f); quadraticBezierTo(50f, 69f, 26.8f, 63f); close() }
}

private fun DrawScope.shirt() {
    fill(Palette.sky) {
        moveTo(38f, 14f); lineTo(14f, 24f); lineTo(5f, 48f); lineTo(20f, 54f); lineTo(26f, 42f); lineTo(26f, 88f)
        lineTo(74f, 88f); lineTo(74f, 42f); lineTo(80f, 54f); lineTo(95f, 48f); lineTo(86f, 24f); lineTo(62f, 14f); close()
    }
    rr(Palette.trail, 59f, 44f, 10f, 3f)
    fill(Palette.cream) { moveTo(38f, 14f); lineTo(50f, 22f); lineTo(42f, 32f); lineTo(34f, 18f); close() }
    fill(Palette.cream) { moveTo(62f, 14f); lineTo(50f, 22f); lineTo(58f, 32f); lineTo(66f, 18f); close() }
    ln(Palette.trail, 50f, 24f, 50f, 88f, 2f)
    for (y in listOf(38f, 52f, 66f, 80f)) dot(Palette.ink, 2.2f, 50f, y)
}

private fun DrawScope.key() {
    rotate(-30f, Offset(50f, 50f)) {
        ring(Palette.sunflower, 13f, 26f, 50f, 9f)
        rr(Palette.sunflower, 36f, 45f, 54f, 10f, 3f)
        rr(Palette.sunflower, 70f, 52f, 7f, 14f, 1.5f)
        rr(Palette.sunflower, 81f, 52f, 7f, 10f, 1.5f)
        dot(Palette.sunflowerInk, 2.5f, 26f, 37.5f)
    }
}

private fun DrawScope.spoon() {
    rotate(-40f, Offset(50f, 50f)) {
        rr(Grey, 40f, 46f, 52f, 8f, 4f)
        ov(Grey, 6f, 36f, 40f, 28f)
        ov(GreyLight, 13f, 41f, 18f, 9f)
    }
}

private fun DrawScope.bottle() {
    rr(Palette.sky, 42f, 18f, 16f, 12f)
    rr(Palette.coral, 39f, 8f, 22f, 13f, 3f)
    rr(Palette.sky, 30f, 26f, 40f, 66f, 12f)
    rr(Palette.trail, 30f, 50f, 40f, 20f)
    rr(Palette.sky, 36f, 56f, 28f, 3f)
    rr(Palette.trail, 35f, 32f, 5f, 14f, 2.5f)
}

private fun DrawScope.phone() {
    rr(Palette.ink, 28f, 8f, 44f, 84f, 9f)
    rr(Palette.sky, 32f, 16f, 36f, 64f, 3f)
    val apps = listOf(Palette.coral, Palette.sunflower, Palette.mint, Palette.lavender, Palette.cream, Palette.coral,
        Palette.sunflower, Palette.mint, Palette.cream, Palette.lavender, Palette.coral, Palette.sunflower)
    for (i in apps.indices) rr(apps[i], 35.5f + (i % 3) * 10.5f, 21f + (i / 3) * 12f, 8f, 8f, 2.5f)
    dot(Grey, 3f, 50f, 86f)
    rr(Grey, 45f, 11f, 10f, 2.5f, 1.25f)
}

private fun DrawScope.tv() {
    rr(Palette.ink, 46f, 72f, 8f, 10f)
    rr(Palette.ink, 30f, 80f, 40f, 6f, 3f)
    rr(Palette.ink, 6f, 14f, 88f, 60f, 6f)
    rr(Palette.sky, 11f, 19f, 78f, 50f, 2f)
    dot(Palette.sunflower, 7f, 68f, 34f)
    fill(Palette.mint) {
        moveTo(11f, 69f); lineTo(11f, 58f); quadraticBezierTo(32f, 40f, 56f, 60f); quadraticBezierTo(72f, 50f, 89f, 58f); lineTo(89f, 69f); close()
    }
    dot(Palette.mint, 2f, 86f, 71.5f)
}

private fun DrawScope.kite() {
    rotate(-12f, Offset(50f, 50f)) {
        strokeP(Palette.ink, 2.5f) { moveTo(50f, 70f); cubicTo(36f, 78f, 70f, 84f, 60f, 98f) }
        for ((x, y) in listOf(46f to 77f, 57f to 88f)) {
            fill(Palette.coral) { moveTo(x, y); lineTo(x - 6f, y - 4f); lineTo(x - 6f, y + 4f); close() }
            fill(Palette.coral) { moveTo(x, y); lineTo(x + 6f, y - 4f); lineTo(x + 6f, y + 4f); close() }
        }
        fill(Palette.sunflower) { moveTo(50f, 6f); lineTo(80f, 34f); lineTo(50f, 72f); lineTo(20f, 34f); close() }
        fill(Palette.coral) { moveTo(50f, 6f); lineTo(50f, 34f); lineTo(20f, 34f); close() }
        fill(Palette.coral) { moveTo(50f, 34f); lineTo(80f, 34f); lineTo(50f, 72f); close() }
        ln(Brown, 50f, 6f, 50f, 72f, 2.5f)
        ln(Brown, 20f, 34f, 80f, 34f, 2.5f)
    }
}

private fun DrawScope.drum() {
    rr(Palette.coral, 20f, 44f, 60f, 34f)
    ov(Palette.coral, 20f, 70f, 60f, 16f)
    strokeP(Palette.cream, 3f) {
        moveTo(22f, 48f)
        for (i in 1..6) lineTo(20f + i * 10f, if (i % 2 == 1) 80f else 48f)
    }
    rr(Palette.sunflower, 18f, 40f, 64f, 8f, 4f)
    ov(Palette.cream, 20f, 32f, 60f, 16f)
    ovS(Palette.outline, 20f, 32f, 60f, 16f, 2.5f)
    ln(Brown, 22f, 12f, 48f, 38f, 4f)
    ln(Brown, 78f, 12f, 52f, 38f, 4f)
    dot(Brown, 4f, 22f, 12f)
    dot(Brown, 4f, 78f, 12f)
}

private fun DrawScope.bell() {
    ring(Palette.sunflowerInk, 6f, 50f, 18f, 4f)
    dot(Palette.ink, 7f, 50f, 80f)
    fill(Palette.sunflower) {
        moveTo(22f, 74f); cubicTo(28f, 66f, 28f, 54f, 30f, 42f); cubicTo(32f, 18f, 68f, 18f, 70f, 42f)
        cubicTo(72f, 54f, 72f, 66f, 78f, 74f); close()
    }
    rr(Palette.sunflowerInk, 16f, 70f, 68f, 8f, 4f)
    strokeP(Palette.sunflowerSoft, 4f) { moveTo(38f, 36f); quadraticBezierTo(35f, 50f, 35f, 62f) }
}

private fun DrawScope.scissors() {
    rotate(-28f, Offset(50f, 50f)) {
        for (a in listOf(-13f, 13f)) {
            rotate(a, Offset(48f, 50f)) {
                fill(Grey) { moveTo(44f, 46f); lineTo(94f, 49f); quadraticBezierTo(96f, 50f, 94f, 51f); lineTo(44f, 54f); close() }
                rr(Palette.coral, 26f, 46f, 22f, 8f, 4f)
                ring(Palette.coral, 9f, 18f, 50f, 6f)
            }
        }
        dot(Palette.ink, 3.5f, 48f, 50f)
    }
}

private fun DrawScope.comb() {
    rotate(-12f, Offset(50f, 50f)) {
        rr(Palette.lavender, 10f, 26f, 80f, 18f, 7f)
        for (i in 0 until 12) rr(Palette.lavender, 14f + i * 6.2f, 36f, 3.6f, if (i < 6) 40f else 32f, 1.8f)
    }
}

private fun DrawScope.toothbrush() {
    rotate(-24f, Offset(50f, 50f)) {
        rr(Palette.coral, 6f, 54f, 64f, 11f, 5.5f)
        rr(Palette.coral, 64f, 55f, 18f, 8f, 4f)
        rr(Palette.coral, 70f, 52f, 24f, 12f, 5f)
        for (i in 0 until 5) rr(Palette.sky, 72f + i * 4.4f, 38f, 3.4f, 15f, 1.7f)
        fill(Palette.mint) {
            moveTo(70f, 38f); quadraticBezierTo(74f, 30f, 80f, 34f); quadraticBezierTo(86f, 28f, 90f, 34f); quadraticBezierTo(96f, 34f, 94f, 40f)
            lineTo(70f, 40f); close()
        }
        rr(Palette.cream, 14f, 57f, 30f, 3f, 1.5f)
    }
}

private fun DrawScope.soap() {
    for ((r, x, y) in listOf(Triple(9f, 32f, 28f), Triple(7f, 56f, 20f), Triple(5.5f, 72f, 34f))) {
        dot(Palette.trail, r, x, y)
        ring(Palette.sky, r, x, y, 2.5f)
    }
    rr(Pink, 16f, 44f, 68f, 40f, 14f)
    rr(Palette.coral, 16f, 72f, 68f, 12f, 6f)
    rr(Pink, 16f, 44f, 68f, 34f, 14f)
    rr(Palette.cream, 26f, 51f, 22f, 6f, 3f)
}

private fun DrawScope.bucket() {
    drawArc(Palette.ink, 180f, 180f, false, Offset(22f, 10f), Size(56f, 52f), style = Stroke(3.5f, cap = StrokeCap.Round))
    fill(Palette.sky) { moveTo(20f, 38f); lineTo(80f, 38f); lineTo(71f, 90f); lineTo(29f, 90f); close() }
    ov(Palette.trail, 20f, 31f, 60f, 14f)
    ovS(Palette.sky, 20f, 31f, 60f, 14f, 3f)
    fill(Palette.lavender) { moveTo(25f, 58f); lineTo(75f, 58f); lineTo(74f, 64f); lineTo(26f, 64f); close() }
    dot(Palette.ink, 3f, 22f, 38f)
    dot(Palette.ink, 3f, 78f, 38f)
}

private fun DrawScope.door() {
    rr(Grey, 18f, 86f, 64f, 7f, 2f)
    rr(Brown, 24f, 8f, 52f, 80f, 3f)
    rr(Wood, 29f, 13f, 42f, 75f)
    rrS(Brown, 35f, 19f, 30f, 26f, 3f, 2.5f)
    rrS(Brown, 35f, 52f, 30f, 28f, 3f, 2.5f)
    dot(Palette.sunflower, 4f, 64f, 50f)
    dot(Palette.sunflowerInk, 1.5f, 64f, 50f)
}

private fun DrawScope.window() {
    rr(Brown, 16f, 12f, 68f, 70f, 4f)
    rr(Palette.trail, 21f, 17f, 58f, 60f)
    ln(Palette.cream, 58f, 24f, 68f, 34f, 3f)
    ln(Palette.cream, 28f, 54f, 36f, 62f, 3f)
    rr(Brown, 48f, 17f, 4f, 60f)
    rr(Brown, 21f, 45f, 58f, 4f)
    fill(Palette.coral) {
        moveTo(21f, 17f); lineTo(38f, 17f); quadraticBezierTo(28f, 38f, 30f, 52f); quadraticBezierTo(26f, 66f, 30f, 77f); lineTo(21f, 77f); close()
    }
    fill(Palette.coral) {
        moveTo(79f, 17f); lineTo(62f, 17f); quadraticBezierTo(72f, 38f, 70f, 52f); quadraticBezierTo(74f, 66f, 70f, 77f); lineTo(79f, 77f); close()
    }
    rr(Palette.sunflower, 23f, 50f, 9f, 4f, 2f)
    rr(Palette.sunflower, 68f, 50f, 9f, 4f, 2f)
    rr(Palette.coralInk, 14f, 10f, 72f, 6f, 3f)
    rr(Brown, 10f, 80f, 80f, 8f, 3f)
}

private fun DrawScope.box() {
    translate(0f, -4f) {
        rr(Wood, 16f, 42f, 50f, 46f)
        fill(Brown) { moveTo(66f, 42f); lineTo(86f, 28f); lineTo(86f, 74f); lineTo(66f, 88f); close() }
        fill(Palette.outline) { moveTo(16f, 42f); lineTo(36f, 28f); lineTo(86f, 28f); lineTo(66f, 42f); close() }
        fill(Palette.sunflowerSoft) { moveTo(37f, 42f); lineTo(57f, 28f); lineTo(65f, 28f); lineTo(45f, 42f); close() }
        rr(Palette.sunflowerSoft, 37f, 42f, 8f, 16f)
        ln(Brown, 22f, 76f, 34f, 76f, 2.5f)
    }
}

private fun DrawScope.sock() {
    fill(Palette.coral) {
        moveTo(34f, 10f); lineTo(64f, 10f); lineTo(64f, 52f); lineTo(80f, 60f); cubicTo(94f, 67f, 92f, 90f, 74f, 88f)
        lineTo(46f, 80f); cubicTo(28f, 75f, 28f, 60f, 34f, 52f); close()
    }
    rr(Palette.sunflower, 34f, 10f, 30f, 12f)
    rr(Palette.sunflower, 34f, 28f, 30f, 6f)
    rr(Palette.sunflower, 34f, 40f, 30f, 6f)
    fill(Palette.sky) { moveTo(80f, 60f); cubicTo(94f, 67f, 92f, 90f, 74f, 88f); lineTo(72f, 87.5f); quadraticBezierTo(80f, 74f, 74f, 57f); close() }
    fill(Palette.sky) { moveTo(46f, 80f); cubicTo(28f, 75f, 28f, 60f, 34f, 52f); lineTo(38f, 54f); quadraticBezierTo(38f, 72f, 50f, 81f); close() }
}

private fun DrawScope.glasses() {
    translate(0f, -2f) {
        ln(Palette.ink, 14f, 48f, 6f, 40f, 4f)
        ln(Palette.ink, 86f, 48f, 94f, 40f, 4f)
        dot(Palette.trail, 17f, 30f, 54f)
        dot(Palette.trail, 17f, 70f, 54f)
        ln(Palette.cream, 22f, 52f, 30f, 44f, 3f)
        ln(Palette.cream, 62f, 52f, 70f, 44f, 3f)
        ring(Palette.ink, 17f, 30f, 54f, 5f)
        ring(Palette.ink, 17f, 70f, 54f, 5f)
        drawArc(Palette.ink, 200f, 140f, false, Offset(43f, 46f), Size(14f, 12f), style = Stroke(4.5f, cap = StrokeCap.Round))
    }
}

private fun DrawScope.ladder() {
    for (i in 0 until 6) {
        val y = 16f + i * 14f
        val t = (y - 8f) / 84f
        ln(Wood, 34f - 8f * t, y, 66f + 8f * t, y, 5f)
    }
    ln(Brown, 34f, 8f, 26f, 92f, 6f)
    ln(Brown, 66f, 8f, 74f, 92f, 6f)
}

private fun DrawScope.candle() {
    ov(Grey, 22f, 80f, 56f, 12f)
    ov(GreyLight, 30f, 80f, 40f, 7f)
    rr(Palette.coral, 38f, 36f, 24f, 50f, 3f)
    fill(Pink) {
        moveTo(38f, 39f); quadraticBezierTo(38f, 36f, 41f, 36f); lineTo(59f, 36f); quadraticBezierTo(62f, 36f, 62f, 39f); lineTo(62f, 44f)
        quadraticBezierTo(58f, 48f, 56f, 44f); lineTo(56f, 52f); quadraticBezierTo(53f, 56f, 51f, 52f); lineTo(51f, 44f); quadraticBezierTo(44f, 50f, 38f, 44f); close()
    }
    ln(Palette.ink, 50f, 36f, 50f, 28f, 2.5f)
    fill(Palette.sunflower) {
        moveTo(50f, 6f); cubicTo(58f, 16f, 61f, 22f, 59f, 27f); cubicTo(57f, 33f, 43f, 33f, 41f, 27f); cubicTo(39f, 22f, 42f, 16f, 50f, 6f); close()
    }
    ov(Palette.coral, 46f, 20f, 8f, 10f)
}

private fun DrawScope.broom() {
    rotate(22f, Offset(50f, 50f)) {
        fill(Palette.sunflowerSoft) {
            moveTo(43f, 34f); lineTo(57f, 34f); quadraticBezierTo(72f, 60f, 80f, 94f); quadraticBezierTo(50f, 98f, 20f, 94f); quadraticBezierTo(28f, 60f, 43f, 34f); close()
        }
        for (i in 0 until 7) {
            val bx = 28f + i * 7.4f
            ln(Palette.sunflower, 50f + (i - 3) * 1.5f, 38f, bx, 92f, 2.5f)
        }
        rr(Palette.coral, 41f, 6f, 18f, 34f, 7f)
        for (y in listOf(14f, 22f, 30f)) ln(Palette.sunflowerSoft, 43f, y, 57f, y + 3f, 2.5f)
    }
}

private fun DrawScope.hammer() {
    rotate(35f, Offset(50f, 50f)) {
        rr(Brown, 45f, 28f, 10f, 64f, 4f)
        rr(Palette.coral, 44f, 66f, 12f, 26f, 5f)
        rr(Grey, 26f, 14f, 46f, 18f, 3f)
        rr(Palette.muted, 24f, 13f, 9f, 20f, 2f)
        fill(Grey) { moveTo(72f, 14f); quadraticBezierTo(80f, 14f, 84f, 7f); lineTo(84f, 24f); quadraticBezierTo(80f, 32f, 72f, 32f); close() }
    }
}

private fun DrawScope.magnet() {
    drawArc(Palette.coral, 180f, 180f, false, Offset(25f, 22f), Size(50f, 50f), style = Stroke(18f))
    rr(Palette.coral, 16f, 46f, 18f, 24f)
    rr(Palette.coral, 66f, 46f, 18f, 24f)
    rr(Grey, 16f, 68f, 18f, 16f)
    rr(Grey, 66f, 68f, 18f, 16f)
    strokeP(Palette.cream, 3f) { moveTo(22f, 46f); lineTo(22f, 38f); quadraticBezierTo(26f, 26f, 36f, 21f) }
}

private fun DrawScope.stone() {
    scale(1.12f, Offset(52f, 58f)) {
        fill(Grey) {
            moveTo(14f, 70f); cubicTo(10f, 50f, 26f, 30f, 48f, 28f); cubicTo(68f, 24f, 90f, 38f, 90f, 60f)
            cubicTo(92f, 78f, 74f, 86f, 50f, 86f); cubicTo(28f, 86f, 16f, 82f, 14f, 70f); close()
        }
        fill(GreyLight) { moveTo(26f, 52f); cubicTo(28f, 40f, 40f, 34f, 52f, 34f); cubicTo(42f, 40f, 36f, 46f, 34f, 56f); close() }
        dot(Palette.muted, 3f, 64f, 66f)
        dot(Palette.muted, 2f, 74f, 56f)
        dot(Palette.muted, 2.5f, 44f, 74f)
    }
}

// =================================== homes ===================================

private fun DrawScope.tent() {
    ln(Palette.mintInk, 4f, 86f, 96f, 86f, 3f)
    ln(Palette.ink, 50f, 20f, 50f, 8f, 3f)
    fill(Palette.sunflower) { moveTo(51f, 8f); lineTo(64f, 12f); lineTo(51f, 16f); close() }
    ln(Palette.ink, 22f, 64f, 8f, 86f, 2f)
    ln(Palette.ink, 78f, 64f, 92f, 86f, 2f)
    fill(Palette.coral) { moveTo(12f, 86f); lineTo(50f, 18f); lineTo(88f, 86f); close() }
    fill(Palette.ink) { moveTo(38f, 86f); lineTo(50f, 48f); lineTo(62f, 86f); close() }
    fill(Palette.sunflowerSoft) { moveTo(50f, 48f); lineTo(62f, 86f); lineTo(72f, 86f); close() }
}

private fun DrawScope.igloo() {
    val dome = pth { moveTo(10f, 82f); arcTo(Rect(10f, 24f, 90f, 140f), 180f, 180f, false); close() }
    drawPath(dome, Palette.trail)
    clipPath(dome) {
        for (y in listOf(40f, 54f, 68f)) ln(Palette.sky, 0f, y, 100f, y, 2.5f)
        val rows = listOf(24f to listOf(42f, 58f), 40f to listOf(30f, 50f, 70f), 54f to listOf(20f, 40f, 60f, 80f), 68f to listOf(30f, 50f, 70f))
        for ((y, xs) in rows) for (x in xs) ln(Palette.sky, x, y, x, y + 14f, 2.5f)
    }
    drawPath(dome, Palette.sky, style = Stroke(3f))
    val door = pth { moveTo(34f, 84f); arcTo(Rect(34f, 56f, 66f, 112f), 180f, 180f, false); close() }
    drawPath(door, Palette.trail)
    drawPath(door, Palette.sky, style = Stroke(3f))
    fill(Palette.ink) { moveTo(41f, 84f); arcTo(Rect(41f, 64f, 59f, 104f), 180f, 180f, false); close() }
    ln(Palette.sky, 6f, 84f, 94f, 84f, 3f)
}

private fun DrawScope.hut() {
    rr(Wood, 24f, 50f, 52f, 36f)
    fill(Brown) { moveTo(42f, 86f); lineTo(42f, 72f); arcTo(Rect(42f, 64f, 58f, 80f), 180f, 180f, false); lineTo(58f, 86f); close() }
    ln(Palette.mintInk, 10f, 87f, 90f, 87f, 3f)
    fill(Palette.sunflower) {
        moveTo(50f, 12f); lineTo(92f, 58f)
        for (i in 0 until 5) { val x = 92f - i * 16.8f; quadraticBezierTo(x - 8.4f, 66f, x - 16.8f, 58f) }
        close()
    }
    for ((x, y) in listOf(24f to 56f, 38f to 59f, 62f to 59f, 76f to 56f)) ln(Palette.sunflowerInk, 50f, 20f, x, y, 2f)
    ln(Brown, 50f, 12f, 50f, 6f, 3f)
}

// =================================== places ===================================

private fun DrawScope.school() {
    translate(0f, 3f) {
        rr(Palette.sunflowerSoft, 10f, 46f, 80f, 40f)
        rr(Palette.coral, 6f, 42f, 88f, 6f, 2f)
        rr(Palette.sunflowerSoft, 35f, 32f, 30f, 54f)
        fill(Palette.coral) { moveTo(31f, 34f); lineTo(50f, 18f); lineTo(69f, 34f); close() }
        // bell in the gable
        fill(Palette.sunflower) { moveTo(45f, 32f); quadraticBezierTo(46f, 23f, 50f, 23f); quadraticBezierTo(54f, 23f, 55f, 32f); close() }
        dot(Palette.ink, 1.6f, 50f, 33f)
        // flag
        ln(Palette.ink, 50f, 19f, 50f, 2f, 2.5f)
        rr(Saffron, 51f, 2f, 15f, 3.4f)
        rr(Palette.cream, 51f, 5.4f, 15f, 3.4f)
        rr(Palette.mintInk, 51f, 8.8f, 15f, 3.4f)
        dot(Palette.sky, 1.2f, 58.5f, 7.1f)
        for (x in listOf(15f, 25f, 67f, 77f)) for (y in listOf(53f, 68f)) rr(Palette.sky, x, y, 8f, 9f, 1.5f)
        rr(Palette.sky, 41f, 40f, 18f, 8f, 1.5f)
        rr(Brown, 43f, 62f, 14f, 24f, 2f)
        ln(Palette.ink, 4f, 87f, 96f, 87f, 3f)
    }
}

private fun DrawScope.hospital() {
    translate(0f, -4f) {
        rr(Palette.trail, 14f, 30f, 72f, 60f)
        rr(Palette.sky, 10f, 26f, 80f, 6f, 2f)
        rr(Palette.card, 37f, 36f, 26f, 26f, 4f)
        rr(Palette.coral, 46f, 39f, 8f, 20f, 1.5f)
        rr(Palette.coral, 40f, 45f, 20f, 8f, 1.5f)
        for (x in listOf(19f, 29f, 63f, 73f)) for (y in listOf(38f, 54f)) rr(Palette.sky, x, y, 8f, 10f, 1.5f)
        for (x in listOf(19f, 73f)) rr(Palette.sky, x, 70f, 8f, 10f, 1.5f)
        rr(Palette.sky, 39f, 68f, 22f, 22f, 2f)
        ln(Palette.trail, 50f, 70f, 50f, 90f, 2f)
        ln(Palette.ink, 4f, 91f, 96f, 91f, 3f)
    }
}

private fun DrawScope.shop() {
    rr(Palette.coral, 12f, 10f, 76f, 16f, 4f)
    for (i in 0 until 4) dot(Palette.sunflowerSoft, 2.5f, 26f + i * 16f, 18f)
    rr(Palette.sunflowerSoft, 14f, 26f, 72f, 62f)
    // shelves with jars
    rr(Brown, 20f, 46f, 60f, 26f)
    for ((i, c) in listOf(Palette.mint, Palette.sky, Palette.coral, Palette.lavender, Palette.sunflower).withIndex()) {
        rr(c, 24f + i * 11.2f, 50f, 8f, 9f, 2f)
    }
    rr(Palette.sunflowerSoft, 20f, 60f, 60f, 2.5f)
    for (i in 0 until 6) dot(if (i % 2 == 0) Palette.sunflower else Palette.coral, 3.5f, 27f + i * 9.2f, 67f)
    rr(Wood, 16f, 70f, 68f, 18f, 2f)
    rr(Palette.sunflowerInk, 16f, 70f, 68f, 3f)
    // awning
    val sw = 80f / 9f
    for (i in 0 until 9) {
        val x = 10f + i * sw
        val c = if (i % 2 == 0) Palette.coral else Palette.cream
        rr(c, x, 26f, sw, 14f)
        drawArc(c, 0f, 180f, true, Offset(x, 40f - sw / 2f), Size(sw, sw))
    }
}

private fun DrawScope.temple() {
    rr(Wood, 10f, 84f, 80f, 6f, 1.5f)
    rr(Brown, 14f, 80f, 72f, 5f, 1.5f)
    // side shrines
    for (x in listOf(13f, 69f)) {
        rr(Palette.sunflowerSoft, x, 62f, 18f, 18f)
        fill(Palette.sunflower) { moveTo(x - 2f, 64f); quadraticBezierTo(x + 2f, 52f, x + 9f, 46f); quadraticBezierTo(x + 16f, 52f, x + 20f, 64f); close() }
        rr(Brown, x + 6f, 68f, 6f, 12f, 3f)
    }
    // main shrine and shikhara
    rr(Palette.sunflowerSoft, 30f, 54f, 40f, 30f)
    val shikhara = pth { moveTo(28f, 58f); cubicTo(28f, 40f, 40f, 28f, 46f, 20f); lineTo(54f, 20f); cubicTo(60f, 28f, 72f, 40f, 72f, 58f); close() }
    drawPath(shikhara, Palette.sunflower)
    clipPath(shikhara) {
        for (y in listOf(28f, 36f, 44f, 52f)) ln(Palette.sunflowerInk, 0f, y, 100f, y, 2f)
        ln(Palette.sunflowerInk, 50f, 20f, 50f, 58f, 2f)
    }
    ov(Palette.sunflowerSoft, 41f, 15f, 18f, 7f)
    dot(Palette.sunflowerInk, 3f, 50f, 13f)
    ln(Palette.ink, 50f, 12f, 50f, 2f, 2f)
    fill(Saffron) { moveTo(51f, 2f); lineTo(64f, 5.5f); lineTo(51f, 9f); close() }
    fill(Brown) { moveTo(42f, 84f); lineTo(42f, 70f); arcTo(Rect(42f, 62f, 58f, 78f), 180f, 180f, false); lineTo(58f, 84f); close() }
    dot(Palette.sunflower, 2f, 50f, 72f)
}

private fun DrawScope.mosque() {
    val wall = Palette.cream
    val edge = Palette.outline
    // minarets
    for (x in listOf(8f, 80f)) {
        fill(Palette.mint) { moveTo(x - 1f, 32f); quadraticBezierTo(x - 1f, 24f, x + 6f, 16f); quadraticBezierTo(x + 13f, 24f, x + 13f, 32f); close() }
        ln(Palette.sunflower, x + 6f, 16f, x + 6f, 10f, 2.5f)
        rr(wall, x, 32f, 12f, 56f)
        rrS(edge, x, 32f, 12f, 56f, 0f, 2.5f)
        rr(Palette.mint, x - 2f, 46f, 16f, 5f, 2f)
        rr(Palette.mintInk, x + 4f, 58f, 4f, 9f, 2f)
    }
    // dome
    fill(Palette.mint) { moveTo(28f, 52f); cubicTo(22f, 36f, 40f, 28f, 50f, 18f); cubicTo(60f, 28f, 78f, 36f, 72f, 52f); close() }
    ln(Palette.sunflower, 50f, 18f, 50f, 12f, 2.5f)
    fill(Palette.sunflower) { moveTo(50f, 2f); cubicTo(57f, 2f, 57f, 12f, 50f, 12f); cubicTo(53.5f, 10f, 53.5f, 4f, 50f, 2f); close() }
    // hall
    rr(wall, 22f, 50f, 56f, 38f)
    rrS(edge, 22f, 50f, 56f, 38f, 0f, 2.5f)
    rr(Palette.mint, 22f, 50f, 56f, 5f)
    fill(Palette.mintInk) { moveTo(42f, 88f); lineTo(42f, 72f); quadraticBezierTo(42f, 64f, 50f, 60f); quadraticBezierTo(58f, 64f, 58f, 72f); lineTo(58f, 88f); close() }
    for (x in listOf(28f, 64f)) fill(Palette.mintInk) { moveTo(x, 76f); lineTo(x, 68f); quadraticBezierTo(x, 63f, x + 4f, 61f); quadraticBezierTo(x + 8f, 63f, x + 8f, 68f); lineTo(x + 8f, 76f); close() }
    ln(Palette.ink, 4f, 89f, 96f, 89f, 3f)
}

private fun DrawScope.church() {
    val wall = Palette.cream
    val edge = Palette.outline
    // nave
    fill(Palette.coral) { moveTo(14f, 56f); lineTo(50f, 38f); lineTo(86f, 56f); close() }
    rr(wall, 18f, 54f, 64f, 34f)
    rrS(edge, 18f, 54f, 64f, 34f, 0f, 2.5f)
    for (x in listOf(24f, 68f)) fill(Palette.sky) { moveTo(x, 78f); lineTo(x, 66f); quadraticBezierTo(x + 4f, 60f, x + 8f, 66f); lineTo(x + 8f, 78f); close() }
    // tower and steeple
    rr(wall, 38f, 30f, 24f, 58f)
    rrS(edge, 38f, 30f, 24f, 58f, 0f, 2.5f)
    fill(Palette.coral) { moveTo(35f, 32f); lineTo(50f, 12f); lineTo(65f, 32f); close() }
    ln(Palette.ink, 50f, 13f, 50f, 1f, 3.5f)
    ln(Palette.ink, 45f, 5f, 55f, 5f, 3.5f)
    dot(Palette.sky, 5f, 50f, 44f)
    ring(Palette.sunflower, 5f, 50f, 44f, 2f)
    fill(Brown) { moveTo(43f, 88f); lineTo(43f, 70f); arcTo(Rect(43f, 63f, 57f, 77f), 180f, 180f, false); lineTo(57f, 88f); close() }
    ln(Palette.ink, 4f, 89f, 96f, 89f, 3f)
}

private fun DrawScope.gurudwara() {
    val wall = Palette.cream
    val edge = Palette.outline
    // Nishan Sahib
    ln(Palette.ink, 10f, 88f, 10f, 6f, 3f)
    fill(Saffron) { moveTo(11f, 6f); lineTo(28f, 12f); lineTo(11f, 18f); close() }
    dot(Palette.sunflower, 2.5f, 10f, 5f)
    // central gold dome
    fill(Palette.sunflower) { moveTo(36f, 46f); cubicTo(28f, 32f, 42f, 26f, 54f, 18f); cubicTo(66f, 26f, 80f, 32f, 72f, 46f); close() }
    for (dx in listOf(-8f, 0f, 8f)) strokeP(Palette.sunflowerInk, 1.8f) { moveTo(54f + dx * 1.6f, 45f); quadraticBezierTo(54f + dx * 1.2f, 30f, 54f, 20f) }
    ln(Palette.sunflowerInk, 54f, 19f, 54f, 10f, 2.5f)
    dot(Palette.sunflower, 3f, 54f, 13f)
    // building
    rr(wall, 22f, 44f, 64f, 44f)
    rrS(edge, 22f, 44f, 64f, 44f, 0f, 2.5f)
    rr(Palette.sunflowerSoft, 22f, 44f, 64f, 6f)
    // corner kiosks
    for (x in listOf(22f, 86f)) {
        fill(Palette.sunflower) { moveTo(x - 7f, 44f); quadraticBezierTo(x - 7f, 36f, x, 30f); quadraticBezierTo(x + 7f, 36f, x + 7f, 44f); close() }
        ln(Palette.sunflowerInk, x, 30f, x, 25f, 2f)
    }
    // arches
    for (x in listOf(30f, 47f, 64f)) {
        val w = if (x == 47f) 14f else 12f
        val h = if (x == 47f) 30f else 22f
        fill(Palette.sunflowerInk) { moveTo(x, 88f); lineTo(x, 88f - h + w / 2f); quadraticBezierTo(x, 88f - h, x + w / 2f, 88f - h - 3f); quadraticBezierTo(x + w, 88f - h, x + w, 88f - h + w / 2f); lineTo(x + w, 88f); close() }
    }
    ln(Palette.ink, 4f, 89f, 96f, 89f, 3f)
}

private fun DrawScope.park() {
    rr(Palette.garden, 4f, 78f, 92f, 12f, 6f)
    // tree
    rr(Brown, 69f, 40f, 9f, 42f, 2f)
    dot(Palette.mint, 22f, 73f, 34f)
    dot(Palette.mintInk, 9f, 64f, 28f)
    // bench
    ln(Palette.ink, 18f, 70f, 16f, 84f, 3.5f)
    ln(Palette.ink, 54f, 70f, 56f, 84f, 3.5f)
    ln(Palette.ink, 20f, 56f, 20f, 68f, 3f)
    ln(Palette.ink, 52f, 56f, 52f, 68f, 3f)
    rr(Brown, 12f, 50f, 48f, 6f, 3f)
    rr(Brown, 12f, 59f, 48f, 6f, 3f)
    rr(Brown, 9f, 67f, 54f, 7f, 3f)
    // flowers
    for (x in listOf(30f, 42f)) { dot(Palette.coral, 3.5f, x, 84f); dot(Palette.sunflower, 1.5f, x, 84f) }
}

private fun DrawScope.farm() {
    // haystack
    fill(Palette.sunflower) { moveTo(64f, 68f); quadraticBezierTo(64f, 44f, 78f, 44f); quadraticBezierTo(92f, 44f, 92f, 68f); close() }
    ln(Palette.sunflowerInk, 70f, 56f, 76f, 60f, 2f); ln(Palette.sunflowerInk, 82f, 52f, 86f, 58f, 2f)
    // barn
    fill(Palette.coral) { moveTo(14f, 68f); lineTo(14f, 38f); lineTo(36f, 20f); lineTo(58f, 38f); lineTo(58f, 68f); close() }
    strokeP(Brown, 3f) { moveTo(10f, 40f); lineTo(36f, 18f); lineTo(62f, 40f) }
    rr(Palette.cream, 27f, 46f, 18f, 22f)
    ln(Palette.coral, 27f, 46f, 45f, 68f, 2.5f)
    ln(Palette.coral, 45f, 46f, 27f, 68f, 2.5f)
    rr(Palette.cream, 31f, 30f, 10f, 8f, 1f)
    // field
    rr(Brown, 4f, 68f, 92f, 22f, 4f)
    for ((j, y) in listOf(73f, 80f, 87f).withIndex()) {
        for (i in 0 until 9) {
            val x = 10f + i * 10f + (if (j % 2 == 1) 5f else 0f)
            if (x > 92f) continue
            fill(Palette.mint) { moveTo(x, y + 2f); quadraticBezierTo(x - 4f, y - 2f, x - 3f, y - 5f); quadraticBezierTo(x, y - 3f, x, y + 2f); close() }
            fill(Palette.mint) { moveTo(x, y + 2f); quadraticBezierTo(x + 4f, y - 2f, x + 3f, y - 5f); quadraticBezierTo(x, y - 3f, x, y + 2f); close() }
        }
    }
}

// =================================== festivals ===================================

private fun DrawScope.diya() {
    translate(0f, 4f) {
        // flame
        fill(Palette.sunflower) {
            moveTo(50f, 8f); cubicTo(58f, 22f, 64f, 32f, 62f, 39f); cubicTo(60f, 49f, 40f, 49f, 38f, 39f); cubicTo(36f, 32f, 42f, 22f, 50f, 8f); close()
        }
        ov(Palette.coral, 44f, 28f, 12f, 16f)
        ln(Palette.ink, 50f, 44f, 50f, 50f, 2.5f)
        // bowl
        ov(Brown, 12f, 46f, 76f, 14f)
        fill(Clay) { moveTo(8f, 52f); quadraticBezierTo(50f, 62f, 92f, 52f); cubicTo(86f, 76f, 70f, 82f, 50f, 82f); cubicTo(30f, 82f, 14f, 76f, 8f, 52f); close() }
        rr(Clay, 40f, 78f, 20f, 7f, 2f)
        for (i in 0 until 5) dot(Palette.sunflower, 2.5f, 30f + i * 10f, 68f)
        ln(Palette.sunflowerSoft, 20f, 61f, 80f, 61f, 2f)
    }
}

private fun DrawScope.rangoli() {
    val c = Offset(50f, 50f)
    for (i in 0 until 8) rotate(i * 45f, c) { ov(Palette.coral, 42f, 8f, 16f, 30f) }
    for (i in 0 until 8) rotate(22.5f + i * 45f, c) {
        ov(Palette.sunflower, 44f, 22f, 12f, 22f)
        dot(Palette.lavender, 3.5f, 50f, 10f)
    }
    dot(Palette.mint, 14f, 50f, 50f)
    for (i in 0 until 8) rotate(i * 45f, c) { dot(Palette.cream, 2.5f, 50f, 41f) }
    dot(Palette.sky, 6f, 50f, 50f)
}

private fun DrawScope.pichkari() {
    translate(-4f, 4f) {
        // spray
        val drops = listOf(Triple(86f, 42f, Palette.coral), Triple(93f, 36f, Palette.sky), Triple(97f, 46f, Palette.lavender),
            Triple(90f, 50f, Palette.mint), Triple(100f, 30f, Palette.coral), Triple(84f, 34f, Palette.sunflower))
        for ((x, y, col) in drops) dot(col, 3.5f, x, y)
        // plunger
        ln(Palette.ink, 24f, 50f, 8f, 50f, 4f)
        rr(Palette.coral, 4f, 36f, 7f, 28f, 3.5f)
        // barrel
        rr(Palette.mint, 22f, 36f, 50f, 28f, 6f)
        rr(Palette.garden, 30f, 42f, 30f, 5f, 2.5f)
        rr(Palette.sunflower, 18f, 33f, 8f, 34f, 3f)
        rr(Palette.sunflower, 66f, 33f, 8f, 34f, 3f)
        fill(Palette.sunflower) { moveTo(72f, 42f); lineTo(84f, 47f); lineTo(84f, 53f); lineTo(72f, 58f); close() }
    }
}

private fun DrawScope.lantern() {
    ln(Palette.ink, 50f, 2f, 50f, 16f, 2.5f)
    rr(Palette.sunflowerInk, 38f, 13f, 24f, 7f, 2f)
    ov(Palette.coral, 20f, 16f, 60f, 66f)
    ov(Palette.sunflowerSoft, 38f, 34f, 24f, 30f)
    ovS(Palette.coralInk, 32f, 16f, 36f, 66f, 2.5f)
    ln(Palette.coralInk, 50f, 17f, 50f, 81f, 2.5f)
    rr(Palette.sunflowerInk, 38f, 78f, 24f, 7f, 2f)
    for (dx in listOf(-5f, 0f, 5f)) ln(Palette.sunflower, 50f + dx * 0.4f, 85f, 50f + dx, 97f, 3f)
}

private fun DrawScope.giftbox() {
    rr(Palette.coral, 20f, 50f, 60f, 38f, 2f)
    rr(Palette.coralInk, 20f, 50f, 60f, 4f)
    rr(Palette.coral, 15f, 38f, 70f, 14f, 3f)
    rr(Palette.sunflower, 45f, 38f, 10f, 50f)
    fill(Palette.sunflower) { moveTo(50f, 38f); cubicTo(38f, 14f, 18f, 26f, 30f, 36f); quadraticBezierTo(38f, 40f, 50f, 38f); close() }
    fill(Palette.sunflower) { moveTo(50f, 38f); cubicTo(62f, 14f, 82f, 26f, 70f, 36f); quadraticBezierTo(62f, 40f, 50f, 38f); close() }
    ov(Palette.sunflowerInk, 44f, 32f, 12f, 9f)
}

private fun DrawScope.balloon() {
    strokeP(Palette.ink, 2.5f) { moveTo(50f, 76f); cubicTo(42f, 84f, 58f, 88f, 48f, 97f) }
    fill(Palette.coral) { moveTo(45f, 80f); lineTo(50f, 72f); lineTo(55f, 80f); close() }
    fill(Palette.coral) {
        moveTo(50f, 76f); cubicTo(28f, 68f, 18f, 48f, 20f, 34f); cubicTo(22f, 16f, 38f, 6f, 50f, 6f)
        cubicTo(62f, 6f, 78f, 16f, 80f, 34f); cubicTo(82f, 48f, 72f, 68f, 50f, 76f); close()
    }
    rotate(-25f, Offset(36f, 28f)) { ov(Palette.cream, 31f, 18f, 9f, 18f) }
}

// =================================== music ===================================

private fun DrawScope.guitar() {
    translate(7f, -6f) { rotate(38f, Offset(50f, 50f)) {
        rr(Brown, 46f, 6f, 8f, 46f, 1f)
        rr(Brown, 43f, 0f, 14f, 12f, 3f)
        for (y in listOf(3f, 8f)) { dot(Palette.cream, 1.6f, 45f, y); dot(Palette.cream, 1.6f, 55f, y) }
        dot(Palette.sunflower, 16f, 50f, 50f)
        dot(Palette.sunflower, 22f, 50f, 74f)
        rr(Palette.sunflower, 38f, 50f, 24f, 20f)
        dot(Palette.ink, 7f, 50f, 60f)
        rr(Brown, 41f, 78f, 18f, 5f, 2f)
        for (x in listOf(48f, 50f, 52f)) ln(Palette.cream, x, 8f, x, 80f, 1f)
    } }
}

private fun DrawScope.flute() {
    rotate(-28f, Offset(50f, 50f)) {
        rr(Wood, 4f, 44f, 92f, 12f, 6f)
        rr(Palette.sunflowerInk, 4f, 44f, 8f, 12f, 4f)
        for (x in listOf(14f, 28f, 88f)) rr(Palette.coral, x, 43f, 4f, 14f, 1.5f)
        dot(Palette.ink, 3f, 22f, 50f)
        for (i in 0 until 6) dot(Palette.ink, 2.6f, 44f + i * 7.5f, 50f)
        ln(Palette.sunflowerSoft, 34f, 46.5f, 84f, 46.5f, 1.8f)
    }
    strokeP(Palette.coral, 2.5f) { moveTo(18f, 70f); quadraticBezierTo(14f, 80f, 20f, 88f) }
    strokeP(Palette.coral, 2.5f) { moveTo(18f, 70f); quadraticBezierTo(24f, 80f, 26f, 86f) }
}

private fun DrawScope.tabla() {
    translate(0f, -6f) {
        // bayan (metal, left)
        fill(Grey) { moveTo(12f, 54f); cubicTo(4f, 76f, 16f, 94f, 32f, 94f); cubicTo(48f, 94f, 60f, 76f, 52f, 54f); close() }
        fill(GreyLight) { moveTo(16f, 62f); cubicTo(14f, 74f, 18f, 84f, 24f, 88f); cubicTo(20f, 80f, 20f, 70f, 22f, 62f); close() }
        ov(Palette.cream, 12f, 47f, 40f, 14f)
        ovS(Palette.outline, 12f, 47f, 40f, 14f, 2.5f)
        ov(Palette.ink, 20f, 50f, 14f, 7f)
        // dayan (wood, right)
        fill(Brown) { moveTo(58f, 40f); lineTo(88f, 40f); lineTo(85f, 92f); lineTo(61f, 92f); close() }
        for (i in 0 until 4) { val x = 63f + i * 6.5f; ln(Palette.sunflowerSoft, x, 44f, x + (73f - x) * 0.08f, 90f, 2f) }
        rr(Palette.coral, 59f, 66f, 28f, 6f, 2f)
        ov(Palette.cream, 57f, 34f, 32f, 12f)
        ovS(Palette.outline, 57f, 34f, 32f, 12f, 2.5f)
        ov(Palette.ink, 66f, 37f, 14f, 6f)
    }
}

private fun DrawScope.piano() {
    translate(0f, -4f) {
        rr(Palette.ink, 12f, 72f, 6f, 20f, 2f)
        rr(Palette.ink, 82f, 72f, 6f, 20f, 2f)
        rr(Palette.ink, 6f, 26f, 88f, 50f, 6f)
        dot(Palette.coral, 3f, 16f, 34f); dot(Palette.sunflower, 3f, 25f, 34f); dot(Palette.mint, 3f, 34f, 34f)
        rr(Palette.sky, 60f, 31f, 26f, 7f, 2f)
        val w = 80f / 8f
        for (i in 0 until 8) rr(Palette.cream, 10f + i * w + 0.8f, 44f, w - 1.6f, 28f, 1.5f)
        for (i in listOf(1, 2, 4, 5, 6)) rr(Palette.ink, 10f + i * w - 3f, 44f, 6f, 16f, 1f)
    }
}

private fun DrawScope.trumpet() {
    translate(0f, -2f) {
        rrS(Palette.sunflower, 28f, 50f, 38f, 22f, 11f, 5f)
        rr(Palette.sunflower, 12f, 49f, 58f, 7f, 3f)
        rr(Palette.sunflowerInk, 4f, 47f, 10f, 11f, 3f)
        fill(Palette.sunflower) { moveTo(64f, 48f); quadraticBezierTo(78f, 46f, 88f, 32f); lineTo(88f, 74f); quadraticBezierTo(78f, 60f, 64f, 57f); close() }
        ov(Palette.sunflowerInk, 84f, 32f, 9f, 42f)
        ov(Palette.sunflowerSoft, 86f, 35f, 5f, 36f)
        for (x in listOf(34f, 44f, 54f)) {
            rr(Palette.sunflowerInk, x, 38f, 6f, 14f, 1.5f)
            rr(Palette.sunflower, x - 1.5f, 32f, 9f, 6f, 3f)
        }
    }
}

private fun DrawScope.dholak() {
    // far head
    ov(Palette.cream, 10f, 30f, 18f, 44f)
    ovS(Palette.outline, 10f, 30f, 18f, 44f, 2.5f)
    // barrel
    fill(Palette.coral) {
        moveTo(19f, 30f); quadraticBezierTo(50f, 20f, 81f, 30f); lineTo(81f, 74f); quadraticBezierTo(50f, 84f, 19f, 74f); close()
    }
    strokeP(Palette.cream, 2.5f) {
        moveTo(22f, 31f)
        for (i in 1..8) {
            val x = 22f + i * 7.25f
            val top = 30f - 7f * (1f - ((x - 50f) / 31f) * ((x - 50f) / 31f))
            val bot = 74f + 7f * (1f - ((x - 50f) / 31f) * ((x - 50f) / 31f))
            lineTo(x, if (i % 2 == 1) bot - 1f else top + 1f)
        }
    }
    for (x in listOf(32f, 50f, 68f)) rr(Palette.sunflower, x - 3f, 49f, 6f, 6f, 1.5f)
    // near head
    ov(Palette.cream, 72f, 30f, 18f, 44f)
    ovS(Palette.outline, 72f, 30f, 18f, 44f, 2.5f)
}
