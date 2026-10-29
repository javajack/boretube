package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.background
import com.rakesh.boretube.learn.world.Discovery
import com.rakesh.boretube.learn.data.Player
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.border
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
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds
import com.rakesh.boretube.learn.world.LandId
import com.rakesh.boretube.learn.world.World
import kotlinx.coroutines.delay
import java.time.LocalTime

/**
 * Tubby's Town: three lands side by side (mock artboard 1). ◀ ▶ choose, OK
 * goes in. ▲ reaches who's playing and their class (several children can
 * share the TV); ▼ reaches "Today in Tubby's Town", three cards that bring
 * new and forgotten things back to the surface (spec P2b §8).
 */
@Composable
fun TownScreen(
    state: LearnState,
    settings: LearnSettings,
    sounds: Sounds,
    hour: Int = LocalTime.now().hour,
    world: World = World.MATHS,
    player: Player? = null,
    discoveries: List<Discovery> = emptyList(),
    onPlayers: (() -> Unit)? = null,
    onClass: (() -> Unit)? = null,
    onSettings: (() -> Unit)? = null,
    /** The sticker book (null: no button). */
    onStickers: (() -> Unit)? = null,
    /** Tubby's greeting (default: by the time of day). */
    hello: String = greeting(hour),
    onDiscover: (Discovery) -> Unit = {},
    onBack: () -> Unit = {},
    onLand: (LandId) -> Unit,
) {
    var sel by remember { mutableIntStateOf(0) }
    // −1 the header (who / class), 0 the lands, 1 today's cards.
    var row by remember { mutableIntStateOf(0) }
    var top by remember { mutableIntStateOf(0) }
    var card by remember { mutableIntStateOf(0) }
    var soon by remember { mutableStateOf<LandId?>(null) }
    LaunchedEffect(soon) {
        if (soon != null) { delay(2_400); soon = null }
    }
    val stars = state.stars.values.sum()
    val heads = listOfNotNull(onPlayers?.let { 0 }, onClass?.let { 1 }, onStickers?.let { 3 }, onSettings?.let { 2 })
    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .remote(row) { key ->
                when (key) {
                    RemoteKey.Up -> {
                        val n = if (row == 0 && heads.isEmpty()) 0 else (row - 1).coerceAtLeast(-1)
                        if (n != row) { row = n; if (row == -1) top = heads.first(); sounds.tick(Sfx.focus_bazaar) }
                        true
                    }
                    RemoteKey.Down -> {
                        val n = if (row == 0 && discoveries.isEmpty()) 0 else (row + 1).coerceAtMost(1)
                        if (n != row) { row = n; card = 0; sounds.tick(Sfx.focus_bazaar) }
                        true
                    }
                    RemoteKey.Left, RemoteKey.Right -> {
                        val d = if (key == RemoteKey.Left) -1 else 1
                        when (row) {
                            -1 -> { val n = (heads.indexOf(top) + d).coerceIn(0, heads.lastIndex); if (heads[n] != top) { top = heads[n]; sounds.tick(Sfx.focus_bazaar) } }
                            1 -> { val n = (card + d).coerceIn(0, discoveries.lastIndex); if (n != card) { card = n; sounds.tick(Sfx.focus_bazaar) } }
                            else -> { val n = (sel + d).coerceIn(0, world.lands.lastIndex); if (n != sel) { sel = n; sounds.tick(world.lands[n].tick) } }
                        }
                        true
                    }
                    RemoteKey.Ok -> {
                        when (row) {
                            -1 -> { sounds.play(Sfx.select); when (top) { 0 -> onPlayers?.invoke(); 1 -> onClass?.invoke(); 3 -> onStickers?.invoke(); else -> onSettings?.invoke() } }
                            1 -> discoveries.getOrNull(card)?.let { sounds.play(Sfx.select); onDiscover(it) }
                            else -> {
                                val land = world.lands[sel]
                                if (land.skills.isEmpty()) { sounds.play(Sfx.back); soon = land.id } else { sounds.play(Sfx.select); onLand(land.id) }
                            }
                        }
                        true
                    }
                    RemoteKey.Back -> { if (row != 0) { row = 0; sounds.play(Sfx.back) } else onBack(); true }
                    else -> false
                }
            }
            .padding(horizontal = Safe.x, vertical = Safe.y),
        verticalArrangement = Arrangement.spacedBy(Gap.f21),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Tubby(TubbyMood.calm, Modifier.width(66.dp))
            Spacer(Modifier.width(Gap.f21))
            Column(Modifier.weight(1f)) {
                BasicText("Tubby's Town", style = Text.display(TypeScale.s43))
                BasicText(hello, style = Text.muted(), maxLines = 1)
            }
            if (stars > 0) {
                StarRow(1, 1, size = 26.dp)
                Spacer(Modifier.width(Gap.f8))
                BasicText("$stars ${if (stars == 1) "star" else "stars"}", style = Text.body(TypeScale.s21, FontWeight.SemiBold))
                Spacer(Modifier.width(Gap.f34))
            }
            if (player != null && onPlayers != null) {
                HeaderChip(Modifier.testTag("who"), row == -1 && top == 0) {
                    Box(Modifier.size(44.dp).clip(CircleShape).background(Palette.cream), contentAlignment = Alignment.Center) { PictureArt(player.pic, Modifier.size(36.dp)) }
                    BasicText("Who's playing", style = Text.body(TypeScale.s18, FontWeight.Bold).copy(color = if (row == -1 && top == 0) Palette.cream else Palette.ink))
                }
                Spacer(Modifier.width(Gap.f13))
            }
            if (onClass != null) {
                HeaderChip(Modifier.testTag("class"), row == -1 && top == 1) {
                    BasicText(gradeName(settings.grade), style = Text.display(TypeScale.s21).copy(color = if (row == -1 && top == 1) Palette.cream else Palette.ink))
                    BasicText("change", style = Text.body(TypeScale.s18, FontWeight.SemiBold).copy(color = if (row == -1 && top == 1) Palette.sunflowerSoft else Palette.muted))
                }
            }
            if (onStickers != null) {
                Spacer(Modifier.width(Gap.f13))
                HeaderChip(Modifier.testTag("stickers"), row == -1 && top == 3) {
                    // The sticker book: a sticker icon, like the cog beside it.
                    PictureArt("giftbox", Modifier.size(34.dp).padding(start = Gap.f4))
                }
            }
            if (onSettings != null) {
                Spacer(Modifier.width(Gap.f13))
                HeaderChip(Modifier.testTag("settings"), row == -1 && top == 2) {
                    Gear(if (row == -1 && top == 2) Palette.cream else Palette.ink, Modifier.size(30.dp).padding(start = Gap.f4))
                }
            }
        }
        Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(Gap.f34), verticalAlignment = Alignment.CenterVertically) {
            world.lands.forEachIndexed { i, land ->
                val p = world.progress(state, land, settings.grade)
                val shape = RoundedCornerShape(Radii.r34)
                Column(
                    Modifier
                        .weight(1f)
                        .height(if (discoveries.isEmpty()) 440.dp else 360.dp)
                        .testTag("land-${land.id}")
                        .selectedRing(row == 0 && i == sel, shape)
                        .clip(shape)
                        .background(land.tint),
                ) {
                    LandScene(land.id, Modifier.fillMaxWidth().height(if (discoveries.isEmpty()) 250.dp else 190.dp))
                    Column(Modifier.padding(horizontal = Gap.f34, vertical = Gap.f21), verticalArrangement = Arrangement.spacedBy(Gap.f8)) {
                        BasicText(land.name, style = Text.display(TypeScale.s34))
                        if (land.skills.isEmpty()) {
                            BasicText(land.subject, style = Text.muted())
                            BasicText("New levels coming soon", style = Text.muted())
                        } else {
                            BasicText("${land.subject} · ${p.mastered} of ${p.total} skills", style = Text.muted(), maxLines = 1)
                            p.next?.let { next ->
                                BasicText(
                                    "Next: ${world.title(next)}",
                                    style = Text.body(TypeScale.s21, FontWeight.Bold).copy(color = Palette.coralInk),
                                    maxLines = 1,
                                )
                            } ?: BasicText("Every skill mastered!", style = Text.body(TypeScale.s21, FontWeight.Bold).copy(color = Palette.mintInk))
                        }
                    }
                }
            }
        }
        if (discoveries.isNotEmpty()) {
            Column(verticalArrangement = Arrangement.spacedBy(Gap.f8)) {
                BasicText("Today in Tubby's Town", style = Text.body(TypeScale.s21, FontWeight.Bold))
                Row(Modifier.fillMaxWidth().height(96.dp), horizontalArrangement = Arrangement.spacedBy(Gap.f34)) {
                    discoveries.forEachIndexed { i, d -> DiscoveryCard(d, world, row == 1 && i == card, Modifier.weight(1f).testTag("discover-$i")) }
                }
            }
        }
        Box(Modifier.height(26.dp)) {
            BasicText(
                when {
                    soon != null -> "Tubby is still building this land."
                    row == -1 -> "◀ ▶ choose · OK · ▼ back to the lands"
                    row == 1 -> "◀ ▶ choose · OK to play · ▲ back to the lands"
                    heads.isNotEmpty() && discoveries.isNotEmpty() -> "◀ ▶ choose a land · OK to go in · ▲ who's playing · ▼ today's ideas"
                    else -> "◀ ▶ to choose a land · OK to go in"
                },
                style = Text.muted(),
                maxLines = 1,
            )
        }
    }
}

/** A simple cog: a ring of teeth around a hole. */
@Composable
private fun Gear(color: androidx.compose.ui.graphics.Color, modifier: Modifier) {
    androidx.compose.foundation.Canvas(modifier) {
        val c = center
        val r = size.minDimension / 2f
        for (i in 0 until 8) {
            val a = Math.toRadians(i * 45.0)
            drawLine(color, c, androidx.compose.ui.geometry.Offset(c.x + r * kotlin.math.cos(a).toFloat(), c.y + r * kotlin.math.sin(a).toFloat()), r * 0.42f)
        }
        drawCircle(color, r * 0.72f, c)
        drawCircle(if (color == Palette.cream) Palette.ink else Palette.card, r * 0.3f, c)
    }
}

@Composable
private fun HeaderChip(modifier: Modifier, selected: Boolean, content: @Composable () -> Unit) {
    val shape = RoundedCornerShape(Radii.r21)
    Row(
        modifier
            .height(55.dp)
            .selectedRing(selected, shape, primary = true)
            .clip(shape)
            .background(if (selected) Palette.ink else Palette.card)
            .border(1.dp, if (selected) Palette.ink else Palette.hairline, shape)
            .padding(start = Gap.f8, end = Gap.f21),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Gap.f8),
    ) { content() }
}

/** A "today" card: the land's colour, a picture or flame, what to try and why. */
@Composable
private fun DiscoveryCard(d: Discovery, world: World, selected: Boolean, modifier: Modifier) {
    val land = world.of(d.land)
    val shape = RoundedCornerShape(Radii.r21)
    Row(
        modifier
            .fillMaxHeight()
            .selectedRing(selected, shape, primary = true)
            .clip(shape)
            .background(if (selected) Palette.ink else land.tint)
            .padding(horizontal = Gap.f21),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Gap.f13),
    ) {
        Box(Modifier.size(55.dp).clip(CircleShape).background(Palette.card), contentAlignment = Alignment.Center) {
            val badge = d.skill?.let { world.badge(it) }
            when {
                d.skill == null -> com.rakesh.boretube.learn.ui.level.Flame(2, Modifier.size(34.dp))
                badge != null && badge in Pictures.ids -> PictureArt(badge, Modifier.size(38.dp))
                else -> BasicText(badge ?: "?", style = Text.display(TypeScale.s21), maxLines = 1)
            }
        }
        Column(Modifier.weight(1f)) {
            BasicText(d.title, style = Text.display(TypeScale.s21).copy(color = if (selected) Palette.cream else Palette.ink), maxLines = 1)
            BasicText(d.line, style = Text.body(TypeScale.s18, FontWeight.SemiBold).copy(color = if (selected) Palette.sunflowerSoft else Palette.muted), maxLines = 1)
        }
    }
}

fun greeting(hour: Int): String = when (hour) {
    in 5..11 -> "Good morning! Where shall we go?"
    in 12..16 -> "Good afternoon! Where shall we go?"
    else -> "Good evening! Where shall we go?"
}
