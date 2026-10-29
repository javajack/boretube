package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Maths
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds
import com.rakesh.boretube.learn.world.LandId
import com.rakesh.boretube.learn.world.Lands
import kotlinx.coroutines.delay
import java.time.LocalTime

/** Tubby's Town: three lands side by side (mock artboard 1). ◀ ▶ choose, OK goes in. */
@Composable
fun TownScreen(
    state: LearnState,
    settings: LearnSettings,
    sounds: Sounds,
    hour: Int = LocalTime.now().hour,
    onBack: () -> Unit = {},
    onLand: (LandId) -> Unit,
) {
    var sel by remember { mutableIntStateOf(0) }
    var soon by remember { mutableStateOf<LandId?>(null) }
    LaunchedEffect(soon) {
        if (soon != null) { delay(2_400); soon = null }
    }
    val stars = state.stars.values.sum()
    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .remote(Unit) { key ->
                when (key) {
                    RemoteKey.Left, RemoteKey.Right -> {
                        val n = (sel + if (key == RemoteKey.Left) -1 else 1).coerceIn(0, Lands.all.lastIndex)
                        if (n != sel) { sel = n; sounds.tick(Lands.all[n].tick) }
                        true
                    }
                    RemoteKey.Ok -> {
                        val land = Lands.all[sel]
                        if (land.skills.isEmpty()) { sounds.play(Sfx.back); soon = land.id } else { sounds.play(Sfx.select); onLand(land.id) }
                        true
                    }
                    RemoteKey.Back -> { onBack(); true }
                    else -> false
                }
            }
            .padding(horizontal = Safe.x, vertical = Safe.y),
        verticalArrangement = Arrangement.spacedBy(Gap.f34),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Tubby(TubbyMood.calm, Modifier.width(66.dp))
            Spacer(Modifier.width(Gap.f21))
            Column(Modifier.weight(1f)) {
                BasicText("Tubby's Town", style = Text.display(TypeScale.s43))
                BasicText(greeting(hour), style = Text.muted())
            }
            if (stars > 0) {
                StarRow(1, 1, size = 26.dp)
                Spacer(Modifier.width(Gap.f8))
                BasicText("$stars ${if (stars == 1) "star" else "stars"}", style = Text.body(TypeScale.s21, FontWeight.SemiBold))
            }
        }
        Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(Gap.f34), verticalAlignment = Alignment.CenterVertically) {
            Lands.all.forEachIndexed { i, land ->
                val p = Lands.progress(state, land, settings.grade)
                val shape = RoundedCornerShape(Radii.r34)
                Column(
                    Modifier
                        .weight(1f)
                        .height(440.dp)
                        .testTag("land-${land.id}")
                        .selectedRing(i == sel, shape)
                        .clip(shape)
                        .background(land.tint),
                ) {
                    LandScene(land.id, Modifier.fillMaxWidth().height(250.dp))
                    Column(Modifier.padding(horizontal = Gap.f34, vertical = Gap.f21), verticalArrangement = Arrangement.spacedBy(Gap.f8)) {
                        BasicText(land.name, style = Text.display(TypeScale.s34))
                        if (land.skills.isEmpty()) {
                            BasicText(land.subject, style = Text.muted())
                            BasicText("New levels coming soon", style = Text.muted())
                        } else {
                            BasicText("${land.subject} · ${p.mastered} of ${p.total} skills", style = Text.muted())
                            p.next?.let { next ->
                                BasicText(
                                    "Next: ${Maths.skill(next)?.title ?: next}",
                                    style = Text.body(TypeScale.s21, FontWeight.Bold).copy(color = Palette.coralInk),
                                    maxLines = 1,
                                )
                            } ?: BasicText("Every skill mastered!", style = Text.body(TypeScale.s21, FontWeight.Bold).copy(color = Palette.mintInk))
                        }
                    }
                }
            }
        }
        Box(Modifier.height(26.dp)) {
            BasicText(
                if (soon != null) "Tubby is still building this land." else "◀ ▶ to choose a land · OK to go in",
                style = Text.muted(),
            )
        }
    }
}

fun greeting(hour: Int): String = when (hour) {
    in 5..11 -> "Good morning! Where shall we go?"
    in 12..16 -> "Good afternoon! Where shall we go?"
    else -> "Good evening! Where shall we go?"
}
