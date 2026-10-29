package com.rakesh.boretube.learn.ui.level

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
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
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.core.Answered
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Levels
import com.rakesh.boretube.learn.core.Question
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds
import com.rakesh.boretube.learn.speech.Speaker
import com.rakesh.boretube.learn.speech.safeSay
import com.rakesh.boretube.learn.ui.Gap
import com.rakesh.boretube.learn.ui.LocalUptime
import com.rakesh.boretube.learn.ui.Palette
import com.rakesh.boretube.learn.ui.ProgressBar
import com.rakesh.boretube.learn.ui.Radii
import com.rakesh.boretube.learn.ui.RemoteKey
import com.rakesh.boretube.learn.ui.Safe
import com.rakesh.boretube.learn.ui.Text
import com.rakesh.boretube.learn.ui.TypeScale
import com.rakesh.boretube.learn.ui.remote
import com.rakesh.boretube.learn.ui.selectedRing
import kotlinx.coroutines.delay
import kotlin.random.Random

private val KEYS = listOf("+ Ten", "+ One", "Take one away", "Done")

/**
 * Build (mock artboard 5): make the number from tens rods and ones cubes.
 * Done with the right number is a "Yes!"; anything else is the learn moment
 * ("47 is 4 tens and 7 ones."). Five numbers a level.
 */
@Composable
fun BuildLevel(
    state: LearnState,
    sounds: Sounds,
    speaker: Speaker,
    settings: LearnSettings,
    random: Random,
    now: Long,
    onDone: (List<Answered>) -> Unit,
    onLeave: () -> Unit,
) {
    val targets = remember { Levels.buildTargets(state, now, random) }
    if (targets.isEmpty()) {
        LaunchedEffect(Unit) { onLeave() }
        return
    }
    val uptime = LocalUptime.current
    var i by remember { mutableIntStateOf(0) }
    var shownAt by remember { mutableStateOf(uptime()) }
    val added = remember { mutableStateListOf<Int>() } // 10s and 1s, in order
    var sel by remember { mutableIntStateOf(0) }
    var right by remember { mutableStateOf(false) }
    var learn by remember { mutableStateOf<Int?>(null) } // what they made, on a miss
    val results = remember { mutableListOf<Answered>() }
    var leaving by remember { mutableStateOf(false) }
    var leaveSel by remember { mutableIntStateOf(0) }
    var streak by remember { mutableIntStateOf(0) }
    val q = targets[i]
    val target = Levels.buildTarget(q)
    val tens = added.count { it == 10 }
    val ones = added.count { it == 1 }
    val made = tens * 10 + ones

    fun next() {
        added.clear()
        right = false
        learn = null
        sel = 0
        if (i + 1 < targets.size) { i++; shownAt = uptime() } else onDone(results.toList())
    }

    LaunchedEffect(i) {
        if (settings.lang != "en" || settings.grade <= 1) speaker.safeSay("Make $target", settings.lang != "en")
    }
    LaunchedEffect(right) {
        if (right) { delay(RIGHT_MS); next() }
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .remote(Triple(i, learn, leaving)) { key ->
                if (leaving) {
                    when (key) {
                        RemoteKey.Left, RemoteKey.Right -> leaveSel = 1 - leaveSel
                        RemoteKey.Ok -> if (leaveSel == 0) leaving = false else { sounds.play(Sfx.back); onLeave() }
                        RemoteKey.Back -> leaving = false
                        else -> return@remote false
                    }
                    return@remote true
                }
                if (learn != null) {
                    if (key == RemoteKey.Ok) next() else if (key == RemoteKey.Back) leaving = true
                    return@remote true
                }
                when (key) {
                    RemoteKey.Left -> if (sel > 0) { sel--; sounds.tick(Sfx.focus_bazaar) }
                    RemoteKey.Right -> if (sel < KEYS.lastIndex) { sel++; sounds.tick(Sfx.focus_bazaar) }
                    RemoteKey.Up -> speaker.safeSay("Make $target", settings.lang != "en")
                    RemoteKey.Ok -> if (!right) when (sel) {
                        0 -> if (tens < 9) { added += 10; sounds.play(Sfx.build_ten) }
                        1 -> if (ones < 9) { added += 1; sounds.play(Sfx.build_one) }
                        2 -> if (added.isNotEmpty()) { added.removeAt(added.lastIndex); sounds.play(Sfx.build_undo) }
                        else -> {
                            val ok = made == target
                            results += Answered(q, if (ok) q.answer else -1, ok, uptime() - shownAt, false)
                            if (ok) {
                                streak++
                                sounds.play(Sfx.build_hit)
                                sounds.right(streak)
                                right = true
                            } else {
                                streak = 0
                                sounds.play(Sfx.miss)
                                learn = made
                            }
                        }
                    }
                    RemoteKey.Back -> { leaving = true; leaveSel = 0; sounds.play(Sfx.back) }
                    else -> return@remote false
                }
                true
            },
    ) {
        val miss = learn
        if (miss != null) {
            // The learn moment, phrased for building: "Make 47 … You made 45 … 47 is 4 tens and 7 ones."
            val shown = Question(
                key = q.key, skill = q.skill, prompt = "Make $target", promptHi = null, spoken = "Make $target", spokenHi = null,
                options = listOf("$miss", "$target"), answer = 1, fact = "Make $target", explain = q.explain,
            )
            LearnMoment(shown, picked = 0, pickedLabel = "You made ")
        } else {
            Column(Modifier.fillMaxSize().padding(horizontal = Safe.x, vertical = Gap.f34), verticalArrangement = Arrangement.spacedBy(Gap.f21)) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.Top) {
                    Column(Modifier.weight(1f)) {
                        BasicText(if (right) "Yes! $target" else "Make $target", style = Text.display(TypeScale.s89).copy(color = if (right) Palette.mintInk else Palette.ink))
                        BasicText("Tens and ones · Number Bazaar", style = Text.muted())
                    }
                    Column(Modifier.width(233.dp).padding(top = Gap.f21), horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(Gap.f8)) {
                        BasicText("${i + 1} of ${targets.size}", style = Text.body(TypeScale.s21, FontWeight.SemiBold))
                        ProgressBar((i + 1) / targets.size.toFloat(), Palette.coral, track = Palette.hairline)
                    }
                }
                Row(
                    Modifier
                        .weight(1f)
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(Radii.r34))
                        .background(Palette.card)
                        .border(1.dp, Palette.hairline, RoundedCornerShape(Radii.r34))
                        .padding(horizontal = Gap.f55),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(Gap.f55),
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(Gap.f13)) {
                        BasicText("Tens", style = Text.body(TypeScale.s21, FontWeight.SemiBold).copy(color = Palette.muted))
                        Row(Modifier.height(233.dp), horizontalArrangement = Arrangement.spacedBy(Gap.f13)) {
                            repeat(tens) { Rod(Modifier.width(34.dp).fillMaxHeight()) }
                        }
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(Gap.f13)) {
                        BasicText("Ones", style = Text.body(TypeScale.s21, FontWeight.SemiBold).copy(color = Palette.muted))
                        Column(Modifier.height(233.dp), verticalArrangement = Arrangement.spacedBy(Gap.f13)) {
                            for (rowCount in listOf(minOf(ones, 3), (ones - 3).coerceIn(0, 3), (ones - 6).coerceIn(0, 3))) {
                                Row(horizontalArrangement = Arrangement.spacedBy(Gap.f13)) {
                                    repeat(rowCount) { Box(Modifier.size(34.dp).clip(RoundedCornerShape(Radii.r8)).background(Palette.sunflower)) }
                                }
                            }
                        }
                    }
                    Column(Modifier.weight(1f), horizontalAlignment = Alignment.End) {
                        BasicText("So far", style = Text.muted())
                        BasicText("$made", style = Text.display(TypeScale.s144), modifier = Modifier.testTag("so-far"))
                        BasicText(hint(made, target), style = Text.muted())
                    }
                }
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Gap.f34)) {
                    KEYS.forEachIndexed { k, label ->
                        val shape = RoundedCornerShape(Radii.r21)
                        Box(
                            Modifier
                                .weight(1f)
                                .height(89.dp)
                                .selectedRing(k == sel && !right, shape, primary = true)
                                .clip(shape)
                                .background(if (k == sel && !right) Palette.ink else Palette.card)
                                .border(1.dp, if (k == sel) Palette.ink else Palette.hairline, shape),
                            contentAlignment = Alignment.Center,
                        ) {
                            BasicText(label, style = Text.display(TypeScale.s34).copy(color = if (k == sel && !right) Palette.cream else Palette.ink), maxLines = 1)
                        }
                    }
                }
            }
        }
        if (leaving) LeaveSheet(leaveSel)
    }
}

/** A gentle nudge under the number, never a scold. */
private fun hint(made: Int, target: Int): String {
    val d = target - made
    return when {
        d == 0 -> "That's it! Press Done."
        d > 0 && d % 10 == 0 -> "${d / 10} more ${if (d == 10) "ten" else "tens"} to go"
        d in 1..9 -> "$d more ${if (d == 1) "one" else "ones"} to go"
        d > 0 -> "Keep building"
        else -> "A little too many: take one away"
    }
}

@Composable
private fun Rod(modifier: Modifier) {
    Canvas(modifier) {
        drawRoundRect(Palette.sky, cornerRadius = CornerRadius(8.dp.toPx()))
        val cell = (size.height - 4.dp.toPx()) / 10f
        for (k in 0 until 10) {
            drawRoundRect(
                androidx.compose.ui.graphics.Color(0xFF7FB4FF),
                Offset(2.dp.toPx(), 2.dp.toPx() + k * cell + 1f),
                Size(size.width - 4.dp.toPx(), cell - 2f),
                CornerRadius(3.dp.toPx()),
            )
        }
    }
}
