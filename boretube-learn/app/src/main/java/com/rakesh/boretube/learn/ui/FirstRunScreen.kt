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
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds

private val LANGS = listOf("en" to "English", "hi" to "हिन्दी", "enHi" to "English + Hindi voice")

/**
 * The first time the app opens (no settings from the phone yet): pick the
 * class (two even rows of four), then the language. A grown-up can change
 * both later from the phone.
 */
@Composable
fun FirstRunScreen(sounds: Sounds, onDone: (LearnSettings) -> Unit, onBack: () -> Unit) {
    var step by remember { mutableIntStateOf(0) }
    var grade by remember { mutableIntStateOf(0) }
    var lang by remember { mutableIntStateOf(0) }
    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .remote(step) { key ->
                when (key) {
                    RemoteKey.Left, RemoteKey.Right, RemoteKey.Up, RemoteKey.Down -> {
                        val d = when (key) { RemoteKey.Left -> -1; RemoteKey.Right -> 1; RemoteKey.Up -> -4; else -> 4 }
                        if (step == 0) {
                            val n = grade + d
                            if (n in 0..7 && !(key == RemoteKey.Right && grade == 3) && !(key == RemoteKey.Left && grade == 4)) { grade = n; sounds.tick(Sfx.focus_bazaar) }
                        } else if (key == RemoteKey.Left || key == RemoteKey.Right) {
                            val n = (lang + d).coerceIn(0, LANGS.lastIndex)
                            if (n != lang) { lang = n; sounds.tick(Sfx.focus_bazaar) }
                        }
                    }
                    RemoteKey.Ok -> {
                        sounds.play(Sfx.select)
                        if (step == 0) step = 1 else onDone(LearnSettings(grade = grade, lang = LANGS[lang].first, set = true))
                    }
                    RemoteKey.Back -> if (step == 1) { step = 0; sounds.play(Sfx.back) } else onBack()
                    else -> return@remote false
                }
                true
            }
            .padding(horizontal = Safe.x, vertical = Safe.y),
        verticalArrangement = Arrangement.spacedBy(Gap.f34, Alignment.CenterVertically),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Tubby(TubbyMood.cheer, Modifier.width(110.dp))
            Column(Modifier.padding(start = Gap.f34)) {
                BasicText("Hi! I'm Tubby.", style = Text.muted(TypeScale.s26))
                BasicText(if (step == 0) "Which class are you in?" else "Which language?", style = Text.display(TypeScale.s55))
            }
        }
        if (step == 0) {
            Column(verticalArrangement = Arrangement.spacedBy(Gap.f34)) {
                for (row in listOf(0..3, 4..7)) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Gap.f34)) {
                        for (g in row) Choice(gradeName(g), g == grade, Modifier.weight(1f))
                    }
                }
            }
            BasicText("Ask a grown-up if you're not sure.", style = Text.muted())
        } else {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(Gap.f34)) {
                LANGS.forEachIndexed { i, (_, label) -> Choice(label, i == lang, Modifier.weight(1f)) }
            }
            BasicText("Questions are read aloud for the little ones.", style = Text.muted())
        }
    }
}

@Composable
private fun Choice(label: String, selected: Boolean, modifier: Modifier) {
    val shape = RoundedCornerShape(Radii.r21)
    Box(
        modifier
            .height(110.dp)
            .selectedRing(selected, shape, primary = true, scale = 1.06f)
            .clip(shape)
            .background(if (selected) Palette.ink else Palette.card)
            .border(1.dp, if (selected) Palette.ink else Palette.hairline, shape),
        contentAlignment = Alignment.Center,
    ) { BasicText(label, style = Text.display(TypeScale.s34).copy(color = if (selected) Palette.cream else Palette.ink), maxLines = 1) }
}
