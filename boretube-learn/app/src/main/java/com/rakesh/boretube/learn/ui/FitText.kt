package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp

/**
 * Text that fits its box (a tile, a card, a ball, a path node): the largest
 * size from [style]'s down to [min] at which every word fits on one line
 * (words never break in the middle) and the whole fits in [maxLines] and
 * the box's height. In a [circle] it fits the circle's inscribed square, so
 * nothing touches the curve.
 */
@Composable
fun FitText(
    text: String,
    style: TextStyle,
    modifier: Modifier = Modifier,
    maxLines: Int = 2,
    min: TextUnit = 16.sp,
    circle: Boolean = false,
    align: TextAlign = TextAlign.Center,
    /**
     * Siblings that should share one size (the tiles of a row): each reports
     * the size it fits at, and all use the smallest, so a row reads evenly.
     */
    group: FitGroup? = null,
) {
    val measurer = rememberTextMeasurer()
    val density = LocalDensity.current
    BoxWithConstraints(modifier, contentAlignment = if (align == TextAlign.Start) Alignment.CenterStart else Alignment.Center) {
        val inset = if (circle) 0.7f else 1f
        val maxW = (if (constraints.hasBoundedWidth) constraints.maxWidth else Int.MAX_VALUE / 2).let { (it * inset).toInt() }
        val maxH = if (constraints.hasBoundedHeight) (constraints.maxHeight * inset).toInt() else Int.MAX_VALUE / 2
        val size = remember(text, maxW, maxH, style, maxLines) {
            val words = text.split(' ').filter { it.isNotEmpty() }
            var s = style.fontSize.value
            val floor = min.value.coerceAtMost(s)
            var chosen = floor
            while (s >= floor) {
                val st = style.copy(fontSize = s.sp, textAlign = align)
                val wordsFit = words.all { w -> measurer.measure(w, st, maxLines = 1, softWrap = false).size.width <= maxW }
                val all = measurer.measure(text, st, maxLines = maxLines, constraints = Constraints(maxWidth = maxW))
                if (wordsFit && !all.hasVisualOverflow && all.size.height <= maxH) { chosen = s; break }
                s *= 0.92f
            }
            chosen
        }
        val shared = if (group != null) {
            androidx.compose.runtime.DisposableEffect(group, text) {
                onDispose { group.sizes.remove(text) }
            }
            androidx.compose.runtime.SideEffect { group.sizes[text] = size }
            minOf(size, group.sizes.values.minOrNull() ?: size)
        } else size
        val wDp = with(density) { maxW.toDp() }
        BasicText(
            text,
            modifier = Modifier.widthIn(max = wDp),
            style = style.copy(fontSize = shared.sp, textAlign = align, lineHeight = (shared * 1.08f).sp),
            maxLines = maxLines,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

/** A row of [FitText]s that share one size. Remember one per question. */
class FitGroup {
    internal val sizes = androidx.compose.runtime.mutableStateMapOf<String, Float>()
}
