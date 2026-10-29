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

/** Picture library: food, fruits and vegetables, Indian food, plants, nature, space and weather. Same rules as ui/Pictures.kt (100×100 grid, flat fills from the palette). */
internal val natureFoodArt: Map<String, DrawScope.() -> Unit> = mapOf(
    // food
    "orange" to { orange() }, "grapes" to { grapes() }, "watermelon" to { watermelon() }, "pineapple" to { pineapple() },
    "strawberry" to { strawberry() }, "coconut" to { coconut() }, "guava" to { guava() }, "lemon" to { lemon() },
    "tomato" to { tomato() }, "potato" to { potato() }, "onion" to { onion() }, "peas" to { peas() }, "corn" to { corn() },
    "brinjal" to { brinjal() }, "cabbage" to { cabbage() }, "chilli" to { chilli() }, "bread" to { bread() }, "milk" to { milk() },
    "rice" to { rice() }, "roti" to { roti() }, "icecream" to { icecream() }, "cake" to { cake() }, "ladoo" to { ladoo() },
    "honey" to { honey() },
    // fruits and vegetables
    "papaya" to { papaya() }, "pomegranate" to { pomegranate() }, "cherry" to { cherry() }, "pear" to { pear() },
    "peach" to { peach() }, "plum" to { plum() }, "kiwi" to { kiwi() }, "beetroot" to { beetroot() },
    "cauliflower" to { cauliflower() }, "spinach" to { spinach() }, "pumpkin" to { pumpkin() }, "cucumber" to { cucumber() },
    "radish" to { radish() }, "garlic" to { garlic() }, "ginger" to { ginger() }, "beans" to { beans() },
    // Indian food
    "dosa" to { dosa() }, "idli" to { idli() }, "samosa" to { samosa() }, "jalebi" to { jalebi() }, "chapati" to { chapati() },
    "dal" to { dal() }, "khichdi" to { khichdi() }, "poha" to { poha() }, "paratha" to { paratha() }, "pakora" to { pakora() },
    "curd" to { curd() }, "ghee" to { ghee() }, "paneer" to { paneer() }, "sugarcane" to { sugarcane() },
    "jaggery" to { jaggery() }, "chikki" to { chikki() },
    // plants
    "rose" to { rose() }, "lotus" to { lotus() }, "sunflower" to { sunflowerPlant() }, "tulsi" to { tulsi() },
    "neem" to { neem() }, "banyan" to { banyan() }, "palm" to { palm() }, "pine" to { pine() }, "bamboo" to { bamboo() },
    "moneyplant" to { moneyplant() }, "sapling" to { sapling() }, "roots" to { roots() },
    // nature
    "mountain" to { mountain() }, "river" to { river() }, "wave" to { wave() }, "rainbow" to { rainbow() },
    "snow" to { snow() }, "wind" to { wind() }, "lightning" to { lightning() }, "grass" to { grass() },
    "cactus" to { cactus() }, "mushroom" to { mushroom() }, "nest" to { nest() }, "shell" to { shell() }, "pond" to { pond() },
    // space
    "earth" to { earth() }, "saturn" to { saturn() }, "planet" to { planet() }, "comet" to { comet() },
    "telescope" to { telescope() }, "astronaut" to { astronaut() },
    // weather
    "fog" to { fog() }, "storm" to { storm() }, "hail" to { hail() },
)

// ---- colours (palette first; these only where a food truly needs its own) ----
private val Brown = Color(0xFF8A5A00)
private val Grey = Color(0xFF9AA3B5)
private val Pink = Color(0xFFFFB3A6)
private val DarkBrown = Color(0xFF5C3A00)
private val Orange = Color(0xFFFF8C2E)
private val OrangeDeep = Color(0xFFF07418)
private val OrangeLight = Color(0xFFFFB45C)
private val Lemon = Color(0xFFFFDD3C)
private val LemonDeep = Color(0xFFF5C518)
private val LemonPale = Color(0xFFFFF0A0)
private val Guava = Color(0xFF8FCB5A)
private val GuavaDeep = Color(0xFF6FAE3E)
private val Grape = Color(0xFF7A4CC2)
private val GrapeLight = Color(0xFF9A72DE)
private val Red = Color(0xFFE8434F)
private val RedDeep = Color(0xFFB82A3C)
private val Tan = Color(0xFFD9A75F)
private val Onion = Color(0xFFB8467A)
private val OnionLight = Color(0xFFDB86AE)
private val PeaGreen = Color(0xFF8AD65A)
private val LeafLight = Color(0xFFA6DE84)
private val Brinjal = Color(0xFF6A3A9C)
private val BrinjalLight = Color(0xFF8E62C0)
private val Cucumber = Color(0xFF3B9B52)
private val CucumberMid = Color(0xFF7CC567)
private val CucumberPale = Color(0xFFD3F0B8)
private val Golden = Color(0xFFE8A23A)
private val GoldenDark = Color(0xFFC27A22)
private val Wheat = Color(0xFFEDC685)
private val WheatDark = Color(0xFFC48A3E)
private val Steel = Color(0xFFDDE2EA)
private val Clay = Color(0xFFC0643C)
private val ClayDark = Color(0xFF9C4A28)
private val Plum = Color(0xFF8A3A78)
private val PlumLight = Color(0xFFB0609E)
private val Peach = Color(0xFFFFAE7A)
private val PeachBlush = Color(0xFFFF8A6B)
private val Pear = Color(0xFFC8DA4F)
private val Beet = Color(0xFFA3245A)
private val Pom = Color(0xFFD12C48)
private val PomPith = Color(0xFFFFE3D6)
private val Cauli = Color(0xFFF6EDD3)
private val Spinach = Color(0xFF2E9A50)
private val Kiwi = Color(0xFF8DC63F)
private val KiwiBrown = Color(0xFF9C6B3A)
private val Cane = Color(0xFF7A3E6A)
private val CaneLight = Color(0xFFA9679A)
private val Jaggery = Color(0xFFA5652A)
private val JaggeryTop = Color(0xFFC88446)
private val JaggeryDark = Color(0xFF7E4A1C)
private val Caramel = Color(0xFFDDA048)
private val Bamboo = Color(0xFF8CC63F)
private val EggBlue = Color(0xFFA9D8F2)
private val StormGrey = Color(0xFF6E7891)
private val LavenderDeep = Color(0xFF6B5BD6)
private val LavenderPale = Color(0xFFB9AFFF)
private val Jalebi = Color(0xFFFF8A1F)

// ---- helpers ----
private fun path(b: Path.() -> Unit) = Path().apply(b)

private fun DrawScope.ln(c: Color, x1: Float, y1: Float, x2: Float, y2: Float, w: Float = 4f) =
    drawLine(c, Offset(x1, y1), Offset(x2, y2), w, StrokeCap.Round)

private fun DrawScope.circ(c: Color, r: Float, x: Float, y: Float) = drawCircle(c, r, Offset(x, y))
private fun DrawScope.oval(c: Color, x: Float, y: Float, w: Float, h: Float) = drawOval(c, Offset(x, y), Size(w, h))
private fun DrawScope.rr(c: Color, x: Float, y: Float, w: Float, h: Float, r: Float) = drawRoundRect(c, Offset(x, y), Size(w, h), CornerRadius(r))
private fun DrawScope.ring(c: Color, r: Float, x: Float, y: Float, w: Float = 2.5f) = drawCircle(c, r, Offset(x, y), style = Stroke(w))
private fun DrawScope.stroke(p: Path, c: Color, w: Float = 3f) = drawPath(p, c, style = Stroke(w, cap = StrokeCap.Round, join = StrokeJoin.Round))
private fun DrawScope.soft(p: Path, c: Color, w: Float = 5f) { drawPath(p, c); drawPath(p, c, style = Stroke(w, join = StrokeJoin.Round)) }

/** A pointed leaf whose base sits at ([x],[y]) and points along [deg] (0 = right, 90 = down). [wid] is the bulge. */
private fun DrawScope.leaf(c: Color, x: Float, y: Float, len: Float, wid: Float, deg: Float) {
    translate(x, y) {
        rotate(deg, Offset.Zero) {
            drawPath(path { moveTo(0f, 0f); quadraticBezierTo(len * 0.5f, -wid, len, 0f); quadraticBezierTo(len * 0.5f, wid, 0f, 0f); close() }, c)
        }
    }
}

/** A leaf that droops at its tip (palm fronds, bamboo leaves). */
private fun DrawScope.curvedLeaf(c: Color, x: Float, y: Float, len: Float, wid: Float, deg: Float, droop: Float) {
    translate(x, y) {
        rotate(deg, Offset.Zero) {
            drawPath(path { moveTo(0f, 0f); quadraticBezierTo(len * 0.45f, -wid, len, droop); quadraticBezierTo(len * 0.55f, wid * 0.35f, 0f, 0f); close() }, c)
        }
    }
}

/** A heart-shaped leaf with its notch at ([x],[y]) and tip along [deg]. */
private fun DrawScope.heartLeaf(c: Color, x: Float, y: Float, s: Float, deg: Float, vein: Color? = null) {
    translate(x, y) {
        rotate(deg, Offset.Zero) {
            drawPath(path {
                moveTo(s * 0.2f, 0f)
                cubicTo(-s * 0.3f, -s * 1.1f, s * 1.3f, -s * 1.0f, s * 2f, 0f)
                cubicTo(s * 1.3f, s * 1.0f, -s * 0.3f, s * 1.1f, s * 0.2f, 0f); close()
            }, c)
            if (vein != null) drawLine(vein, Offset(s * 0.3f, 0f), Offset(s * 1.6f, 0f), 2f, StrokeCap.Round)
        }
    }
}

private fun DrawScope.citrusSlice(cx: Float, cy: Float, r: Float, rind: Color, flesh: Color) {
    circ(rind, r, cx, cy)
    circ(Palette.cream, r - 3f, cx, cy)
    circ(flesh, r - 4.5f, cx, cy)
    for (i in 0 until 8) {
        val a = Math.toRadians(i * 45.0 + 22.5)
        ln(Palette.cream, cx, cy, cx + (r - 4.5f) * cos(a).toFloat(), cy + (r - 4.5f) * sin(a).toFloat(), 2f)
    }
    circ(Palette.cream, 2.5f, cx, cy)
}

/** A steel thali seen at an angle, centred at [cy]. */
private fun DrawScope.plate(cy: Float, w: Float = 88f, h: Float = 30f) {
    oval(Grey, 50f - w / 2, cy - h / 2, w, h)
    oval(Steel, 50f - w / 2 + 4f, cy - h / 2 + 2.5f, w - 8f, h - 7f)
}

/** A bowl whose rim is centred at y=[rim]: body below, food surface showing as the top half of the rim oval. */
private fun DrawScope.bowl(body: Color, food: Color, rim: Float, w: Float = 76f, depth: Float = 34f) {
    val l = 50f - w / 2
    val r = 50f + w / 2
    oval(body, l, rim - 9f, w, 18f)
    oval(food, l + 3f, rim - 7f, w - 6f, 14f)
    drawPath(path { moveTo(l, rim); lineTo(r, rim); cubicTo(r, rim + depth * 0.9f, 50f + w * 0.3f, rim + depth, 50f, rim + depth); cubicTo(50f - w * 0.3f, rim + depth, l, rim + depth * 0.9f, l, rim); close() }, body)
    rr(body, 38f, rim + depth - 3f, 24f, 6f, 3f)
}

private fun DrawScope.cloudAt(c: Color, dx: Float, dy: Float, s: Float) {
    translate(dx, dy) {
        scale(s, s, Offset(50f, 50f)) {
            circ(c, 20f, 34f, 56f); circ(c, 26f, 56f, 46f); circ(c, 18f, 74f, 58f)
            rr(c, 18f, 56f, 72f, 20f, 10f)
        }
    }
}

private fun DrawScope.miniStar(c: Color, cx: Float, cy: Float, r: Float) {
    val p = Path()
    for (i in 0 until 10) {
        val rr = if (i % 2 == 0) r else r * 0.45f
        val a = Math.toRadians(-90.0 + i * 36.0)
        val x = cx + rr * cos(a).toFloat()
        val y = cy + rr * sin(a).toFloat()
        if (i == 0) p.moveTo(x, y) else p.lineTo(x, y)
    }
    p.close(); drawPath(p, c)
}

// =================================== food ===================================

private fun DrawScope.orange() {
    circ(Orange, 29f, 40f, 46f)
    for ((x, y) in listOf(28f to 38f, 34f to 58f, 48f to 50f, 52f to 34f, 26f to 50f, 42f to 66f)) circ(OrangeDeep, 1.4f, x, y)
    ln(Brown, 40f, 19f, 41f, 12f, 3.5f)
    leaf(Palette.mint, 41f, 15f, 20f, 10f, -15f)
    citrusSlice(70f, 70f, 20f, OrangeDeep, OrangeLight)
}

private fun DrawScope.grapes() {
    ln(Brown, 50f, 26f, 52f, 12f, 4f)
    leaf(Palette.mint, 52f, 16f, 26f, 14f, -20f)
    var k = 0
    for ((y, xs) in listOf(34f to listOf(29f, 43f, 57f, 71f), 48f to listOf(36f, 50f, 64f), 62f to listOf(43f, 57f), 76f to listOf(50f))) {
        for (x in xs) { circ(if (k % 2 == 0) Grape else GrapeLight, 9.5f, x, y); k++ }
    }
    for ((x, y) in listOf(26f to 31f, 47f to 45f, 40f to 59f, 47f to 73f, 68f to 31f)) circ(Palette.lavender, 2.2f, x, y)
}

private fun DrawScope.watermelon() = translate(0f, 6f) {
    drawArc(Palette.mintInk, 0f, 180f, true, Offset(5f, -21f), Size(90f, 90f))
    drawArc(Palette.garden, 0f, 180f, true, Offset(9.5f, -16.5f), Size(81f, 81f))
    drawArc(Red, 0f, 180f, true, Offset(13f, -13f), Size(74f, 74f))
    for ((x, y) in listOf(30f to 34f, 50f to 40f, 70f to 34f, 40f to 52f, 60f to 52f, 50f to 62f)) oval(Palette.ink, x - 2.2f, y - 3.2f, 4.4f, 6.4f)
}

private fun DrawScope.pineapple() {
    leaf(Palette.mint, 46f, 44f, 26f, 14f, -150f)
    leaf(Palette.mint, 54f, 44f, 26f, 14f, -30f)
    leaf(Palette.mintInk, 48f, 44f, 32f, 14f, -115f)
    leaf(Palette.mintInk, 52f, 44f, 32f, 14f, -65f)
    leaf(Palette.mint, 50f, 44f, 38f, 14f, -90f)
    val body = path { addOval(Rect(26f, 38f, 74f, 94f)) }
    drawPath(body, Palette.sunflower)
    clipPath(body) {
        var k = -60f
        while (k < 100f) {
            ln(Palette.sunflowerInk, 26f + k, 38f, 26f + k + 56f, 94f, 2.2f)
            ln(Palette.sunflowerInk, 74f - k, 38f, 74f - k - 56f, 94f, 2.2f)
            k += 11f
        }
    }
}

private fun DrawScope.strawberry() {
    drawPath(path { moveTo(50f, 30f); cubicTo(70f, 24f, 86f, 34f, 82f, 50f); cubicTo(78f, 68f, 60f, 88f, 50f, 92f); cubicTo(40f, 88f, 22f, 68f, 18f, 50f); cubicTo(14f, 34f, 30f, 24f, 50f, 30f); close() }, Red)
    for ((x, y) in listOf(32f to 44f, 50f to 42f, 68f to 44f, 40f to 56f, 60f to 56f, 28f to 58f, 72f to 58f, 50f to 68f, 40f to 72f, 60f to 72f, 50f to 82f)) oval(Palette.sunflowerSoft, x - 1.6f, y - 2.4f, 3.2f, 4.8f)
    for (a in listOf(160f, 20f, 125f, 55f, 90f)) leaf(Palette.mint, 50f, 30f, if (a == 90f) 14f else 20f, 10f, a)
    ln(Palette.mintInk, 50f, 30f, 53f, 14f, 4f)
}

private fun DrawScope.coconut() {
    circ(Brown, 30f, 40f, 46f)
    for ((x, y) in listOf(20f to 50f, 26f to 62f, 52f to 66f, 58f to 50f, 36f to 70f, 22f to 38f)) ln(DarkBrown, x, y, x + 5f, y - 3f, 2f)
    for ((x, y) in listOf(33f to 32f, 44f to 30f, 38f to 40f)) circ(DarkBrown, 3.6f, x, y)
    circ(DarkBrown, 21f, 70f, 70f)
    circ(Palette.cream, 17f, 70f, 70f)
    circ(Palette.trail, 10f, 70f, 70f)
}

private fun DrawScope.guava() {
    circ(Guava, 28f, 40f, 46f)
    for ((x, y) in listOf(28f to 40f, 50f to 36f, 36f to 60f, 52f to 56f, 24f to 52f)) circ(GuavaDeep, 1.5f, x, y)
    ln(Brown, 40f, 19f, 41f, 12f, 3.5f)
    leaf(Palette.mintInk, 41f, 15f, 24f, 10f, -15f)
    circ(Guava, 20f, 70f, 70f)
    circ(Palette.cream, 17f, 70f, 70f)
    circ(Pink, 15.5f, 70f, 70f)
    for (i in 0 until 8) {
        val a = Math.toRadians(i * 45.0)
        circ(Palette.sunflowerSoft, 1.8f, 70f + 8f * cos(a).toFloat(), 70f + 8f * sin(a).toFloat())
    }
}

private fun DrawScope.lemon() {
    rotate(-25f, Offset(40f, 44f)) {
        oval(Lemon, 12f, 26f, 56f, 38f)
        circ(Lemon, 4.5f, 10.5f, 45f)
        circ(Lemon, 4.5f, 69.5f, 45f)
    }
    leaf(Palette.mint, 56f, 26f, 18f, 9f, -40f)
    citrusSlice(70f, 70f, 20f, LemonDeep, LemonPale)
}

private fun DrawScope.tomato() {
    oval(Red, 14f, 30f, 72f, 60f)
    oval(Pink, 24f, 44f, 10f, 6f)
    for (a in listOf(170f, 10f, 130f, 50f, 90f)) leaf(Palette.mint, 50f, 33f, if (a == 90f) 12f else 18f, 9f, a)
    ln(Palette.mintInk, 50f, 33f, 50f, 20f, 4f)
}

private fun DrawScope.potato() {
    drawPath(path { moveTo(12f, 56f); cubicTo(10f, 32f, 38f, 22f, 60f, 26f); cubicTo(82f, 28f, 92f, 44f, 88f, 62f); cubicTo(84f, 80f, 60f, 86f, 42f, 82f); cubicTo(22f, 80f, 13f, 70f, 12f, 56f); close() }, Tan)
    for ((x, y) in listOf(30f to 44f, 58f to 38f, 72f to 60f, 42f to 66f, 26f to 62f)) {
        ln(Brown, x - 3f, y, x + 3f, y - 1f, 2.5f)
    }
    for ((x, y) in listOf(48f to 50f, 66f to 72f, 36f to 34f, 78f to 46f)) circ(Brown, 1.5f, x, y)
}

private fun DrawScope.onion() {
    val body = path { moveTo(50f, 18f); cubicTo(56f, 34f, 84f, 40f, 82f, 62f); cubicTo(80f, 82f, 64f, 88f, 50f, 88f); cubicTo(36f, 88f, 20f, 82f, 18f, 62f); cubicTo(16f, 40f, 44f, 34f, 50f, 18f); close() }
    drawPath(body, Onion)
    stroke(path { moveTo(50f, 22f); quadraticBezierTo(30f, 52f, 40f, 86f) }, OnionLight, 2.5f)
    stroke(path { moveTo(50f, 22f); quadraticBezierTo(70f, 52f, 60f, 86f) }, OnionLight, 2.5f)
    stroke(path { moveTo(50f, 24f); lineTo(50f, 87f) }, OnionLight, 2.5f)
    ln(Onion, 50f, 20f, 53f, 9f, 4f)
    for (dx in listOf(-6f, 0f, 6f)) ln(Brown, 50f + dx * 0.5f, 88f, 50f + dx, 95f, 2f)
}

private fun DrawScope.peas() {
    rotate(-18f, Offset(50f, 50f)) {
        drawPath(path { moveTo(8f, 50f); cubicTo(24f, 26f, 76f, 26f, 92f, 50f); cubicTo(76f, 68f, 24f, 68f, 8f, 50f); close() }, Palette.mintInk)
        drawPath(path { moveTo(14f, 48f); cubicTo(28f, 34f, 72f, 34f, 86f, 48f); cubicTo(72f, 56f, 28f, 56f, 14f, 48f); close() }, Palette.garden)
        for (x in listOf(26f, 38f, 50f, 62f, 74f)) circ(PeaGreen, 6.5f, x, 47f)
        drawPath(path { moveTo(8f, 50f); cubicTo(24f, 70f, 76f, 70f, 92f, 50f); cubicTo(76f, 60f, 24f, 60f, 8f, 50f); close() }, Palette.mint)
        stroke(path { moveTo(92f, 50f); quadraticBezierTo(98f, 44f, 95f, 36f) }, Palette.mintInk, 3f)
    }
    circ(PeaGreen, 6.5f, 34f, 82f)
    circ(PeaGreen, 6.5f, 50f, 86f)
}

private fun DrawScope.corn() {
    rotate(15f, Offset(50f, 52f)) {
        val cob = path { addOval(Rect(34f, 6f, 66f, 84f)) }
        drawPath(cob, Palette.sunflower)
        clipPath(cob) {
            var y = 9f
            var row = 0
            while (y < 84f) {
                var x = 36.5f + (row % 2) * 3.2f
                while (x < 66f) { circ(Palette.sunflowerSoft, 2.6f, x, y); x += 6.4f }
                y += 5.6f; row++
            }
        }
        leaf(Palette.mint, 50f, 96f, 64f, 24f, -110f)
        leaf(Palette.mintInk, 50f, 96f, 64f, 24f, -70f)
    }
}

private fun DrawScope.brinjal() {
    rotate(32f, Offset(50f, 54f)) {
        drawPath(path { moveTo(50f, 22f); cubicTo(62f, 22f, 66f, 34f, 68f, 48f); cubicTo(72f, 64f, 76f, 92f, 50f, 94f); cubicTo(24f, 92f, 28f, 64f, 32f, 48f); cubicTo(34f, 34f, 38f, 22f, 50f, 22f); close() }, Brinjal)
        stroke(path { moveTo(40f, 50f); quadraticBezierTo(36f, 68f, 40f, 80f) }, BrinjalLight, 4f)
        for (a in listOf(150f, 30f, 115f, 65f)) leaf(Palette.mint, 50f, 24f, 18f, 11f, a)
        oval(Palette.mint, 40f, 16f, 20f, 12f)
        ln(Palette.mintInk, 50f, 18f, 50f, 6f, 5f)
    }
}

private fun DrawScope.cabbage() {
    circ(LeafLight, 30f, 50f, 46f)
    stroke(path { moveTo(32f, 40f); quadraticBezierTo(50f, 26f, 68f, 40f) }, Palette.mint, 3f)
    leaf(Palette.mint, 50f, 92f, 76f, 48f, -124f)
    leaf(Palette.mint, 50f, 92f, 76f, 48f, -56f)
    ln(LeafLight, 50f, 92f, 25f, 56f, 2.5f)
    ln(LeafLight, 50f, 92f, 75f, 56f, 2.5f)
    ln(LeafLight, 34f, 74f, 22f, 72f, 2f)
    ln(LeafLight, 66f, 74f, 78f, 72f, 2f)
}

private fun DrawScope.chilli() {
    drawPath(path { moveTo(28f, 28f); cubicTo(18f, 58f, 44f, 88f, 90f, 90f); cubicTo(62f, 74f, 46f, 54f, 44f, 28f); close() }, Red)
    stroke(path { moveTo(33f, 40f); quadraticBezierTo(36f, 62f, 52f, 74f) }, Pink, 2.5f)
    oval(Palette.mint, 24f, 20f, 24f, 12f)
    stroke(path { moveTo(36f, 22f); quadraticBezierTo(36f, 10f, 50f, 8f) }, Palette.mintInk, 4.5f)
}

private fun DrawScope.bread() {
    val crust = Color(0xFFD08A3C)
    circ(crust, 19f, 33f, 34f); circ(crust, 19f, 67f, 34f)
    drawRect(crust, Offset(33f, 15f), Size(34f, 30f))
    rr(crust, 18f, 34f, 64f, 56f, 7f)
    circ(Palette.bazaar, 14f, 33f, 35f); circ(Palette.bazaar, 14f, 67f, 35f)
    drawRect(Palette.bazaar, Offset(33f, 21f), Size(34f, 24f))
    rr(Palette.bazaar, 23f, 34f, 54f, 50f, 4f)
    for ((x, y) in listOf(38f to 48f, 58f to 42f, 46f to 64f, 64f to 70f, 34f to 74f, 54f to 56f)) oval(Palette.outline, x - 2.5f, y - 1.6f, 5f, 3.2f)
}

private fun DrawScope.milk() {
    val bottle = path {
        moveTo(41f, 24f); lineTo(59f, 24f); lineTo(59f, 32f); cubicTo(70f, 38f, 72f, 44f, 72f, 52f); lineTo(72f, 86f)
        quadraticBezierTo(72f, 93f, 65f, 93f); lineTo(35f, 93f); quadraticBezierTo(28f, 93f, 28f, 86f); lineTo(28f, 52f)
        cubicTo(28f, 44f, 30f, 38f, 41f, 32f); close()
    }
    drawPath(bottle, Palette.cream)
    drawPath(bottle, Palette.sky, style = Stroke(3f, join = StrokeJoin.Round))
    rr(Palette.sky, 28f, 58f, 44f, 22f, 2f)
    drawPath(path { moveTo(50f, 61f); cubicTo(56f, 68f, 58f, 71f, 58f, 73f); cubicTo(58f, 78f, 42f, 78f, 42f, 73f); cubicTo(42f, 71f, 44f, 68f, 50f, 61f); close() }, Palette.cream)
    rr(Palette.sky, 38f, 10f, 24f, 12f, 4f)
}

private fun DrawScope.rice() {
    val mound = path { moveTo(18f, 52f); cubicTo(18f, 22f, 82f, 22f, 82f, 52f); close() }
    drawPath(mound, Palette.cream)
    stroke(path { moveTo(18f, 52f); cubicTo(18f, 22f, 82f, 22f, 82f, 52f) }, Palette.outline, 2.5f)
    for ((i, p) in listOf(32f to 40f, 44f to 32f, 56f to 34f, 68f to 42f, 40f to 46f, 52f to 44f, 62f to 48f, 28f to 49f, 74f to 50f, 48f to 38f).withIndex()) {
        rotate(i * 37f, Offset(p.first, p.second)) { oval(Palette.outline, p.first - 3.2f, p.second - 1.5f, 6.4f, 3f) }
    }
    drawPath(path { moveTo(12f, 52f); lineTo(88f, 52f); cubicTo(88f, 80f, 70f, 90f, 50f, 90f); cubicTo(30f, 90f, 12f, 80f, 12f, 52f); close() }, Palette.sky)
    rr(Palette.sky, 38f, 87f, 24f, 6f, 3f)
    rr(Palette.trail, 26f, 62f, 48f, 4f, 2f)
}

private fun DrawScope.roti() {
    circ(Grey, 44f, 50f, 50f)
    circ(Steel, 40f, 50f, 50f)
    circ(Wheat, 33f, 50f, 50f)
    for ((x, y, s) in listOf(Triple(36f, 38f, 5f), Triple(60f, 34f, 4f), Triple(64f, 58f, 6f), Triple(42f, 64f, 4.5f), Triple(52f, 48f, 3f), Triple(30f, 54f, 3.5f), Triple(54f, 72f, 3f), Triple(72f, 44f, 2.5f))) {
        oval(WheatDark, x - s, y - s * 0.7f, s * 2f, s * 1.4f)
    }
}

private fun DrawScope.icecream() {
    val cone = path { moveTo(32f, 52f); lineTo(68f, 52f); lineTo(50f, 95f); close() }
    drawPath(cone, Color(0xFFE9B86A))
    clipPath(cone) {
        var k = 20f
        while (k < 90f) { ln(GoldenDark, k, 50f, k + 30f, 96f, 2f); ln(GoldenDark, k + 10f, 50f, k - 20f, 96f, 2f); k += 9f }
    }
    circ(Pink, 19f, 50f, 42f)
    for (x in listOf(34f, 42f, 50f, 58f, 66f)) circ(Pink, 5.5f, x, 54f)
    circ(Palette.mint, 14f, 50f, 24f)
    circ(Red, 5f, 54f, 9f)
    ln(Palette.mintInk, 55f, 5f, 60f, 1.5f, 2f)
}

private fun DrawScope.cake() {
    rr(Palette.trail, 8f, 84f, 84f, 8f, 4f)
    rr(Palette.sunflowerSoft, 16f, 50f, 68f, 36f, 6f)
    rr(Palette.coral, 16f, 66f, 68f, 5f, 0f)
    rr(Pink, 14f, 42f, 72f, 14f, 7f)
    for ((x, h) in listOf(22f to 10f, 34f to 14f, 48f to 9f, 60f to 15f, 74f to 11f)) rr(Pink, x - 3.5f, 50f, 7f, h, 3.5f)
    for (x in listOf(34f, 50f, 66f)) {
        rr(Palette.sky, x - 3f, 24f, 6f, 18f, 2f)
        drawPath(path { moveTo(x, 10f); cubicTo(x + 5f, 16f, x + 4f, 21f, x, 21f); cubicTo(x - 4f, 21f, x - 5f, 16f, x, 10f); close() }, Palette.sunflower)
    }
}

private fun DrawScope.ladoo() {
    plate(80f, 90f, 26f)
    val dots = listOf(-8f to -6f, 4f to -9f, 9f to 2f, -3f to 5f, -10f to 4f, 2f to 11f, 7f to -3f)
    for ((x, y) in listOf(32f to 66f, 68f to 66f, 50f to 42f)) {
        circ(Palette.sunflower, 18f, x, y)
        for ((dx, dy) in dots) circ(GoldenDark, 1.6f, x + dx, y + dy)
    }
    circ(Palette.mint, 2.4f, 48f, 32f); circ(Palette.mint, 2.4f, 54f, 35f)
}

private fun DrawScope.honey() {
    rr(Palette.sunflower, 20f, 36f, 60f, 56f, 16f)
    rr(Brown, 24f, 22f, 52f, 16f, 5f)
    drawPath(path {
        moveTo(24f, 34f); lineTo(76f, 34f); lineTo(76f, 40f); quadraticBezierTo(72f, 40f, 72f, 46f); quadraticBezierTo(68f, 52f, 64f, 46f)
        quadraticBezierTo(62f, 40f, 52f, 42f); lineTo(52f, 50f); quadraticBezierTo(48f, 56f, 44f, 50f); lineTo(44f, 42f)
        quadraticBezierTo(32f, 40f, 32f, 46f); quadraticBezierTo(28f, 52f, 26f, 44f); lineTo(24f, 40f); close()
    }, Palette.sunflowerSoft)
    val hex = Path()
    for (i in 0 until 6) {
        val a = Math.toRadians(i * 60.0)
        val x = 50f + 13f * cos(a).toFloat(); val y = 70f + 13f * sin(a).toFloat()
        if (i == 0) hex.moveTo(x, y) else hex.lineTo(x, y)
    }
    hex.close(); drawPath(hex, Palette.cream)
    // a bee on the label
    oval(Palette.sunflower, 43f, 65f, 14f, 10f)
    ln(Palette.ink, 48f, 65.5f, 48f, 74.5f, 2.2f); ln(Palette.ink, 52.5f, 65.5f, 52.5f, 74.5f, 2.2f)
    oval(Palette.trail, 45f, 59f, 6f, 7f); oval(Palette.trail, 50f, 59f, 6f, 7f)
}

// ============================ fruits and vegetables ============================

private fun DrawScope.papaya() {
    val shape = path { moveTo(50f, 8f); cubicTo(66f, 8f, 72f, 26f, 74f, 42f); cubicTo(78f, 62f, 76f, 92f, 50f, 93f); cubicTo(24f, 92f, 22f, 62f, 26f, 42f); cubicTo(28f, 26f, 34f, 8f, 50f, 8f); close() }
    drawPath(shape, Guava)
    scale(0.86f, 0.9f, Offset(50f, 52f)) { drawPath(shape, Orange) }
    oval(OrangeLight, 37f, 40f, 26f, 42f)
    for ((x, y) in listOf(44f to 48f, 52f to 46f, 58f to 52f, 42f to 56f, 50f to 55f, 57f to 61f, 44f to 65f, 52f to 64f, 47f to 73f, 55f to 71f)) circ(Palette.ink, 2.6f, x, y)
    ln(Brown, 50f, 9f, 50f, 4f, 4f)
}

private fun DrawScope.pomegranate() {
    circ(Pom, 25f, 38f, 42f)
    drawPath(path { moveTo(30f, 21f); lineTo(28f, 9f); lineTo(34f, 14f); lineTo(38f, 6f); lineTo(42f, 14f); lineTo(48f, 9f); lineTo(46f, 21f); close() }, RedDeep)
    circ(Pom, 24f, 66f, 68f)
    circ(PomPith, 20f, 66f, 68f)
    for ((x, y) in listOf(0f to 0f, -8f to -6f, 8f to -6f, -8f to 6f, 8f to 6f, 0f to -12f, 0f to 12f, -14f to 0f, 14f to 0f, -6f to -14f, 6f to 14f, 6f to -14f, -6f to 14f, -13f to -8f, 13f to 8f, 13f to -8f, -13f to 8f)) {
        circ(Red, 3.6f, 66f + x, 68f + y)
        circ(Pink, 1.1f, 65f + x, 67f + y)
    }
}

private fun DrawScope.cherry() {
    stroke(path { moveTo(32f, 58f); quadraticBezierTo(38f, 30f, 58f, 16f) }, Palette.mintInk, 3.5f)
    stroke(path { moveTo(68f, 54f); quadraticBezierTo(62f, 32f, 58f, 16f) }, Palette.mintInk, 3.5f)
    leaf(Palette.mint, 58f, 16f, 26f, 14f, -10f)
    circ(Red, 17f, 31f, 71f)
    circ(Red, 17f, 68f, 68f)
    oval(Pink, 22f, 63f, 6f, 8f)
    oval(Pink, 59f, 60f, 6f, 8f)
}

private fun DrawScope.pear() {
    drawPath(path { moveTo(50f, 20f); cubicTo(60f, 20f, 62f, 34f, 64f, 44f); cubicTo(80f, 54f, 84f, 70f, 80f, 80f); cubicTo(74f, 94f, 26f, 94f, 20f, 80f); cubicTo(16f, 70f, 20f, 54f, 36f, 44f); cubicTo(38f, 34f, 40f, 20f, 50f, 20f); close() }, Pear)
    oval(Color(0xFFE3EC8F), 30f, 60f, 8f, 14f)
    stroke(path { moveTo(50f, 22f); quadraticBezierTo(50f, 14f, 55f, 8f) }, Brown, 4f)
    leaf(Palette.mint, 52f, 13f, 22f, 12f, -30f)
}

private fun DrawScope.peach() {
    circ(Peach, 32f, 50f, 58f)
    circ(PeachBlush, 18f, 62f, 64f)
    stroke(path { moveTo(48f, 28f); quadraticBezierTo(38f, 54f, 46f, 86f) }, PeachBlush, 3f)
    ln(Brown, 48f, 28f, 48f, 18f, 4f)
    leaf(Palette.mint, 48f, 21f, 24f, 14f, -160f)
    leaf(Palette.mintInk, 49f, 21f, 22f, 12f, -30f)
}

private fun DrawScope.plum() {
    oval(Plum, 20f, 28f, 60f, 64f)
    oval(PlumLight, 30f, 40f, 8f, 14f)
    stroke(path { moveTo(52f, 30f); quadraticBezierTo(62f, 58f, 54f, 90f) }, PlumLight, 2.5f)
    ln(Brown, 52f, 30f, 54f, 16f, 4f)
    leaf(Palette.mint, 54f, 20f, 24f, 12f, -15f)
}

private fun DrawScope.kiwi() {
    oval(KiwiBrown, 10f, 20f, 56f, 44f)
    for ((x, y) in listOf(20f to 34f, 30f to 28f, 44f to 26f, 24f to 48f, 36f to 40f, 50f to 36f)) ln(Brown, x, y, x + 2f, y + 3f, 1.8f)
    circ(KiwiBrown, 26f, 62f, 62f)
    circ(Kiwi, 23f, 62f, 62f)
    for (i in 0 until 16) {
        val a = Math.toRadians(i * 22.5)
        ln(Color(0xFFB4DE72), 62f + 8f * cos(a).toFloat(), 62f + 8f * sin(a).toFloat(), 62f + 20f * cos(a).toFloat(), 62f + 20f * sin(a).toFloat(), 1.6f)
    }
    oval(Color(0xFFEFF7C8), 55f, 57f, 14f, 10f)
    for (i in 0 until 12) {
        val a = Math.toRadians(i * 30.0)
        circ(Palette.ink, 1.6f, 62f + 11f * cos(a).toFloat(), 62f + 10f * sin(a).toFloat())
    }
}

private fun DrawScope.beetroot() {
    ln(Beet, 50f, 36f, 36f, 14f, 3f)
    ln(Beet, 50f, 36f, 64f, 12f, 3f)
    leaf(Palette.mint, 44f, 26f, 30f, 22f, -130f)
    leaf(Palette.mintInk, 56f, 24f, 30f, 22f, -55f)
    leaf(Palette.mint, 50f, 34f, 30f, 18f, -90f)
    drawPath(path { moveTo(40f, 80f); lineTo(60f, 80f); quadraticBezierTo(54f, 88f, 52f, 97f); quadraticBezierTo(48f, 88f, 40f, 80f); close() }, Beet)
    circ(Beet, 26f, 50f, 60f)
    stroke(path { moveTo(34f, 52f); quadraticBezierTo(40f, 46f, 48f, 46f) }, Color(0xFFC84A82), 3f)
}

private fun DrawScope.cauliflower() {
    leaf(Palette.mint, 50f, 86f, 44f, 30f, -165f)
    leaf(Palette.mint, 50f, 86f, 44f, 30f, -15f)
    leaf(Palette.mintInk, 50f, 88f, 40f, 26f, -130f)
    leaf(Palette.mintInk, 50f, 88f, 40f, 26f, -50f)
    for ((x, y, r) in listOf(Triple(30f, 46f, 13f), Triple(50f, 36f, 14f), Triple(70f, 46f, 13f), Triple(38f, 60f, 13f), Triple(62f, 60f, 13f), Triple(50f, 52f, 12f), Triple(50f, 68f, 11f))) {
        circ(Cauli, r, x, y)
        ring(Palette.outline, r, x, y, 2.5f)
    }
    for ((x, y) in listOf(28f to 44f, 48f to 34f, 70f to 44f, 36f to 58f, 62f to 58f, 50f to 66f)) circ(Palette.outline, 1.6f, x + 3f, y + 2f)
}

private fun DrawScope.spinach() {
    for ((deg, len) in listOf(-145f to 48f, -35f to 48f, -120f to 62f, -60f to 62f, -90f to 74f)) {
        leaf(if (deg == -90f || deg == -145f || deg == -35f) Spinach else Palette.mint, 50f, 90f, len, len * 0.55f, deg)
        val a = Math.toRadians(deg.toDouble())
        ln(LeafLight, 50f, 90f, 50f + len * 0.8f * cos(a).toFloat(), 90f + len * 0.8f * sin(a).toFloat(), 2f)
    }
    rr(Palette.coral, 42f, 78f, 16f, 6f, 3f)
}

private fun DrawScope.pumpkin() {
    oval(OrangeDeep, 10f, 32f, 44f, 58f)
    oval(OrangeDeep, 46f, 32f, 44f, 58f)
    oval(Orange, 26f, 28f, 48f, 64f)
    stroke(path { moveTo(38f, 34f); quadraticBezierTo(30f, 60f, 38f, 88f) }, OrangeDeep, 2.5f)
    stroke(path { moveTo(62f, 34f); quadraticBezierTo(70f, 60f, 62f, 88f) }, OrangeDeep, 2.5f)
    rr(Brown, 45f, 16f, 9f, 18f, 3f)
    leaf(Palette.mint, 53f, 24f, 24f, 14f, -25f)
    stroke(path { moveTo(46f, 24f); quadraticBezierTo(34f, 16f, 38f, 10f) }, Palette.mint, 2.5f)
}

private fun DrawScope.cucumber() {
    rotate(-30f, Offset(50f, 50f)) {
        rr(Cucumber, 6f, 36f, 40f, 28f, 14f)
        drawRect(Cucumber, Offset(20f, 36f), Size(62f, 28f))
        for ((x, y) in listOf(16f to 44f, 28f to 54f, 38f to 42f, 50f to 52f, 60f to 42f, 70f to 56f, 24f to 40f, 46f to 60f)) circ(CucumberMid, 1.6f, x, y)
        oval(CucumberMid, 74f, 36f, 16f, 28f)
        oval(CucumberPale, 76f, 38.5f, 12f, 23f)
        for (y in listOf(44f, 50f, 56f)) oval(Palette.cream, 80.5f, y - 1.5f, 3f, 3f)
    }
    circ(CucumberMid, 11f, 76f, 80f)
    circ(CucumberPale, 8.5f, 76f, 80f)
    for (i in 0 until 3) {
        val a = Math.toRadians(i * 120.0 + 90)
        oval(Palette.cream, 76f + 4f * cos(a).toFloat() - 1.5f, 80f + 4f * sin(a).toFloat() - 1.5f, 3f, 3f)
    }
}

private fun DrawScope.radish() {
    leaf(Palette.mint, 48f, 34f, 34f, 24f, -125f)
    leaf(Palette.mint, 52f, 34f, 34f, 24f, -55f)
    leaf(Palette.mintInk, 50f, 34f, 34f, 22f, -90f)
    val root = path { moveTo(34f, 38f); cubicTo(34f, 28f, 66f, 28f, 66f, 38f); cubicTo(66f, 58f, 56f, 80f, 50f, 96f); cubicTo(44f, 80f, 34f, 58f, 34f, 38f); close() }
    drawPath(root, Palette.cream)
    drawPath(root, Palette.outline, style = Stroke(2.5f, join = StrokeJoin.Round))
    for ((x, y, d) in listOf(Triple(38f, 54f, -1f), Triple(62f, 60f, 1f), Triple(42f, 70f, -1f), Triple(58f, 76f, 1f))) ln(Palette.outline, x, y, x + d * 6f, y + 2f, 2f)
}

private fun DrawScope.garlic() {
    val bulb = path { moveTo(50f, 22f); cubicTo(54f, 36f, 82f, 42f, 82f, 64f); cubicTo(82f, 84f, 64f, 90f, 50f, 90f); cubicTo(36f, 90f, 18f, 84f, 18f, 64f); cubicTo(18f, 42f, 46f, 36f, 50f, 22f); close() }
    rr(Palette.cream, 46f, 8f, 8f, 20f, 3f)
    rr(Palette.outline, 46f, 8f, 8f, 20f, 3f)
    drawPath(bulb, Palette.cream)
    drawPath(bulb, Palette.outline, style = Stroke(3f, join = StrokeJoin.Round))
    stroke(path { moveTo(48f, 34f); quadraticBezierTo(26f, 58f, 38f, 89f) }, Palette.outline, 2.5f)
    stroke(path { moveTo(52f, 34f); quadraticBezierTo(74f, 58f, 62f, 89f) }, Palette.outline, 2.5f)
    stroke(path { moveTo(50f, 36f); lineTo(50f, 89f) }, Palette.outline, 2.5f)
    for (dx in listOf(-8f, -3f, 3f, 8f)) ln(Brown, 50f + dx * 0.6f, 90f, 50f + dx, 96f, 1.8f)
}

private fun DrawScope.ginger() {
    val g = Color(0xFFE0B36A)
    val gd = Color(0xFFB98535)
    rr(g, 12f, 46f, 64f, 26f, 13f)
    rotate(-30f, Offset(30f, 46f)) { rr(g, 20f, 22f, 20f, 34f, 10f) }
    rotate(25f, Offset(58f, 46f)) { rr(g, 50f, 22f, 18f, 32f, 9f) }
    rr(g, 62f, 50f, 28f, 20f, 10f)
    rotate(20f, Offset(40f, 76f)) { rr(g, 32f, 60f, 16f, 28f, 8f) }
    oval(Color(0xFFF5DC9C), 80f, 52f, 9f, 16f)
    for ((x, y) in listOf(26f to 52f, 46f to 50f, 60f to 56f, 24f to 34f, 58f to 34f, 38f to 76f, 74f to 62f)) {
        stroke(path { moveTo(x - 3f, y - 3f); quadraticBezierTo(x + 1f, y, x - 2f, y + 4f) }, gd, 2f)
    }
}

private fun DrawScope.beans() {
    for ((i, y) in listOf(16f, 36f, 56f).withIndex()) {
        val x = 10f; val deg = 22f
        leaf(if (i == 1) Palette.mintInk else Palette.mint, x, y, 82f, 18f, deg)
        val a = Math.toRadians(deg.toDouble())
        for (t in listOf(0.25f, 0.4f, 0.55f, 0.7f, 0.82f)) circ(PeaGreen, 2.6f, x + 82f * t * cos(a).toFloat(), y + 82f * t * sin(a).toFloat())
        ln(Palette.mintInk, x, y, x - 4f, y - 5f, 3f)
    }
}

// ================================= Indian food =================================

private fun DrawScope.dosa() {
    plate(68f, 94f, 40f)
    rotate(-16f, Offset(50f, 56f)) {
        rr(Golden, 8f, 44f, 82f, 24f, 12f)
        for ((x, y) in listOf(22f to 52f, 34f to 58f, 46f to 50f, 58f to 60f, 70f to 52f, 28f to 62f)) ln(GoldenDark, x, y, x + 7f, y - 1f, 2f)
        oval(GoldenDark, 80f, 44f, 14f, 24f)
        oval(Palette.sunflowerSoft, 82.5f, 47f, 9f, 18f)
        stroke(path { moveTo(87f, 50f); quadraticBezierTo(91f, 56f, 87f, 62f); quadraticBezierTo(84f, 57f, 87f, 54f) }, GoldenDark, 2f)
    }
    circ(Grey, 9f, 26f, 80f); circ(Palette.cream, 7f, 26f, 80f)
    circ(Grey, 8f, 46f, 84f); circ(Palette.coral, 6f, 46f, 84f)
}

private fun DrawScope.idli() {
    plate(72f, 94f, 44f)
    circ(Palette.mint, 7f, 86f, 66f)
    fun dome(x: Float, y: Float, w: Float) {
        val p = path { moveTo(x - w, y); cubicTo(x - w, y - w * 1.25f, x + w, y - w * 1.25f, x + w, y); quadraticBezierTo(x, y + 6f, x - w, y); close() }
        drawPath(p, Palette.cream)
        drawPath(p, Palette.outline, style = Stroke(2.5f, join = StrokeJoin.Round))
        for ((dx, dy) in listOf(-6f to -10f, 4f to -14f, 8f to -6f, -2f to -4f)) circ(Palette.hairline, 1.3f, x + dx * w / 17f, y + dy * w / 17f)
    }
    dome(50f, 56f, 21f)
    dome(30f, 78f, 20f)
    dome(68f, 80f, 20f)
}

private fun DrawScope.samosa() {
    plate(80f, 90f, 24f)
    fun one(x: Float, y: Float, s: Float) {
        val front = path { moveTo(x - 24f * s, y); lineTo(x + 14f * s, y); lineTo(x - 2f * s, y - 46f * s); close() }
        val side = path { moveTo(x + 14f * s, y); lineTo(x + 26f * s, y - 8f * s); lineTo(x - 2f * s, y - 46f * s); close() }
        soft(side, GoldenDark, 5f)
        soft(front, Golden, 5f)
        for ((dx, dy) in listOf(-10f to -8f, 2f to -12f, -4f to -22f, -12f to -2f, 6f to -4f)) circ(Palette.sunflowerSoft, 1.6f * s, x + dx * s, y + dy * s)
        for (i in 0 until 5) circ(GoldenDark, 1.4f, x - 20f * s + i * 8.5f * s, y - 2.5f)
    }
    one(68f, 76f, 0.78f)
    one(40f, 82f, 1.05f)
    circ(Grey, 8f, 82f, 84f); circ(Palette.mint, 6f, 82f, 84f)
}

private fun DrawScope.jalebi() {
    plate(64f, 92f, 50f)
    fun spiral(cx: Float, cy: Float, rMax: Float, turns: Float) {
        val p = Path()
        val steps = 90
        for (i in 0..steps) {
            val t = i / steps.toFloat() * turns * 2f * Math.PI.toFloat()
            val r = 2f + (rMax - 2f) * i / steps
            val x = cx + r * cos(t); val y = cy + r * sin(t) * 0.82f
            if (i == 0) p.moveTo(x, y) else p.lineTo(x, y)
        }
        stroke(p, Jalebi, 6.5f)
        stroke(p, Palette.sunflowerSoft, 1.4f)
    }
    spiral(38f, 56f, 26f, 2.6f)
    spiral(68f, 66f, 20f, 2.2f)
}

private fun DrawScope.chapati() {
    plate(80f, 92f, 24f)
    for ((i, y) in listOf(68f, 60f, 52f).withIndex()) {
        oval(WheatDark, 14f, y - 13f + 3f, 72f, 28f)
        oval(Wheat, 14f, y - 13f, 72f, 28f)
        if (i == 2) for ((x, yy, s) in listOf(Triple(34f, 46f, 4f), Triple(56f, 42f, 3.5f), Triple(64f, 54f, 4.5f), Triple(42f, 56f, 3f), Triple(50f, 50f, 2.5f))) oval(WheatDark, x - s, yy - s * 0.5f, s * 2f, s)
    }
    stroke(path { moveTo(38f, 30f); quadraticBezierTo(34f, 24f, 38f, 18f) }, Palette.outline, 3f)
    stroke(path { moveTo(52f, 28f); quadraticBezierTo(48f, 20f, 52f, 12f) }, Palette.outline, 3f)
    stroke(path { moveTo(64f, 30f); quadraticBezierTo(60f, 24f, 64f, 18f) }, Palette.outline, 3f)
}

private fun DrawScope.dal() {
    bowl(Grey, Color(0xFFF6C033), 48f, 80f, 38f)
    for ((x, y) in listOf(34f to 44f, 60f to 43f, 46f to 47f)) circ(Palette.coral, 2.4f, x, y)
    for ((x, y) in listOf(40f to 43f, 54f to 45f, 66f to 46f, 30f to 47f)) oval(Brown, x - 1.8f, y - 1f, 3.6f, 2f)
    leaf(Palette.mint, 50f, 43f, 10f, 7f, -30f)
    leaf(Palette.mint, 50f, 43f, 10f, 7f, -150f)
    rr(Steel, 22f, 58f, 40f, 4f, 2f)
    stroke(path { moveTo(38f, 32f); quadraticBezierTo(34f, 24f, 38f, 16f) }, Palette.outline, 3f)
    stroke(path { moveTo(52f, 32f); quadraticBezierTo(48f, 22f, 52f, 12f) }, Palette.outline, 3f)
    stroke(path { moveTo(64f, 32f); quadraticBezierTo(60f, 24f, 64f, 16f) }, Palette.outline, 3f)
}

private fun DrawScope.khichdi() {
    val k = Color(0xFFF2C14E)
    drawPath(path { moveTo(16f, 54f); cubicTo(16f, 22f, 84f, 22f, 84f, 54f); close() }, k)
    for ((i, p) in listOf(30f to 44f, 42f to 34f, 56f to 36f, 68f to 44f, 38f to 48f, 52f to 46f, 62f to 50f, 26f to 52f, 74f to 52f, 48f to 40f).withIndex()) {
        rotate(i * 41f, Offset(p.first, p.second)) { oval(Palette.cream, p.first - 3f, p.second - 1.4f, 6f, 2.8f) }
    }
    for ((x, y) in listOf(36f to 38f, 58f to 44f, 46f to 50f, 70f to 48f)) circ(Palette.mint, 2.8f, x, y)
    oval(Palette.sunflowerSoft, 44f, 26f, 14f, 7f)
    drawPath(path { moveTo(10f, 54f); lineTo(90f, 54f); cubicTo(90f, 82f, 70f, 90f, 50f, 90f); cubicTo(30f, 90f, 10f, 82f, 10f, 54f); close() }, Palette.coral)
    rr(Palette.coral, 38f, 87f, 24f, 6f, 3f)
    rr(Pink, 24f, 64f, 52f, 4f, 2f)
}

private fun DrawScope.poha() {
    plate(64f, 94f, 52f)
    drawPath(path { moveTo(14f, 66f); cubicTo(12f, 46f, 34f, 40f, 50f, 42f); cubicTo(70f, 40f, 88f, 48f, 86f, 66f); cubicTo(84f, 80f, 64f, 84f, 50f, 82f); cubicTo(32f, 84f, 16f, 80f, 14f, 66f); close() }, Color(0xFFF9DC6E))
    for ((i, p) in listOf(24f to 60f, 34f to 52f, 46f to 58f, 58f to 50f, 70f to 58f, 78f to 66f, 30f to 72f, 44f to 70f, 62f to 72f, 52f to 64f, 66f to 64f, 38f to 62f).withIndex()) {
        rotate(i * 53f, Offset(p.first, p.second)) { oval(Palette.cream, p.first - 3.2f, p.second - 1.6f, 6.4f, 3.2f) }
    }
    for ((x, y) in listOf(30f to 58f, 54f to 56f, 72f to 70f, 42f to 76f)) { oval(Brown, x - 3.2f, y - 2.4f, 6.4f, 4.8f); oval(Tan, x - 1.8f, y - 1.6f, 3f, 2.4f) }
    leaf(Palette.mintInk, 40f, 64f, 14f, 8f, -40f)
    leaf(Palette.mintInk, 62f, 62f, 14f, 8f, -150f)
    for ((x, y) in listOf(48f to 54f, 66f to 56f, 36f to 70f, 58f to 76f)) circ(Palette.mint, 2f, x, y)
    drawArc(Lemon, 200f, 180f, true, Offset(70f, 32f), Size(22f, 22f))
    drawArc(LemonPale, 200f, 180f, true, Offset(73f, 35f), Size(16f, 16f))
}

private fun DrawScope.paratha() {
    plate(76f, 94f, 32f)
    fun tri(dy: Float, c: Color) = soft(path { moveTo(14f, 76f + dy); lineTo(86f, 76f + dy); lineTo(54f, 30f + dy); close() }, c, 8f)
    tri(4f, WheatDark)
    tri(0f, Color(0xFFF0C46E))
    stroke(path { moveTo(22f, 72f); lineTo(78f, 72f); lineTo(53f, 37f); close() }, WheatDark, 2f)
    stroke(path { moveTo(31f, 68f); lineTo(70f, 68f); lineTo(52f, 44f); close() }, WheatDark, 2f)
    for ((x, y, s) in listOf(Triple(40f, 62f, 3f), Triple(62f, 58f, 2.5f), Triple(50f, 52f, 2f))) oval(Brown, x - s, y - s * 0.6f, s * 2f, s * 1.2f)
    oval(Palette.cream, 36f, 54f, 8f, 3.5f); oval(Palette.cream, 58f, 64f, 7f, 3f)
    rr(Palette.sunflowerSoft, 46f, 40f, 16f, 12f, 3f)
    rr(Palette.bazaar, 46f, 40f, 16f, 4f, 2f)
}

private fun DrawScope.pakora() {
    plate(74f, 94f, 38f)
    val c = Color(0xFFD98A2B)
    fun one(x: Float, y: Float, s: Float) {
        circ(c, 10f * s, x, y); circ(c, 7f * s, x - 9f * s, y + 2f * s); circ(c, 7f * s, x + 9f * s, y + 3f * s); circ(c, 6f * s, x + 3f * s, y - 8f * s); circ(c, 6f * s, x - 5f * s, y - 7f * s)
        for ((dx, dy) in listOf(-6f to -2f, 4f to 2f, 0f to -6f, -10f to 4f, 10f to 4f, 6f to -8f)) circ(Brown, 1.6f * s, x + dx * s, y + dy * s)
        for ((dx, dy) in listOf(-2f to 4f, 8f to -2f)) circ(Palette.mint, 1.4f * s, x + dx * s, y + dy * s)
    }
    one(30f, 62f, 1.1f); one(68f, 62f, 1.1f); one(50f, 46f, 1.1f); one(48f, 78f, 1.15f)
    stroke(path { moveTo(78f, 84f); quadraticBezierTo(88f, 80f, 90f, 66f) }, Palette.mintInk, 5f)
}

private fun DrawScope.curd() {
    ln(Grey, 64f, 40f, 82f, 10f, 5f)
    oval(Clay, 8f, 42f, 84f, 18f)
    val mound = path { moveTo(14f, 51f); cubicTo(22f, 28f, 78f, 28f, 86f, 51f); close() }
    drawPath(mound, Palette.cream)
    stroke(path { moveTo(14f, 51f); cubicTo(22f, 28f, 78f, 28f, 86f, 51f) }, Palette.outline, 2.5f)
    stroke(path { moveTo(40f, 40f); quadraticBezierTo(50f, 32f, 58f, 40f) }, Palette.outline, 2.5f)
    oval(Grey, 58f, 36f, 14f, 8f)
    drawPath(path { moveTo(8f, 51f); lineTo(92f, 51f); cubicTo(92f, 82f, 72f, 92f, 50f, 92f); cubicTo(28f, 92f, 8f, 82f, 8f, 51f); close() }, Clay)
    rr(Clay, 38f, 89f, 24f, 6f, 3f)
    rr(ClayDark, 14f, 60f, 72f, 4f, 2f)
}

private fun DrawScope.ghee() {
    rr(Palette.sunflowerSoft, 22f, 32f, 56f, 60f, 12f)
    for ((x, y) in listOf(30f to 44f, 40f to 40f, 64f to 42f, 70f to 54f, 28f to 84f, 70f to 84f, 36f to 52f, 62f to 86f)) circ(Palette.sunflower, 1.6f, x, y)
    rr(Grey, 18f, 18f, 64f, 16f, 5f)
    rr(Steel, 18f, 18f, 64f, 5f, 2.5f)
    rr(Palette.cream, 30f, 56f, 40f, 24f, 4f)
    drawPath(path { moveTo(50f, 59f); cubicTo(56f, 66f, 58f, 69f, 58f, 71f); cubicTo(58f, 77f, 42f, 77f, 42f, 71f); cubicTo(42f, 69f, 44f, 66f, 50f, 59f); close() }, Palette.sunflower)
}

private fun DrawScope.paneer() {
    plate(78f, 92f, 30f)
    fun cube(x: Float, y: Float, s: Float) {
        val top = path { moveTo(x, y - s * 0.5f); lineTo(x + s, y - s * 0.1f); lineTo(x, y + s * 0.3f); lineTo(x - s, y - s * 0.1f); close() }
        val left = path { moveTo(x - s, y - s * 0.1f); lineTo(x, y + s * 0.3f); lineTo(x, y + s * 1.2f); lineTo(x - s, y + s * 0.8f); close() }
        val right = path { moveTo(x + s, y - s * 0.1f); lineTo(x, y + s * 0.3f); lineTo(x, y + s * 1.2f); lineTo(x + s, y + s * 0.8f); close() }
        drawPath(left, Palette.cream); drawPath(right, Color(0xFFF1E6D2)); drawPath(top, Color(0xFFFFFDF8))
        for (p in listOf(top, left, right)) drawPath(p, Palette.outline, style = Stroke(2f, join = StrokeJoin.Round))
    }
    cube(34f, 58f, 16f)
    cube(66f, 58f, 16f)
    cube(50f, 34f, 16f)
    cube(50f, 70f, 14f)
}

private fun DrawScope.sugarcane() {
    for ((deg, cx) in listOf(-16f to 42f, 14f to 58f)) {
        rotate(deg, Offset(cx, 56f)) {
            rr(Cane, cx - 6f, 22f, 12f, 74f, 5f)
            var y = 34f
            while (y < 92f) { rr(CaneLight, cx - 6f, y, 12f, 3f, 1.5f); y += 14f }
            curvedLeaf(Palette.mint, cx, 24f, 34f, 12f, -125f, 10f)
            curvedLeaf(Palette.mintInk, cx, 24f, 34f, 12f, -55f, -10f)
            curvedLeaf(Palette.mint, cx, 24f, 22f, 9f, -92f, 0f)
        }
    }
    rr(Cane, 66f, 80f, 22f, 10f, 3f)
    oval(Palette.bazaar, 84f, 80f, 6f, 10f)
}

private fun DrawScope.jaggery() {
    plate(78f, 92f, 28f)
    val top = path { moveTo(16f, 44f); lineTo(46f, 30f); lineTo(84f, 38f); lineTo(56f, 54f); close() }
    val front = path { moveTo(16f, 44f); lineTo(56f, 54f); lineTo(58f, 82f); lineTo(20f, 74f); close() }
    val side = path { moveTo(56f, 54f); lineTo(84f, 38f); lineTo(82f, 66f); lineTo(58f, 82f); close() }
    soft(front, Jaggery, 4f); soft(side, JaggeryDark, 4f); soft(top, JaggeryTop, 4f)
    for ((x, y) in listOf(30f to 58f, 42f to 66f, 26f to 66f, 48f to 58f, 68f to 60f, 74f to 52f, 40f to 40f, 60f to 42f, 50f to 36f)) circ(JaggeryDark, 1.8f, x, y)
    soft(path { moveTo(76f, 82f); lineTo(86f, 76f); lineTo(90f, 84f); lineTo(80f, 88f); close() }, Jaggery, 3f)
}

private fun DrawScope.chikki() {
    fun bar(y: Float, deg: Float) {
        rotate(deg, Offset(50f, y + 14f)) {
            rr(GoldenDark, 12f, y + 4f, 76f, 26f, 6f)
            rr(Caramel, 12f, y, 76f, 26f, 6f)
            for ((i, x) in listOf(20f, 31f, 42f, 53f, 64f, 75f).withIndex()) {
                val yy = y + if (i % 2 == 0) 8f else 17f
                oval(Palette.bazaar, x - 4.5f, yy - 3.2f, 9f, 6.4f)
                ln(Brown, x, yy - 2f, x, yy + 2f, 1.4f)
                val yy2 = y + if (i % 2 == 0) 18f else 8f
                oval(Palette.bazaar, x + 1f, yy2 - 2.6f, 7f, 5.2f)
            }
            rr(Palette.sunflowerSoft, 18f, y + 2.5f, 30f, 2.5f, 1.2f)
        }
    }
    bar(56f, 6f)
    bar(22f, -8f)
}

// ==================================== plants ====================================

private fun DrawScope.rose() {
    ln(Palette.mintInk, 50f, 50f, 50f, 96f, 5f)
    for ((y, d) in listOf(66f to -1f, 80f to 1f)) drawPath(path { moveTo(50f, y); lineTo(50f + d * 6f, y - 3f); lineTo(50f, y + 4f); close() }, Palette.mintInk)
    leaf(Palette.mint, 50f, 72f, 26f, 16f, -150f)
    leaf(Palette.mint, 50f, 62f, 26f, 16f, -30f)
    leaf(Palette.mint, 50f, 50f, 14f, 10f, 130f)
    leaf(Palette.mint, 50f, 50f, 14f, 10f, 50f)
    drawPath(path { moveTo(28f, 26f); cubicTo(26f, 50f, 40f, 56f, 50f, 56f); cubicTo(60f, 56f, 74f, 50f, 72f, 26f); quadraticBezierTo(50f, 36f, 28f, 26f); close() }, RedDeep)
    circ(Red, 18f, 50f, 30f)
    drawPath(path { moveTo(30f, 30f); cubicTo(30f, 48f, 44f, 52f, 50f, 52f); cubicTo(42f, 46f, 38f, 38f, 30f, 30f); close() }, Red)
    drawPath(path { moveTo(70f, 30f); cubicTo(70f, 48f, 56f, 52f, 50f, 52f); cubicTo(58f, 46f, 62f, 38f, 70f, 30f); close() }, Red)
    stroke(path { moveTo(50f, 30f); cubicTo(56f, 28f, 56f, 36f, 50f, 36f); cubicTo(42f, 36f, 42f, 24f, 50f, 22f); cubicTo(60f, 20f, 64f, 32f, 60f, 40f) }, RedDeep, 2.5f)
}

private fun DrawScope.lotus() {
    oval(Palette.mint, 8f, 70f, 84f, 20f)
    drawArc(Palette.sky, 0f, 180f, true, Offset(4f, 76f), Size(92f, 16f))
    val lp = Color(0xFFF27BA6)
    leaf(lp, 50f, 76f, 56f, 26f, -90f)
    leaf(lp, 48f, 76f, 46f, 26f, -128f)
    leaf(lp, 52f, 76f, 46f, 26f, -52f)
    leaf(Pink, 48f, 77f, 38f, 22f, -160f)
    leaf(Pink, 52f, 77f, 38f, 22f, -20f)
    leaf(Pink, 49f, 78f, 40f, 24f, -108f)
    leaf(Pink, 51f, 78f, 40f, 24f, -72f)
}

private fun DrawScope.sunflowerPlant() {
    ln(Palette.mintInk, 50f, 50f, 50f, 96f, 5f)
    leaf(Palette.mint, 50f, 78f, 28f, 18f, -150f)
    leaf(Palette.mint, 50f, 70f, 28f, 18f, -30f)
    for (i in 0 until 14) {
        val a = i * (360f / 14f)
        val r = Math.toRadians(a.toDouble())
        leaf(Palette.sunflower, 50f + 12f * cos(r).toFloat(), 36f + 12f * sin(r).toFloat(), 22f, 11f, a)
    }
    circ(Brown, 15f, 50f, 36f)
    for ((dx, dy) in listOf(-6f to -5f, 3f to -8f, 7f to 1f, -2f to 2f, -8f to 4f, 2f to 8f, 8f to -6f, -4f to 9f)) circ(DarkBrown, 1.8f, 50f + dx, 36f + dy)
}

private fun DrawScope.tulsi() {
    ln(Palette.mintInk, 50f, 62f, 50f, 22f, 3.5f)
    for ((sx, sy, ex, ey) in listOf(floatArrayOf(50f, 54f, 30f, 38f), floatArrayOf(50f, 54f, 70f, 38f), floatArrayOf(50f, 44f, 36f, 26f), floatArrayOf(50f, 44f, 64f, 26f))) ln(Palette.mintInk, sx, sy, ex, ey, 3f)
    val tips = listOf(30f to 38f, 70f to 38f, 36f to 26f, 64f to 26f, 50f to 22f)
    for ((x, y) in tips) {
        rr(Palette.lavender, x - 2.5f, y - 12f, 5f, 12f, 2.5f)
        leaf(Palette.mint, x, y + 1f, 12f, 9f, -160f)
        leaf(Palette.mint, x, y + 1f, 12f, 9f, -20f)
        leaf(Palette.mint, x, y + 6f, 11f, 8f, 160f)
        leaf(Palette.mint, x, y + 6f, 11f, 8f, 20f)
    }
    for ((x, y) in listOf(40f to 48f, 60f to 48f, 44f to 36f, 56f to 36f)) { leaf(Palette.mintInk, x, y, 10f, 8f, -150f); leaf(Palette.mintInk, x, y, 10f, 8f, -30f) }
    rr(ClayDark, 26f, 60f, 48f, 8f, 3f)
    rr(Clay, 30f, 66f, 40f, 28f, 3f)
    rr(ClayDark, 28f, 90f, 44f, 6f, 2f)
    drawPath(path { moveTo(50f, 72f); lineTo(56f, 80f); lineTo(50f, 88f); lineTo(44f, 80f); close() }, Palette.sunflower)
}

private fun DrawScope.neem() {
    drawPath(path { moveTo(44f, 96f); lineTo(46f, 62f); lineTo(36f, 48f); lineTo(40f, 46f); lineTo(50f, 58f); lineTo(62f, 44f); lineTo(65f, 47f); lineTo(54f, 62f); lineTo(56f, 96f); close() }, Brown)
    for ((x, y, r) in listOf(Triple(30f, 42f, 20f), Triple(70f, 42f, 20f), Triple(50f, 30f, 24f), Triple(50f, 50f, 20f))) circ(Palette.mint, r, x, y)
    fun spray(x: Float, y: Float, deg: Float) {
        translate(x, y) {
            rotate(deg, Offset.Zero) {
                drawLine(Palette.mintInk, Offset(0f, 0f), Offset(24f, 0f), 1.8f, StrokeCap.Round)
                for (t in listOf(5f, 10f, 15f, 20f)) {
                    leaf(Palette.mintInk, t, 0f, 7f, 5f, -55f)
                    leaf(Palette.mintInk, t, 0f, 7f, 5f, 55f)
                }
                leaf(Palette.mintInk, 24f, 0f, 7f, 5f, 0f)
            }
        }
    }
    spray(38f, 26f, -150f); spray(50f, 26f, -90f); spray(62f, 26f, -30f)
    spray(38f, 44f, 160f); spray(62f, 44f, 20f)
    spray(46f, 50f, 115f); spray(56f, 50f, 65f)
}

private fun DrawScope.banyan() {
    drawPath(path { moveTo(36f, 96f); quadraticBezierTo(44f, 80f, 42f, 46f); lineTo(58f, 46f); quadraticBezierTo(56f, 80f, 64f, 96f); close() }, Brown)
    oval(Palette.mintInk, 4f, 18f, 92f, 38f)
    oval(Palette.mint, 10f, 10f, 46f, 34f)
    oval(Palette.mint, 44f, 10f, 48f, 34f)
    oval(Palette.mint, 28f, 4f, 44f, 30f)
    for (x in listOf(14f, 22f, 30f, 70f, 78f, 86f)) ln(Brown, x, 50f, x + (if (x < 50f) -1f else 1f), 94f, 2.5f)
    ln(Brown, 8f, 95f, 92f, 95f, 2.5f)
}

private fun DrawScope.palm() = scale(0.9f, 0.9f, Offset(50f, 96f)) {
    val trunk = path { moveTo(38f, 96f); quadraticBezierTo(42f, 56f, 58f, 28f); lineTo(64f, 30f); quadraticBezierTo(50f, 60f, 50f, 96f); close() }
    drawPath(trunk, Color(0xFFB07A3A))
    for (t in listOf(0.15f, 0.3f, 0.45f, 0.6f, 0.75f)) {
        val y = 96f - t * 68f
        val x = 44f + t * t * 20f + t * 2f
        ln(Brown, x - 4f, y + 1f, x + 5f, y - 1f, 2f)
    }
    for ((deg, len, c) in listOf(Triple(-170f, 42f, Palette.mint), Triple(-10f, 42f, Palette.mint), Triple(-130f, 36f, Palette.mintInk), Triple(-50f, 36f, Palette.mintInk), Triple(-90f, 28f, Palette.mint), Triple(160f, 34f, Palette.mintInk), Triple(20f, 34f, Palette.mintInk))) {
        curvedLeaf(c, 61f, 28f, len, 13f, deg, if (deg < -90f || deg > 90f) 16f else -16f)
    }
    circ(Brown, 5f, 57f, 34f); circ(Brown, 5f, 65f, 35f); circ(Brown, 5f, 61f, 40f)
}

private fun DrawScope.pine() {
    rr(Brown, 44f, 80f, 12f, 16f, 2f)
    soft(path { moveTo(50f, 44f); lineTo(14f, 84f); lineTo(86f, 84f); close() }, Palette.mintInk, 5f)
    soft(path { moveTo(50f, 24f); lineTo(20f, 62f); lineTo(80f, 62f); close() }, Palette.mintInk, 5f)
    soft(path { moveTo(50f, 6f); lineTo(27f, 40f); lineTo(73f, 40f); close() }, Palette.mintInk, 5f)
    drawPath(path { moveTo(50f, 44f); lineTo(14f, 84f); lineTo(50f, 84f); close() }, Palette.mint)
    drawPath(path { moveTo(50f, 24f); lineTo(20f, 62f); lineTo(50f, 62f); close() }, Palette.mint)
    drawPath(path { moveTo(50f, 6f); lineTo(27f, 40f); lineTo(50f, 40f); close() }, Palette.mint)
}

private fun DrawScope.bamboo() {
    for ((x, top) in listOf(28f to 14f, 50f to 6f, 72f to 20f)) {
        rr(Bamboo, x - 6f, top, 12f, 94f - top, 4f)
        var y = top + 16f
        while (y < 92f) { rr(Palette.mintInk, x - 7f, y, 14f, 3f, 1.5f); y += 18f }
    }
    curvedLeaf(Palette.mintInk, 28f, 30f, 22f, 7f, -160f, 6f)
    curvedLeaf(Palette.mint, 50f, 22f, 22f, 7f, -20f, -6f)
    curvedLeaf(Palette.mintInk, 50f, 40f, 20f, 6f, -160f, 6f)
    curvedLeaf(Palette.mint, 72f, 36f, 22f, 7f, -20f, -6f)
    curvedLeaf(Palette.mint, 28f, 66f, 18f, 6f, -165f, 6f)
    curvedLeaf(Palette.mintInk, 72f, 72f, 18f, 6f, -15f, -6f)
}

private fun DrawScope.moneyplant() {
    stroke(path { moveTo(36f, 64f); cubicTo(22f, 64f, 16f, 76f, 18f, 92f) }, Palette.mintInk, 2.5f)
    stroke(path { moveTo(64f, 64f); cubicTo(78f, 64f, 84f, 76f, 82f, 92f) }, Palette.mintInk, 2.5f)
    heartLeaf(Palette.mint, 22f, 70f, 7f, 160f, LeafLight)
    heartLeaf(Palette.mint, 18f, 84f, 7f, 120f, LeafLight)
    heartLeaf(Palette.mint, 78f, 70f, 7f, 20f, LeafLight)
    heartLeaf(Palette.mint, 82f, 84f, 7f, 60f, LeafLight)
    for ((x, y, deg) in listOf(Triple(50f, 58f, -90f), Triple(46f, 58f, -140f), Triple(54f, 58f, -40f), Triple(44f, 46f, -110f), Triple(56f, 46f, -70f), Triple(50f, 36f, -90f))) {
        heartLeaf(Palette.mint, x, y, 9f, deg, LeafLight)
    }
    rr(Palette.sky, 30f, 60f, 40f, 8f, 3f)
    drawPath(path { moveTo(33f, 66f); lineTo(67f, 66f); lineTo(62f, 94f); lineTo(38f, 94f); close() }, Palette.sky)
}

private fun DrawScope.sapling() {
    drawArc(Brown, 180f, 180f, true, Offset(16f, 72f), Size(68f, 32f))
    ln(Palette.mint, 50f, 86f, 50f, 40f, 4f)
    leaf(Palette.mint, 50f, 50f, 32f, 22f, -155f)
    leaf(Palette.mint, 50f, 44f, 32f, 22f, -25f)
    leaf(Palette.mintInk, 50f, 40f, 22f, 16f, -95f)
}

private fun DrawScope.roots() {
    rr(Color(0xFFB07A3A), 8f, 50f, 84f, 44f, 6f)
    rr(Palette.mint, 8f, 46f, 84f, 8f, 4f)
    ln(Palette.mint, 50f, 48f, 50f, 20f, 4f)
    leaf(Palette.mint, 50f, 30f, 26f, 18f, -155f)
    leaf(Palette.mint, 50f, 26f, 26f, 18f, -25f)
    leaf(Palette.mintInk, 50f, 20f, 16f, 12f, -95f)
    val r = Palette.bazaar
    ln(r, 50f, 54f, 50f, 86f, 3.5f)
    stroke(path { moveTo(50f, 60f); quadraticBezierTo(38f, 64f, 28f, 82f) }, r, 3f)
    stroke(path { moveTo(50f, 62f); quadraticBezierTo(64f, 66f, 72f, 84f) }, r, 3f)
    stroke(path { moveTo(50f, 72f); quadraticBezierTo(42f, 78f, 40f, 88f) }, r, 2.5f)
    stroke(path { moveTo(50f, 74f); quadraticBezierTo(58f, 80f, 60f, 89f) }, r, 2.5f)
    stroke(path { moveTo(36f, 70f); lineTo(24f, 70f) }, r, 2f)
    stroke(path { moveTo(64f, 72f); lineTo(78f, 70f) }, r, 2f)
}

// ==================================== nature ====================================

private fun DrawScope.mountain() {
    soft(path { moveTo(40f, 88f); lineTo(68f, 30f); lineTo(96f, 88f); close() }, Palette.lavender, 4f)
    soft(path { moveTo(68f, 30f); lineTo(60f, 46f); lineTo(65f, 43f); lineTo(69f, 48f); lineTo(73f, 42f); lineTo(76f, 46f); close() }, Palette.cream, 2f)
    soft(path { moveTo(4f, 88f); lineTo(38f, 16f); lineTo(74f, 88f); close() }, Grey, 4f)
    soft(path { moveTo(38f, 16f); lineTo(27f, 39f); lineTo(33f, 35f); lineTo(38f, 41f); lineTo(43f, 34f); lineTo(49f, 39f); close() }, Palette.cream, 2f)
    rr(Palette.mint, 2f, 86f, 96f, 8f, 4f)
}

private fun DrawScope.river() {
    val land = path { addRoundRect(androidx.compose.ui.geometry.RoundRect(8f, 10f, 92f, 90f, CornerRadius(14f))) }
    drawPath(land, Palette.mint)
    clipPath(land) {
        drawPath(path { moveTo(50f, 10f); cubicTo(28f, 36f, 74f, 54f, 18f, 90f); lineTo(64f, 90f); cubicTo(96f, 56f, 50f, 36f, 62f, 10f); close() }, Palette.sky)
        stroke(path { moveTo(52f, 30f); quadraticBezierTo(56f, 32f, 58f, 30f) }, Palette.trail, 2.5f)
        stroke(path { moveTo(52f, 54f); quadraticBezierTo(58f, 56f, 64f, 52f) }, Palette.trail, 2.5f)
        stroke(path { moveTo(36f, 76f); quadraticBezierTo(44f, 80f, 52f, 74f) }, Palette.trail, 2.5f)
    }
    circ(Palette.mintInk, 8f, 24f, 30f); rr(Brown, 22.5f, 34f, 3f, 8f, 1f)
    circ(Palette.mintInk, 7f, 78f, 70f); rr(Brown, 76.5f, 74f, 3f, 7f, 1f)
    oval(Grey, 72f, 22f, 10f, 6f)
}

private fun DrawScope.wave() {
    drawPath(path {
        moveTo(6f, 92f); lineTo(6f, 64f); cubicTo(8f, 32f, 40f, 12f, 66f, 16f); cubicTo(86f, 18f, 96f, 34f, 90f, 48f)
        cubicTo(86f, 58f, 70f, 60f, 64f, 50f); cubicTo(60f, 42f, 66f, 34f, 74f, 36f); cubicTo(64f, 28f, 46f, 34f, 44f, 52f)
        cubicTo(42f, 68f, 60f, 78f, 94f, 74f); lineTo(94f, 92f); close()
    }, Palette.sky)
    stroke(path { moveTo(16f, 60f); cubicTo(20f, 38f, 42f, 22f, 64f, 22f) }, Palette.trail, 3f)
    stroke(path { moveTo(14f, 84f); quadraticBezierTo(24f, 80f, 34f, 84f); quadraticBezierTo(44f, 88f, 54f, 84f); quadraticBezierTo(64f, 80f, 74f, 84f); quadraticBezierTo(82f, 88f, 88f, 85f) }, Palette.trail, 3f)
    for ((x, y) in listOf(86f to 54f, 92f to 60f, 80f to 60f)) circ(Palette.sky, 2.5f, x, y)
}

private fun DrawScope.rainbow() {
    for ((i, c) in listOf(Palette.coral, Palette.sunflower, Palette.mint, Palette.sky, Palette.lavender).withIndex()) {
        val r = 40f - i * 6.5f
        drawArc(c, 180f, 180f, false, Offset(50f - r, 70f - r), Size(2 * r, 2 * r), style = Stroke(7f))
    }
    for (cx in listOf(17f, 83f)) {
        circ(Palette.trail, 9f, cx - 6f, 74f); circ(Palette.trail, 11f, cx + 3f, 70f); circ(Palette.trail, 8f, cx + 10f, 76f)
        rr(Palette.trail, cx - 14f, 74f, 30f, 10f, 5f)
    }
}

private fun DrawScope.snow() {
    for (i in 0 until 6) {
        val a = Math.toRadians(i * 60.0 - 90.0)
        val ca = cos(a).toFloat(); val sa = sin(a).toFloat()
        ln(Palette.sky, 50f, 50f, 50f + 40f * ca, 50f + 40f * sa, 5f)
        for ((t, l) in listOf(0.5f to 11f, 0.78f to 8f)) {
            val bx = 50f + 40f * t * ca; val by = 50f + 40f * t * sa
            for (s in listOf(-1, 1)) {
                val b = a + s * Math.toRadians(45.0)
                ln(Palette.sky, bx, by, bx + l * cos(b).toFloat(), by + l * sin(b).toFloat(), 4f)
            }
        }
    }
    circ(Palette.sky, 7f, 50f, 50f)
    circ(Palette.trail, 3f, 50f, 50f)
}

private fun DrawScope.wind() {
    stroke(path { moveTo(8f, 36f); lineTo(58f, 36f); cubicTo(76f, 36f, 80f, 14f, 66f, 12f); cubicTo(56f, 11f, 54f, 24f, 63f, 25f) }, Palette.sky, 5f)
    stroke(path { moveTo(14f, 54f); lineTo(74f, 54f); cubicTo(94f, 54f, 96f, 80f, 80f, 82f); cubicTo(70f, 83f, 68f, 70f, 77f, 70f) }, Palette.sky, 5f)
    stroke(path { moveTo(8f, 72f); lineTo(42f, 72f); cubicTo(56f, 72f, 58f, 88f, 48f, 90f); cubicTo(42f, 91f, 40f, 84f, 45f, 82f) }, Palette.trail, 5f)
    leaf(Palette.mint, 24f, 16f, 18f, 10f, 20f)
    leaf(Palette.sunflower, 86f, 38f, 14f, 8f, 120f)
}

private fun DrawScope.lightning() {
    soft(path { moveTo(60f, 6f); lineTo(22f, 56f); lineTo(46f, 56f); lineTo(34f, 94f); lineTo(80f, 40f); lineTo(55f, 40f); lineTo(70f, 6f); close() }, Palette.sunflower, 3f)
}

private fun DrawScope.grass() {
    rr(Brown, 8f, 84f, 84f, 10f, 5f)
    val blades = listOf(Triple(14f, 46f, -4f), Triple(22f, 62f, 3f), Triple(30f, 40f, -2f), Triple(38f, 70f, 4f), Triple(46f, 52f, -3f), Triple(54f, 76f, 2f), Triple(62f, 48f, 5f), Triple(70f, 66f, -2f), Triple(78f, 44f, 3f), Triple(86f, 58f, -4f))
    for ((i, b) in blades.withIndex()) {
        val (x, h, lean) = b
        drawPath(path { moveTo(x - 6f, 86f); quadraticBezierTo(x - 3f, 86f - h * 0.6f, x + lean, 86f - h); quadraticBezierTo(x + 3f, 86f - h * 0.5f, x + 6f, 86f); close() }, if (i % 2 == 0) Palette.mint else Palette.mintInk)
    }
}

private fun DrawScope.cactus() {
    rr(Palette.mint, 38f, 16f, 24f, 66f, 12f)
    rr(Palette.mint, 16f, 34f, 12f, 28f, 6f)
    rr(Palette.mint, 16f, 52f, 30f, 12f, 6f)
    rr(Palette.mint, 72f, 26f, 12f, 26f, 6f)
    rr(Palette.mint, 54f, 42f, 30f, 12f, 6f)
    ln(Palette.mintInk, 50f, 24f, 50f, 78f, 2.5f)
    ln(Palette.mintInk, 22f, 40f, 22f, 58f, 2f)
    ln(Palette.mintInk, 78f, 32f, 78f, 48f, 2f)
    for ((x, y) in listOf(42f to 30f, 58f to 38f, 42f to 50f, 58f to 62f, 42f to 70f, 19f to 44f, 81f to 36f)) ln(Palette.mintInk, x, y, x + (if (x < 50f) -3f else 3f), y - 2f, 1.5f)
    circ(Pink, 6f, 50f, 15f); circ(Palette.coral, 2.5f, 50f, 15f)
    rr(ClayDark, 30f, 76f, 40f, 7f, 3f)
    drawPath(path { moveTo(33f, 82f); lineTo(67f, 82f); lineTo(63f, 95f); lineTo(37f, 95f); close() }, Clay)
}

private fun DrawScope.mushroom() {
    val stem = path { moveTo(40f, 52f); lineTo(60f, 52f); quadraticBezierTo(62f, 80f, 64f, 88f); quadraticBezierTo(50f, 94f, 36f, 88f); quadraticBezierTo(38f, 80f, 40f, 52f); close() }
    drawPath(stem, Palette.cream)
    drawPath(stem, Palette.outline, style = Stroke(2.5f, join = StrokeJoin.Round))
    drawPath(path { moveTo(8f, 56f); cubicTo(8f, 12f, 92f, 12f, 92f, 56f); quadraticBezierTo(50f, 64f, 8f, 56f); close() }, Palette.coral)
    for ((x, y, r) in listOf(Triple(30f, 40f, 6f), Triple(52f, 28f, 7f), Triple(70f, 42f, 5.5f), Triple(46f, 48f, 4f), Triple(18f, 52f, 3.5f), Triple(84f, 52f, 3.5f))) circ(Palette.cream, r, x, y)
    for (x in listOf(24f, 32f, 70f, 78f)) leaf(Palette.mint, x, 92f, 10f, 6f, if (x < 50f) -110f else -70f)
}

private fun DrawScope.nest() {
    oval(EggBlue, 26f, 26f, 20f, 28f)
    oval(EggBlue, 54f, 26f, 20f, 28f)
    oval(Palette.trail, 40f, 20f, 20f, 30f)
    for ((x, y) in listOf(32f to 36f, 60f to 34f, 47f to 30f)) circ(Palette.sky, 1.6f, x, y)
    val bowl = path { moveTo(8f, 50f); cubicTo(12f, 92f, 88f, 92f, 92f, 50f); quadraticBezierTo(50f, 60f, 8f, 50f); close() }
    drawPath(bowl, Brown)
    clipPath(bowl) {
        for (i in 0 until 9) {
            val x = 6f + i * 11f
            stroke(path { moveTo(x, 52f); quadraticBezierTo(x + 8f, 66f, x + 20f, 70f) }, Color(0xFFBF801F), 2.2f)
            stroke(path { moveTo(x + 14f, 54f); quadraticBezierTo(x + 4f, 70f, x - 8f, 80f) }, DarkBrown, 2.2f)
        }
    }
    rr(Color(0xFFB07A3A), 6f, 46f, 88f, 8f, 4f)
    ln(DarkBrown, 4f, 48f, 18f, 52f, 2.2f); ln(DarkBrown, 84f, 52f, 96f, 46f, 2.2f)
}

private fun DrawScope.shell() {
    val ribs = 7
    val cx = 50f; val cy = 80f; val r = 48f
    drawArc(Pink, -150f, 120f, true, Offset(cx - r, cy - r), Size(2 * r, 2 * r))
    for (i in 0..ribs) {
        val a = Math.toRadians(-150.0 + i * 120.0 / ribs)
        circ(Pink, 6.5f, cx + r * cos(a).toFloat(), cy + r * sin(a).toFloat())
    }
    for (i in 1 until ribs) {
        val a = Math.toRadians(-150.0 + i * 120.0 / ribs)
        ln(PeachBlush, cx, cy, cx + (r - 2f) * cos(a).toFloat(), cy + (r - 2f) * sin(a).toFloat(), 2.5f)
    }
    soft(path { moveTo(36f, 76f); lineTo(64f, 76f); lineTo(60f, 90f); lineTo(40f, 90f); close() }, Pink, 4f)
    ln(PeachBlush, 42f, 83f, 58f, 83f, 2f)
}

private fun DrawScope.pond() {
    oval(Grey, 4f, 36f, 92f, 52f)
    oval(Palette.sky, 8f, 38f, 84f, 46f)
    oval(Palette.trail, 48f, 70f, 18f, 4f)
    drawArc(Palette.mint, 20f, 320f, true, Offset(52f, 48f), Size(22f, 14f))
    drawArc(Palette.mint, 200f, 320f, true, Offset(62f, 64f), Size(18f, 11f))
    leaf(Color(0xFFF27BA6), 64f, 56f, 12f, 8f, -90f); leaf(Pink, 64f, 56f, 10f, 8f, -135f); leaf(Pink, 64f, 56f, 10f, 8f, -45f)
    for ((x, h) in listOf(16f to 40f, 22f to 50f, 28f to 36f)) {
        ln(Palette.mintInk, x, 62f, x, 62f - h, 2.5f)
        rr(Brown, x - 2.5f, 62f - h + 4f, 5f, 12f, 2.5f)
    }
}

// ===================================== space =====================================

private fun DrawScope.earth() {
    val globe = path { addOval(Rect(12f, 12f, 88f, 88f)) }
    drawPath(globe, Palette.sky)
    clipPath(globe) {
        drawPath(path { moveTo(18f, 30f); cubicTo(26f, 18f, 44f, 20f, 46f, 30f); cubicTo(48f, 40f, 36f, 42f, 38f, 52f); cubicTo(40f, 62f, 50f, 64f, 46f, 76f); cubicTo(42f, 86f, 34f, 80f, 32f, 70f); cubicTo(30f, 60f, 22f, 54f, 14f, 50f); close() }, Palette.mint)
        drawPath(path { moveTo(58f, 22f); cubicTo(70f, 18f, 86f, 26f, 88f, 40f); cubicTo(90f, 50f, 78f, 50f, 74f, 58f); cubicTo(70f, 66f, 72f, 74f, 64f, 76f); cubicTo(58f, 70f, 62f, 58f, 56f, 50f); cubicTo(52f, 42f, 54f, 30f, 58f, 22f); close() }, Palette.mint)
    }
}

private fun DrawScope.saturn() {
    rotate(-18f, Offset(50f, 50f)) {
        drawArc(Palette.coral, 180f, 180f, false, Offset(4f, 38f), Size(92f, 24f), style = Stroke(5f))
        drawArc(Palette.sunflowerSoft, 180f, 180f, false, Offset(12f, 41f), Size(76f, 18f), style = Stroke(3f))
        val body = path { addOval(Rect(26f, 26f, 74f, 74f)) }
        drawPath(body, Palette.sunflower)
        clipPath(body) {
            rr(Palette.sunflowerSoft, 20f, 34f, 60f, 5f, 2.5f)
            rr(Palette.sunflowerSoft, 20f, 60f, 60f, 4f, 2f)
        }
        drawArc(Palette.coral, 0f, 180f, false, Offset(4f, 38f), Size(92f, 24f), style = Stroke(5f))
        drawArc(Palette.sunflowerSoft, 0f, 180f, false, Offset(12f, 41f), Size(76f, 18f), style = Stroke(3f))
    }
}

private fun DrawScope.planet() {
    val body = path { addOval(Rect(14f, 22f, 74f, 82f)) }
    drawPath(body, Palette.lavender)
    clipPath(body) {
        rr(LavenderDeep, 8f, 36f, 72f, 7f, 3.5f)
        rr(LavenderPale, 8f, 50f, 72f, 5f, 2.5f)
        rr(LavenderDeep, 8f, 64f, 72f, 6f, 3f)
    }
    oval(Palette.coral, 46f, 54f, 12f, 7f)
    circ(Grey, 8f, 82f, 22f)
    circ(Steel, 2.4f, 80f, 20f)
    miniStar(Palette.sunflower, 18f, 14f, 6f)
    miniStar(Palette.sunflower, 86f, 74f, 5f)
    circ(Palette.sunflower, 2f, 90f, 46f)
}

private fun DrawScope.comet() {
    drawPath(path { moveTo(60f, 20f); lineTo(8f, 74f); lineTo(76f, 42f); close() }, Palette.sunflowerSoft)
    drawPath(path { moveTo(62f, 26f); lineTo(18f, 88f); lineTo(72f, 38f); close() }, Palette.coral)
    drawPath(path { moveTo(64f, 24f); lineTo(30f, 56f); lineTo(74f, 34f); close() }, Palette.sunflower)
    circ(Palette.sunflower, 16f, 72f, 28f)
    circ(Palette.sunflowerSoft, 8f, 75f, 25f)
    miniStar(Palette.lavender, 22f, 22f, 6f)
    miniStar(Palette.lavender, 80f, 78f, 6f)
    circ(Palette.lavender, 2f, 46f, 12f)
}

private fun DrawScope.telescope() {
    ln(Palette.ink, 50f, 52f, 30f, 94f, 4f)
    ln(Palette.ink, 50f, 52f, 70f, 94f, 4f)
    ln(Palette.ink, 50f, 52f, 50f, 94f, 4f)
    rotate(-28f, Offset(50f, 46f)) {
        rr(Palette.sky, 8f, 41f, 12f, 10f, 2f)
        rr(Palette.sky, 18f, 37f, 60f, 18f, 4f)
        rr(LavenderDeep, 74f, 32f, 14f, 28f, 3f)
        rr(Palette.sunflower, 42f, 35f, 6f, 22f, 2f)
    }
    circ(Palette.ink, 5f, 50f, 50f)
    miniStar(Palette.sunflower, 84f, 12f, 7f)
    circ(Palette.sunflower, 2f, 92f, 30f)
}

private fun DrawScope.astronaut() {
    rr(Grey, 18f, 56f, 64f, 38f, 10f)
    rr(Palette.cream, 24f, 58f, 52f, 38f, 14f)
    drawRoundRect(Palette.outline, Offset(24f, 58f), Size(52f, 38f), CornerRadius(14f), style = Stroke(2.5f))
    rr(Palette.sky, 38f, 70f, 24f, 14f, 3f)
    circ(Palette.coral, 3f, 45f, 77f); circ(Palette.sunflower, 3f, 55f, 77f)
    rr(Palette.coral, 18f, 32f, 8f, 16f, 3f)
    rr(Palette.coral, 74f, 32f, 8f, 16f, 3f)
    circ(Palette.cream, 28f, 50f, 38f)
    ring(Palette.outline, 28f, 50f, 38f, 3f)
    rr(Palette.ink, 31f, 26f, 38f, 26f, 12f)
    stroke(path { moveTo(38f, 34f); quadraticBezierTo(42f, 30f, 48f, 30f) }, Palette.trail, 3f)
    circ(Palette.trail, 1.8f, 38f, 40f)
}

// ==================================== weather ====================================

private fun DrawScope.fog() {
    cloudAt(Palette.trail, 0f, -14f, 0.78f)
    ln(Grey, 14f, 66f, 72f, 66f, 6f)
    ln(Grey, 28f, 78f, 88f, 78f, 6f)
    ln(Grey, 12f, 90f, 62f, 90f, 6f)
    ln(Grey, 80f, 66f, 86f, 66f, 6f)
    ln(Grey, 72f, 90f, 80f, 90f, 6f)
}

private fun DrawScope.storm() {
    cloudAt(StormGrey, 0f, -14f, 0.92f)
    soft(path { moveTo(54f, 52f); lineTo(38f, 74f); lineTo(50f, 74f); lineTo(42f, 96f); lineTo(66f, 66f); lineTo(53f, 66f); lineTo(62f, 52f); close() }, Palette.sunflower, 2.5f)
    for (x in listOf(24f, 32f, 76f, 84f)) ln(Palette.sky, x, 68f + (x % 8f), x - 4f, 80f + (x % 8f), 4f)
}

private fun DrawScope.hail() {
    cloudAt(Grey, 0f, -14f, 0.92f)
    for ((x, y) in listOf(26f to 72f, 46f to 80f, 66f to 72f, 36f to 92f, 58f to 92f, 78f to 88f)) {
        circ(Palette.trail, 5.5f, x, y)
        ring(Palette.sky, 5.5f, x, y, 2.5f)
    }
}
