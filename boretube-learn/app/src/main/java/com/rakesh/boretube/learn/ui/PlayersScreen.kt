package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.data.Player
import com.rakesh.boretube.learn.data.PlayersRepo
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds

/**
 * Who's playing: every child on this TV as an avatar with their class and
 * stars, then "New player". ◀ ▶ choose, OK plays as them, Back stays.
 */
@Composable
fun WhoScreen(
    players: List<Player>,
    activeId: String?,
    stars: (String) -> Int,
    sounds: Sounds,
    onPick: (String) -> Unit,
    onNew: () -> Unit,
    onBack: () -> Unit,
) {
    val canAdd = players.size < PlayersRepo.MAX
    val count = players.size + if (canAdd) 1 else 0
    var sel by remember { mutableIntStateOf(players.indexOfFirst { it.id == activeId }.coerceAtLeast(0)) }
    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .remote(Unit) { key ->
                when (key) {
                    RemoteKey.Left, RemoteKey.Right -> {
                        val n = (sel + if (key == RemoteKey.Left) -1 else 1).coerceIn(0, count - 1)
                        if (n != sel) { sel = n; sounds.tick(Sfx.focus_bazaar) }
                    }
                    RemoteKey.Ok -> { sounds.play(Sfx.select); if (sel < players.size) onPick(players[sel].id) else onNew() }
                    RemoteKey.Back -> { sounds.play(Sfx.back); onBack() }
                    else -> return@remote false
                }
                true
            }
            .padding(horizontal = Safe.x, vertical = Safe.y)
            .testTag("who-screen"),
        verticalArrangement = Arrangement.spacedBy(Gap.f55, Alignment.CenterVertically),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Tubby(TubbyMood.cheer, Modifier.width(89.dp))
            Column(Modifier.padding(start = Gap.f34)) {
                BasicText("Hello again!", style = Text.muted(TypeScale.s26))
                BasicText("Who's playing?", style = Text.display(TypeScale.s55))
            }
        }
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Gap.f34, Alignment.CenterHorizontally)) {
            players.forEachIndexed { i, p ->
                PlayerTile(i == sel, Modifier.testTag("player-${p.id}")) {
                    Box(Modifier.size(110.dp).clip(CircleShape).background(if (p.id == activeId) Palette.sunflowerSoft else Palette.cream), contentAlignment = Alignment.Center) {
                        PictureArt(p.pic, Modifier.size(84.dp))
                    }
                    BasicText(gradeName(p.grade), style = Text.display(TypeScale.s26))
                    val st = stars(p.id)
                    BasicText(if (st > 0) "$st stars" else "Just starting", style = Text.muted(TypeScale.s18))
                }
            }
            if (canAdd) {
                PlayerTile(sel == players.size, Modifier.testTag("player-new")) {
                    Box(Modifier.size(110.dp).clip(CircleShape).background(Palette.cream), contentAlignment = Alignment.Center) {
                        Canvas(Modifier.size(44.dp)) {
                            val w = 6.dp.toPx()
                            drawLine(Palette.coral, Offset(size.width / 2, 0f), Offset(size.width / 2, size.height), w, StrokeCap.Round)
                            drawLine(Palette.coral, Offset(0f, size.height / 2), Offset(size.width, size.height / 2), w, StrokeCap.Round)
                        }
                    }
                    BasicText("New player", style = Text.display(TypeScale.s26))
                    BasicText("Pick an animal", style = Text.muted(TypeScale.s18))
                }
            }
        }
        BasicText("◀ ▶ choose · OK to play · Each player keeps their own stars", style = Text.muted())
    }
}

@Composable
private fun PlayerTile(selected: Boolean, modifier: Modifier, content: @Composable () -> Unit) {
    val shape = RoundedCornerShape(Radii.r34)
    Column(
        modifier
            .width(200.dp)
            .selectedRing(selected, shape, primary = true, scale = 1.06f)
            .clip(shape)
            .background(Palette.card)
            .border(1.dp, if (selected) Palette.ink else Palette.hairline, shape)
            .padding(vertical = Gap.f21),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(Gap.f8),
    ) { content() }
}

/** A new player's animal: two rows of six. Animals other players use are marked. */
@Composable
fun AvatarScreen(taken: Set<String>, sounds: Sounds, onPick: (String) -> Unit, onBack: () -> Unit) {
    val all = PlayersRepo.AVATARS
    var sel by remember { mutableIntStateOf(all.indexOfFirst { it !in taken }.coerceAtLeast(0)) }
    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .remote(Unit) { key ->
                when (key) {
                    RemoteKey.Left, RemoteKey.Right, RemoteKey.Up, RemoteKey.Down -> {
                        val d = when (key) { RemoteKey.Left -> -1; RemoteKey.Right -> 1; RemoteKey.Up -> -6; else -> 6 }
                        val n = sel + d
                        val sameRow = key == RemoteKey.Up || key == RemoteKey.Down || n / 6 == sel / 6
                        if (n in all.indices && sameRow) { sel = n; sounds.tick(Sfx.focus_bazaar) }
                    }
                    RemoteKey.Ok -> { sounds.play(Sfx.select); onPick(all[sel]) }
                    RemoteKey.Back -> { sounds.play(Sfx.back); onBack() }
                    else -> return@remote false
                }
                true
            }
            .padding(horizontal = Safe.x, vertical = Safe.y)
            .testTag("avatar-screen"),
        verticalArrangement = Arrangement.spacedBy(Gap.f34, Alignment.CenterVertically),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Tubby(TubbyMood.cheer, Modifier.width(89.dp))
            Column(Modifier.padding(start = Gap.f34)) {
                BasicText("A new player!", style = Text.muted(TypeScale.s26))
                BasicText("Pick your animal", style = Text.display(TypeScale.s55))
            }
        }
        for (row in all.chunked(6).withIndex()) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Gap.f21)) {
                row.value.forEachIndexed { k, pic ->
                    val i = row.index * 6 + k
                    val shape = RoundedCornerShape(Radii.r21)
                    Box(
                        Modifier
                            .weight(1f)
                            .height(144.dp)
                            .selectedRing(i == sel, shape, primary = true, scale = 1.06f)
                            .clip(shape)
                            .background(if (i == sel) Palette.sunflowerSoft else Palette.card)
                            .border(1.dp, Palette.hairline, shape)
                            .testTag("avatar-$pic"),
                        contentAlignment = Alignment.Center,
                    ) {
                        PictureArt(pic, Modifier.size(110.dp))
                        if (pic in taken) {
                            BasicText(
                                "taken",
                                modifier = Modifier.align(Alignment.BottomCenter).padding(Gap.f8).clip(RoundedCornerShape(Radii.r8)).background(Palette.ink).padding(horizontal = Gap.f8),
                                style = Text.body(TypeScale.s18, FontWeight.Bold).copy(color = Palette.cream),
                            )
                        }
                    }
                }
            }
        }
        BasicText("◀ ▶ ▲ ▼ choose · OK · Back to cancel", style = Text.muted())
    }
}

/** Change class: KG to Class 7 in two rows of four. The path and levels follow. */
@Composable
fun ClassScreen(current: Int, sounds: Sounds, onPick: (Int) -> Unit, onBack: () -> Unit) {
    var sel by remember { mutableIntStateOf(current.coerceIn(0, 7)) }
    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .remote(Unit) { key ->
                when (key) {
                    RemoteKey.Left, RemoteKey.Right, RemoteKey.Up, RemoteKey.Down -> {
                        val d = when (key) { RemoteKey.Left -> -1; RemoteKey.Right -> 1; RemoteKey.Up -> -4; else -> 4 }
                        val n = sel + d
                        if (n in 0..7 && !(key == RemoteKey.Right && sel == 3) && !(key == RemoteKey.Left && sel == 4)) { sel = n; sounds.tick(Sfx.focus_bazaar) }
                    }
                    RemoteKey.Ok -> { sounds.play(Sfx.select); onPick(sel) }
                    RemoteKey.Back -> { sounds.play(Sfx.back); onBack() }
                    else -> return@remote false
                }
                true
            }
            .padding(horizontal = Safe.x, vertical = Safe.y)
            .testTag("class-screen"),
        verticalArrangement = Arrangement.spacedBy(Gap.f34, Alignment.CenterVertically),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Tubby(TubbyMood.calm, Modifier.width(89.dp))
            Column(Modifier.padding(start = Gap.f34)) {
                BasicText("Now in ${gradeName(current)}", style = Text.muted(TypeScale.s26))
                BasicText("Which class?", style = Text.display(TypeScale.s55))
            }
        }
        for (row in listOf(0..3, 4..7)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Gap.f34)) {
                for (g in row) {
                    val shape = RoundedCornerShape(Radii.r21)
                    Column(
                        Modifier
                            .weight(1f)
                            .height(110.dp)
                            .selectedRing(g == sel, shape, primary = true, scale = 1.06f)
                            .clip(shape)
                            .background(if (g == sel) Palette.ink else Palette.card)
                            .border(1.dp, if (g == sel) Palette.ink else Palette.hairline, shape)
                            .testTag("class-$g"),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.Center,
                    ) {
                        BasicText(gradeName(g), style = Text.display(TypeScale.s34).copy(color = if (g == sel) Palette.cream else Palette.ink))
                        if (g == current) BasicText("now", style = Text.body(TypeScale.s18, FontWeight.Bold).copy(color = if (g == sel) Palette.sunflowerSoft else Palette.coralInk))
                    }
                }
            }
        }
        BasicText("Stars and skills already earned are kept.", style = Text.muted())
    }
}
