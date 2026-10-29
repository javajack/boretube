package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Fill
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.scale

enum class TubbyMood { calm, cheer, think, asleep }

/**
 * Tubby on a daylight ground: the TV Guard mascot (same 120×110 geometry as
 * the agent's `android/Tubby.kt`) with ink antennae and legs, so they read on
 * cream. Size it by width; the height follows.
 */
@Composable
fun Tubby(mood: TubbyMood, modifier: Modifier = Modifier) {
    Canvas(modifier.aspectRatio(120f / 110f)) {
        val k = size.width / 120f
        scale(k, k, pivot = Offset.Zero) { tubby(mood) }
    }
}

private fun DrawScope.tubby(mood: TubbyMood) {
    val thin = Stroke(width = 5f, cap = StrokeCap.Round)
    drawLine(Palette.ink, Offset(44f, 14f), Offset(34f, 2f), 5f, StrokeCap.Round)
    drawLine(Palette.ink, Offset(76f, 14f), Offset(86f, 2f), 5f, StrokeCap.Round)
    if (mood == TubbyMood.cheer) {
        drawLine(Palette.coral, Offset(8f, 52f), Offset(-6f, 34f), 7f, StrokeCap.Round)
        drawLine(Palette.coral, Offset(112f, 52f), Offset(126f, 34f), 7f, StrokeCap.Round)
    }
    val body = when (mood) {
        TubbyMood.calm -> Palette.sky
        TubbyMood.cheer -> Palette.coral
        TubbyMood.think, TubbyMood.asleep -> Palette.sunflower
    }
    drawRoundRect(body, Offset(6f, 14f), Size(108f, 80f), CornerRadius(26f))
    drawRoundRect(Palette.cream, Offset(18f, 25f), Size(84f, 58f), CornerRadius(18f))
    when (mood) {
        TubbyMood.calm -> {
            eyes()
            drawPath(Path().apply { moveTo(48f, 64f); quadraticBezierTo(60f, 74f, 72f, 64f) }, Palette.ink, style = thin)
            cheeks()
        }
        TubbyMood.cheer -> {
            val p = Path().apply {
                moveTo(38f, 52f); quadraticBezierTo(45f, 44f, 52f, 52f)
                moveTo(68f, 52f); quadraticBezierTo(75f, 44f, 82f, 52f)
            }
            drawPath(p, Palette.ink, style = thin)
            drawPath(Path().apply { moveTo(46f, 61f); quadraticBezierTo(60f, 80f, 74f, 61f); close() }, Palette.ink, style = Fill)
            cheeks()
        }
        TubbyMood.think -> {
            eyes()
            drawLine(Palette.ink, Offset(37f, 38f), Offset(52f, 35f), 4f, StrokeCap.Round)
            drawCircle(Palette.ink, 5f, Offset(64f, 67f), style = Stroke(4f))
        }
        TubbyMood.asleep -> {
            val p = Path().apply {
                moveTo(38f, 52f); quadraticBezierTo(45f, 58f, 52f, 52f)
                moveTo(68f, 52f); quadraticBezierTo(75f, 58f, 82f, 52f)
            }
            drawPath(p, Palette.ink, style = Stroke(4.5f, cap = StrokeCap.Round))
        }
    }
    drawRoundRect(Palette.ink, Offset(32f, 94f), Size(10f, 12f), CornerRadius(4f))
    drawRoundRect(Palette.ink, Offset(78f, 94f), Size(10f, 12f), CornerRadius(4f))
}

private fun DrawScope.eyes() {
    drawCircle(Palette.ink, 6f, Offset(45f, 50f))
    drawCircle(Palette.ink, 6f, Offset(75f, 50f))
}

private fun DrawScope.cheeks() {
    drawCircle(Palette.coral.copy(alpha = 0.55f), 5f, Offset(33f, 64f))
    drawCircle(Palette.coral.copy(alpha = 0.55f), 5f, Offset(87f, 64f))
}
