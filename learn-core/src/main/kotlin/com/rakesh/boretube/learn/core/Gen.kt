package com.rakesh.boretube.learn.core

import kotlin.random.Random

/**
 * One kind of generated question: a grid of seeds ([dims], each 0 until n)
 * and how to build the question a seed names. [build] returns null for a
 * seed that makes no good question (a word without a plural, a repeat);
 * those are skipped, never shown.
 */
class Template(
    val id: String,
    /** 1 easy, 2 medium, 3 hard. */
    val tier: Int,
    val dims: IntArray,
    /**
     * The level format these questions are made for: quickfire (any 2–4
     * options, also Catch and Pairs), truefalse, sort (two fixed baskets) or
     * order.
     */
    val kind: Format = Format.quickfire,
    val build: (IntArray, Random) -> Question?,
) {
    init { require(':' !in id) { "no ':' in template ids" } }

    /** Seeds in the grid (some may build null). */
    val size: Long get() = dims.fold(1L) { a, n -> a * n }

    fun random(r: Random): IntArray = IntArray(dims.size) { r.nextInt(dims[it]) }

    /** Every seed, in order (tests and counts). */
    fun seeds(): Sequence<IntArray> = sequence {
        if (dims.any { it <= 0 }) return@sequence
        val p = IntArray(dims.size)
        while (true) {
            yield(p.copyOf())
            var i = dims.size - 1
            while (i >= 0) {
                p[i]++
                if (p[i] < dims[i]) break
                p[i] = 0
                i--
            }
            if (i < 0) return@sequence
        }
    }
}

/**
 * A skill made by generators over word lists and fact tables (spec §4b).
 * Keys are `<skill>:<template>:<seed…>`, so a missed question comes back
 * as itself (with fresh wrong options).
 */
class GenSkill(
    override val id: String,
    override val grade: Int,
    override val subject: String,
    override val title: String,
    override val badge: String,
    val templates: List<Template>,
    /** Formats in rotation; by default the kinds its templates make. */
    override val formats: List<Format> = templates.map { it.kind }.distinct(),
    /** What the skill is about, in a few words (the path and the phone). */
    val strand: String = "",
) : SkillSource {
    init {
        require(':' !in id) { "no ':' in skill ids" }
        require(templates.isNotEmpty()) { "$id: no templates" }
        require(templates.map { it.id }.toSet().size == templates.size) { "$id: template ids repeat" }
    }

    private val byId = templates.associateBy { it.id }

    override val tiers: Int = templates.maxOf { it.tier }

    override fun next(r: Random): Question = next(r, 1)

    override fun next(r: Random, tier: Int): Question = next(r, tier, null)

    /**
     * A question at [tier] (the nearest tier the skill has) made for
     * [format]: Catch and Pairs use quickfire templates; null takes any kind
     * but order.
     */
    override fun next(r: Random, tier: Int, format: Format?): Question {
        val kind = when (format) {
            null -> null
            Format.catch, Format.pairs, Format.build -> Format.quickfire
            else -> format
        }
        val fit = templates.filter { if (kind == null) it.kind != Format.order else it.kind == kind }.ifEmpty { templates }
        val t = tier.coerceIn(1, fit.maxOf { it.tier })
        val pool = fit.filter { it.tier == t }.ifEmpty { fit.filter { it.tier <= t }.ifEmpty { fit } }
        repeat(60) {
            val tp = pick(pool, r)
            make(tp, tp.random(r), r)?.let { return it }
        }
        // Small or sparse grids: walk them instead of guessing.
        for (tp in pool.shuffled(r)) for (s in tp.seeds()) make(tp, s, r)?.let { return it }
        error("$id: no question at tier $t")
    }

    /** Weighted by grid size, so every seed is about as likely. */
    private fun pick(pool: List<Template>, r: Random): Template {
        val total = pool.sumOf { it.size.toDouble() }
        var x = r.nextDouble() * total
        for (t in pool) {
            x -= t.size
            if (x <= 0) return t
        }
        return pool.last()
    }

    private fun make(t: Template, seed: IntArray, r: Random): Question? =
        try {
            t.build(seed, r)?.copy(key = key(t, seed), skill = id, tier = t.tier)
        } catch (_: IndexOutOfBoundsException) {
            null
        }

    fun key(t: Template, seed: IntArray) = (listOf(id, t.id) + seed.map { "$it" }).joinToString(":")

    override fun build(key: String, r: Random): Question? {
        val parts = key.split(":")
        if (parts.size < 2 || parts[0] != id) return null
        val t = byId[parts[1]] ?: return null
        val seed = parts.drop(2).map { it.toIntOrNull() ?: return null }.toIntArray()
        if (seed.size != t.dims.size || seed.indices.any { seed[it] !in 0 until t.dims[it] }) return null
        return make(t, seed, r)
    }

    /** One tier down, same kind of question (or another at tier 1). */
    override fun easier(q: Question, r: Random): Question? {
        val down = (q.tier - 1).coerceAtLeast(1)
        val kind = byId[q.key.split(":").getOrElse(1) { "" }]?.kind
        repeat(10) { val e = next(r, down, kind); if (e.key != q.key) return e }
        return null
    }

    /** Sort: a level's cards share one pair of baskets, so they come from one template. */
    fun sortSet(n: Int, tier: Int, r: Random): List<Question> {
        val sorts = templates.filter { it.kind == Format.sort }
        if (sorts.isEmpty()) return emptyList()
        val t = tier.coerceIn(1, sorts.maxOf { it.tier })
        val pool = sorts.filter { it.tier == t }.ifEmpty { sorts }
        val tp = pick(pool, r)
        val out = LinkedHashMap<String, Question>()
        repeat(n * 30) {
            if (out.size >= n) return out.values.toList()
            make(tp, tp.random(r), r)?.let { out.putIfAbsent(it.key, it) }
        }
        return out.values.toList()
    }

    /** Every question the skill can ask (tests and the volume report). */
    fun all(r: Random = Random(0)): Sequence<Question> =
        templates.asSequence().flatMap { t -> t.seeds().mapNotNull { make(t, it, r) } }
}

/** Helpers for generators: options from a pool, never repeating the answer. */
object Opt {
    /** [answer] plus up to [count] − 1 distinct [wrongs] (in order of preference), shuffled. */
    fun of(answer: String, wrongs: List<String>, r: Random, count: Int = 4): Pair<List<String>, Int>? {
        val w = LinkedHashSet<String>()
        for (x in wrongs) if (!x.equals(answer, ignoreCase = true) && w.size < count - 1) w += x
        if (w.size < minOf(count - 1, 1)) return null
        val all = (w + answer).toList().shuffled(r)
        return all to all.indexOf(answer)
    }

    /** True / False, always in that order. */
    fun trueFalse(isTrue: Boolean): Pair<List<String>, Int> = listOf("True", "False") to if (isTrue) 0 else 1

    /** Two baskets, always in the given order (Sort keeps left and right fixed). */
    fun baskets(left: String, right: String, isLeft: Boolean): Pair<List<String>, Int> =
        listOf(left, right) to if (isLeft) 0 else 1

    /** Picks [n] distinct items from [pool] by a seed ([s] steps through the pool). */
    fun <T> spread(pool: List<T>, n: Int, s: Int): List<T> {
        if (pool.size < n) return emptyList()
        val out = ArrayList<T>(n)
        val step = 1 + (s % maxOf(1, pool.size - 1))
        var i = s % pool.size
        val used = HashSet<Int>()
        while (out.size < n && used.size < pool.size) {
            while (i in used) i = (i + 1) % pool.size
            used += i
            out += pool[i]
            i = (i + step) % pool.size
        }
        return out
    }
}

/** Builds a question; generators fill key, skill and tier through [GenSkill]. */
fun gq(
    prompt: String,
    opts: Pair<List<String>, Int>,
    explain: String,
    fact: String = opts.first[opts.second],
    spoken: String = prompt,
    visual: Visual? = null,
    order: List<String>? = null,
): Question = Question(
    key = "", skill = "", prompt = prompt, promptHi = null, spoken = spoken, spokenHi = null,
    options = opts.first, answer = opts.second, fact = fact, explain = explain,
    visual = visual, learnVisual = visual, order = order,
)
