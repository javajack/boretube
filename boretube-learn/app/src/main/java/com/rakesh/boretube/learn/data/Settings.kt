package com.rakesh.boretube.learn.data

import android.content.SharedPreferences

/** What the parent (or the first-run picker) chose. [set] is false until someone chose. */
data class LearnSettings(
    /** CBSE class: 0 = KG … 7. */
    val grade: Int = 1,
    /** en | hi | enHi */
    val lang: String = "en",
    val sounds: Boolean = true,
    val music: Boolean = true,
    val set: Boolean = false,
)

interface SettingsRepo {
    fun get(): LearnSettings
    fun put(s: LearnSettings)
}

class SettingsStore(private val prefs: SharedPreferences) : SettingsRepo {
    override fun get() = LearnSettings(
        grade = prefs.getInt("grade", 1).coerceIn(0, 7),
        lang = prefs.getString("lang", "en")?.takeIf { it in LANGS } ?: "en",
        sounds = prefs.getBoolean("sounds", true),
        music = prefs.getBoolean("music", true),
        set = prefs.getBoolean("set", false),
    )

    override fun put(s: LearnSettings) {
        prefs.edit()
            .putInt("grade", s.grade)
            .putString("lang", s.lang)
            .putBoolean("sounds", s.sounds)
            .putBoolean("music", s.music)
            .putBoolean("set", s.set)
            .apply()
    }

    companion object { val LANGS = setOf("en", "hi", "enHi") }
}
