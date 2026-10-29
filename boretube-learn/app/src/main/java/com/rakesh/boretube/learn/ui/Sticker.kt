package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale

/** The P1 sticker (a peacock, the mock's art on a 120×120 grid). Each skill gets its own art in P2. */
@Composable
fun PeacockSticker(modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val k = size.minDimension / 120f
        scale(k, k, pivot = Offset.Zero) {
            drawCircle(Palette.garden, 56f, Offset(60f, 60f))
            drawOval(Palette.mint, Offset(48f, 12f), Size(24f, 56f))
            rotate(-35f, Offset(38f, 48f)) { drawOval(Palette.mint, Offset(27f, 23f), Size(22f, 50f)) }
            rotate(35f, Offset(82f, 48f)) { drawOval(Palette.mint, Offset(71f, 23f), Size(22f, 50f)) }
            drawCircle(Palette.sky, 6f, Offset(60f, 26f))
            drawCircle(Palette.sky, 5f, Offset(34f, 36f))
            drawCircle(Palette.sky, 5f, Offset(86f, 36f))
            drawOval(Palette.sky, Offset(46f, 60f), Size(28f, 40f))
            drawCircle(Palette.sky, 8f, Offset(60f, 58f))
            drawPath(Path().apply { moveTo(67f, 58f); lineTo(74f, 60f); lineTo(67f, 62f); close() }, Palette.sunflower)
            drawCircle(Palette.cream, 1.6f, Offset(62f, 56f))
        }
    }
}
