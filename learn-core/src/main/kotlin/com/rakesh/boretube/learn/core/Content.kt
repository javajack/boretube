package com.rakesh.boretube.learn.core

import kotlinx.serialization.Serializable
import kotlin.random.Random

/** A written question bank: one subject, one class (spec §4). */
@Serializable
data class Pack(
    val id: String,
    /** english | evs */
    val subject: String,
    /** CBSE class, 0 = KG. */
    val grade: Int,
    val version: Int = 1,
    /** Set once a grown-up has read the review page; only reviewed packs reach the TV. */
    val reviewed: Reviewed = Reviewed(),
    val skills: List<PackSkillDoc>,
)

@Serializable
data class Reviewed(val by: String = "", val at: String = "") {
    val done: Boolean get() = by.isNotBlank()
}

@Serializable
data class PackSkillDoc(
    val id: String,
    val title: String,
    /** NCERT learning-outcome code (our index, content/outcomes.md). */
    val outcome: String,
    /** The short mark inside the path node. */
    val badge: String,
    /** quickfire | catch, in rotation. */
    val formats: List<String> = listOf("quickfire"),
    val items: List<Item>,
)

@Serializable
data class Item(
    val id: String,
    val q: String,
    val qHi: String? = null,
    val options: List<String>,
    val answer: Int,
    val explain: String,
    /** The full fact for "Yes!" and the learn screen (default: the answer). */
    val fact: String? = null,
    /** A picture id from the app's library. */
    val picture: String? = null,
    val speak: String? = null,
    val speakHi: String? = null,
)

/** Checks a pack the way spec §4 asks. Empty list = good. */
object PackValidator {
    val SUBJECTS = setOf("english", "evs")
    val FORMATS = setOf("quickfire", "catch")
    const val MIN_ITEMS = 24
    private val JARGON = listOf("commutative", "numerator", "denominator", "associative", "quotient", "dividend", "integer", "operand")

    fun check(p: Pack, pictures: Set<String>): List<String> {
        val e = mutableListOf<String>()
        if (p.subject !in SUBJECTS) e += "${p.id}: subject must be english|evs"
        if (p.grade !in 0..Maths.MAX_GRADE) e += "${p.id}: grade must be 0..7"
        val skillIds = HashSet<String>()
        for (s in p.skills) {
            if (!skillIds.add(s.id)) e += "${p.id}/${s.id}: skill id repeats"
            if (':' in s.id) e += "${p.id}/${s.id}: no ':' in skill ids"
            if (s.items.size < MIN_ITEMS) e += "${p.id}/${s.id}: needs at least $MIN_ITEMS items (has ${s.items.size})"
            if (s.formats.isEmpty() || !FORMATS.containsAll(s.formats)) e += "${p.id}/${s.id}: formats must be quickfire|catch"
            val itemIds = HashSet<String>()
            for (i in s.items) {
                val w = "${p.id}/${s.id}/${i.id}"
                if (!itemIds.add(i.id)) e += "$w: item id repeats"
                if (i.options.size !in 2..4) e += "$w: needs 2-4 options"
                if (i.options.toSet().size != i.options.size) e += "$w: options repeat"
                if (i.answer !in i.options.indices) e += "$w: answer index out of range"
                if ("catch" in s.formats && (i.options.size < 3 || i.options.any { it.length > 12 })) e += "$w: catch needs 3+ short options"
                if (Maths.wordCount(i.explain) > Maths.MAX_EXPLAIN_WORDS) e += "$w: explanation over 12 words"
                if (!i.explain.endsWith(".") || Regex("[.!?]\\s").containsMatchIn(i.explain)) e += "$w: explanation must be one sentence"
                if (JARGON.any { it in i.explain.lowercase() }) e += "$w: jargon in explanation"
                if (i.picture != null && i.picture !in pictures) e += "$w: unknown picture ${i.picture}"
                for (o in i.options.filter { it.startsWith("pic:") }) {
                    if (o.removePrefix("pic:") !in pictures) e += "$w: unknown picture option $o"
                    if ("catch" in s.formats) e += "$w: catch can't show picture options"
                }
            }
        }
        return e
    }
}

/** A skill: the maths ladder's generators, or a written bank. What levels and the town need. */
interface SkillSource {
    val id: String
    val grade: Int
    val title: String
    val badge: String
    /** maths | english | evs */
    val subject: String
    /** Formats in rotation (one per play). */
    val formats: List<Format>
    fun next(r: Random): Question
    /** Rebuilds the question a key names (spaced repetition), or null. */
    fun build(key: String, r: Random): Question?
    fun easier(q: Question, r: Random): Question?
}

private class MathsSource(private val s: Skill) : SkillSource {
    override val id = s.id
    override val grade = s.grade
    override val title = s.title
    override val badge = MATHS_BADGES[s.id] ?: "?"
    override val subject = "maths"
    override val formats: List<Format> = when (s.id) {
        "placeValue" -> listOf(Format.build, Format.quickfire)
        in QUICKFIRE_ONLY -> listOf(Format.quickfire)
        else -> listOf(Format.catch, Format.pairs)
    }
    override fun next(r: Random) = s.next(r)
    override fun build(key: String, r: Random) = Maths.fromKey(key, r)
    override fun easier(q: Question, r: Random) = Maths.easierThan(q, r)

    companion object {
        /** Clocks, pies, pictures and comparisons can't be Catch or Pairs. */
        val QUICKFIRE_ONLY = setOf("clock", "fractions", "decimals", "count10", "biggest10", "next20")
        val MATHS_BADGES = mapOf(
            "count10" to "123", "biggest10" to "5>2", "add10" to "2+3", "sub10" to "5−2", "next20" to "19",
            "make10" to "9+6", "placeValue" to "47", "add100" to "+99", "tablesLow" to "×5", "money" to "₹",
            "clock" to "3:30", "tablesHigh" to "×7", "divide" to "÷", "mul21" to "23×4", "fractions" to "¾",
            "halfOf" to "½", "decimals" to "0.5", "percent" to "%", "negatives" to "−3", "equations" to "x",
        )
    }
}

private class PackSource(private val pack: Pack, private val doc: PackSkillDoc) : SkillSource {
    override val id = doc.id
    override val grade = pack.grade
    override val title = doc.title
    override val badge = doc.badge
    override val subject = pack.subject
    override val formats = doc.formats.mapNotNull { f -> Format.entries.firstOrNull { it.name == f } }.ifEmpty { listOf(Format.quickfire) }

    private fun question(i: Item, r: Random): Question {
        val right = i.options[i.answer]
        val opts = i.options.shuffled(r)
        val pic = i.picture?.let { Visual.Picture(it) }
        return Question(
            key = "$id:${i.id}", skill = id, prompt = i.q, promptHi = i.qHi,
            spoken = i.speak ?: i.q, spokenHi = i.speakHi ?: i.qHi,
            options = opts, answer = opts.indexOf(right), fact = i.fact ?: right,
            explain = i.explain, visual = pic, learnVisual = pic,
        )
    }

    override fun next(r: Random) = question(doc.items.random(r), r)
    override fun build(key: String, r: Random): Question? =
        doc.items.firstOrNull { "$id:${it.id}" == key }?.let { question(it, r) }
    override fun easier(q: Question, r: Random): Question? =
        doc.items.filter { "$id:${it.id}" != q.key }.randomOrNull(r)?.let { question(it, r) }
}

/** Every skill the app knows: the maths ladder plus the reviewed banks. */
class Catalog(val sources: List<SkillSource>) {
    private val byId = sources.associateBy { it.id }

    fun skill(id: String): SkillSource? = byId[id]
    fun fromKey(key: String, r: Random): Question? = skill(key.substringBefore(':'))?.build(key, r)
    fun easierThan(q: Question, r: Random): Question? = skill(q.skill)?.easier(q, r)

    /** A subject's skills, easy to hard (class, then order in the pack). */
    fun bySubject(subject: String): List<SkillSource> =
        sources.withIndex().filter { it.value.subject == subject }.sortedWith(compareBy({ it.value.grade }, { it.index })).map { it.value }

    companion object {
        val MATHS = Catalog(Maths.LADDER.map { MathsSource(it) })

        fun of(packs: List<Pack>) = Catalog(MATHS.sources + packs.flatMap { p -> p.skills.map { PackSource(p, it) } })
    }
}
