package com.rakesh.boretube.learn.ui

import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import com.rakesh.boretube.learn.R

/** Bricolage Grotesque ExtraBold: display, titles, numbers. */
@OptIn(ExperimentalTextApi::class)
val Display = FontFamily(
    Font(R.font.bricolage, FontWeight.ExtraBold, variationSettings = FontVariation.Settings(FontVariation.weight(800))),
    Font(R.font.bricolage, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
)

/** Figtree: everything else. */
@OptIn(ExperimentalTextApi::class)
val Body = FontFamily(
    Font(R.font.figtree, FontWeight.Normal, variationSettings = FontVariation.Settings(FontVariation.weight(400))),
    Font(R.font.figtree, FontWeight.Medium, variationSettings = FontVariation.Settings(FontVariation.weight(500))),
    Font(R.font.figtree, FontWeight.SemiBold, variationSettings = FontVariation.Settings(FontVariation.weight(600))),
    Font(R.font.figtree, FontWeight.Bold, variationSettings = FontVariation.Settings(FontVariation.weight(700))),
)

object Text {
    fun display(size: TextUnit) = TextStyle(fontFamily = Display, fontWeight = FontWeight.ExtraBold, fontSize = size, color = Palette.ink)
    fun body(size: TextUnit, weight: FontWeight = FontWeight.Normal) =
        TextStyle(fontFamily = Body, fontWeight = weight, fontSize = size, color = Palette.ink)
    fun muted(size: TextUnit = TypeScale.s21) = body(size).copy(color = Palette.muted)
}
