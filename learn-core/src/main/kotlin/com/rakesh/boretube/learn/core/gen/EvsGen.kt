package com.rakesh.boretube.learn.core.gen

import com.rakesh.boretube.learn.core.Format
import com.rakesh.boretube.learn.core.GenSkill
import com.rakesh.boretube.learn.core.Opt
import com.rakesh.boretube.learn.core.Template
import com.rakesh.boretube.learn.core.Visual
import com.rakesh.boretube.learn.core.gq
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlin.random.Random

/**
 * Generated EVS skills, KG to Class 5 (spec P2b). Every question comes from
 * the fact tables in `content/data/evs.json` (built by
 * `boretube-learn/tools/content/data/evs_data.py`). A missing field there
 * means "unknown or arguable", so it is never asked; wrong options are taken
 * only from rows that are surely wrong.
 */
/**
 * Animal pictures only: an animal row must never show a food or a thing
 * (the kiwi bird once borrowed the kiwi fruit's picture).
 */
private val ANIMAL_PICS = setOf(
    "fish", "cat", "dog", "cow", "bird", "ant",
    "lion", "tiger", "elephant", "monkey", "horse", "goat", "sheep", "pig", "hen", "duck", "frog", "snake", "butterfly", "bee",
    "rabbit", "deer", "camel", "giraffe", "zebra", "bear", "owl", "parrot", "peacock", "crow", "eagle", "penguin", "turtle", "crab",
    "snail", "spider", "mouse", "squirrel", "buffalo", "donkey", "lizard", "caterpillar", "tadpole", "chick", "puppy", "kitten", "calf",
    "leopard", "wolf", "fox", "kangaroo", "hippo", "rhino", "crocodile", "cheetah", "panda", "koala", "gorilla", "bat", "hedgehog", "ox", "yak",
    "sparrow", "pigeon", "kingfisher", "flamingo", "ostrich", "swan", "woodpecker", "vulture",
    "mosquito", "housefly", "ladybird", "dragonfly", "grasshopper", "earthworm", "cockroach",
    "octopus", "starfish", "jellyfish", "dolphin", "whale", "shark", "seahorse", "prawn",
)

object EvsGen {
    internal val json = Json { ignoreUnknownKeys = true }

    fun skills(data: (String) -> String?): List<GenSkill> {
        val text = data("evs.json") ?: return emptyList()
        val d = json.decodeFromString(EvsData.serializer(), text)
        return EvsSkills(d.copy(animals = d.animals.map { a -> if (a.pic != null && a.pic !in ANIMAL_PICS) a.copy(pic = null) else a })).all()
    }
}

// ------------------------------------------------------------------ tables

@Serializable
private data class EAnimal(
    val n: String, val an: Boolean = false, val pl: String = "", val group: String = "", val contested: Boolean = false,
    val kg: Boolean = false, val both: Boolean = false, val hab: List<String> = emptyList(), val home: List<String> = emptyList(),
    val food: String? = null, val cover: String? = null, val young: String? = null, val legs: Int? = null,
    val birth: String? = null, val kind: String? = null, val size: Int? = null, val flies: Boolean? = null,
    val sound: String? = null, val noise: String? = null, val beak: String? = null, val feet: String? = null,
    val moves: List<String> = emptyList(), val cannot: List<String> = emptyList(), val pic: String? = null,
)

@Serializable
private data class EPlant(
    val n: String, val an: Boolean = false, val type: String? = null, val uses: List<String> = emptyList(),
    val seeds: String? = null, val why: String? = null, val none: Boolean = false, val pic: String? = null,
)

@Serializable
private data class EFood(
    val n: String, val form: String = "s", val an: Boolean = false, val fv: String? = null, val src: String? = null,
    val part: String? = null, val rich: List<String> = emptyList(), val poor: List<String> = emptyList(),
    val cook: String? = null, val method: String? = null, val health: String? = null, val taste: List<String> = emptyList(),
    val pic: String? = null,
)

@Serializable
private data class EObject(
    val n: String, val form: String = "s", val an: Boolean = false, val made: List<String> = emptyList(),
    val magnetic: Boolean? = null, val seeThrough: Boolean? = null, val floats: Boolean? = null, val waste: String? = null,
    val natural: Boolean? = null, val feel: String? = null, val pic: String? = null,
)

@Serializable private data class ENamedWhy(val n: String, val why: String = "", val pic: String? = null)

@Serializable
private data class EHelper(
    val n: String, val an: Boolean = false, val tools: List<String> = emptyList(), val places: List<String> = emptyList(),
    val does: List<String> = emptyList(), val makes: String? = null, val pic: String? = null,
)

@Serializable
private data class ETransport(val n: String, val an: Boolean = false, val mode: String = "", val wheels: Int? = null, val power: String? = null, val pic: String? = null)

@Serializable private data class EBodyPart(val n: String, val count: Int? = null, val ask: String? = null, val pic: String? = null)
@Serializable private data class EBodyUse(val verb: String, val parts: List<String>)
@Serializable private data class EWear(val thing: String, val part: String)

@Serializable
private data class EHouse(val n: String, val an: Boolean = false, val kind: String? = null, val made: List<String> = emptyList(), val features: List<String> = emptyList(), val pic: String? = null)
@Serializable private data class EHouseFeature(val key: String, val text: String, val why: String)
@Serializable private data class EKind(val n: String, val kind: String)

@Serializable
private data class EState(val n: String, val kind: String, val capital: String? = null, val languages: List<String> = emptyList(), val dances: List<String> = emptyList(), val festivals: List<String> = emptyList())

@Serializable
private data class EFestival(val n: String, val month: String? = null, val date: String? = null, val foods: List<String> = emptyList(), val features: List<String> = emptyList(), val maybe: List<String> = emptyList(), val pic: String? = null)
@Serializable private data class EFeature(val key: String, val text: String)
@Serializable private data class ESeasonItem(val we: String, val seasons: List<String>)
@Serializable private data class EWeather(val n: String, val days: List<String> = emptyList(), val never: List<String> = emptyList(), val worn: Boolean = false, val pic: String? = null)
@Serializable private data class EMonth(val n: String, val days: Int)
@Serializable private data class EWaterSource(val n: String, val natural: Boolean, val salty: Boolean, val pic: String? = null)

/** Yes/no scenario rows (save water, habits, safety, ...): one flag is set. */
@Serializable
private data class EFlag(
    val n: String, val safe: Boolean? = null, val saves: Boolean? = null, val good: Boolean? = null, val fast: Boolean? = null,
    val renewable: Boolean? = null, val stops: Boolean? = null, val pic: String? = null,
)

@Serializable private data class ESignal(val colour: String, val means: String)
@Serializable private data class EDayNight(val n: String, val `when`: String)
@Serializable private data class ESequence(val key: String, val ask: String, val steps: List<String>)
@Serializable private data class EThenNow(val old: String, val new: String, val use: String)
@Serializable private data class EKeep(val n: String, val ways: List<String>)
@Serializable private data class EChange(val n: String, val change: String)
@Serializable private data class EEats(val n: String, val food: List<String>)
@Serializable private data class EPlanet(val n: String, val facts: List<String>, val pic: String? = null)
@Serializable private data class ECycle(val n: String, val steps: List<String>)
@Serializable private data class EOrgan(val n: String, val form: String = "s", val jobs: List<String> = emptyList(), val count: Int? = null, val pic: String? = null)
@Serializable private data class EUse(val n: String, val uses: String, val pic: String? = null)
@Serializable private data class EDisease(val n: String, val by: String)
@Serializable private data class EName(val n: String, val girl: Boolean)

@Serializable
private data class EvsData(
    val animals: List<EAnimal> = emptyList(),
    val plants: List<EPlant> = emptyList(),
    val foods: List<EFood> = emptyList(),
    val objects: List<EObject> = emptyList(),
    val nonlivingTricky: List<ENamedWhy> = emptyList(),
    val helpers: List<EHelper> = emptyList(),
    val toolPics: Map<String, String> = emptyMap(),
    val placePics: Map<String, String> = emptyMap(),
    val transport: List<ETransport> = emptyList(),
    val bodyParts: List<EBodyPart> = emptyList(),
    val bodyUses: List<EBodyUse> = emptyList(),
    val wear: List<EWear> = emptyList(),
    val houses: List<EHouse> = emptyList(),
    val houseFeatures: List<EHouseFeature> = emptyList(),
    val houseMaterials: List<String> = emptyList(),
    val kutchaPucca: List<EKind> = emptyList(),
    val india: List<EState> = emptyList(),
    val classicalDances: List<String> = emptyList(),
    val festivals: List<EFestival> = emptyList(),
    val festivalFeatures: List<EFeature> = emptyList(),
    val seasonItems: List<ESeasonItem> = emptyList(),
    val weather: List<EWeather> = emptyList(),
    val weatherWords: Map<String, String> = emptyMap(),
    val months: List<EMonth> = emptyList(),
    val days: List<String> = emptyList(),
    val waterSources: List<EWaterSource> = emptyList(),
    val safeWater: List<EFlag> = emptyList(),
    val saveWater: List<EFlag> = emptyList(),
    val habits: List<EFlag> = emptyList(),
    val safety: List<EFlag> = emptyList(),
    val signals: List<ESignal> = emptyList(),
    val dayNight: List<EDayNight> = emptyList(),
    val sequences: List<ESequence> = emptyList(),
    val thenNow: List<EThenNow> = emptyList(),
    val keepFood: List<EKeep> = emptyList(),
    val keepWays: Map<String, String> = emptyMap(),
    val spoils: List<EFlag> = emptyList(),
    val waterChanges: List<EChange> = emptyList(),
    val waterCycle: List<String> = emptyList(),
    val eats: List<EEats> = emptyList(),
    val producers: List<String> = emptyList(),
    val herbivores: List<String> = emptyList(),
    val carnivores: List<String> = emptyList(),
    val planets: List<EPlanet> = emptyList(),
    val lifeCycles: List<ECycle> = emptyList(),
    val stepPics: Map<String, String> = emptyMap(),
    val youngPics: Map<String, String> = emptyMap(),
    val wearPics: Map<String, String> = emptyMap(),
    val organs: List<EOrgan> = emptyList(),
    val digestion: List<String> = emptyList(),
    val breathing: List<String> = emptyList(),
    val energy: List<EFlag> = emptyList(),
    val saveEnergy: List<EFlag> = emptyList(),
    val energyUses: List<EUse> = emptyList(),
    val diseases: List<EDisease> = emptyList(),
    val spread: Map<String, String> = emptyMap(),
    val germs: List<EFlag> = emptyList(),
    val names: List<EName> = emptyList(),
)

// ------------------------------------------------------------------ question shapes

/** A thing that can be an option: its words, and its picture (if the app draws one). */
private class Th(val name: String, val pic: String? = null)

/** Quick-fire: [ans] plus wrong options drawn (fresh each time) from [wrongs], or exactly [fixed]. */
private class QF(
    val prompt: String, val ans: String, val wrongs: List<String>, val explain: String, val fact: String,
    val pic: String? = null, val fixed: List<String>? = null,
)

private class TF(val text: String, val truth: Boolean, val explain: String, val pic: String? = null)
private class SO(val text: String, val left: Boolean, val explain: String, val pic: String? = null)
private class OR(val prompt: String, val steps: List<String>, val explain: String, val pic: String? = null)

/** Builds one skill: templates from question lists, no repeats, formats from what it holds. */
private class SB(val id: String, val grade: Int, val title: String, val badge: String, val strand: String) {
    /** Picture options ("pic:<id>") where every option has its own picture. */
    val pics = true
    val ts = mutableListOf<Template>()
    internal val seen = HashSet<String>()
    private var maxOpt = 0
    private var picOpts = false

    internal fun note(opts: Collection<String>) {
        for (o in opts) {
            if (o.startsWith("pic:")) picOpts = true else maxOpt = maxOf(maxOpt, o.length)
        }
    }

    internal fun <T> add(tid: String, tier: Int, kind: Format, items: List<T>, make: (T, Random) -> com.rakesh.boretube.learn.core.Question) {
        if (items.isEmpty()) return
        items.chunked(4500).forEachIndexed { i, part ->
            var id = if (i == 0) tid else "$tid$i"
            while (ts.any { it.id == id }) id += "x"
            ts += Template(id, tier, intArrayOf(part.size), kind) { s, r -> make(part[s[0]], r) }
        }
    }

    fun qf(tid: String, tier: Int, all: List<QF>) {
        val items = all.mapNotNull { q ->
            if (q.ans.length > 24) null
            else if (q.fixed != null) q.takeIf { it.fixed!!.all { o -> o.length <= 24 } }
            else QF(q.prompt, q.ans, q.wrongs.filter { it.length <= 24 }, q.explain, q.fact, q.pic)
        }
        val f = items.filter { q ->
            (q.fixed != null || q.wrongs.size >= 2) && q.prompt.length <= 90 && seen.add("${q.prompt}|${q.ans}")
        }
        for (q in f) note((q.fixed ?: q.wrongs) + q.ans)
        add(tid, tier, Format.quickfire, f) { q, r ->
            val opts = if (q.fixed != null) {
                val o = q.fixed.shuffled(r)
                o to o.indexOf(q.ans)
            } else Opt.of(q.ans, q.wrongs.shuffled(r), r)!!
            gq(q.prompt, opts, q.explain, fact = q.fact, visual = q.pic?.let { Visual.Picture(it) })
        }
    }

    fun tf(tid: String, tier: Int, items: List<TF>) {
        val f = items.filter { it.text.length <= 90 && seen.add("${it.text}|${it.truth}") }
        add(tid, tier, Format.truefalse, f) { q, _ ->
            gq(q.text, Opt.trueFalse(q.truth), q.explain, fact = q.explain, visual = q.pic?.let { Visual.Picture(it) })
        }
    }

    fun sort(tid: String, tier: Int, left: String, right: String, items: List<SO>) {
        val f = items.filter { seen.add("${it.text}|${if (it.left) left else right}") }
        if (f.size < 8 || f.none { it.left } || f.all { it.left }) return
        note(listOf(left, right))
        add(tid, tier, Format.sort, f) { q, _ ->
            gq(q.text, Opt.baskets(left, right, q.left), q.explain, visual = q.pic?.let { Visual.Picture(it) })
        }
    }

    fun order(tid: String, tier: Int, items: List<OR>) {
        val f = items.filter { it.steps.size in 3..5 && it.steps.all { s -> s.length <= 28 } && seen.add("${it.prompt}|${it.steps}") }
        for (q in f) note(q.steps)
        add(tid, tier, Format.order, f) { q, r ->
            val shuffled = q.steps.shuffled(r).let { if (it == q.steps) it.reversed() else it }
            gq(q.prompt, shuffled to shuffled.indexOf(q.steps[0]), q.explain, fact = q.steps.joinToString(", "),
                visual = q.pic?.let { Visual.Picture(it) }, order = q.steps)
        }
    }

    fun build(): GenSkill? {
        if (ts.none { it.kind == Format.quickfire || it.kind == Format.truefalse }) return null
        val kinds = listOf(Format.quickfire, Format.truefalse, Format.sort, Format.order).filter { k -> ts.any { it.kind == k } }
        val catch = !picOpts && maxOpt in 1..12 && ts.any { it.kind == Format.quickfire }
        val formats = if (catch) kinds.take(1) + Format.catch + kinds.drop(1) else kinds
        return GenSkill(id, grade, "evs", title, badge, ts.toList(), formats, strand)
    }
}

// ------------------------------------------------------------------ words

private fun cap(s: String) = s.replaceFirstChar { it.uppercase() }
private fun art(n: String, an: Boolean) = (if (an) "an " else "a ") + n
private fun aOf(n: String) = art(n, n.first().lowercaseChar() in "aeiou")

/** A noun as a subject: "A mango", "Grapes", "Rice"; and its verbs. */
private class Noun(val name: String, val form: String, an: Boolean) {
    val plural = form == "pl"
    val obj = when (form) { "s" -> art(name, an); else -> name }
    val subj = cap(obj)
    val be = if (plural) "are" else "is"
    val has = if (plural) "have" else "has"
    val its = if (plural) "their" else "its"
    fun v(one: String, many: String) = if (plural) many else one
}

/** Picks a wrong option list: pictures when the answer and 3+ wrongs have their own, else words. */
private fun SB.choice(prompt: String, ans: Th, pool: List<Th>, explain: String, fact: String = cap(ans.name), visual: String? = null): QF {
    if (pics && ans.pic != null) {
        val wp = pool.mapNotNull { it.pic }.filter { it != ans.pic }.distinct()
        if (wp.size >= 3) return QF(prompt, "pic:${ans.pic}", wp.map { "pic:$it" }, explain, fact, visual)
    }
    val w = pool.map { it.name }.filter { !it.equals(ans.name, ignoreCase = true) }.distinct()
    return QF(prompt, ans.name, w, explain, fact, visual)
}

/**
 * Odd one out over seeded trios: "Which one is not a bird: crow, owl, cow or myna?".
 * The odd thing is the answer; the prompt names all four, so each set is its own question.
 */
private fun SB.odd(label: String, group: List<Th>, odds: List<Th>, explain: (Th) -> String, perOdd: Int = 12, needPics: Boolean = true): List<QF> {
    if (group.size < 3) return emptyList()
    val out = ArrayList<QF>()
    // Pictures where we can: a picture set needs four different pictures.
    val picGroup = group.filter { it.pic != null }.distinctBy { it.pic }
    odds.forEachIndexed { oi, o ->
        val usePics = pics && o.pic != null && picGroup.count { it.pic != o.pic } >= 3
        if (!usePics && grade <= 2 && pics && needPics) return@forEachIndexed
        val pool = if (usePics) picGroup.filter { it.pic != o.pic } else group
        for (s in 0 until perOdd) {
            val trio = Opt.spread(pool, 3, oi * 7 + s * 13)
            if (trio.size < 3 || trio.any { it.name == o.name }) continue
            val four = (trio + o).shuffled(Random(oi * 1009 + s))
            val names = four.map { it.name }
            val prompt = "Which one $label: ${names[0]}, ${names[1]}, ${names[2]} or ${names[3]}?"
            val picsOk = pics && four.all { it.pic != null } && four.map { it.pic }.toSet().size == 4
            val opts = if (picsOk) four.map { "pic:${it.pic}" } else names
            val ans = if (picsOk) "pic:${o.pic}" else o.name
            if (opts.toSet().size == 4) out += QF(prompt, ans, emptyList(), explain(o), cap(o.name), fixed = opts)
        }
    }
    return out
}

/** Every in-order selection of 3..5 steps from [steps] (for things whose order is strict). */
private fun subsets(steps: List<String>, min: Int = 3): List<List<String>> {
    val out = ArrayList<List<String>>()
    val n = steps.size
    for (mask in 1 until (1 shl n)) {
        val k = Integer.bitCount(mask)
        if (k < min || k > 5) continue
        out += (0 until n).filter { mask and (1 shl it) != 0 }.map { steps[it] }
    }
    return out
}

/** [k] items from [pool] picked by stride from [seed] (deterministic false statements). */
private fun <T> stride(pool: List<T>, k: Int, seed: Int): List<T> =
    if (pool.isEmpty()) emptyList() else (0 until minOf(k, pool.size)).map { pool[(seed * 7 + it * 5) % pool.size] }.distinct()

private val NUM = listOf("zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten")

// ------------------------------------------------------------------ the skills

private class EvsSkills(private val d: EvsData) {
    internal val animals = d.animals
    internal val sure = animals.filter { !it.contested }
    internal fun th(a: EAnimal) = Th(a.n, a.pic)
    internal fun the(a: EAnimal) = art(a.n, a.an)
    internal fun The(a: EAnimal) = cap(the(a))
    internal fun food(f: EFood) = Noun(f.n, f.form, f.an)
    internal fun obj(o: EObject) = Noun(o.n, o.form, o.an)

    /** Objects whose picture belongs to them alone (a "spoon" picture can't say steel or wood). */
    internal val objPic: Map<String, String?> = run {
        val count = d.objects.mapNotNull { it.pic }.groupingBy { it }.eachCount()
        d.objects.associate { o -> o.n to o.pic?.takeIf { count[it] == 1 } }
    }
    internal fun oth(o: EObject) = Th(o.n, objPic[o.n])

    fun all(): List<GenSkill> = listOfNotNull(
        // KG
        petWild(), whereLive(), body(), fruitVeg(), helpersKg(), transport(), weather(), sounds(), habits(), bigSmall(),
        // Class 1
        homes(), babies(), goodFood(), helperPlace(), festivals1(), seasons(), tastes(), safety(), moves(), dayNight(),
    ) + more()

    /** Classes 2 to 5 (split for readability). */
    internal fun more(): List<GenSkill> = EvsMore(d, this).all()

    // ================================================================ KG

    internal fun petWild(): GenSkill? {
        val s = SB("evk.petWild", 0, "Pet, farm or wild", "Pet", "pet, farm and wild animals")
        val k = sure.filter { it.kind != null }
        fun why(a: EAnimal) = when (a.kind) {
            "pet" -> "${The(a)} lives with people, so it is a pet."
            "farm" -> "${The(a)} is kept by people on a farm."
            else -> "${The(a)} lives in the wild, away from people."
        }
        // "Wild animal" means a creature a child pictures as one (tiger, deer, eagle), not a butterfly or an ant.
        val wild = k.filter { it.kind == "wild" && it.group in setOf("mammal", "bird", "reptile") }
        val kgWild = wild.filter { it.kg }
        s.sort("pw", 1, "Pet", "Wild", k.filter { it.kind == "pet" }.map { SO(cap(it.n), true, why(it), it.pic) } +
            kgWild.filterIndexed { i, _ -> i % 2 == 0 }.map { SO(cap(it.n), false, why(it), it.pic) })
        s.sort("fw", 1, "Farm", "Wild", k.filter { it.kind == "farm" }.map { SO(cap(it.n), true, why(it), it.pic) } +
            kgWild.filterIndexed { i, _ -> i % 2 == 1 }.map { SO(cap(it.n), false, why(it), it.pic) })
        val tame = k.filter { it.kind != "wild" }.map(::th)
        s.qf("which", 1, k.filter { it.kg || it.kind != "wild" }.map { a ->
            when (a.kind) {
                "pet" -> s.choice("Which of these is a pet?", th(a), wild.map(::th), why(a))
                "farm" -> s.choice("Which of these is a farm animal?", th(a), wild.map(::th), why(a))
                else -> s.choice("Which of these is a wild animal?", th(a), tame, why(a))
            }
        })
        s.qf("wild2", 2, wild.filter { !it.kg }.map { s.choice("Which of these is a wild animal?", th(it), tame, why(it)) })
        s.qf("odd", 2, s.odd("is not a wild animal", kgWild.map(::th), k.filter { it.kind != "wild" }.map(::th), { o ->
            "${cap(aOf(o.name))} lives with people, not in the wild."
        }))
        s.tf("tf", 3, k.flatMap { a ->
            when (a.kind) {
                "wild" -> listOf(TF("${The(a)} is a wild animal.", true, why(a), a.pic), TF("${The(a)} is a pet.", false, why(a), a.pic),
                    TF("${The(a)} is a farm animal.", false, why(a), a.pic))
                "pet" -> listOf(TF("${The(a)} is a pet.", true, why(a), a.pic), TF("${The(a)} is a wild animal.", false, why(a), a.pic))
                else -> listOf(TF("${The(a)} is a farm animal.", true, why(a), a.pic), TF("${The(a)} is a wild animal.", false, why(a), a.pic))
            }
        })
        return s.build()
    }

    internal val waterHabs = setOf("sea", "fresh")
    /** Birds that feed in water still live on land (in trees, on banks), so they are never "in water". */
    internal fun inWater(a: EAnimal) = !a.both && a.group != "bird" && a.hab.isNotEmpty() && a.hab.all { it in waterHabs }
    internal fun onLand(a: EAnimal) = !a.both && a.hab.isNotEmpty() && a.hab.none { it in waterHabs }
    internal fun waterBird(a: EAnimal) = a.group == "bird" && a.hab.any { it in waterHabs }
    internal fun whereWhy(a: EAnimal) = when {
        inWater(a) -> "${The(a)} lives only in water."
        onLand(a) -> "${The(a)} lives on land, not in water."
        else -> "${The(a)} lives on land and in water."
    }
    internal fun flyWhy(a: EAnimal) = when {
        a.flies == true -> "${The(a)} has wings, so it can fly."
        a.group == "bird" -> "${The(a)} has wings but cannot fly."
        else -> "${The(a)} has no wings, so it cannot fly."
    }

    internal fun whereLive(): GenSkill? {
        val s = SB("evk.whereLive", 0, "Land or water", "Pond", "where animals live, and which fly")
        val placed = animals.filter { (inWater(it) || onLand(it) || it.both) && !waterBird(it) }
        val water = placed.filter(::inWater)
        val land = placed.filter(::onLand)
        s.sort("lw", 1, "Land", "Water", placed.filter { it.kg && !it.both }.map { SO(cap(it.n), onLand(it), whereWhy(it), it.pic) })
        s.qf("water", 2, water.map { s.choice("Which of these lives in water?", th(it), land.map(::th), whereWhy(it)) })
        s.qf("land", 1, land.filter { it.kg }.map { s.choice("Which of these lives on land?", th(it), water.map(::th), whereWhy(it)) })
        val fly = sure.filter { it.flies != null }
        s.qf("fly", 1, fly.filter { it.flies == true }.map { a ->
            s.choice("Which of these can fly?", th(a), fly.filter { it.flies == false }.map(::th), flyWhy(a))
        })
        s.qf("both", 3, placed.filter { it.both && !it.contested }.map { s.choice("Which of these lives on land and in water?", th(it), land.map(::th), whereWhy(it)) })
        s.qf("odd", 3, s.odd("does not live in water", water.map(::th), land.filter { it.kg }.map(::th), { o ->
            "${cap(aOf(o.name))} lives on land, not in water."
        }))
        s.tf("tf", 3, placed.flatMap { a ->
            listOf(TF("${The(a)} lives in water.", !onLand(a), whereWhy(a), a.pic), TF("${The(a)} lives on land.", !inWater(a), whereWhy(a), a.pic))
        } + fly.map { TF("${The(it)} can fly.", it.flies == true, flyWhy(it), it.pic) })
        return s.build()
    }

    internal fun body(): GenSkill? {
        val s = SB("evk.body", 0, "My body", "Body", "body parts and what they do")
        val parts = d.bodyParts.associateBy { it.n }
        val inside = setOf("heart", "lungs", "brain")
        val outer = d.bodyParts.filter { it.n !in inside && it.n !in setOf("skin", "hair", "nails") }.map { Th(it.n, it.pic) }
        fun pt(n: String) = Th(n, parts[n]?.pic)
        s.qf("use", 1, d.bodyUses.flatMap { u ->
            u.parts.map { p ->
                s.choice("Which part do we use to ${u.verb}?", pt(p), outer.filter { it.name !in u.parts }, "We ${u.verb} with our $p.")
            }
        })
        s.qf("count", 1, d.bodyParts.filter { it.count != null && it.ask != null }.map { p ->
            val c = p.count!!
            val why = when {
                "one hand" in p.ask!! -> "There are five fingers on one hand."
                "one foot" in p.ask -> "There are five toes on one foot."
                "a nose" in p.ask -> "There are two nostrils in a nose."
                c == 1 -> "We have only one ${p.n}."
                else -> "We have ${NUM[c]} ${p.n}."
            }
            QF(p.ask, "$c", listOf(1, 2, 3, 4, 5, 10).filter { it != c }.map { "$it" }, why, why, p.pic)
        })
        val wearParts = d.wear.map { it.part }.distinct()
        s.qf("wear", 2, d.wear.map { w ->
            QF("Where do we wear ${w.thing}?", w.part, wearParts.filter { it != w.part && !(it.removeSuffix("s") == w.part.removeSuffix("s")) },
                "We wear ${w.thing} on our ${w.part}.", "We wear ${w.thing} on our ${w.part}.", d.wearPics[w.thing])
        })
        s.tf("tfuse", 3, d.bodyUses.flatMapIndexed { i, u ->
            u.parts.map { TF("We ${u.verb} with our $it.", true, "We ${u.verb} with our $it.", parts[it]?.pic) } +
                stride(outer.filter { it.name !in u.parts }, 4, i).map {
                    TF("We ${u.verb} with our ${it.name}.", false, "We ${u.verb} with our ${u.parts[0]}, not our ${it.name}.", it.pic)
                }
        })
        s.tf("tfwear", 2, d.wear.flatMapIndexed { i, w ->
            val why = "We wear ${w.thing} on our ${w.part}."
            listOf(TF(why, true, why, d.wearPics[w.thing])) +
                stride(wearParts.filter { it.removeSuffix("s") != w.part.removeSuffix("s") }, 2, i).map {
                    TF("We wear ${w.thing} on our $it.", false, why, d.wearPics[w.thing])
                }
        })
        return s.build()
    }

        /** A picture that sets the scene for a habit or safety card (never the answer itself). */
    internal fun scene(t: String): String? {
        val x = t.lowercase()
        return listOf("soap" to "soap", "hands" to "soap", "brush" to "toothbrush", "comb" to "comb", "fruit" to "apple", "vegetable" to "carrot",
            "water" to "drop", "tap" to "drop", "tv" to "tv", "book" to "book", "toys" to "ball", "fire" to "fire", "matches" to "fire",
            "knife" to "knife", "scissors" to "scissors", "wire" to "wire", "plug" to "switch", "kite" to "kite", "bus" to "bus",
            "helmet" to "scooter", "seat belt" to "car", "road" to "car", "crossing" to "car", "lighter" to "fire", "light" to "bulb", "dustbin" to "bucket",
            "swim" to "wave", "pool" to "wave", "bed" to "bed", "stairs" to "ladder", "breakfast" to "roti", "sneez" to "nose",
            "cough" to "mouth", "nose" to "nose", "nails" to "hand", "junk" to "icecream", "park" to "park", "school" to "school",
            "flowers" to "flower", "plants" to "tree", "birds" to "bird", "animals" to "dog", "dog" to "dog", "fridge" to "fridge",
            "medicine" to "hospital", "chair" to "chair", "window" to "window", "door" to "door", "stranger" to "door",
        ).firstOrNull { it.first in x }?.second
    }

    /** "a fruit" / "fruits" to follow a food's verb. */
    internal fun kindWord(f: EFood, k: String) = if (f.form == "pl") "${k}s" else aOf(k)

    internal fun fruitVeg(): GenSkill? {
        val s = SB("evk.fruitVeg", 0, "Fruit or vegetable", "Veg", "fruits and vegetables")
        val fv = d.foods.filter { it.fv != null }
        fun why(f: EFood): String {
            val n = food(f)
            val other = if (f.fv == "fruit") "vegetable" else "fruit"
            return "${n.subj} ${n.be} ${kindWord(f, f.fv!!)}, not ${kindWord(f, other)}."
        }
        val fruits = fv.filter { it.fv == "fruit" }
        val veg = fv.filter { it.fv == "veg" }
        fun fth(f: EFood) = Th(f.n, f.pic)
        s.sort("sort", 1, "Fruit", "Vegetable", fv.map { SO(cap(it.n), it.fv == "fruit", why(it).replace("veg,", "vegetable,"), it.pic) })
        s.qf("fruit", 2, fruits.map { s.choice("Which of these is a fruit?", fth(it), veg.map(::fth), whyFv(it)) } +
            veg.map { s.choice("Which of these is a vegetable?", fth(it), fruits.map(::fth), whyFv(it)) })
        s.qf("odd", 3, s.odd("is not a fruit", fruits.map(::fth), veg.map(::fth), { o -> whyFv(fv.first { it.n == o.name }) }) +
            s.odd("is not a vegetable", veg.map(::fth), fruits.map(::fth), { o -> whyFv(fv.first { it.n == o.name }) }, 6))
        s.tf("tf", 3, fv.flatMap { f ->
            val n = food(f)
            listOf(TF("${n.subj} ${n.be} ${kindWord(f, "fruit")}.", f.fv == "fruit", whyFv(f), f.pic),
                TF("${n.subj} ${n.be} ${kindWord(f, "vegetable")}.", f.fv == "veg", whyFv(f), f.pic))
        })
        return s.build()
    }

    internal fun whyFv(f: EFood): String {
        val n = food(f)
        val k = if (f.fv == "fruit") "fruit" else "vegetable"
        val o = if (f.fv == "fruit") "vegetable" else "fruit"
        return "${n.subj} ${n.be} ${kindWord(f, k)}, not ${kindWord(f, o)}."
    }

    internal fun toolWord(t: String) = if (t.endsWith("s") || t in setOf("chalk", "clay", "thread", "cement", "paint", "wire")) t else aOf(t)
    internal fun toolSubj(t: String) = cap(toolWord(t)) + if (t.endsWith("s")) " are" else " is"
    internal fun hth(h: EHelper) = Th(h.n, h.pic)
    internal fun aH(h: EHelper) = art(h.n, h.an)

    internal val kgHelpers = setOf(
        "doctor", "nurse", "farmer", "teacher", "tailor", "barber", "cobbler", "carpenter", "potter", "postman", "police officer",
        "firefighter", "pilot", "bus driver", "cook", "dentist", "vegetable seller", "sweeper", "milkman", "gardener", "fisherman",
    )

    internal fun helpersKg(): GenSkill? {
        val s = SB("evk.helpers", 0, "Helpers and tools", "Help", "people who help us, and their tools")
        val hs = d.helpers.filter { it.n in kgHelpers }
        val tools = hs.flatMap { it.tools }.distinct()
        fun tth(t: String) = Th(t, d.toolPics[t])
        s.qf("who", 1, tools.flatMap { t ->
            hs.filter { t in it.tools }.map { h ->
                s.choice("Who uses ${toolWord(t)}?", hth(h), hs.filter { t !in it.tools }.map(::hth), "${cap(aH(h))} uses ${toolWord(t)} at work.",
                    visual = d.toolPics[t])
            }
        })
        s.qf("what", 2, hs.flatMap { h ->
            h.tools.map { t ->
                s.choice("What does ${aH(h)} use?", tth(t), tools.filter { it !in h.tools }.map(::tth), "${cap(aH(h))} uses ${toolWord(t)} at work.",
                    fact = cap(t))
            }
        })
        val does = hs.flatMap { it.does }.distinct()
        s.qf("does", 2, does.flatMap { x ->
            hs.filter { x in it.does }.map { h -> s.choice("Who $x?", hth(h), hs.filter { x !in it.does }.map(::hth), "${cap(aH(h))} $x.") }
        })
        s.tf("tf", 3, hs.flatMapIndexed { i, h ->
            h.tools.map { TF("${cap(aH(h))} uses ${toolWord(it)}.", true, "${cap(aH(h))} uses ${toolWord(it)} at work.", d.toolPics[it]) } +
                stride(tools.filter { it !in h.tools }, 3, i).map { t ->
                    val owner = hs.first { t in it.tools }
                    TF("${cap(aH(h))} uses ${toolWord(t)}.", false, "${toolSubj(t)} used by ${aH(owner)}, not ${aH(h)}.", d.toolPics[t])
                } +
                h.does.map { TF("${cap(aH(h))} $it.", true, "${cap(aH(h))} $it.") } +
                stride(does.filter { it !in h.does }, 2, i).map { TF("${cap(aH(h))} $it.", false, "${cap(aH(h))} ${h.does[0]}.") }
        })
        return s.build()
    }

    internal val modeDo = mapOf("land" to "moves on land", "water" to "moves on water", "air" to "flies in the air")
    internal fun tth(t: ETransport) = Th(t.n, t.pic)
    internal fun aT(t: ETransport) = art(t.n, t.an)

    internal fun transport(): GenSkill? {
        val s = SB("evk.transport", 0, "Ways to travel", "Go", "land, water and air transport")
        val ts = d.transport
        val land = ts.filter { it.mode == "land" }
        fun why(t: ETransport) = "${cap(aT(t))} ${modeDo[t.mode]}."
        s.sort("lw", 1, "Land", "Water", land.filterIndexed { i, _ -> i % 2 == 0 }.map { SO(cap(it.n), true, why(it), it.pic) } +
            ts.filter { it.mode == "water" }.map { SO(cap(it.n), false, why(it), it.pic) })
        s.sort("la", 1, "Land", "Air", land.filterIndexed { i, _ -> i % 2 == 1 }.map { SO(cap(it.n), true, why(it), it.pic) } +
            ts.filter { it.mode == "air" }.map { SO(cap(it.n), false, why(it), it.pic) })
        s.qf("mode", 1, ts.map { t -> s.choice("Which of these ${modeDo[t.mode]}?", tth(t), ts.filter { it.mode != t.mode }.map(::tth), why(t)) })
        s.qf("wheels", 2, ts.filter { it.wheels != null }.map { t ->
            QF("How many wheels does ${aT(t)} have?", "${t.wheels}", listOf(1, 2, 3, 4, 6).filter { it != t.wheels }.map { "$it" },
                "${cap(aT(t))} has ${NUM[t.wheels!!]} wheels.", "${cap(aT(t))} has ${NUM[t.wheels]} wheels.", t.pic)
        })
        val engine = ts.filter { it.power == null && it.mode == "land" }.map(::tth)
        s.qf("power", 3, ts.filter { it.power == "pedal" }.map {
            s.choice("Which of these do we pedal to make it move?", tth(it), engine, "We push the pedals of ${aT(it)} to move it.")
        } + ts.filter { it.power == "animal" }.map { s.choice("Which of these is pulled by animals?", tth(it), engine, "${cap(aT(it))} is pulled by animals.") } +
            ts.filter { it.power == "wind" }.map {
                s.choice("Which of these is pushed by the wind?", tth(it), ts.filter { o -> o.mode == "water" && o.power != "wind" }.map(::tth),
                    "${cap(aT(it))} uses its sail to catch the wind.")
            })
        s.qf("odd", 2, listOf("land", "water", "air").flatMap { m ->
            s.odd("does not ${modeDo[m]!!.removeSuffix("s").replace("moves", "move").replace("flies", "fly")}",
                ts.filter { it.mode == m }.map(::tth), ts.filter { it.mode != m }.map(::tth), { o ->
                    val t = ts.first { it.n == o.name }
                    why(t)
                }, 6)
        })
        s.tf("tf", 3, ts.flatMap { t ->
            modeDo.map { (m, phrase) -> TF("${cap(aT(t))} $phrase.", m == t.mode, why(t), t.pic) } +
                (if (t.wheels != null) listOf(
                    TF("${cap(aT(t))} has ${NUM[t.wheels]} wheels.", true, "${cap(aT(t))} has ${NUM[t.wheels]} wheels.", t.pic),
                    TF("${cap(aT(t))} has ${NUM[t.wheels + 1]} wheels.", false, "${cap(aT(t))} has ${NUM[t.wheels]} wheels.", t.pic),
                ) else emptyList())
        })
        return s.build()
    }

    internal fun thing(n: String) = when {
        n in setOf("hot soup", "nimbu pani") -> n
        n.endsWith("s") -> n
        else -> aOf(n)
    }

    internal fun weather(): GenSkill? {
        val s = SB("evk.weather", 0, "Weather and clothes", "Sun", "what we use and wear in each weather")
        val ws = d.weather
        val word = d.weatherWords
        fun wth(w: EWeather) = Th(w.n, w.pic)
        fun use(w: EWeather) = if (w.worn) "wear" else "use"
        fun why(w: EWeather, day: String) = "We ${use(w)} ${thing(w.n)} on ${word[day]}."
        for (day in listOf("hot", "cold", "rainy")) {
            val yes = ws.filter { day in it.days }
            val no = ws.filter { day in it.never }
            s.qf("use$day", 1, yes.map { s.choice("Which of these do we use on ${word[day]}?", wth(it), no.map(::wth), why(it, day)) })
            s.qf("wear$day", 2, yes.filter { it.worn }.map { s.choice("What do we wear on ${word[day]}?", wth(it), no.filter { o -> o.worn }.map(::wth), why(it, day)) })
            s.qf("odd$day", 3, s.odd("is not for ${word[day]}", yes.map(::wth), no.map(::wth), { o ->
                val w = ws.first { it.n == o.name }
                why(w, w.days[0])
            }, 8, needPics = false))
        }
        s.sort("hc", 2, "Hot day", "Cold day", ws.filter { ("hot" in it.days) != ("cold" in it.days) && ("hot" in it.never || "cold" in it.never) }
            .map { SO(cap(it.n), "hot" in it.days, why(it, if ("hot" in it.days) "hot" else "cold"), it.pic) })
        val season = mapOf("hot" to "summer", "cold" to "winter", "rainy" to "monsoon")
        s.qf("season", 2, ws.filter { w -> w.days.count { it in season } == 1 }.map { w ->
            val day = w.days.first { it in season }
            val sn = season[day]!!
            QF("In which season do we ${use(w)} ${thing(w.n)}?", cap(sn), emptyList(), "We ${use(w)} ${thing(w.n)} in ${if (sn == "monsoon") "the monsoon" else sn}.",
                cap(sn), w.pic, fixed = listOf("Summer", "Monsoon", "Winter"))
        })
        s.tf("tf", 3, ws.flatMap { w ->
            w.days.filter { it in word }.map { TF(why(w, it), true, why(w, it), w.pic) } +
                w.never.map { TF("We ${use(w)} ${thing(w.n)} on ${word[it]}.", false, why(w, w.days[0]), w.pic) }
        })
        return s.build()
    }

    internal fun sounds(): GenSkill? {
        val s = SB("evk.sounds", 0, "Animal sounds", "Moo", "the sounds animals make")
        val sa = animals.filter { it.sound != null }
        val verbs = sa.map { it.sound!! }.distinct()
        val noises = sa.mapNotNull { it.noise }.distinct()
        fun why(a: EAnimal) = if (a.noise != null) "${The(a)} ${a.sound} and says \"${a.noise}\"." else "${The(a)} ${a.sound}."
        s.qf("who", 1, sa.map { a -> s.choice("Which animal ${a.sound}?", th(a), sa.filter { it.sound != a.sound }.map(::th), why(a)) })
        s.qf("verb", 1, sa.map { a ->
            QF("What sound does ${the(a)} make?", "It ${a.sound}", verbs.filter { it != a.sound }.map { "It $it" }, why(a), why(a), a.pic)
        })
        s.qf("noise", 2, sa.filter { it.noise != null }.map { a ->
            s.choice("Who says \"${a.noise}\"?", th(a), sa.filter { it.sound != a.sound }.map(::th), why(a))
        })
        s.qf("say", 2, sa.filter { it.noise != null }.map { a ->
            QF("What does ${the(a)} say?", a.noise!!, sa.filter { it.sound != a.sound }.mapNotNull { it.noise }.distinct(), why(a), why(a), a.pic)
        })
        s.tf("tf", 3, sa.flatMapIndexed { i, a ->
            listOf(TF("${The(a)} ${a.sound}.", true, why(a), a.pic)) +
                stride(verbs.filter { it != a.sound }, 4, i).map { TF("${The(a)} $it.", false, why(a), a.pic) } +
                (if (a.noise != null) listOf(TF("${The(a)} says \"${a.noise}\".", true, why(a), a.pic)) +
                    stride(noises.filter { it != a.noise && sa.none { o -> o.noise == it && o.sound == a.sound } }, 2, i).map {
                        TF("${The(a)} says \"$it\".", false, why(a), a.pic)
                    } else emptyList())
        })
        return s.build()
    }

    internal fun habits(): GenSkill? {
        val s = SB("evk.habits", 0, "Good habits", "Good", "good and bad habits")
        val hs = d.habits.filter { it.good != null }
        fun why(h: EFlag) = if (h.good == true) "${h.n} keeps us clean, healthy and kind." else "${h.n} is a bad habit we should stop."
        s.sort("sort", 1, "Good habit", "Bad habit", hs.map { SO(it.n, it.good == true, why(it), scene(it.n)) })
        s.qf("good", 2, hs.map { h ->
            QF(if (h.good == true) "Which of these is a good habit?" else "Which of these is a bad habit?", h.n,
                hs.filter { it.good != h.good }.map { it.n }, why(h), h.n, scene(h.n))
        })
        s.tf("tf", 3, hs.flatMap { h ->
            listOf(TF("${h.n} is a good habit.", h.good == true, why(h), scene(h.n)), TF("${h.n} is a bad habit.", h.good == false, why(h), scene(h.n)))
        })
        return s.build()
    }

    internal fun bigSmall(): GenSkill? {
        val s = SB("evk.bigSmall", 0, "Big and small", "Big", "comparing animal sizes")
        val kg = animals.filter { it.kg && it.size != null }
        val pairs1 = ArrayList<QF>()
        val pairs2 = ArrayList<QF>()
        val tfs = ArrayList<TF>()
        for (i in kg.indices) for (j in kg.indices) {
            if (i >= j) continue
            val a = kg[i]; val b = kg[j]
            val diff = a.size!! - b.size!!
            if (kotlin.math.abs(diff) < 2) continue
            val big = if (diff > 0) a else b
            val small = if (diff > 0) b else a
            val why = "${The(big)} is much bigger than ${the(small)}."
            val picsOk = a.pic != null && b.pic != null && a.pic != b.pic
            val opts = if (picsOk) listOf("pic:${a.pic}", "pic:${b.pic}") else listOf(a.n, b.n)
            fun o(x: EAnimal) = if (picsOk) "pic:${x.pic}" else x.n
            val list = if (kotlin.math.abs(diff) >= 3) pairs1 else pairs2
            list += QF("Which is bigger, ${the(a)} or ${the(b)}?", o(big), emptyList(), why, cap(big.n), fixed = opts)
            list += QF("Which is smaller, ${the(a)} or ${the(b)}?", o(small), emptyList(), why, cap(small.n), fixed = opts)
            if ((i + j) % 2 == 0) {
                tfs += TF("${The(big)} is bigger than ${the(small)}.", true, why, big.pic)
                tfs += TF("${The(small)} is bigger than ${the(big)}.", false, why, small.pic)
            }
        }
        s.qf("pair1", 1, pairs1)
        s.qf("pair2", 2, pairs2)
        val trios = ArrayList<List<EAnimal>>()
        for (i in kg.indices) for (j in i + 1 until kg.size) for (k in j + 1 until kg.size) {
            val t = listOf(kg[i], kg[j], kg[k]).sortedBy { it.size }
            if (t[1].size!! - t[0].size!! >= 2 && t[2].size!! - t[1].size!! >= 2) trios += t
        }
        val pick = trios.filterIndexed { i, _ -> i % maxOf(1, trios.size / 1500) == 0 }
        s.qf("biggest", 2, pick.map { t ->
            val shown = t.shuffled(Random(t.hashCode()))
            val picsOk = t.all { it.pic != null } && t.map { it.pic }.toSet().size == 3
            val opts = shown.map { if (picsOk) "pic:${it.pic}" else it.n }
            QF("Which is the biggest: ${shown[0].n}, ${shown[1].n} or ${shown[2].n}?", if (picsOk) "pic:${t[2].pic}" else t[2].n, emptyList(),
                "${The(t[2])} is the biggest of the three.", cap(t[2].n), fixed = opts)
        })
        s.order("order", 3, pick.filterIndexed { i, _ -> i % 4 == 0 }.map { t ->
            OR("Put them in order, smallest first.", t.map { it.n }, "${The(t[0])} is smallest and ${the(t[2])} is biggest.")
        })
        s.tf("tf", 3, tfs)
        return s.build()
    }

    // ================================================================ Class 1

    internal fun homes(): GenSkill? {
        val s = SB("ev1.homes", 1, "Where animals live", "Nest", "animal homes")
        val ha = animals.filter { it.home.isNotEmpty() }
        val homes = ha.flatMap { it.home }.distinct()
        val hpic = mapOf("nest" to "nest", "hive" to "honeycomb")
        fun why(a: EAnimal) = "${The(a)} lives in ${aOf(a.home[0])}."
        s.qf("where", 1, ha.map { a ->
            s.choice("Where does ${the(a)} live?", Th(a.home[0], hpic[a.home[0]]), homes.filter { it !in a.home }.map { Th(it, hpic[it]) },
                why(a), visual = a.pic)
        })
        s.qf("who", 2, ha.map { a ->
            s.choice("Which animal lives in ${aOf(a.home[0])}?", th(a), ha.filter { a.home[0] !in it.home }.map(::th), why(a), visual = hpic[a.home[0]])
        })
        s.sort("nd", 2, "Nest", "Den", ha.filter { (it.home[0] == "nest" && "den" !in it.home) || (it.home[0] == "den" && "nest" !in it.home) }
            .map { SO(cap(it.n), it.home[0] == "nest", why(it), it.pic) })
        s.qf("odd", 3, homes.flatMap { h ->
            s.odd("does not live in ${aOf(h)}", ha.filter { h in it.home }.map(::th), ha.filter { h !in it.home }.map(::th), { o ->
                why(ha.first { it.n == o.name })
            }, 6)
        })
        s.tf("tf", 3, ha.flatMapIndexed { i, a ->
            a.home.map { TF("${The(a)} lives in ${aOf(it)}.", true, why(a), a.pic) } +
                stride(homes.filter { it !in a.home }, 3, i).map { TF("${The(a)} lives in ${aOf(it)}.", false, why(a), a.pic) }
        })
        return s.build()
    }

    internal fun babies(): GenSkill? {
        val s = SB("ev1.babies", 1, "Baby animals", "Baby", "animals and their young ones")
        val ya = animals.filter { it.young != null }
        val young = ya.map { it.young!! }.distinct()
        fun yth(y: String) = Th(y, d.youngPics[y])
        fun why(a: EAnimal) = "A baby ${a.n} is called ${aOf(a.young!!)}."
        s.qf("name", 1, ya.map { a -> s.choice("What is a baby ${a.n} called?", yth(a.young!!), young.filter { it != a.young }.map(::yth), why(a), visual = a.pic) })
        s.qf("whose", 2, ya.map { a ->
            s.choice("Whose baby is ${aOf(a.young!!)}?", th(a), ya.filter { it.young != a.young }.map(::th), why(a), visual = d.youngPics[a.young])
        })
        s.tf("tf", 3, ya.flatMapIndexed { i, a ->
            listOf(TF(why(a), true, why(a), a.pic)) +
                stride(young.filter { it != a.young }, 3, i).map { TF("A baby ${a.n} is called ${aOf(it)}.", false, why(a), a.pic) }
        })
        return s.build()
    }

    internal fun goodFood(): GenSkill? {
        val s = SB("ev1.goodFood", 1, "Healthy food", "Yum", "healthy food and junk food")
        val fs = d.foods.filter { it.health != null }
        fun fth(f: EFood) = Th(f.n, f.pic)
        fun why(f: EFood): String {
            val n = food(f)
            return if (f.health == "healthy") "${n.subj} ${n.v("helps", "help")} our body grow strong."
            else "${n.subj} ${n.has} lots of oil, salt or sugar."
        }
        val good = fs.filter { it.health == "healthy" }
        val junk = fs.filter { it.health == "junk" }
        s.sort("sort", 1, "Healthy", "Junk food", fs.map { SO(cap(it.n), it.health == "healthy", why(it), it.pic) })
        s.qf("which", 2, good.map { s.choice("Which of these is healthy food?", fth(it), junk.map(::fth), why(it)) } +
            junk.map { s.choice("Which of these is junk food?", fth(it), good.map(::fth), why(it)) })
        s.qf("odd", 3, s.odd("is junk food", good.map(::fth), junk.map(::fth), { o -> why(junk.first { it.n == o.name }) }, 10))
        s.tf("tf", 3, fs.flatMap { f ->
            val n = food(f)
            listOf(TF("${n.subj} ${n.be} healthy food.", f.health == "healthy", why(f), f.pic), TF("${n.subj} ${n.be} junk food.", f.health == "junk", why(f), f.pic))
        })
        return s.build()
    }

    internal val genericPlaces = setOf("school", "hospital", "clinic", "kitchen", "restaurant", "shop", "market", "street", "workshop")
    internal fun at(p: String) = when (p) {
        "sea" -> "at sea"
        "river" -> "on a river"
        "street" -> "on the street"
        "field" -> "in a field"
        "roadside stall" -> "at a roadside stall"
        "building site" -> "at a building site"
        "bus depot" -> "at a bus depot"
        "airport" -> "at an airport"
        else -> "in ${aOf(p)}"
    }

    internal fun helperPlace(): GenSkill? {
        val s = SB("ev1.helperPlace", 1, "Where helpers work", "Work", "where people work")
        val hs = d.helpers.filter { it.places.isNotEmpty() }
        val places = hs.flatMap { it.places }.distinct()
        fun pth(p: String) = Th(p, d.placePics[p])
        val specificHelpers = hs.filter { h -> h.places.none { it in genericPlaces } }
        s.qf("where", 1, hs.flatMap { h ->
            h.places.map { p ->
                s.choice("Where does ${aH(h)} work?", pth(p), places.filter { it !in h.places && it !in genericPlaces }.map(::pth),
                    "${cap(aH(h))} works ${at(p)}.", visual = h.pic)
            }
        })
        s.qf("who", 2, places.flatMap { p ->
            hs.filter { p in it.places }.map { h ->
                s.choice("Who works ${at(p)}?", hth(h), specificHelpers.filter { p !in it.places }.map(::hth), "${cap(aH(h))} works ${at(p)}.",
                    visual = d.placePics[p])
            }
        })
        s.tf("tf", 3, hs.flatMapIndexed { i, h ->
            h.places.map { TF("${cap(aH(h))} works ${at(it)}.", true, "${cap(aH(h))} works ${at(it)}.", d.placePics[it]) } +
                stride(places.filter { it !in h.places && it !in genericPlaces }, 3, i).map {
                    TF("${cap(aH(h))} works ${at(it)}.", false, "${cap(aH(h))} works ${at(h.places[0])}.", d.placePics[it])
                }
        })
        return s.build()
    }

    internal val familiarFest = setOf(
        "Diwali", "Holi", "Eid ul-Fitr", "Christmas", "Raksha Bandhan", "Republic Day", "Independence Day", "Gandhi Jayanti",
        "Children's Day", "Teachers' Day", "Janmashtami", "Ganesh Chaturthi", "Dussehra", "Navratri", "Makar Sankranti",
    )

    internal fun festivals1(): GenSkill? {
        val s = SB("ev1.festivals", 1, "Festivals", "Fest", "festivals we celebrate")
        val fs = d.festivals
        val text = d.festivalFeatures.associate { it.key to it.text }
        fun fth(f: EFestival) = Th(f.n, f.pic)
        for ((tier, set) in listOf(1 to fs.filter { it.n in familiarFest }, 2 to fs.filter { it.n !in familiarFest })) {
            s.qf("feat$tier", tier, set.flatMap { f ->
                f.features.filter { it in text }.map { k ->
                    s.choice("Which festival ${text[k]}?", fth(f), fs.filter { k !in it.features && k !in it.maybe }.map(::fth), "${f.n} ${text[k]}.")
                }
            })
        }
        val months = d.months.map { it.n }
        s.qf("month", 2, fs.filter { it.month != null }.map { f ->
            QF("In which month is ${f.n}?", f.month!!, months.filter { it != f.month }, "${f.n} comes in ${f.month}.", "${f.n} comes in ${f.month}.", f.pic)
        })
        s.tf("tf", 3, fs.flatMapIndexed { i, f ->
            val feats = f.features.filter { it in text }
            if (feats.isEmpty()) return@flatMapIndexed emptyList()
            val why = "${f.n} ${text[feats[0]]}."
            feats.map { TF("${f.n} ${text[it]}.", true, "${f.n} ${text[it]}.", f.pic) } +
                stride(text.keys.filter { it !in f.features && it !in f.maybe }, 3, i).map { TF("${f.n} ${text[it]}.", false, why, f.pic) } +
                (if (f.month != null) listOf(TF("${f.n} comes in ${f.month}.", true, "${f.n} comes in ${f.month}.", f.pic)) +
                    stride(months.filter { it != f.month }, 2, i).map { TF("${f.n} comes in $it.", false, "${f.n} comes in ${f.month}.", f.pic) }
                else emptyList())
        })
        return s.build()
    }

    internal fun inSeason(sn: String) = if (sn == "monsoon") "the monsoon" else sn

    internal fun seasons(): GenSkill? {
        val s = SB("ev1.seasons", 1, "Seasons", "Rain", "summer, monsoon and winter")
        val items = d.seasonItems
        val all = listOf("summer", "monsoon", "winter")
        fun why(i: ESeasonItem) = "We ${i.we} in ${i.seasons.joinToString(" and ") { inSeason(it) }}."
        val wpic = mapOf("summer" to "sun", "monsoon" to "rain", "winter" to "snow")
        s.qf("when", 1, items.filter { it.seasons.size == 1 }.map { i ->
            QF("In which season do we ${i.we}?", cap(i.seasons[0]), emptyList(), why(i), why(i), fixed = all.map(::cap))
        })
        s.qf("what", 2, all.flatMap { sn ->
            items.filter { sn in it.seasons }.map { i ->
                QF("What do we do in ${inSeason(sn)}?", cap(i.we), items.filter { sn !in it.seasons }.map { cap(it.we) }, why(i), why(i), wpic[sn])
            }
        })
        s.sort("sw", 2, "Summer", "Winter", items.filter { it.seasons.size == 1 && it.seasons[0] != "monsoon" }
            .map { SO(cap(it.we), it.seasons[0] == "summer", why(it)) })
        s.tf("tf", 3, items.flatMap { i -> all.map { sn -> TF("We ${i.we} in ${inSeason(sn)}.", sn in i.seasons, why(i), wpic[sn]) } })
        return s.build()
    }

    internal fun tastes(): GenSkill? {
        val s = SB("ev1.tastes", 1, "Tastes", "Taste", "sweet, sour, salty, bitter and spicy")
        val fs = d.foods.filter { it.taste.isNotEmpty() }
        val all = listOf("sweet", "sour", "salty", "bitter", "spicy")
        fun fth(f: EFood) = Th(f.n, f.pic)
        fun why(f: EFood): String { val n = food(f); return "${n.subj} ${n.v("tastes", "taste")} ${f.taste.joinToString(" and ")}." }
        s.qf("how", 1, fs.filter { it.taste.size == 1 }.map { f ->
            QF("How does ${food(f).obj} taste?", cap(f.taste[0]), all.filter { it !in f.taste }.map(::cap), why(f), why(f), f.pic)
        })
        s.qf("which", 2, all.flatMap { t ->
            fs.filter { t in it.taste }.map { f -> s.choice("Which of these tastes $t?", fth(f), fs.filter { t !in it.taste }.map(::fth), why(f)) }
        })
        s.sort("ss", 2, "Sweet", "Sour", fs.filter { it.taste.size == 1 && it.taste[0] in setOf("sweet", "sour") }
            .map { SO(cap(it.n), it.taste[0] == "sweet", why(it), it.pic) })
        s.qf("odd", 3, s.odd("is not sweet", fs.filter { it.taste == listOf("sweet") }.map(::fth),
            fs.filter { "sweet" !in it.taste }.map(::fth), { o -> why(fs.first { it.n == o.name }) }, 6))
        s.tf("tf", 3, fs.flatMapIndexed { i, f ->
            val n = food(f)
            f.taste.map { TF("${n.subj} ${n.v("tastes", "taste")} $it.", true, why(f), f.pic) } +
                stride(all.filter { it !in f.taste }, 2, i).map { TF("${n.subj} ${n.v("tastes", "taste")} $it.", false, why(f), f.pic) }
        })
        return s.build()
    }

    internal fun safety(): GenSkill? {
        val s = SB("ev1.safety", 1, "Safe or unsafe", "Safe", "staying safe at home and on the road")
        val xs = d.safety.filter { it.safe != null }
        fun why(x: EFlag) = if (x.safe == true) "${x.n} keeps us safe." else "${x.n} can put us in danger."
        s.sort("sort", 1, "Safe", "Unsafe", xs.map { SO(it.n, it.safe == true, why(it), scene(it.n)) })
        s.qf("which", 2, xs.map { x ->
            QF(if (x.safe == true) "Which of these is safe?" else "Which of these is unsafe?", x.n, xs.filter { it.safe != x.safe }.map { it.n }, why(x), x.n, scene(x.n))
        })
        val means = d.signals.map { cap(it.means) }
        s.qf("signal", 1, d.signals.map { g ->
            QF("What does a ${g.colour} traffic light mean?", cap(g.means), emptyList(), "A ${g.colour} light means ${g.means}.", cap(g.means), fixed = means)
        })
        s.tf("tf", 3, xs.flatMap { x -> listOf(TF("${x.n} is safe.", x.safe == true, why(x), scene(x.n)), TF("${x.n} is unsafe.", x.safe == false, why(x), scene(x.n))) } +
            d.signals.flatMap { g -> d.signals.map { m -> TF("A ${g.colour} light means ${m.means}.", m == g, "A ${g.colour} light means ${g.means}.") } })
        return s.build()
    }

    internal fun moves(): GenSkill? {
        val s = SB("ev1.moves", 1, "How animals move", "Hop", "flying, swimming, hopping and crawling")
        val ma = animals.filter { it.moves.isNotEmpty() || it.cannot.isNotEmpty() }
        val verbs = listOf("fly", "swim", "hop", "crawl")
        fun why(a: EAnimal, v: String) = if (v in a.moves) "${The(a)} can $v." else
            "${The(a)} cannot $v" + (if (a.moves.isNotEmpty()) ", but it can ${a.moves[0]}." else ".")
        s.qf("which", 1, verbs.flatMap { v ->
            ma.filter { v in it.moves }.map { a -> s.choice("Which of these can $v?", th(a), ma.filter { v in it.cannot }.map(::th), why(a, v)) }
        })
        s.qf("can", 2, ma.flatMap { a ->
            a.moves.map { v -> QF("What can ${the(a)} do?", cap(v), a.cannot.map(::cap), why(a, v), why(a, v), a.pic) }
        })
        s.qf("odd", 3, verbs.flatMap { v ->
            s.odd("cannot $v", ma.filter { v in it.moves }.map(::th), ma.filter { v in it.cannot }.map(::th), { o -> why(ma.first { it.n == o.name }, v) }, 5)
        })
        s.tf("tf", 3, ma.flatMap { a -> (a.moves + a.cannot).map { v -> TF("${The(a)} can $v.", v in a.moves, why(a, v), a.pic) } })
        return s.build()
    }

    internal fun dayNight(): GenSkill? {
        val s = SB("ev1.dayNight", 1, "Day and night", "Moon", "day, night and the order of things")
        fun why(x: EDayNight) = if (x.`when` == "day") "${x.n} during the day." else "${x.n} at night."
        val dpic = mapOf("day" to "sun", "night" to "moon")
        s.sort("sort", 1, "Day", "Night", d.dayNight.map { SO(it.n, it.`when` == "day", why(it), dpic[it.`when`]) })
        s.tf("tfdn", 2, d.dayNight.flatMap { x ->
            listOf(TF("${x.n} at night.", x.`when` == "night", why(x), dpic[x.`when`]), TF("${x.n} during the day.", x.`when` == "day", why(x), dpic[x.`when`]))
        })
        val nouns = setOf("day", "meals", "sun")
        s.order("order", 2, d.sequences.flatMap { q ->
            subsets(q.steps).map { st -> OR(q.ask, st, "First ${st.first()}, and last ${st.last()}.") }
        })
        val next = ArrayList<QF>()
        val tfs = ArrayList<TF>()
        for (q in d.sequences) {
            val noun = q.key in nouns
            for (i in q.steps.indices) for (j in q.steps.indices) {
                if (i == j) continue
                val a = q.steps[i]; val b = q.steps[j]
                val first = if (i < j) a else b
                val then = if (i < j) b else a
                val why = if (noun) "${cap(first)} comes before $then." else "We $first first, then we $then."
                tfs += TF(if (noun) "${cap(a)} comes before $b." else "We $a before we $b.", i < j, why)
            }
            for (i in 0 until q.steps.size - 1) {
                val a = q.steps[i]; val b = q.steps[i + 1]
                val wrong = q.steps.filterIndexed { k, _ -> k != i && k != i + 1 }
                val why = if (noun) "${cap(b)} comes just after $a." else "After we $a, we $b."
                next += QF(if (noun) "What comes after $a?" else "What do we do after we $a?", cap(b), wrong.map(::cap), why, cap(b))
            }
        }
        s.qf("next", 1, next)
        s.tf("tfseq", 3, tfs)
        return s.build()
    }
}

/** Classes 2 to 5. */
private class EvsMore(private val d: EvsData, private val k: EvsSkills) {
    private val animals = d.animals
    private val sure = animals.filter { !it.contested }
    private fun th(a: EAnimal) = Th(a.n, a.pic)
    private fun the(a: EAnimal) = art(a.n, a.an)
    private fun The(a: EAnimal) = cap(the(a))
    private fun food(f: EFood) = Noun(f.n, f.form, f.an)
    private fun fth(f: EFood) = Th(f.n, f.pic)
    private fun obj(o: EObject) = Noun(o.n, o.form, o.an)
    private fun aH(h: EHelper) = k.aH(h)
    private val waterHabs = setOf("sea", "fresh")
    private fun hth(h: EHelper) = k.hth(h)
    private fun toolWord(t: String) = k.toolWord(t)
    private fun toolSubj(t: String) = k.toolSubj(t)

    fun all(): List<GenSkill> = listOfNotNull(
        // Class 2
        eats(), covering(), legs(), living(), foodFrom(), materials(), houses(), water(), months(), plantUses(),
        // Class 3
        plantType(), partEat(), rawCooked(), waste(), seeThrough(), relatives(), eggs(), festivals3(), natural(), saveWater(),
        // Class 4
        capitals(), groups(), beaks(), dispersal(), keepFood(), work(), culture(), waterCycle(), habitat(), thenNow(),
        // Class 5
        foodChain(), nutrients(), floatSink(), planets(), lifeCycle(), organs(), energy(), health(), magnets(),
    )

    // ================================================================ Class 2

    private fun eatWhy(a: EAnimal) = when (a.food) {
        "herbivore" -> "${The(a)} eats only plants, so it is a herbivore."
        "carnivore" -> "${The(a)} eats other animals, so it is a carnivore."
        else -> "${The(a)} eats plants and animals, so it is an omnivore."
    }

    private fun eats(): GenSkill? {
        val s = SB("ev2.eats", 2, "Who eats what", "Eat", "herbivores, carnivores and omnivores")
        val fa = sure.filter { it.food != null }
        val herb = fa.filter { it.food == "herbivore" }
        val carn = fa.filter { it.food == "carnivore" }
        val plain = mapOf("herbivore" to "Only plants", "carnivore" to "Only animals", "omnivore" to "Plants and animals")
        s.qf("what", 1, fa.map { a -> QF("What does ${the(a)} eat?", plain[a.food]!!, emptyList(), eatWhy(a), eatWhy(a), a.pic, fixed = plain.values.toList()) })
        s.sort("hc", 1, "Herbivore", "Carnivore", (herb + carn).map { SO(cap(it.n), it.food == "herbivore", eatWhy(it), it.pic) })
        s.qf("which", 2, herb.map { s.choice("Which of these eats only plants?", th(it), carn.map(::th), eatWhy(it)) } +
            carn.map { s.choice("Which of these eats other animals?", th(it), herb.map(::th), eatWhy(it)) } +
            fa.filter { it.food == "omnivore" }.map { s.choice("Which of these eats plants and animals?", th(it), herb.map(::th), eatWhy(it)) })
        s.qf("kind", 3, fa.map { a ->
            QF("What kind of eater is ${the(a)}?", cap(a.food!!), emptyList(), eatWhy(a), eatWhy(a), a.pic, fixed = listOf("Herbivore", "Carnivore", "Omnivore"))
        })
        s.qf("odd", 3, s.odd("does not eat only plants", herb.map(::th), carn.map(::th), { o -> eatWhy(carn.first { it.n == o.name }) }, 8))
        s.tf("tf", 3, fa.flatMap { a ->
            listOf("herbivore", "carnivore", "omnivore").map { f -> TF("${The(a)} is ${aOf(f)}.", a.food == f, eatWhy(a), a.pic) }
        })
        return s.build()
    }

    private fun fam(c: String) = if (c in setOf("fur", "hair", "wool")) "hairy" else c
    private fun coverWord(c: String) = if (c == "skin") "smooth, wet skin" else c
    private fun coverHas(c: String) = if (c == "shell") "a hard shell" else coverWord(c)

    private fun covering(): GenSkill? {
        val s = SB("ev2.covering", 2, "Animal coverings", "Fur", "fur, feathers, scales and shells")
        val ca = sure.filter { it.cover != null }
        val words = listOf("fur", "hair", "wool", "feathers", "scales", "shell", "skin")
        /** Coverings surely not on [c]'s animal: another family, and never scales with shells, never skin. */
        fun wrongFor(c: String) = words.filter { w ->
            fam(w) != fam(c) && w != "skin" && !(setOf(w, c) == setOf("scales", "shell"))
        }
        fun why(a: EAnimal) = "${The(a)}'s body is covered with ${coverHas(a.cover!!)}."
        s.qf("what", 1, ca.map { a ->
            QF("What covers ${the(a)}'s body?", coverWord(a.cover!!), wrongFor(a.cover).map(::coverWord), why(a), why(a), a.pic)
        })
        s.qf("which", 2, ca.map { a ->
            s.choice("Which animal is covered with ${coverHas(a.cover!!)}?", th(a), ca.filter { it.cover in wrongFor(a.cover) }.map(::th), why(a))
        })
        s.sort("ff", 2, "Feathers", "Fur or hair", ca.filter { it.cover == "feathers" || fam(it.cover!!) == "hairy" }
            .map { SO(cap(it.n), it.cover == "feathers", why(it), it.pic) })
        s.qf("odd", 3, s.odd("has no feathers", ca.filter { it.cover == "feathers" }.map(::th), ca.filter { fam(it.cover!!) == "hairy" }.map(::th),
            { o -> why(ca.first { it.n == o.name }) }, 6) +
            s.odd("has no scales", ca.filter { it.cover == "scales" }.map(::th), ca.filter { it.cover in wrongFor("scales") }.map(::th),
                { o -> why(ca.first { it.n == o.name }) }, 5))
        s.tf("tf", 3, ca.flatMapIndexed { i, a ->
            listOf(TF("${The(a)} has ${coverHas(a.cover!!)}.", true, why(a), a.pic)) +
                stride(wrongFor(a.cover).filter { it != "hair" && it != "wool" }, 2, i).map { TF("${The(a)} has ${coverHas(it)}.", false, why(a), a.pic) }
        })
        return s.build()
    }

    private fun legWhy(a: EAnimal) = if (a.legs == 0) "${The(a)} has no legs." else "${The(a)} has ${NUM[a.legs!!]} legs."

    private fun legs(): GenSkill? {
        val s = SB("ev2.legs", 2, "Count the legs", "Legs", "how many legs animals have")
        val la = animals.filter { it.legs != null }
        val counts = listOf(0, 2, 4, 6, 8)
        s.qf("how", 1, la.map { a -> QF("How many legs does ${the(a)} have?", "${a.legs}", counts.filter { it != a.legs }.map { "$it" }, legWhy(a), legWhy(a), a.pic) })
        s.qf("which", 2, la.map { a ->
            val p = if (a.legs == 0) "Which animal has no legs?" else "Which animal has ${NUM[a.legs!!]} legs?"
            s.choice(p, th(a), la.filter { it.legs != a.legs }.map(::th), legWhy(a))
        })
        val kg = la.filter { it.kg }
        val cmp = ArrayList<QF>()
        for (i in kg.indices) for (j in i + 1 until kg.size) {
            val a = kg[i]; val b = kg[j]
            if (a.legs == b.legs) continue
            val more = if (a.legs!! > b.legs!!) a else b
            val less = if (more == a) b else a
            val picsOk = a.pic != null && b.pic != null && a.pic != b.pic
            fun o(x: EAnimal) = if (picsOk) "pic:${x.pic}" else x.n
            val why = "${The(more)} has ${NUM[more.legs!!]} legs, ${the(less)} has ${NUM[less.legs!!]}."
            cmp += QF("Which has more legs, ${the(a)} or ${the(b)}?", o(more), emptyList(), why, cap(more.n), fixed = listOf(o(a), o(b)))
        }
        s.qf("more", 2, cmp.filterIndexed { i, _ -> i % 2 == 0 })
        s.qf("times", 3, kg.filter { it.legs!! > 0 }.flatMap { a ->
            (2..4).map { n ->
                val t = n * a.legs!!
                val wrong = (counts.filter { it > 0 && it != a.legs }.map { it * n } + listOf(a.legs, t + 2, t - 2)).filter { it != t && it > 0 }.distinct()
                QF("How many legs do $n ${a.pl} have?", "$t", wrong.map { "$it" }, "Each ${a.n} has ${a.legs} legs, so $n ${a.pl} have $t.", "$t", a.pic)
            }
        })
        s.tf("tf", 3, la.flatMapIndexed { i, a ->
            listOf(TF(legWhy(a), true, legWhy(a), a.pic)) + stride(counts.filter { it != a.legs }, 2, i).map {
                TF(if (it == 0) "${The(a)} has no legs." else "${The(a)} has ${NUM[it]} legs.", false, legWhy(a), a.pic)
            }
        })
        return s.build()
    }

    private fun plantName(p: EPlant) = when {
        p.n.endsWith("plant") || p.n == "grass" -> p.n
        p.type == "tree" -> "${p.n} tree"
        else -> "${p.n} plant"
    }

    private fun living(): GenSkill? {
        val s = SB("ev2.living", 2, "Living or non-living", "Live", "living and non-living things")
        class L(val th: Th, val subj: String, val living: Boolean, val why: String)
        val organic = setOf("feather", "seashell", "twig", "log of wood", "cork", "cotton ball", "dry leaves", "sponge")
        val out = ArrayList<L>()
        for (a in animals) out += L(th(a), The(a), true, "${The(a)} breathes, eats and grows, so it is living.")
        for (p in d.plants) {
            val n = plantName(p)
            val subj = if (n == "grass") "Grass" else cap(aOf(n))
            out += L(Th(n, p.pic), subj, true, "$subj grows and needs water, so it is living.")
        }
        for (o in d.objects.filter { it.waste != "wet" && it.n !in organic && it.n !in setOf("water", "air") }) {
            val n = obj(o)
            out += L(Th(o.n, objPicOf(o)), n.subj, false, "${n.subj} ${n.v("does", "do")} not breathe, eat or grow.")
        }
        for (t in d.nonlivingTricky) {
            val subj = when (t.n) { "sun", "moon", "wind" -> "The ${t.n}"; "fire", "rain" -> cap(t.n); else -> cap(aOf(t.n)) }
            out += L(Th(t.n, t.pic), subj, false, "$subj ${t.why.removePrefix("it ")}.")
        }
        val liv = out.filter { it.living }
        val non = out.filter { !it.living }
        val kgLiving = liv.filter { l -> animals.any { it.n == l.th.name && it.kg } || d.plants.any { plantName(it) == l.th.name && it.pic != null } }
        s.sort("sort", 1, "Living", "Non-living", kgLiving.map { SO(cap(it.th.name), true, it.why, it.th.pic) } +
            non.filterIndexed { i, _ -> i % 2 == 0 }.map { SO(cap(it.th.name), false, it.why, it.th.pic) })
        s.qf("which", 2, kgLiving.map { s.choice("Which of these is a living thing?", it.th, non.map { n -> n.th }, it.why) } +
            non.map { s.choice("Which of these is non-living?", it.th, kgLiving.map { n -> n.th }, it.why) })
        s.qf("odd", 3, s.odd("is not living", kgLiving.map { it.th }, non.filter { it.th.pic != null }.map { it.th }, { o -> out.first { it.th.name == o.name }.why }, 8))
        s.tf("tf", 3, out.flatMap { l ->
            val be = if (l.subj.endsWith("s") && !l.subj.endsWith("ss") && l.subj.split(" ").size > 1 && !l.subj.startsWith("A")) "are" else "is"
            listOf(TF("${l.subj} $be a living thing.", l.living, l.why, l.th.pic), TF("${l.subj} $be non-living.", !l.living, l.why, l.th.pic))
        })
        return s.build()
    }

    private fun objPicOf(o: EObject): String? {
        val count = d.objects.count { it.pic != null && it.pic == o.pic }
        return o.pic?.takeIf { count == 1 }
    }
    private fun oth(o: EObject) = Th(o.n, objPicOf(o))

    private fun foodFrom(): GenSkill? {
        val s = SB("ev2.foodFrom", 2, "Food from plants", "Farm", "food from plants and from animals")
        val fs = d.foods.filter { it.src != null }
        fun why(f: EFood): String { val n = food(f); return "${n.subj} ${n.v("comes", "come")} from ${if (f.src == "plant") "a plant" else "an animal"}." }
        val pl = fs.filter { it.src == "plant" }
        val an = fs.filter { it.src == "animal" }
        s.sort("sort", 1, "From plants", "From animals", an.map { SO(cap(it.n), false, why(it), it.pic) } +
            pl.filterIndexed { i, _ -> i % 2 == 0 }.map { SO(cap(it.n), true, why(it), it.pic) })
        s.qf("which", 2, an.map { s.choice("Which of these comes from animals?", fth(it), pl.map(::fth), why(it)) } +
            pl.map { s.choice("Which of these comes from plants?", fth(it), an.map(::fth), why(it)) })
        s.qf("odd", 3, s.odd("does not come from a plant", pl.map(::fth), an.map(::fth), { o -> why(an.first { it.n == o.name }) }, 10) +
            s.odd("does not come from an animal", an.map(::fth), pl.map(::fth), { o -> why(pl.first { it.n == o.name }) }, 2))
        s.tf("tf", 3, fs.flatMap { f ->
            val n = food(f)
            listOf(TF("${n.subj} ${n.v("comes", "come")} from plants.", f.src == "plant", why(f), f.pic),
                TF("${n.subj} ${n.v("comes", "come")} from animals.", f.src == "animal", why(f), f.pic))
        })
        return s.build()
    }

    private val materialsAll = listOf("wood", "metal", "plastic", "glass", "paper", "cloth", "clay", "rubber", "leather", "wool", "stone", "wax")
    /** Materials surely not in [made] (wool and cloth are too close to call against each other). */
    private fun notMade(made: List<String>) = materialsAll.filter { m ->
        m !in made && !(m == "cloth" && "wool" in made) && !(m == "wool" && "cloth" in made) && !(m == "stone" && "clay" in made)
    }

    private fun materials(): GenSkill? {
        val s = SB("ev2.materials", 2, "What is it made of?", "Make", "wood, metal, plastic, glass and more")
        val os = d.objects.filter { it.made.isNotEmpty() }
        fun why(o: EObject): String { val n = obj(o); return "${n.subj} ${n.be} made of ${o.made.joinToString(" or ")}." }
        s.qf("what", 1, os.filter { it.made.size == 1 }.map { o -> QF("What is ${obj(o).obj} made of?", cap(o.made[0]), notMade(o.made).map(::cap), why(o), why(o), objPicOf(o)) })
        s.qf("which", 2, materialsAll.flatMap { m ->
            os.filter { m in it.made }.map { o -> s.choice("Which of these is made of $m?", oth(o), os.filter { m in notMade(it.made) }.map(::oth), why(o)) }
        })
        s.sort("wm", 2, "Wood", "Metal", os.filter { ("wood" in it.made) != ("metal" in it.made) && it.made.size == 1 }
            .map { SO(cap(it.n), "wood" in it.made, why(it), objPicOf(it)) })
        s.qf("odd", 3, listOf("wood", "metal", "plastic", "glass", "paper", "cloth").flatMap { m ->
            s.odd("is not made of $m", os.filter { it.made == listOf(m) }.map(::oth), os.filter { m in notMade(it.made) }.map(::oth),
                { o -> why(os.first { it.n == o.name }) }, 2)
        })
        s.tf("tf", 3, os.flatMapIndexed { i, o ->
            val n = obj(o)
            o.made.map { TF("${n.subj} ${n.be} made of $it.", true, why(o), objPicOf(o)) } +
                stride(notMade(o.made), 3, i).map { TF("${n.subj} ${n.be} made of $it.", false, why(o), objPicOf(o)) }
        })
        return s.build()
    }

    private fun houses(): GenSkill? {
        val s = SB("ev2.houses", 2, "Houses we live in", "Home", "kinds of houses and what they are made of")
        val hs = d.houses
        val feat = d.houseFeatures.associateBy { it.key }
        fun hth(h: EHouse) = Th(h.n, h.pic)
        fun aHo(h: EHouse) = art(h.n, h.an)
        fun madeWhy(h: EHouse) = "${cap(aHo(h))} is made of ${h.made.joinToString(" and ")}."
        s.qf("feat", 1, hs.flatMap { h ->
            h.features.map { f -> s.choice("Which house ${feat[f]!!.text}?", hth(h), hs.filter { f !in it.features }.map(::hth), feat[f]!!.why, visual = null) }
        })
        s.qf("made", 1, hs.flatMap { h ->
            h.made.map { m -> QF("What is ${aHo(h)} made of?", cap(m), d.houseMaterials.filter { it !in h.made }.map(::cap), madeWhy(h), madeWhy(h), h.pic) }
        })
        val kWhy = mapOf("kutcha" to "Kutcha houses are made of mud, straw or bamboo.", "pucca" to "Pucca houses are made of bricks, cement or stone.")
        val parts = d.kutchaPucca
        s.sort("kp", 2, "Kutcha", "Pucca", parts.map { SO(cap(it.n), it.kind == "kutcha", kWhy[it.kind]!!) } +
            hs.filter { it.kind != null }.map { SO(cap(it.n), it.kind == "kutcha", kWhy[it.kind]!!, it.pic) })
        s.qf("kind", 2, parts.map { p ->
            QF("Which of these is part of a ${p.kind} house?", cap(p.n), parts.filter { it.kind != p.kind }.map { cap(it.n) }, kWhy[p.kind]!!, cap(p.n))
        } + hs.filter { it.kind != null }.map { h ->
            s.choice("Which of these is a ${h.kind} house?", hth(h), hs.filter { it.kind != null && it.kind != h.kind }.map(::hth), kWhy[h.kind]!!)
        })
        s.qf("odd", 3, s.odd("is not used for a kutcha house", listOf("mud", "straw", "bamboo", "leaves").map { Th(it) },
            listOf("bricks", "cement", "stone", "marble").map { Th(it) }, { kWhy["kutcha"]!! }, 4))
        s.tf("tf", 3, hs.flatMapIndexed { i, h ->
            h.made.map { TF("${cap(aHo(h))} is made of $it.", true, madeWhy(h), h.pic) } +
                stride(d.houseMaterials.filter { it !in h.made }, 4, i).map { TF("${cap(aHo(h))} is made of $it.", false, madeWhy(h), h.pic) } +
                h.features.map { TF("${cap(aHo(h))} ${feat[it]!!.text}.", true, feat[it]!!.why, h.pic) } +
                stride(feat.keys.filter { it !in h.features }, 3, i).map {
                    TF("${cap(aHo(h))} ${feat[it]!!.text}.", false, if (h.features.isEmpty()) madeWhy(h) else feat[h.features[0]]!!.why, h.pic)
                }
        } + parts.flatMap { p ->
            listOf("kutcha", "pucca").map { kd -> TF("A house with ${p.n} is $kd.", kd == p.kind, kWhy[p.kind]!!) }
        })
        return s.build()
    }

    private fun srcName(n: String) = when (n) { "sea", "ocean" -> "the $n"; "rain" -> "rain"; else -> aOf(n) }

    private fun water(): GenSkill? {
        val s = SB("ev2.water", 2, "Water around us", "Tap", "sources of water and safe water")
        val ws = d.waterSources
        fun wth(w: EWaterSource) = Th(w.n, w.pic)
        fun why(w: EWaterSource) = if (w.natural) "${cap(srcName(w.n))} is made by nature, not by people." else "People make ${srcName(w.n)} to get water."
        fun saltWhy(w: EWaterSource) = if (w.salty) "Water in ${srcName(w.n)} is salty." else "${cap(srcName(w.n))} has fresh water, not salty water."
        val nat = ws.filter { it.natural }
        val made = ws.filter { !it.natural }
        s.sort("sort", 1, "Natural", "Made by people", ws.map { SO(cap(it.n), it.natural, why(it), it.pic) })
        s.qf("which", 2, nat.map { s.choice("Which of these is a natural source of water?", wth(it), made.map(::wth), why(it)) } +
            made.map { s.choice("Which of these is made by people?", wth(it), nat.map(::wth), why(it)) } +
            ws.filter { it.salty }.map { s.choice("Which of these has salty water?", wth(it), nat.filter { n -> !n.salty }.map(::wth), saltWhy(it)) })
        s.qf("odd", 3, s.odd("is not made by people", made.map(::wth), nat.map(::wth), { o -> why(ws.first { it.n == o.name }) }, 8, needPics = false) +
            s.odd("is not natural", nat.map(::wth), made.map(::wth), { o -> why(ws.first { it.n == o.name }) }, 8, needPics = false))
        val safe = d.safeWater.filter { it.safe != null }
        fun safeWhy(x: EFlag) = when {
            x.safe == true -> "Boiling or filtering takes the germs out of water."
            x.n == "sea water" -> "Sea water is far too salty to drink."
            else -> "${cap(x.n)} can have germs that make us ill."
        }
        s.qf("safe", 2, safe.map { x ->
            QF(if (x.safe == true) "Which water is safe to drink?" else "Which water is not safe to drink?", cap(x.n),
                safe.filter { it.safe != x.safe }.map { cap(it.n) }, safeWhy(x), cap(x.n))
        })
        s.tf("tf", 3, ws.flatMap { w ->
            listOf(TF("${cap(srcName(w.n))} is made by people.", !w.natural, why(w), w.pic), TF("${cap(srcName(w.n))} is natural.", w.natural, why(w), w.pic)) +
                (if (w.natural) listOf(TF("${cap(srcName(w.n))} has salty water.", w.salty, saltWhy(w), w.pic)) else emptyList())
        } + safe.map { TF("${cap(it.n)} is safe to drink.", it.safe == true, safeWhy(it)) })
        return s.build()
    }

    private fun months(): GenSkill? {
        val s = SB("ev2.months", 2, "Months and days", "Cal", "months of the year and days of the week")
        val ms = d.months.map { it.n }
        val ds = d.days
        val ord = listOf("first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth", "eleventh", "twelfth")
        fun near(list: List<String>, i: Int) = list.indices.filter { it != i }.sortedBy { kotlin.math.abs(it - i) }.map { list[it] }
        val one = ArrayList<QF>()
        for (list in listOf(ms, ds)) {
            val what = if (list === ms) "month" else "day"
            for (i in list.indices) {
                val nx = list[(i + 1) % list.size]
                val pv = list[(i - 1 + list.size) % list.size]
                if (list === ms && i == 11 || list === ds && i == 6) { /* wraps: still true */ }
                one += QF("Which $what comes after ${list[i]}?", nx, near(list, (i + 1) % list.size).filter { it != list[i] }.take(4), "$nx comes after ${list[i]}.", "$nx comes after ${list[i]}.")
                one += QF("Which $what comes before ${list[i]}?", pv, near(list, (i - 1 + list.size) % list.size).filter { it != list[i] }.take(4), "$pv comes before ${list[i]}.", "$pv comes before ${list[i]}.")
            }
        }
        s.qf("next", 1, one)
        s.qf("nth", 1, ms.indices.map { i ->
            QF("Which is the ${ord[i]} month of the year?", ms[i], near(ms, i).take(4), "${ms[i]} is month number ${i + 1}.", ms[i])
        } + ds.indices.map { i ->
            QF("If today is ${ds[i]}, what day is tomorrow?", ds[(i + 1) % 7], near(ds, (i + 1) % 7).take(4), "The day after ${ds[i]} is ${ds[(i + 1) % 7]}.", ds[(i + 1) % 7])
        } + ds.indices.map { i ->
            QF("If today is ${ds[i]}, what day was yesterday?", ds[(i + 6) % 7], near(ds, (i + 6) % 7).take(4), "The day before ${ds[i]} is ${ds[(i + 6) % 7]}.", ds[(i + 6) % 7])
        })
        s.qf("days", 2, d.months.map { m ->
            val wrong = if (m.n == "February") listOf("30", "31") else listOf(28, 30, 31).filter { it != m.days }.map { "$it" }
            val why = if (m.n == "February") "February has 28 days, or 29 in a leap year." else "${m.n} has ${m.days} days."
            QF(if (m.n == "February") "How many days does February have in most years?" else "How many days does ${m.n} have?", "${m.days}", wrong, why, why)
        } + ds.indices.flatMap { i ->
            (2..3).map { k -> QF("What day is it $k days after ${ds[i]}?", ds[(i + k) % 7], near(ds, (i + k) % 7).filter { it != ds[i] }.take(4),
                "Count $k days on from ${ds[i]} to reach ${ds[(i + k) % 7]}.", ds[(i + k) % 7]) }
        })
        s.order("order", 2, subsets(ms).filter { it.size == 3 }.map { OR("Put the months in order.", it, "${it[0]} comes first, then ${it[1]}, then ${it[2]}.") } +
            subsets(ds).filter { it.size == 3 }.map { OR("Put the days in order.", it, "${it[0]} comes first, then ${it[1]}, then ${it[2]}.") })
        s.order("order4", 3, subsets(ms).filter { it.size == 4 }.filterIndexed { i, _ -> i % 2 == 0 }.map { OR("Put the months in order.", it, "${it[0]} comes first and ${it[3]} comes last.") } +
            subsets(ds).filter { it.size == 4 }.map { OR("Put the days in order.", it, "${it[0]} comes first and ${it[3]} comes last.") })
        s.tf("tf", 3, d.months.flatMap { m ->
            listOf(28, 30, 31).filter { !(m.n == "February" && it == 28) }.map {
                TF("${m.n} has $it days.", it == m.days, if (m.n == "February") "February has 28 days, or 29 in a leap year." else "${m.n} has ${m.days} days.")
            }
        } + ds.indices.flatMap { i ->
            listOf(TF("${ds[(i + 1) % 7]} comes after ${ds[i]}.", true, "${ds[(i + 1) % 7]} comes just after ${ds[i]}."),
                TF("${ds[i]} comes after ${ds[(i + 1) % 7]}.", false, "${ds[(i + 1) % 7]} comes just after ${ds[i]}."))
        })
        return s.build()
    }

    private val products = listOf("oil", "fibre", "rubber", "tea", "coffee", "sugar", "spice", "dye", "medicine", "wood")
    private val mainSource = mapOf(
        "oil" to "mustard", "fibre" to "cotton", "rubber" to "rubber tree", "tea" to "tea", "coffee" to "coffee", "sugar" to "sugarcane",
        "spice" to "black pepper", "dye" to "henna", "medicine" to "tulsi", "wood" to "teak tree",
    )
    private val soft = setOf("herb", "climber", "creeper")

    /** Plants that surely do not give us [p]. */
    private fun noProduct(p: String) = d.plants.filter { pl ->
        p !in pl.uses && if (p == "wood") pl.type in soft else pl.none
    }

    private fun plantUses(): GenSkill? {
        val s = SB("ev2.plantUses", 2, "Gifts of plants", "Tree", "what we get from plants")
        fun pth(p: EPlant) = Th(plantName(p), p.pic)
        fun why(p: EPlant, u: String) = "We get $u from the ${plantName(p)}."
        val ps = d.plants
        s.qf("which", 1, products.flatMap { u ->
            ps.filter { u in it.uses }.map { p -> s.choice("Which plant gives us $u?", pth(p), noProduct(u).map(::pth), why(p, u)) }
        })
        val exclusive = listOf("rubber", "tea", "coffee", "sugar")
        s.qf("what", 2, ps.flatMap { p ->
            p.uses.filter { it in products }.map { u ->
                val wrong = exclusive.filter { it !in p.uses && !(it == "sugar" && p.n == "coconut") } + (if (p.type in soft) listOf("wood") else emptyList())
                QF("What do we get from the ${plantName(p)}?", cap(u), wrong.map(::cap), why(p, u), why(p, u), p.pic)
            }
        })
        s.qf("odd", 3, listOf("oil", "fibre", "spice", "wood", "medicine").flatMap { u ->
            s.odd("does not give us $u", ps.filter { u in it.uses }.map(::pth), noProduct(u).map(::pth), { o ->
                val src = mainSource[u]!!
                "We get $u from plants like the ${if (src.endsWith("tree")) src else "$src plant"}."
            }, 4)
        })
        s.tf("tf", 3, ps.flatMapIndexed { i, p ->
            p.uses.filter { it in products }.map { TF(why(p, it), true, why(p, it), p.pic) } +
                stride(products.filter { u -> p in noProduct(u) }, 3, i).map { u ->
                    val src = mainSource[u]!!
                    TF("We get $u from the ${plantName(p)}.", false, "We get $u from the ${if (src.endsWith("tree")) src else "$src plant"}, not this.", p.pic)
                }
        })
        return s.build()
    }

    // ================================================================ Class 3

    private val typeWhy = mapOf(
        "tree" to "is a tree with a thick, woody trunk.",
        "shrub" to "is a shrub with many woody stems.",
        "herb" to "is a herb with a soft, green stem.",
        "climber" to "is a climber that climbs up a support.",
        "creeper" to "is a creeper that spreads on the ground.",
    )

    private fun plantType(): GenSkill? {
        val s = SB("ev3.plantType", 3, "Trees, shrubs, herbs", "Leaf", "trees, shrubs, herbs, climbers and creepers")
        val ps = d.plants.filter { it.type != null }
        fun pn(p: EPlant) = cap(aOf(if (p.n.endsWith("plant")) p.n else "${p.n} plant"))
        fun why(p: EPlant) = "${pn(p)} ${typeWhy[p.type]}"
        fun pth(p: EPlant) = Th(p.n, p.pic)
        val types = typeWhy.keys.toList()
        s.qf("kind", 1, ps.map { p -> QF("What kind of plant is ${if (p.n.endsWith("plant")) "a " + p.n else p.n}?", cap(p.type!!), types.filter { it != p.type }.map(::cap), why(p), why(p), p.pic) })
        s.qf("which", 2, ps.map { p -> s.choice("Which of these is ${aOf(p.type!!)}?", pth(p), ps.filter { it.type != p.type }.map(::pth), why(p)) })
        s.sort("th", 2, "Tree", "Herb", ps.filter { it.type == "tree" || it.type == "herb" }.map { SO(cap(it.n), it.type == "tree", why(it), it.pic) })
        s.qf("odd", 3, types.flatMap { t ->
            s.odd("is not ${aOf(t)}", ps.filter { it.type == t }.map(::pth), ps.filter { it.type != t }.map(::pth), { o -> why(ps.first { it.n == o.name }) }, 3)
        })
        s.tf("tf", 3, ps.flatMapIndexed { i, p ->
            listOf(TF("${pn(p)} is ${aOf(p.type!!)}.", true, why(p), p.pic)) +
                stride(types.filter { it != p.type }, 2, i).map { TF("${pn(p)} is ${aOf(it)}.", false, why(p), p.pic) }
        })
        return s.build()
    }

    private val partTricky = mapOf(
        "potato" to "A potato grows underground but is a stem, not a root.",
        "ginger" to "Ginger grows underground but is a stem, not a root.",
        "turmeric" to "Turmeric grows underground but is a stem, not a root.",
        "sweet potato" to "A sweet potato is a root, unlike a potato.",
    )

    private fun partWhy(f: EFood): String {
        partTricky[f.n]?.let { return it }
        val n = food(f)
        val word = if (f.part == "leaf") "leaves" else f.part!!
        return "${n.subj} ${n.be} the $word of ${if (n.plural) "their" else "its"} plant."
    }

    private fun partEat(): GenSkill? {
        val s = SB("ev3.partEat", 3, "Plant parts we eat", "Root", "roots, stems, leaves, flowers, fruits and seeds we eat")
        val fs = d.foods.filter { it.part != null && it.src == "plant" }
        val parts = listOf("root", "stem", "leaf", "flower", "fruit", "seed")
        fun word(p: String) = if (p == "leaf") "Leaves" else cap(p)
        s.qf("what", 1, fs.map { f ->
            val n = food(f)
            QF("Which part of the plant ${if (n.plural) "are" else "is"} ${n.obj}?", word(f.part!!), parts.filter { it != f.part }.map(::word), partWhy(f), partWhy(f), f.pic)
        })
        s.qf("which", 2, fs.map { f ->
            s.choice("In which of these do we eat the ${if (f.part == "leaf") "leaves" else f.part}?", fth(f), fs.filter { it.part != f.part }.map(::fth), partWhy(f))
        })
        s.sort("rs", 2, "Root", "Stem", fs.filter { it.part == "root" || it.part == "stem" }.map { SO(cap(it.n), it.part == "root", partWhy(it), it.pic) })
        s.sort("ls", 2, "Leaves", "Seeds", fs.filter { it.part == "leaf" || it.part == "seed" }.map { SO(cap(it.n), it.part == "leaf", partWhy(it), it.pic) })
        s.qf("odd", 3, parts.flatMap { p ->
            s.odd("is not ${if (p == "leaf") "leaves" else aOf(p)} we eat", fs.filter { it.part == p }.map(::fth), fs.filter { it.part != p }.map(::fth),
                { o -> partWhy(fs.first { it.n == o.name }) }, 2)
        })
        s.tf("tf", 3, fs.flatMapIndexed { i, f ->
            val n = food(f)
            fun st(p: String) = "We eat the ${if (p == "leaf") "leaves" else p} of the ${f.n} plant."
            if (n.plural || f.form == "m" && f.n.contains(" ")) {
                listOf(TF("${n.subj} are the ${f.part} part of a plant.", true, partWhy(f), f.pic)) +
                    stride(parts.filter { it != f.part }, 2, i).map { TF("${n.subj} are the $it part of a plant.", false, partWhy(f), f.pic) }
            } else listOf(TF(st(f.part!!), true, partWhy(f), f.pic)) + stride(parts.filter { it != f.part }, 2, i).map { TF(st(it), false, partWhy(f), f.pic) }
        })
        return s.build()
    }

    private val methodWord = mapOf("steam" to "Steamed", "fry" to "Fried", "bake" to "Baked", "boil" to "Boiled", "roast" to "Roasted")
    private val methodWhy = mapOf("steam" to "in steam", "fry" to "in hot oil", "bake" to "in an oven", "boil" to "in boiling water", "roast" to "over a fire")

    private fun rawCooked(): GenSkill? {
        val s = SB("ev3.rawCooked", 3, "Raw or cooked", "Cook", "food we eat raw, and how food is cooked")
        val fs = d.foods.filter { it.cook != null }
        fun why(f: EFood): String {
            val n = food(f)
            return when (f.cook) {
                "raw" -> "We can eat ${n.obj} raw, without cooking."
                "cooked" -> "We cook ${n.obj} to make it soft and safe."
                else -> "We can eat ${n.obj} raw or cooked."
            }
        }
        val raw = fs.filter { it.cook == "raw" }
        val cooked = fs.filter { it.cook == "cooked" }
        s.sort("sort", 1, "Eaten raw", "Cooked first", (raw + cooked).map { SO(cap(it.n), it.cook == "raw", why(it), it.pic) })
        s.qf("which", 2, fs.filter { it.cook != "cooked" }.map { s.choice("Which of these can we eat raw?", fth(it), cooked.map(::fth), why(it)) } +
            cooked.map { s.choice("Which of these must be cooked first?", fth(it), raw.map(::fth), why(it)) })
        val ms = d.foods.filter { it.method != null }
        fun mWhy(f: EFood): String { val n = food(f); return "${n.subj} ${n.be} cooked ${methodWhy[f.method]}." }
        s.qf("how", 2, ms.map { f -> QF("How ${if (food(f).plural) "are" else "is"} ${food(f).obj} cooked?", methodWord[f.method]!!, methodWord.filterKeys { it != f.method }.values.toList(), mWhy(f), mWhy(f), f.pic) })
        s.qf("odd", 3, s.odd("is not fried", ms.filter { it.method == "fry" }.map(::fth), ms.filter { it.method != "fry" }.map(::fth), { o -> mWhy(ms.first { it.n == o.name }) }, 6))
        s.tf("tf", 3, fs.flatMap { f ->
            val n = food(f)
            when (f.cook) {
                "raw" -> listOf(TF("We can eat ${n.obj} raw.", true, why(f), f.pic), TF("We must cook ${n.obj} before eating.", false, why(f), f.pic))
                "cooked" -> listOf(TF("We must cook ${n.obj} before eating.", true, why(f), f.pic), TF("We can eat ${n.obj} raw.", false, why(f), f.pic))
                else -> listOf(TF("We can eat ${n.obj} raw or cooked.", true, why(f), f.pic))
            }
        } + ms.flatMapIndexed { i, f ->
            val n = food(f)
            listOf(TF("${n.subj} ${n.be} ${methodWord[f.method]!!.lowercase()}.", true, mWhy(f), f.pic)) +
                stride(methodWord.keys.filter { it != f.method }, 2, i).map { TF("${n.subj} ${n.be} ${methodWord[it]!!.lowercase()}.", false, mWhy(f), f.pic) }
        })
        return s.build()
    }

    private fun waste(): GenSkill? {
        val s = SB("ev3.waste", 3, "Wet or dry waste", "Bin", "sorting waste into wet and dry")
        val ws = d.objects.filter { it.waste != null }
        fun why(o: EObject): String {
            val n = obj(o)
            return if (o.waste == "wet") "${n.subj} ${n.v("rots", "rot")} easily, so ${if (n.plural) "they are" else "it is"} wet waste."
            else "${n.subj} ${n.v("rots", "rot")} very slowly, so ${if (n.plural) "they are" else "it is"} dry waste."
        }
        val wet = ws.filter { it.waste == "wet" }
        val dry = ws.filter { it.waste == "dry" }
        s.sort("sort", 1, "Wet waste", "Dry waste", ws.map { SO(cap(it.n), it.waste == "wet", why(it), objPicOf(it)) })
        s.qf("which", 2, wet.map { s.choice("Which of these is wet waste?", oth(it), dry.map(::oth), why(it)) } +
            dry.map { s.choice("Which of these is dry waste?", oth(it), wet.map(::oth), why(it)) })
        val lasting = dry.filter { o -> o.made.any { it in setOf("plastic", "glass", "metal", "rubber") } }
        s.qf("rot", 3, wet.map { s.choice("Which of these can rot and become compost?", oth(it), lasting.map(::oth), why(it)) })
        s.qf("odd", 3, s.odd("is not wet waste", wet.map(::oth), dry.map(::oth), { o -> why(ws.first { it.n == o.name }) }, 6) +
            s.odd("is not dry waste", dry.map(::oth), wet.map(::oth), { o -> why(ws.first { it.n == o.name }) }, 6))
        s.tf("tf", 3, ws.flatMap { o ->
            val n = obj(o)
            listOf(TF("${n.subj} ${n.be} wet waste.", o.waste == "wet", why(o), objPicOf(o)), TF("${n.subj} ${n.be} dry waste.", o.waste == "dry", why(o), objPicOf(o)))
        })
        return s.build()
    }

    private fun seeThrough(): GenSkill? {
        val s = SB("ev3.seeThrough", 3, "See-through or not", "Glass", "see-through, hard and soft things")
        val st = d.objects.filter { it.seeThrough != null }
        fun why(o: EObject): String {
            val n = obj(o)
            return if (o.seeThrough == true) "Light passes through ${n.obj}, so we can see through." else "Light cannot pass through ${n.obj}."
        }
        val yes = st.filter { it.seeThrough == true }
        val no = st.filter { it.seeThrough == false }
        s.sort("see", 1, "See-through", "Not see-through", yes.map { SO(cap(it.n), true, why(it), objPicOf(it)) } +
            no.filterIndexed { i, _ -> i % 3 == 0 }.map { SO(cap(it.n), false, why(it), objPicOf(it)) })
        s.qf("which", 2, yes.map { s.choice("Which of these can we see through?", oth(it), no.map(::oth), why(it)) } +
            no.filterIndexed { i, _ -> i % 3 != 0 }.map { s.choice("Which of these can we not see through?", oth(it), yes.map(::oth), why(it)) })
        val hs = d.objects.filter { it.feel != null && it.waste != "wet" && it.n != "leftover food" }
        fun fWhy(o: EObject): String { val n = obj(o); return if (o.feel == "hard") "${n.subj} ${n.v("keeps", "keep")} ${n.its} shape when pressed." else "${n.subj} ${n.v("squashes", "squash")} easily when pressed." }
        val soft = hs.filter { it.feel == "soft" }
        val hard = hs.filter { it.feel == "hard" }
        s.sort("hs", 2, "Hard", "Soft", soft.map { SO(cap(it.n), false, fWhy(it), objPicOf(it)) } + hard.filterIndexed { i, _ -> i % 3 == 0 }.map { SO(cap(it.n), true, fWhy(it), objPicOf(it)) })
        s.qf("feel", 2, soft.map { s.choice("Which of these is soft?", oth(it), hard.map(::oth), fWhy(it)) } +
            hard.filterIndexed { i, _ -> i % 3 != 0 }.map { s.choice("Which of these is hard?", oth(it), soft.map(::oth), fWhy(it)) })
        s.qf("odd", 3, s.odd("is not see-through", yes.map(::oth), no.map(::oth), { o -> why(st.first { it.n == o.name }) }, 2))
        s.tf("tf", 3, st.flatMap { o ->
            val n = obj(o)
            listOf(TF("We can see through ${n.obj}.", o.seeThrough == true, why(o), objPicOf(o)))
        } + hs.flatMap { o ->
            val n = obj(o)
            listOf(TF("${n.subj} ${n.be} soft.", o.feel == "soft", fWhy(o), objPicOf(o)), TF("${n.subj} ${n.be} hard.", o.feel == "hard", fWhy(o), objPicOf(o)))
        })
        return s.build()
    }

    /** One- and two-step family relations: (path, word). */
    private val chains = listOf(
        "mother's mother" to "grandmother", "mother's father" to "grandfather", "father's mother" to "grandmother", "father's father" to "grandfather",
        "mother's brother" to "uncle", "father's brother" to "uncle", "mother's sister" to "aunt", "father's sister" to "aunt",
        "mother's son" to "brother", "father's daughter" to "sister",
        "uncle's son" to "cousin", "aunt's daughter" to "cousin", "uncle's daughter" to "cousin", "aunt's son" to "cousin",
        "brother's son" to "nephew", "sister's son" to "nephew", "brother's daughter" to "niece", "sister's daughter" to "niece",
        "son's son" to "grandson", "daughter's son" to "grandson", "son's daughter" to "granddaughter", "daughter's daughter" to "granddaughter",
        "father's sister's son" to "cousin", "mother's brother's daughter" to "cousin",
        "father's father's father" to "great-grandfather", "mother's mother's mother" to "great-grandmother",
    )
    private val hindi = listOf(
        "mother's brother" to "mama", "mother's sister" to "mausi", "father's sister" to "bua", "father's younger brother" to "chacha",
        "father's mother" to "dadi", "father's father" to "dada", "mother's mother" to "nani", "mother's father" to "nana",
    )

    private fun relatives(): GenSkill? {
        val s = SB("ev3.relatives", 3, "Family and relatives", "Fam", "family relations")
        val words = chains.map { it.second }.distinct()
        val ns = d.names
        fun his(n: EName) = if (n.girl) "her" else "his"
        val tier1 = setOf("grandmother", "grandfather", "uncle", "aunt", "brother", "sister")
        val c1 = ArrayList<QF>(); val c2 = ArrayList<QF>()
        chains.forEachIndexed { ci, (path, w) ->
            // "mother's son" could be the child itself; only for a girl is it surely a brother.
            ns.forEachIndexed { ni, n ->
                if (path == "mother's son" && !n.girl || path == "father's daughter" && n.girl) return@forEachIndexed
                if ((ci + ni) % 2 == 1) return@forEachIndexed
                val why = "A $path is ${aOf(w)}."
                val q = QF("${n.n}'s $path is ${his(n)} …?", cap(w), words.filter { it != w }.map(::cap), why, "${n.n}'s $path is ${his(n)} $w.")
                if (w in tier1 && path.count { it == '\'' } == 1) c1 += q else c2 += q
            }
        }
        s.qf("chain1", 1, c1)
        s.qf("chain2", 2, c2)
        val back = listOf("mother" to true, "father" to false, "grandmother" to true, "grandfather" to false, "aunt" to true, "uncle" to false, "sister" to true, "brother" to false)
        fun child(rel: String, girl: Boolean) = when (rel) {
            "mother", "father" -> if (girl) "daughter" else "son"
            "grandmother", "grandfather" -> if (girl) "granddaughter" else "grandson"
            "aunt", "uncle" -> if (girl) "niece" else "nephew"
            else -> if (girl) "sister" else "brother"
        }
        val rev = ArrayList<QF>()
        back.forEachIndexed { ri, (rel, female) ->
            val as_ = ns.filter { it.girl == female }
            as_.forEachIndexed { ai, a ->
                for (k in 0 until 3) {
                    val b = ns[(ai * 5 + ri * 3 + k * 11) % ns.size]
                    if (b.n == a.n) continue
                    val w = child(rel, b.girl)
                    val opts = listOf("son", "daughter", "grandson", "granddaughter", "nephew", "niece", "brother", "sister").filter { it != w }
                    rev += QF("${a.n} is ${b.n}'s $rel. ${b.n} is ${a.n}'s …?", cap(w), opts.map(::cap),
                        "${b.n} is ${a.n}'s $w.", "${b.n} is ${a.n}'s $w.")
                }
            }
        }
        s.qf("back", 2, rev)
        s.qf("hindi", 3, hindi.flatMap { (path, w) ->
            ns.filterIndexed { i, _ -> i % 3 == 0 }.map { n ->
                QF("In Hindi, ${n.n} calls ${his(n)} $path …?", cap(w), hindi.map { it.second }.filter { it != w }.map(::cap),
                    "In Hindi, a $path is called $w.", cap(w))
            }
        })
        s.tf("tf", 3, chains.flatMapIndexed { ci, (path, w) ->
            listOf(TF("Your $path is your $w.", true, "Your $path is your $w.")) +
                stride(words.filter { it != w && !(w == "cousin") }, 2, ci).map { TF("Your $path is your $it.", false, "Your $path is your $w.") }
        })
        return s.build()
    }

    private fun eggWhy(a: EAnimal) = when {
        a.birth == "eggs" -> "Baby ${a.pl} hatch from eggs."
        a.group == "mammal" -> "${The(a)} gives birth to babies and feeds them milk."
        else -> "${The(a)} gives birth to live babies."
    }

    private fun eggs(): GenSkill? {
        val s = SB("ev3.eggs", 3, "Eggs or babies", "Egg", "animals that lay eggs and that give birth")
        val ba = sure.filter { it.birth != null }
        val e = ba.filter { it.birth == "eggs" }
        val l = ba.filter { it.birth == "live" }
        s.sort("sort", 1, "Lays eggs", "Gives birth", ba.filter { it.kg || it.birth == "live" }.map { SO(cap(it.n), it.birth == "eggs", eggWhy(it), it.pic) })
        s.qf("which", 2, e.map { s.choice("Which of these lays eggs?", th(it), l.map(::th), eggWhy(it)) } +
            l.map { s.choice("Which of these gives birth to babies?", th(it), e.map(::th), eggWhy(it)) })
        s.qf("odd", 3, s.odd("does not lay eggs", e.map(::th), l.map(::th), { o -> eggWhy(l.first { it.n == o.name }) }, 6) +
            s.odd("does not give birth", l.map(::th), e.map(::th), { o -> eggWhy(e.first { it.n == o.name }) }, 3))
        s.tf("tf", 3, ba.flatMap { a ->
            listOf(TF("${The(a)} lays eggs.", a.birth == "eggs", eggWhy(a), a.pic), TF("${The(a)} gives birth to babies.", a.birth == "live", eggWhy(a), a.pic))
        })
        return s.build()
    }

    private val regional = setOf("Onam", "Vishu", "Pongal", "Bihu", "Lohri", "Baisakhi", "Chhath", "Bathukamma", "Hornbill Festival", "Gudi Padwa", "Ugadi")
    private val twins = listOf(setOf("Punjab", "Haryana"), setOf("Andhra Pradesh", "Telangana"), setOf("Bihar", "Jharkhand"),
        setOf("Madhya Pradesh", "Chhattisgarh"), setOf("Uttar Pradesh", "Uttarakhand"), setOf("Punjab", "Himachal Pradesh"))
    private fun twin(a: String, b: String) = twins.any { a in it && b in it }
    private fun shortState(n: String) = n.length <= 24

    private fun festivals3(): GenSkill? {
        val s = SB("ev3.festivals", 3, "Festivals of India", "Mela", "festivals of our states")
        val states = d.india.filter { it.kind == "state" && shortState(it.n) }
        val fests = d.festivals.associateBy { it.n }
        val qs = ArrayList<QF>()
        val tfs = ArrayList<TF>()
        for (st in states) for (f in st.festivals.filter { it in regional }) {
            val has = states.filter { f in it.festivals }.map { it.n }
            val why = "$f is a big festival in ${st.n}."
            qs += QF("$f is a big festival in which state?", st.n, states.filter { it.n !in has && has.none { h -> twin(h, it.n) } }.map { it.n }, why, why)
        }
        s.qf("state", 1, qs)
        s.qf("fest", 2, states.flatMap { st ->
            st.festivals.filter { it in regional }.map { f ->
                QF("Which of these is a big festival in ${st.n}?", f, regional.filter { it !in st.festivals && states.none { o -> it in o.festivals && twin(o.n, st.n) } }.toList(),
                    "$f is a big festival in ${st.n}.", f, fests[f]?.pic)
            }
        })
        val harvest = d.festivals.filter { "harvest" in it.features }
        val notHarvest = d.festivals.filter { "harvest" !in it.features && "harvest" !in it.maybe }
        s.qf("harvest", 2, harvest.map { f ->
            QF("Which of these is a harvest festival?", f.n, notHarvest.map { it.n }, "${f.n} is a harvest festival, when crops are cut.", f.n, f.pic)
        })
        val dated = d.festivals.filter { it.date != null }
        s.qf("date", 2, dated.map { f -> QF("On which date is ${f.n}?", f.date!!, dated.filter { it != f }.map { it.date!! }, "${f.n} is on ${f.date}.", "${f.n} is on ${f.date}.", f.pic) })
        val foods = d.festivals.flatMap { f -> f.foods.map { it to f } }
        s.qf("food", 2, foods.map { (food, f) ->
            QF("${cap(food)} is made for which festival?", f.n, d.festivals.filter { food !in it.foods && food !in it.maybe }.map { it.n }, "People make $food for ${f.n}.", f.n, f.pic)
        })
        states.forEachIndexed { i, st ->
            for (f in st.festivals.filter { it in regional }) {
                tfs += TF("$f is a big festival in ${st.n}.", true, "$f is a big festival in ${st.n}.", fests[f]?.pic)
                for (o in stride(states.filter { f !in it.festivals && !twin(it.n, st.n) }, 3, i)) {
                    tfs += TF("$f is a big festival in ${o.n}.", false, "$f is a big festival in ${st.n}.", fests[f]?.pic)
                }
            }
        }
        tfs += harvest.map { TF("${it.n} is a harvest festival.", true, "${it.n} is a harvest festival, when crops are cut.", it.pic) }
        tfs += notHarvest.map { TF("${it.n} is a harvest festival.", false, "${it.n} is not a harvest festival.", it.pic) }
        tfs += foods.flatMapIndexed { i, (food, f) ->
            listOf(TF("People make $food for ${f.n}.", true, "People make $food for ${f.n}.", f.pic)) +
                stride(d.festivals.filter { food !in it.foods && food !in it.maybe }, 2, i).map { TF("People make $food for ${it.n}.", false, "People make $food for ${f.n}.", it.pic) }
        }
        s.tf("tf", 3, tfs)
        return s.build()
    }

    private fun natural(): GenSkill? {
        val s = SB("ev3.natural", 3, "Natural or made by us", "Made", "natural things and things people make")
        class N(val th: Th, val subj: String, val nat: Boolean)
        val xs = ArrayList<N>()
        for (o in d.objects.filter { it.natural != null }) xs += N(oth(o), obj(o).subj, o.natural!!)
        val natT = setOf("sun", "moon", "cloud", "river", "wind", "rain", "star", "mountain")
        val madeT = setOf("car", "train", "aeroplane", "robot", "ceiling fan", "clock", "bicycle", "boat")
        for (t in d.nonlivingTricky) {
            val subj = when (t.n) { "sun", "moon", "wind" -> "The ${t.n}"; "rain" -> "Rain"; else -> cap(aOf(t.n)) }
            if (t.n in natT) xs += N(Th(t.n, t.pic), subj, true) else if (t.n in madeT) xs += N(Th(t.n, t.pic), subj, false)
        }
        fun be(x: N) = if (x.subj.endsWith("s") && !x.subj.startsWith("A ") && !x.subj.startsWith("An ") && x.subj != "Glass") "are" else "is"
        fun why(x: N) = if (x.nat) "${x.subj} ${be(x)} found in nature, not made by people." else
            "People make ${x.subj.replaceFirstChar { it.lowercase() }.let { if (it.startsWith("the ")) it else it }} by hand or in factories."
        val nat = xs.filter { it.nat }
        val made = xs.filter { !it.nat }
        s.sort("sort", 1, "Natural", "Made by people", nat.map { SO(cap(it.th.name), true, why(it), it.th.pic) } + made.filterIndexed { i, _ -> i % 2 == 0 }.map { SO(cap(it.th.name), false, why(it), it.th.pic) })
        s.qf("which", 2, nat.map { s.choice("Which of these is natural?", it.th, made.map { m -> m.th }, why(it)) } +
            made.filterIndexed { i, _ -> i % 2 == 1 }.map { s.choice("Which of these is made by people?", it.th, nat.map { m -> m.th }, why(it)) })
        s.qf("odd", 3, s.odd("is not natural", nat.map { it.th }, made.map { it.th }, { o -> why(xs.first { it.th.name == o.name }) }, 3))
        s.tf("tf", 3, xs.flatMap { x -> listOf(TF("${x.subj} ${be(x)} natural.", x.nat, why(x), x.th.pic), TF("${x.subj} ${be(x)} made by people.", !x.nat, why(x), x.th.pic)) })
        return s.build()
    }

    private fun saveWater(): GenSkill? {
        val s = SB("ev3.saveWater", 3, "Save water", "Drop", "saving and wasting water")
        val xs = d.saveWater.filter { it.saves != null }
        fun why(x: EFlag) = if (x.saves == true) "${x.n} uses only the water we need." else "${x.n} lets clean water go to waste."
        s.sort("sort", 1, "Saves water", "Wastes water", xs.map { SO(it.n, it.saves == true, why(it), "drop") })
        s.qf("which", 2, xs.map { x ->
            QF(if (x.saves == true) "Which of these saves water?" else "Which of these wastes water?", x.n, xs.filter { it.saves != x.saves }.map { it.n }, why(x), x.n, "drop")
        })
        s.tf("tf", 3, xs.flatMap { x -> listOf(TF("${x.n} saves water.", x.saves == true, why(x), "drop"), TF("${x.n} wastes water.", x.saves == false, why(x), "drop")) })
        // Where water comes from, as a second track.
        val ws = d.waterSources
        s.qf("salty", 2, ws.filter { it.natural && it.n != "rain" }.map { w ->
            QF("Is the water in ${srcName(w.n)} salty or fresh?", if (w.salty) "Salty" else "Fresh", emptyList(),
                if (w.salty) "Water in ${srcName(w.n)} is salty." else "${cap(srcName(w.n))} has fresh water.", if (w.salty) "Salty" else "Fresh", w.pic,
                fixed = listOf("Salty", "Fresh", "Both"))
        })
        return s.build()
    }

    // ================================================================ Class 4

    private fun capitals(): GenSkill? {
        val s = SB("ev4.capitals", 4, "State capitals", "Map", "states, union territories and their capitals")
        val cs = d.india.filter { it.capital != null && it.n.split(" ").size <= 4 }
        fun kindWord(st: EState) = if (st.kind == "ut") "union territory" else "state"
        fun why(st: EState) = "${st.capital} is the capital of ${st.n}."
        s.qf("cap", 1, cs.map { st -> QF("What is the capital of ${st.n}?", st.capital!!, cs.map { it.capital!! }.filter { it != st.capital }.distinct(), why(st), why(st)) })
        s.qf("state", 2, cs.filter { shortState(it.n) }.map { st ->
            QF("${st.capital} is the capital of which ${kindWord(st)}?", st.n,
                cs.filter { it.kind == st.kind && it.capital != st.capital && shortState(it.n) }.map { it.n }, why(st), why(st))
        })
        s.tf("tf", 3, cs.flatMapIndexed { i, st ->
            listOf(TF(why(st), true, why(st))) +
                stride(cs.filter { it.capital != st.capital }, 4, i).map { o -> TF("${o.capital} is the capital of ${st.n}.", false, why(st)) }
        })
        return s.build()
    }

    private val groups = listOf("mammal", "bird", "reptile", "fish", "insect", "amphibian")
    private fun groupWhy(a: EAnimal) = when (a.group) {
        "mammal" -> "${The(a)} feeds its babies milk, so it is a mammal."
        "bird" -> "${The(a)} has feathers and wings, so it is a bird."
        "reptile" -> "${The(a)} has dry, scaly skin, so it is a reptile."
        "fish" -> "${The(a)} has gills and fins, so it is a fish."
        "insect" -> "${The(a)} has six legs, so it is an insect."
        else -> "${The(a)} is an amphibian: it lives on land and in water."
    }

    private fun groups(): GenSkill? {
        val s = SB("ev4.groups", 4, "Animal groups", "Zoo", "mammals, birds, reptiles, fish, insects, amphibians")
        val ga = sure.filter { it.group in groups && it.n != "fish" }
        s.qf("group", 1, ga.map { a -> QF("Which group does ${the(a)} belong to?", cap(a.group), groups.filter { it != a.group }.map(::cap), groupWhy(a), groupWhy(a), a.pic) })
        s.qf("which", 2, ga.map { a -> s.choice("Which of these is ${aOf(a.group)}?", th(a), ga.filter { it.group != a.group }.map(::th), groupWhy(a)) })
        for ((l, r) in listOf("mammal" to "bird", "reptile" to "amphibian", "insect" to "fish")) {
            s.sort("$l$r", 2, cap(l), cap(r), ga.filter { it.group == l || it.group == r }.map { SO(cap(it.n), it.group == l, groupWhy(it), it.pic) })
        }
        s.qf("odd", 3, groups.flatMap { g ->
            s.odd("is not ${aOf(g)}", ga.filter { it.group == g }.map(::th), ga.filter { it.group != g }.map(::th), { o -> groupWhy(ga.first { it.n == o.name }) }, 3)
        })
        s.tf("tf", 3, ga.flatMapIndexed { i, a ->
            listOf(TF("${The(a)} is ${aOf(a.group)}.", true, groupWhy(a), a.pic)) +
                stride(groups.filter { it != a.group }, 3, i).map { TF("${The(a)} is ${aOf(it)}.", false, groupWhy(a), a.pic) }
        })
        return s.build()
    }

    private val beakOpt = mapOf("hooked" to "Hooked", "flat" to "Flat", "long-thin" to "Long and thin", "long-pointed" to "Long and pointed",
        "short-strong" to "Short and strong", "chisel" to "Like a chisel", "pouch" to "With a pouch")
    private val beakUse = mapOf("hooked" to "tear meat", "flat" to "strain food from water", "long-thin" to "suck nectar from flowers",
        "long-pointed" to "catch fish", "short-strong" to "crack seeds", "chisel" to "make holes in bark", "pouch" to "scoop up fish")
    private val feetOpt = mapOf("webbed" to "Webbed", "talons" to "Sharp talons", "perching" to "Perching", "climbing" to "Climbing",
        "wading" to "Long wading legs", "scratching" to "Scratching")
    private val feetUse = mapOf("webbed" to "swim", "talons" to "grip its prey", "perching" to "hold on to branches", "climbing" to "climb up tree trunks",
        "wading" to "walk in shallow water", "scratching" to "scratch the soil for food")

    private fun beaks(): GenSkill? {
        val s = SB("ev4.beaks", 4, "Beaks and feet", "Beak", "how birds' beaks and feet suit their food")
        val bs = animals.filter { it.beak != null || it.feet != null }
        fun bUse(a: EAnimal) = if (a.n == "parrot") "crack nuts and fruits" else beakUse[a.beak]!!
        fun bWhy(a: EAnimal) = "${The(a)}'s ${beakOpt[a.beak]!!.lowercase()} beak helps it ${bUse(a)}."
        fun fWhy(a: EAnimal) = "${The(a)}'s ${feetOpt[a.feet]!!.lowercase()} ${if (a.feet == "talons" || a.feet == "wading") "help" else "feet help"} it ${feetUse[a.feet]}."
        val withBeak = bs.filter { it.beak != null }
        val withFeet = bs.filter { it.feet != null }
        s.qf("beak", 1, withBeak.map { a -> QF("What kind of beak does ${the(a)} have?", beakOpt[a.beak]!!, beakOpt.filterKeys { it != a.beak }.values.toList(), bWhy(a), bWhy(a), a.pic) })
        s.qf("feet", 1, withFeet.map { a -> QF("What kind of feet does ${the(a)} have?", feetOpt[a.feet]!!, feetOpt.filterKeys { it != a.feet }.values.toList(), fWhy(a), fWhy(a), a.pic) })
        s.qf("bwho", 2, withBeak.map { a -> s.choice("Which bird has a beak to ${bUse(a)}?", th(a), withBeak.filter { it.beak != a.beak }.map(::th), bWhy(a)) })
        s.qf("fwho", 2, withFeet.map { a -> s.choice("Which bird has feet to ${feetUse[a.feet]!!.replace("its", "their")}?", th(a), withFeet.filter { it.feet != a.feet }.map(::th), fWhy(a)) })
        s.qf("why", 3, withFeet.map { a ->
            QF("Why does ${the(a)} have ${feetOpt[a.feet]!!.lowercase()}${if (a.feet == "talons" || a.feet == "wading") "" else " feet"}?",
                "To ${feetUse[a.feet]}", feetUse.filterKeys { it != a.feet }.values.map { "To $it" }.filter { it.length <= 24 }, fWhy(a), fWhy(a), a.pic)
        })
        s.sort("wt", 2, "Webbed", "Talons", withFeet.filter { it.feet == "webbed" || it.feet == "talons" }.map { SO(cap(it.n), it.feet == "webbed", fWhy(it), it.pic) })
        s.tf("tf", 3, withBeak.flatMapIndexed { i, a ->
            listOf(TF("${The(a)} has a ${beakOpt[a.beak]!!.lowercase()} beak.", true, bWhy(a), a.pic)) +
                stride(beakOpt.keys.filter { it != a.beak }, 2, i).map { TF("${The(a)} has a ${beakOpt[it]!!.lowercase()} beak.", false, bWhy(a), a.pic) }
        } + withFeet.flatMapIndexed { i, a ->
            listOf(TF("${The(a)} has ${feetOpt[a.feet]!!.lowercase()} feet.", true, fWhy(a), a.pic)) +
                stride(feetOpt.keys.filter { it != a.feet }, 2, i).map { TF("${The(a)} has ${feetOpt[it]!!.lowercase()} feet.", false, fWhy(a), a.pic) }
        })
        return s.build()
    }

    private val travel = mapOf("wind" to "By wind", "water" to "By water", "animal" to "By animals", "burst" to "By bursting open")

    private fun dispersal(): GenSkill? {
        val s = SB("ev4.dispersal", 4, "How seeds travel", "Seed", "seeds spread by wind, water, animals or bursting")
        val ps = d.plants.filter { it.seeds != null && it.why != null }
        fun why(p: EPlant) = "${cap(p.n)} seeds travel ${travel[p.seeds]!!.lowercase()}: ${p.why}."
        fun pth(p: EPlant) = Th(p.n, p.pic)
        s.qf("how", 1, ps.map { p -> QF("How do ${p.n} seeds travel?", travel[p.seeds]!!, travel.filterKeys { it != p.seeds }.values.toList(), why(p), why(p), p.pic) })
        s.qf("whose", 2, ps.map { p -> s.choice("Whose seeds travel ${travel[p.seeds]!!.lowercase()}?", pth(p), ps.filter { it.seeds != p.seeds }.map(::pth), why(p)) })
        s.qf("why", 3, ps.map { p ->
            QF("Why do ${p.n} seeds travel ${travel[p.seeds]!!.lowercase()}?", cap(p.why!!), ps.filter { it.seeds != p.seeds }.map { cap(it.why!!) }.distinct(), why(p), why(p), p.pic)
        })
        s.sort("ww", 2, "Wind", "Animals", ps.filter { it.seeds == "wind" || it.seeds == "animal" }.map { SO(cap(it.n), it.seeds == "wind", why(it), it.pic) })
        s.tf("tf", 3, ps.flatMap { p -> travel.map { (k, v) -> TF("${cap(p.n)} seeds travel ${v.lowercase()}.", k == p.seeds, why(p), p.pic) } })
        return s.build()
    }

    private val keepWhy = mapOf(
        "dry" to "Germs cannot grow in dry food.", "salt" to "Salt stops germs from growing in food.", "sugar" to "Lots of sugar stops germs from growing.",
        "oil" to "A layer of oil keeps air and germs out.", "cold" to "Germs grow very slowly in the cold.", "boil" to "Boiling kills the germs in food.",
        "airtight" to "Air and germs cannot get into the pack.",
    )

    private fun keepFood(): GenSkill? {
        val s = SB("ev4.keepFood", 4, "Keeping food fresh", "Jar", "how we stop food from spoiling")
        val ways = d.keepWays
        s.qf("how", 1, d.keepFood.flatMap { f ->
            f.ways.map { w -> QF("How do we keep ${f.n} from spoiling?", cap(ways[w]!!), ways.filterKeys { it !in f.ways }.values.map(::cap), keepWhy[w]!!, "By ${ways[w]}") }
        })
        val sp = d.spoils.filter { it.fast != null }
        fun pl(n: String) = n.endsWith("s") && !n.endsWith("ss")
        fun spWhy(x: EFlag) = if (x.fast == true) "${cap(x.n)} ${if (pl(x.n)) "spoil" else "spoils"} fast, so eat ${if (pl(x.n)) "them" else "it"} soon or keep ${if (pl(x.n)) "them" else "it"} cold."
            else "${cap(x.n)} ${if (pl(x.n)) "keep" else "keeps"} for a long time if stored well."
        s.sort("sort", 2, "Spoils fast", "Keeps long", sp.map { SO(cap(it.n), it.fast == true, spWhy(it)) })
        s.qf("which", 2, sp.map { x ->
            QF(if (x.fast == true) "Which of these spoils fast?" else "Which of these keeps for a long time?", cap(x.n), sp.filter { it.fast != x.fast }.map { cap(it.n) }, spWhy(x), cap(x.n))
        })
        s.tf("tf", 3, d.keepFood.flatMapIndexed { i, f ->
            f.ways.map { TF("We keep ${f.n} from spoiling by ${ways[it]}.", true, keepWhy[it]!!) } +
                stride(ways.keys.filter { it !in f.ways }, 3, i).map { TF("We keep ${f.n} from spoiling by ${ways[it]}.", false, "We keep ${f.n} by ${ways[f.ways[0]]}.") }
        } + sp.flatMap { x ->
            listOf(TF("${cap(x.n)} ${if (pl(x.n)) "spoil" else "spoils"} fast.", x.fast == true, spWhy(x)),
                TF("${cap(x.n)} ${if (pl(x.n)) "keep" else "keeps"} for a long time.", x.fast == false, spWhy(x)))
        })
        return s.build()
    }

    private val crafts = setOf("potter", "weaver", "blacksmith", "goldsmith", "carpenter", "tailor", "cobbler", "baker")

    private fun work(): GenSkill? {
        val s = SB("ev4.work", 4, "Work and tools", "Tool", "what people make, and the tools they use")
        val hs = d.helpers
        val mk = hs.filter { it.n in crafts && it.makes != null }
        fun mWhy(h: EHelper) = "${cap(aH(h))} makes ${h.makes}."
        s.qf("who", 1, mk.map { h -> s.choice("Who makes ${h.makes}?", hth(h), mk.filter { it != h }.map(::hth), mWhy(h)) })
        s.qf("what", 1, mk.map { h -> QF("What does ${aH(h)} make?", cap(h.makes!!), mk.filter { it != h }.map { cap(it.makes!!) }, mWhy(h), mWhy(h), h.pic) })
        val tools = hs.flatMap { it.tools }.distinct()
        s.qf("tool", 2, hs.flatMap { h ->
            h.tools.map { t -> QF("Which of these does ${aH(h)} use?", cap(t), tools.filter { it !in h.tools }.map(::cap), "${cap(aH(h))} uses ${toolWord(t)}.", cap(t), d.toolPics[t]) }
        })
        s.qf("user", 2, tools.flatMap { t ->
            hs.filter { t in it.tools }.map { h -> s.choice("${toolSubj(t)} used by …?", hth(h), hs.filter { t !in it.tools }.map(::hth), "${cap(aH(h))} uses ${toolWord(t)}.", visual = d.toolPics[t]) }
        })
        s.tf("tf", 3, mk.flatMapIndexed { i, h ->
            listOf(TF(mWhy(h), true, mWhy(h))) + stride(mk.filter { it != h }, 2, i).map { TF("${cap(aH(h))} makes ${it.makes}.", false, mWhy(h)) }
        } + hs.flatMapIndexed { i, h ->
            stride(tools.filter { it !in h.tools }, 2, i).map { t ->
                val owner = hs.first { t in it.tools }
                TF("${cap(aH(h))} uses ${toolWord(t)}.", false, "${toolSubj(t)} used by ${aH(owner)}.", d.toolPics[t])
            } + h.does.map { TF("${cap(aH(h))} $it.", true, "${cap(aH(h))} $it.") }
        })
        return s.build()
    }

    private fun culture(): GenSkill? {
        val s = SB("ev4.culture", 4, "Languages and dances", "Dance", "languages and dances of our states")
        val st = d.india.filter { shortState(it.n) }
        val langs = st.flatMap { it.languages }.distinct()
        fun lWhy(x: EState) = "Most people in ${x.n} speak ${x.languages[0]}."
        s.qf("lang", 1, st.filter { it.languages.isNotEmpty() }.map { x -> QF("Which language do most people in ${x.n} speak?", x.languages[0], langs.filter { it !in x.languages }, lWhy(x), lWhy(x)) })
        s.qf("where", 3, st.filter { it.languages.isNotEmpty() && it.languages[0] != "Hindi" }.map { x ->
            val l = x.languages[0]
            QF("In which of these do most people speak $l?", x.n, st.filter { l !in it.languages && it.languages.isNotEmpty() && !twin(it.n, x.n) }.map { it.n }, lWhy(x), x.n)
        })
        val dances = st.flatMap { x -> x.dances.map { it to x } }
        fun dWhy(dn: String, x: EState) = if (dn in d.classicalDances) "$dn is a classical dance from ${x.n}." else "$dn is a folk dance from ${x.n}."
        s.qf("dfrom", 1, dances.map { (dn, x) -> QF("Which state is the $dn dance from?", x.n, st.filter { dn !in it.dances && !twin(it.n, x.n) }.map { it.n }, dWhy(dn, x), x.n) })
        s.qf("dance", 2, dances.map { (dn, x) -> QF("Which dance is from ${x.n}?", dn, dances.filter { (o, y) -> o !in x.dances && !twin(y.n, x.n) }.map { it.first }, dWhy(dn, x), dn) })
        s.sort("cf", 2, "Classical", "Folk", dances.map { (dn, x) -> SO(dn, dn in d.classicalDances, dWhy(dn, x)) })
        s.tf("tf", 3, dances.flatMapIndexed { i, (dn, x) ->
            listOf(TF("$dn is a dance from ${x.n}.", true, dWhy(dn, x))) +
                stride(st.filter { dn !in it.dances && !twin(it.n, x.n) }, 3, i).map { TF("$dn is a dance from ${it.n}.", false, dWhy(dn, x)) }
        } + st.filter { it.languages.isNotEmpty() }.flatMapIndexed { i, x ->
            listOf(TF(lWhy(x), true, lWhy(x))) + stride(langs.filter { it !in x.languages }, 2, i).map { TF("Most people in ${x.n} speak $it.", false, lWhy(x)) }
        })
        return s.build()
    }

    private val changeWhy = mapOf(
        "evaporation" to "Heat turns the water into vapour, which goes into the air.",
        "condensation" to "Water vapour cools and turns back into water drops.",
        "freezing" to "Water gets very cold and turns into solid ice.",
        "melting" to "Heat turns the solid into a liquid.",
    )

    private fun waterCycle(): GenSkill? {
        val s = SB("ev4.waterCycle", 4, "The water cycle", "Rain", "evaporation, condensation, freezing, melting")
        val ch = d.waterChanges
        val names = changeWhy.keys.toList()
        s.qf("what", 1, ch.map { c -> QF("${c.n} What is this change called?", cap(c.change), names.filter { it != c.change }.map(::cap), changeWhy[c.change]!!, cap(c.change)) })
        s.qf("def", 1, listOf(
            QF("Water turning into vapour is called …?", "Evaporation", emptyList(), changeWhy["evaporation"]!!, "Evaporation", fixed = names.map(::cap)),
            QF("Vapour turning into water drops is called …?", "Condensation", emptyList(), changeWhy["condensation"]!!, "Condensation", fixed = names.map(::cap)),
            QF("Water turning into ice is called …?", "Freezing", emptyList(), changeWhy["freezing"]!!, "Freezing", fixed = names.map(::cap)),
            QF("Ice turning into water is called …?", "Melting", emptyList(), changeWhy["melting"]!!, "Melting", fixed = names.map(::cap)),
        ))
        s.sort("ec", 2, "Evaporation", "Condensation", ch.filter { it.change == "evaporation" || it.change == "condensation" }.map { SO(it.n, it.change == "evaporation", changeWhy[it.change]!!) })
        val cyc = d.waterCycle
        s.order("cycle", 2, subsets(cyc).map { st -> OR("Put the water cycle in order.", st, "First ${st.first()}, and last ${st.last()}.", "rain") } + listOf(
            OR("Put these in order as ice is heated.", listOf("ice", "water", "steam"), "Ice melts into water, and water boils into steam."),
            OR("Put these in order as steam cools.", listOf("steam", "water", "ice"), "Steam cools into water, and water freezes into ice."),
        ))
        s.qf("next", 2, (0 until cyc.size - 1).map { i ->
            QF("In the water cycle, what comes after this: ${cyc[i]}?", cap(cyc[i + 1]), cyc.filterIndexed { k, _ -> k != i && k != i + 1 }.map(::cap),
                "After ${cyc[i]}, ${cyc[i + 1]}.", cap(cyc[i + 1]), "rain")
        })
        val states = listOf("ice" to "solid", "water" to "liquid", "steam" to "gas")
        s.tf("tf", 3, ch.flatMap { c -> names.map { n -> TF("${c.n.removeSuffix(".")} because of $n.", n == c.change, changeWhy[c.change]!!) } } +
            states.flatMap { (x, st) -> states.map { (_, o) -> TF("${cap(x)} is ${aOf(o)}.", o == st, "${cap(x)} is water as ${aOf(st)}.") } } +
            cyc.indices.flatMap { i -> cyc.indices.filter { it != i }.map { j ->
                TF("In the water cycle, ${cyc[i]} before ${cyc[j]}.".replace("water cycle, the sun", "water cycle, the sun"), i < j,
                    "First ${cyc[minOf(i, j)]}, then ${cyc[maxOf(i, j)]}.")
            } })
        return s.build()
    }

    private val habWord = mapOf("forest" to "forests", "grassland" to "grasslands", "desert" to "the desert", "snow" to "snowy places",
        "sea" to "the sea", "fresh" to "ponds and rivers", "mountain" to "the mountains")
    /** Habitats so far from [h] that an animal living only in them surely does not live in [h]. */
    private val far = mapOf(
        "forest" to setOf("sea", "desert", "snow"), "grassland" to setOf("sea", "snow", "fresh"), "desert" to setOf("sea", "fresh", "snow"),
        "snow" to setOf("desert", "forest", "grassland", "farm", "house", "fresh"), "sea" to setOf("desert", "grassland", "forest", "farm", "house", "mountain"),
        "fresh" to setOf("desert", "snow", "grassland", "house"), "mountain" to setOf("sea", "fresh", "desert"),
    )

    private fun habitat(): GenSkill? {
        val s = SB("ev4.habitat", 4, "Where animals live", "Wild", "forests, deserts, seas, snow and rivers")
        val ha = animals.filter { it.hab.isNotEmpty() }
        fun lives(a: EAnimal, h: String) = h in a.hab && !(a.group == "bird" && h in waterHabs)
        fun farFrom(a: EAnimal, h: String) = a.hab.all { it in far[h]!! }
        fun why(a: EAnimal): String {
            val w = a.hab.filter { it in habWord && !(a.group == "bird" && it in waterHabs) }.map { habWord[it]!! }
            return when {
                w.isEmpty() && a.group == "bird" -> "${The(a)} lives near water and feeds there."
                w.isEmpty() && "farm" in a.hab -> "${The(a)} lives on farms, with people."
                w.isEmpty() -> "${The(a)} lives with people, in their homes."
                w.size == 1 -> "${The(a)} lives in ${w[0]}."
                else -> "${The(a)} lives in ${w.dropLast(1).joinToString(", ")} and ${w.last()}."
            }
        }
        s.qf("where", 1, ha.filter { a -> a.hab.count { it in habWord } == 1 && a.hab.size <= 2 }.map { a ->
            val h = a.hab.first { it in habWord }
            QF("Where does ${the(a)} live?", cap(habWord[h]!!), far[h]!!.filter { it in habWord && it !in a.hab }.map { cap(habWord[it]!!) }, why(a), why(a), a.pic)
        })
        s.qf("who", 2, habWord.keys.flatMap { h ->
            ha.filter { lives(it, h) }.map { a -> s.choice("Which animal lives in ${habWord[h]}?", th(a), ha.filter { farFrom(it, h) }.map(::th), "${The(a)} lives in ${habWord[h]}.") }
        })
        s.qf("odd", 3, habWord.keys.flatMap { h ->
            s.odd("does not live in ${habWord[h]}", ha.filter { lives(it, h) }.map(::th), ha.filter { farFrom(it, h) }.map(::th), { o -> why(ha.first { it.n == o.name }) }, 3)
        })
        s.tf("tf", 3, ha.flatMap { a ->
            habWord.keys.mapNotNull { h ->
                when {
                    a.group == "bird" && h in waterHabs -> null
                    lives(a, h) -> TF("${The(a)} lives in ${habWord[h]}.", true, why(a), a.pic)
                    farFrom(a, h) -> TF("${The(a)} lives in ${habWord[h]}.", false, why(a), a.pic)
                    else -> null
                }
            }
        })
        return s.build()
    }

    private fun thenNow(): GenSkill? {
        val s = SB("ev4.thenNow", 4, "Then and now", "Old", "how things we use have changed")
        val tn = d.thenNow
        fun why(x: EThenNow) = "The ${x.old} came first; now we use the ${x.new}."
        s.qf("before", 1, tn.map { x -> QF("What came before the ${x.new}?", cap(x.old), tn.filter { it.use != x.use }.map { cap(it.old) }, why(x), cap(x.old)) })
        s.qf("now", 2, tn.map { x -> QF("What do we use now in place of the ${x.old}?", cap(x.new), tn.filter { it.use != x.use }.map { cap(it.new) }, why(x), cap(x.new)) })
        s.qf("use", 2, tn.map { x -> QF("What was the ${x.old} used for?", cap(x.use), tn.map { it.use }.distinct().filter { it != x.use }.map(::cap), "People used the ${x.old} for ${x.use}.", cap(x.use)) })
        s.sort("sort", 2, "Older way", "Newer way", tn.flatMapIndexed { i, x -> if (i % 2 == 0) listOf(SO(cap(x.old), true, why(x))) else listOf(SO(cap(x.new), false, why(x))) })
        s.tf("tf", 3, tn.flatMap { x ->
            listOf(TF("People used the ${x.old} before the ${x.new}.", true, why(x)), TF("People used the ${x.new} before the ${x.old}.", false, why(x)))
        })
        return s.build()
    }

    // ================================================================ Class 5

    private fun foodChain(): GenSkill? {
        val s = SB("ev5.foodChain", 5, "Food chains", "Chain", "who eats whom, in order")
        val eats = d.eats.associate { it.n to it.food }
        val prod = d.producers.toSet()
        val byName = animals.associateBy { it.n }
        fun a(n: String) = byName[n]?.let { the(it) } ?: (if (n in prod) n else aOf(n))
        fun pl(n: String) = if (n in prod) n else byName[n]?.pl ?: if (n.endsWith("fish")) n else "${n}s"
        fun edge(x: String, y: String) = "${cap(a(y))} eats ${pl(x)}."
        val chains = ArrayList<List<String>>()
        fun walk(path: List<String>) {
            if (path.size >= 3) chains += path
            if (path.size == 5) return
            for ((e, f) in eats) if (path.last() in f && e !in path) walk(path + e)
        }
        prod.forEach { walk(listOf(it)) }
        val pureHerb = eats.filter { (_, f) -> f.all { it in prod } }.keys
        val pureCarn = eats.filter { (_, f) -> f.none { it in prod } }.keys
        val herbW = d.herbivores
        val carnW = d.carnivores
        fun gap(c: List<String>, i: Int): QF {
            val shown = c.mapIndexed { k, x -> if (k == i) "?" else x }.joinToString(" → ")
            val wrong = when {
                i == 0 -> herbW + carnW
                c[i - 1] in prod -> carnW
                else -> herbW
            }.filter { it !in c }
            val why = if (i == 0) edge(c[0], c[1]) else edge(c[i - 1], c[i])
            return QF("Fill the gap: $shown", c[i], wrong, why, c.joinToString(" → "))
        }
        for (len in 3..5) {
            val cs = chains.filter { it.size == len }
            s.qf("gap$len", len - 2, cs.flatMap { c -> c.indices.map { gap(c, it) } })
        }
        s.order("order", 2, chains.filter { it.size <= 4 }.map { OR("Put this food chain in order, plant first.", it, "Each one eats the one before it, starting with ${it[0]}.") })
        s.order("order5", 3, chains.filter { it.size == 5 }.map { OR("Put this food chain in order, plant first.", it, "Each one eats the one before it, starting with ${it[0]}.") })
        s.qf("eat", 1, eats.flatMap { (e, f) ->
            when (e) {
                in pureHerb -> f.map { x -> QF("What does ${a(e)} eat?", cap(x), carnW.filter { it != e }.map(::cap), edge(x, e), edge(x, e), byName[e]?.pic) }
                in pureCarn -> f.map { x -> QF("What does ${a(e)} eat?", cap(x), d.producers.map(::cap), edge(x, e), edge(x, e), byName[e]?.pic) }
                else -> emptyList()
            }
        })
        s.qf("who", 2, eats.values.flatten().distinct().flatMap { x ->
            eats.filter { x in it.value }.keys.map { e ->
                s.choice("Which of these eats ${pl(x)}?", Th(e, byName[e]?.pic), (if (x in prod) carnW else herbW).filter { it != e && x !in (eats[it] ?: emptyList()) }.map { Th(it, byName[it]?.pic) }, edge(x, e))
            }
        })
        s.tf("tf", 3, eats.flatMap { (e, f) -> f.map { TF(edge(it, e), true, edge(it, e), byName[e]?.pic) } } +
            pureHerb.flatMapIndexed { i, e -> stride(carnW + herbW.filter { it != e }, 2, i).map { TF("${cap(a(e))} eats ${pl(it)}.", false, "${cap(a(e))} eats only plants.", byName[e]?.pic) } } +
            pureCarn.flatMapIndexed { i, e -> stride(d.producers, 2, i).map { TF("${cap(a(e))} eats $it.", false, "${cap(a(e))} eats other animals, not plants.", byName[e]?.pic) } })
        return s.build()
    }

    private val nutWord = mapOf("c" to "carbohydrates", "p" to "proteins", "f" to "fats", "v" to "vitamins and minerals")
    private val nutWhy = mapOf("c" to "gives us energy from carbohydrates", "p" to "helps our body grow with proteins",
        "f" to "is rich in fats that give energy", "v" to "has vitamins and minerals that keep us well")

    private fun nutrients(): GenSkill? {
        val s = SB("ev5.nutrients", 5, "Food and nutrients", "Fit", "carbohydrates, proteins, fats, vitamins and minerals")
        val fs = d.foods.filter { it.rich.isNotEmpty() }
        fun why(f: EFood, n: String): String {
            val x = food(f)
            val w = nutWhy[n]!!
            val verb = if (!x.plural) w else w.replaceFirst("gives", "give").replaceFirst("helps", "help").replaceFirst("is ", "are ").replaceFirst("has ", "have ")
            return "${x.subj} $verb."
        }
        s.qf("what", 1, fs.filter { it.rich.size == 1 && it.poor.size >= 2 }.map { f ->
            QF("What ${if (food(f).plural) "are" else "is"} ${food(f).obj} rich in?", cap(nutWord[f.rich[0]]!!), f.poor.map { cap(nutWord[it]!!) }, why(f, f.rich[0]), why(f, f.rich[0]), f.pic)
        })
        s.qf("which", 2, nutWord.keys.flatMap { n ->
            fs.filter { n in it.rich }.map { f -> s.choice("Which of these is rich in ${nutWord[n]}?", fth(f), d.foods.filter { n in it.poor }.map(::fth), why(f, n)) }
        })
        s.sort("pc", 2, "Proteins", "Carbohydrates", fs.filter { it.rich == listOf("p") || it.rich == listOf("c") }.map { SO(cap(it.n), it.rich[0] == "p", why(it, it.rich[0]), it.pic) })
        s.qf("odd", 3, nutWord.keys.flatMap { n ->
            s.odd("is not rich in ${nutWord[n]}", fs.filter { n in it.rich }.map(::fth), d.foods.filter { n in it.poor }.map(::fth), { o ->
                val f = d.foods.first { it.n == o.name }
                if (f.rich.isNotEmpty()) why(f, f.rich[0]) else "${food(f).subj} ${food(f).be} not rich in ${nutWord[n]}."
            }, 3)
        })
        s.tf("tf", 3, d.foods.flatMap { f ->
            val x = food(f)
            f.rich.map { TF("${x.subj} ${x.be} rich in ${nutWord[it]}.", true, why(f, it), f.pic) } +
                f.poor.map { TF("${x.subj} ${x.be} rich in ${nutWord[it]}.", false, if (f.rich.isNotEmpty()) why(f, f.rich[0]) else "${x.subj} ${x.be} not rich in ${nutWord[it]}.", f.pic) }
        })
        return s.build()
    }

    private fun floatSink(): GenSkill? {
        val s = SB("ev5.floatSink", 5, "Float or sink", "Boat", "things that float and things that sink")
        val os = d.objects.filter { it.floats != null }
        fun why(o: EObject): String {
            val n = obj(o)
            return if (o.floats == true) "${n.subj} ${n.be} light for ${n.its} size, so ${if (n.plural) "they float" else "it floats"}."
            else "${n.subj} ${n.be} heavy for ${n.its} size, so ${if (n.plural) "they sink" else "it sinks"}."
        }
        val fl = os.filter { it.floats == true }
        val sk = os.filter { it.floats == false }
        s.sort("sort", 1, "Floats", "Sinks", os.map { SO(cap(it.n), it.floats == true, why(it), objPicOf(it)) })
        s.qf("which", 2, fl.map { s.choice("Which of these floats on water?", oth(it), sk.map(::oth), why(it)) } +
            sk.map { s.choice("Which of these sinks in water?", oth(it), fl.map(::oth), why(it)) })
        s.qf("odd", 3, s.odd("does not float", fl.map(::oth), sk.map(::oth), { o -> why(os.first { it.n == o.name }) }, 6) +
            s.odd("does not sink", sk.map(::oth), fl.map(::oth), { o -> why(os.first { it.n == o.name }) }, 6))
        s.tf("tf", 3, os.flatMap { o ->
            val n = obj(o)
            listOf(TF("${n.subj} ${n.v("floats", "float")} on water.", o.floats == true, why(o), objPicOf(o)),
                TF("${n.subj} ${n.v("sinks", "sink")} in water.", o.floats == false, why(o), objPicOf(o)))
        })
        return s.build()
    }

    private fun planets(): GenSkill? {
        val s = SB("ev5.planets", 5, "Our solar system", "Sun", "the planets and their order from the Sun")
        val ps = d.planets
        val names = ps.map { it.n }
        val ord = listOf("first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth")
        fun near(i: Int) = names.indices.filter { it != i }.sortedBy { kotlin.math.abs(it - i) }.map { names[it] }
        fun posWhy(i: Int) = "${names[i]} is planet number ${i + 1} from the Sun."
        s.qf("fact", 1, ps.flatMap { p -> p.facts.map { f -> QF("Which planet $f?", p.n, names.filter { it != p.n }, "${p.n} $f.", p.n, p.pic) } })
        s.qf("pos", 1, ps.indices.map { i -> QF("Which is the ${ord[i]} planet from the Sun?", names[i], near(i).take(4), posWhy(i), names[i]) })
        s.qf("next", 2, (0 until 7).map { i -> QF("Which planet comes just after ${names[i]}?", names[i + 1], near(i + 1).filter { it != names[i] }.take(4), posWhy(i + 1), names[i + 1]) } +
            (1 until 8).map { i -> QF("Which planet comes just before ${names[i]}?", names[i - 1], near(i - 1).filter { it != names[i] }.take(4), posWhy(i - 1), names[i - 1]) })
        s.order("order3", 2, subsets(names).filter { it.size == 3 }.map { OR("Put the planets in order from the Sun.", it, "${it[0]} is closest to the Sun of these.") })
        s.order("order45", 3, subsets(names).filter { it.size >= 4 }.map { OR("Put the planets in order from the Sun.", it, "${it[0]} is closest and ${it.last()} farthest from the Sun.") })
        s.tf("tf", 3, names.indices.flatMap { i -> names.indices.filter { it != i }.map { j ->
            TF("${names[i]} is closer to the Sun than ${names[j]}.", i < j, "${names[i]} is planet ${i + 1} and ${names[j]} is planet ${j + 1}.")
        } } + ps.flatMap { p -> p.facts.flatMap { f -> ps.map { o -> TF("${o.n} $f.", o == p, "${p.n} $f.", o.pic) } } })
        return s.build()
    }

    private fun lifeCycle(): GenSkill? {
        val s = SB("ev5.lifeCycle", 5, "Life cycles", "Grow", "how living things grow and change")
        fun theStep(x: String) = if (" " in x) x else "the $x"
        val poss = mapOf("person" to "a person's", "mango tree" to "a mango tree's", "bean seed" to "a bean seed's")
        fun whose(c: ECycle) = poss[c.n] ?: "${aOf(c.n)}'s"
        s.order("order", 2, d.lifeCycles.flatMap { c ->
            subsets(c.steps).map { st -> OR("Put ${whose(c)} life in order.", st, "In ${whose(c)} life, ${st.first()} comes first.", d.stepPics[c.steps.last()] ?: d.stepPics[c.n]) }
        })
        val next = ArrayList<QF>()
        val tfs = ArrayList<TF>()
        for (c in d.lifeCycles) {
            val st = c.steps
            for (i in 0 until st.size - 1) {
                val why = "First ${st[i]}, then ${st[i + 1]}."
                next += QF("In ${whose(c)} life, what comes after ${theStep(st[i])}?", cap(st[i + 1]), st.filterIndexed { k, _ -> k != i + 1 && k != i }.map(::cap) +
                    d.lifeCycles.filter { it != c }.flatMap { it.steps }.filter { it !in st }.take(3).map(::cap), why, cap(st[i + 1]), d.stepPics[st[i]])
                next += QF("In ${whose(c)} life, what comes before ${theStep(st[i + 1])}?", cap(st[i]), st.filterIndexed { k, _ -> k != i + 1 && k != i }.map(::cap) +
                    d.lifeCycles.filter { it != c }.flatMap { it.steps }.filter { it !in st }.take(3).map(::cap), why, cap(st[i]), d.stepPics[st[i + 1]])
            }
            for (i in st.indices) for (j in st.indices) if (i != j) {
                tfs += TF("In ${whose(c)} life, ${st[i]} comes before ${st[j]}.", i < j, "First ${st[minOf(i, j)]}, then ${st[maxOf(i, j)]}.")
            }
        }
        s.qf("next", 1, next)
        s.tf("tf", 3, tfs)
        return s.build()
    }

    private fun base(job: String, form: String): String {
        if (form == "pl") return job
        val w = job.substringBefore(" ")
        val rest = job.substringAfter(" ", "")
        val b = when {
            w.endsWith("ies") -> w.removeSuffix("ies") + "y"
            w.endsWith("ses") || w.endsWith("shes") -> w.removeSuffix("es")
            w.endsWith("s") -> w.removeSuffix("s")
            else -> w
        }
        return if (rest.isEmpty()) b else "$b $rest"
    }
    private fun third(job: String, form: String) = if (form != "pl") job else {
        val w = job.substringBefore(" ")
        val rest = job.substringAfter(" ", "")
        (if (w.endsWith("y")) w.dropLast(1) + "ies" else "${w}s") + if (rest.isEmpty()) "" else " $rest"
    }

    private fun organs(): GenSkill? {
        val s = SB("ev5.organs", 5, "Inside our body", "Heart", "organs, bones and what they do")
        val os = d.organs
        fun ot(o: EOrgan) = Th(o.n, o.pic)
        fun sub(o: EOrgan) = if (o.form == "m") cap(o.n) else "The ${o.n}"
        fun why(o: EOrgan, j: String) = "${sub(o)} $j."
        val jobs = os.flatMap { o -> o.jobs.map { base(it, o.form) } }.distinct()
        s.qf("which", 1, os.flatMap { o ->
            o.jobs.map { j -> s.choice("Which part of the body ${third(j, o.form)}?", ot(o), os.filter { x -> x.jobs.none { base(it, x.form) == base(j, o.form) } }.map(::ot), why(o, j)) }
        })
        s.qf("job", 2, os.flatMap { o ->
            o.jobs.map { j -> QF("What is the job of ${if (o.form == "m") "the ${o.n}" else "the ${o.n}"}?", "To ${base(j, o.form)}", jobs.filter { it !in o.jobs.map { x -> base(x, o.form) } }.map { "To $it" }.filter { it.length <= 24 }, why(o, j), why(o, j), o.pic) }
        })
        s.qf("count", 2, os.filter { it.count != null }.map { o ->
            val c = o.count!!
            val why = if (c == 1) "We have only one ${o.n}." else "We have ${NUM[c]} ${o.n}."
            QF("How many ${if (o.form == "pl") o.n else o.n + "s"} do we have?", "$c", listOf(1, 2, 3, 4).filter { it != c }.map { "$it" }, why, why, o.pic)
        })
        val dg = d.digestion
        s.order("dig", 2, subsets(dg).map { OR("Put the path of food in order.", it, "Food goes from the ${it.first()} to the ${it.last()}.", "stomach") } +
            listOf(OR("Put the path of air in order.", d.breathing, "Air goes in through the nose to the lungs.", "lungs")))
        s.qf("next", 2, (0 until dg.size - 1).map { i ->
            QF("Where does food go after the ${dg[i]}?", cap(dg[i + 1]), dg.filterIndexed { k, _ -> k != i && k != i + 1 }.map(::cap), "Food goes from the ${dg[i]} to the ${dg[i + 1]}.", cap(dg[i + 1]), "stomach")
        })
        s.tf("tf", 3, os.flatMapIndexed { i, o ->
            o.jobs.map { TF(why(o, it), true, why(o, it), o.pic) } +
                stride(jobs.filter { j -> j !in o.jobs.map { base(it, o.form) } }, 5, i).map { j ->
                    TF("${sub(o)} ${if (o.form == "pl") j else third(j, "pl")}.", false, why(o, o.jobs[0]), o.pic)
                }
        } + dg.indices.flatMap { i -> dg.indices.filter { it != i }.map { j ->
            TF("Food reaches the ${dg[i]} before the ${dg[j]}.", i < j, "Food goes from the ${dg[minOf(i, j)]} to the ${dg[maxOf(i, j)]}.")
        } })
        return s.build()
    }

    private fun energy(): GenSkill? {
        val s = SB("ev5.energy", 5, "Energy and fuels", "Power", "renewable energy and saving fuel")
        val es = d.energy.filter { it.renewable != null }
        fun why(x: EFlag) = if (x.renewable == true) "${cap(x.n)} will not run out, so it is renewable." else "${x.n.let { if (it == "LPG" || it == "CNG") it else cap(it) }} will run out one day, so it is non-renewable."
        val ren = es.filter { it.renewable == true }
        val non = es.filter { it.renewable == false }
        s.sort("sort", 1, "Renewable", "Non-renewable", es.map { SO(cap(it.n), it.renewable == true, why(it)) })
        s.qf("which", 2, ren.map { x -> QF("Which of these will not run out?", cap(x.n), non.map { cap(it.n) }, why(x), cap(x.n)) } +
            non.map { x -> QF("Which of these will run out one day?", cap(x.n), ren.map { cap(it.n) }, why(x), cap(x.n)) })
        s.qf("odd", 3, s.odd("is not renewable", ren.map { Th(it.n) }, non.map { Th(it.n) }, { o -> why(es.first { it.n == o.name }) }, 4))
        fun nm(x: String) = if (x == "LPG" || x == "CNG") x else x
        s.qf("uses", 2, d.energyUses.map { u ->
            QF("What does ${aOf(u.n)} run on?", cap(nm(u.uses)), es.map { it.n }.filter { it != u.uses }.map(::cap), "${cap(aOf(u.n))} runs on ${nm(u.uses)}.", cap(u.uses), u.pic)
        })
        s.tf("tfuses", 3, d.energyUses.flatMapIndexed { i, u ->
            listOf(TF("${cap(aOf(u.n))} runs on ${nm(u.uses)}.", true, "${cap(aOf(u.n))} runs on ${nm(u.uses)}.", u.pic)) +
                stride(es.map { it.n }.filter { it != u.uses }, 3, i).map { TF("${cap(aOf(u.n))} runs on $it.", false, "${cap(aOf(u.n))} runs on ${nm(u.uses)}.", u.pic) }
        })
        val sv = d.saveEnergy.filter { it.saves != null }
        fun sWhy(x: EFlag) = if (x.saves == true) "${x.n} saves electricity or fuel." else "${x.n} wastes electricity or fuel."
        s.sort("save", 2, "Saves energy", "Wastes energy", sv.map { SO(it.n, it.saves == true, sWhy(it)) })
        s.qf("save", 2, sv.map { x -> QF(if (x.saves == true) "Which of these saves energy?" else "Which of these wastes energy?", x.n, sv.filter { it.saves != x.saves }.map { it.n }, sWhy(x), x.n) })
        s.tf("tf", 3, es.flatMap { x ->
            val n = if (x.n == "LPG" || x.n == "CNG") x.n else cap(x.n)
            listOf(TF("$n is renewable.", x.renewable == true, why(x)), TF("$n will run out one day.", x.renewable == false, why(x)))
        } + sv.flatMap { x -> listOf(TF("${x.n} saves energy.", x.saves == true, sWhy(x)), TF("${x.n} wastes energy.", x.saves == false, sWhy(x))) })
        return s.build()
    }

    private fun health(): GenSkill? {
        val s = SB("ev5.health", 5, "Germs and health", "Germ", "how diseases spread and how to stop germs")
        val ds = d.diseases
        val sp = d.spread
        fun why(x: EDisease) = when (x.by) {
            "mosquito" -> "Mosquitoes carry ${x.n} germs from person to person."
            "water" -> "${cap(x.n)} germs spread through dirty water and food."
            else -> "${cap(x.n)} germs spread through the air when people cough."
        }
        s.qf("how", 1, ds.map { x -> QF("How does ${x.n} spread?", cap(sp[x.by]!!), emptyList(), why(x), why(x), if (x.by == "mosquito") "mosquito" else null, fixed = sp.values.map(::cap)) })
        s.qf("which", 2, ds.map { x -> QF("Which disease spreads through ${sp[x.by]}?", cap(x.n), ds.filter { it.by != x.by }.map { cap(it.n) }, why(x), cap(x.n)) })
        val gs = d.germs.filter { it.stops != null }
        fun gWhy(x: EFlag) = if (x.stops == true) "${x.n} stops germs from spreading." else "${x.n} helps germs to spread."
        s.sort("sort", 2, "Stops germs", "Spreads germs", gs.map { SO(it.n, it.stops == true, gWhy(it)) })
        s.qf("germ", 2, gs.map { x -> QF(if (x.stops == true) "Which of these stops germs?" else "Which of these spreads germs?", x.n, gs.filter { it.stops != x.stops }.map { it.n }, gWhy(x), x.n) })
        s.tf("tf", 3, ds.flatMap { x -> sp.map { (k, v) -> TF("${cap(x.n)} spreads through $v.", k == x.by, why(x)) } } +
            gs.flatMap { x -> listOf(TF("${x.n} stops germs.", x.stops == true, gWhy(x)), TF("${x.n} spreads germs.", x.stops == false, gWhy(x))) })
        return s.build()
    }

    private fun magnets(): GenSkill? {
        val s = SB("ev5.magnets", 5, "Magnets", "Pull", "what a magnet pulls, and its poles")
        val os = d.objects.filter { it.magnetic != null && it.waste != "wet" }
        fun why(o: EObject): String {
            val n = obj(o)
            return if (o.magnetic == true) "${n.subj} ${n.has} iron in ${if (n.plural) "them" else "it"}, so a magnet pulls ${if (n.plural) "them" else "it"}."
            else "A magnet pulls only things with iron, nickel or cobalt."
        }
        val yes = os.filter { it.magnetic == true }
        val no = os.filter { it.magnetic == false }
        s.sort("sort", 1, "Pulled", "Not pulled", yes.map { SO(cap(it.n), true, why(it), objPicOf(it)) } + no.filterIndexed { i, _ -> i % 3 == 0 }.map { SO(cap(it.n), false, why(it), objPicOf(it)) })
        s.qf("which", 2, yes.map { s.choice("Which of these does a magnet pull?", oth(it), no.map(::oth), why(it), visual = "magnet") } +
            no.filterIndexed { i, _ -> i % 3 != 0 }.map { s.choice("Which of these does a magnet not pull?", oth(it), yes.map(::oth), why(it), visual = "magnet") })
        s.qf("odd", 3, s.odd("is not pulled by a magnet", yes.map(::oth), no.map(::oth), { o -> why(os.first { it.n == o.name }) }, 4))
        val poles = listOf("north" to "north", "north" to "south", "south" to "south")
        s.qf("poles", 2, poles.map { (a, b) ->
            val pull = a != b
            QF("What happens when the $a pole of one magnet meets the $b pole of another?", if (pull) "They pull together" else "They push apart", emptyList(),
                if (pull) "Unlike poles of magnets pull each other." else "Like poles of magnets push each other away.", if (pull) "They pull together" else "They push apart",
                "magnet", fixed = listOf("They pull together", "They push apart", "Nothing happens"))
        })
        s.tf("tf", 3, os.flatMap { o ->
            val n = obj(o)
            listOf(TF("A magnet pulls ${n.obj}.", o.magnetic == true, why(o), objPicOf(o)))
        } + poles.flatMap { (a, b) ->
            val pull = a != b
            listOf(TF("A $a pole and a $b pole pull each other.", pull, if (pull) "Unlike poles of magnets pull each other." else "Like poles of magnets push each other away.", "magnet"))
        } + listOf(
            TF("A freely hanging magnet points north and south.", true, "A magnet always comes to rest pointing north and south.", "compass"),
            TF("A compass needle is a small magnet.", true, "A compass needle is a magnet that points north.", "compass"),
        ))
        return s.build()
    }
}
