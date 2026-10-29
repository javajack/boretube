package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** [filled] of [total] stars, sunflower on a light ground; empty ones are outlines. */
@Composable
fun StarRow(filled: Int, total: Int = 3, size: Dp = 21.dp, modifier: Modifier = Modifier) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(size / 6)) {
        repeat(total) { i -> Star(i < filled, Modifier.size(size).testTag(if (i < filled) "star-full" else "star-empty")) }
    }
}

@Composable
fun Star(full: Boolean, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val k = size.width / 24f
        val pts = floatArrayOf(12f, 2.5f, 14.9f, 8.6f, 21.5f, 9.4f, 16.6f, 13.9f, 17.9f, 20.5f, 12f, 17.2f, 6.1f, 20.5f, 7.4f, 13.9f, 2.5f, 9.4f, 9.1f, 8.6f)
        val p = Path()
        for (i in pts.indices step 2) if (i == 0) p.moveTo(pts[i] * k, pts[i + 1] * k) else p.lineTo(pts[i] * k, pts[i + 1] * k)
        p.close()
        if (full) drawPath(p, Palette.sunflower) else drawPath(p, Palette.outline, style = Stroke(1.6f * k))
    }
}
