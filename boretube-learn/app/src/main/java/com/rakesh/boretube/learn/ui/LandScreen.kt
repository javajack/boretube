package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
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
import androidx.compose.runtime.mutableStateOf
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
/** At most this many levels on one page of the path (three rows of the snake). */
internal const val PAGE = 12

/** A land's winding path of levels (mock artboard 2). ◀ ▶ walk it, OK plays, Back goes to town. */
@Composable
fun LandScreen(
    land: LandInfo,
    state: LearnState,
    settings: LearnSettings,
    sounds: Sounds,
    world: World = World.MATHS,
    onRun: (() -> Unit)? = null,
    onPlay: (String) -> Unit,
    onBack: () -> Unit,
) {
    val path = remember(land, settings.grade) { world.path(land, settings.grade) }
    val progress = world.progress(state, land, settings.grade)
    val start = path.indexOf(progress.next).takeIf { it >= 0 } ?: 0
    var sel by remember(path) { mutableIntStateOf(start) }
    // ▼ from the path focuses the Streak run button in the panel.
    var onRunButton by remember { mutableStateOf(false) }
    // Up to three snake rows on one page; longer paths split into even pages.
    val pages = ((path.size + PAGE - 1) / PAGE).coerceAtLeast(1)
    val per = ((path.size + pages - 1) / pages).coerceAtLeast(1)
    val page = sel / per
    val onPage = path.drop(page * per).take(per)
    val centres = remember(onPage.size) { nodeCentres(onPage.size) }
    val selected = path.getOrNull(sel)
    Box(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .remote(onRunButton) { key ->
                if (onRunButton) {
                    when (key) {
                        RemoteKey.Up, RemoteKey.Right -> { onRunButton = false; sounds.tick(land.tick) }
                        RemoteKey.Ok -> { sounds.play(Sfx.run_start); onRun?.invoke() }
                        RemoteKey.Back -> { sounds.play(Sfx.back); onBack() }
                        else -> return@remote false
                    }
                    return@remote true
                }
                when (key) {
                    RemoteKey.Left, RemoteKey.Right -> {
                        val n = (sel + if (key == RemoteKey.Left) -1 else 1).coerceIn(0, path.lastIndex)
                        if (n != sel) {
                            if (n / per != sel / per) sounds.play(Sfx.card_flip) else sounds.tick(land.tick)
                            sel = n
                        }
                        true
                    }
                    RemoteKey.Down -> { if (onRun != null) { onRunButton = true; sounds.tick(land.tick) }; true }
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
            selected?.let { LevelCard(it, state.stars[it] ?: 0, state, state.tiers[it] ?: 1, world) }
            if (onRun != null) RunButton(onRunButton, state.bestRuns[land.id.name] ?: 0)
            BasicText(if (onRun != null) "◀ ▶ walk the path · ▼ streak run · OK to play" else "◀ ▶ walk the path · OK to play", style = Text.muted(TypeScale.s18), maxLines = 1)
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
        if (pages > 1) PageDots(page, pages, Modifier.offset(x = (PANEL_W + 40f).dp, y = 34.dp))
        onPage.forEachIndexed { k, id ->
            val i = page * per + k
            val c = centres[k]
            PathNode(
                id = id,
                done = id in state.mastered,
                current = id == progress.next,
                selected = i == sel && !onRunButton,
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
private fun LevelCard(id: String, best: Int, state: LearnState, tier: Int, world: World) {
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(Radii.r21)).background(Palette.cream).padding(horizontal = Gap.f21, vertical = Gap.f21),
        verticalArrangement = Arrangement.spacedBy(Gap.f8),
    ) {
        BasicText(world.title(id), style = Text.display(TypeScale.s34), maxLines = 2)
        val line = when (Levels.formatFor(id, state, world.catalog)) {
            Format.catch -> "Catch · ${Levels.LEVEL_SIZE} questions"
            Format.pairs -> "Pairs · ${Levels.PAIRS} to match"
            Format.build -> "Build · ${Levels.BUILDS} numbers"
            Format.quickfire -> "Quick-fire · ${Levels.LEVEL_SIZE} questions"
            Format.truefalse -> "True or false · ${Levels.LEVEL_SIZE} questions"
            Format.sort -> "Sort · ${Levels.LEVEL_SIZE} cards"
            Format.order -> "Put in order · ${com.rakesh.boretube.learn.ui.level.LevelPlan.ORDER_SIZE} puzzles"
        }
        BasicText(line, style = Text.muted(), maxLines = 1)
        val tiers = world.catalog.skill(id)?.tiers ?: 1
        if (tiers > 1) TierRow(tier, tiers) else BasicText("About 3 minutes", style = Text.muted(TypeScale.s18))
        if (best > 0) StarRow(best, size = 26.dp) else BasicText("New level, no stars yet", style = Text.body(TypeScale.s21))
    }
}

/** Easy · Medium · Hard, the child's step in sunflower: 3 stars climbs it. */
@Composable
private fun TierRow(tier: Int, tiers: Int) {
    Row(horizontalArrangement = Arrangement.spacedBy(Gap.f8), verticalAlignment = Alignment.CenterVertically) {
        for (t in 1..tiers) {
            val on = t == tier
            BasicText(
                TIER_NAMES.getOrElse(t - 1) { "Hard" },
                modifier = Modifier
                    .clip(RoundedCornerShape(Radii.r13))
                    .background(if (on) Palette.sunflower else Palette.canvas)
                    .padding(horizontal = Gap.f13, vertical = Gap.f4)
                    .testTag(if (on) "tier-on" else "tier-$t"),
                style = Text.body(TypeScale.s18, if (on) FontWeight.ExtraBold else FontWeight.SemiBold).copy(color = if (on) Palette.ink else Palette.muted),
            )
        }
    }
}

private val TIER_NAMES = listOf("Easy", "Medium", "Hard")

/** The Streak run: a flame, the best run so far, and how to start it. */
@Composable
private fun RunButton(selected: Boolean, best: Int) {
    val shape = RoundedCornerShape(Radii.r21)
    Row(
        Modifier
            .fillMaxWidth()
            .selectedRing(selected, shape, primary = true, gap = Palette.sunflowerSoft)
            .clip(shape)
            .background(if (selected) Palette.ink else Palette.card)
            .padding(horizontal = Gap.f21, vertical = Gap.f13)
            .testTag("run-button"),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(Gap.f13),
    ) {
        com.rakesh.boretube.learn.ui.level.Flame(if (best >= 10) 3 else 2, Modifier.size(34.dp))
        Column(Modifier.weight(1f)) {
            BasicText("Streak run", style = Text.display(TypeScale.s26).copy(color = if (selected) Palette.cream else Palette.ink))
            BasicText(
                if (best > 0) "Best: $best in a row" else "How many in a row?",
                style = Text.body(TypeScale.s18, FontWeight.SemiBold).copy(color = if (selected) Palette.sunflowerSoft else Palette.muted),
            )
        }
    }
}

/** "Part 2 of 4": the page of the path you're on. */
@Composable
private fun PageDots(page: Int, pages: Int, modifier: Modifier) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(Gap.f8), verticalAlignment = Alignment.CenterVertically) {
        BasicText("Part ${page + 1} of $pages", style = Text.body(TypeScale.s18, FontWeight.SemiBold).copy(color = Palette.muted))
        for (i in 0 until pages) {
            Box(Modifier.size(if (i == page) 13.dp else 8.dp).clip(CircleShape).background(if (i == page) Palette.ink else Palette.outline))
        }
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
