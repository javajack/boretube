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
import com.rakesh.boretube.learn.ui.Palette
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** Picture library: animals, birds, insects and sea life. Same rules as ui/Pictures.kt (100×100 grid, flat fills from the palette). */
internal val animalArt: Map<String, DrawScope.() -> Unit> = mapOf(
    // animals
    "lion" to { lion() }, "tiger" to { tiger() }, "elephant" to { elephant() }, "monkey" to { monkey() },
    "horse" to { horse() }, "goat" to { goat() }, "sheep" to { sheep() }, "pig" to { pig() }, "hen" to { hen() },
    "duck" to { duck() }, "frog" to { frog() }, "snake" to { snake() }, "butterfly" to { butterfly() }, "bee" to { bee() },
    "rabbit" to { rabbit() }, "deer" to { deer() }, "camel" to { camel() }, "giraffe" to { giraffe() }, "zebra" to { zebra() },
    "bear" to { bear() }, "owl" to { owl() }, "parrot" to { parrot() }, "peacock" to { peacock() }, "crow" to { crow() },
    "eagle" to { eagle() }, "penguin" to { penguin() }, "turtle" to { turtle() }, "crab" to { crab() }, "snail" to { snail() },
    "spider" to { spider() }, "mouse" to { mouse() }, "squirrel" to { squirrel() }, "buffalo" to { buffalo() },
    "donkey" to { donkey() }, "lizard" to { lizard() }, "caterpillar" to { caterpillar() }, "tadpole" to { tadpole() },
    "chick" to { chick() }, "puppy" to { puppy() }, "kitten" to { kitten() }, "calf" to { calf() }, "leopard" to { leopard() },
    "wolf" to { wolf() }, "fox" to { fox() }, "kangaroo" to { kangaroo() }, "hippo" to { hippo() }, "rhino" to { rhino() },
    "crocodile" to { crocodile() }, "cheetah" to { cheetah() }, "panda" to { panda() }, "koala" to { koala() },
    "gorilla" to { gorilla() }, "bat" to { bat() }, "hedgehog" to { hedgehog() }, "ox" to { ox() }, "yak" to { yak() },
    // birds
    "sparrow" to { sparrow() }, "pigeon" to { pigeon() }, "kingfisher" to { kingfisher() }, "flamingo" to { flamingo() },
    "ostrich" to { ostrich() }, "swan" to { swan() }, "woodpecker" to { woodpecker() }, "vulture" to { vulture() },
    // insects
    "mosquito" to { mosquito() }, "housefly" to { housefly() }, "ladybird" to { ladybird() }, "dragonfly" to { dragonfly() },
    "grasshopper" to { grasshopper() }, "earthworm" to { earthworm() }, "cockroach" to { cockroach() }, "honeycomb" to { honeycomb() },
    // sea
    "octopus" to { octopus() }, "starfish" to { starfish() }, "jellyfish" to { jellyfish() }, "dolphin" to { dolphin() },
    "whale" to { whale() }, "shark" to { shark() }, "seahorse" to { seahorse() }, "prawn" to { prawn() },
)

// Colours: the file-level three from Pictures.kt, plus a few coats the palette doesn't have.
private val Brown = Color(0xFF8A5A00)
private val Grey = Color(0xFF9AA3B5)
private val Pink = Color(0xFFFFB3A6)
private val PinkDeep = Color(0xFFF2877A)
private val Chestnut = Color(0xFFB4652F)
private val Fawn = Color(0xFFD99A55)
private val Sand = Color(0xFFE6BE7E)
private val Orange = Color(0xFFFF8C1A)
private val Slate = Color(0xFF6F788C)
private val Charcoal = Color(0xFF3A3D52)
private val Mauve = Color(0xFFA897D6)
private val Croc = Color(0xFF5E9A48)
private val Rose = Color(0xFFFF8FA3)
private val Dolphin = Color(0xFF86A9D8)

private val Ink get() = Palette.ink
private val Cream get() = Palette.cream
private val Edge get() = Palette.outline

// ---- drawing helpers (Number params keep the coordinates readable) ----

private fun Path.m(x: Number, y: Number) = moveTo(x.toFloat(), y.toFloat())
private fun Path.l(x: Number, y: Number) = lineTo(x.toFloat(), y.toFloat())
private fun Path.q(x1: Number, y1: Number, x2: Number, y2: Number) =
    quadraticBezierTo(x1.toFloat(), y1.toFloat(), x2.toFloat(), y2.toFloat())
private fun Path.cu(x1: Number, y1: Number, x2: Number, y2: Number, x3: Number, y3: Number) =
    cubicTo(x1.toFloat(), y1.toFloat(), x2.toFloat(), y2.toFloat(), x3.toFloat(), y3.toFloat())

private fun DrawScope.shape(c: Color, b: Path.() -> Unit) = drawPath(Path().apply(b), c)
private fun DrawScope.curve(c: Color, w: Number, b: Path.() -> Unit) =
    drawPath(Path().apply(b), c, style = Stroke(w.toFloat(), cap = StrokeCap.Round, join = StrokeJoin.Round))
private fun DrawScope.poly(c: Color, vararg p: Number) = shape(c) {
    m(p[0], p[1]); for (i in 2 until p.size step 2) l(p[i], p[i + 1]); close()
}
private fun DrawScope.ov(c: Color, cx: Number, cy: Number, rx: Number, ry: Number = rx) {
    val x = cx.toFloat(); val y = cy.toFloat(); val a = rx.toFloat(); val b = ry.toFloat()
    drawOval(c, Offset(x - a, y - b), Size(2 * a, 2 * b))
}
private fun DrawScope.ring(c: Color, cx: Number, cy: Number, r: Number, w: Number = 2.5f) =
    drawCircle(c, r.toFloat(), Offset(cx.toFloat(), cy.toFloat()), style = Stroke(w.toFloat()))
private fun DrawScope.ln(c: Color, x1: Number, y1: Number, x2: Number, y2: Number, w: Number = 3f) =
    drawLine(c, Offset(x1.toFloat(), y1.toFloat()), Offset(x2.toFloat(), y2.toFloat()), w.toFloat(), StrokeCap.Round)
private fun DrawScope.rr(c: Color, x: Number, y: Number, w: Number, h: Number, r: Number) =
    drawRoundRect(c, Offset(x.toFloat(), y.toFloat()), Size(w.toFloat(), h.toFloat()), CornerRadius(r.toFloat()))
private fun DrawScope.tilt(deg: Number, px: Number, py: Number, b: DrawScope.() -> Unit) =
    rotate(deg.toFloat(), Offset(px.toFloat(), py.toFloat()), b)
private fun DrawScope.inOval(cx: Number, cy: Number, rx: Number, ry: Number, b: DrawScope.() -> Unit) {
    val x = cx.toFloat(); val y = cy.toFloat(); val a = rx.toFloat(); val bb = ry.toFloat()
    clipPath(Path().apply { addOval(Rect(x - a, y - bb, x + a, y + bb)) }) { b() }
}

/** Dot eye in ink, like the cat; [bright] gives a cream-ringed eye for dark coats. */
private fun DrawScope.eye(x: Number, y: Number, r: Number = 3.5f, bright: Boolean = false) {
    if (bright) ov(Cream, x, y, r.toFloat() + 1.6f)
    ov(Ink, x, y, r)
}

/** White animals: everything is drawn twice, first grown in the egg's outline colour, then in cream. */
private inline fun DrawScope.outlined(fill: Color = Cream, parts: DrawScope.(c: Color, g: Float) -> Unit) {
    parts(Edge, 2.5f)
    parts(fill, 0f)
}

// ================= animals =================

private fun DrawScope.lion() {
    for (i in 0 until 12) {
        val a = i * PI / 6
        ov(Chestnut, 50 + 30 * cos(a), 52 + 30 * sin(a), 13)
    }
    ov(Chestnut, 50, 52, 32)
    ov(Palette.sunflower, 34, 32, 7); ov(Palette.sunflower, 66, 32, 7)
    ov(Palette.sunflower, 50, 54, 24)
    ov(Cream, 44, 64, 8); ov(Cream, 56, 64, 8)
    poly(Ink, 45, 58, 55, 58, 50, 64)
    eye(41, 49); eye(59, 49)
}

/** Shared big-cat body, facing right; [marks] draws over it (body clip available via inOval). */
private fun DrawScope.bigCat(coat: Color, slim: Boolean, marks: DrawScope.(by: Float, ry: Float) -> Unit) {
    val by = if (slim) 50f else 54f
    val ry = if (slim) 11f else 14f
    curve(coat, 6) { m(22, by - 4); cu(8, by - 2, 4, by + 12, 10, by + 22) }
    for (x in listOf(26, 36, 58, 68)) ln(coat, x, by, x, 88, 8)
    ov(coat, 46, by, 28, ry)
    ov(coat, 68, 28, 5.5f); ov(coat, 84, 28, 5.5f)
    ov(coat, 76, 40, 14)
    ov(Cream, 84, 46, 7, 5)
    ov(Ink, 89, 43, 2.5f)
    marks(by, ry)
    eye(80, 37, 3)
}

private fun DrawScope.tiger() = bigCat(Orange, slim = false) { by, ry ->
    inOval(46, by, 28, ry) { for (x in 24..68 step 8) ln(Ink, x, by - ry - 2, x - 3, by - 3, 4) }
    ln(Ink, 73, 29, 73, 34, 2.5f); ln(Ink, 77, 27, 77, 33, 2.5f); ln(Ink, 81, 29, 81, 34, 2.5f)
    ln(Ink, 64, 40, 69, 42, 2.5f); ln(Ink, 65, 46, 70, 46, 2.5f)
    ov(Ink, 10, by + 22, 3.5f)
}

private fun DrawScope.leopard() = bigCat(Palette.sunflowerSoft, slim = false) { by, ry ->
    inOval(46, by, 28, ry) {
        for ((x, y) in listOf(26 to -4, 36 to 4, 44 to -6, 54 to 3, 64 to -5, 30 to 9, 50 to 10, 62 to 9, 38 to -8)) {
            ring(Brown, x, by + y, 3.6f, 2.4f)
        }
    }
    for ((x, y) in listOf(72 to 32, 78 to 30, 70 to 44)) ov(Brown, x, y, 1.6f)
    for (x in listOf(26, 36, 58, 68)) ov(Brown, x, 76, 1.8f)
}

private fun DrawScope.cheetah() = bigCat(Palette.sunflower, slim = true) { by, ry ->
    inOval(46, by, 28, ry) {
        for (i in 0 until 28) ov(Ink, 20 + (i * 37) % 54, by - 9 + (i * 23) % 19, 1.6f)
    }
    for (x in listOf(26, 36, 58, 68)) { ov(Ink, x, 70, 1.5f); ov(Ink, x, 80, 1.5f) }
    curve(Ink, 2.5f) { m(80, 40); q(80, 46, 85, 50) }
}

private fun DrawScope.elephant() {
    val dark = Color(0xFF7F889B)
    ln(Grey, 16, 46, 10, 62, 3)
    rr(dark, 32, 60, 11, 28, 5); rr(dark, 64, 60, 11, 28, 5)
    rr(Grey, 20, 58, 13, 30, 5); rr(Grey, 52, 58, 13, 30, 5)
    ov(Grey, 44, 50, 30, 22)
    curve(Grey, 10) { m(82, 44); cu(92, 56, 92, 72, 86, 80); q(84, 86, 92, 86) }
    ov(Grey, 72, 40, 17)
    ov(dark, 61, 43, 12, 16)
    eye(77, 36)
}

private fun DrawScope.monkey() {
    ov(Brown, 22, 50, 10); ov(Brown, 78, 50, 10)
    ov(Pink, 22, 50, 6); ov(Pink, 78, 50, 6)
    ov(Brown, 50, 48, 28)
    ov(Pink, 41, 45, 11); ov(Pink, 59, 45, 11)
    ov(Pink, 50, 62, 18, 13)
    eye(42, 45); eye(58, 45)
    ov(Brown, 47, 56, 1.5f); ov(Brown, 53, 56, 1.5f)
    curve(Ink, 3) { m(42, 64); q(50, 71, 58, 64) }
    curve(Brown, 4) { m(44, 22); q(50, 14, 56, 22) }
}

/** Horse-family silhouette facing right; [g] grows every part for outlines. */
private fun DrawScope.equine(c: Color, g: Float = 0f, longEars: Boolean = false) {
    for (x in listOf(24, 32, 58, 66)) ln(c, x, 58, x, 87, 7 + 2 * g)
    ov(c, 44, 52, 26 + g, 13 + g)
    ln(c, 60, 48, 71, 26, 16 + 2 * g)
    if (longEars) { ln(c, 67, 22, 62, 6, 6 + 2 * g); ln(c, 72, 21, 75, 5, 6 + 2 * g) } else ln(c, 68, 20, 69, 11, 5 + 2 * g)
    ln(c, 71, 24, 85, 37, 13 + 2 * g)
}

private fun DrawScope.horse() {
    curve(Ink, 6) { m(20, 46); cu(10, 50, 8, 62, 12, 76) }
    equine(Chestnut)
    curve(Ink, 5) { m(67, 15); q(62, 30, 55, 42) }
    for (x in listOf(24, 32, 58, 66)) ln(Ink, x, 86, x, 88, 7)
    eye(75, 27, 3); ov(Ink, 86, 39, 1.6f)
}

private fun DrawScope.donkey() {
    ln(Grey, 20, 46, 14, 66, 3); ov(Ink, 14, 68, 3.5f)
    equine(Grey, longEars = true)
    ln(Pink, 66.5f, 19, 63, 10, 2.5f); ln(Ink, 62, 6, 62, 6, 6); ln(Ink, 75, 5, 75, 5, 6)
    curve(Ink, 4) { m(66, 22); q(62, 32, 57, 40) }
    ov(Cream, 84, 37, 6)
    for (x in listOf(24, 32, 58, 66)) ln(Ink, x, 86, x, 88, 7)
    eye(75, 28, 3); ov(Ink, 87, 38, 1.5f)
}

private fun DrawScope.zebra() {
    curve(Ink, 3) { m(20, 46); q(12, 54, 14, 66) }; ov(Ink, 14, 68, 3.5f)
    equine(Ink, 1.5f)
    equine(Palette.card)
    inOval(44, 52, 26, 13) { for (x in 20..66 step 7) curve(Ink, 3.5f) { m(x, 38); q(x + 4, 50, x, 66) } }
    for (x in listOf(24, 32, 58, 66)) for (y in listOf(66, 73, 80)) ln(Ink, x - 3, y, x + 3, y, 2.5f)
    for (t in listOf(0.25f, 0.5f, 0.75f)) {
        val cx = 60 + 11 * t; val cy = 48 - 22 * t
        ln(Ink, cx - 6, cy - 3, cx + 6, cy + 3, 3)
    }
    ln(Ink, 74, 27, 78, 31, 3)
    ln(Ink, 82, 34, 86, 38, 9)
    curve(Ink, 5) { m(67, 15); q(62, 30, 55, 42) }
    eye(75, 28, 3)
}

private fun DrawScope.goat() {
    curve(Grey, 4) { m(68, 30); q(64, 16, 54, 18) }
    outlined { c, g ->
        for (x in listOf(30, 37, 58, 65)) ln(c, x, 58, x, 86, 5 + 2 * g)
        ln(c, 26, 46, 22, 36, 5 + 2 * g)
        ov(c, 46, 52, 22 + g, 12 + g)
        ln(c, 62, 48, 70, 34, 12 + 2 * g)
        ln(c, 66, 32, 57, 37, 5 + 2 * g)
        ln(c, 70, 31, 80, 43, 11 + 2 * g)
    }
    poly(Grey, 75, 46, 81, 45, 77, 56)
    for (x in listOf(30, 37, 58, 65)) ln(Grey, x, 85, x, 87, 5)
    eye(73, 34, 3); ov(Ink, 82, 43, 1.5f)
}

private fun DrawScope.sheep() {
    for (x in listOf(34, 42, 54, 62)) ln(Ink, x, 60, x, 86, 5)
    val puffs = listOf(30 to 50, 38 to 40, 50 to 37, 62 to 41, 68 to 52, 60 to 62, 46 to 64, 32 to 61)
    for ((x, y) in puffs) ov(Edge, x, y, 12.5f)
    ov(Edge, 48, 51, 22.5f, 14.5f)
    for ((x, y) in puffs) ov(Cream, x, y, 10)
    ov(Cream, 48, 51, 20, 12)
    ln(Ink, 66, 42, 60, 48, 6)
    tilt(20, 74, 47) { ov(Ink, 74, 47, 9, 12) }
    ov(Cream, 72, 36, 5)
    ov(Cream, 76, 46, 2.6f)
}

private fun DrawScope.pig() {
    for (x in listOf(28, 38, 56, 66)) ln(Pink, x, 64, x, 84, 9)
    curve(PinkDeep, 3) { m(19, 48); cu(10, 46, 10, 36, 16, 38); cu(20, 40, 16, 46, 12, 44) }
    ov(Pink, 44, 54, 28, 20)
    poly(PinkDeep, 62, 36, 66, 22, 76, 33)
    ov(Pink, 72, 48, 16)
    ov(PinkDeep, 87, 52, 6, 8)
    ov(Ink, 86, 49, 1.5f); ov(Ink, 86, 55, 1.5f)
    eye(75, 43)
}

private fun DrawScope.hen() {
    shape(Brown) { m(32, 60); l(14, 26); q(30, 26, 42, 46); close() }
    for (x in listOf(44, 56)) { ln(Palette.sunflower, x, 72, x, 88, 3); ln(Palette.sunflower, x - 5, 88, x + 5, 88, 3) }
    ov(Chestnut, 48, 58, 25, 18)
    ov(Chestnut, 66, 34, 12)
    ov(Palette.coral, 61, 21, 4); ov(Palette.coral, 66, 20, 4.5f); ov(Palette.coral, 71, 22, 4)
    ov(Palette.coral, 75, 45, 3, 5)
    poly(Palette.sunflower, 76, 31, 86, 35, 76, 39)
    ov(Brown, 44, 58, 14, 9)
    eye(69, 31, 3)
}

private fun DrawScope.chick() {
    for (x in listOf(42, 54)) ln(Orange, x, 70, x, 80, 3)
    ov(Palette.sunflowerSoft, 48, 60, 21, 19)
    ov(Palette.sunflowerSoft, 60, 38, 14)
    tilt(-20, 42, 58) { ov(Palette.sunflower, 42, 58, 10, 7) }
    poly(Orange, 72, 36, 81, 39, 72, 43)
    eye(64, 35, 3)
    curve(Palette.sunflower, 3) { m(58, 25); q(56, 18, 62, 16) }
    outlined { c, g ->
        shape(c) {
            m(22 - g, 68 - g); l(30, 74 - g); l(38, 66 - g); l(46, 74 - g); l(54, 66 - g); l(62, 74 - g); l(70, 66 - g); l(78 + g, 70 - g)
            cu(78 + g, 86 + g, 66, 92 + g, 50, 92 + g); cu(34, 92 + g, 22 - g, 86 + g, 22 - g, 68 - g); close()
        }
    }
}

private fun DrawScope.duck() {
    for (x in listOf(42, 56)) { ln(Orange, x, 70, x, 84, 3); poly(Orange, x - 2, 82, x + 9, 88, x - 2, 89) }
    outlined { c, g ->
        poly(c, 26, 58, 10 - g, 44 - g, 32, 50)
        ov(c, 46, 60, 28 + g, 16 + g)
        ln(c, 63, 50, 67, 36, 12 + 2 * g)
        ov(c, 68, 32, 12 + g)
    }
    curve(Edge, 2.5f) { m(30, 56); q(44, 70, 58, 58) }
    rr(Orange, 75, 33, 17, 7, 3.5f)
    eye(71, 29, 3)
}

private fun DrawScope.frog() {
    ov(Palette.mint, 22, 74, 14, 10); ov(Palette.mint, 78, 74, 14, 10)
    ov(Palette.mint, 50, 62, 28, 22)
    ov(Palette.mint, 36, 38, 11); ov(Palette.mint, 64, 38, 11)
    ov(Palette.garden, 50, 70, 16, 12)
    ov(Cream, 36, 37, 7); ov(Cream, 64, 37, 7)
    eye(37, 37); eye(63, 37)
    curve(Ink, 3) { m(36, 54); q(50, 64, 64, 54) }
    ov(Palette.mintInk, 38, 85, 7, 4); ov(Palette.mintInk, 62, 85, 7, 4)
}

private fun DrawScope.snake() {
    curve(Palette.mint, 12) { m(16, 84); cu(40, 92, 72, 88, 70, 70); cu(68, 54, 30, 62, 32, 46); cu(34, 32, 54, 28, 66, 30) }
    for ((x, y) in listOf(30 to 87, 50 to 87, 66 to 78, 50 to 60, 35 to 52, 46 to 34)) ov(Palette.mintInk, x, y, 2.2f)
    curve(Palette.coral, 2) { m(84, 32); l(92, 32); m(92, 32); l(95, 29); m(92, 32); l(95, 35) }
    ov(Palette.mint, 75, 31, 11, 8)
    eye(77, 28, 2.8f)
}

private fun DrawScope.butterfly() {
    ov(Palette.coral, 30, 38, 20, 18); ov(Palette.coral, 70, 38, 20, 18)
    ov(Palette.sunflower, 34, 66, 14, 13); ov(Palette.sunflower, 66, 66, 14, 13)
    ov(Palette.sunflowerSoft, 28, 36, 7); ov(Palette.sunflowerSoft, 72, 36, 7)
    ov(Palette.coral, 33, 68, 4.5f); ov(Palette.coral, 67, 68, 4.5f)
    rr(Ink, 46, 28, 8, 48, 4)
    ov(Ink, 50, 25, 5.5f)
    curve(Ink, 2.5f) { m(48, 22); q(44, 12, 38, 10); m(52, 22); q(56, 12, 62, 10) }
    ov(Ink, 38, 10, 2.5f); ov(Ink, 62, 10, 2.5f)
}

private fun DrawScope.bee() {
    tilt(-25, 42, 36) { ov(Palette.trail, 42, 36, 10, 15); drawOval(Palette.sky, Offset(32f, 21f), Size(20f, 30f), style = Stroke(2f)) }
    tilt(20, 56, 34) { ov(Palette.trail, 56, 34, 10, 15); drawOval(Palette.sky, Offset(46f, 19f), Size(20f, 30f), style = Stroke(2f)) }
    poly(Ink, 24, 56, 12, 60, 24, 64)
    ov(Palette.sunflower, 46, 60, 25, 18)
    inOval(46, 60, 25, 18) { for (x in listOf(36, 50, 64)) ln(Ink, x, 40, x, 80, 6) }
    curve(Ink, 2.5f) { m(76, 48); q(80, 36, 86, 34); m(80, 50); q(88, 42, 92, 42) }
    ov(Ink, 76, 58, 11)
    eye(80, 55, 2.6f, bright = true)
}

private fun DrawScope.rabbit() {
    outlined { c, g ->
        tilt(-8, 42, 24) { ov(c, 42, 24, 7 + g, 16 + g) }
        tilt(8, 58, 24) { ov(c, 58, 24, 7 + g, 16 + g) }
        ov(c, 50, 74, 22 + g, 17 + g)
        ov(c, 50, 48, 17 + g)
        ov(c, 38, 89, 8 + g, 4 + g); ov(c, 62, 89, 8 + g, 4 + g)
    }
    tilt(-8, 42, 24) { ov(Pink, 42, 25, 3.5f, 11) }
    tilt(8, 58, 24) { ov(Pink, 58, 25, 3.5f, 11) }
    eye(43, 46); eye(57, 46)
    poly(Pink, 46, 53, 54, 53, 50, 57)
    curve(Ink, 2) { m(46, 61); q(50, 64, 50, 58); q(50, 64, 54, 61) }
}

private fun DrawScope.deer() {
    for (x in listOf(28, 35, 58, 65)) { ln(Fawn, x, 58, x, 87, 4.5f); ln(Ink, x, 87, x, 88, 4.5f) }
    ln(Fawn, 24, 46, 18, 52, 5)
    ov(Fawn, 46, 52, 24, 11)
    ln(Fawn, 62, 48, 70, 30, 10)
    ln(Fawn, 66, 28, 58, 24, 5)
    ln(Fawn, 70, 28, 81, 37, 10)
    curve(Brown, 3) { m(70, 24); l(65, 8); m(67, 15); l(59, 11); m(73, 23); l(79, 7); m(76, 15); l(85, 11) }
    for ((x, y) in listOf(34 to 48, 42 to 52, 50 to 47, 56 to 53, 38 to 56, 46 to 57, 30 to 53)) ov(Cream, x, y, 1.8f)
    eye(73, 30, 2.8f); ov(Ink, 85, 38, 2)
}

private fun DrawScope.camel() {
    val coat = Color(0xFFD9A65E)
    for (x in listOf(30, 38, 60, 68)) ln(coat, x, 60, x, 88, 6)
    ln(coat, 24, 52, 19, 66, 3)
    ov(coat, 46, 44, 17, 14)
    ov(coat, 48, 57, 26, 13)
    curve(coat, 11) { m(66, 54); q(84, 60, 80, 34) }
    ln(coat, 78, 32, 90, 37, 11)
    ln(coat, 76, 29, 74, 24, 4)
    eye(82, 31, 2.6f); ov(Ink, 92, 37, 1.5f)
}

private fun DrawScope.giraffe() {
    val coat = Palette.sunflower
    for (x in listOf(24, 32, 50, 58)) ln(coat, x, 64, x, 93, 5)
    ln(coat, 20, 56, 14, 70, 2); ov(Brown, 14, 71, 2.5f)
    ov(coat, 40, 60, 23, 11)
    curve(Brown, 4) { m(52, 50); l(66, 16) }
    ln(coat, 56, 54, 70, 18, 11)
    ln(Brown, 68, 13, 66, 6, 2.5f); ov(Brown, 66, 5, 2.5f)
    ln(Brown, 73, 13, 73, 6, 2.5f); ov(Brown, 73, 5, 2.5f)
    ln(coat, 66, 16, 59, 13, 4)
    ln(coat, 70, 16, 83, 23, 10)
    inOval(40, 60, 23, 11) {
        for ((x, y) in listOf(24 to 56, 34 to 54, 46 to 54, 56 to 58, 28 to 64, 40 to 64, 52 to 66)) rr(Brown, x - 3.5f, y - 3.5f, 7, 7, 2.5f)
    }
    for ((x, y) in listOf(60 to 42, 64 to 32, 67 to 24)) rr(Brown, x - 2.5f, y - 2.5f, 5, 5, 2)
    eye(73, 18, 2.6f)
}

private fun DrawScope.bear() {
    ov(Brown, 26, 28, 11); ov(Brown, 74, 28, 11)
    ov(Sand, 26, 28, 5.5f); ov(Sand, 74, 28, 5.5f)
    ov(Brown, 50, 54, 32, 30)
    ov(Sand, 50, 64, 15, 12)
    ov(Ink, 50, 58, 6, 4.5f)
    curve(Ink, 2.5f) { m(50, 62); l(50, 66); m(44, 68); q(50, 72, 56, 68) }
    eye(38, 47); eye(62, 47)
}

private fun DrawScope.owl() {
    ln(Chestnut, 14, 90, 86, 90, 5)
    poly(Brown, 26, 34, 26, 12, 42, 26)
    poly(Brown, 74, 34, 74, 12, 58, 26)
    ov(Brown, 50, 56, 28, 33)
    ov(Sand, 50, 70, 16, 17)
    ov(Sand, 38, 42, 12.5f); ov(Sand, 62, 42, 12.5f)
    ov(Palette.sunflower, 38, 42, 8.5f); ov(Palette.sunflower, 62, 42, 8.5f)
    ov(Ink, 38, 42, 5); ov(Ink, 62, 42, 5)
    ov(Cream, 40, 40, 1.6f); ov(Cream, 64, 40, 1.6f)
    poly(Orange, 46, 52, 54, 52, 50, 59)
    ov(Orange, 42, 89, 3); ov(Orange, 58, 89, 3)
}

private fun DrawScope.parrot() {
    ln(Brown, 16, 74, 88, 74, 6)
    curve(Palette.mintInk, 8) { m(42, 62); l(24, 94) }
    tilt(18, 50, 52) { ov(Palette.mint, 50, 52, 14, 23) }
    ov(Palette.mint, 58, 28, 13)
    tilt(18, 46, 54) { ov(Palette.mintInk, 46, 54, 8, 15) }
    shape(Palette.coral) { m(67, 22); q(80, 22, 78, 38); q(74, 32, 67, 33); close() }
    curve(Ink, 2.5f) { m(48, 36); q(56, 44, 66, 38) }
    eye(60, 25, 3)
    ov(Grey, 50, 74, 4, 3); ov(Grey, 58, 74, 4, 3)
}

private fun DrawScope.peacock() {
    drawArc(Palette.mintInk, 150f, 240f, true, Offset(8f, 14f), Size(84f, 84f))
    for (r in listOf(33, 20)) {
        val n = if (r == 33) 9 else 6
        for (i in 0 until n) {
            val a = (160 + i * 220.0 / (n - 1)) * PI / 180
            val x = 50 + r * cos(a); val y = 56 + r * sin(a)
            ov(Palette.mint, x, y, 6); ov(Palette.sunflower, x, y, 3.6f); ov(Palette.sky, x, y, 1.8f)
        }
    }
    for (x in listOf(46, 54)) ln(Grey, x, 80, x, 94, 3)
    ov(Palette.sky, 50, 70, 10, 15)
    ln(Palette.sky, 50, 64, 50, 42, 8)
    ov(Palette.sky, 50, 38, 7)
    for (dx in listOf(-5, 0, 5)) { ln(Palette.sky, 50, 32, 50 + dx, 23, 1.6f); ov(Palette.sky, 50 + dx, 22, 2.2f) }
    poly(Palette.sunflower, 48, 42, 52, 42, 50, 47)
    eye(47.5f, 37, 1.6f); eye(52.5f, 37, 1.6f)
}

private fun DrawScope.crow() {
    for (x in listOf(46, 54)) { ln(Ink, x, 68, x, 86, 3); ln(Ink, x - 4, 86, x + 5, 86, 3) }
    poly(Ink, 30, 52, 8, 66, 12, 72, 34, 62)
    ov(Ink, 46, 56, 22, 14)
    ov(Grey, 61, 46, 9, 11)
    ov(Palette.muted, 42, 54, 14, 8)
    ov(Ink, 68, 38, 12)
    poly(Ink, 77, 33, 94, 41, 77, 46)
    eye(70, 35, 2, bright = true)
}

private fun DrawScope.eagle() {
    for (s in listOf(-1, 1)) {
        val x = { v: Number -> 50 + s * v.toFloat() }
        poly(Brown, x(4), 44, x(44), 30, x(40), 39, x(46), 42, x(40), 48, x(44), 52, x(34), 55, x(4), 60)
    }
    poly(Brown, 44, 68, 56, 68, 62, 84, 38, 84)
    ov(Brown, 50, 56, 10, 17)
    ov(Edge, 50, 36, 11.5f); ov(Cream, 50, 36, 9)
    shape(Palette.sunflower) { m(46, 38); l(54, 38); q(54, 46, 49, 48); q(51, 44, 46, 42); close() }
    eye(46, 34, 2); eye(54, 34, 2)
}

private fun DrawScope.penguin() {
    ov(Orange, 41, 89, 8, 4); ov(Orange, 59, 89, 8, 4)
    tilt(20, 26, 56) { ov(Ink, 26, 56, 6, 17) }
    tilt(-20, 74, 56) { ov(Ink, 74, 56, 6, 17) }
    ov(Ink, 50, 52, 24, 36)
    ov(Cream, 50, 60, 16, 26)
    ov(Cream, 43, 36, 8, 9); ov(Cream, 57, 36, 8, 9)
    eye(44, 36, 3); eye(56, 36, 3)
    poly(Orange, 45, 42, 55, 42, 50, 48)
}

private fun DrawScope.turtle() {
    ov(Palette.mint, 30, 70, 8, 9); ov(Palette.mint, 64, 70, 8, 9)
    poly(Palette.mint, 18, 58, 8, 64, 20, 64)
    ln(Palette.mint, 72, 62, 82, 56, 10)
    ov(Palette.mint, 84, 54, 10, 9)
    drawArc(Palette.mintInk, 180f, 180f, true, Offset(16f, 30f), Size(68f, 58f))
    rr(Palette.mint, 14, 57, 72, 7, 3.5f)
    poly(Palette.mint, 44, 38, 56, 38, 61, 46, 56, 54, 44, 54, 39, 46)
    for (x in listOf(26, 74)) ov(Palette.mint, x, 50, 6, 4)
    ln(Palette.mint, 50, 32, 50, 35, 3)
    eye(87, 51, 2.8f)
    curve(Ink, 2) { m(88, 57); q(91, 58, 93, 56) }
}

private fun DrawScope.crab() {
    for (s in listOf(-1, 1)) {
        for (i in 0 until 3) {
            val y = 62 + i * 8
            curve(Palette.coral, 4) { m(50 + s * 20, y); l(50 + s * 34, y + 2); l(50 + s * 38, y + 10) }
        }
        curve(Palette.coral, 5) { m(50 + s * 18, 52); l(50 + s * 26, 36) }
        drawArc(Palette.coral, if (s < 0) -60f else -150f, 300f, true, Offset(50f + s * 30f - 10f, 18f), Size(20f, 20f))
    }
    ov(Palette.coral, 50, 64, 26, 18)
    ln(Palette.coral, 43, 50, 41, 38, 3); ln(Palette.coral, 57, 50, 59, 38, 3)
    ov(Cream, 41, 36, 5); ov(Cream, 59, 36, 5)
    eye(41, 36, 2.6f); eye(59, 36, 2.6f)
    curve(Ink, 2.5f) { m(44, 66); q(50, 71, 56, 66) }
}

private fun DrawScope.snail() {
    rr(Grey, 12, 74, 70, 13, 6.5f)
    ln(Grey, 76, 80, 82, 62, 12)
    ln(Grey, 80, 60, 76, 46, 3); ln(Grey, 85, 60, 89, 46, 3)
    ov(Ink, 76, 45, 2.6f); ov(Ink, 89, 45, 2.6f)
    ov(Palette.sunflower, 44, 52, 27)
    curve(Brown, 3.5f) {
        for (i in 0..60) {
            val t = i / 60.0
            val r = 21 * (1 - t) + 2
            val a = -PI / 2 + t * 4.2 * PI
            val x = 46 + r * cos(a); val y = 54 + r * sin(a)
            if (i == 0) m(x, y) else l(x, y)
        }
    }
    eye(84, 70, 2.4f)
}

private fun DrawScope.spider() {
    ln(Grey, 50, 4, 50, 40, 2)
    val knees = listOf(24 to 34, 18 to 46, 18 to 60, 24 to 74)
    val feet = listOf(12 to 42, 6 to 54, 8 to 70, 16 to 86)
    for (s in listOf(-1, 1)) for (i in 0 until 4) {
        curve(Ink, 3.5f) { m(50 + s * 4, 50 + i * 4); l(50 + s * (50 - knees[i].first), knees[i].second); l(50 + s * (50 - feet[i].first), feet[i].second) }
    }
    ov(Ink, 50, 62, 15, 17)
    ov(Ink, 50, 44, 10)
    ov(Cream, 46, 43, 3.2f); ov(Cream, 54, 43, 3.2f)
    ov(Ink, 46.5f, 43.5f, 1.6f); ov(Ink, 53.5f, 43.5f, 1.6f)
}

private fun DrawScope.mouse() {
    curve(Pink, 3) { m(24, 72); cu(8, 74, 4, 56, 16, 52) }
    ov(Pink, 40, 80, 5, 3); ov(Pink, 64, 80, 5, 3)
    ov(Grey, 48, 64, 25, 17)
    ov(Grey, 70, 58, 14)
    poly(Grey, 76, 48, 93, 62, 76, 70)
    ov(Grey, 62, 42, 11); ov(Pink, 62, 42, 7)
    ov(Pink, 92, 62, 3)
    eye(76, 55, 3)
    ln(Palette.muted, 86, 64, 96, 60, 1.5f); ln(Palette.muted, 86, 66, 96, 68, 1.5f)
}

private fun DrawScope.squirrel() {
    curve(Fawn, 20) { m(40, 80); cu(14, 80, 10, 58, 20, 44); cu(28, 32, 20, 22, 30, 16) }
    ov(Fawn, 46, 88, 8, 4)
    tilt(-15, 54, 64) { ov(Fawn, 54, 64, 16, 21) }
    ov(Fawn, 64, 38, 12)
    poly(Fawn, 72, 34, 82, 42, 72, 46)
    poly(Fawn, 58, 30, 58, 18, 66, 28)
    for (dx in listOf(-5, 0, 5)) curve(Cream, 2.5f) { m(46 + dx, 50); q(42 + dx, 62, 48 + dx, 76) }
    ov(Brown, 70, 60, 5.5f, 6.5f)
    ov(Fawn, 66, 56, 4); ov(Fawn, 66, 64, 4)
    eye(68, 36, 2.8f); ov(Ink, 82, 42, 1.8f)
}

private fun DrawScope.buffalo() {
    for (x in listOf(24, 34, 56, 66)) ln(Charcoal, x, 62, x, 88, 8)
    ln(Charcoal, 16, 48, 12, 66, 3)
    ov(Charcoal, 44, 54, 30, 17)
    ov(Charcoal, 78, 58, 12, 14)
    curve(Grey, 6) { m(72, 48); cu(60, 46, 54, 36, 62, 28) }
    curve(Grey, 6) { m(84, 48); cu(96, 46, 98, 36, 90, 28) }
    ov(Palette.muted, 80, 68, 8, 6)
    ov(Ink, 77, 68, 1.5f); ov(Ink, 83, 68, 1.5f)
    eye(73, 56, 2.2f, bright = true); eye(84, 56, 2.2f, bright = true)
}

private fun DrawScope.ox() {
    for (x in listOf(24, 34, 54, 64)) ln(Sand, x, 62, x, 88, 8)
    ln(Sand, 16, 50, 12, 68, 3); ov(Brown, 12, 70, 3.5f)
    ov(Sand, 58, 40, 12, 10)
    ov(Sand, 44, 56, 28, 15)
    poly(Sand, 68, 62, 80, 62, 72, 80)
    ln(Brown, 72, 48, 67, 30, 4.5f); ln(Brown, 84, 48, 89, 30, 4.5f)
    ln(Sand, 70, 52, 62, 50, 5); ln(Sand, 86, 52, 94, 50, 5)
    ov(Sand, 78, 58, 11, 13)
    ov(Fawn, 78, 67, 8, 6)
    ov(Ink, 75, 67, 1.5f); ov(Ink, 81, 67, 1.5f)
    eye(74, 55, 2.6f); eye(82, 55, 2.6f)
}

private fun DrawScope.yak() {
    val coat = Color(0xFF5B4632)
    for (x in listOf(28, 38, 56, 66)) ln(coat, x, 70, x, 88, 8)
    ov(coat, 46, 50, 30, 18)
    ov(coat, 58, 34, 13, 9)
    poly(coat, 16, 52, 76, 52, 76, 76, 70, 70, 64, 78, 58, 70, 52, 78, 46, 70, 40, 78, 34, 70, 28, 78, 22, 70, 16, 74)
    curve(coat, 6) { m(18, 46); q(10, 58, 14, 72) }
    curve(Sand, 4.5f) { m(74, 44); q(64, 40, 68, 28) }
    curve(Sand, 4.5f) { m(86, 44); q(96, 40, 92, 28) }
    ov(coat, 80, 54, 12, 14)
    poly(coat, 70, 44, 90, 44, 86, 52, 80, 48, 74, 52)
    ov(Palette.muted, 80, 64, 7, 5)
    eye(75, 54, 2.2f, bright = true); eye(85, 54, 2.2f, bright = true)
}

private fun DrawScope.lizard() {
    val c = Palette.mintInk
    curve(c, 7) { m(50, 66); cu(50, 80, 60, 84, 70, 82) }
    curve(c, 3.5f) { m(70, 82); q(82, 80, 84, 70) }
    for (s in listOf(-1, 1)) {
        curve(c, 4) { m(50 + s * 6, 40); l(50 + s * 18, 38); l(50 + s * 22, 28) }
        curve(c, 4) { m(50 + s * 6, 62); l(50 + s * 18, 66); l(50 + s * 22, 76) }
        for ((fx, fy) in listOf(22 to 28, 22 to 76)) ov(c, 50 + s * fx, fy, 3)
    }
    ov(c, 50, 52, 10, 18)
    ov(c, 50, 28, 9, 11)
    for (y in listOf(44, 52, 60)) ov(Palette.mint, 50, y, 2.2f)
    eye(45, 24, 2, bright = true); eye(55, 24, 2, bright = true)
}

private fun DrawScope.caterpillar() {
    val segs = listOf(18 to 66, 30 to 60, 42 to 64, 54 to 58, 66 to 60)
    for ((x, y) in segs) { ln(Ink, x, y + 8, x, y + 14, 3) }
    for ((x, y) in segs) ov(Palette.mint, x, y, 10)
    for ((x, y) in segs) ov(Palette.sunflower, x, y - 4, 2.5f)
    curve(Ink, 2.5f) { m(76, 38); l(72, 26); m(84, 38); l(88, 26) }
    ov(Ink, 72, 25, 2.5f); ov(Ink, 88, 25, 2.5f)
    ov(Palette.mintInk, 80, 48, 13)
    eye(76, 45, 2.6f, bright = true); eye(86, 45, 2.6f, bright = true)
    curve(Cream, 2.5f) { m(76, 53); q(81, 57, 86, 53) }
}

private fun DrawScope.tadpole() {
    for ((x, y, r) in listOf(Triple(78, 22, 5), Triple(88, 34, 3.5f), Triple(70, 34, 3))) ring(Palette.sky, x, y, r, 2.5f)
    curve(Ink, 8) { m(44, 56); cu(56, 46, 66, 66, 78, 56) }
    curve(Ink, 4) { m(76, 57); q(84, 50, 92, 54) }
    ov(Ink, 34, 58, 20, 17)
    eye(28, 52, 3, bright = true); eye(42, 52, 3, bright = true)
    curve(Cream, 2.5f) { m(30, 64); q(35, 68, 40, 64) }
}

private fun DrawScope.puppy() {
    curve(Brown, 6) { m(32, 76); q(18, 72, 20, 58) }
    ov(Brown, 48, 76, 18, 14)
    ln(Brown, 42, 76, 42, 90, 8); ln(Brown, 56, 76, 56, 90, 8)
    ov(Sand, 42, 90, 5, 3); ov(Sand, 56, 90, 5, 3)
    rr(Palette.coral, 36, 61, 26, 5, 2.5f)
    ov(Brown, 49, 42, 23, 21)
    tilt(15, 26, 44) { ov(Ink, 26, 44, 8, 15) }
    tilt(-15, 72, 44) { ov(Ink, 72, 44, 8, 15) }
    ov(Sand, 49, 52, 10, 8)
    ov(Ink, 49, 48, 4.5f, 3.2f)
    ov(Pink, 49, 59, 3.5f, 4)
    ov(Cream, 40, 40, 4); ov(Cream, 58, 40, 4)
}

private fun DrawScope.kitten() {
    ov(Palette.lavender, 78, 80, 11)
    curve(Cream, 2) { m(70, 76); q(78, 70, 86, 78); m(70, 84); q(78, 78, 88, 84) }
    curve(Palette.lavender, 2) { m(68, 82); q(60, 90, 54, 86) }
    curve(Palette.sunflower, 6) { m(26, 80); cu(10, 80, 10, 62, 18, 60) }
    ov(Palette.sunflower, 40, 74, 17, 15)
    ln(Palette.sunflower, 36, 78, 36, 90, 7); ln(Palette.sunflower, 46, 78, 48, 90, 7)
    poly(Palette.sunflower, 24, 36, 26, 16, 38, 28)
    poly(Palette.sunflower, 56, 36, 54, 16, 42, 28)
    ov(Palette.sunflower, 40, 44, 19)
    ln(Orange, 36, 28, 37, 33, 2.5f); ln(Orange, 44, 28, 43, 33, 2.5f)
    eye(33, 44, 3.8f); eye(47, 44, 3.8f)
    poly(Pink, 38, 50, 42, 50, 40, 53)
    curve(Ink, 2) { m(36, 55); q(40, 58, 40, 53); q(40, 58, 44, 55) }
}

private fun DrawScope.calf() {
    outlined { c, g ->
        for (x in listOf(30, 38, 54, 62)) ln(c, x, 62, x, 86, 6 + 2 * g)
        ln(c, 24, 58, 18, 70, 3 + 2 * g)
        ov(c, 46, 62, 22 + g, 13 + g)
        ln(c, 64, 42, 54, 40, 6 + 2 * g)
        ov(c, 72, 46, 14 + g, 13 + g)
    }
    inOval(46, 62, 22, 13) { ov(Ink, 36, 56, 9, 7); ov(Ink, 56, 68, 7, 6) }
    ov(Ink, 66, 40, 5, 4)
    for (x in listOf(30, 38, 54, 62)) ln(Brown, x, 85, x, 87, 6)
    ov(Pink, 80, 54, 8, 6)
    ov(Ink, 78, 53, 1.3f); ov(Ink, 83, 53, 1.3f)
    eye(74, 43, 3)
}

private fun DrawScope.wolf() {
    ov(Palette.sunflowerSoft, 22, 22, 11)
    curve(Grey, 11) { m(38, 86); q(14, 90, 12, 70) }
    ov(Grey, 42, 70, 18, 19)
    ln(Grey, 50, 62, 58, 38, 16)
    poly(Grey, 50, 32, 47, 14, 60, 26)
    ov(Grey, 60, 34, 12)
    poly(Grey, 58, 26, 84, 16, 70, 38)
    ov(Cream, 56, 62, 5, 11)
    ln(Grey, 56, 70, 58, 90, 7)
    ov(Grey, 34, 87, 9, 4)
    ov(Ink, 83, 16.5f, 2.4f)
    eye(63, 29, 2.4f)
}

private fun DrawScope.fox() {
    curve(Palette.coral, 13) { m(26, 50); q(8, 52, 10, 70) }
    ov(Edge, 10, 74, 6.5f); ov(Cream, 10, 74, 5)
    for (x in listOf(28, 36, 56, 64)) { ln(Palette.coral, x, 56, x, 84, 5); ln(Ink, x, 80, x, 87, 5) }
    ov(Palette.coral, 46, 52, 22, 11)
    poly(Palette.coral, 63, 38, 66, 20, 74, 32)
    poly(Palette.coral, 74, 32, 80, 20, 82, 36)
    ln(Ink, 66, 22, 67, 26, 3); ln(Ink, 79, 22, 79, 26, 3)
    ov(Palette.coral, 72, 42, 11)
    poly(Palette.coral, 76, 37, 93, 47, 76, 52)
    poly(Cream, 72, 47, 91, 48, 76, 53)
    ov(Cream, 64, 54, 5, 7)
    ov(Ink, 92, 47, 2.5f)
    eye(76, 40, 2.6f)
}

private fun DrawScope.kangaroo() {
    curve(Fawn, 9) { m(40, 74); q(24, 86, 8, 90) }
    ln(Fawn, 50, 86, 68, 88, 7)
    ov(Fawn, 50, 72, 13, 16)
    tilt(15, 56, 52) { ov(Fawn, 56, 52, 12, 22) }
    ov(Sand, 60, 62, 8, 9)
    ov(Fawn, 62, 55, 5); ov(Ink, 63, 54, 1.3f)
    ln(Fawn, 64, 40, 72, 48, 4)
    ln(Fawn, 60, 18, 56, 5, 5); ln(Fawn, 64, 17, 66, 4, 5)
    ov(Fawn, 63, 24, 9)
    ln(Fawn, 65, 24, 75, 28, 8)
    eye(65, 21, 2.4f); ov(Ink, 78, 28, 1.8f)
}

private fun DrawScope.hippo() {
    for (x in listOf(22, 36, 52, 62)) ln(Mauve, x, 64, x, 86, 12)
    ln(Mauve, 12, 52, 8, 60, 3)
    ov(Mauve, 40, 56, 30, 22)
    ov(Mauve, 64, 36, 4.5f)
    ov(Mauve, 70, 50, 16, 16)
    ov(Mauve, 82, 60, 13, 12)
    ov(Mauve, 72, 38, 5.5f)
    eye(72, 38, 2.6f)
    ov(PinkDeep, 85, 52, 2); ov(PinkDeep, 89, 55, 2)
    curve(Palette.muted, 2.5f) { m(74, 66); q(84, 70, 94, 62) }
}

private fun DrawScope.rhino() {
    for (x in listOf(24, 34, 54, 64)) ln(Grey, x, 62, x, 88, 10)
    ln(Grey, 14, 48, 10, 62, 3)
    ov(Grey, 42, 54, 28, 18)
    tilt(18, 74, 58) { ov(Grey, 74, 58, 17, 11) }
    poly(Sand, 80, 52, 92, 30, 90, 56)
    poly(Sand, 73, 48, 77, 38, 80, 48)
    ln(Grey, 64, 46, 62, 36, 5)
    curve(Slate, 2.5f) { m(60, 40); q(56, 54, 60, 68); m(30, 40); q(26, 54, 30, 68) }
    eye(72, 54, 2.6f)
}

private fun DrawScope.crocodile() {
    val dark = Palette.mintInk
    for ((x0, x1) in listOf(28 to 24, 36 to 40, 62 to 58, 70 to 74)) ln(Croc, x0, 62, x1, 74, 6)
    for (x in 16..60 step 8) poly(dark, x - 4, 50 - (x - 16) * 0.05f, x, 42 - (x - 16) * 0.05f, x + 4, 50 - (x - 16) * 0.05f)
    shape(Croc) {
        m(4, 52); cu(20, 46, 40, 44, 60, 46); l(68, 46); cu(80, 50, 90, 50, 95, 54); l(95, 60)
        cu(80, 66, 70, 66, 62, 66); cu(40, 68, 20, 62, 4, 52); close()
    }
    ov(Croc, 68, 45, 6)
    eye(69, 44, 2.6f, bright = true)
    ln(Ink, 70, 58, 94, 57, 2.5f)
    for (x in listOf(74, 80, 86)) poly(Cream, x, 57.6f, x + 3, 57.4f, x + 1.5f, 61.5f)
    ov(dark, 92, 51, 1.8f)
}

private fun DrawScope.panda() {
    ov(Ink, 25, 28, 11); ov(Ink, 75, 28, 11)
    ov(Edge, 50, 54, 34.5f, 30.5f)
    ov(Cream, 50, 54, 32, 28)
    tilt(25, 38, 50) { ov(Ink, 38, 50, 8, 11) }
    tilt(-25, 62, 50) { ov(Ink, 62, 50, 8, 11) }
    ov(Cream, 39, 48, 2.6f); ov(Cream, 61, 48, 2.6f)
    ov(Ink, 50, 64, 5.5f, 4)
    curve(Ink, 2.5f) { m(50, 66); l(50, 70); m(45, 72); q(50, 75, 55, 72) }
}

private fun DrawScope.koala() {
    ov(Grey, 22, 34, 16); ov(Grey, 78, 34, 16)
    ov(Cream, 20, 36, 9); ov(Cream, 80, 36, 9)
    ov(Grey, 50, 56, 29, 27)
    ov(Ink, 50, 60, 7, 11)
    eye(38, 50); eye(62, 50)
    curve(Ink, 2.5f) { m(45, 76); q(50, 79, 55, 76) }
}

private fun DrawScope.gorilla() {
    ov(Charcoal, 36, 86, 11, 6); ov(Charcoal, 64, 86, 11, 6)
    ln(Charcoal, 30, 48, 20, 84, 12); ln(Charcoal, 70, 48, 80, 84, 12)
    ov(Charcoal, 50, 64, 26, 24)
    ov(Grey, 50, 64, 13, 12)
    ov(Charcoal, 50, 32, 17, 17)
    ov(Grey, 50, 38, 12, 10)
    ln(Charcoal, 40, 31, 60, 31, 5)
    eye(45, 35, 2.4f); eye(55, 35, 2.4f)
    ov(Ink, 47.5f, 41, 1.5f); ov(Ink, 52.5f, 41, 1.5f)
    curve(Ink, 2) { m(46, 45); q(50, 47, 54, 45) }
}

private fun DrawScope.bat() {
    for (s in listOf(-1, 1)) {
        val x = { v: Number -> 50 + s * v.toFloat() }
        shape(Palette.muted) {
            m(x(4), 40); l(x(42), 28); q(x(40), 44, x(46), 52)
            q(x(38), 50, x(34), 58); q(x(28), 54, x(20), 60); q(x(14), 54, x(4), 62); close()
        }
    }
    ov(Ink, 50, 54, 9, 14)
    poly(Ink, 42, 36, 41, 22, 49, 32)
    poly(Ink, 58, 36, 59, 22, 51, 32)
    ov(Ink, 50, 40, 9)
    ov(Cream, 46.5f, 39, 2.4f); ov(Cream, 53.5f, 39, 2.4f)
    poly(Cream, 47, 45, 49, 45, 48, 49); poly(Cream, 51, 45, 53, 45, 52, 49)
}

private fun DrawScope.hedgehog() {
    shape(Brown) {
        val n = 15
        for (i in 0..n * 2) {
            val a = PI * (1.0 - 0.02) + i * (PI * 1.1) / (n * 2)
            val r = if (i % 2 == 0) 26 else 36
            val x = 46 + r * cos(a); val y = 70 + r * sin(a)
            if (i == 0) m(x, y) else l(x, y)
        }
        l(56, 80); l(20, 80); close()
    }
    ov(Sand, 50, 72, 28, 12)
    poly(Sand, 66, 60, 92, 70, 68, 82)
    ov(Brown, 40, 84, 5, 3); ov(Brown, 62, 84, 5, 3)
    ov(Ink, 91, 70, 3)
    eye(75, 66, 2.8f)
}

// ================= birds =================

private fun DrawScope.sparrow() {
    for (x in listOf(48, 56)) { ln(PinkDeep, x, 72, x, 86, 2.5f); ln(PinkDeep, x - 4, 86, x + 4, 86, 2.5f) }
    poly(Brown, 32, 56, 10, 40, 14, 34, 36, 50)
    ov(Fawn, 48, 58, 22, 17)
    ov(Palette.hairline, 54, 66, 15, 9)
    ov(Brown, 42, 56, 14, 9)
    ln(Ink, 34, 54, 44, 56, 2); ln(Ink, 36, 60, 46, 61, 2)
    ov(Chestnut, 66, 42, 13)
    ov(Cream, 70, 47, 6, 5)
    ov(Ink, 68, 55, 5, 4)
    poly(Ink, 78, 41, 87, 44, 78, 47)
    eye(70, 39, 2.6f)
}

private fun DrawScope.pigeon() {
    for (x in listOf(46, 54)) { ln(PinkDeep, x, 72, x, 86, 3); ln(PinkDeep, x - 4, 86, x + 4, 86, 3) }
    poly(Slate, 26, 56, 8, 62, 10, 70, 30, 64)
    ov(Grey, 46, 60, 26, 16)
    ln(Grey, 63, 54, 68, 38, 14)
    ov(Palette.mint, 63, 50, 7, 6)
    ov(Palette.lavender, 66, 45, 5, 4)
    ov(Grey, 70, 34, 10)
    ln(Slate, 34, 58, 50, 58, 3); ln(Slate, 36, 64, 52, 64, 3)
    poly(Ink, 78, 33, 86, 36, 78, 38)
    ov(Cream, 78, 32, 1.6f)
    ov(Orange, 72, 32, 2.8f); ov(Ink, 72, 32, 1.4f)
}

private fun DrawScope.kingfisher() {
    rr(Palette.trail, 6, 82, 88, 10, 5)
    ln(Brown, 12, 70, 76, 70, 5)
    poly(Palette.sky, 36, 62, 26, 80, 34, 82, 42, 66)
    tilt(15, 48, 52) { ov(Palette.sky, 48, 52, 14, 19) }
    tilt(15, 54, 58) { ov(Orange, 54, 58, 9, 13) }
    for ((x, y) in listOf(42 to 46, 46 to 52, 40 to 56)) ov(Palette.trail, x, y, 1.8f)
    ov(Palette.sky, 58, 30, 13)
    ov(Orange, 60, 38, 5, 4)
    poly(Ink, 66, 25, 94, 32, 66, 36)
    eye(61, 27, 3)
    ov(Palette.coral, 52, 70, 3, 2); ov(Palette.coral, 58, 70, 3, 2)
}

private fun DrawScope.flamingo() {
    ln(PinkDeep, 46, 62, 46, 94, 3)
    curve(PinkDeep, 3) { m(46, 66); l(56, 74); l(48, 80) }
    tilt(-12, 42, 56) { ov(Rose, 42, 56, 20, 12) }
    tilt(-12, 40, 54) { ov(Palette.coral, 40, 54, 11, 6) }
    curve(Rose, 6) { m(56, 52); cu(76, 48, 72, 30, 62, 26); cu(54, 22, 56, 12, 64, 11) }
    ov(Rose, 66, 13, 6.5f)
    shape(Palette.sunflowerSoft) { m(70, 10); l(78, 14); l(76, 20); close() }
    poly(Ink, 77, 16, 78, 14, 76, 22)
    eye(67, 12, 2)
}

private fun DrawScope.ostrich() {
    curve(Pink, 5) { m(42, 64); l(38, 80); l(42, 94) }
    curve(Pink, 5) { m(54, 64); l(58, 80); l(56, 94) }
    ln(Pink, 42, 94, 48, 94, 4); ln(Pink, 56, 94, 62, 94, 4)
    ov(Ink, 46, 56, 25, 15)
    ov(Cream, 26, 52, 6, 5); ov(Cream, 32, 46, 5, 4); ov(Cream, 30, 58, 5, 4)
    ln(Pink, 64, 50, 70, 17, 6)
    ov(Pink, 72, 15, 6.5f)
    poly(Palette.sunflowerSoft, 77, 13, 86, 16, 77, 19)
    eye(73, 13, 2.2f)
}

private fun DrawScope.swan() {
    rr(Palette.trail, 6, 74, 88, 14, 7)
    outlined { c, g ->
        poly(c, 22, 64, 14 - g, 48 - g, 34, 56)
        ov(c, 44, 64, 28 + g, 13 + g)
        curve(c, 8 + 2 * g) { m(62, 62); cu(74, 56, 68, 40, 64, 34); cu(60, 26, 66, 18, 74, 22) }
        ov(c, 74, 23, 6.5f + g)
    }
    curve(Edge, 2.5f) { m(28, 60); q(44, 72, 60, 62) }
    poly(Orange, 79, 21, 92, 28, 80, 28)
    ov(Ink, 79, 23, 2)
    eye(74, 21, 2)
}

private fun DrawScope.woodpecker() {
    rr(Brown, 72, 4, 20, 92, 5)
    ln(Chestnut, 80, 14, 80, 30, 3); ln(Chestnut, 86, 50, 86, 70, 3); ln(Chestnut, 78, 76, 78, 88, 3)
    poly(Ink, 50, 74, 56, 94, 62, 92, 58, 74)
    tilt(10, 54, 56) { ov(Ink, 54, 56, 12, 22) }
    tilt(10, 50, 58) { ov(Cream, 50, 58, 6, 14) }
    for ((x, y) in listOf(58 to 50, 60 to 58, 58 to 66)) ov(Cream, x, y, 1.8f)
    ov(Ink, 56, 30, 10)
    ov(Palette.coral, 54, 23, 8, 5)
    ln(Cream, 49, 33, 58, 35, 3)
    poly(Grey, 64, 28, 73, 31, 64, 34)
    eye(58, 29, 1.8f, bright = true)
    ln(Ink, 62, 70, 72, 72, 3); ln(Ink, 62, 76, 72, 78, 3)
}

private fun DrawScope.vulture() {
    ln(Chestnut, 18, 86, 74, 86, 5)
    for (x in listOf(40, 50)) ln(Grey, x, 76, x, 86, 3)
    tilt(-15, 42, 58) { ov(Brown, 42, 58, 20, 24) }
    tilt(-15, 38, 62) { ov(Chestnut, 38, 62, 13, 19) }
    poly(Brown, 28, 74, 18, 90, 32, 82)
    ln(Pink, 56, 40, 66, 24, 6)
    ov(Edge, 54, 42, 11.5f, 8.5f); ov(Cream, 54, 42, 10, 7)
    ov(Pink, 68, 22, 7)
    shape(Grey) { m(74, 18); q(86, 20, 82, 32); l(78, 26); l(74, 26); close() }
    eye(69, 20, 2)
}

// ================= insects =================

private fun DrawScope.mosquito() {
    tilt(-20, 40, 34) { ov(Palette.trail, 40, 34, 16, 6); drawOval(Palette.sky, Offset(24f, 28f), Size(32f, 12f), style = Stroke(1.5f)) }
    tilt(-40, 46, 30) { ov(Palette.trail, 46, 30, 14, 5); drawOval(Palette.sky, Offset(32f, 25f), Size(28f, 10f), style = Stroke(1.5f)) }
    for ((k, f) in listOf((36 to 62) to (26 to 88), (46 to 66) to (42 to 90), (60 to 64) to (68 to 90))) {
        curve(Ink, 2) { m(52, 48); l(k.first, k.second); l(f.first, f.second) }
        curve(Palette.muted, 1.6f) { m(54, 48); l(k.first + 6, k.second - 2); l(f.first + 8, f.second - 2) }
    }
    ln(Palette.muted, 18, 58, 46, 48, 7)
    for (x in listOf(24, 32, 40)) ln(Cream, x, 56.5f - (x - 18) * 0.36f - 3, x + 1, 56.5f - (x - 18) * 0.36f + 3, 1.6f)
    ov(Palette.muted, 52, 46, 7, 6)
    ov(Ink, 62, 42, 5)
    ln(Ink, 65, 45, 88, 60, 2)
    curve(Ink, 1.6f) { m(64, 38); q(70, 30, 76, 32) }
    ov(Cream, 63.5f, 41, 1.4f)
}

private fun DrawScope.housefly() {
    tilt(30, 40, 62) { ov(Palette.trail, 40, 62, 11, 22); drawOval(Palette.sky, Offset(29f, 40f), Size(22f, 44f), style = Stroke(1.5f)) }
    tilt(-30, 60, 62) { ov(Palette.trail, 60, 62, 11, 22); drawOval(Palette.sky, Offset(49f, 40f), Size(22f, 44f), style = Stroke(1.5f)) }
    for (s in listOf(-1, 1)) {
        curve(Ink, 3) { m(50 + s * 8, 42); l(50 + s * 20, 36); l(50 + s * 26, 24) }
        curve(Ink, 3) { m(50 + s * 10, 48); l(50 + s * 24, 50); l(50 + s * 32, 44) }
        curve(Ink, 3) { m(50 + s * 8, 56); l(50 + s * 20, 68); l(50 + s * 24, 82) }
    }
    ov(Charcoal, 50, 66, 11, 15)
    for (y in listOf(60, 68, 76)) ln(Grey, 42, y, 58, y, 2)
    ov(Charcoal, 50, 46, 12, 10)
    ov(Ink, 50, 32, 9, 7)
    ov(Palette.coral, 42, 30, 6.5f, 7.5f); ov(Palette.coral, 58, 30, 6.5f, 7.5f)
}

private fun DrawScope.ladybird() {
    for (s in listOf(-1, 1)) for (y in listOf(40, 56, 72)) ln(Ink, 50 + s * 24, y, 50 + s * 36, y + (y - 56) / 3 + 2, 3)
    curve(Ink, 2.5f) { m(46, 18); q(40, 10, 34, 10); m(54, 18); q(60, 10, 66, 10) }
    ov(Ink, 50, 25, 13, 10)
    ov(Cream, 44, 23, 2.4f); ov(Cream, 56, 23, 2.4f)
    ov(Palette.coral, 50, 58, 29, 29)
    ln(Ink, 50, 30, 50, 87, 3)
    for ((x, y) in listOf(39 to 44, 61 to 44, 34 to 61, 66 to 61, 42 to 76, 58 to 76)) ov(Ink, x, y, 5)
}

private fun DrawScope.dragonfly() {
    for ((y, deg) in listOf(34 to -8, 46 to 8)) for (s in listOf(-1, 1)) {
        val cx = 50 + s * 22
        tilt(deg * s, cx, y) { ov(Palette.trail, cx, y, 22, 6); drawOval(Palette.sky, Offset(cx - 22f, y - 6f), Size(44f, 12f), style = Stroke(1.5f)) }
    }
    ln(Palette.sky, 50, 44, 50, 92, 6)
    for (y in listOf(56, 66, 76, 86)) ln(Palette.trail, 47, y, 53, y, 1.6f)
    ov(Palette.sky, 50, 38, 6, 9)
    ov(Palette.mint, 44, 24, 6.5f); ov(Palette.mint, 56, 24, 6.5f)
    eye(44, 24, 2.4f); eye(56, 24, 2.4f)
}

private fun DrawScope.grasshopper() {
    val leg = Palette.mintInk
    ln(leg, 42, 62, 34, 80, 3)
    for ((x0, x1) in listOf(60 to 58, 66 to 70, 72 to 80)) ln(leg, x0, 60, x1, 78, 3)
    ln(Palette.mint, 18, 58, 70, 54, 15)
    ln(Palette.mintInk, 24, 52, 62, 48, 2.5f)
    ln(Palette.mint, 40, 56, 60, 34, 9)
    ln(leg, 60, 34, 38, 82, 3.5f)
    ln(leg, 38, 82, 30, 82, 3)
    ov(Palette.mint, 77, 52, 10, 11)
    curve(leg, 2) { m(78, 43); q(82, 26, 94, 18); m(82, 44); q(90, 32, 96, 30) }
    eye(80, 49, 3)
    curve(Ink, 2) { m(82, 58); q(85, 59, 87, 57) }
}

private fun DrawScope.earthworm() {
    rr(Brown, 6, 74, 88, 20, 8)
    for ((x, y) in listOf(16 to 84, 34 to 88, 60 to 86, 80 to 84, 48 to 80)) ov(Chestnut, x, y, 2.5f)
    curve(Pink, 11) { m(14, 72); cu(22, 44, 38, 42, 46, 58); cu(54, 74, 70, 72, 74, 50); q(76, 38, 84, 36) }
    curve(PinkDeep, 11) { m(52, 67); l(55, 70.5f) }
    for ((x, y) in listOf(20 to 58, 30 to 50, 40 to 52, 64 to 68, 72 to 60)) ov(PinkDeep, x, y, 1.6f)
    eye(83, 34, 2); eye(88, 37, 2)
}

private fun DrawScope.cockroach() {
    for (s in listOf(-1, 1)) {
        curve(Brown, 3) { m(50 + s * 8, 34); l(50 + s * 22, 30); l(50 + s * 30, 18) }
        curve(Brown, 3) { m(50 + s * 10, 48); l(50 + s * 26, 50); l(50 + s * 36, 40) }
        curve(Brown, 3) { m(50 + s * 10, 60); l(50 + s * 26, 72); l(50 + s * 32, 90) }
        curve(Brown, 2) { m(50 + s * 3, 18); cu(50 + s * 8, 6, 50 + s * 24, 4, 50 + s * 40, 10) }
    }
    ov(Chestnut, 50, 60, 18, 30)
    ov(Brown, 50, 32, 15, 9)
    ov(Charcoal, 50, 22, 7, 5)
    ln(Brown, 50, 40, 50, 89, 2.5f)
    ov(Fawn, 42, 54, 3, 10); ov(Fawn, 58, 54, 3, 10)
}

private fun DrawScope.honeycomb() {
    val r = 12f
    val w = r * 1.732f
    val rows = listOf(3, 4, 3, 2)
    for ((ri, n) in rows.withIndex()) for (i in 0 until n) {
        val cx = 50 + (i - (n - 1) / 2f) * w
        val cy = 22 + ri * r * 1.5f
        val filled = (ri + i) % 3 != 2
        shape(if (filled) Palette.sunflower else Palette.sunflowerSoft) {
            for (k in 0 until 6) {
                val a = PI / 6 + k * PI / 3
                val x = cx + (r - 1.2f) * cos(a); val y = cy + (r - 1.2f) * sin(a)
                if (k == 0) m(x, y) else l(x, y)
            }
            close()
        }
    }
    shape(Palette.sunflower) { m(44, 84); l(56, 84); cu(56, 88, 54, 90, 54, 92); cu(54, 96, 46, 96, 46, 92); cu(46, 90, 44, 88, 44, 84); close() }
}

// ================= sea =================

private fun DrawScope.octopus() {
    val c = Palette.lavender
    for (i in 0 until 6) {
        val x0 = 30 + i * 8f
        val k = i - 2.5f
        val sg = if (k < 0) -1 else 1
        val ex = x0 + k * 5
        curve(c, 8) { m(x0, 50); q(x0 + k * 2, 70, ex, 80); q(ex + sg * 6, 88, ex + sg * 10, 80) }
    }
    ov(c, 50, 38, 25, 24)
    rr(c, 26, 38, 48, 18, 8)
    ov(Cream, 41, 40, 6); ov(Cream, 59, 40, 6)
    eye(42, 41, 3); eye(58, 41, 3)
    curve(Ink, 2.5f) { m(44, 50); q(50, 55, 56, 50) }
    ov(Pink, 34, 48, 3.5f, 2.5f); ov(Pink, 66, 48, 3.5f, 2.5f)
}

private fun DrawScope.starfish() {
    val p = Path().apply {
        for (i in 0 until 10) {
            val r = if (i % 2 == 0) 38.0 else 17.0
            val a = (-90.0 + i * 36.0) * PI / 180
            val x = 50 + r * cos(a); val y = 54 + r * sin(a)
            if (i == 0) m(x, y) else l(x, y)
        }
        close()
    }
    drawPath(p, Palette.coral)
    drawPath(p, Palette.coral, style = Stroke(8f, join = StrokeJoin.Round))
    for (i in 0 until 5) {
        val a = (-90.0 + i * 72.0) * PI / 180
        for (d in listOf(14, 24)) ov(Pink, 50 + d * cos(a), 54 + d * sin(a), if (d == 14) 2.6f else 2f)
    }
    ov(Pink, 50, 54, 3)
}

private fun DrawScope.jellyfish() {
    for (i in 0 until 5) {
        val x = 30 + i * 10f
        curve(PinkDeep, 3) { m(x, 50); q(x - 5, 60, x, 68); q(x + 5, 76, x, 84); q(x - 3, 89, x, 93) }
    }
    shape(Pink) {
        m(18, 52); cu(18, 14, 82, 14, 82, 52)
        q(76, 58, 69, 52); q(63, 58, 56, 52); q(50, 58, 44, 52); q(37, 58, 31, 52); q(24, 58, 18, 52); close()
    }
    ov(Cream, 34, 32, 4, 6)
    eye(42, 42, 3); eye(58, 42, 3)
    curve(Ink, 2.5f) { m(46, 48); q(50, 51, 54, 48) }
}

private fun DrawScope.dolphin() {
    shape(Palette.sky) { m(6, 84); q(20, 76, 34, 84); q(48, 92, 62, 84); q(76, 76, 94, 84); l(94, 94); l(6, 94); close() }
    ov(Palette.trail, 20, 72, 3); ov(Palette.trail, 80, 72, 3.5f)
    shape(Dolphin) { m(62, 30); q(56, 14, 44, 12); q(50, 22, 44, 34); close() }
    shape(Dolphin) {
        m(92, 44); cu(88, 34, 82, 26, 68, 26); cu(46, 24, 28, 36, 20, 58); l(27, 63)
        cu(36, 52, 54, 50, 72, 50); cu(82, 50, 88, 48, 92, 46); close()
    }
    poly(Dolphin, 25, 61, 8, 56, 16, 64, 12, 76)
    poly(Dolphin, 60, 46, 52, 58, 66, 47)
    eye(78, 36, 2.6f)
    curve(Ink, 2) { m(82, 44); q(87, 44, 91, 43) }
}

private fun DrawScope.whale() {
    curve(Palette.sky, 3.5f) { m(58, 36); l(58, 24); m(58, 26); q(52, 16, 44, 16); m(58, 26); q(64, 16, 72, 16) }
    ov(Palette.sky, 42, 15, 2.6f); ov(Palette.sky, 74, 15, 2.6f)
    shape(Palette.sky) { m(24, 62); q(14, 54, 12, 40); l(20, 46); close() }
    shape(Palette.sky) { m(12, 40); q(4, 36, 4, 28); q(10, 34, 14, 34); q(16, 26, 24, 24); q(20, 34, 20, 46); close() }
    ov(Palette.sky, 54, 60, 38, 22)
    inOval(54, 60, 38, 22) { ov(Palette.trail, 62, 80, 32, 10) }
    for (x in listOf(52, 62, 72)) ln(Palette.sky, x, 72, x + 1, 78, 2)
    eye(78, 56, 3)
    curve(Ink, 2.5f) { m(70, 66); q(80, 70, 90, 62) }
}

private fun DrawScope.shark() {
    poly(Grey, 44, 42, 54, 16, 62, 42)
    poly(Grey, 24, 50, 6, 28, 14, 51, 6, 72)
    shape(Grey) { m(94, 52); cu(82, 36, 50, 34, 20, 48); l(20, 54); cu(50, 68, 82, 66, 94, 52); close() }
    poly(Slate, 56, 58, 46, 74, 66, 59)
    for (x in listOf(64, 68, 72)) ln(Slate, x, 46, x - 1, 54, 2)
    eye(82, 46, 2.8f)
    curve(Ink, 2.5f) { m(74, 57); q(82, 60, 90, 55) }
    for (x in listOf(77, 81, 85)) poly(Cream, x, 58, x + 3, 58, x + 1.5f, 61.5f)
}

private fun DrawScope.seahorse() {
    val c = Palette.sunflower
    ov(Palette.sunflowerSoft, 68, 48, 6, 10)
    curve(c, 9) { m(57, 66); cu(62, 80, 56, 92, 46, 90); cu(38, 88, 40, 78, 48, 80) }
    shape(c) { m(48, 28); cu(34, 40, 36, 62, 52, 72); l(60, 70); cu(70, 58, 68, 36, 62, 22); close() }
    poly(c, 50, 15, 55, 5, 60, 15)
    ov(c, 55, 22, 10, 9)
    ln(c, 48, 25, 32, 30, 7)
    for (y in listOf(42, 50, 58)) ln(Orange, 41 + (y - 50) * (y - 50) / 40f, y, 48, y + 1, 2.5f)
    eye(56, 20, 2.8f)
}

private fun DrawScope.prawn() {
    curve(Palette.coral, 2) { m(70, 32); cu(86, 16, 76, 6, 48, 8); m(72, 36); cu(92, 26, 92, 12, 80, 8) }
    val segs = 9
    for (i in segs - 1 downTo 0) {
        val a = (-40.0 + i * 26.0) * PI / 180
        val x = 46 + 22 * cos(a); val y = 54 + 22 * sin(a)
        val r = 13f - i * 0.9f
        if (i in 1..6) ln(Palette.coral, x, y, x + 5 * cos(a), y + 14 * sin(a).coerceAtLeast(0.3), 2.5f)
        ov(Palette.coral, x, y, r); ring(PinkDeep, x, y, r, 1.6f)
    }
    val ta = (-40.0 + segs * 26.0) * PI / 180
    val tx = 46 + 22 * cos(ta); val ty = 54 + 22 * sin(ta)
    for (d in listOf(-30.0, 0.0, 30.0)) {
        val b = ta + PI / 2 + d * PI / 180
        ln(Palette.coral, tx, ty, tx + 12 * cos(b), ty + 12 * sin(b), 6)
    }
    ov(Palette.coral, 66, 36, 13)
    poly(Palette.coral, 74, 30, 92, 34, 76, 38)
    eye(70, 32, 3)
}
