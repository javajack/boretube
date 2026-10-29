package com.rakesh.boretube.learn.core

import kotlin.random.Random

/**
 * The checks every generated question must pass (spec P2b §6). Run over
 * every question of every skill by the unit tests; an empty list is good.
 */
object GenChecks {
    const val MAX_PROMPT = 90
    const val MAX_STORY_PROMPT = 140
    const val MAX_OPTION = 24
    const val MAX_CATCH_OPTION = 12

    private val JARGON = listOf("commutative", "numerator", "denominator", "associative", "quotient", "dividend", "operand")

    /** US spellings children's text must not use (CBSE uses British). */
    private val US = Regex(
        "\\b(color|colors|colored|favorite|favorites|center|centers|meter|meters|liter|liters|theater|neighbor|neighbors|" +
            "flavor|honor|humor|labor|odor|behavior|organize|organized|realize|realized|recognize|apologize|" +
            "mom|moms|math|gray|airplane|jewelry|traveler|traveling|catalog|program|tire|tires|aluminum|" +
            "fall season|cookie|cookies|candy|eraser is|vacation|pants)\\b",
        RegexOption.IGNORE_CASE,
    )

    fun question(s: SkillSource, q: Question): List<String> {
        val e = mutableListOf<String>()
        val w = "${q.key} \"${q.prompt}\""
        if (!q.key.startsWith("${s.id}:")) e += "$w: key must start with the skill id"
        if (q.options.size !in 2..5) e += "$w: needs 2-5 options"
        if (q.options.map { it.lowercase().trim() }.toSet().size != q.options.size) e += "$w: options repeat"
        if (q.answer !in q.options.indices) e += "$w: answer out of range"
        if (q.options.any { it.isBlank() }) e += "$w: blank option"
        if (q.prompt.isBlank()) e += "$w: blank prompt"
        val story = q.prompt.length > MAX_PROMPT
        if (q.prompt.length > MAX_STORY_PROMPT) e += "$w: prompt over $MAX_STORY_PROMPT chars"
        if (story && Format.catch in s.formats) e += "$w: long prompt in a Catch skill"
        if (q.options.any { it.length > MAX_OPTION } && q.order == null) e += "$w: option over $MAX_OPTION chars"
        if (Format.catch in s.formats && q.options.any { it.length > MAX_CATCH_OPTION }) e += "$w: catch option over $MAX_CATCH_OPTION chars"
        if (Maths.wordCount(q.explain) > Maths.MAX_EXPLAIN_WORDS) e += "$w: explanation over 12 words: ${q.explain}"
        if (!q.explain.endsWith(".") || Regex("[.!?]\\s").containsMatchIn(q.explain)) e += "$w: explanation must be one sentence ending in a full stop: ${q.explain}"
        if (JARGON.any { it in q.explain.lowercase() }) e += "$w: jargon in explanation"
        val text = listOf(q.prompt, q.explain, q.fact, q.spoken) + q.options
        for (t in text) US.find(t)?.let { e += "$w: US spelling \"${it.value}\"" }
        if (q.tier !in 1..3) e += "$w: tier must be 1..3"
        val ord = q.order
        if (ord != null) {
            if (ord.size !in 3..5) e += "$w: order needs 3-5 items"
            if (ord.toSet().size != ord.size) e += "$w: order items repeat"
            if (q.options.sorted() != ord.sorted()) e += "$w: options must be the order items, shuffled"
            if (ord.any { it.length > 28 }) e += "$w: order item over 28 chars"
        }
        return e
    }

    /** Every question of [s]: per-question checks, repeats, format shapes. */
    fun skill(s: GenSkill, r: Random = Random(7)): List<String> {
        val e = mutableListOf<String>()
        val keys = HashSet<String>()
        val pairs = HashSet<String>()
        val basketsByTemplate = HashMap<String, Set<String>>()
        var n = 0
        val tiers = HashSet<Int>()
        for (q in s.all(r)) {
            n++
            tiers += q.tier
            e += question(s, q)
            if (!keys.add(q.key)) e += "${q.key}: key repeats"
            val pa = "${q.prompt}|${q.answerText}|${q.order}"
            if (!pairs.add(pa)) e += "${q.key}: same prompt and answer as another question: ${q.prompt}"
            val tmpl = q.key.split(":").getOrElse(1) { "" }
            if (Format.sort in s.formats && q.options.size == 2 && q.order == null) {
                val set = q.options.toSet()
                val had = basketsByTemplate.putIfAbsent(tmpl, set)
                if (had != null && had != set) e += "${q.key}: sort baskets differ within template $tmpl"
            }
            if (Format.truefalse in s.formats && q.options.size == 2 && q.options.toSet() == setOf("True", "False")) {
                if (q.options != listOf("True", "False")) e += "${q.key}: True must come before False"
            }
            if (e.size > 50) return e
        }
        if (n < MIN_QUESTIONS) e += "${s.id}: only $n questions (needs $MIN_QUESTIONS)"
        if (tiers.size < 2) e += "${s.id}: needs at least 2 tiers (has $tiers)"
        if (Format.sort in s.formats && s.all(r).none { it.options.size == 2 && it.order == null }) e += "${s.id}: sort format but no 2-option questions"
        if (Format.order in s.formats && s.all(r).none { it.order != null }) e += "${s.id}: order format but no order questions"
        if (Format.truefalse in s.formats && s.all(r).none { it.options == listOf("True", "False") }) e += "${s.id}: truefalse format but no True/False questions"
        return e
    }

    /** Distinct questions a skill can ask. */
    fun count(s: GenSkill): Int = s.all(Random(0)).count()

    const val MIN_QUESTIONS = 200
}
