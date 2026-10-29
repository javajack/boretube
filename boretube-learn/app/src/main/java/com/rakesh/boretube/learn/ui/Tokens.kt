package com.rakesh.boretube.learn.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * The only sizes, colours and durations screens may use (spec §5). Spacing
 * and type follow Fibonacci / φ steps on the 1280×720 dp TV grid.
 */
object Gap {
    val f4 = 4.dp
    val f8 = 8.dp
    val f13 = 13.dp
    val f21 = 21.dp
    val f34 = 34.dp
    val f55 = 55.dp
    val f89 = 89.dp
}

object TypeScale {
    val s18 = 18.sp
    val s21 = 21.sp
    val s26 = 26.sp
    val s34 = 34.sp
    val s43 = 43.sp
    val s55 = 55.sp
    val s89 = 89.sp
    val s144 = 144.sp
}

object Radii {
    val r8 = 8.dp
    val r13 = 13.dp
    val r21 = 21.dp
    val r34 = 34.dp
}

/** Durations in ms. */
object Motion {
    const val press = 120
    const val flip = 200
    const val sheet = 320
    const val slow = 520
}

object Palette {
    val canvas = Color(0xFFFFF4E4)
    val card = Color(0xFFFFFFFF)
    val hairline = Color(0xFFEADFD1)
    val ink = Color(0xFF1C1D3A)
    val muted = Color(0xFF5B5C78)
    val cream = Color(0xFFFFF8F1)
    val coral = Color(0xFFFF6B4A)
    /** Coral as text on light grounds (4.5:1). */
    val coralInk = Color(0xFFB33A1F)
    val sunflower = Color(0xFFFFB020)
    val sunflowerSoft = Color(0xFFFFD27A)
    val sunflowerInk = Color(0xFF8A5A00)
    val mint = Color(0xFF1FBF8F)
    val mintInk = Color(0xFF0E7C5B)
    val sky = Color(0xFF3A8DFF)
    val lavender = Color(0xFF8C7CFF)
    val bazaar = Color(0xFFFFE1A6)
    val garden = Color(0xFFCDEFE0)
    val trail = Color(0xFFD6E8FF)
    /** A path node or slot that's open but not done. */
    val outline = Color(0xFFE6C98F)
}

/** The TV-safe margin around every screen (5% of 1280×720 is 64×36; φ steps give 89×55). */
object Safe {
    val x = 89.dp
    val y = 55.dp
}
