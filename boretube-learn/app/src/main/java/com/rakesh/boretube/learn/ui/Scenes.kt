package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipRect
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.text.TextMeasurer
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.sp
import com.rakesh.boretube.learn.world.LandId

/**
 * The little picture at the top of each land card (mock artboard 1), drawn on
 * a 340×250 grid and scaled to fill. Flat shapes from the palette only.
 */
@Composable
fun LandScene(land: LandId, modifier: Modifier = Modifier) {
    val text = rememberTextMeasurer()
    Canvas(modifier) {
        val k = maxOf(size.width / 340f, size.height / 250f)
        clipRect {
            scale(k, k, pivot = Offset.Zero) {
                when (land) {
                    LandId.bazaar -> bazaar(text)
                    LandId.garden -> garden(text)
                    LandId.trail -> trail()
                }
            }
        }
    }
}

private fun DrawScope.kite(cx: Float, top: Float, w: Float, color: Color) {
    val p = Path().apply { moveTo(cx, top); lineTo(cx + w, top + w * 1.2f); lineTo(cx, top + w * 2.4f); lineTo(cx - w, top + w * 1.2f); close() }
    drawPath(p, color)
    val tail = Path().apply { moveTo(cx, top + w * 2.4f); quadraticBezierTo(cx - 6f, top + w * 4f, cx + 10f, top + w * 5.4f) }
    drawPath(tail, Palette.ink, style = Stroke(2f))
}

private fun DrawScope.stall(x: Float, y: Float, w: Float, h: Float, awning: Color, label: String, text: TextMeasurer) {
    drawRect(Palette.cream, Offset(x, y), Size(w, h))
    val roof = Path().apply { moveTo(x - 8f, y); lineTo(x + w + 8f, y); lineTo(x + w - 4f, y - 30f); lineTo(x + 4f, y - 30f); close() }
    drawPath(roof, awning)
    var sx = x + 14f
    while (sx < x + w) { drawLine(Palette.cream, Offset(sx, y - 30f), Offset(sx, y), 8f); sx += 22f }
    val t = text.measure(label, Text.display(40.sp))
    drawText(t, topLeft = Offset(x + (w - t.size.width) / 2f, y + (h - t.size.height) / 2f))
}

private fun DrawScope.bazaar(text: TextMeasurer) {
    drawRect(Palette.sunflowerSoft, size = Size(340f, 250f))
    kite(78f, 18f, 18f, Palette.coral)
    kite(264f, 12f, 14f, Palette.sky)
    stall(30f, 150f, 120f, 100f, Palette.coral, "7×8", text)
    stall(190f, 160f, 120f, 90f, Palette.mint, "½", text)
}

private fun DrawScope.flower(cx: Float, cy: Float, r: Float, petal: Color, heart: Color, stem: Float) {
    drawLine(Palette.mintInk, Offset(cx, cy + r), Offset(cx, cy + r + stem), 5f)
    drawCircle(petal, r, Offset(cx, cy))
    drawCircle(heart, r * 0.4f, Offset(cx, cy))
}

private fun DrawScope.bird(x: Float, y: Float) {
    val p = Path().apply { moveTo(x, y); quadraticBezierTo(x + 10f, y - 10f, x + 20f, y); quadraticBezierTo(x + 30f, y - 10f, x + 40f, y) }
    drawPath(p, Palette.ink, style = Stroke(3f, cap = StrokeCap.Round))
}

private fun DrawScope.garden(text: TextMeasurer) {
    drawRect(Color(0xFFA8E3C9), size = Size(340f, 250f))
    drawPath(Path().apply { moveTo(0f, 200f); quadraticBezierTo(170f, 160f, 340f, 200f); lineTo(340f, 250f); lineTo(0f, 250f); close() }, Palette.mint)
    flower(70f, 150f, 22f, Palette.coral, Palette.sunflower, 40f)
    flower(170f, 130f, 26f, Palette.lavender, Palette.cream, 50f)
    flower(270f, 155f, 20f, Palette.sunflower, Palette.coral, 35f)
    bird(120f, 60f)
    bird(220f, 40f)
    val t = text.measure("Aa", Text.display(34.sp).copy(color = Palette.mintInk))
    drawText(t, topLeft = Offset(44f, 24f))
}

private fun DrawScope.trail() {
    drawRect(Color(0xFFB7D6FF), size = Size(340f, 250f))
    drawCircle(Palette.sunflower, 26f, Offset(280f, 50f))
    drawPath(Path().apply { moveTo(0f, 180f); quadraticBezierTo(90f, 140f, 170f, 180f); quadraticBezierTo(250f, 220f, 340f, 170f); lineTo(340f, 250f); lineTo(0f, 250f); close() }, Palette.mint)
    drawPath(Path().apply { moveTo(0f, 220f); quadraticBezierTo(120f, 200f, 200f, 225f); quadraticBezierTo(280f, 250f, 340f, 215f); lineTo(340f, 250f); lineTo(0f, 250f); close() }, Palette.sky)
    drawRect(Palette.sunflowerInk, Offset(66f, 110f), Size(12f, 60f))
    drawCircle(Palette.mintInk, 34f, Offset(72f, 100f))
    // A calf by the river.
    drawOval(Palette.cream, Offset(170f, 149f), Size(60f, 32f))
    drawCircle(Palette.cream, 10f, Offset(226f, 152f))
    drawCircle(Palette.ink, 2.5f, Offset(229f, 150f))
    drawLine(Palette.cream, Offset(186f, 178f), Offset(186f, 188f), 5f, StrokeCap.Round)
    drawLine(Palette.cream, Offset(212f, 178f), Offset(212f, 188f), 5f, StrokeCap.Round)
}
