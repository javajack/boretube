package com.rakesh.boretube.learn.core

/** Maths symbols as words, so text-to-speech doesn't say "multiplication sign". */
object Speakable {
    private val EN = listOf("×" to " times ", "÷" to " divided by ", "−" to " minus ", "+" to " plus ", "=" to " is ")
    private val HI = listOf("×" to " गुणा ", "÷" to " भाग ", "−" to " घटा ", "+" to " जोड़ ", "=" to " बराबर ")

    fun of(t: String, hindi: Boolean): String {
        var s = t
        for ((a, b) in if (hindi) HI else EN) s = s.replace(a, b)
        return s.replace(Regex("\\s+"), " ").trim()
    }
}
