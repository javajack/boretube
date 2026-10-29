package com.rakesh.boretube.learn.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.core.Chest
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds
import com.rakesh.boretube.learn.world.World
import java.time.LocalDate

/** Pictures that can come out of a treasure chest (all drawn by [Pictures]). */
val TREASURES = listOf(
    "tiger", "elephant", "peacock", "rocket", "kite", "rainbow", "dolphin", "giraffe", "owl", "lotus", "saturn", "astronaut",
    "butterfly", "panda", "kangaroo", "telescope", "drum", "guitar", "lantern", "balloon", "starfish", "seahorse", "parrot", "comet",
).filter { it in Pictures.ids }

private val STICKERS = listOf("lion", "tiger", "elephant", "monkey", "giraffe", "zebra", "parrot", "owl", "dolphin", "panda", "deer", "rabbit")
    .filter { it in Pictures.ids }

/** Pictures that suit a subject when a skill has none of its own. */
private val SUBJECT_STICKERS = mapOf(
    "maths" to listOf("cube", "ruler", "clock", "sphere", "cone", "cylinder", "crayon", "notebook"),
    "english" to listOf("book", "pencil", "pen", "notebook", "crayon", "blackboard", "schoolbag", "globe"),
    "evs" to listOf("lotus", "sunflower", "butterfly", "peacock", "tree", "earth", "rainbow", "magnifier"),
)

/**
 * The sticker a mastered skill earns, related to what was learned: its
 * badge picture; else a picture named in its title or id ("Magnets" → magnet,
 * "Animal sounds" → a subject picture); else one that suits its subject.
 */
fun stickerFor(skillId: String, world: World): String {
    world.badge(skillId)?.takeIf { it in Pictures.ids }?.let { return it }
    val words = (world.title(skillId) + " " + skillId.substringAfter('.'))
        .lowercase().split(Regex("[^a-z]+")).filter { it.length >= 3 }
    for (w in words) {
        for (c in listOf(w, w.removeSuffix("s"), w.removeSuffix("es"))) if (c in Pictures.ids) return c
    }
    val subject = world.catalog.skill(skillId)?.subject
    val pool = (SUBJECT_STICKERS[subject] ?: STICKERS).filter { it in Pictures.ids }.ifEmpty { STICKERS }
    return pool.getOrElse(Math.floorMod(skillId.hashCode(), maxOf(1, pool.size))) { "star" }
}

/**
 * The sticker book: a sticker for every mastered skill and the treasures
 * from weekly chests. ◀ ▶ walk them (the name shows below), Back goes to town.
 */
@Composable
fun StickerBookScreen(state: LearnState, world: World, today: LocalDate, sounds: Sounds, onBack: () -> Unit) {
    data class Sticker(val pic: String, val name: String, val treasure: Boolean)
    val all = remember(state) {
        state.mastered.filter { world.catalog.skill(it) != null }.map { Sticker(stickerFor(it, world), world.title(it), false) } +
            state.treasures.filter { it in Pictures.ids }.map { Sticker(it, "Treasure: ${stickerName(it)}", true) }
    }
    var sel by remember { mutableIntStateOf(0) }
    val page = sel / PAGE_SIZE
    val chest = Chest.status(state, today)
    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .testTag("sticker-book")
            .remote(Unit) { key ->
                when (key) {
                    RemoteKey.Left, RemoteKey.Right -> {
                        val n = (sel + if (key == RemoteKey.Left) -1 else 1).coerceIn(0, (all.size - 1).coerceAtLeast(0))
                        if (n != sel) { sel = n; sounds.tick(Sfx.focus_bazaar) }
                    }
                    RemoteKey.Back, RemoteKey.Ok -> { sounds.play(Sfx.back); onBack() }
                    else -> return@remote false
                }
                true
            }
            .padding(horizontal = Safe.x, vertical = Safe.y),
        verticalArrangement = Arrangement.spacedBy(Gap.f21),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Tubby(TubbyMood.cheer, Modifier.width(66.dp))
            Spacer(Modifier.width(Gap.f21))
            Column(Modifier.weight(1f)) {
                BasicText("My sticker book", style = Text.display(TypeScale.s43))
                BasicText(
                    when (all.size) {
                        0 -> "Master a skill to win your first sticker!"
                        1 -> "1 sticker so far. Lovely start!"
                        else -> "${all.size} stickers so far. Keep going!"
                    },
                    style = Text.muted(),
                )
            }
        }
        ChestRow(chest, openedNow = false)
        Box(Modifier.weight(1f).fillMaxWidth()) {
            val shown = all.drop(page * PAGE_SIZE).take(PAGE_SIZE)
            Column(verticalArrangement = Arrangement.spacedBy(Gap.f21)) {
                for (row in shown.chunked(PER_ROW).withIndex()) {
                    Row(horizontalArrangement = Arrangement.spacedBy(Gap.f21)) {
                        row.value.forEachIndexed { j, s ->
                            val i = page * PAGE_SIZE + row.index * PER_ROW + j
                            val shape = RoundedCornerShape(Radii.r21)
                            Box(
                                Modifier
                                    .size(150.dp)
                                    .selectedRing(i == sel, shape, primary = true)
                                    .clip(shape)
                                    .background(if (s.treasure) Palette.sunflowerSoft else Palette.card)
                                    .border(1.dp, Palette.hairline, shape)
                                    .testTag("sticker-$i"),
                                contentAlignment = Alignment.Center,
                            ) { PictureArt(s.pic, Modifier.size(110.dp)) }
                        }
                    }
                }
            }
        }
        BasicText(
            all.getOrNull(sel)?.name ?: "Every mastered skill puts a sticker here.",
            style = Text.body(TypeScale.s21, FontWeight.Bold).copy(textAlign = TextAlign.Start),
            maxLines = 1,
            modifier = Modifier.fillMaxWidth(),
        )
        BasicText("◀ ▶ look at your stickers · Back to town", style = Text.muted(), maxLines = 1)
    }
}

private const val PER_ROW = 8
private const val PAGE_SIZE = 16
