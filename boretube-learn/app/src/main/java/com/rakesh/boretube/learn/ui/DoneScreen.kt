package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.core.LevelResult
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds
import kotlinx.coroutines.delay

/**
 * Level done (mock artboard 3): Tubby cheers, the stars count in one by one,
 * a sticker if the skill was just mastered, the fact to practise, then
 * **Play another** (default) or **Back to town**.
 */
@Composable
fun DoneScreen(
    result: LevelResult,
    skillTitle: String,
    sounds: Sounds,
    onAnother: () -> Unit,
    onTown: () -> Unit,
    /** A perfect level sometimes earns a golden star: a surprise, never a goal. */
    golden: Boolean = result.total > 0 && result.right == result.total && result.state.plays.values.sum() % 3 == 0,
) {
    var shown by remember { mutableIntStateOf(0) }
    var gold by remember { mutableStateOf(false) }
    var sel by remember { mutableIntStateOf(0) }
    LaunchedEffect(result) {
        // A held breath before the first star lands.
        delay(STAR_GAP_MS + 260)
        for (n in 1..result.stars) {
            shown = n
            sounds.play(Sfx.star(n))
            delay(STAR_GAP_MS)
        }
        if (golden) {
            delay(180)
            gold = true
            sounds.play(Sfx.star_gold)
            delay(STAR_GAP_MS)
        }
        sounds.play(Sfx.level_done_bazaar)
    }
    Row(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .remote(Unit) { key ->
                when (key) {
                    RemoteKey.Left, RemoteKey.Right -> { sel = 1 - sel; sounds.tick(Sfx.focus_bazaar) }
                    RemoteKey.Ok -> { sounds.play(Sfx.select); if (sel == 0) onAnother() else onTown() }
                    RemoteKey.Back -> { sounds.play(Sfx.back); onTown() }
                    else -> return@remote false
                }
                true
            }
            .padding(horizontal = Safe.x, vertical = Safe.y),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Gap.f89),
    ) {
        Column(Modifier.weight(0.382f), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Gap.f21)) {
            Tubby(TubbyMood.cheer, Modifier.width(233.dp))
            BasicText("Level done!", style = Text.display(TypeScale.s55))
            Box(contentAlignment = Alignment.Center) {
                PoppingStars(shown, 3, size = 72.dp)
                if (shown > 0) com.rakesh.boretube.learn.ui.level.Burst(shown, Modifier.size(260.dp, 80.dp), reach = 55.dp)
            }
            if (gold) GoldStar()
            BasicText("${result.right} of ${result.total} right · $skillTitle", style = Text.muted(), maxLines = 1)
        }
        Column(Modifier.weight(0.618f), verticalArrangement = Arrangement.spacedBy(Gap.f34)) {
            if (result.newlyMastered) {
                Row(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Radii.r34))
                        .background(Palette.card)
                        .border(1.dp, Palette.hairline, RoundedCornerShape(Radii.r34))
                        .padding(Gap.f34)
                        .testTag("sticker"),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Gap.f34),
                ) {
                    PeacockSticker(Modifier.size(144.dp))
                    Column(verticalArrangement = Arrangement.spacedBy(Gap.f8)) {
                        BasicText("New sticker", style = Text.muted())
                        BasicText("Peacock", style = Text.display(TypeScale.s43))
                        BasicText("For mastering $skillTitle.", style = Text.body(TypeScale.s21))
                    }
                }
            }
            result.toPractise?.let { q ->
                BasicText("One to practise: ${q.fact}. It comes back in a later level.", style = Text.muted())
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Gap.f34)) {
                DoneButton("Play another", sel == 0, primary = true, Modifier.weight(1f).testTag("done-another"))
                DoneButton("Back to town", sel == 1, primary = false, Modifier.weight(1f).testTag("done-town"))
            }
        }
    }
}

@Composable
private fun DoneButton(label: String, selected: Boolean, primary: Boolean, modifier: Modifier) {
    val shape = RoundedCornerShape(Radii.r21)
    Box(
        modifier
            .height(89.dp)
            .selectedRing(selected, shape, primary = primary)
            .clip(shape)
            .background(if (selected) Palette.ink else Palette.card)
            .border(1.dp, if (selected) Palette.ink else Palette.hairline, shape)
            .padding(horizontal = Gap.f21),
        contentAlignment = Alignment.Center,
    ) { BasicText(label, style = Text.display(TypeScale.s34).copy(color = if (selected) Palette.cream else Palette.ink), maxLines = 1) }
}

private const val STAR_GAP_MS = 320L

/** Stars that land one by one with a bounce (the empty ones wait as outlines). */
@Composable
private fun PoppingStars(filled: Int, total: Int, size: androidx.compose.ui.unit.Dp) {
    Row(horizontalArrangement = Arrangement.spacedBy(size / 6)) {
        repeat(total) { i ->
            val on = i < filled
            val s by androidx.compose.animation.core.animateFloatAsState(
                if (on) 1f else 0.82f,
                androidx.compose.animation.core.spring(androidx.compose.animation.core.Spring.DampingRatioHighBouncy, androidx.compose.animation.core.Spring.StiffnessMedium),
                label = "star",
            )
            Star(on, Modifier.size(size).graphicsLayer { scaleX = s; scaleY = s; rotationZ = if (on) 0f else -12f }.testTag(if (on) "star-full" else "star-empty"))
        }
    }
}

/** The rare golden star: a ribbon under the three. */
@Composable
private fun GoldStar() {
    val inn = remember { androidx.compose.animation.core.Animatable(0f) }
    LaunchedEffect(Unit) { inn.animateTo(1f, androidx.compose.animation.core.spring(androidx.compose.animation.core.Spring.DampingRatioMediumBouncy)) }
    Row(
        Modifier
            .graphicsLayer { scaleX = inn.value; scaleY = inn.value }
            .clip(RoundedCornerShape(Radii.r21))
            .background(Palette.ink)
            .padding(horizontal = Gap.f21, vertical = Gap.f8)
            .testTag("gold-star"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Gap.f8),
    ) {
        Star(true, Modifier.size(34.dp))
        BasicText("Golden star: every one right!", style = Text.body(TypeScale.s21, androidx.compose.ui.text.font.FontWeight.Bold).copy(color = Palette.sunflowerSoft))
    }
}
