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
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.rakesh.boretube.learn.data.LearnSettings
import com.rakesh.boretube.learn.data.Player
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.sound.Sounds

/**
 * Settings, all on the TV (the app never needs the phone to be used): this
 * player's language, sounds, and removing this player. ▲ ▼ move,
 * ◀ ▶ or OK change, Back saves and returns.
 */
@Composable
fun SettingsScreen(
    settings: LearnSettings,
    player: Player?,
    canRemove: Boolean,
    sounds: Sounds,
    onChange: (LearnSettings) -> Unit,
    onRemove: () -> Unit,
    onBack: () -> Unit,
) {
    var s by remember { mutableStateOf(settings) }
    var row by remember { mutableIntStateOf(0) }
    var confirm by remember { mutableStateOf(false) }
    val rows = if (canRemove && player != null) 3 else 2
    fun apply(n: LearnSettings) { s = n; onChange(n) }
    fun change(d: Int) {
        when (row) {
            0 -> { val i = (LANGS.indexOfFirst { it.first == s.lang } + d).mod(LANGS.size); apply(s.copy(lang = LANGS[i].first)) }
            1 -> apply(s.copy(sounds = !s.sounds))
        }
        sounds.play(Sfx.select)
    }
    Column(
        Modifier
            .fillMaxSize()
            .background(Palette.canvas)
            .remote(row to confirm) { key ->
                when (key) {
                    RemoteKey.Up, RemoteKey.Down -> {
                        val n = (row + if (key == RemoteKey.Up) -1 else 1).coerceIn(0, rows - 1)
                        if (n != row) { row = n; confirm = false; sounds.tick(Sfx.focus_bazaar) }
                    }
                    RemoteKey.Left, RemoteKey.Right -> if (row < 2) change(if (key == RemoteKey.Left) -1 else 1)
                    RemoteKey.Ok -> if (row < 2) change(1) else if (confirm) { sounds.play(Sfx.back); onRemove() } else { confirm = true; sounds.play(Sfx.select) }
                    RemoteKey.Back -> { sounds.play(Sfx.back); onBack() }
                    else -> return@remote false
                }
                true
            }
            .padding(horizontal = Safe.x, vertical = Safe.y)
            .testTag("settings-screen"),
        verticalArrangement = Arrangement.spacedBy(Gap.f21),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Tubby(TubbyMood.calm, Modifier.width(66.dp))
            Column(Modifier.padding(start = Gap.f21)) {
                BasicText("For grown-ups", style = Text.muted())
                BasicText("Settings", style = Text.display(TypeScale.s43))
            }
            if (player != null) {
                Box(Modifier.padding(start = Gap.f34).size(55.dp).clip(CircleShape).background(Palette.cream), contentAlignment = Alignment.Center) {
                    PictureArt(player.pic, Modifier.size(44.dp))
                }
                BasicText("  ${gradeName(player.grade)}", style = Text.body(TypeScale.s21, FontWeight.Bold))
            }
        }
        SettingRow("Language", LANGS.first { it.first == s.lang }.second, "Questions read aloud follow this", row == 0, "lang")
        SettingRow("Sounds", if (s.sounds) "On" else "Off", "Clicks, chimes and cheers", row == 1, "sounds")
        if (rows == 3) {
            SettingRow(
                "Remove this player",
                if (confirm) "Press OK again to remove" else "Removes their stars",
                "Other players keep theirs",
                row == 2, "remove", danger = true,
            )
        }
        BasicText("▲ ▼ move · ◀ ▶ or OK change · Back when done", style = Text.muted())
    }
}

@Composable
private fun SettingRow(label: String, value: String, hint: String, selected: Boolean, tag: String, danger: Boolean = false) {
    val shape = RoundedCornerShape(Radii.r21)
    Row(
        Modifier
            .fillMaxWidth()
            .height(89.dp)
            .selectedRing(selected, shape, primary = true, scale = 1.02f)
            .clip(shape)
            .background(if (selected) Palette.ink else Palette.card)
            .border(1.dp, if (selected) Palette.ink else Palette.hairline, shape)
            .padding(horizontal = Gap.f34)
            .testTag("setting-$tag"),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            BasicText(label, style = Text.display(TypeScale.s26).copy(color = if (selected) Palette.cream else if (danger) Palette.coralInk else Palette.ink))
            BasicText(hint, style = Text.body(TypeScale.s18).copy(color = if (selected) Palette.sunflowerSoft else Palette.muted))
        }
        BasicText(value, style = Text.display(TypeScale.s26).copy(color = if (selected) Palette.cream else Palette.ink))
    }
}
