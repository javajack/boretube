package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
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
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.core.Format
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Levels
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds
import com.rakesh.boretube.learn.world.LandInfo
import com.rakesh.boretube.learn.world.World

private const val PANEL_W = 470f
private const val NODE = 89f
private const val PER_ROW = 4

/** A land's winding path of levels (mock artboard 2). ◀ ▶ walk it, OK plays, Back goes to town. */
@Composable
fun LandScreen(
    land: LandInfo,
    state: LearnState,
    settings: LearnSettings,
    sounds: Sounds,
    world: World = World.MATHS,
    onPlay: (String) -> Unit,
    onBack: () -> Unit,
) {
    val path = remember(land, settings.grade) { world.path(land, settings.grade) }
    val progress = world.progress(state, land, settings.grade)
    val start = path.indexOf(progress.next).takeIf { it >= 0 } ?: 0
    var sel by remember(path) { mutableIntStateOf(start) }
    val centres = remember(path) { nodeCentres(path.size) }
    val selected = path.getOrNull(sel)
    Box(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .remote(Unit) { key ->
                when (key) {
                    RemoteKey.Left, RemoteKey.Right -> {
                        val n = (sel + if (key == RemoteKey.Left) -1 else 1).coerceIn(0, path.lastIndex)
                        if (n != sel) { sel = n; sounds.tick(land.tick) }
                        true
                    }
                    RemoteKey.Ok -> { selected?.let { sounds.play(Sfx.select); onPlay(it) }; true }
                    RemoteKey.Back -> { sounds.play(Sfx.back); onBack(); true }
                    else -> false
                }
            },
    ) {
        // The side panel.
        Column(
            Modifier
                .width(PANEL_W.dp)
                .fillMaxHeight()
                .background(land.tint)
                .padding(start = Safe.x, end = Gap.f55, top = Safe.y, bottom = Safe.y),
            verticalArrangement = Arrangement.spacedBy(Gap.f21),
        ) {
            BasicText("Tubby's Town ›", style = Text.body(TypeScale.s21, FontWeight.SemiBold).copy(color = Palette.sunflowerInk))
            BasicText(land.name, style = Text.display(TypeScale.s43), maxLines = 1)
            BasicText("${land.subject} · ${gradeName(settings.grade)} path", style = Text.muted())
            ProgressBar(if (progress.total == 0) 0f else progress.mastered / progress.total.toFloat(), Palette.sunflower)
            BasicText("${progress.mastered} of ${progress.total} skills · ${path.sumOf { state.stars[it] ?: 0 }} stars", style = Text.body(TypeScale.s21))
            Spacer(Modifier.weight(1f))
            selected?.let { LevelCard(it, state.stars[it] ?: 0, state.plays[it] ?: 0, world) }
            BasicText("◀ ▶ walk the path · OK to play", style = Text.muted(TypeScale.s18))
        }
        // The path and its nodes.
        Canvas(Modifier.offset(x = PANEL_W.dp).size((DESIGN_W - PANEL_W).dp, DESIGN_H.dp)) {
            if (centres.size < 2) return@Canvas
            val p = Path()
            centres.forEachIndexed { i, c ->
                val o = Offset(c.x.dp.toPx(), c.y.dp.toPx())
                if (i == 0) p.moveTo(o.x, o.y) else {
                    val prev = centres[i - 1]
                    val a = Offset(prev.x.dp.toPx(), prev.y.dp.toPx())
                    val midY = (a.y + o.y) / 2f
                    if (a.y == o.y) p.quadraticBezierTo((a.x + o.x) / 2f, a.y - 40.dp.toPx(), o.x, o.y)
                    else p.cubicTo(a.x, midY, o.x, midY, o.x, o.y)
                }
            }
            drawPath(p, Palette.outline, style = Stroke(10.dp.toPx(), cap = StrokeCap.Round, pathEffect = PathEffect.dashPathEffect(floatArrayOf(2f, 22.dp.toPx()))))
        }
        path.forEachIndexed { i, id ->
            val c = centres[i]
            PathNode(
                id = id,
                done = id in state.mastered,
                current = id == progress.next,
                selected = i == sel,
                stars = state.stars[id] ?: 0,
                world = world,
                modifier = Modifier.offset(x = (PANEL_W + c.x - 90f).dp, y = (c.y - NODE / 2f).dp),
            )
        }
    }
}

@Composable
private fun PathNode(id: String, done: Boolean, current: Boolean, selected: Boolean, stars: Int, world: World, modifier: Modifier) {
    Column(modifier.width(180.dp), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(Gap.f4)) {
        val fill = when {
            current -> Palette.coral
            done -> Palette.sunflower
            else -> Palette.cream
        }
        Box(
            Modifier
                .size(NODE.dp)
                .testTag("node-$id")
                .selectedRing(selected, CircleShape, scale = 1.15f)
                .clip(CircleShape)
                .background(fill)
                .then(if (!current && !done) Modifier.border(3.dp, Palette.outline, CircleShape) else Modifier),
            contentAlignment = Alignment.Center,
        ) {
            val badge = world.badge(id)
            when {
                done && !current -> BasicText("✓", style = Text.display(TypeScale.s26))
                badge in Pictures.ids -> PictureArt(badge, Modifier.size(55.dp))
                else -> BasicText(badge, style = Text.display(TypeScale.s26).copy(color = if (current) Palette.card else Palette.ink))
            }
        }
        if (stars > 0) StarRow(stars, size = 18.dp) else Spacer(Modifier.height(18.dp))
        // A canvas-coloured backing so the dotted path never runs through the words.
        BasicText(
            world.title(id),
            modifier = Modifier.clip(RoundedCornerShape(Radii.r8)).background(Palette.canvas).padding(horizontal = Gap.f8, vertical = Gap.f4),
            style = Text.body(TypeScale.s18, if (selected) FontWeight.ExtraBold else FontWeight.SemiBold).copy(textAlign = TextAlign.Center),
            maxLines = 2,
        )
    }
}

@Composable
private fun LevelCard(id: String, best: Int, plays: Int, world: World) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(Radii.r21)).background(Palette.cream).padding(horizontal = Gap.f21, vertical = Gap.f21),
        verticalArrangement = Arrangement.spacedBy(Gap.f8),
    ) {
        BasicText(world.title(id), style = Text.display(TypeScale.s34))
        val line = when (Levels.formatFor(id, plays, world.catalog)) {
            Format.catch -> "Catch · ${Levels.LEVEL_SIZE} questions"
            Format.pairs -> "Pairs · ${Levels.PAIRS} to match"
            Format.build -> "Build · ${Levels.BUILDS} numbers"
            Format.quickfire -> "Quick-fire · ${Levels.LEVEL_SIZE} questions"
        }
        BasicText(line, style = Text.muted(), maxLines = 1)
        BasicText("About 3 minutes", style = Text.muted(TypeScale.s18))
        if (best > 0) StarRow(best, size = 26.dp) else BasicText("New level, no stars yet", style = Text.body(TypeScale.s21))
    }
}

@Composable
fun ProgressBar(fraction: Float, color: androidx.compose.ui.graphics.Color, track: androidx.compose.ui.graphics.Color = Palette.canvas) {
    Box(Modifier.fillMaxWidth().height(13.dp).clip(RoundedCornerShape(Radii.r8)).background(track)) {
        Box(Modifier.fillMaxWidth(fraction.coerceIn(0f, 1f)).fillMaxHeight().background(color))
    }
}

fun gradeName(g: Int) = if (g == 0) "KG" else "Class $g"

/** Node centres in the path area (810×720): a snake of up to [PER_ROW] per row, bottom row first. */
internal fun nodeCentres(n: Int): List<Offset> {
    if (n == 0) return emptyList()
    val rows = (n + PER_ROW - 1) / PER_ROW
    val ys = when (rows) {
        1 -> listOf(380f)
        2 -> listOf(500f, 240f)
        else -> List(rows) { r -> 560f - r * (430f / (rows - 1)) }
    }
    val xs = List(PER_ROW) { c -> 120f + c * 190f }
    return List(n) { i ->
        val r = i / PER_ROW
        val c = i % PER_ROW
        Offset(if (r % 2 == 0) xs[c] else xs[PER_ROW - 1 - c], ys[r])
    }
}
