package com.rakesh.boretube.learn.ui.level

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.ui.Gap
import com.rakesh.boretube.learn.ui.Palette
import com.rakesh.boretube.learn.ui.Radii
import com.rakesh.boretube.learn.ui.Text
import com.rakesh.boretube.learn.ui.Tubby
import com.rakesh.boretube.learn.ui.TubbyMood
import com.rakesh.boretube.learn.ui.TypeScale

/** What Tubby says after a right answer; [fact] marks a "Did you know?" card (it stays longer, OK moves on). */
data class CheerLine(val text: String, val fact: Boolean = false, val comeback: Boolean = false)

/** Tubby pops up beside the answer with a short line: praise with the fact, a comeback, or a "Did you know?". */
@Composable
fun CheerBubble(line: CheerLine, modifier: Modifier = Modifier) {
    val pop = remember(line) { Animatable(0.6f) }
    LaunchedEffect(line) { pop.animateTo(1f, spring(Spring.DampingRatioMediumBouncy, Spring.StiffnessMedium)) }
    val shape = RoundedCornerShape(Radii.r21)
    Row(
        modifier
            .graphicsLayer { scaleX = pop.value; scaleY = pop.value; alpha = (pop.value - 0.6f) / 0.4f }
            .testTag(if (line.fact) "did-you-know" else if (line.comeback) "comeback" else "cheer"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Gap.f13),
    ) {
        Column(
            Modifier
                .widthIn(max = 360.dp)
                .clip(shape)
                .background(if (line.fact) Palette.sunflowerSoft else Palette.card)
                .border(2.dp, if (line.comeback) Palette.mint else Palette.hairline, shape)
                .padding(horizontal = Gap.f21, vertical = Gap.f13),
            verticalArrangement = Arrangement.spacedBy(Gap.f4),
        ) {
            if (line.fact) BasicText("Did you know?", style = Text.body(TypeScale.s18, FontWeight.Bold).copy(color = Palette.coralInk))
            BasicText(line.text, style = if (line.fact) Text.body(TypeScale.s21, FontWeight.SemiBold) else Text.display(TypeScale.s21), maxLines = 4)
            if (line.fact) BasicText("OK to go on", style = Text.muted())
        }
        Tubby(TubbyMood.cheer, Modifier.width(89.dp))
    }
}
