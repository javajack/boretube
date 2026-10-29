package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.requiredSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.dp

/**
 * Every screen is designed on a 1280×720 dp grid (the mocks). This frame
 * scales that grid to whatever the TV reports (the VU3 is about 960×540 dp),
 * letterboxing in [ground] if the aspect ratio differs.
 */
@Composable
fun DesignFrame(ground: Color = Palette.canvas, content: @Composable () -> Unit) {
    BoxWithConstraints(Modifier.fillMaxSize().background(ground), contentAlignment = Alignment.Center) {
        val outer = LocalDensity.current
        val pxW = with(outer) { maxWidth.toPx() }
        val pxH = with(outer) { maxHeight.toPx() }
        val k = minOf(pxW / DESIGN_W, pxH / DESIGN_H)
        CompositionLocalProvider(LocalDensity provides Density(k, fontScale = 1f)) {
            Box(Modifier.requiredSize(DESIGN_W.dp, DESIGN_H.dp)) { content() }
        }
    }
}

const val DESIGN_W = 1280f
const val DESIGN_H = 720f
