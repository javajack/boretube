package com.rakesh.boretube.learn.core.gen

import com.rakesh.boretube.learn.core.GenSkill

/**
 * Every generated skill (spec P2b). [data] reads a file from
 * `assets/content/data` by name, or null when it isn't there.
 */
object Generated {
    fun skills(data: (String) -> String?): List<GenSkill> =
        MathsGen.skills(data) + EnglishGen.skills(data) + EvsGen.skills(data) + ScienceGen.skills(data)

    fun subject(name: String, data: (String) -> String?): List<GenSkill> = when (name) {
        "maths" -> MathsGen.skills(data)
        "english" -> EnglishGen.skills(data)
        "evs" -> EvsGen.skills(data).filter { it.subject == "evs" }
        "science" -> ScienceGen.skills(data)
        else -> emptyList()
    }
}
