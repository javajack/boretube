package com.rakesh.boretube.learn.ui.level

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.rakesh.boretube.learn.core.Visual
import com.rakesh.boretube.learn.ui.Gap
import com.rakesh.boretube.learn.ui.Palette
import com.rakesh.boretube.learn.ui.Text
import com.rakesh.boretube.learn.ui.TypeScale
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/** A question's picture (the same geometry as brain breaks, on daylight). */
@Composable
fun QuestionVisual(v: Visual, modifier: Modifier = Modifier, numbered: Boolean = false) {
    when (v) {
        is Visual.Objects -> Mangoes(v.count, modifier, numbered)
        is Visual.Clock -> ClockFace(v.hour, v.minute, modifier.aspectRatio(1f))
        is Visual.Dots -> DotGrid(v, modifier)
        is Visual.Picture -> com.rakesh.boretube.learn.ui.PictureArt(v.id, modifier)
        is Visual.Pies -> Row(modifier, horizontalArrangement = Arrangement.spacedBy(Gap.f34), verticalAlignment = Alignment.CenterVertically) {
            for ((a, b) in v.fractions) {
                Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Gap.f13)) {
                    Pie(a, b, Modifier.size(160.dp))
                    BasicText("$a/$b", style = Text.display(TypeScale.s34))
                }
            }
        }
    }
}

private val LEAF = Path().apply { moveTo(40f, 16f); cubicTo(40f, 8f, 46f, 4f, 54f, 4f); cubicTo(50f, 10f, 46f, 14f, 40f, 16f); close() }
private val MANGO = Path().apply {
    moveTo(40f, 14f); cubicTo(62f, 14f, 74f, 34f, 72f, 54f); cubicTo(70f, 76f, 52f, 86f, 36f, 84f)
    cubicTo(18f, 82f, 8f, 66f, 10f, 48f); cubicTo(12f, 28f, 24f, 14f, 40f, 14f); close()
}
private val SHINE = Path().apply { moveTo(24f, 36f); cubicTo(28f, 28f, 34f, 24f, 40f, 24f) }

@Composable
fun Mangoes(n: Int, modifier: Modifier = Modifier, numbered: Boolean = false) {
    val perRow = if (n <= 5) n else (n + 1) / 2
    val rows = if (n <= 5) listOf(n) else listOf(perRow, n - perRow)
    var k = 0
    Column(modifier, verticalArrangement = Arrangement.spacedBy(Gap.f13), horizontalAlignment = Alignment.CenterHorizontally) {
        for (count in rows) {
            Row(horizontalArrangement = Arrangement.spacedBy(Gap.f21)) {
                repeat(count) { Mango(if (numbered) ++k else null, Modifier.width(if (n <= 5) 96.dp else 72.dp)) }
            }
        }
    }
}

@Composable
private fun Mango(label: Int?, modifier: Modifier) {
    val text = rememberTextMeasurer()
    Canvas(modifier.aspectRatio(80f / 90f)) {
        val k = size.width / 80f
        scale(k, k, pivot = Offset.Zero) {
            drawPath(LEAF, Palette.mint)
            drawPath(MANGO, Palette.sunflower)
            drawPath(SHINE, Palette.sunflowerSoft, style = Stroke(5f, cap = StrokeCap.Round))
        }
        if (label != null) {
            val t = text.measure("$label", Text.display(20.sp))
            drawText(t, topLeft = Offset((size.width - t.size.width) / 2f, size.height * 0.5f))
        }
    }
}

@Composable
fun ClockFace(hour: Int, minute: Int, modifier: Modifier = Modifier) {
    val text = rememberTextMeasurer()
    Canvas(modifier) {
        val r = size.minDimension / 2f
        val c = Offset(size.width / 2f, size.height / 2f)
        drawCircle(Palette.card, r, c)
        drawCircle(Palette.hairline, r, c, style = Stroke(3.dp.toPx()))
        for (i in 0 until 12) {
            if (i % 3 == 0) continue
            val a = Math.toRadians(i * 30.0)
            drawCircle(Palette.ink, r * 0.025f, Offset(c.x + (r * 0.88f) * sin(a).toFloat(), c.y - (r * 0.88f) * cos(a).toFloat()))
        }
        for (i in listOf(12, 3, 6, 9)) {
            val a = Math.toRadians(i * 30.0)
            val t = text.measure("$i", Text.display((r * 0.17f / density).sp))
            val p = Offset(c.x + (r * 0.74f) * sin(a).toFloat(), c.y - (r * 0.74f) * cos(a).toFloat())
            drawText(t, topLeft = Offset(p.x - t.size.width / 2f, p.y - t.size.height / 2f))
        }
        val ha = Math.toRadians((hour % 12) * 30.0 + minute * 0.5)
        val ma = Math.toRadians(minute * 6.0)
        drawLine(Palette.ink, c, Offset(c.x + r * 0.42f * sin(ha).toFloat(), c.y - r * 0.42f * cos(ha).toFloat()), r * 0.07f, StrokeCap.Round)
        drawLine(Palette.coral, c, Offset(c.x + r * 0.6f * sin(ma).toFloat(), c.y - r * 0.6f * cos(ma).toFloat()), r * 0.045f, StrokeCap.Round)
        drawCircle(Palette.ink, r * 0.05f, c)
    }
}

@Composable
fun Pie(num: Int, den: Int, modifier: Modifier = Modifier, empty: Color = Palette.hairline, line: Color = Palette.card) {
    Canvas(modifier) {
        val r = size.minDimension / 2f
        val c = Offset(size.width / 2f, size.height / 2f)
        drawCircle(empty, r, c)
        drawArc(Palette.coral, -90f, 360f * num / den, true, Offset(c.x - r, c.y - r), Size(2 * r, 2 * r))
        for (i in 0 until den) {
            val a = Math.toRadians(-90.0 + 360.0 * i / den)
            drawLine(line, c, Offset(c.x + r * cos(a).toFloat(), c.y + r * sin(a).toFloat()), 3.dp.toPx())
        }
    }
}

@Composable
fun DotGrid(v: Visual.Dots, modifier: Modifier = Modifier, maxCell: Dp = 34.dp) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Gap.f13)) {
        Canvas(Modifier.width(maxCell * v.cols).aspectRatio(v.cols.toFloat() / v.rows)) {
            val cell = min(size.width / v.cols, size.height / v.rows)
            for (r in 0 until v.rows) for (col in 0 until v.cols) {
                drawCircle(
                    if (v.splitAt in 1..col) Palette.coral else Palette.sunflower,
                    cell * 0.36f,
                    Offset(col * cell + cell / 2f, r * cell + cell / 2f),
                )
            }
        }
        val caption = when {
            v.splitAt > 0 && v.splitAt * 2 == v.cols -> "${v.rows} rows of ${v.cols} · two halves of ${v.rows * v.splitAt}"
            v.rows == 1 -> "${v.splitAt} and ${v.cols - v.splitAt} more"
            else -> "${v.rows} rows of ${v.cols}"
        }
        BasicText(caption, style = Text.muted())
    }
}
