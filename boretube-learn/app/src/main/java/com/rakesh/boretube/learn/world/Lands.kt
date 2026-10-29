package com.rakesh.boretube.learn.world

import androidx.compose.ui.graphics.Color
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Maths
import com.rakesh.boretube.learn.sound.Sfx
import com.rakesh.boretube.learn.ui.Palette

enum class LandId { bazaar, garden, trail }

data class LandInfo(
    val id: LandId,
    val name: String,
    val subject: String,
    val tint: Color,
    /** The land's own focus tick. */
    val tick: Sfx,
    /** Skill ids, easy to hard (empty until the land's packs ship). */
    val skills: List<String>,
)

data class LandProgress(val mastered: Int, val total: Int, val next: String?)

/** Tubby's Town (spec §1). P1: Number Bazaar has the maths ladder; the other lands come with P3 packs. */
object Lands {
    val all = listOf(
        LandInfo(LandId.bazaar, "Number Bazaar", "Maths", Palette.bazaar, Sfx.focus_bazaar, Maths.LADDER.map { it.id }),
        LandInfo(LandId.garden, "Word Garden", "English", Palette.garden, Sfx.focus_garden, emptyList()),
        LandInfo(LandId.trail, "Nature Trail", "EVS", Palette.trail, Sfx.focus_trail, emptyList()),
    )

    fun of(id: LandId): LandInfo = all.first { it.id == id }

    /** The levels a child of [grade] sees: one class below to one class above. */
    fun path(land: LandInfo, grade: Int): List<String> {
        if (land.skills.isEmpty()) return emptyList()
        val lo = Maths.minRung(grade)
        val hi = Maths.maxRung(grade)
        return land.skills.filter { Maths.indexOf(it) in lo..hi }
    }

    /** Mastered / total on the path, and the next skill to play (the rung, else the first not mastered). */
    fun progress(s: LearnState, land: LandInfo, grade: Int): LandProgress {
        val path = path(land, grade)
        val current = Maths.LADDER.getOrNull(s.rung)?.id?.takeIf { it in path && it !in s.mastered }
        val next = current ?: path.firstOrNull { it !in s.mastered }
        return LandProgress(path.count { it in s.mastered }, path.size, next)
    }

    /** The short mark inside a path node. */
    fun badge(skillId: String): String = when (skillId) {
        "count10" -> "123"
        "biggest10" -> "5>2"
        "add10" -> "2+3"
        "sub10" -> "5−2"
        "next20" -> "19"
        "make10" -> "9+6"
        "placeValue" -> "47"
        "add100" -> "+99"
        "tablesLow" -> "×5"
        "money" -> "₹"
        "clock" -> "3:30"
        "tablesHigh" -> "×7"
        "divide" -> "÷"
        "mul21" -> "23×4"
        "fractions" -> "¾"
        "halfOf" -> "½"
        "decimals" -> "0.5"
        "percent" -> "%"
        "negatives" -> "−3"
        "equations" -> "x"
        else -> "?"
    }
}
