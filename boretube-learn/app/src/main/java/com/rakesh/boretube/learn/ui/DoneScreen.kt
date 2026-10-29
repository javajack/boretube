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
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
fun DoneScreen(result: LevelResult, skillTitle: String, sounds: Sounds, onAnother: () -> Unit, onTown: () -> Unit) {
    var shown by remember { mutableIntStateOf(0) }
    var sel by remember { mutableIntStateOf(0) }
    LaunchedEffect(result) {
        for (n in 1..result.stars) {
            delay(STAR_GAP_MS)
            shown = n
            sounds.play(Sfx.star(n))
        }
        delay(STAR_GAP_MS)
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
            StarRow(shown, 3, size = 72.dp)
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
