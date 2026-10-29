package com.rakesh.boretube.learn.ui.level

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.ui.Gap
import com.rakesh.boretube.learn.ui.Palette
import com.rakesh.boretube.learn.ui.Radii
import com.rakesh.boretube.learn.ui.Text
import com.rakesh.boretube.learn.ui.TypeScale
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/** Right answers in a row in this level (the combo flame reads it). */
val LocalCombo = compositionLocalOf { 0 }

/** Combos that light the flame and play [com.rakesh.boretube.learn.sound.Sfx.combo]. */
val COMBO_STEPS = setOf(3, 5, 8)

/** The flame's size class for a combo: none below 3, then it grows at 5 and 8. */
fun comboLevel(n: Int): Int = when {
    n >= 8 -> 3
    n >= 5 -> 2
    n >= 3 -> 1
    else -> 0
}

/** A small flame: sunflower inside coral, growing with [level] (1..3). */
@Composable
fun Flame(level: Int, modifier: Modifier = Modifier, color: Color = Palette.coral) {
    val grow by animateFloatAsState(0.7f + 0.15f * level, spring(Spring.DampingRatioMediumBouncy, Spring.StiffnessMediumLow), label = "flame")
    val flicker by rememberInfiniteTransition(label = "flicker").animateFloat(
        0f, 1f, infiniteRepeatable(tween(420, easing = LinearEasing), RepeatMode.Reverse), label = "flicker",
    )
    Canvas(modifier.graphicsLayer { scaleX = grow; scaleY = grow * (0.96f + 0.08f * flicker); transformOrigin = androidx.compose.ui.graphics.TransformOrigin(0.5f, 1f) }) {
        val w = size.width
        val h = size.height
        fun flame(scale: Float): Path = Path().apply {
            val cx = w / 2f
            val bw = w * 0.42f * scale
            val top = h * (1f - 0.95f * scale)
            moveTo(cx, top)
            cubicTo(cx + bw * 0.4f, h * 0.35f, cx + bw * 1.1f, h * 0.55f, cx + bw * 0.8f, h * 0.8f)
            cubicTo(cx + bw * 0.6f, h * 0.97f, cx - bw * 0.6f, h * 0.97f, cx - bw * 0.8f, h * 0.8f)
            cubicTo(cx - bw * 1.1f, h * 0.55f, cx - bw * 0.2f, h * 0.45f, cx, top)
            close()
        }
        drawPath(flame(1f), color)
        drawPath(flame(0.55f), Palette.sunflower)
    }
}

/** "🔥 5 in a row" without emoji: the flame and the count, beside the progress bar. */
@Composable
fun ComboChip(combo: Int, modifier: Modifier = Modifier) {
    val level = comboLevel(combo)
    if (level == 0) return
    val pop = remember { Animatable(0.6f) }
    LaunchedEffect(combo) {
        pop.snapTo(1.25f)
        pop.animateTo(1f, spring(Spring.DampingRatioMediumBouncy, Spring.StiffnessMedium))
    }
    Row(
        modifier
            .graphicsLayer { scaleX = pop.value; scaleY = pop.value }
            .clip(RoundedCornerShape(Radii.r21))
            .background(Palette.ink)
            .padding(start = Gap.f8, end = Gap.f13, top = Gap.f4, bottom = Gap.f4)
            .testTag("combo"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Gap.f4),
    ) {
        Flame(level, Modifier.size(26.dp))
        BasicText("$combo in a row", style = Text.body(TypeScale.s18, FontWeight.Bold).copy(color = Palette.cream))
    }
}

/**
 * A burst of sparks from the centre of whatever it sits over, once per
 * [trigger]: eight sunflower and mint dots fly out and fade.
 */
@Composable
fun Burst(trigger: Any, modifier: Modifier = Modifier, reach: Dp = 110.dp) {
    val t = remember(trigger) { Animatable(0f) }
    LaunchedEffect(trigger) { t.animateTo(1f, tween(620, easing = FastOutSlowInEasing)) }
    Canvas(modifier) {
        val p = t.value
        if (p <= 0f || p >= 1f) return@Canvas
        val c = Offset(size.width / 2f, size.height / 2f)
        val r = reach.toPx() * p
        for (i in 0 until 10) {
            val a = (i / 10f) * 2f * PI.toFloat() + 0.3f
            // Out from the tile's edge, on an ellipse the tile's shape.
            val o = c + Offset(cos(a) * (size.width / 2f + r), sin(a) * (size.height / 2f + r))
            val dot = if (i % 2 == 0) Palette.sunflower else Palette.mint
            drawCircle(dot.copy(alpha = 1f - p), radius = (9f * (1f - p * 0.6f)).dp.toPx(), center = o)
        }
    }
}

/** A soft no-no shake, once per [trigger] (a wrong pick, a misplaced tile). */
fun Modifier.shake(trigger: Any?): Modifier = composed {
    val x = remember { Animatable(0f) }
    LaunchedEffect(trigger) {
        if (trigger == null) return@LaunchedEffect
        for (d in listOf(14f, -11f, 8f, -5f, 2f, 0f)) x.animateTo(d, tween(55))
    }
    this.graphicsLayer { translationX = x.value.dp.toPx() }
}

/** A gentle in-and-out breath, for the one button waiting to be pressed. */
fun Modifier.breathe(on: Boolean): Modifier = composed {
    if (!on) return@composed this
    val s by rememberInfiniteTransition(label = "breathe").animateFloat(
        1f, 1.04f, infiniteRepeatable(tween(700, easing = FastOutSlowInEasing), RepeatMode.Reverse), label = "breathe",
    )
    this.graphicsLayer { scaleX = s; scaleY = s }
}
