package com.rakesh.boretube.learn.world

import androidx.compose.ui.graphics.Color
import com.rakesh.boretube.learn.core.Catalog
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Maths
import com.rakesh.boretube.learn.core.Pack
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
    /** Skill ids, easy to hard (empty until the land's banks are reviewed). */
    val skills: List<String>,
)

data class LandProgress(val mastered: Int, val total: Int, val next: String?)

/**
 * Tubby's Town for one [catalog] (spec §1): Number Bazaar holds the maths
 * ladder, Word Garden the English banks, Nature Trail the EVS/Science banks.
 */
class World(val catalog: Catalog) {
    val lands: List<LandInfo> = listOf(
        LandInfo(LandId.bazaar, "Number Bazaar", "Maths", Palette.bazaar, Sfx.focus_bazaar, catalog.bySubject("maths").map { it.id }),
        LandInfo(LandId.garden, "Word Garden", "English", Palette.garden, Sfx.focus_garden, catalog.bySubject("english").map { it.id }),
        LandInfo(LandId.trail, "Nature Trail", "EVS", Palette.trail, Sfx.focus_trail, catalog.bySubject("evs").map { it.id }),
    )

    fun of(id: LandId): LandInfo = lands.first { it.id == id }

    /** The land a skill lives in (Number Bazaar if unknown). */
    fun landOf(skillId: String): LandInfo = lands.firstOrNull { skillId in it.skills } ?: of(LandId.bazaar)

    /** The levels a child of [grade] sees: one class below to one class above. */
    fun path(land: LandInfo, grade: Int): List<String> =
        land.skills.filter { (catalog.skill(it)?.grade ?: -9) in (grade - 1)..(grade + 1) }

    /** Mastered / total on the path, and the next skill (the maths rung, else the first not mastered). */
    fun progress(s: LearnState, land: LandInfo, grade: Int): LandProgress {
        val path = path(land, grade)
        val rung = if (land.id == LandId.bazaar) Maths.LADDER.getOrNull(s.rung)?.id else null
        val current = rung?.takeIf { it in path && it !in s.mastered }
        val next = current ?: path.firstOrNull { it !in s.mastered }
        return LandProgress(path.count { it in s.mastered }, path.size, next)
    }

    fun badge(skillId: String): String = catalog.skill(skillId)?.badge ?: "?"
    fun title(skillId: String): String = catalog.skill(skillId)?.title ?: skillId

    companion object {
        val MATHS = World(Catalog.MATHS)
        fun of(packs: List<Pack>) = World(Catalog.of(packs))
    }
}

/** The maths-only world (tests, and before any bank is reviewed). */
val Lands: World get() = World.MATHS
