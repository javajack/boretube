package com.rakesh.boretube.learn.ui

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.drawOutline
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.translate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.semantics.SemanticsPropertyKey
import androidx.compose.ui.semantics.SemanticsPropertyReceiver
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp

/** Set by [focusRing]: whether this item shows the focus ring (tests, accessibility). */
val FocusedKey = SemanticsPropertyKey<Boolean>("BtFocused")
var SemanticsPropertyReceiver.btFocused by FocusedKey

/**
 * The same ring, driven by screen state (screens keep one "selected" index and
 * take the remote keys themselves, see [remote]).
 */
fun Modifier.selectedRing(
    selected: Boolean,
    shape: Shape,
    primary: Boolean = false,
    scale: Float = 1.04f,
    gap: androidx.compose.ui.graphics.Color = Palette.canvas,
): Modifier = composed {
    val s by animateFloatAsState(if (selected) scale else 1f, tween(Motion.press), label = "select")
    this
        .semantics { btFocused = selected }
        .graphicsLayer { scaleX = s; scaleY = s }
        .drawWithContent {
            drawContent()
            if (selected) rings(shape, primary, gap)
        }
}

private fun androidx.compose.ui.graphics.drawscope.ContentDrawScope.rings(
    shape: Shape,
    primary: Boolean,
    gap: androidx.compose.ui.graphics.Color,
) {
    val ring = 5.dp.toPx()
    for ((i, color) in listOf(gap, if (primary) Palette.coral else Palette.ink).withIndex()) {
        val grow = ring * (i + 0.5f) * 2f
        val outline = shape.createOutline(Size(size.width + grow, size.height + grow), layoutDirection, this)
        translate(-grow / 2f, -grow / 2f) {
            drawOutline(outline, color, style = Stroke(width = ring))
        }
    }
}

/**
 * The one focus look (spec §5): the focused item grows to [scale] over
 * [Motion.press] ms and gets two rings outside its [shape]: a 5 dp gap in the
 * canvas colour, then a 5 dp ink ring (coral for the screen's primary).
 * Put it before `.focusable()` / `.clickable()` in the chain.
 */
fun Modifier.focusRing(
    shape: Shape,
    primary: Boolean = false,
    scale: Float = 1.04f,
    gap: androidx.compose.ui.graphics.Color = Palette.canvas,
): Modifier = composed {
    var focused by remember { mutableStateOf(false) }
    val s by animateFloatAsState(if (focused) scale else 1f, tween(Motion.press), label = "focus")
    this
        .onFocusChanged { focused = it.isFocused || it.hasFocus }
        .semantics { btFocused = focused }
        .graphicsLayer { scaleX = s; scaleY = s }
        .drawWithContent {
            drawContent()
            if (focused) rings(shape, primary, gap)
        }
}
