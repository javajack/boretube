package com.rakesh.boretube.learn.core.gen

import com.rakesh.boretube.learn.core.Format
import com.rakesh.boretube.learn.core.GenSkill
import com.rakesh.boretube.learn.core.Opt
import com.rakesh.boretube.learn.core.Question
import com.rakesh.boretube.learn.core.Template
import com.rakesh.boretube.learn.core.Visual
import com.rakesh.boretube.learn.core.gq
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlin.random.Random

/** One headword of content/data/lexicon.json (see its "_doc"). */
@Serializable
private data class EnWord(
    val w: String,
    val lvl: Int = 3,
    val pos: List<String> = emptyList(),
    val cat: String? = null,
    val plural: String? = null,
    val past: String? = null,
    val pp: String? = null,
    val s3: String? = null,
    val ing: String? = null,
    val irr: Boolean = false,
    val edRule: String? = null,
    val comp: String? = null,
    val sup: String? = null,
    val compRule: String? = null,
    val count: Boolean? = null,
    val an: Boolean? = null,
    val opp: String? = null,
    val syn: List<String> = emptyList(),
    val rhyme: String? = null,
    val syl: Int? = null,
    val sylBreak: String? = null,
    val pic: String? = null,
    val miss: List<String> = emptyList(),
    val gaps: Map<String, List<String>> = emptyMap(),
    val contested: Boolean = false,
)

@Serializable
private data class EnLexFile(val words: List<EnWord>)

/**
 * Generated English skills (spec P2b), KG to Class 7, built from
 * content/data/lexicon.json and content/data/english.json (curated tables,
 * made by boretube-learn/tools/content/data/english_data.py). Picture ids
 * come from content/data/pictures.json. [data] reads a file by name.
 */
object EnglishGen {
    fun skills(data: (String) -> String?): List<GenSkill> {
        val lexText = data("lexicon.json") ?: return emptyList()
        val enText = data("english.json") ?: return emptyList()
        val json = Json { ignoreUnknownKeys = true }
        val words = json.decodeFromString(EnLexFile.serializer(), lexText).words
        val tables = json.parseToJsonElement(enText).jsonObject
        val pics = data("pictures.json")?.let { p ->
            json.parseToJsonElement(p).jsonObject.filterKeys { it != "_doc" }.values
                .flatMap { v -> (v as? JsonArray)?.map { it.jsonPrimitive.content } ?: emptyList() }.toSet()
        } ?: emptySet()
        val e = En(words, tables, pics)
        return e.kg() + e.c1() + e.c2() + e.c3() + e.c4() + e.c5() + e.c6() + e.c7()
    }
}

private val PIC_SKIP = setOf("bat", "palm", "saw", "pine", "drop", "star", "glass", "pan", "pen", "fan", "fire", "fly")
private const val VOWELS = "aeiou"

/** All the tables, and the skills by class. */
private class En(words: List<EnWord>, private val t: JsonObject, private val pics: Set<String>) {
    // ---------------------------------------------------------------- helpers

    private val JsonElement.s: String get() = jsonPrimitive.content
    private val JsonElement.i: Int get() = jsonPrimitive.int
    private val JsonElement.ss: List<String> get() = jsonArray.map { it.s }

    private fun cap(x: String) = x.replaceFirstChar { it.uppercaseChar() }

    /** The explanation's one sentence: always a full stop at the end. */
    private fun dot(x: String) = if (x.endsWith(".")) x else "$x."

    private fun factOf(explain: String) = explain.removeSuffix(".")

    /** Quick-fire: [ans] and up to n-1 of [wrongs] (shuffled unless [keep]). */
    private fun ask(
        prompt: String, ans: String, wrongs: List<String>, explain: String, r: Random,
        n: Int = 4, vis: Visual? = null, keep: Boolean = false,
    ): Question? {
        if (prompt.isBlank() || ans.isBlank() || ans.length > 24) return null
        val pool = (if (keep) wrongs else wrongs.shuffled(r)).filter { it.isNotBlank() && it.length <= 24 && !it.equals(ans, ignoreCase = true) }.distinct()
        if (pool.isEmpty()) return null
        val o = Opt.of(ans, pool, r, n) ?: return null
        val ex = dot(explain)
        return gq(prompt, o, ex, fact = factOf(ex), visual = vis)
    }

    private fun tf(statement: String, isTrue: Boolean, explain: String, vis: Visual? = null): Question {
        val ex = dot(explain)
        return gq(statement, Opt.trueFalse(isTrue), ex, fact = factOf(ex), visual = vis)
    }

    private fun sortQ(prompt: String, left: String, right: String, isLeft: Boolean, explain: String, vis: Visual? = null): Question {
        val ex = dot(explain)
        return gq(prompt, Opt.baskets(left, right, isLeft), ex, fact = factOf(ex), visual = vis)
    }

    private fun orderQ(prompt: String, items: List<String>, explain: String, r: Random): Question? {
        if (items.size !in 3..5 || items.toSet().size != items.size || items.any { it.length > 28 }) return null
        var sh = items.shuffled(r)
        if (sh == items) sh = items.drop(1) + items.first()
        val ex = dot(explain)
        return gq(prompt, sh to sh.indexOf(items[0]), ex, fact = factOf(ex), order = items)
    }

    private fun qt(id: String, tier: Int, vararg dims: Int, b: (IntArray, Random) -> Question?) =
        Template(id, tier, dims, Format.quickfire, b)

    private fun tft(id: String, tier: Int, vararg dims: Int, b: (IntArray, Random) -> Question?) =
        Template(id, tier, dims, Format.truefalse, b)

    private fun st(id: String, tier: Int, vararg dims: Int, b: (IntArray, Random) -> Question?) =
        Template(id, tier, dims, Format.sort, b)

    private fun ot(id: String, tier: Int, vararg dims: Int, b: (IntArray, Random) -> Question?) =
        Template(id, tier, dims, Format.order, b)

    private fun nCk(n: Int, k: Int): Long {
        if (k < 0 || k > n) return 0
        var r = 1L
        for (i in 0 until k) r = r * (n - i) / (i + 1)
        return r
    }

    /** The [idx]-th k-subset of 0 until n, in lexicographic order. */
    private fun combo(n: Int, k: Int, idx0: Long): IntArray {
        var idx = idx0
        val out = IntArray(k)
        var x = 0
        for (i in 0 until k) {
            while (x < n) {
                val c = nCk(n - x - 1, k - i - 1)
                if (idx < c) { out[i] = x; x++; break }
                idx -= c
                x++
            }
        }
        return out
    }

    /** Seed s of a grid capped at [limit] mapped onto distinct k-subsets of n. */
    private fun comboSeed(n: Int, k: Int, s: Int, limit: Int): IntArray? {
        val total = nCk(n, k)
        if (total <= 0 || s >= minOf(total, limit.toLong())) return null
        val p = if (total % 7919L == 0L) 7907L else 7919L
        val idx = if (total <= limit) s.toLong() else (s.toLong() * p) % total
        return combo(n, k, idx)
    }

    private fun gridSize(n: Int, k: Int, limit: Int) = minOf(nCk(n, k), limit.toLong()).toInt()


    val lex: Map<String, EnWord> = words.associateBy { it.w }
    val byPlural: Map<String, EnWord> = words.filter { it.plural != null && it.plural != it.w }.associateBy { it.plural!! }
    val girls = t["names"]!!.jsonArray[0].ss
    val boys = t["names"]!!.jsonArray[1].ss
    val names = girls.zip(boys).flatMap { listOf(it.first, it.second) }

    fun rows(k: String): List<JsonArray> = t[k]?.jsonArray?.map { it.jsonArray } ?: emptyList()
    fun strs(k: String): List<String> = t[k]?.jsonArray?.map { it.s } ?: emptyList()
    fun obj(k: String): JsonObject = t[k]?.jsonObject ?: JsonObject(emptyMap())
    fun map(k: String): Map<String, List<String>> = obj(k).mapValues { it.value.ss }

    // ---- pictures
    fun picId(w0: String): String? {
        var x = w0.lowercase().trim()
        for (a in listOf("a ", "an ", "the ", "some ", "ripe ")) x = x.removePrefix(a)
        lex[x]?.pic?.let { return it }
        byPlural[x]?.pic?.let { return it }
        return if (x in pics && x !in PIC_SKIP) x else null
    }

    fun vis(w: String): Visual? = picId(w)?.let { Visual.Picture(it) }
    fun picOpt(w: String) = "pic:" + picId(w)!!

    /** Picture options for [ans] and [wrongs] (only words with pictures), else null. */
    fun askPic(prompt: String, ans: String, wrongs: List<String>, explain: String, r: Random, vis: Visual? = null): Question? {
        val a = picId(ans) ?: return null
        val ws = wrongs.filter { picId(it) != null && picId(it) != a }.distinctBy { picId(it) }
        if (ws.size < 3) return null
        val q = ask(prompt, "pic:$a", ws.shuffled(r).take(3).map { "pic:" + picId(it) }, explain, r, vis = vis, keep = true) ?: return null
        return q
    }

    fun art(w: String): String {
        val x = w.lowercase()
        lex[x]?.an?.let { return if (it) "an" else "a" }
        return if (x.firstOrNull()?.let { it in VOWELS } == true) "an" else "a"
    }

    fun withArt(w: String): String {
        val e = lex[w]
        return when {
            e?.count == false -> w
            byPlural.containsKey(w) || (e != null && e.plural == null && w.endsWith("s")) -> w
            else -> "${art(w)} $w"
        }
    }

    fun thisIs(w: String): String {
        val e = lex[w]
        return when {
            e?.count == false -> "This is $w."
            byPlural.containsKey(w) || (e != null && e.plural == null && w.endsWith("s")) -> "These are $w."
            else -> "This is ${art(w)} $w."
        }
    }

    fun isAlpha(w: String) = w.isNotEmpty() && w.all { it in 'a'..'z' }
    fun nouns(maxLvl: Int) = lex.values.filter { "n" in it.pos && it.lvl <= maxLvl && isAlpha(it.w) && !it.contested }.sortedBy { it.w }
    fun pureNouns(maxLvl: Int) = nouns(maxLvl).filter { it.pos == listOf("n") && it.count == true }
    fun pureVerbs(maxLvl: Int) = lex.values.filter { it.pos == listOf("v") && it.lvl <= maxLvl && isAlpha(it.w) }.sortedBy { it.w }
    fun pureAdjs(maxLvl: Int) = lex.values.filter { it.pos == listOf("adj") && it.lvl <= maxLvl && isAlpha(it.w) }.sortedBy { it.w }
    fun picNouns(maxLvl: Int) = nouns(maxLvl).filter { picId(it.w) != null }.distinctBy { picId(it.w) }
    fun uniqPic(ws: List<String>) = ws.filter { picId(it) != null }.distinctBy { picId(it) }

    fun s3(v: String): String = lex[v]?.s3 ?: when {
        v.endsWith("s") || v.endsWith("x") || v.endsWith("ch") || v.endsWith("sh") || v.endsWith("o") -> v + "es"
        v.endsWith("y") && v.length > 1 && v[v.length - 2] !in VOWELS -> v.dropLast(1) + "ies"
        else -> v + "s"
    }

    fun pastOf(v: String): String = lex[v]?.past ?: (if (v.endsWith("e")) v + "d" else v + "ed")
    fun ppOf(v: String): String = lex[v]?.pp ?: pastOf(v)
    fun ingOf(v: String): String = lex[v]?.ing ?: (if (v.endsWith("e") && !v.endsWith("ee")) v.dropLast(1) + "ing" else v + "ing")

    fun skill(id: String, grade: Int, title: String, badge: String, strand: String, vararg ts: Template): GenSkill {
        require(title.length <= 22) { "$id: title too long" }
        require(badge.length <= 4) { "$id: badge too long" }
        return GenSkill(id, grade, "english", title, badge, ts.toList(), strand = strand)
    }

    // ================================================================ KG
    private val UP = ('A'..'Z').map { "$it" }
    private val LO = ('a'..'z').map { "$it" }
    private val LOOK = mapOf(
        'b' to "dpq", 'd' to "bpq", 'p' to "qbd", 'q' to "pbd", 'm' to "nwu", 'n' to "muh", 'u' to "nvw", 'w' to "mvu",
        'i' to "ljt", 'l' to "itj", 'h' to "nbk", 'f' to "tlj", 't' to "fli", 'g' to "qyj", 'y' to "gvj", 'e' to "coa",
        'c' to "eoa", 'o' to "cae", 'a' to "oed", 's' to "zcx", 'z' to "sxn", 'v' to "wyu", 'k' to "hxl", 'x' to "kzy",
        'j' to "igy", 'r' to "nmh",
    )

    private fun look(c: Char) = LOOK[c]?.map { "$it" } ?: emptyList()

    fun kg(): List<GenSkill> = listOf(kgLetters(), kgAbc(), kgStarts(), kgRhyme(), kgColours(), kgOpp(), kgSight(), kgOdd(), kgActions(), kgSeq(), kgPicWord())

    private fun kgLetters(): GenSkill {
        val words = nouns(1).map { it.w }
        return skill(
            "enk.letters", 0, "Big and small letters", "Aa", "letters",
            qt("upLow", 1, 26) { s, r ->
                val l = LO[s[0]]; val u = UP[s[0]]
                ask("Find the small letter for $u.", l, LO - l - look(l[0]).toSet(), "Big $u and small $l are the same letter.", r)
            },
            qt("lowUp", 1, 26) { s, r ->
                val l = LO[s[0]]; val u = UP[s[0]]
                ask("Find the big letter for $l.", u, UP - u - look(l[0]).map { it.uppercase() }.toSet(), "Small $l and big $u are the same letter.", r)
            },
            tft("match", 2, 26, 3) { s, _ ->
                val l = LO[s[0]]; val u = UP[s[0]]
                if (s[1] == 0) tf("Small $l goes with big $u.", true, "Big $u goes with small $l.")
                else look(l[0]).getOrNull(s[1] - 1)?.let { x -> tf("Small $x goes with big $u.", false, "Big $u goes with small $l, not $x.") }
            },
            qt("hasLetter", 3, 26, 6) { s, r ->
                val l = LO[s[0]]
                val with = words.filter { l in it }
                val w = with.getOrNull(s[1]) ?: return@qt null
                ask("Which word has the letter $l in it?", w, words.filter { l !in it }, "${cap(w)} has the letter $l.", r)
            },
        )
    }

    private fun kgAbc(): GenSkill = skill(
        "enk.abc", 0, "ABC order", "abc", "letters",
        qt("after", 1, 25) { s, r ->
            val i = s[0]
            ask("Which letter comes just after ${UP[i]}?", UP[i + 1], listOfNotNull(UP.getOrNull(i - 1), UP.getOrNull(i + 2), UP.getOrNull(i + 3), UP[(i + 7) % 26]),
                "In the ABC, ${UP[i + 1]} comes just after ${UP[i]}.", r)
        },
        qt("before", 1, 25) { s, r ->
            val i = s[0] + 1
            ask("Which letter comes just before ${UP[i]}?", UP[i - 1], listOfNotNull(UP.getOrNull(i + 1), UP.getOrNull(i - 2), UP.getOrNull(i + 2), UP[(i + 9) % 26]),
                "In the ABC, ${UP[i - 1]} comes just before ${UP[i]}.", r)
        },
        qt("between", 2, 24) { s, r ->
            val i = s[0]
            ask("${UP[i]}, __, ${UP[i + 2]}: which letter is missing?", UP[i + 1], listOfNotNull(UP.getOrNull(i + 3), UP.getOrNull(i - 1), UP[(i + 5) % 26]),
                "${UP[i]}, ${UP[i + 1]}, ${UP[i + 2]} come in this order.", r)
        },
        qt("afterLow", 2, 25) { s, r ->
            val i = s[0]
            ask("Which letter comes just after ${LO[i]}?", LO[i + 1], listOfNotNull(LO.getOrNull(i - 1), LO.getOrNull(i + 2), LO[(i + 11) % 26]) + look(LO[i + 1][0]),
                "In the abc, ${LO[i + 1]} comes just after ${LO[i]}.", r)
        },
        ot("run3", 1, 24) { s, r ->
            val items = UP.subList(s[0], s[0] + 3)
            orderQ("Put the letters in ABC order.", items, "In ABC order: ${items.joinToString(", ")}.", r)
        },
        ot("pick3", 2, gridSize(26, 3, 150)) { s, r ->
            val c = comboSeed(26, 3, s[0], 150) ?: return@ot null
            if (c[1] == c[0] + 1 && c[2] == c[1] + 1) return@ot null
            val items = c.map { UP[it] }
            orderQ("Put the letters in ABC order.", items, "In ABC order: ${items.joinToString(", ")}.", r)
        },
        ot("pick4", 3, gridSize(26, 4, 150)) { s, r ->
            val c = comboSeed(26, 4, s[0], 150) ?: return@ot null
            val items = c.map { UP[it] }
            orderQ("Put the letters in ABC order.", items, "In ABC order: ${items.joinToString(", ")}.", r)
        },
    )

    private fun kgStarts(): GenSkill {
        val ws = picNouns(3).map { it.w }
        return skill(
            "enk.starts", 0, "Starts with…", "b", "letters",
            qt("first", 1, ws.size) { s, r ->
                val w = ws[s[0]]; val f = w.take(1)
                ask("Which letter does $w start with?", f, look(f[0]) + LO.shuffled(r), "${cap(w)} starts with $f.", r, vis = vis(w), keep = true)
            },
            tft("tf", 1, ws.size, 2) { s, _ ->
                val w = ws[s[0]]; val f = w.take(1)
                if (s[1] == 0) tf("${cap(w)} starts with $f.", true, "${cap(w)} starts with $f.", vis(w))
                else {
                    val x = look(f[0]).firstOrNull() ?: LO[(f[0] - 'a' + 1) % 26]
                    tf("${cap(w)} starts with $x.", false, "${cap(w)} starts with $f, not $x.", vis(w))
                }
            },
            qt("whichPic", 2, ws.size) { s, r ->
                val w = ws[s[0]]; val f = w.take(1)
                askPic("Which picture starts with $f?", w, ws.filter { it[0] != w[0] }, "${cap(w)} starts with $f.", r)
            },
            qt("endsPic", 3, ws.size) { s, r ->
                val w = ws[s[0]]; val l = w.takeLast(1)
                askPic("Which picture ends with $l?", w, ws.filter { it.last() != w.last() }, "${cap(w)} ends with $l.", r)
            },
        )
    }

    private val families: Map<String, List<String>> by lazy { map("families") }

    private fun kgRhyme(): GenSkill {
        val fams = families.entries.toList()
        val F = fams.size
        fun others(f: Int) = fams.filterIndexed { j, _ -> j != f }.flatMap { it.value }
        return skill(
            "enk.rhyme", 0, "Rhyming words", "-at", "sounds",
            qt("pick", 1, F, 8, 8) { s, r ->
                val (rime, ws) = fams[s[0]]
                val a = ws.getOrNull(s[1]) ?: return@qt null
                val b = ws.getOrNull(s[2]) ?: return@qt null
                if (a == b || (vis(a) == null && picId(b) == null)) return@qt null
                val ex = "${cap(a)} and $b both end in -$rime."
                val wrong = others(s[0])
                if (picId(b) != null) askPic("Which picture rhymes with $a?", b, wrong, ex, r, vis = vis(a))
                else ask("Which word rhymes with $a?", b, wrong, ex, r, vis = vis(a))
            },
            tft("tf", 2, F, 8, 9) { s, _ ->
                val (rime, ws) = fams[s[0]]
                val a = ws.getOrNull(s[1]) ?: return@tft null
                if (vis(a) == null) return@tft null
                if (s[2] < 8) {
                    val b = ws.getOrNull(s[2]) ?: return@tft null
                    if (s[2] <= s[1]) return@tft null
                    tf("${cap(a)} and $b rhyme.", true, "${cap(a)} and $b both end in -$rime.", vis(a))
                } else {
                    val of = fams[(s[0] + 1 + s[1]) % F].value
                    val o = of[s[1] % of.size]
                    tf("${cap(a)} and $o rhyme.", false, "${cap(a)} and $o end in different sounds.", vis(a))
                }
            },
            qt("odd", 3, F, 8, 6) { s, r ->
                val (rime, ws) = fams[s[0]]
                if (ws.size < 4) return@qt null
                val a = ws.getOrNull(s[1]) ?: return@qt null
                if (vis(a) == null) return@qt null
                val of = fams[(s[0] + 1 + s[2]) % F].value
                val o = of[(s[1] + s[2]) % of.size]
                val same = (ws - a).shuffled(r).take(3)
                val ex = "${cap(o)} does not end in -$rime."
                if (picId(o) != null && same.all { picId(it) != null } && (same + o).map { picId(it) }.toSet().size == 4)
                    ask("Which picture does not rhyme with $a?", "pic:" + picId(o), same.map { "pic:" + picId(it) }, ex, r, vis = vis(a), keep = true)
                else ask("Which word does not rhyme with $a?", o, same, ex, r, keep = true, vis = vis(a))
            },
        )
    }

    private fun kgColours(): GenSkill {
        val things = rows("colourThings").map { it[0].s to it[1].s }
        val colours = things.map { it.second }.distinct() + "purple"
        fun tv(x: String) = if ("chilli" in x || "bear" in x) null else vis(x)
        fun be(x: String) = if (x in setOf("peas", "tea leaves")) "are" else "is"
        val nonColour = nouns(1).map { it.w }.filter { it !in colours }
        val mix = rows("colourMix")
        return skill(
            "enk.colours", 0, "Colour words", "red", "words",
            qt("what", 1, things.size) { s, r ->
                val (x, c) = things[s[0]]
                ask("What colour ${be(x)} $x?", c, colours - c, "${cap(x)} ${be(x)} $c.", r, vis = tv(x))
            },
            tft("tf", 1, things.size, 3) { s, _ ->
                val (x, c) = things[s[0]]
                if (s[1] == 0) tf("${cap(x)} ${be(x)} $c.", true, "${cap(x)} ${be(x)} $c.", tv(x))
                else {
                    val o = (colours - c)[(s[0] * 3 + s[1]) % (colours.size - 1)]
                    tf("${cap(x)} ${be(x)} $o.", false, "${cap(x)} ${be(x)} $c, not $o.", tv(x))
                }
            },
            qt("which", 2, things.size) { s, r ->
                val (x, c) = things[s[0]]
                val wrong = things.filter { it.second != c }.map { it.first }
                val ex = "${cap(x)} ${be(x)} $c."
                (if (tv(x) != null) askPic("Which one is $c?", x, wrong.filter { tv(it) != null }, ex, r) else null)
                    ?: ask("Which one is $c?", x, wrong, ex, r)
            },
            qt("mix", 3, mix.size, 2) { s, r ->
                val m = mix[s[0]]
                val (a, b) = if (s[1] == 0) m[0].s to m[1].s else m[1].s to m[0].s
                ask("$a and $b make which colour?", m[2].s, colours - m[2].s - a - b, "Mixing $a and $b makes ${m[2].s}.", r)
            },
            qt("notColour", 3, nonColour.size) { s, r ->
                val w = nonColour[s[0]]
                ask("Which word is not a colour?", w, colours, "${cap(w)} is not a colour.", r)
            },
        )
    }

    private fun kgOpp(): GenSkill {
        val pairs = rows("oppKG").map { Triple(it[0].s, it[1].s, it[2].i == 1) }
        val dirs = pairs.flatMap { (a, b, two) -> if (two) listOf(a to b, b to a) else listOf(a to b) }
        val oppOf = HashMap<String, MutableSet<String>>()
        for ((a, b, _) in pairs) { oppOf.getOrPut(a) { HashSet() } += b; oppOf.getOrPut(b) { HashSet() } += a }
        val all = pairs.flatMap { listOf(it.first, it.second) }.distinct()
        fun bad(a: String, x: String) = x == a || x in oppOf[a].orEmpty()
        return skill(
            "enk.opposites", 0, "Opposites", "↔", "words",
            qt("opp", 1, dirs.size) { s, r ->
                val (a, b) = dirs[s[0]]
                ask("What is the opposite of $a?", b, all.filter { !bad(a, it) && it != b }, "${cap(a)} is the opposite of $b.", r, vis = vis(a))
            },
            tft("tf", 2, dirs.size, 4) { s, _ ->
                val (a, b) = dirs[s[0]]
                if (s[1] == 0) tf("${cap(a)} is the opposite of $b.", true, "${cap(a)} is the opposite of $b.")
                else {
                    val pool = all.filter { !bad(a, it) }
                    val x = pool[(s[0] * 5 + s[1] * 7) % pool.size]
                    tf("${cap(a)} is the opposite of $x.", false, "${cap(a)} is the opposite of $b, not $x.")
                }
            },
            qt("pair", 2, pairs.size) { s, r ->
                val (a, b, _) = pairs[s[0]]
                val pool = all.filter { !bad(a, it) && it != b }.shuffled(r)
                val wr = listOf("$a – ${pool[0]}", "${pool[1]} – $b", "${pool[2]} – ${pool[3]}")
                    .filter { o -> val (p, q) = o.split(" – "); q !in oppOf[p].orEmpty() }
                ask("Which two are opposites?", "$a – $b", wr, "${cap(a)} and $b are opposites.", r)
            },
        )
    }

    private val sight: List<JsonObject> by lazy { t["sight"]!!.jsonArray.map { it.jsonObject } }

    private fun sightSkill(id: String, grade: Int, title: String, badge: String, lvl: Int, find: Boolean): GenSkill {
        val ws = sight.filter { it["lvl"]!!.i == lvl }
        fun w(x: JsonObject) = x["w"]!!.s
        fun gaps(x: JsonObject, p: Int) = x["gaps"]?.jsonObject?.get("$p")?.ss ?: emptyList()
        fun spelled(x: String) = x.toList().joinToString("-")
        val ts = mutableListOf<Template>()
        if (find) ts += qt("find", 1, ws.size) { s, r ->
            val x = ws[s[0]]
            ask("Find the word: ${w(x)}", w(x), x["look"]!!.ss, "This word is ${w(x)}.", r)
        }
        ts += qt("spelt", if (find) 2 else 1, ws.size) { s, r ->
            val x = ws[s[0]]
            ask("Which word is spelt right?", w(x), x["miss"]!!.ss, "We spell it ${spelled(w(x))}.", r)
        }
        ts += qt("gap", if (find) 3 else 2, ws.size, 7) { s, r ->
            val x = ws[s[0]]; val word = w(x); val p = s[1]
            if (p >= word.length || word.length < 2 || (!find && word[p] !in VOWELS)) return@qt null
            val g = gaps(x, p)
            if (g.size < 2) return@qt null
            val masked = word.mapIndexed { i, c -> if (i == p) '_' else c }.joinToString(" ")
            ask("Fill the gap to make a word: $masked", "${word[p]}", g, "The word is $word.", r)
        }
        val missOwner = HashMap<String, String>()
        for (x in ws) for (m in x["miss"]!!.ss) missOwner.putIfAbsent(m, w(x))
        if (!find) ts += tft("tf", 3, ws.size, 3) { s, _ ->
            val x = ws[s[0]]; val word = w(x)
            if (s[1] == 0) tf("\"$word\" is spelt right.", true, "We spell it ${spelled(word)}.")
            else x["miss"]!!.ss.getOrNull(s[1] - 1)?.takeIf { missOwner[it] == word }?.let { m -> tf("\"$m\" is spelt right.", false, "We spell it ${spelled(word)}, not $m.") }
        }
        return skill(id, grade, title, badge, "reading", *ts.toTypedArray())
    }

    private fun kgSight() = sightSkill("enk.sight", 0, "Sight words", "the", 0, find = true)

    private data class OddCat(val cat: String, val one: String, val many: String, val not: Set<String> = emptySet())

    private val ODD_CATS = listOf(
        OddCat("fruit", "a fruit", "fruits"), OddCat("vegetable", "a vegetable", "vegetables"),
        OddCat("animal", "an animal", "animals", setOf("bird", "insect", "sea")), OddCat("bird", "a bird", "birds"),
        OddCat("vehicle", "a vehicle", "vehicles"), OddCat("body", "a part of the body", "parts of the body"),
        OddCat("clothes", "something we wear", "things we wear"), OddCat("furniture", "furniture", "furniture"),
        OddCat("insect", "an insect", "insects"),
    )

    private fun kgOdd(): GenSkill {
        val pw = lex.values.filter { it.pic != null && !it.contested && it.lvl <= 3 && it.cat != null && "n" in it.pos }.sortedBy { it.w }.distinctBy { it.pic }
        val inCat = ODD_CATS.map { c -> pw.filter { it.cat == c.cat }.map { it.w } }
        val outCat = ODD_CATS.map { c -> pw.filter { it.cat != c.cat && it.cat !in c.not }.map { it.w } }
        val C = ODD_CATS.size
        return skill(
            "enk.odd", 0, "Odd one out", "odd", "words",
            qt("not", 1, C, 220) { s, r ->
                val c = ODD_CATS[s[0]]
                if (inCat[s[0]].size < 3) return@qt null
                val odd = outCat[s[0]].getOrNull(s[1]) ?: return@qt null
                val q = askPic("Which one is not ${c.one}?", odd, inCat[s[0]], "${cap(odd)} is not ${c.one}.", r)
                q
            },
            qt("is", 2, C, 40) { s, r ->
                val c = ODD_CATS[s[0]]
                val w = inCat[s[0]].getOrNull(s[1]) ?: return@qt null
                askPic("Which one is ${c.one}?", w, outCat[s[0]], "${cap(w)} is ${c.one}.", r)
            },
            qt("belong", 3, pw.size) { s, r ->
                val odd = pw[s[0]]
                val k = (0 until C).map { (s[0] + it) % C }.firstOrNull { j ->
                    val c = ODD_CATS[j]
                    c.cat != odd.cat && odd.cat !in c.not && inCat[j].size >= 3
                } ?: return@qt null
                askPic("Which one does not belong?", odd.w, inCat[k], "The others are all ${ODD_CATS[k].many}.", r)
            },
        )
    }

    private fun kgActions(): GenSkill {
        val frames = rows("actionFrames").map { Triple(it[0].s, it[1].s, it[2].s.split(" ").filter { x -> x.isNotBlank() }.toSet()) }
        val verbs = strs("actionVerbs")
        val can = map("canDo")
        val canVerbs = can.keys.toList()
        fun objOf(f: String) = f.substringAfter("___ ").removeSuffix(".").split(" ").last()
        return skill(
            "enk.actions", 0, "Action words", "run", "words",
            qt("frame", 1, frames.size) { s, r ->
                val (f, a, ok) = frames[s[0]]
                ask(f, a, verbs.filter { it != a && it !in ok }, f.replace("___", a), r, vis = vis(objOf(f)))
            },
            tft("tf", 2, frames.size, 3) { s, _ ->
                val (f, a, ok) = frames[s[0]]
                val right = f.replace("___", a)
                if (s[1] == 0) tf(right, true, right, vis(objOf(f)))
                else {
                    val pool = verbs.filter { it != a && it !in ok }
                    val x = pool[(s[0] * 3 + s[1] * 5) % pool.size]
                    tf(f.replace("___", x), false, right, vis(objOf(f)))
                }
            },
            qt("can", 2, canVerbs.size, 12) { s, r ->
                val v = canVerbs[s[0]]
                val o = can[v]!!.getOrNull(s[1]) ?: return@qt null
                val wrong = canVerbs.filter { it != v }.flatMap { can[it]!! }
                val ex = "You can $v ${if (lex[o]?.count == true) withArt(o) else o}."
                askPic("Which one can you $v?", o, wrong, ex, r) ?: ask("Which one can you $v?", o, wrong, ex, r)
            },
        )
    }

    private fun seqSkill(id: String, grade: Int, title: String, badge: String, key: String, short: Boolean): GenSkill {
        val scripts = rows(key).map { it.ss }
        val S = scripts.size
        val maxLen = scripts.maxOf { it.size }
        val allSteps = scripts.flatten()
        fun other(i: Int) = allSteps.filter { it !in scripts[i] }
        val ts = mutableListOf<Template>(
            qt("next", 1, S, maxLen - 1) { s, r ->
                val sc = scripts[s[0]]; val i = s[1]
                if (i + 1 >= sc.size) return@qt null
                ask("What happens right after this? ${sc[i]}", sc[i + 1], sc.take(i).shuffled(r) + other(s[0]).shuffled(r), "Next comes: ${sc[i + 1]}", r, n = 3, keep = true)
            },
            qt("before", 1, S, maxLen - 1) { s, r ->
                val sc = scripts[s[0]]; val i = s[1] + 1
                if (i >= sc.size) return@qt null
                ask("What happens just before this? ${sc[i]}", sc[i - 1], sc.drop(i + 1).shuffled(r) + other(s[0]).shuffled(r), "Just before comes: ${sc[i - 1]}", r, n = 3, keep = true)
            },
            qt("first", 2, S) { s, r ->
                val sc = scripts[s[0]]
                ask("Which of these happens first?", sc[0], sc.drop(1), "It starts with: ${sc[0]}", r)
            },
            qt("last", 2, S) { s, r ->
                val sc = scripts[s[0]]
                ask("Which of these happens last?", sc.last(), sc.dropLast(1), "It ends with: ${sc.last()}", r)
            },
        )
        if (short) {
            ts += ot("order3", 2, S, 4) { s, r ->
                val sc = scripts[s[0]]
                if (sc.size != 4) return@ot null
                orderQ("Put the story in order.", sc.filterIndexed { i, _ -> i != s[1] }, "First: ${sc.filterIndexed { i, _ -> i != s[1] }[0]}", r)
            }
            ts += ot("order4", 3, S) { s, r -> orderQ("Put the story in order.", scripts[s[0]], "First: ${scripts[s[0]][0]}", r) }
        } else {
            ts += ot("order4", 2, S, 15) { s, r ->
                val sc = scripts[s[0]]
                val c = combo(sc.size, 4, s[1].toLong())
                if (s[1] >= nCk(sc.size, 4)) return@ot null
                val items = c.map { sc[it] }
                orderQ("Put these in order.", items, "First: ${items[0]}", r)
            }
            ts += ot("order5", 3, S, 6) { s, r ->
                val sc = scripts[s[0]]
                if (s[1] >= nCk(sc.size, 5)) return@ot null
                val items = combo(sc.size, 5, s[1].toLong()).map { sc[it] }
                orderQ("Put these in order.", items, "First: ${items[0]}", r)
            }
        }
        return skill(id, grade, title, badge, "reading", *ts.toTypedArray())
    }

    private fun kgSeq() = seqSkill("enk.sequence", 0, "First, next, last", "123", "seqKG", short = true)

    private fun kgPicWord(): GenSkill {
        val ws = picNouns(3).map { it.w }
        return skill(
            "enk.picword", 0, "Name the picture", "pic", "reading",
            qt("name", 1, ws.size) { s, r ->
                val w = ws[s[0]]
                val sameStart = ws.filter { it != w && it[0] == w[0] }
                val sameLen = ws.filter { it != w && it.length == w.length }
                ask("Tap the word for this picture.", w, (sameStart.shuffled(r) + sameLen.shuffled(r) + ws.shuffled(r)), thisIs(w), r, vis = vis(w), keep = true)
            },
            tft("tf", 2, ws.size, 2) { s, _ ->
                val w = ws[s[0]]
                if (s[1] == 0) tf(thisIs(w), true, thisIs(w), vis(w))
                else {
                    val o = ws[(s[0] + 1) % ws.size]
                    tf(thisIs(o), false, "${thisIs(w).removeSuffix(".")}, not ${withArt(o)}.", vis(w))
                }
            },
            qt("findPic", 1, ws.size) { s, r ->
                val w = ws[s[0]]
                askPic("Find the picture: $w", w, ws, thisIs(w), r)
            },
            qt("spell", 3, ws.size) { s, r ->
                val w = ws[s[0]]
                ask("Which spelling is right for this picture?", w, lex[w]?.miss ?: emptyList(), "We spell it ${w.toList().joinToString("-")}.", r, vis = vis(w))
            },
        )
    }

    // ================================================================ Class 1
    fun c1(): List<GenSkill> = listOf(c1Cvc(), c1Digraph(), c1Plural(), c1AAn(), c1NounVerb(), c1Capital(), c1Days(), c1Families(),
        sightSkill("en1.sight", 1, "Sight words 2", "why", 1, find = false), c1Vowels())

    private fun c1Cvc(): GenSkill {
        val rs = t["cvc"]!!.jsonArray.map { it.jsonObject }
        val cvcSet = rs.map { it["w"]!!.s }.toSet()
        val pg = picNouns(3).map { it.w }.filter { lex[it]?.gaps?.isNotEmpty() == true }
        fun gapQ(s: IntArray, r: Random, p: Int): Question? {
            val x = rs[s[0]]; val w = x["w"]!!.s
            val g = x["gaps"]!!.jsonObject["$p"]?.ss ?: return null
            if (g.isEmpty()) return null
            val masked = w.mapIndexed { i, c -> if (i == p) '_' else c }.joinToString(" ")
            return ask("Fill the gap: $masked", "${w[p]}", g, "The word is $w.", r, vis = vis(w))
        }
        return skill(
            "en1.cvc", 1, "Missing letter: c_t", "c_t", "phonics",
            qt("middle", 1, rs.size) { s, r -> gapQ(s, r, 1) },
            qt("whichWord", 1, rs.size) { s, r ->
                val w = rs[s[0]]["w"]!!.s
                val v = vis(w) ?: return@qt null
                val near = rs.map { it["w"]!!.s }.filter { o -> o != w && o.indices.count { o[it] != w[it] } == 1 }
                ask("Which word is this?", w, near.shuffled(r) + rs.map { it["w"]!!.s }.shuffled(r), "${thisIs(w)}", r, vis = v, keep = true)
            },
            qt("first", 2, rs.size) { s, r -> gapQ(s, r, 0) },
            qt("picGap", 2, pg.size, 8) { s, r ->
                val w = pg[s[0]]; val p = s[1]
                if (p >= w.length) return@qt null
                val g = lex[w]?.gaps?.get("$p") ?: return@qt null
                if (g.size < 2 || (w.length <= 3 && w in cvcSet)) return@qt null
                val masked = w.mapIndexed { i, c -> if (i == p) '_' else c }.joinToString(" ")
                ask("Fill the gap: $masked", "${w[p]}", g, "The word is $w.", r, vis = vis(w))
            },
            qt("last", 3, rs.size) { s, r -> gapQ(s, r, 2) },
        )
    }

    private fun c1Digraph(): GenSkill {
        val dg = map("digraphs")
        val keys = dg.keys.toList()
        val all = dg.values.flatten().distinct()
        val picAll = lex.values.filter { it.pic != null && isAlpha(it.w) }.map { it.w }
        fun sortT(id: String, tier: Int, a: String, b: String): Template {
            val cards = (dg[a]!! + dg[b]!!).distinct().filter { (a in it) != (b in it) }
            return st(id, tier, cards.size) { s, _ ->
                val w = cards[s[0]]
                val left = a in w
                sortQ(w, a, b, left, "${cap(w)} has ${if (left) a else b} in it.", vis(w))
            }
        }
        return skill(
            "en1.digraph", 1, "sh, ch, th, ck", "sh", "phonics",
            qt("has", 1, keys.size, 16) { s, r ->
                val d = keys[s[0]]
                val w = dg[d]!!.getOrNull(s[1]) ?: return@qt null
                ask("Which word has $d in it?", w, all.filter { d !in it }, "${cap(w)} has $d in it.", r)
            },
            sortT("sortShCh", 1, "sh", "ch"),
            qt("picHas", 2, keys.size, 16) { s, r ->
                val d = keys[s[0]]
                val w = uniqPic(dg[d]!!).getOrNull(s[1]) ?: return@qt null
                if (dg.filterKeys { it != d }.values.any { w in it }) return@qt null
                askPic("Which picture has $d in its name?", w, picAll.filter { d !in it && !(d == "ck" && "k" in it) && !(d == "sh" && "s" in it && "h" in it) }, "${cap(w)} has $d in it.", r)
            },
            sortT("sortThCk", 2, "th", "ck"),
            tft("tf", 2, all.size, 2) { s, _ ->
                val w = all[s[0]]
                val d = keys.first { it in w }
                if (s[1] == 0) tf("${cap(w)} has $d in it.", true, "${cap(w)} has $d in it.", vis(w))
                else keys.firstOrNull { it != d && it !in w }?.let { o -> tf("${cap(w)} has $o in it.", false, "${cap(w)} has $d, not $o.", vis(w)) }
            },
            qt("ends", 3, keys.size, 16) { s, r ->
                val d = keys[s[0]]
                val w = dg[d]!!.getOrNull(s[1]) ?: return@qt null
                if (!w.endsWith(d)) return@qt null
                ask("Which word ends with $d?", w, all.filter { !it.endsWith(d) }, "${cap(w)} ends with $d.", r)
            },
        )
    }

    private fun c1Plural(): GenSkill {
        val allS = nouns(2).filter { it.count == true && it.plural == it.w + "s" && it.cat != "people" }
        val ns = allS.filter { picId(it.w) != null }.distinctBy { picId(it.w) }
        val es = nouns(2).filter { it.count == true && it.plural == it.w + "es" }
        val cards = (ns + es).map { it.w to it.plural!! }
        val singles = (allS + es).map { it.w }
        return skill(
            "en1.plural", 1, "One and more: -s", "s", "grammar",
            qt("two", 1, ns.size) { s, r ->
                val w = ns[s[0]].w; val p = ns[s[0]].plural!!
                ask("One $w, two ___.", p, listOf(w, w + "es"), "For more than one $w, add s: $p.", r, n = 3, vis = vis(w))
            },
            st("sort", 1, cards.size, 2) { s, _ ->
                val (w, p) = cards[s[0]]
                if (s[1] == 0) sortQ(w, "One", "Many", true, "${cap(w)} means just one.", vis(w))
                else sortQ(p, "One", "Many", false, "${cap(p)} means more than one $w.", vis(w))
            },
            qt("which", 2, allS.size) { s, r ->
                val w = allS[s[0]].w; val p = allS[s[0]].plural!!
                ask("Which word means more than one?", p, singles.filter { it != w }, "${cap(p)} means more than one $w.", r)
            },
            tft("tf", 2, ns.size, 2) { s, _ ->
                val w = ns[s[0]].w; val p = ns[s[0]].plural!!
                if (s[1] == 0) tf("${cap(p)} means more than one $w.", true, "${cap(p)} means more than one $w.", vis(w))
                else tf("${cap(w)} means more than one $w.", false, "${cap(w)} is just one, and $p means many.", vis(w))
            },
        )
    }

    private val ADJ_FOR = mapOf(
        "thing" to "big small old new red ugly empty heavy tiny huge clean dirty",
        "school" to "big small old new red empty heavy tiny clean dirty",
        "home" to "big small old new ugly empty heavy tiny huge clean dirty",
        "toy" to "big small old new red ugly tiny huge",
        "animal" to "big small old young ugly angry tiny huge fat hungry lazy",
        "bird" to "big small old young ugly angry tiny hungry",
        "fruit" to "big small ripe red juicy unripe old",
        "vehicle" to "big small old new red empty heavy",
    ).mapValues { it.value.split(" ") }

    private fun anEx(w: String, an: Boolean) =
        if (an) "${cap(w)} starts with a vowel sound, so we say an." else "${cap(w)} starts with a consonant sound, so we say a."

    private fun aAnNouns(maxLvl: Int) = nouns(maxLvl).filter { it.count == true && it.plural != null && it.an != null && it.w[0] !in "uh" && !it.w.startsWith("eu") && !it.w.startsWith("one") }

    private fun adjNouns(maxLvl: Int): List<Pair<String, String>> {
        val ns = aAnNouns(maxLvl).filter { it.cat in ADJ_FOR && picId(it.w) != null }
        return ns.flatMap { n -> ADJ_FOR[n.cat]!!.map { it to n.w } }
    }

    private fun c1AAn(): GenSkill {
        val ns = aAnNouns(2)
        val an = ns.filter { it.an == true }
        val a = ns.filter { it.an == false }
        val an2 = adjNouns(2)
        val plain = (ns.map { it.w } + an2.map { "${it.first} ${it.second}" }).toSet()
        val tricky = rows("anTricky").filter { it[0].s !in plain }
        return skill(
            "en1.aan", 1, "a or an", "a/an", "grammar",
            st("sort", 1, ns.size) { s, _ ->
                val w = ns[s[0]]
                sortQ("___ ${w.w}", "a", "an", w.an == false, anEx(w.w, w.an == true), vis(w.w))
            },
            qt("needsAn", 2, an.size) { s, r ->
                val w = an[s[0]].w
                ask("Which word needs an before it?", w, a.map { it.w }, anEx(w, true), r, vis = vis(w))
            },
            qt("needsA", 2, a.size) { s, r ->
                val w = a[s[0]].w
                ask("Which word needs a before it?", w, an.map { it.w }, anEx(w, false), r, vis = vis(w))
            },
            qt("adj", 1, an2.size) { s, r ->
                val (adj, n) = an2[s[0]]
                val isAn = adj[0] in VOWELS
                ask("___ $adj $n", if (isAn) "an" else "a", listOf(if (isAn) "a" else "an"), anEx(adj, isAn), r, vis = vis(n))
            },
            qt("tricky", 3, tricky.size) { s, r ->
                val p = tricky[s[0]][0].s; val ans = tricky[s[0]][1].s
                val first = p.split(" ")[0]
                val why = if (ans == "an") "${cap(first)} starts with a vowel sound, so we say an."
                else "${cap(first)} starts with a consonant sound, so we say a."
                ask("___ $p", ans, listOf(if (ans == "an") "a" else "an"), why, r, vis = vis(p))
            },
        )
    }

    private fun c1NounVerb(): GenSkill {
        val ns = pureNouns(1).filter { it.cat !in setOf("time", "thing") }.map { it.w }
        val vs = pureVerbs(2).map { it.w }
        val cards = ns.map { it to true } + vs.map { it to false }
        val sents = rows("sbSubj").map { it[0].s }.flatMap { sub -> (strs("sbVp3") + strs("sbVp4")).map { sub to it } }
        return skill(
            "en1.nounverb", 1, "Naming or doing?", "n/v", "grammar",
            st("sort", 1, cards.size) { s, _ ->
                val (w, noun) = cards[s[0]]
                sortQ(w, "Naming word", "Doing word", noun, if (noun) "${cap(w)} is a naming word." else "${cap(w)} is a doing word.", if (noun) vis(w) else null)
            },
            qt("naming", 1, ns.size) { s, r ->
                val w = ns[s[0]]
                ask("Which one is a naming word?", w, vs, "${cap(w)} names a thing, so it is a naming word.", r)
            },
            qt("doing", 2, vs.size) { s, r ->
                val w = vs[s[0]]
                ask("Which one is a doing word?", w, ns, "${cap(w)} is something we do.", r)
            },
            qt("inSentence", 3, sents.size) { s, r ->
                val (sub, vp) = sents[s[0]]
                val sentence = "$sub $vp."
                val verb = vp.split(" ")[0]
                val words = sentence.removeSuffix(".").split(" ").filter { it.lowercase() !in setOf("a", "the", "my", "with") }
                ask("Find the doing word: $sentence", verb, words.filter { it != verb }, "${cap(verb)} tells us what ${if (sub.startsWith("My")) "my " + sub.substringAfter(" ") else sub} does.", r)
            },
        )
    }

    private fun c1Capital(): GenSkill {
        val preds = strs("capPred")
        val sents = preds.flatMapIndexed { p, pr -> (0 until 3).map { k -> names[(p * 3 + k) % names.size].let { n -> n to "$n $pr." } } }
            .filter { it.second.length <= 24 }
        val capI = strs("capI")
        val capName = strs("capName").flatMap { f -> names.take(10).map { n -> n to f.replace("{n}", n) } }.filter { it.second.length <= 24 }
        fun lowerFirst(x: String) = x.replaceFirstChar { it.lowercaseChar() }
        return skill(
            "en1.capital", 1, "Capitals, full stops", "Aa.", "writing",
            qt("start", 1, sents.size) { s, r ->
                val (n, x) = sents[s[0]]
                val others = (1..3).map { k -> lowerFirst(sents[(s[0] + k * 5) % sents.size].second) }
                ask("Which one starts with a capital letter?", x, others, "A sentence starts with a capital letter, like $n.", r)
            },
            qt("stop", 2, sents.size) { s, r ->
                val (_, x) = sents[s[0]]
                ask("Which one ends with a full stop?", x, listOf(x.removeSuffix(".")), "A telling sentence ends with a full stop.", r)
            },
            tft("tf", 2, sents.size, 2) { s, _ ->
                val (n, x) = sents[s[0]]
                if (s[1] == 0) tf("This is written correctly: $x", true, "It starts with a capital and ends with a full stop.")
                else if (s[0] % 2 == 0) tf("This is written correctly: ${lowerFirst(x)}", false, "Names like $n start with a capital letter.")
                else tf("This is written correctly: ${x.removeSuffix(".")}", false, "A telling sentence ends with a full stop.")
            },
            qt("i", 3, capI.size) { s, r ->
                val x = capI[s[0]]
                fun lowI(y: String) = y.split(" ").joinToString(" ") { if (it == "I") "i" else it }
                val o1 = capI[(s[0] + 3) % capI.size]; val o2 = capI[(s[0] + 7) % capI.size]
                ask("Which is written correctly?", x, listOf(lowI(o1), o2.removeSuffix("."), lowI(capI[(s[0] + 11) % capI.size])), "We always write I as a capital letter.", r)
            },
            qt("name", 3, capName.size) { s, r ->
                val (n, x) = capName[s[0]]
                val (n1, o1) = capName[(s[0] + 13) % capName.size]; val (_, o2) = capName[(s[0] + 29) % capName.size]
                ask("Which is written correctly?", x, listOf(o1.replace(n1, n1.lowercase()), o2.removeSuffix("."), capName[(s[0] + 41) % capName.size].let { (n3, o3) -> o3.replace(n3, n3.lowercase()) }),
                    "Names like $n start with a capital letter.", r)
            },
        )
    }

    private fun c1Days(): GenSkill {
        val D = strs("days"); val M = strs("months")
        val week6 = D.take(6)
        val daySets = (0 until nCk(6, 3).toInt()).map { combo(6, 3, it.toLong()) } + (0 until nCk(6, 4).toInt()).map { combo(6, 4, it.toLong()) }
        fun near(l: List<String>, i: Int) = listOf(l[(i + 2) % l.size], l[(i + l.size - 1) % l.size], l[(i + 3) % l.size], l[(i + 4) % l.size])
        return skill(
            "en1.days", 1, "Days and months", "Mon", "words",
            qt("dayAfter", 1, 7) { s, r ->
                val i = s[0]; val n = D[(i + 1) % 7]
                ask("Which day comes after ${D[i]}?", n, near(D, i).filter { it != n }, "$n comes after ${D[i]}.", r)
            },
            qt("dayBefore", 1, 7) { s, r ->
                val i = s[0]; val p = D[(i + 6) % 7]
                ask("Which day comes before ${D[i]}?", p, listOf(D[(i + 1) % 7], D[(i + 2) % 7], D[(i + 4) % 7]), "$p comes before ${D[i]}.", r)
            },
            ot("dayOrder", 1, daySets.size) { s, r ->
                val items = daySets[s[0]].map { week6[it] }
                orderQ("Put the days in order.", items, "In order: ${items.joinToString(", ")}.", r)
            },
            qt("monthAfter", 2, 12) { s, r ->
                val i = s[0]; val n = M[(i + 1) % 12]
                ask("Which month comes after ${M[i]}?", n, near(M, i).filter { it != n }, "$n comes after ${M[i]}.", r)
            },
            qt("monthBefore", 2, 12) { s, r ->
                val i = s[0]; val p = M[(i + 11) % 12]
                ask("Which month comes before ${M[i]}?", p, listOf(M[(i + 1) % 12], M[(i + 2) % 12], M[(i + 10) % 12]), "$p comes before ${M[i]}.", r)
            },
            qt("between", 2, 10) { s, r ->
                val i = s[0]
                ask("Which month comes between ${M[i]} and ${M[i + 2]}?", M[i + 1], listOf(M[(i + 3) % 12], M[(i + 11) % 12], M[(i + 5) % 12]), "${M[i]}, ${M[i + 1]}, ${M[i + 2]} come in this order.", r)
            },
            qt("twoAfter", 3, 7) { s, r ->
                val i = s[0]; val n = D[(i + 2) % 7]
                ask("Which day comes two days after ${D[i]}?", n, listOf(D[(i + 1) % 7], D[(i + 3) % 7], D[(i + 6) % 7]), "After ${D[i]} come ${D[(i + 1) % 7]}, then $n.", r)
            },
            ot("month3", 2, nCk(12, 3).toInt()) { s, r ->
                val items = combo(12, 3, s[0].toLong()).map { M[it] }
                orderQ("Put the months in order.", items, "In order: ${items.joinToString(", ")}.", r)
            },
            ot("month4", 3, gridSize(12, 4, 300)) { s, r ->
                val items = comboSeed(12, 4, s[0], 300)?.map { M[it] } ?: return@ot null
                orderQ("Put the months in order.", items, "In order: ${items.joinToString(", ")}.", r)
            },
        )
    }

    private fun c1Families(): GenSkill {
        val fams = families.entries.toList()
        val F = fams.size
        val all = fams.flatMap { (rime, ws) -> ws.map { it to rime } }
        val pairs = rows("familyPairs").map { it[0].s to it[1].s }
        val usedF = HashSet<String>()
        val okPairs = pairs.filter { (a, b) -> a !in usedF && b !in usedF && usedF.add(a) && usedF.add(b) }
        val sortTs = okPairs.mapIndexed { k, (a, b) ->
            val cards = (families[a].orEmpty() + families[b].orEmpty())
            st("sort_${a}_$b", if (k < 5) 1 else 2, cards.size) { s, _ ->
                val w = cards[s[0]]
                val left = w.endsWith(a) && w in families[a].orEmpty()
                sortQ(w, "-$a", "-$b", left, "${cap(w)} ends in -${if (left) a else b}.", vis(w))
            }
        }
        val ts = mutableListOf<Template>(
            qt("inFamily", 1, all.size) { s, r ->
                val (w, rime) = all[s[0]]
                val wrong = all.filter { !it.first.endsWith(rime) }.map { it.first }
                val ex = "${cap(w)} ends in -$rime."
                askPic("Which picture is in the -$rime family?", w, wrong, ex, r) ?: ask("Which word is in the -$rime family?", w, wrong, ex, r)
            },
            qt("change", 2, F, 8, 8) { s, r ->
                val (rime, ws) = fams[s[0]]
                val a = ws.getOrNull(s[1]) ?: return@qt null
                val b = ws.getOrNull(s[2]) ?: return@qt null
                if (a == b || !a.endsWith(rime) || !b.endsWith(rime) || (vis(a) == null && vis(b) == null)) return@qt null
                val oa = a.removeSuffix(rime); val ob = b.removeSuffix(rime)
                if (oa.isEmpty() || ob.isEmpty()) return@qt null
                ask("Change the $oa in $a to $ob. Which word do you get?", b, (ws - b - a) + listOf(a) + all.filter { it.first.startsWith(ob) && it.second != rime }.map { it.first },
                    "${cap(ob)} and -$rime make $b.", r, vis = vis(b))
            },
            tft("tf", 3, F, 8, 9) { s, _ ->
                val (rime, ws) = fams[s[0]]
                val a = ws.getOrNull(s[1]) ?: return@tft null
                if (vis(a) == null) return@tft null
                if (s[2] < 8) {
                    val b = ws.getOrNull(s[2]) ?: return@tft null
                    if (s[2] <= s[1]) return@tft null
                    tf("${cap(a)} and $b are in the same word family.", true, "${cap(a)} and $b both end in -$rime.", vis(a))
                } else {
                    val (orime, of) = fams[(s[0] + 2 + s[1]) % F]
                    val o = of[s[1] % of.size]
                    if (o.endsWith(rime)) return@tft null
                    tf("${cap(a)} and $o are in the same word family.", false, "${cap(a)} ends in -$rime, but $o ends in -$orime.", vis(a))
                }
            },
        )
        ts += sortTs
        return skill("en1.families", 1, "Word families: -at", "-at", "phonics", *ts.toTypedArray())
    }

    private fun c1Vowels(): GenSkill {
        val letters = LO.filter { it != "y" }
        val vowelStart = picNouns(2).map { it.w }.filter { it[0] in VOWELS }
        val consStart = picNouns(3).map { it.w }.filter { it[0] !in VOWELS }
        val cw = picNouns(3).map { it.w }.filter { 'y' !in it && it.count { c -> c in VOWELS } in 1..4 }
        fun countQ(w: String, r: Random): Question? {
            val vs = w.filter { it in VOWELS }
            val n = vs.length
            val ex = "${cap(w)} has $n ${if (n == 1) "vowel" else "vowels"}: ${vs.toList().joinToString(", ")}."
            return ask("How many vowels are in $w?", "$n", listOf("1", "2", "3", "4", "5") - "$n", ex, r, vis = vis(w))
        }
        val short = cw.filter { it.length <= 5 }; val long = cw.filter { it.length > 5 }
        return skill(
            "en1.vowels", 1, "Vowels: a e i o u", "aei", "phonics",
            st("sort", 1, letters.size) { s, _ ->
                val l = letters[s[0]]; val v = l[0] in VOWELS
                sortQ(l, "Vowel", "Not a vowel", v, if (v) "$l is one of the vowels a, e, i, o, u." else "$l is not one of a, e, i, o, u.")
            },
            qt("startPic", 1, vowelStart.size) { s, r ->
                val w = vowelStart[s[0]]
                askPic("Which picture starts with a vowel?", w, consStart, "${cap(w)} starts with the vowel ${w[0]}.", r)
            },
            tft("tf", 1, 26) { s, _ ->
                val l = UP[s[0]]
                if (l == "Y") return@tft null
                val v = l.lowercase()[0] in VOWELS
                tf("$l is a vowel.", v, if (v) "$l is one of the vowels." else "$l is not a vowel.")
            },
            qt("count", 2, short.size) { s, r -> countQ(short[s[0]], r) },
            qt("countLong", 3, long.size) { s, r -> countQ(long[s[0]], r) },
        )
    }

    // ================================================================ Class 2
    fun c2(): List<GenSkill> = listOf(c2MagicE(), c2Plurals(), c2Pronoun(), c2Be(), c2PastEd(), c2QWords(), c2Compound(), c2Alpha(), c2SameOpp(), c2Build())

    private fun c2MagicE(): GenSkill {
        val rs = rows("magicE").map { it.ss }
        val longs = rs.map { it[1] }; val shorts = rs.map { it[0] }
        return skill(
            "en2.magice", 2, "Magic e: cap, cape", "e", "phonics",
            st("sort", 1, rs.size, 2) { s, _ ->
                val (sh, lo) = rs[s[0]].let { it[0] to it[1] }
                if (s[1] == 0) sortQ(lo, "Magic e", "No magic e", true, "${cap(lo)} ends with a magic e.", vis(lo))
                else sortQ(sh, "Magic e", "No magic e", false, "${cap(sh)} has no e at the end.", vis(sh))
            },
            qt("add", 1, rs.size) { s, r ->
                val (sh, lo) = rs[s[0]].let { it[0] to it[1] }
                ask("Add e to $sh. Which word do you get?", lo, listOf(sh) + longs.shuffled(r), "${cap(sh)} plus e makes $lo.", r, vis = vis(lo), keep = true)
            },
            qt("remove", 2, rs.size) { s, r ->
                val (sh, lo) = rs[s[0]].let { it[0] to it[1] }
                ask("Take the e off $lo. Which word is left?", sh, listOf(lo) + shorts.shuffled(r), "${cap(lo)} without the e is $sh.", r, keep = true)
            },
            tft("tf", 2, rs.size, 2) { s, _ ->
                val (sh, lo) = rs[s[0]].let { it[0] to it[1] }
                if (s[1] == 0) tf("${cap(sh)} plus e makes $lo.", true, "${cap(sh)} plus e makes $lo.")
                else {
                    val o = longs[(s[0] + 5) % longs.size]
                    if (o == lo) null else tf("${cap(sh)} plus e makes $o.", false, "${cap(sh)} plus e makes $lo, not $o.")
                }
            },
            qt("frame", 3, rs.size, 2) { s, r ->
                val row = rs[s[0]]
                val (f, ans, other) = if (s[1] == 0) Triple(row[2], row[1], row[0]) else Triple(row[3], row[0], row[1])
                if (f.isBlank() || "___" !in f) return@qt null
                ask(f, ans, listOf(other, if (s[1] == 0) shorts[(s[0] + 3) % shorts.size] else longs[(s[0] + 3) % longs.size]), "Here we need $ans, not $other.", r, n = 3, keep = true)
            },
        )
    }

    private fun pluralKind(w: EnWord): String {
        val p = w.plural!!; val x = w.w
        return when {
            p == x + "s" && x.endsWith("y") -> "ys"
            p == x + "s" -> "s"
            p == x + "es" -> "es"
            x.endsWith("y") && p == x.dropLast(1) + "ies" -> "ies"
            p.endsWith("ves") -> "ves"
            else -> "irr"
        }
    }

    private fun pluralWrongs(x: String, p: String): List<String> {
        val c = mutableListOf(x + "s", x + "es")
        if (x.endsWith("y")) c += x.dropLast(1) + "ies"
        if (x.endsWith("f")) c += x.dropLast(1) + "ves"
        if (x.endsWith("fe")) c += x.dropLast(2) + "ves"
        if (p != x + "s" && p != x + "es" && !p.endsWith("ies") && !p.endsWith("ves")) c += p + "s"
        c += x
        return c.filter { it != p }.distinct()
    }

    private fun pluralWhy(w: EnWord): String {
        val x = w.w; val p = w.plural!!
        return when (pluralKind(w)) {
            "es" -> "Words ending in ${if (x.endsWith("ch") || x.endsWith("sh")) x.takeLast(2) else x.takeLast(1)} add es: $p."
            "ies" -> "Change y to i and add es: $p."
            "ys" -> "${cap(x)} has a vowel before y, so just add s: $p."
            "ves" -> "${cap(x)} changes f to v and adds es: $p."
            "s" -> "Just add s: $p."
            else -> if (p == x) "${cap(x)} stays $p for more than one." else "${cap(x)} changes to $p, not ${x}s."
        }
    }

    private fun c2Plurals(): GenSkill {
        val ns = nouns(3).filter { it.count == true && it.plural != null && isAlpha(it.plural!!) }
        val by = ns.groupBy { pluralKind(it) }
        val es = by["es"].orEmpty(); val ys = by["ies"].orEmpty() + by["ys"].orEmpty()
        val ves = by["ves"].orEmpty(); val irr = by["irr"].orEmpty()
        val sortCards = (by["s"].orEmpty().filter { it.lvl <= 2 } + es)
        val hard = es + ys + ves + irr
        fun two(w: EnWord, r: Random) = ask("One ${w.w}, two ___.", w.plural!!, pluralWrongs(w.w, w.plural!!), pluralWhy(w), r, vis = vis(w.w))
        return skill(
            "en2.plurals", 2, "Plurals: es, ies, ves", "es", "grammar",
            qt("es", 1, es.size) { s, r -> two(es[s[0]], r) },
            st("sort", 1, sortCards.size) { s, _ ->
                val w = sortCards[s[0]]
                sortQ(w.w, "add s", "add es", pluralKind(w) == "s", "${cap(w.w)} becomes ${w.plural}.", vis(w.w))
            },
            qt("y", 2, ys.size) { s, r -> two(ys[s[0]], r) },
            qt("ves", 2, ves.size) { s, r -> two(ves[s[0]], r) },
            qt("irr", 3, irr.size) { s, r -> two(irr[s[0]], r) },
            tft("tf", 3, hard.size, 3) { s, _ ->
                val w = hard[s[0]]
                if (s[1] == 0) tf("One ${w.w}, two ${w.plural}.", true, pluralWhy(w), vis(w.w))
                else pluralWrongs(w.w, w.plural!!).filter { it != w.w }.getOrNull(s[1] - 1)?.let { f ->
                    tf("One ${w.w}, two $f.", false, pluralWhy(w), vis(w.w))
                }
            },
        )
    }

    private fun npLow(np: String) = if (np.startsWith("My ") || np.startsWith("The ")) np.replaceFirstChar { it.lowercaseChar() } else np

    private fun c2Pronoun(): GenSkill {
        val np = rows("pronNP").map { Triple(it[0].s, it[1].s, it[2].s) }
        val th = rows("pronThing").map { it[0].s to it[1].s }
        val fr = obj("pronFrames").mapValues { it.value.ss }
        val subj = listOf("She", "He", "It", "They")
        val items = listOf("bag", "kite", "book", "cap")
        fun objP(k: String) = when (k) { "f" -> "her"; "m" -> "him"; else -> "them" }
        fun poss(k: String) = when (k) { "f" -> "her"; "m" -> "his"; else -> "their" }
        return skill(
            "en2.pronoun", 2, "He, she, it, they", "she", "grammar",
            qt("person", 1, np.size, 8) { s, r ->
                val (n, p, k) = np[s[0]]
                val f = (if (k == "pl") fr["pl"]!! else fr["sg"]!!)[s[1]]
                ask("Look at ${npLow(n)}. $f", cap(p), subj, "We use $p for ${npLow(n)}.", r)
            },
            qt("thing", 1, th.size, 4) { s, r ->
                val (n, p) = th[s[0]]
                val f = (if (p == "they") fr["thingPl"]!! else fr["thingSg"]!!)[s[1]]
                ask("Look at ${npLow(n)}. $f", cap(p), subj, "We use $p for ${npLow(n)}.", r, vis = vis(n))
            },
            qt("object", 2, np.size, 5) { s, r ->
                val (n, p, k) = np[s[0]]
                val o = objP(k)
                ask("Look at ${npLow(n)}. ${fr["obj"]!![s[1]]}", o, listOf(p, "her", "him", "them", "it") - o, "After a doing word, ${npLow(n)} becomes $o.", r)
            },
            qt("owner", 3, np.size, items.size) { s, r ->
                val (n, _, k) = np[s[0]]
                val it0 = items[s[1]]
                val ps = poss(k)
                ask("This $it0 belongs to ${npLow(n)}. It is ___ $it0.", ps, listOf("her", "his", "their", "she", "they", "its") - ps,
                    "It belongs to ${npLow(n)}, so it is $ps $it0.", r, vis = vis(it0))
            },
        )
    }

    private fun lowSubj(x: String) = when {
        x == "I" -> x
        x in names || x.startsWith("Riya") || x == "Grandpa" || x == "Grandma" -> x
        else -> x.replaceFirstChar { it.lowercaseChar() }
    }

    private fun c2Be(): GenSkill {
        val subs = rows("beSubj").map { it[0].s to it[1].s }
        val comps = strs("bePeopleComp")
        val pron = setOf("I", "You", "We", "They", "He", "She")
        val nounSubs = subs.filter { it.first !in pron }
        val pronSubs = subs.filter { it.first in pron }
        val things = rows("beThing").flatMap { row -> row[2].ss.map { Triple(row[0].s, row[1].s, it) } }
        fun be(k: String) = when (k) { "I" -> "am"; "3s" -> "is"; else -> "are" }
        fun was(k: String) = if (k == "I" || k == "3s") "was" else "were"
        return skill(
            "en2.be", 2, "Is, are, am", "is", "grammar",
            st("sort", 1, things.size) { s, _ ->
                if (s[0] % 2 == 1) return@st null
                val (n, k, c) = things[s[0]]
                sortQ("$n ___ $c.", "is", "are", k == "3s", "We say ${npLow(n)} ${be(k)} $c.", vis(n))
            },
            qt("noun", 1, nounSubs.size, comps.size) { s, r ->
                val (n, k) = nounSubs[s[0]]; val c = comps[s[1]]
                ask("$n ___ $c.", be(k), listOf("is", "are", "am") - be(k), "We say ${lowSubj(n)} ${be(k)} $c.", r)
            },
            qt("thing", 2, things.size) { s, r ->
                if (s[0] % 2 == 0) return@qt null
                val (n, k, c) = things[s[0]]
                ask("$n ___ $c.", be(k), listOf("is", "are", "am") - be(k), "We say ${npLow(n)} ${be(k)} $c.", r, vis = vis(n.substringAfter(" ")))
            },
            qt("pronoun", 2, pronSubs.size, comps.size) { s, r ->
                val (n, k) = pronSubs[s[0]]; val c = comps[s[1]]
                ask("$n ___ $c.", be(k), listOf("is", "are", "am") - be(k), "We say ${lowSubj(n)} ${be(k)}.", r)
            },
            qt("past", 3, subs.size, comps.size) { s, r ->
                val (n, k) = subs[s[0]]; val c = comps[s[1]]
                val a = was(k)
                ask("Yesterday, ${lowSubj(n)} ___ $c.", a, listOf("was", "were", "is", "are") - a, "Yesterday is the past, so ${lowSubj(n)} $a.", r)
            },
        )
    }

    private val INTRANS = setOf("walk", "jump", "play", "cook", "clean", "dance", "smile", "laugh", "talk", "shout", "cry", "hurry",
        "rest", "wait", "work", "skip", "hop", "clap", "shop", "jog", "nod", "travel", "climb", "paint", "wash", "listen", "count",
        "study", "learn", "shiver", "arrive", "skate", "look", "bake", "move", "try", "stop", "help", "finish", "start", "answer",
        "reply", "agree", "obey", "share", "plant", "kick", "push", "pull", "brush", "fix", "mix", "trip")

    private fun edWrongs(v: String, rule: String?): List<String> = when (rule) {
        "d" -> listOf(v + "ed", v.dropLast(1) + "ied")
        "ied" -> listOf(v + "ed", v + "d")
        "double" -> listOf(v + "ed", v + v.last() + "d")
        else -> listOf(v + "d", v + "t")
    }

    private fun edWhy(v: String, p: String, rule: String?) = when (rule) {
        "d" -> "${cap(v)} ends in e, so just add d: $p."
        "ied" -> "Change y to i and add ed: $p."
        "double" -> "Double the last letter and add ed: $p."
        else -> "Add ed to $v: $p."
    }

    private fun c2PastEd(): GenSkill {
        val vs = lex.values.filter { "v" in it.pos && !it.irr && it.lvl <= 3 && isAlpha(it.w) && it.edRule != null }.sortedBy { it.w }
        val fr = vs.filter { it.w in INTRANS }
        val tricky = vs.filter { it.edRule != "ed" }
        return skill(
            "en2.pasted", 2, "Past tense: -ed", "ed", "grammar",
            qt("frame", 1, fr.size) { s, r ->
                val v = fr[s[0]]
                ask("Today I ${v.w}. Yesterday I ___.", v.past!!, listOf(v.w, v.s3!!) + edWrongs(v.w, v.edRule), edWhy(v.w, v.past, v.edRule), r)
            },
            st("sort", 1, vs.size, 2) { s, _ ->
                val v = vs[s[0]]
                if (s[1] == 0) sortQ(v.w, "Now", "Past", true, "${cap(v.w)} tells about now.")
                else sortQ(v.past!!, "Now", "Past", false, "${cap(v.past)} tells about the past.")
            },
            qt("spell", 2, tricky.size) { s, r ->
                val v = tricky[s[0]]
                ask("Add ed to ${v.w}. Which is right?", v.past!!, edWrongs(v.w, v.edRule), edWhy(v.w, v.past, v.edRule), r)
            },
            tft("tf", 3, vs.size, 2) { s, _ ->
                val v = vs[s[0]]
                if (s[1] == 0) tf("${cap(v.w)} in the past is ${v.past}.", true, edWhy(v.w, v.past!!, v.edRule))
                else tf("${cap(v.w)} in the past is ${edWrongs(v.w, v.edRule)[0]}.", false, edWhy(v.w, v.past!!, v.edRule))
            },
        )
    }

    private val QW_WHY = mapOf(
        "Who" to "Who asks about a person.", "What" to "What asks about a thing.", "Where" to "Where asks about a place.",
        "When" to "When asks about a time.", "Why" to "Why asks for a reason.", "How" to "How asks about the way or the amount.",
        "Which" to "Which asks us to choose.", "Whose" to "Whose asks who owns something.",
    )
    private val QW_TOPIC = mapOf("Who" to "a person", "What" to "a thing", "Where" to "a place", "When" to "a time", "Why" to "a reason")

    private fun c2QWords(): GenSkill {
        val fr = rows("qwFrames").map { Triple(it[0].s, it[1].s, it[2].ss) }
        val slots = map("qwSlots") + mapOf("name" to names)
        fun fill(f: String, s: Int): String? {
            val m = Regex("\\{(\\w+)}").find(f) ?: return if (s == 0) f else null
            val key = m.groupValues[1]
            val vals = slots[key.lowercase()] ?: slots[key] ?: return null
            val v = vals.getOrNull(s) ?: return null
            return f.replace(m.value, if (key[0].isUpperCase()) cap(v) else v)
        }
        fun tier(a: String) = when (a) { "Who", "What", "Where", "When" -> 1; "Why", "How" -> 2; else -> 3 }
        fun tmpl(tr: Int) = qt("q$tr", tr, fr.size, 20) { s, r ->
            val (f, a, w) = fr[s[0]]
            if (tier(a) != tr) return@qt null
            val p = fill(f, s[1]) ?: return@qt null
            val v = if ("{thing}" in f) slots["thing"]?.getOrNull(s[1])?.let { vis(it) } else null
            ask(p, a, w, QW_WHY[a]!!, r, vis = v)
        }
        return skill(
            "en2.qwords", 2, "Who, what, where?", "?", "grammar",
            tmpl(1), tmpl(2), tmpl(3),
            tft("tf", 2, fr.size, 2) { s, _ ->
                val (f, a, _) = fr[s[0]]
                val topic = QW_TOPIC[a] ?: return@tft null
                val q0 = f.substringBefore("?")
                if ("{" in q0) return@tft null
                val q = q0.replace("___", a) + "?"
                if (s[1] == 0) tf("\"$q\" asks about $topic.", true, QW_WHY[a]!!)
                else {
                    val o = QW_TOPIC.values.filter { it != topic }[s[0] % 4]
                    tf("\"$q\" asks about $o.", false, QW_WHY[a]!!)
                }
            },
        )
    }

    private fun c2Compound(): GenSkill {
        val cs = rows("compounds").map { it[0].s to it[1].s }
        val not = strs("notCompound")
        val made = cs.map { it.first + it.second }.toSet()
        return skill(
            "en2.compound", 2, "Compound words", "+", "words",
            qt("join", 1, cs.size) { s, r ->
                val (a, b) = cs[s[0]]
                val o1 = cs[(s[0] + 7) % cs.size].second; val o2 = cs[(s[0] + 13) % cs.size].first
                ask("$a + $b = ?", a + b, listOf(b + a, a + o1, o2 + b).filter { it !in made }, "${cap(a)} and $b join to make ${a + b}.", r, vis = vis(a + b))
            },
            qt("second", 2, cs.size) { s, r ->
                val (a, b) = cs[s[0]]
                ask("$a + ___ = ${a + b}", b, cs.map { it.second }.filter { it != b }, "${cap(a)} and $b join to make ${a + b}.", r, vis = vis(a + b))
            },
            qt("first", 2, cs.size) { s, r ->
                val (a, b) = cs[s[0]]
                ask("___ + $b = ${a + b}", a, cs.map { it.first }.filter { it != a }, "${cap(a)} and $b join to make ${a + b}.", r, vis = vis(a + b))
            },
            tft("tf", 2, cs.size, 2) { s, _ ->
                val (a, b) = cs[s[0]]
                if (s[1] == 0) tf("${cap(a)} + $b makes ${a + b}.", true, "${cap(a)} and $b join to make ${a + b}.", vis(a + b))
                else {
                    val o = cs.map { it.second }.filter { it != b }.let { it[(s[0] * 3) % it.size] }
                    tf("${cap(a)} + $o makes ${a + b}.", false, "${cap(a)} and $b join to make ${a + b}.")
                }
            },
            qt("which", 3, cs.size) { s, r ->
                val (a, b) = cs[s[0]]
                ask("Which is a compound word?", a + b, not, "${cap(a + b)} is $a and $b joined together.", r)
            },
        )
    }

    private fun alphaWords(maxLvl: Int) = lex.values.filter { it.lvl <= maxLvl && isAlpha(it.w) && it.w.length >= 3 && ("n" in it.pos || "v" in it.pos || "adj" in it.pos) }
        .map { it.w }.distinct().sorted()

    private fun c2Alpha(): GenSkill {
        val ws = alphaWords(2).filter { lex[it]!!.pos.contains("n") }
        val pw = picNouns(2).map { it.w }
        val byL = ws.groupBy { it[0] }.toSortedMap()
        val letters = byL.keys.toList()
        fun pick(k: Int, s: Int): List<String>? {
            val c = comboSeed(letters.size, k, s, 200) ?: return null
            return c.mapIndexed { j, li -> byL[letters[li]]!!.let { it[(s * (j + 3) + j * 7) % it.size] } }
        }
        return skill(
            "en2.alpha", 2, "ABC order of words", "abc", "words",
            ot("order3", 1, gridSize(letters.size, 3, 200)) { s, r ->
                val items = pick(3, s[0]) ?: return@ot null
                orderQ("Put the words in ABC order.", items, "In ABC order: ${items.joinToString(", ")}.", r)
            },
            ot("order4", 2, gridSize(letters.size, 4, 200)) { s, r ->
                val items = pick(4, s[0]) ?: return@ot null
                orderQ("Put the words in ABC order.", items, "In ABC order: ${items.joinToString(", ")}.", r)
            },
            qt("first", 1, ws.size) { s, r ->
                val w = ws[s[0]]
                if (s[0] % 3 != 0) return@qt null
                ask("Which word comes first in ABC order?", w, ws.filter { it[0] > w[0] }, "${cap(w)} starts with ${w[0]}, which comes first.", r)
            },
            qt("picFirst", 2, pw.size) { s, r ->
                val w = pw[s[0]]
                askPic("Which picture's name comes first in ABC order?", w, pw.filter { it[0] > w[0] }, "${cap(w)} starts with ${w[0]}, which comes first.", r)
            },
            qt("picLast", 2, pw.size) { s, r ->
                val w = pw[s[0]]
                askPic("Which picture's name comes last in ABC order?", w, pw.filter { it[0] < w[0] }, "${cap(w)} starts with ${w[0]}, which comes last.", r)
            },
            tft("tf", 3, ws.size, 1) { s, _ ->
                val a = ws[s[0]]
                val b = ws[(s[0] * 7 + s[1] * 31 + 11) % ws.size]
                if (a[0] == b[0]) return@tft null
                val first = if (a[0] < b[0]) a else b
                tf("${cap(a)} comes before $b in ABC order.", a[0] < b[0], "${first[0].uppercaseChar()} comes before ${(if (first == a) b else a)[0].uppercaseChar()} in the ABC.")
            },
        )
    }

    private fun c2SameOpp(): GenSkill = synOpp("en2.sameopp", 2, "Same and opposite", "=", 0, 3, "means the same as", "the opposite of", "Same", "Opposite")

    /** Synonym/antonym skill over levels [lo]..[hi]. */
    private fun synOpp(id: String, grade: Int, title: String, badge: String, lo: Int, hi: Int, sameWords: String, oppWords: String, sameB: String, oppB: String): GenSkill {
        val syn = rows("synEasy").filter { it[2].i in lo..hi }.map { it[0].s to it[1].s }
        val opp = rows("oppPairs").filter { it[2].i in lo..hi }.map { it[0].s to it[1].s }
        val synAll = rows("synEasy").map { it[0].s to it[1].s }
        val oppAll = rows("oppPairs").map { it[0].s to it[1].s } + rows("oppKG").map { it[0].s to it[1].s }
        val synOf = HashMap<String, MutableSet<String>>(); val oppOf = HashMap<String, MutableSet<String>>()
        for ((a, b) in synAll) { synOf.getOrPut(a) { HashSet() } += b; synOf.getOrPut(b) { HashSet() } += a }
        for ((a, b) in oppAll) { oppOf.getOrPut(a) { HashSet() } += b; oppOf.getOrPut(b) { HashSet() } += a }
        val pool = (synAll + oppAll).flatMap { listOf(it.first, it.second) }.distinct()
        fun near(x: String) = setOf(x) + synOf[x].orEmpty() + oppOf[x].orEmpty() + synOf[x].orEmpty().flatMap { oppOf[it].orEmpty() } + oppOf[x].orEmpty().flatMap { synOf[it].orEmpty() }
        val synDirs = syn.flatMap { (a, b) -> listOf(a to b, b to a) }
        val oppDirs = opp.flatMap { (a, b) -> listOf(a to b, b to a) }.filter { (a, _) -> oppOf[a].orEmpty().size == 1 }
        val cards = syn.map { Triple(it.first, it.second, true) } + opp.map { Triple(it.first, it.second, false) }
        val isPlain = sameWords == "means the same as"
        return skill(
            id, grade, title, badge, "words",
            qt("same", 1, synDirs.size) { s, r ->
                val (a, b) = synDirs[s[0]]
                val bad = near(a) + near(b)
                val wr = oppOf[a].orEmpty().toList() + pool.filter { it !in bad }.shuffled(r)
                ask(if (isPlain) "Which word means the same as $a?" else "Which word is a synonym of $a?", b, wr, "${cap(a)} and $b mean the same.", r, keep = true)
            },
            qt("opp", 1, oppDirs.size) { s, r ->
                val (a, b) = oppDirs[s[0]]
                val bad = near(a) + near(b)
                val wr = synOf[a].orEmpty().toList() + pool.filter { it !in bad }.shuffled(r)
                ask(if (isPlain) "What is the opposite of $a?" else "Which word is an antonym of $a?", b, wr, "${cap(a)} is the opposite of $b.", r, keep = true)
            },
            st("sort", 2, cards.size) { s, _ ->
                val (a, b, same) = cards[s[0]]
                sortQ("$a – $b", sameB, oppB, same, if (same) "${cap(a)} and $b mean the same." else "${cap(a)} and $b are opposites.")
            },
            tft("tf", 2, cards.size) { s, _ ->
                val (a, b, same) = cards[s[0]]
                tf("${cap(a)} $sameWords $b.", same, if (same) "${cap(a)} and $b mean the same." else "${cap(a)} and $b are opposites.")
            },
            tft("tfOpp", 3, cards.size) { s, _ ->
                val (a, b, same) = cards[s[0]]
                tf("${cap(a)} is $oppWords $b.", !same, if (same) "${cap(a)} and $b mean the same." else "${cap(a)} and $b are opposites.")
            },
        )
    }

    private fun c2Build(): GenSkill {
        val subs = rows("sbSubj").map { it[0].s }
        val vps = listOf(strs("sbVp3"), strs("sbVp4"), strs("sbVp5"))
        fun tiles(sub: String, vp: String): List<String>? {
            val w = "$sub $vp".split(" ")
            if (w.size !in 3..5 || w.toSet().size != w.size) return null
            return w.dropLast(1) + (w.last() + ".")
        }
        val short = subs.flatMap { sb -> (vps[0] + vps[1]).map { sb to it } }.filter { "$it".length < 60 && "${it.first} ${it.second}.".length <= 24 }
        fun scramble(ws: List<String>, k: Int): String {
            val core = ws.map { it.removeSuffix(".") }
            val p = if (k == 0) core.drop(1) + core.first() else core.reversed()
            return p.mapIndexed { i, x -> if (i == 0) cap(x) else if (x in names || x == "Grandpa") x else x.lowercase() }.joinToString(" ") + "."
        }
        fun ordT(id: String, tier: Int, vi: Int) = ot(id, tier, subs.size, vps[vi].size) { s, r ->
            val tl = tiles(subs[s[0]], vps[vi][s[1]]) ?: return@ot null
            if (tl.size != vi + 3) return@ot null
            orderQ("Make a sentence.", tl, "The sentence is: ${tl.joinToString(" ")}", r)
        }
        return skill(
            "en2.build", 2, "Make a sentence", "Aa.", "writing",
            ordT("order3", 1, 0), ordT("order4", 2, 1), ordT("order5", 3, 2),
            qt("sense", 1, short.size) { s, r ->
                val (sb, vp) = short[s[0]]
                val right = "$sb $vp."
                val ws = right.split(" ")
                ask("Which sentence makes sense?", right, listOf(scramble(ws, 0), scramble(ws, 1)), "The right word order is: $right", r, n = 3)
            },
        )
    }

    // ================================================================ Class 3
    fun c3(): List<GenSkill> = listOf(c3Proper(), c3Adj(), c3IrrPast(), c3Articles(), c3EndPunct(), c3Homophones(), c3Prefix(), c3Suffix(), c3Alpha2(), c3Gender(), c3Collective())

    private fun c3Proper(): GenSkill {
        val pr = rows("proper").map { it[0].s to it[1].s }
        val kinds = strs("commonKinds")
        val commons = (kinds + listOf("town", "village", "school", "teacher", "park", "doctor", "shop") + pureNouns(2).map { it.w }).distinct()
        val cards = pr.map { it.first to true } + commons.map { it to false }
        val firstOfKind = pr.groupBy { it.second }.mapValues { it.value.first().first }
        return skill(
            "en3.proper", 3, "Proper nouns: Delhi", "Aa", "grammar",
            st("sort", 1, cards.size) { s, _ ->
                val (w, p) = cards[s[0]]
                sortQ(w, "Common noun", "Proper noun", !p, if (p) "$w is a special name, so it is a proper noun." else "${cap(w)} is a general word, so it is a common noun.", if (!p) vis(w) else null)
            },
            qt("kind", 1, pr.size) { s, r ->
                val (p, k) = pr[s[0]]
                ask("$p is the name of a ___.", k, kinds - k, "$p is a $k, so it starts with a capital letter.", r)
            },
            qt("which", 2, pr.size) { s, r ->
                val (p, k) = pr[s[0]]
                ask("Which is a proper noun?", p, listOf(k) + commons.shuffled(r), "$p names one special $k, so it is a proper noun.", r, keep = true)
            },
            tft("tf", 2, pr.size, 2) { s, _ ->
                val (p, k) = pr[s[0]]
                if (s[1] == 0) tf("$p is a proper noun.", true, "$p names one special $k.")
                else if (firstOfKind[k] == p) tf("The word $k is a proper noun.", false, "${cap(k)} is a general word, so it is a common noun.") else null
            },
            qt("capital", 3, pr.size) { s, r ->
                val (p, _) = pr[s[0]]
                ask("Which word needs a capital letter?", p.lowercase(), commons, "$p is a special name, so we write it with a capital.", r)
            },
        )
    }

    private val SMALL = setOf("the", "a", "an", "some", "at", "us", "me", "from", "on", "in", "under", "near", "away", "down", "many", "of", "to")

    private fun c3Adj(): GenSkill {
        data class AS(val cat: String, val adjs: List<String>, val nouns: List<String>, val ends: List<String>)
        val sets = rows("adjSets").map { AS(it[0].s, it[1].ss, it[2].ss, it[3].ss.filter { e -> "many" !in e }) }
        val sents = sets.flatMap { a -> a.adjs.flatMap { adj -> a.nouns.flatMap { n -> a.ends.map { e -> Triple(adj, n, e) } } } }
        val pred = rows("adjPred").flatMap { r0 -> r0[1].ss.map { r0[0].s to it } }
        val adjs = pureAdjs(3).map { it.w }
        val others = pureNouns(3).map { it.w } + pureVerbs(3).map { it.w }
        val cards = adjs.map { it to true } + pureNouns(2).map { it.w to false }
        return skill(
            "en3.adjective", 3, "Describing words", "red", "grammar",
            qt("find", 1, sents.size) { s, r ->
                val (a, n, e) = sents[s[0]]
                val content = e.split(" ").filter { it !in SMALL }
                ask("Find the describing word: The $a $n $e.", a, listOf(n) + content, "${cap(a)} tells us about the $n.", r, vis = vis(n))
            },
            qt("pred", 2, pred.size) { s, r ->
                val (n, a) = pred[s[0]]
                ask("Find the describing word: The $n is $a.", a, listOf(n, "is"), "${cap(a)} tells us about the $n.", r, vis = vis(n))
            },
            qt("pick", 2, adjs.size) { s, r ->
                val a = adjs[s[0]]
                ask("Which one is a describing word?", a, others, "${cap(a)} describes a naming word.", r)
            },
            st("sort", 3, cards.size) { s, _ ->
                val (w, adj) = cards[s[0]]
                sortQ(w, "Describing word", "Naming word", adj, if (adj) "${cap(w)} describes a naming word." else "${cap(w)} is a naming word.", if (!adj) vis(w) else null)
            },
        )
    }

    private val IRR_SKIP = setOf("lie", "lay", "sting", "shine", "sink", "freeze", "burst", "spread", "cost", "lead", "light", "hang", "bend",
        "tear", "shoot", "slide", "stick", "set", "let", "become", "understand", "forgive", "have", "do", "get", "put", "hurt", "hit", "shut")
    private val NEEDS_OBJ = setOf("give", "take", "make", "bring", "buy", "tell", "find", "keep", "hold", "wear", "send", "lend", "meet", "feed",
        "say", "catch", "break", "steal", "bite", "throw", "build", "sell", "teach", "cut", "choose", "lose", "spend", "pay", "hear", "see", "lay", "dig", "ring", "shake", "hide", "blow", "leave", "feel")

    private fun regPast(v: String): String = when {
        v.endsWith("e") -> v + "d"
        v.endsWith("y") && v.length > 1 && v[v.length - 2] !in VOWELS -> v.dropLast(1) + "ied"
        v.length == 3 && v[1] in VOWELS && v[0] !in VOWELS && v[2] !in VOWELS + "wxy" -> v + v.last() + "ed"
        else -> v + "ed"
    }

    private fun irrVerbs(maxLvl: Int) = lex.values.filter { "v" in it.pos && it.irr && it.lvl <= maxLvl && isAlpha(it.w) && it.w !in IRR_SKIP }.sortedBy { it.w }

    private fun c3IrrPast(): GenSkill {
        val vs = irrVerbs(4)
        val objs = rows("tenseVp").associate { it[0].s to it[1].s }
        val pastCount = vs.groupingBy { it.past }.eachCount()
        fun why(v: EnWord) = if (v.past == v.w) "${cap(v.w)} stays ${v.w} in the past." else "${cap(v.w)} changes to ${v.past}, not ${regPast(v.w)}."
        return skill(
            "en3.irrpast", 3, "Past tense: went, ate", "went", "grammar",
            qt("frame", 1, vs.size) { s, r ->
                val v = vs[s[0]]
                val o = objs[v.w]
                val p = when {
                    o != null -> "Today I ${v.w} $o. Yesterday I ___ $o."
                    v.w in NEEDS_OBJ -> return@qt null
                    else -> "Today I ${v.w}. Yesterday I ___."
                }
                ask(p, v.past!!, listOf(regPast(v.w), v.pp!!, v.s3!!, v.past + "ed"), why(v), r)
            },
            tft("tf", 2, vs.size, 3) { s, _ ->
                val v = vs[s[0]]
                when (s[1]) {
                    0 -> tf("The past of ${v.w} is ${v.past}.", true, why(v))
                    1 -> if (regPast(v.w) == v.past) null else tf("The past of ${v.w} is ${regPast(v.w)}.", false, why(v))
                    else -> if (v.pp == v.past) null else tf("The past of ${v.w} is ${v.pp}.", false, "${cap(v.pp!!)} needs has or had; the past is ${v.past}.")
                }
            },
            qt("reverse", 3, vs.size) { s, r ->
                val v = vs[s[0]]
                if (pastCount[v.past]!! > 1 || v.past == v.w) return@qt null
                val wr = vs.filter { it.w != v.w && it.past != v.past }.sortedBy { if (it.w[0] == v.w[0]) 0 else 1 }.map { it.w }
                ask("${cap(v.past!!)} is the past of which word?", v.w, wr.take(6).shuffled(r) + wr.shuffled(r), "${cap(v.past)} is the past of ${v.w}.", r, keep = true)
            },
        )
    }

    private fun c3Articles(): GenSkill {
        val the = strs("theFrames")
        val sets = rows("adjSets").filter { it[0].s in setOf("animal", "thing", "fruit") }
        val combos = sets.flatMap { r0 -> r0[2].ss.flatMap { n -> r0[1].ss.map { a -> a to n } } }
        val tricky = rows("anTricky")
        return skill(
            "en3.articles", 3, "A, an or the", "the", "grammar",
            qt("the", 1, the.size) { s, r ->
                val f = the[s[0]]
                val start = f.startsWith("___")
                val o = if (start) listOf("The", "A", "An") else listOf("the", "a", "an")
                ask(f, o[0], o.drop(1), "We use the for one special or known thing.", r, n = 3)
            },
            qt("first", 1, combos.size) { s, r ->
                val (a, n) = combos[s[0]]
                val an = a[0] in VOWELS
                ask("I have ___ $a $n.", if (an) "an" else "a", listOf(if (an) "a" else "an"), anEx(a, an), r, vis = vis(n))
            },
            qt("again", 2, combos.size) { s, r ->
                val (a, n) = combos[s[0]]
                ask("I saw ${art(n)} $n. ___ $n was $a.", "The", listOf("A", "An"), "We use the when we talk about it again.", r, n = 3, vis = vis(n))
            },
            qt("tricky", 3, tricky.size) { s, r ->
                val p = tricky[s[0]][0].s; val ans = tricky[s[0]][1].s
                val first = p.split(" ")[0]
                ask("___ $p", ans, listOf(if (ans == "an") "a" else "an"), anEx(first, ans == "an"), r, vis = vis(p))
            },
        )
    }

    private fun genStatements(): List<String> {
        val preds = strs("capPred")
        return preds.flatMapIndexed { p, pr -> (0 until 3).map { k -> "${names[(p * 3 + k + 1) % names.size]} $pr." } }
    }

    private fun genQuestions(): List<String> = strs("qgen").flatMapIndexed { i, f -> (0 until 8).map { k -> f.replace("{n}", names[(i * 2 + k) % names.size]) + "?" } }

    private fun genExclaims(): List<String> = rows("adjSets").flatMap { r0 -> r0[1].ss.take(4).flatMap { a -> r0[2].ss.take(3).map { n -> "What ${art(a)} $a $n!" } } }

    private val MARKS = listOf("Full stop (.)", "Question mark (?)", "Exclamation mark (!)")
    private fun markWhy(m: Char) = when (m) {
        '.' -> "It tells us something, so it needs a full stop."
        '?' -> "It asks something, so it needs a question mark."
        else -> "It shows strong feeling, so it needs an exclamation mark."
    }

    private fun c3EndPunct(): GenSkill {
        val gen = genStatements() + genQuestions()
        val cur = strs("statements") + strs("questions") + strs("exclaims") + genExclaims()
        return skill(
            "en3.endpunct", 3, "Full stop, ? or !", "?!", "writing",
            st("sort", 1, gen.size) { s, _ ->
                val x = gen[s[0]]
                sortQ(x.dropLast(1), MARKS[0], MARKS[1], x.last() == '.', markWhy(x.last()))
            },
            qt("mark", 2, cur.size) { s, r ->
                val x = cur[s[0]]
                val ans = MARKS["..?!".indexOf(x.last()).let { if (it <= 1) 0 else it - 1 }]
                ask("Which mark ends this? ${x.dropLast(1)}", ans, MARKS - ans, markWhy(x.last()), r, n = 3)
            },
            qt("genMark", 1, gen.size) { s, r ->
                if (s[0] % 2 == 0) return@qt null
                val x = gen[s[0]]
                val ans = if (x.last() == '.') MARKS[0] else MARKS[1]
                ask("Which mark ends this? ${x.dropLast(1)}", ans, MARKS - ans, markWhy(x.last()), r, n = 3)
            },
        )
    }

    private fun c3Homophones(): GenSkill {
        val sets = t["homophones"]!!.jsonArray.map { it.jsonObject }
        data class HF(val set: Int, val word: String, val frame: String)
        val words = sets.map { it["words"]!!.ss }
        val fr = sets.flatMapIndexed { i, o -> o["frames"]!!.jsonArray.flatMap { wf -> wf.jsonArray[1].ss.map { f -> HF(i, wf.jsonArray[0].s, f) } } }
        val withFrames = sets.map { o -> o["frames"]!!.jsonArray.filter { it.jsonArray[1].jsonArray.isNotEmpty() }.map { it.jsonArray[0].s } }
        val allW = words.flatten()
        fun fit(f: String, w: String) = if (f.startsWith("___")) cap(w) else w
        return skill(
            "en3.homophones", 3, "Sea or see?", "sea", "words",
            qt("frame1", 1, fr.size) { s, r ->
                val h = fr[s[0]]
                if (h.set >= 15) return@qt null
                val others = words[h.set] - h.word
                ask(h.frame, fit(h.frame, h.word), others.map { fit(h.frame, it) }, "Here we need ${h.word}, not ${others.joinToString(" or ")}.", r)
            },
            qt("frame2", 2, fr.size) { s, r ->
                val h = fr[s[0]]
                if (h.set < 15) return@qt null
                val others = words[h.set] - h.word
                ask(h.frame, fit(h.frame, h.word), others.map { fit(h.frame, it) }, "Here we need ${h.word}, not ${others.joinToString(" or ")}.", r)
            },
            qt("sounds", 2, sets.size, 3) { s, r ->
                val w = withFrames[s[0]].getOrNull(s[1]) ?: return@qt null
                val o = (words[s[0]] - w).firstOrNull() ?: return@qt null
                ask("Which word sounds like $w?", o, allW.filter { it !in words[s[0]] }, "${cap(w)} and $o sound the same but mean different things.", r, vis = vis(w))
            },
            tft("tf", 3, sets.size, 2) { s, _ ->
                val ws = words[s[0]]
                val a = ws[0]
                if (s[1] == 0) tf("${cap(a)} and ${ws[1]} sound the same.", true, "${cap(a)} and ${ws[1]} sound the same but mean different things.")
                else {
                    val x = words[(s[0] + 3) % words.size][0]
                    tf("${cap(a)} and $x sound the same.", false, "${cap(a)} sounds like ${ws[1]}, not $x.")
                }
            },
        )
    }

    private fun c3Prefix(): GenSkill {
        data class P(val word: String, val pre: String, val base: String, val mean: String, val wrong: List<String>)
        val ps = rows("prefix").map { P(it[0].s, it[1].s, it[2].s, it[3].s, it[4].ss) }
        val means = ps.map { it.mean }.toSet()
        fun wrongMeans(p: P) = listOfNotNull(
            if (p.pre != "re") "${p.base} again" else null,
            if (p.mean != "not ${p.base}") "not ${p.base}" else null,
            if (p.pre != "mis") "${p.base} wrongly" else null,
            if (p.pre != "pre") "${p.base} before" else null,
        ).filter { it != p.mean }
        return skill(
            "en3.prefix", 3, "un-, re-, dis-", "un", "words",
            qt("toWord", 1, ps.size) { s, r ->
                val p = ps[s[0]]
                ask("Which word means '${p.mean}'?", p.word, p.wrong, "${cap(p.word)} means ${p.mean}.", r)
            },
            qt("toMean", 2, ps.size) { s, r ->
                val p = ps[s[0]]
                ask("What does '${p.word}' mean?", p.mean, wrongMeans(p), "${cap(p.pre)}- + ${p.base} means ${p.mean}.", r)
            },
            tft("tf", 2, ps.size, 2) { s, _ ->
                val p = ps[s[0]]
                if (s[1] == 0) tf("${cap(p.word)} means ${p.mean}.", true, "${cap(p.word)} means ${p.mean}.")
                else wrongMeans(p).firstOrNull()?.let { tf("${cap(p.word)} means $it.", false, "${cap(p.word)} means ${p.mean}.") }
            },
            qt("pick", 3, ps.size) { s, r ->
                val p = ps[s[0]]
                val pres = p.wrong.map { it.removeSuffix(p.base) }.filter { it.isNotEmpty() }.distinct()
                ask("Which prefix makes '${p.mean}'? ___${p.base}", p.pre, pres, "${cap(p.pre)} + ${p.base} makes ${p.word}.", r)
            },
        )
    }

    private val FUL_SKIP = setOf("thank", "forget", "duty", "mercy")
    private val ER_SKIP = setOf("sail", "direct")

    private fun c3Suffix(): GenSkill {
        val fl = rows("fulLess").map { Triple(it[0].s, it[1].s, it[2].s) }.filter { it.first !in FUL_SKIP }
        val ful = fl.filter { it.second.isNotEmpty() }; val less = fl.filter { it.third.isNotEmpty() }
        val both = fl.filter { it.second.isNotEmpty() && it.third.isNotEmpty() }
        val frames = rows("fulFrames").map { Triple(it[0].s, it[1].s, it[2].s) }
        val er = rows("erDoer").map { it[0].s to it[1].s }.filter { it.first !in ER_SKIP }
        val doers = er.map { it.second }
        return skill(
            "en3.suffix", 3, "-ful, -less, -er", "ful", "words",
            qt("ful", 1, ful.size) { s, r ->
                val (b, f, l) = ful[s[0]]
                ask("Which word means 'full of $b'?", f, listOf(l.ifEmpty { b + "less" }, b + "ness", b + "ly"), "${cap(f)} means full of $b.", r)
            },
            qt("less", 1, less.size) { s, r ->
                val (b, f, l) = less[s[0]]
                ask("Which word means 'without $b'?", l, listOf(f.ifEmpty { b + "ful" }, b + "ness", b + "ly"), "${cap(l)} means without $b.", r)
            },
            qt("opp", 2, both.size) { s, r ->
                val (b, f, l) = both[s[0]]
                ask("What is the opposite of $f?", l, listOf(b, b + "ness") + both.map { it.third }.shuffled(r), "${cap(f)} and $l are opposites.", r, keep = true)
            },
            qt("frame", 2, frames.size) { s, r ->
                val (f, a, w) = frames[s[0]]
                ask(f, a, listOf(w, frames[(s[0] + 5) % frames.size].second), "Here we need $a, not $w.", r, n = 3, keep = true)
            },
            qt("er", 2, er.size) { s, r ->
                val (v, d) = er[s[0]]
                ask("One who ${s3(v)} is a ___.", d, listOf(v + "or", v + "ist", v + "er", v + "man").filter { it != d }, "One who ${s3(v)} is ${art(d)} $d.", r)
            },
            qt("erBack", 3, er.size) { s, r ->
                val (v, d) = er[s[0]]
                ask("What does ${art(d)} $d do?", s3(v), er.map { s3(it.first) }.filter { it != s3(v) }, "${cap(art(d))} $d ${s3(v)}.", r)
            },
            tft("erTf", 3, er.size, 2) { s, _ ->
                val (v, d) = er[s[0]]
                if (s[1] == 0) tf("${cap(art(d))} $d is one who ${s3(v)}.", true, "One who ${s3(v)} is ${art(d)} $d.")
                else { val o = er[(s[0] + 4) % er.size].first; tf("${cap(art(d))} $d is one who ${s3(o)}.", false, "One who ${s3(v)} is ${art(d)} $d.") }
            },
            tft("tf", 3, both.size, 2) { s, _ ->
                val (b, f, l) = both[s[0]]
                if (s[1] == 0) tf("${cap(f)} means without $b.", false, "${cap(f)} means full of $b; $l means without $b.")
                else tf("${cap(l)} means without $b.", true, "${cap(l)} means without $b.")
            },
        )
    }

    private fun c3Alpha2(): GenSkill {
        val ws = alphaWords(4)
        val by1 = ws.groupBy { it[0] }.mapValues { (_, l) -> l.groupBy { it[1] }.toSortedMap() }.toSortedMap()
        val by2 = ws.filter { it.length >= 3 }.groupBy { it.take(2) }.mapValues { (_, l) -> l.groupBy { it[2] }.toSortedMap() }.toSortedMap()
        fun pickSet(m: Map<out Any, Map<Char, List<String>>>, k: Int, s: Int): List<String>? {
            val keys = m.keys.filter { m[it]!!.size >= k }
            if (keys.isEmpty()) return null
            val key = keys[s % keys.size]
            val groups = m[key]!!.values.toList()
            val c = comboSeed(groups.size, k, s / keys.size, 5000) ?: return null
            return c.mapIndexed { j, gi -> groups[gi].let { it[(s + j * 5) % it.size] } }
        }
        return skill(
            "en3.alpha2", 3, "ABC order: 2nd letter", "ab", "words",
            ot("second3", 1, 400) { s, r ->
                val items = pickSet(by1, 3, s[0]) ?: return@ot null
                orderQ("Put the words in ABC order.", items, "Look at the second letter: ${items.joinToString(", ")}.", r)
            },
            ot("second4", 2, 400) { s, r ->
                val items = pickSet(by1, 4, s[0]) ?: return@ot null
                orderQ("Put the words in ABC order.", items, "Look at the second letter: ${items.joinToString(", ")}.", r)
            },
            ot("third3", 3, 300) { s, r ->
                val items = pickSet(by2, 3, s[0]) ?: return@ot null
                orderQ("Put the words in ABC order.", items, "Look at the third letter: ${items.joinToString(", ")}.", r)
            },
            qt("first", 1, ws.size) { s, r ->
                val w = ws[s[0]]
                if (w.length < 2) return@qt null
                ask("Which word comes first in ABC order?", w, ws.filter { it[0] == w[0] && it.length > 1 && it[1] > w[1] }, "Both start with ${w[0]}, so look at the second letter.", r)
            },
            qt("last", 3, ws.size) { s, r ->
                val w = ws[s[0]]
                if (w.length < 3) return@qt null
                ask("Which word comes last in ABC order?", w, ws.filter { it.length > 2 && it.take(2) == w.take(2) && it[2] < w[2] }, "They start with ${w.take(2)}, so look at the third letter.", r)
            },
        )
    }

    private val GENERIC = setOf("lion", "tiger", "fox", "duck", "goose", "dog", "actor", "waiter", "host", "hero", "god", "landlord", "cow", "policeman", "wizard")

    private fun c3Gender(): GenSkill {
        val g = rows("gender").map { it[0].s to it[1].s }
        val males = g.map { it.first }; val females = g.map { it.second }
        val cards = g.flatMap { (m, f) -> listOf(m to true, f to false) }.filter { it.first !in GENERIC }
        return skill(
            "en3.gender", 3, "Lion and lioness", "m/f", "words",
            qt("female", 1, g.size) { s, r ->
                val (m, f) = g[s[0]]
                ask("The female of $m is ___.", f, females - f + (m + "ess"), "The female of $m is $f.", r)
            },
            qt("male", 1, g.size) { s, r ->
                val (m, f) = g[s[0]]
                ask("The male of $f is ___.", m, males - m, "The male of $f is $m.", r)
            },
            tft("tf", 2, g.size, 2) { s, _ ->
                val (m, f) = g[s[0]]
                if (s[1] == 0) tf("${cap(f)} is the female of $m.", true, "The female of $m is $f.")
                else { val o = males[(s[0] + 7) % males.size]; tf("${cap(f)} is the female of $o.", false, "The female of $m is $f.") }
            },
            st("sort", 2, cards.size) { s, _ ->
                val (w, male) = cards[s[0]]
                sortQ(w, "Male", "Female", male, "${cap(w)} is ${if (male) "male" else "female"}.", vis(w))
            },
        )
    }

    private fun c3Collective(): GenSkill {
        val cs = rows("collective").map { Triple(it[0].s, it[1].s, it[2].ss) }
        val valid = HashMap<String, MutableSet<String>>()
        for ((c, n, ok) in cs) valid.getOrPut(n) { HashSet() }.apply { add(c); addAll(ok) }
        val colls = cs.map { it.first }.distinct()
        val nouns = cs.map { it.second }.distinct()
        val firstRow = cs.indices.filter { i -> cs.indexOfFirst { it.second == cs[i].second } == i }.toSet()
        val animalC = setOf("herd", "flock", "swarm", "pride", "pack", "school", "shoal", "litter", "troop", "colony", "brood", "caravan")
        val peopleC = setOf("team", "crowd", "army", "class", "choir", "band", "gang", "crew", "staff", "panel", "audience")
        fun cls(c: String) = if (c in animalC) 0 else if (c in peopleC) 1 else 2
        val mainC = cs.groupBy { it.second }.mapValues { cls(it.value.first().first) }
        fun wrongC(n: String) = colls.filter { it !in valid[n]!! && it != "group" && (cls(it) != mainC[n] || mainC[n] == 0) && !(mainC[n] == 0 && it == "pack") }
        return skill(
            "en3.collective", 3, "A herd of cows", "herd", "words",
            qt("coll", 1, cs.size) { s, r ->
                val (c, n, _) = cs[s[0]]
                ask("A ___ of $n", c, wrongC(n), "We say ${art(c)} $c of $n.", r, vis = vis(n))
            },
            qt("noun", 2, cs.size) { s, r ->
                val (c, n, _) = cs[s[0]]
                ask("A $c of ___", n, nouns.filter { c !in valid[it]!! && (mainC[it] != cls(c) || cls(c) == 0) }, "We say ${art(c)} $c of $n.", r)
            },
            tft("tf", 2, cs.size, 3) { s, _ ->
                val (c, n, _) = cs[s[0]]
                if (s[1] == 0) tf("We say ${art(c)} $c of $n.", true, "We say ${art(c)} $c of $n.", vis(n))
                else {
                    if (s[0] !in firstRow) return@tft null
                    val w = wrongC(n); val x = w[(s[0] * 3 + s[1] * 7) % w.size]
                    val good = c
                    tf("We say ${art(x)} $x of $n.", false, "We say ${art(good)} $good of $n.", vis(n))
                }
            },
        )
    }

    // ================================================================ Class 4
    fun c4(): List<GenSkill> = listOf(c4SubjVerb(), c4Tenses(), c4Adverb(), c4Degrees(),
        synOpp("en4.synant", 4, "Synonyms, antonyms", "syn", 2, 5, "is a synonym of", "an antonym of", "Synonyms", "Antonyms"),
        c4Possessive(), c4Contract(), c4Syllables(), c4Dictionary(), c4SentType())

    private fun c4SubjVerb(): GenSkill {
        val subs = rows("svSubj").map { it[0].s to it[1].s }
        val vps = rows("svVp").map { it[0].s to it[1].s }
        val tricky = rows("svTricky").map { Triple(it[0].s, it[1].s, it[2].s) }
        fun parts(i: Int, k: String): Triple<String, String, String> {
            val (b, s3p) = vps[i]
            val rest = b.substringAfter(" ", "")
            val bv = b.substringBefore(" "); val sv = s3p.substringBefore(" ")
            return if (k == "3s") Triple(sv, bv, rest) else Triple(bv, sv, rest)
        }
        return skill(
            "en4.subjverb", 4, "He runs, they run", "s", "grammar",
            qt("present", 1, subs.size, vps.size) { s, r ->
                val (sub, k) = subs[s[0]]
                val (right, wrong, rest) = parts(s[1], k)
                ask("$sub ___ $rest.", right, listOf(wrong, ingOf(vps[s[1]].first.substringBefore(" "))), "We say ${lowSubj(sub)} $right $rest.", r, n = 3)
            },
            qt("negative", 2, subs.size, vps.size) { s, r ->
                val (sub, k) = subs[s[0]]
                val b = vps[s[1]].first
                val right = if (k == "3s") "doesn't" else "don't"
                ask("$sub ___ $b.", right, listOf(if (k == "3s") "don't" else "doesn't", "isn't"), "With ${lowSubj(sub)}, we say $right.", r, n = 3)
            },
            tft("tf", 2, subs.size, vps.size) { s, _ ->
                val (sub, k) = subs[s[0]]
                val (right, wrong, rest) = parts(s[1], k)
                val ok = (s[0] + s[1]) % 2 == 0
                tf("\"$sub ${if (ok) right else wrong} $rest.\" is a correct sentence.", ok, "We say ${lowSubj(sub)} $right $rest.")
            },
            qt("tricky", 3, tricky.size) { s, r ->
                val (f, a, w) = tricky[s[0]]
                val one = a in setOf("is", "has", "was") || (a.endsWith("s") && a != "are")
                ask(f, a, listOf(w), if (one) "The subject here is one, so we use $a." else "The subject here is more than one, so we use $a.", r)
            },
        )
    }

    private fun pres(k: String, v: String) = if (k == "3s") s3(v) else if (v == "be") (if (k == "I") "am" else "are") else v

    private fun c4Tenses(): GenSkill {
        val subs = rows("tenseSubj").map { it[0].s to it[1].s }
        val vps = rows("tenseVp").map { it[0].s to it[1].s }
        fun low(x: String) = lowSubj(x)
        val tenses = listOf("Past", "Present", "Future")
        return skill(
            "en4.tenses", 4, "Past, present, future", "then", "grammar",
            qt("future", 1, subs.size, vps.size) { s, r ->
                val (sub, k) = subs[s[0]]; val (v, o) = vps[s[1]]
                ask("Tomorrow, ${low(sub)} ___ $o. ($v)", "will $v", listOf(pastOf(v), pres(k, v)), "Tomorrow is the future, so we say will $v.", r, n = 3)
            },
            qt("present", 1, subs.size, vps.size) { s, r ->
                val (sub, k) = subs[s[0]]; val (v, o) = vps[s[1]]
                val p = pres(k, v); val wrongAg = if (k == "3s") v else s3(v)
                ask("Every day, ${low(sub)} ___ $o. ($v)", p, listOf(wrongAg, ingOf(v)), "Every day shows the present: ${low(sub)} $p.", r, n = 3)
            },
            qt("past", 2, subs.size, vps.size) { s, r ->
                val (sub, k) = subs[s[0]]; val (v, o) = vps[s[1]]
                val p = pastOf(v)
                val wr = listOf("will $v", pres(k, v)) + (if (lex[v]?.irr == true && regPast(v) != p) listOf(regPast(v)) else emptyList())
                ask("Yesterday, ${low(sub)} ___ $o. ($v)", p, wr, if (lex[v]?.irr == true) "Yesterday shows the past: $v becomes $p." else "Yesterday shows the past, so we say $p.", r)
            },
            st("sort", 2, subs.size, vps.size, 2) { s, _ ->
                val (sub, _) = subs[s[0]]; val (v, o) = vps[s[1]]
                if (s[2] == 0) sortQ("Last week, ${low(sub)} ${pastOf(v)} $o.", "Past", "Future", true, "${cap(pastOf(v))} shows the past.")
                else sortQ("Next week, ${low(sub)} will $v $o.", "Past", "Future", false, "Will shows the future.")
            },
            qt("name", 3, subs.size, vps.size, 3) { s, r ->
                val (sub, k) = subs[s[0]]; val (v, o) = vps[s[1]]
                val (sent, why) = when (s[2]) {
                    0 -> "$sub ${pastOf(v)} $o." to "${cap(pastOf(v))} shows the past."
                    1 -> "$sub ${pres(k, v)} $o every day." to "${cap(pres(k, v))} shows the present."
                    else -> "$sub will $v $o." to "Will shows the future."
                }
                if (s[2] == 0 && pastOf(v) == v) return@qt null
                ask("Which tense is this? $sent", tenses[s[2]], tenses - tenses[s[2]], why, r, n = 3)
            },
        )
    }

    private fun adverb(a: String): String = when {
        a == "good" -> "well"
        a == "true" -> "truly"
        a == "fast" || a == "hard" -> a
        a.endsWith("le") -> a.dropLast(1) + "y"
        a.endsWith("y") && a.length > 2 && a[a.length - 2] !in VOWELS -> a.dropLast(1) + "ily"
        else -> a + "ly"
    }

    private fun advWhy(a: String, d: String) = when {
        a == "good" -> "The how word for good is well."
        a.endsWith("le") -> "Drop the e and add y: $d."
        a.endsWith("y") && d.endsWith("ily") -> "Change y to i and add ly: $d."
        else -> "Add ly to $a: $d."
    }

    private fun c4Adverb(): GenSkill {
        val sents = rows("advSent").flatMap { r0 -> r0[3].ss.map { listOf(r0[0].s, r0[1].s, r0[2].s, it) } }
        val forms = strs("advForm")
        val irr = rows("advIrr").map { it.ss }
        val cards = forms.filter { adverb(it) != it }.flatMap { listOf(it to true, adverb(it) to false) }
        return skill(
            "en4.adverb", 4, "How words: slowly", "-ly", "grammar",
            qt("find", 1, sents.size) { s, r ->
                val (sub, v, o, a) = sents[s[0]]
                ask("Which word tells how? $sub $v $o $a.", a, listOf(v, o.split(" ").last(), sub.split(" ").last()), "${cap(a)} tells us how ${lowSubj(sub)} $v.", r)
            },
            qt("form", 1, forms.size) { s, r ->
                val a = forms[s[0]]; val d = adverb(a)
                ask("Make a how word from $a.", d, listOf(a + "ly", a, a + "ely", lex[a]?.comp ?: (a + "er")).filter { it != d }, advWhy(a, d), r)
            },
            tft("tf", 2, forms.size, 2) { s, _ ->
                val a = forms[s[0]]; val d = adverb(a)
                if (s[1] == 0) tf("The how word for $a is $d.", true, advWhy(a, d))
                else (if (a + "ly" != d) a + "ly" else a + "ely").let { w -> tf("The how word for $a is $w.", false, advWhy(a, d)) }
            },
            st("sort", 2, cards.size) { s, _ ->
                val (w, adj) = cards[s[0]]
                sortQ(w, "Describing word", "How word", adj, if (adj) "${cap(w)} describes a naming word." else "${cap(w)} tells us how something is done.")
            },
            qt("irr", 3, irr.size, 3) { s, r ->
                val (doer, verb, adv, wrong) = irr[s[0]]
                val n = names[(s[0] * 3 + s[1]) % names.size]
                val adjW = doer.split(" ")[1]
                val why = when (adv) { "well" -> "The how word for good is well."; "fast", "hard" -> "${cap(adv)} stays $adv as a how word."; else -> "${cap(adv)} tells us how $n $verb." }
                ask("$n is $doer. $n $verb ___.", adv, listOf(wrong, adjW, lex[adjW]?.comp ?: "more $adjW"), why, r)
            },
        )
    }

    private fun degreeAdjs() = lex.values.filter { "adj" in it.pos && it.comp != null && it.sup != null && it.compRule != null && it.compRule != "both" &&
        it.lvl <= 4 && isAlpha(it.w) && it.w !in setOf("little", "many", "much", "far") }.sortedBy { it.w }

    private fun naiveComp(a: EnWord): List<String> {
        val w = a.w
        val c = mutableListOf<String>()
        if (a.compRule != "er") c += w + "er"
        if (a.compRule != "more") c += "more $w"
        if (a.compRule == "er") c += w + w.last() + "er"
        if (a.compRule == "irr") c += "more ${a.comp}"
        return c.filter { it != a.comp }.distinct()
    }

    private fun naiveSup(a: EnWord): List<String> {
        val w = a.w
        val c = mutableListOf<String>()
        if (a.compRule != "er") c += w + "est"
        if (a.compRule != "more") c += "most $w"
        if (a.compRule == "er") c += w + w.last() + "est"
        if (a.compRule == "irr") c += "most ${a.sup}"
        return c.filter { it != a.sup }.distinct()
    }

    private fun degWhy(a: EnWord) = when (a.compRule) {
        "r" -> "${cap(a.w)} ends in e, so add r and st: ${a.comp}, ${a.sup}."
        "double" -> "Double the last letter: ${a.comp}, ${a.sup}."
        "ier" -> "Change y to i: ${a.comp}, ${a.sup}."
        "more" -> "Long words use more and most: ${a.comp}."
        "irr" -> "${cap(a.w)} changes: ${a.comp}, ${a.sup}."
        else -> "Add er and est: ${a.comp}, ${a.sup}."
    }

    private fun c4Degrees(): GenSkill {
        val adjs = degreeAdjs()
        val sortable = adjs.filter { it.compRule != "irr" }
        return skill(
            "en4.degrees", 4, "Big, bigger, biggest", "-er", "grammar",
            qt("comp", 1, adjs.size) { s, r ->
                val a = adjs[s[0]]
                ask("${a.w}, ___, ${a.sup}", a.comp!!, naiveComp(a) + a.w, degWhy(a), r)
            },
            qt("sup", 1, adjs.size) { s, r ->
                val a = adjs[s[0]]
                ask("${a.w}, ${a.comp}, ___", a.sup!!, naiveSup(a) + a.w, degWhy(a), r)
            },
            qt("than", 2, adjs.size) { s, r ->
                val a = adjs[s[0]]
                ask("This one is ___ than that one. (${a.w})", a.comp!!, listOf(a.sup!!, a.w) + naiveComp(a), "Than compares two things, so we use ${a.comp}.", r)
            },
            qt("most", 2, adjs.size) { s, r ->
                val a = adjs[s[0]]
                ask("This is the ___ of all. (${a.w})", a.sup!!, listOf(a.comp!!, a.w) + naiveSup(a), "Of all compares many, so we use ${a.sup}.", r)
            },
            st("sort", 3, sortable.size) { s, _ ->
                val a = sortable[s[0]]
                sortQ(a.w, "-er, -est", "more, most", a.compRule != "more", degWhy(a))
            },
            tft("tf", 3, adjs.size, 2) { s, _ ->
                val a = adjs[s[0]]
                if (s[1] == 0) tf("${cap(a.w)}, ${a.comp}, ${a.sup} is right.", true, degWhy(a))
                else naiveComp(a).firstOrNull()?.let { c -> tf("${cap(a.w)}, $c, ${naiveSup(a).first()} is right.", false, degWhy(a)) }
            },
        )
    }

    private fun c4Possessive(): GenSkill {
        val items = listOf("bag", "book", "kite", "room", "pen", "ball", "toys", "cap")
        data class Own(val det: String, val core: String, val kind: Int)
        val sing = names.take(10).map { Own("", it, 0) } + listOf("my sister", "the boy", "the teacher", "the cat", "my friend").map { Own(it.substringBefore(" ") + " ", it.substringAfter(" "), 0) }
        val plural = listOf("the girls", "the boys", "my friends", "the birds", "the players", "the cats", "the teachers", "the dogs", "the farmers", "my cousins", "the doctors")
            .map { Own(it.substringBefore(" ") + " ", it.substringAfter(" "), 1) }
        val irr = listOf("the children", "the men", "the women", "the people").map { Own(it.substringBefore(" ") + " ", it.substringAfter(" "), 2) }
        fun q(o: Own, item: String, r: Random): Question? {
            val ans = if (o.kind == 1) o.core + "'" else o.core + "'s"
            val wr = when (o.kind) {
                0 -> listOf(o.core + "s", o.core + "s'", o.core)
                1 -> listOf(o.core.dropLast(1) + "'s", o.core, o.core + "'s")
                else -> listOf(o.core + "s'", o.core + "s", o.core + "'")
            }
            val plIt = item.endsWith("s")
            val owner = o.det + o.core
            val p = "The $item ${if (plIt) "belong" else "belongs"} to $owner. ${if (plIt) "They are" else "It is"} ${o.det}___ $item."
            val why = when (o.kind) {
                0 -> "For one owner, add 's: $ans."
                1 -> "The owners already end in s, so add only ': $ans."
                else -> "${cap(o.core)} has no s, so add 's: $ans."
            }
            return ask(p, ans, wr, why, r, vis = vis(item))
        }
        return skill(
            "en4.possessive", 4, "Riya's, the boys'", "'s", "grammar",
            qt("one", 1, sing.size, items.size) { s, r -> q(sing[s[0]], items[s[1]], r) },
            qt("many", 2, plural.size, items.size) { s, r -> q(plural[s[0]], items[s[1]], r) },
            qt("irregular", 3, irr.size, items.size) { s, r -> q(irr[s[0]], items[s[1]], r) },
        )
    }

    private fun c4Contract(): GenSkill {
        val cs = rows("contract").map { Triple(it[0].s, it[1].s, it[2].ss) }
        val full = cs.associate { it.second.lowercase() to it.first }
        val frames = rows("contractFrames").map { Triple(it[0].s, it[1].s, it[2].s) }
        val back = cs.filter { !(it.second.endsWith("'s") && it.second != "let's") && !it.second.endsWith("'d") }
        fun why(f: String, sh: String) = when (sh) {
            "won't" -> "Will not becomes won't."
            "can't" -> "Cannot becomes can't."
            else -> "${cap(f)} becomes $sh; the ' shows the missing letters."
        }
        return skill(
            "en4.contract", 4, "Short forms: don't", "n't", "writing",
            qt("short", 1, cs.size) { s, r ->
                val (f, sh, w) = cs[s[0]]
                ask("What is the short form of $f?", sh, w + cs.filter { it.first.substringBefore(" ") == f.substringBefore(" ") && it.second != sh }.map { it.second }, why(f, sh), r)
            },
            tft("spellTf", 1, cs.size, 3) { s, _ ->
                val (f, sh, w) = cs[s[0]]
                if (s[1] == 0) tf("The short form of $f is $sh.", true, why(f, sh))
                else w.getOrNull(s[1] - 1)?.let { tf("The short form of $f is $it.", false, why(f, sh)) }
            },
            qt("full", 2, back.size) { s, r ->
                val (f, sh, _) = back[s[0]]
                ask("What is $sh short for?", f, cs.map { it.first }.filter { it.substringBefore(" ") == f.substringBefore(" ") || it.substringAfter(" ") == f.substringAfter(" ") }, "${cap(sh)} is short for $f.", r)
            },
            qt("frame", 2, frames.size) { s, r ->
                val (fr, a, w) = frames[s[0]]
                val why = if ("'" in a) "${cap(a)} is short for ${full[a.lowercase()] ?: "two words"}." else "${cap(a)} shows who something belongs to."
                ask(fr, a, listOf(w), why, r)
            },
            tft("fullTf", 3, back.size, 2) { s, _ ->
                val (f, sh, _) = back[s[0]]
                if (s[1] == 0) tf("${cap(sh)} is short for $f.", true, "${cap(sh)} is short for $f.")
                else {
                    val o = back[(s[0] + 3) % back.size].first
                    if (o == f) null else tf("${cap(sh)} is short for $o.", false, "${cap(sh)} is short for $f.")
                }
            },
        )
    }

    private fun c4Syllables(): GenSkill {
        val ws = lex.values.filter { it.syl != null && it.sylBreak != null }.sortedBy { it.w }
        fun brk(w: EnWord) = w.sylBreak!!.replaceFirstChar { it.uppercaseChar() }
        fun why(w: EnWord) = "${brk(w)} has ${w.syl} ${if (w.syl == 1) "syllable" else "syllables"}."
        fun wrongSplits(b: String): List<String> {
            val letters = b.replace("-", "")
            val cuts = b.split("-").runningFold(0) { a, p -> a + p.length }.drop(1).dropLast(1)
            val out = mutableListOf<String>()
            for (i in cuts.indices) for (d in listOf(-1, 1)) {
                val nc = cuts.toMutableList(); nc[i] += d
                if (nc.any { it <= 0 || it >= letters.length } || nc.toSet().size != nc.size || nc != nc.sorted()) continue
                val parts = (listOf(0) + nc + letters.length).zipWithNext { a, c -> letters.substring(a, c) }
                out += parts.joinToString("-")
            }
            return out.filter { it != b }.distinct()
        }
        val multi = ws.filter { it.syl!! >= 2 }
        return skill(
            "en4.syllables", 4, "Clap the syllables", "clap", "phonics",
            qt("count", 1, ws.size) { s, r ->
                val w = ws[s[0]]
                ask("How many syllables are in ${w.w}?", "${w.syl}", (1..5).map { "$it" }.filter { it != "${w.syl}" }.sortedBy { kotlin.math.abs(it.toInt() - w.syl!!) }, why(w), r, vis = vis(w.w), keep = true)
            },
            qt("which", 2, ws.size) { s, r ->
                val w = ws[s[0]]
                val other = ws.filter { it.syl != w.syl }.map { it.w }
                val p = "Which word has ${w.syl} ${if (w.syl == 1) "syllable" else "syllables"}?"
                ask(p, w.w, other, why(w), r)
            },
            qt("split", 3, multi.size) { s, r ->
                val w = multi[s[0]]
                ask("How do we split ${w.w} into syllables?", w.sylBreak!!, wrongSplits(w.sylBreak), "We clap it as ${w.sylBreak}.", r, n = 3)
            },
        )
    }

    private fun c4Dictionary(): GenSkill {
        val L = alphaWords(4)
        val N = L.size
        return skill(
            "en4.dictionary", 4, "Dictionary order", "a-z", "words",
            qt("between", 1, N - 6, 2) { s, r ->
                val i = s[0]
                val g1 = L[i]; val g2 = L[i + 5]; val a = L[i + 1 + s[1] * 2]
                val outside = listOfNotNull(L.getOrNull(i - 3), L.getOrNull(i + 8), L.getOrNull(i + 15), L.getOrNull(i - 12), L.getOrNull(i + 30))
                ask("Which word comes between $g1 and $g2 in a dictionary?", a, outside, "${cap(a)} comes after $g1 and before $g2.", r)
            },
            tft("tf", 2, N - 6, 2) { s, _ ->
                val i = s[0]
                val g1 = L[i]; val g2 = L[i + 5]
                if (s[1] == 0) tf("${cap(L[i + 2])} comes between $g1 and $g2 in a dictionary.", true, "${cap(L[i + 2])} comes after $g1 and before $g2.")
                else {
                    val o = L[(i + 20) % N]
                    tf("${cap(o)} comes between $g1 and $g2 in a dictionary.", false, "${cap(o)} does not come between $g1 and $g2.")
                }
            },
            qt("first", 3, N) { s, r ->
                val w = L[s[0]]
                ask("Which word comes first in a dictionary?", w, L.filter { it.take(2) == w.take(2) && it > w }, "${cap(w)} comes first in ABC order.", r)
            },
        )
    }

    private val TYPES = listOf("Statement", "Question", "Command", "Exclamation")
    private fun typeWhy(t: String) = when (t) {
        "Statement" -> "It tells us something, so it is a statement."
        "Question" -> "It asks something, so it is a question."
        "Command" -> "It tells someone what to do, so it is a command."
        else -> "It shows strong feeling, so it is an exclamation."
    }

    private fun c4SentType(): GenSkill {
        val st0 = strs("statements"); val qs = strs("questions"); val cmd = strs("commands"); val ex = strs("exclaims")
        val cur = st0.map { it to "Statement" } + qs.map { it to "Question" } + cmd.map { it to "Command" } + ex.map { it to "Exclamation" }
        val gen = genStatements().map { it to "Statement" } + genQuestions().map { it to "Question" } + genExclaims().map { it to "Exclamation" }
        return skill(
            "en4.senttype", 4, "Kinds of sentences", "?", "grammar",
            st("sort", 1, st0.size + qs.size) { s, _ ->
                val (x, t0) = cur[s[0]]
                sortQ(x, "Statement", "Question", t0 == "Statement", typeWhy(t0))
            },
            qt("gen", 1, gen.size) { s, r ->
                val (x, t0) = gen[s[0]]
                ask("What kind of sentence is this? $x", t0, TYPES - t0, typeWhy(t0), r)
            },
            qt("kind", 2, cur.size) { s, r ->
                val (x, t0) = cur[s[0]]
                ask("What kind of sentence is this? $x", t0, TYPES - t0, typeWhy(t0), r)
            },
            tft("tf", 3, cmd.size + ex.size) { s, _ ->
                val (x, t0) = (cmd.map { it to "Command" } + ex.map { it to "Exclamation" })[s[0]]
                val claim = if (s[0] % 2 == 0) t0 else (if (t0 == "Command") "Exclamation" else "Command")
                tf("\"$x\" is ${if (claim == "Command") "a command" else "an exclamation"}.", claim == t0, typeWhy(t0))
            },
        )
    }

    // ================================================================ Class 5
    fun c5(): List<GenSkill> = listOf(c5Continuous(), c5PrepTime(), c5Simile(), oneWordSkill("en5.oneword", 5, "One-word names", "1", 0, 6),
        c5Analogy(), c5MuchMany(), c5QTags(), c5NounForms(), c5Spelling(), c5FactOpinion())

    private fun beOf(k: String) = when (k) { "I" -> "am"; "3s" -> "is"; else -> "are" }
    private fun wasOf(k: String) = if (k == "I" || k == "3s") "was" else "were"
    private fun hasOf(k: String) = if (k == "3s") "has" else "have"

    private fun c5Continuous(): GenSkill {
        val subs = rows("tenseSubj").map { it[0].s to it[1].s }
        val vps = rows("tenseVp").map { it[0].s to it[1].s }.filter { it.first != "see" }
        val irrV = vps.filter { lex[it.first]?.irr == true && ppOf(it.first) != pastOf(it.first) }
        return skill(
            "en5.continuous", 5, "Is going, has gone", "-ing", "grammar",
            qt("now", 1, subs.size, vps.size) { s, r ->
                val (sub, k) = subs[s[0]]; val (v, o) = vps[s[1]]
                val be = beOf(k); val ans = "$be ${ingOf(v)}"
                val wb = if (be == "is") "are" else "is"
                ask("Look! $sub ___ $o now. ($v)", ans, listOf("$wb ${ingOf(v)}", pres(k, v), pastOf(v)), "It is happening now, so we say $ans.", r)
            },
            qt("was", 2, subs.size, vps.size) { s, r ->
                val (sub, k) = subs[s[0]]; val (v, o) = vps[s[1]]
                val w = wasOf(k); val ans = "$w ${ingOf(v)}"
                ask("$sub ___ $o when the lights went out. ($v)", ans, listOf("${if (w == "was") "were" else "was"} ${ingOf(v)}", "${beOf(k)} ${ingOf(v)}", "will $v"), "It was going on in the past: $ans.", r)
            },
            qt("perfect", 3, subs.size, vps.size) { s, r ->
                val (sub, k) = subs[s[0]]; val (v, o) = vps[s[1]]
                val h = hasOf(k); val pp = ppOf(v)
                ask("$sub $h just ___ $o. ($v)", pp, listOf(pastOf(v), v, ingOf(v), s3(v)), "After $h, we use $pp.", r)
            },
            tft("perfTf", 3, subs.size, irrV.size, 2) { s, _ ->
                val (sub, k) = subs[s[0]]; val (v, o) = irrV[s[1]]
                val h = hasOf(k)
                if (s[2] == 0) tf("$sub $h ${ppOf(v)} $o.", true, "After $h, we use ${ppOf(v)}.")
                else tf("$sub $h ${pastOf(v)} $o.", false, "After $h, use ${ppOf(v)}, not ${pastOf(v)}.")
            },
        )
    }

    private fun c5PrepTime(): GenSkill {
        val ex = rows("timeExpr").map { Triple(it[0].s, it[1].s, it[2].i) }
        val starts = strs("timeStart")
        val bad = map("timeStartBad")
        val place = rows("placePrep").map { it[0].s to it[1].s }
        val P = listOf("in", "on", "at")
        fun why(e: String, p: String) = when {
            p == "at" && e == "night" -> "We say at night."
            p == "at" -> "At is for an exact time: at $e."
            p == "on" -> "On is for days and dates: on $e."
            e.startsWith("the ") -> "We say in $e."
            else -> "In is for months, years and seasons: in $e."
        }
        fun tmpl(tier: Int) = qt("time$tier", tier, starts.size, ex.size) { s, r ->
            val st0 = starts[s[0]]; val (e, p, t0) = ex[s[1]]
            if (t0 != tier || e in bad[st0].orEmpty()) return@qt null
            ask("$st0 ___ $e.", p, P - p, why(e, p), r, n = 3)
        }
        val inOn = ex.filter { it.second != "at" }
        return skill(
            "en5.preptime", 5, "In, on, at", "at", "grammar",
            tmpl(1), tmpl(2), tmpl(3),
            st("sort", 2, inOn.size) { s, _ ->
                val (e, p, _) = inOn[s[0]]
                sortQ("___ $e", "in", "on", p == "in", why(e, p))
            },
            qt("place", 3, place.size) { s, r ->
                val (f, p) = place[s[0]]
                val w = when (p) { "in" -> "In means inside something."; "on" -> "On means on top of, or touching, a surface."; else -> "At is for a point or a place." }
                ask(f, p, P - p, w, r, n = 3)
            },
        )
    }

    private val WRONG_GROUPS = mapOf(
        "weight" to setOf("colour", "taste", "age"), "size" to setOf("colour", "taste", "temp"), "speed" to setOf("colour", "taste", "temp"),
        "sound" to setOf("colour", "taste", "temp"), "strength" to setOf("colour", "taste"), "touch" to setOf("colour", "taste", "speed"),
        "shape" to setOf("colour", "taste", "temp"), "sight" to setOf("taste", "temp"), "age" to setOf("colour", "taste", "temp"),
        "health" to setOf("colour", "taste", "temp"), "ease" to setOf("colour", "taste", "temp"), "colour" to setOf("trait", "speed", "taste"),
        "taste" to setOf("trait", "speed", "colour"), "temp" to setOf("trait", "speed"), "trait" to setOf("colour", "taste", "temp"),
    )

    private fun c5Simile(): GenSkill {
        val sm = rows("similes").map { Triple(it[0].s, it[1].s, it[2].s) }
        val mean = rows("simileMean").map { it[0].s to it[1].s }
        fun wrongs(g: String) = sm.filter { it.third in WRONG_GROUPS[g].orEmpty() }
        return skill(
            "en5.simile", 5, "As busy as a bee", "as", "words",
            qt("noun", 1, sm.size) { s, r ->
                val (a, n, g) = sm[s[0]]
                ask("As $a as ___", n, wrongs(g).map { it.second }, "We say as $a as $n.", r)
            },
            qt("adj", 2, sm.size) { s, r ->
                val (a, n, g) = sm[s[0]]
                ask("As ___ as $n", a, wrongs(g).map { it.first }, "We say as $a as $n.", r)
            },
            tft("tf", 2, sm.size, 3) { s, _ ->
                val (a, n, g) = sm[s[0]]
                if (s[1] == 0) tf("We say 'as $a as $n'.", true, "We say as $a as $n.")
                else wrongs(g).map { it.second }.getOrNull((s[0] + s[1] * 3) % maxOf(1, wrongs(g).size))?.let { x ->
                    if (s[1] == 2 && wrongs(g).size < 2) null else tf("We say 'as $a as $x'.", false, "We say as $a as $n.")
                }
            },
            qt("mean", 3, mean.size) { s, r ->
                val (x, m) = mean[s[0]]
                ask("What does '$x' mean?", m, mean.map { it.second } - m, "'${cap(x)}' means $m.", r)
            },
        )
    }

    private val OW_CONFLICT = listOf(setOf("zoo", "aviary", "aquarium", "apiary", "beehive", "kennel", "stable"), setOf("spectators", "audience"), setOf("apiary", "beehive"))

    private fun oneWordSkill(id: String, grade: Int, title: String, badge: String, lo: Int, hi: Int): GenSkill {
        val all = rows("oneWord").map { listOf(it[0].s, it[1].s, it[2].s, "${it[3].i}") }
        val ws = all.filter { it[3].toInt() in lo..hi }
        fun clash(a: String, b: String) = OW_CONFLICT.any { a in it && b in it }
        fun same(g: String, w: String) = all.filter { it[2] == g && it[1] != w && !clash(it[1], w) }
        fun defn(p: String, w: String, g: String) = when {
            g == "quality" || (g == "time" && !p.startsWith("a ")) -> "${cap(w)} means $p."
            p.startsWith("people") -> "${cap(w)} are $p."
            else -> "${cap(art(w))} $w is $p."
        }
        return skill(
            id, grade, title, badge, "words",
            qt("toWord", 1, ws.size) { s, r ->
                val (p, w, g) = ws[s[0]]
                ask("Which word means '$p'?", w, same(g, w).map { it[1] }, defn(p, w, g), r)
            },
            qt("toPhrase", 2, ws.size) { s, r ->
                val (p, w, g) = ws[s[0]]
                if (p.length > 24) return@qt null
                ask("What does '$w' mean?", p, same(g, w).map { it[0] }.filter { it.length <= 24 }, defn(p, w, g), r)
            },
            tft("tf", 2, ws.size, 3) { s, _ ->
                val (p, w, g) = ws[s[0]]
                if (s[1] == 0) tf("'${cap(w)}' means $p.", true, defn(p, w, g))
                else same(g, w).map { it[0] }.let { o -> o.getOrNull((s[0] + s[1] * 5) % maxOf(1, o.size)) }?.let { x ->
                    if (s[1] == 2 && same(g, w).size < 2) null else tf("'${cap(w)}' means $x.", false, defn(p, w, g))
                }
            },
        )
    }

    private fun c5Analogy(): GenSkill {
        val an = obj("analogy").mapValues { e -> e.value.jsonArray.map { it.jsonArray[0].s to it.jsonArray[1].s } }
        fun why(rel: String, c: String, d: String) = when (rel) {
            "young" -> "A young $c is called ${art(d)} $d."
            "sound" -> "${cap(art(c))} $c makes a $d sound."
            else -> "${cap(art(c))} $c lives in ${art(d)} $d."
        }
        fun tmpl(rel: String, tier: Int): Template {
            val rs = an[rel].orEmpty()
            return qt(rel, tier, rs.size, rs.size) { s, r ->
                if (s[0] == s[1]) return@qt null
                val (a, b) = rs[s[0]]; val (c, d) = rs[s[1]]
                if (b == d) return@qt null
                ask("${cap(a)} is to $b as $c is to ___.", d, rs.map { it.second }.filter { it != d && it != b } + b, why(rel, c, d), r, vis = vis(c))
            }
        }
        return skill("en5.analogy", 5, "Cat is to kitten", "::", "words", tmpl("young", 1), tmpl("sound", 2), tmpl("home", 3))
    }

    private fun c5MuchMany(): GenSkill {
        val unc = lex.values.filter { it.count == false && "n" in it.pos && it.lvl <= 5 && isAlpha(it.w) && it.w !in setOf("weather", "thunder", "news", "hair", "traffic") }.map { it.w }.sorted()
        val cnt = nouns(3).filter { it.count == true && it.plural != null && it.cat in setOf("food", "fruit", "vegetable", "school", "home", "toy", "thing") && isAlpha(it.plural!!) }.map { it.plural!! }
        val all = unc.map { it to false } + cnt.map { it to true }
        val fr = listOf("How ___ %s do you need?", "There %s ___ %s left.", "We don't have ___ %s.")
        fun why(x: String, c: Boolean) = if (c) "We can count $x, so we say many." else "We cannot count $x, so we say much."
        return skill(
            "en5.muchmany", 5, "Much or many", "much", "grammar",
            st("sort", 1, all.size) { s, _ ->
                val (x, c) = all[s[0]]
                sortQ("How ___ $x?", "much", "many", !c, why(x, c), vis(x))
            },
            qt("frame", 2, all.size, 3) { s, r ->
                val (x, c) = all[s[0]]
                val p = when (s[1]) { 0 -> "How ___ $x do you need?"; 1 -> "There ${if (c) "aren't" else "isn't"} ___ $x left."; else -> "We don't have ___ $x." }
                ask(p, if (c) "many" else "much", listOf(if (c) "much" else "many"), why(x, c), r, vis = vis(x))
            },
            qt("few", 3, all.size) { s, r ->
                val (x, c) = all[s[0]]
                val p = if (c) "There are a ___ $x left." else "There is a ___ $x left."
                ask(p, if (c) "few" else "little", listOf(if (c) "little" else "few"), if (c) "A few is for things we can count." else "A little is for things we cannot count.", r, vis = vis(x))
            },
        )
    }

    private fun c5QTags(): GenSkill {
        data class Sb(val text: String, val p: String, val k: String)
        val people = listOf(Sb("He", "he", "3s"), Sb("She", "she", "3s"), Sb("They", "they", "pl"), Sb("We", "we", "pl"), Sb("You", "you", "you"),
            Sb("Riya", "she", "3s"), Sb("Kabir", "he", "3s"), Sb("Your mum", "she", "3s"), Sb("The boys", "they", "pl"), Sb("Grandpa", "he", "3s"), Sb("I", "I", "I"))
        val things = listOf(Sb("The bus", "it", "3s"), Sb("It", "it", "3s"), Sb("The shops", "they", "pl"), Sb("The tea", "it", "3s"))
        val prons = listOf("he", "she", "they", "we", "you", "it", "I")
        fun tagQ(sb: Sb, sent: String, posAux: String, negAux: String, neg: Boolean, r: Random): Question? {
            val p = sb.p
            val tagAux = if (neg) posAux else negAux
            val tag = if (sb.k == "I" && !neg && posAux == "am") "aren't I?" else "$tagAux $p?"
            val wrongPol = if (sb.k == "I" && neg && posAux == "am") "aren't I?" else "${if (neg) negAux else posAux} $p?"
            val wrongP = "$tagAux ${prons.first { it != p && (it == "it") != (p == "it") }}?"
            val wrongAux = "${if (tagAux.endsWith("n't")) (if (tagAux == "isn't") "doesn't" else "isn't") else (if (tagAux == "is") "does" else "is")} $p?"
            val why = if (neg) "A not sentence gets a yes tag: ${tag.removeSuffix("?")}." else "A yes sentence gets a not tag: ${tag.removeSuffix("?")}."
            return ask("$sent, ___?", tag, listOf(wrongPol, wrongP, wrongAux), why, r)
        }
        val beComp = listOf("late", "tired", "ready", "happy", "hungry")
        val canV = listOf("swim", "sing", "cook", "dance")
        val presV = listOf("play" to "chess", "like" to "tea", "live" to "here", "walk" to "to school")
        val pastV = listOf("go" to "home", "eat" to "lunch", "win" to "the match", "see" to "the film")
        val willV = listOf("come", "help", "call", "wait")
        val haveV = listOf("finish" to "the work", "eat" to "lunch", "see" to "the film")
        fun beP(k: String) = beOf(k)
        fun beN(k: String) = when (k) { "I" -> "am not"; "3s" -> "isn't"; else -> "aren't" }
        val all = people + things
        return skill(
            "en5.qtags", 5, "Question tags", "?", "grammar",
            qt("be", 1, all.size, beComp.size, 2) { s, r ->
                val sb = all[s[0]]; val c = beComp[s[1]]; val neg = s[2] == 1
                if (sb.p == "it" && c !in setOf("late", "ready")) return@qt null
                if (sb.k == "pl" && sb.p == "they" && sb.text == "The shops" && c != "late") return@qt null
                val sent = if (sb.k == "I") (if (neg) "I'm not $c" else "I am $c") else "${sb.text} ${if (neg) beN(sb.k) else beP(sb.k)} $c"
                tagQ(sb, sent, beP(sb.k), when (sb.k) { "I" -> "aren't"; "3s" -> "isn't"; else -> "aren't" }, neg, r)
            },
            qt("can", 1, people.size, canV.size, 2) { s, r ->
                val sb = people[s[0]]; val v = canV[s[1]]; val neg = s[2] == 1
                tagQ(sb, "${sb.text} ${if (neg) "can't" else "can"} $v", "can", "can't", neg, r)
            },
            qt("present", 2, people.size, presV.size, 2) { s, r ->
                val sb = people[s[0]]; val (v, o) = presV[s[1]]; val neg = s[2] == 1
                val d = if (sb.k == "3s") "does" else "do"
                val sent = "${sb.text} ${if (neg) "${d}n't $v" else pres(sb.k, v)} $o"
                tagQ(sb, sent, d, "${d}n't", neg, r)
            },
            qt("past", 2, all.size, pastV.size, 2) { s, r ->
                val sb = all[s[0]]; val (v, o) = pastV[s[1]]; val neg = s[2] == 1
                if (sb.p == "it" || sb.text == "The shops") return@qt null
                tagQ(sb, "${sb.text} ${if (neg) "didn't $v" else pastOf(v)} $o", "did", "didn't", neg, r)
            },
            qt("will", 3, all.size, willV.size, 2) { s, r ->
                val sb = all[s[0]]; val v = willV[s[1]]; val neg = s[2] == 1
                if ((sb.p == "it" || sb.text == "The shops") && v != "come") return@qt null
                tagQ(sb, "${sb.text} ${if (neg) "won't" else "will"} $v", "will", "won't", neg, r)
            },
            qt("have", 3, people.size, haveV.size, 2) { s, r ->
                val sb = people[s[0]]; val (v, o) = haveV[s[1]]; val neg = s[2] == 1
                val h = hasOf(sb.k)
                tagQ(sb, "${sb.text} ${if (neg) "${h}n't" else h} ${ppOf(v)} $o", h, "${h}n't", neg, r)
            },
        )
    }

    private fun c5NounForms(): GenSkill {
        val an = rows("adjNoun").map { Triple(it[0].s, it[1].s, it[2].ss) }
        val vn = rows("verbNoun").map { Triple(it[0].s, it[1].s, it[2].ss) }
        val fr = rows("adjNounFrames").map { Triple(it[0].s, it[1].s, it[2].s) }
        val byAdj = an.associateBy { it.first.lowercase() }
        val both = an + vn
        return skill(
            "en5.nounforms", 5, "Kind → kindness", "ness", "words",
            qt("adj", 1, an.size) { s, r ->
                val (a, n, w) = an[s[0]]
                ask("Make a noun from $a.", n, w + a, "The noun from $a is $n.", r)
            },
            qt("frame", 2, fr.size) { s, r ->
                val (f, ans, base) = fr[s[0]]
                val extra = byAdj[base.lowercase()]?.third.orEmpty().map { if (base[0].isUpperCase()) cap(it) else it }
                ask("$f ($base)", ans, listOf(base) + extra, "We need a naming word here: $ans.", r)
            },
            qt("verb", 2, vn.size) { s, r ->
                val (v, n, w) = vn[s[0]]
                ask("Make a noun from $v.", n, w + v, "The noun from $v is $n.", r)
            },
            tft("tf", 3, both.size, 2) { s, _ ->
                val (x, n, w) = both[s[0]]
                if (s[1] == 0) tf("The noun from $x is $n.", true, "The noun from $x is $n.")
                else w.firstOrNull()?.let { tf("The noun from $x is $it.", false, "The noun from $x is $n.") }
            },
        )
    }

    private fun c5Spelling(): GenSkill {
        val sp = rows("spell").map { it[0].s to it[1].ss }
        val owner = HashMap<String, String>()
        for ((r0, ws) in sp) for (w in ws) owner.putIfAbsent(w, r0)
        return skill(
            "en5.spelling", 5, "Spell it right", "abc", "writing",
            qt("right", 1, sp.size) { s, r ->
                val (w, ws) = sp[s[0]]
                ask("Which spelling is right?", w, ws, "We spell it $w.", r)
            },
            tft("tf", 2, sp.size, 3) { s, _ ->
                val (w, ws) = sp[s[0]]
                if (s[1] == 0) tf("\"$w\" is spelt correctly.", true, "We spell it $w.")
                else ws.getOrNull(s[1] - 1)?.takeIf { owner[it] == w }?.let { tf("\"$it\" is spelt correctly.", false, "The right spelling is $w.") }
            },
            qt("wrong", 3, sp.size, 2) { s, r ->
                val (w, ws) = sp[s[0]]
                val m = ws.getOrNull(s[1])?.takeIf { owner[it] == w } ?: return@qt null
                ask("Which word is spelt wrongly?", m, sp.map { it.first }.filter { it != w }, "${cap(m)} should be spelt $w.", r)
            },
        )
    }

    private fun c5FactOpinion(): GenSkill {
        val facts = strs("facts")
        val ops = rows("opinionFrames").flatMap { r0 -> r0[1].ss.map { r0[0].s.replace("{x}", it) } } + strs("opinions")
        val all = facts.map { it to true } + ops.map { it to false }
        fun why(f: Boolean) = if (f) "It can be checked, so it is a fact." else "It is what someone thinks, so it is an opinion."
        return skill(
            "en5.factopinion", 5, "Fact or opinion?", "F/O", "reading",
            st("sort", 1, all.size) { s, _ ->
                val (x, f) = all[s[0]]
                sortQ(x, "Fact", "Opinion", f, why(f))
            },
            tft("tf", 2, all.size, 2) { s, _ ->
                val (x, f) = all[s[0]]
                val claimFact = s[1] == 0
                tf("This is ${if (claimFact) "a fact" else "an opinion"}: $x", claimFact == f, why(f))
            },
        )
    }

    // ================================================================ Class 6
    fun c6(): List<GenSkill> = listOf(c6Pos(), c6Tenses(), c6Passive(), c6Reported(), c6Determiners(), c6Phrasal(), c6Confuse(), c6ErrorSpot(), c6WordForm(), c6Fig())

    private val POS_WHY = mapOf(
        "Noun" to "names a person, place or thing", "Verb" to "shows an action", "Adjective" to "describes a noun",
        "Adverb" to "tells how something is done", "Pronoun" to "stands in for a noun", "Preposition" to "shows where something is",
        "Conjunction" to "joins two ideas", "Interjection" to "shows a sudden feeling",
    )
    private val POS_WRONG = mapOf(
        "Noun" to listOf("Verb", "Adjective", "Pronoun"), "Verb" to listOf("Noun", "Adverb", "Adjective"), "Adjective" to listOf("Adverb", "Noun", "Verb"),
        "Adverb" to listOf("Adjective", "Verb", "Preposition"), "Pronoun" to listOf("Noun", "Adjective", "Conjunction"),
        "Preposition" to listOf("Conjunction", "Adverb", "Pronoun"), "Conjunction" to listOf("Preposition", "Interjection", "Adverb"),
        "Interjection" to listOf("Conjunction", "Noun", "Adverb"),
    )

    private fun posQ(word: String, label: String, sent: String, r: Random): Question? {
        val why = "${cap(word)} is ${art(label)} ${label.lowercase()}: it ${POS_WHY[label]}."
        return ask("What part of speech is '$word'? $sent", label, POS_WRONG[label]!!, why, r)
    }

    private fun c6Pos(): GenSkill {
        val sets = rows("adjSets").map { listOf(it[1].ss, it[2].ss, it[3].ss.filter { e -> "many" !in e }) }
        val s1 = sets.flatMap { (adjs, ns, es) -> adjs.take(4).flatMap { a -> ns.take(4).flatMap { n -> es.map { e -> Triple(a, n, e) } } } }
        val adv = rows("advSent").flatMap { r0 -> r0[3].ss.map { listOf(r0[0].s, r0[1].s, r0[2].s, it) } }
        val pr = listOf("He", "She", "They", "We", "I")
        val th = listOf("book", "bag", "ball", "cup", "pen")
        val preps = listOf("on", "under", "near", "behind", "beside")
        val places = listOf("table", "bed", "chair", "sofa")
        val conj = listOf("{a} and {b} went to the park.", "{a} likes tea but {b} likes milk.", "{a} stayed home because it was raining.",
            "{a} was tired, so {b} cooked dinner.", "{a} can sing or dance.", "{a} smiled when {b} came home.")
        val conjW = listOf("and", "but", "because", "so", "or", "when")
        val inter = listOf("Wow! {a} won the race.", "Ouch! {a} hurt a finger.", "Hurray! {a} came first.", "Oops! {a} dropped the cup.",
            "Oh! {a} forgot the bag.", "Alas! {a} lost the match.")
        val interW = listOf("Wow", "Ouch", "Hurray", "Oops", "Oh", "Alas")
        return skill(
            "en6.pos", 6, "Parts of speech", "POS", "grammar",
            qt("nva", 1, s1.size, 4) { s, r ->
                val (a, n, e) = s1[s[0]]
                val sent = "The $a $n $e."
                val ew = e.split(" ")
                when (s[1]) {
                    0 -> posQ(a, "Adjective", sent, r)
                    1 -> posQ(n, "Noun", sent, r)
                    2 -> if (ew[0] in setOf("was", "had")) null else posQ(ew[0], "Verb", sent, r)
                    else -> ew.last().takeIf { it !in SMALL && it != ew[0] }?.let { posQ(it, "Noun", sent, r) }
                }
            },
            qt("adverb", 2, adv.size, 2) { s, r ->
                val (sub, v, o, a) = adv[s[0]]
                val sent = "$sub $v $o $a."
                if (s[1] == 0) posQ(a, "Adverb", sent, r) else posQ(v, "Verb", sent, r)
            },
            qt("pronPrep", 2, pr.size, th.size, preps.size * places.size) { s, r ->
                val p = pr[s[0]]; val t0 = th[s[1]]; val pp = preps[s[2] % preps.size]; val pl = places[s[2] / preps.size]
                val sent = "$p put the $t0 $pp the $pl."
                if ((s[2] + s[1]) % 2 == 0) posQ(pp, "Preposition", sent, r) else posQ(p, "Pronoun", sent, r)
            },
            qt("conj", 3, conj.size, names.size) { s, r ->
                val a = names[s[1]]; val b = names[(s[1] + 3) % names.size]
                posQ(conjW[s[0]], "Conjunction", conj[s[0]].replace("{a}", a).replace("{b}", b), r)
            },
            qt("interj", 3, inter.size, names.size) { s, r ->
                posQ(interW[s[0]], "Interjection", inter[s[0]].replace("{a}", names[s[1]]), r)
            },
        )
    }

    private data class Fr(val id: String, val tier: Int, val text: String, val tense: Int, val wrong: List<Int>, val durative: Boolean = false)

    private val TENSE_NAMES = listOf("Simple present", "Present continuous", "Present perfect", "Present perfect continuous", "Simple past",
        "Past continuous", "Past perfect", "Past perfect continuous", "Simple future", "Future continuous", "Future perfect")

    private fun tenseForm(t: Int, k: String, v: String): String = when (t) {
        0 -> pres(k, v); 1 -> "${beOf(k)} ${ingOf(v)}"; 2 -> "${hasOf(k)} ${ppOf(v)}"; 3 -> "${hasOf(k)} been ${ingOf(v)}"
        4 -> pastOf(v); 5 -> "${wasOf(k)} ${ingOf(v)}"; 6 -> "had ${ppOf(v)}"; 7 -> "had been ${ingOf(v)}"
        8 -> "will $v"; 9 -> "will be ${ingOf(v)}"; else -> "will have ${ppOf(v)}"
    }

    private val DURATIVE = setOf("play", "cook", "paint", "clean", "watch", "wash", "climb", "swim", "read", "write", "sing", "draw", "bake", "ride", "fly", "build")

    private fun c6Tenses(): GenSkill {
        val subs = rows("tenseSubj").map { it[0].s to it[1].s }
        val vps = rows("tenseVp").map { it[0].s to it[1].s }.filter { it.first != "see" }
        val frames = listOf(
            Fr("past", 1, "Yesterday, {s} ___ {o}.", 4, listOf(8, 2, 1)), Fr("future", 1, "Tomorrow, {s} ___ {o}.", 8, listOf(4, 2, 5)),
            Fr("usually", 1, "{S} usually ___ {o} on Sundays.", 0, listOf(3, 10, 6)), Fr("look", 2, "Look! {S} ___ {o} now.", 1, listOf(4, 6, 10)),
            Fr("lights", 2, "{S} ___ {o} when the lights went out.", 5, listOf(1, 8, 2)), Fr("thisTime", 2, "At this time tomorrow, {s} ___ {o}.", 9, listOf(5, 2, 6)),
            Fr("times", 3, "{S} ___ {o} three times this week.", 2, listOf(9, 6, 5)), Fr("hours", 3, "{S} ___ {o} for two hours now.", 3, listOf(1, 4, 8), true),
            Fr("byTime", 3, "By the time we arrived, {s} ___ {o}.", 6, listOf(2, 10, 1)), Fr("anHour", 3, "{S} ___ {o} for an hour when we arrived.", 7, listOf(3, 9, 1), true),
            Fr("byMonday", 3, "By next Monday, {s} ___ {o}.", 10, listOf(6, 2, 5)),
        )
        val named = listOf(0, 1, 2, 4, 5, 6, 8, 9, 10)
        val ts = frames.map { f ->
            qt(f.id, f.tier, subs.size, vps.size) { s, r ->
                val (sub, k) = subs[s[0]]; val (v, o) = vps[s[1]]
                if (f.durative && v !in DURATIVE) return@qt null
                val p = f.text.replace("{S}", sub).replace("{s}", lowSubj(sub)).replace("{o}", o) + " ($v)"
                val ans = tenseForm(f.tense, k, v)
                ask(p, ans, f.wrong.map { tenseForm(it, k, v) }, "This needs the ${TENSE_NAMES[f.tense].lowercase()}: $ans.", r)
            }
        } + qt("name", 3, subs.size, vps.size, named.size) { s, r ->
            val (sub, k) = subs[s[0]]; val (v, o) = vps[s[1]]
            val t0 = named[s[2]]
            val form = tenseForm(t0, k, v)
            if (t0 == 4 && pastOf(v) == v) return@qt null
            val near = named.filter { it != t0 }.sortedBy { (if (it / 4 == t0 / 4) 0 else 2) + (if (it % 4 == t0 % 4) 0 else 1) }.map { TENSE_NAMES[it] }
            ask("Which tense is this? $sub $form $o.", TENSE_NAMES[t0], near.take(5).shuffled(r), "This is the ${TENSE_NAMES[t0].lowercase()}: $form.", r, keep = true)
        }
        return skill("en6.tenses", 6, "Tenses: has, had, will", "had", "grammar", *ts.toTypedArray())
    }

    private fun isPluralNp(x: String): Boolean {
        val w = x.split(" ").last().lowercase()
        return w in setOf("children", "police", "people") || byPlural.containsKey(w) || (w.endsWith("s") && lex[w] == null && lex[w.dropLast(1)] != null)
    }

    private fun c6Passive(): GenSkill {
        val ps = rows("passive").map { listOf(it[0].s, it[1].s, it[2].s, "${it[3].i}") }
        fun low(x: String) = if (x.split(" ")[0] in setOf("The", "A")) x.replaceFirstChar { it.lowercaseChar() } else x
        fun q(row: List<String>, mode: Int, r: Random): Question? {
            val (doer, v, obj, pl) = row
            val many = pl == "1"; val doerPl = isPluralNp(doer)
            val pp = ppOf(v)
            val (active, ans, wr) = when (mode) {
                0 -> Triple("$doer ${pastOf(v)} $obj.", "${if (many) "were" else "was"} $pp", listOf("${if (many) "was" else "were"} $pp", pastOf(v), "${if (many) "are" else "is"} $pp") + (if (pastOf(v) != pp) listOf("${if (many) "were" else "was"} ${pastOf(v)}") else emptyList()))
                1 -> Triple("$doer ${if (doerPl) v else s3(v)} $obj.", "${if (many) "are" else "is"} $pp", listOf("${if (many) "is" else "are"} $pp", "${if (many) "were" else "was"} $pp", if (doerPl) v else s3(v)))
                2 -> Triple("$doer will $v $obj.", "will be $pp", listOf("will $pp", "will be ${ingOf(v)}", "would be $pp"))
                3 -> Triple("$doer ${if (doerPl) "have" else "has"} ${pp} $obj.", "${if (many) "have" else "has"} been $pp", listOf("${if (many) "has" else "have"} been $pp", "${if (many) "have" else "has"} $pp", "${if (many) "were" else "was"} been $pp"))
                else -> Triple("$doer ${if (doerPl) "are" else "is"} ${ingOf(v)} $obj.", "${if (many) "are" else "is"} being $pp", listOf("${if (many) "is" else "are"} being $pp", "${if (many) "are" else "is"} $pp", "${if (many) "are" else "is"} been $pp"))
            }
            val p = "Active: $active Passive: ${cap(obj)} ___ by ${low(doer)}."
            return ask(p, ans, wr, "The passive of this sentence uses $ans.", r)
        }
        return skill(
            "en6.passive", 6, "Active and passive", "by", "grammar",
            qt("past", 1, ps.size) { s, r -> q(ps[s[0]], 0, r) },
            qt("present", 2, ps.size) { s, r -> q(ps[s[0]], 1, r) },
            qt("more", 3, ps.size, 3) { s, r -> q(ps[s[0]], 2 + s[1], r) },
            tft("which", 2, ps.size, 2) { s, _ ->
                val (doer, v, obj, pl) = ps[s[0]]
                val pas = "${cap(obj)} ${if (pl == "1") "were" else "was"} ${ppOf(v)} by ${low(doer)}."
                val act = "$doer ${pastOf(v)} $obj."
                if (s[1] == 0) tf("\"$pas\" is in the passive.", true, "The thing done to comes first, then was or were and by.")
                else tf("\"$act\" is in the passive.", false, "The doer comes first, so it is active.")
            },
        )
    }

    private fun c6Reported(): GenSkill {
        val rs = rows("reported").map { listOf(it[0].s, it[1].s, it[2].s, it[3].ss.joinToString("|"), "${it[4].i}") }
        val sp = names.take(10)
        fun pron(n: String) = if (n in girls) "she" else "he"
        fun tmpl(tier: Int) = qt("t$tier", tier, sp.size, rs.size) { s, r ->
            val n = sp[s[0]]; val (x, a, rest, w, t0) = rs[s[1]]
            if (t0.toInt() != tier) return@qt null
            ask("$n said, \"I $x.\" $n said that ${pron(n)} ___ $rest.", a, w.split("|"), "In reported speech, ${x.substringBefore(" ")} changes to $a.", r)
        }
        return skill(
            "en6.reported", 6, "Reported speech", "said", "grammar",
            tmpl(1), tmpl(2), tmpl(3),
            qt("pronoun", 2, sp.size, rs.size) { s, r ->
                val n = sp[s[0]]; val (x, a, rest, _, t0) = rs[s[1]]
                if (t0 != "1") return@qt null
                ask("$n said, \"I $x.\" $n said that ___ $a $rest.", pron(n), listOf("I", if (pron(n) == "she") "he" else "she", "you"), "I changes to ${pron(n)} when we report what $n said.", r)
            },
        )
    }

    private fun c6Determiners(): GenSkill {
        val ns = picNouns(3).filter { it.count == true && it.plural != null && isAlpha(it.plural!!) && it.plural != it.w }
        val unc = lex.values.filter { it.count == false && "n" in it.pos && it.lvl <= 4 && isAlpha(it.w) && it.cat in setOf("food", "nature", "thing", "home", "school") }.map { it.w }.sorted()
        val sa = unc.map { it to false } + ns.map { it.plural!! to true }
        val D = listOf("This", "These", "That", "Those")
        val why = listOf("One thing near us: this.", "Many things near us: these.", "One thing far away: that.", "Many things far away: those.")
        return skill(
            "en6.determiners", 6, "This, that, these", "this", "grammar",
            qt("near", 1, ns.size, 2) { s, r ->
                val n = ns[s[0]]
                val k = s[1]
                val p = if (k == 0) "___ ${n.w} here is mine." else "___ ${n.plural} here are mine."
                ask(p, D[k], D - D[k], why[k], r, vis = vis(n.w))
            },
            qt("far", 2, ns.size, 2) { s, r ->
                val n = ns[s[0]]
                val k = 2 + s[1]
                val p = if (k == 2) "___ ${n.w} over there is mine." else "___ ${n.plural} over there are mine."
                ask(p, D[k], D - D[k], why[k], r, vis = vis(n.w))
            },
            qt("someAny", 2, sa.size, 3) { s, r ->
                val (x, c) = sa[s[0]]
                val (p, a) = when (s[1]) {
                    0 -> "There ${if (c) "aren't" else "isn't"} ___ $x left." to "any"
                    1 -> "I bought ___ $x today." to "some"
                    else -> "We don't need ___ $x." to "any"
                }
                ask(p, a, listOf(if (a == "any") "some" else "any"), if (a == "any") "We use any in not sentences." else "We use some in yes sentences.", r, vis = vis(x))
            },
        )
    }

    private val PV_CONFLICT = listOf(setOf("put off", "call off"), setOf("carry on", "go on"), setOf("look for", "look up"), setOf("switch off", "put out"),
        setOf("set up", "make up"), setOf("turn up", "show off"), setOf("hold on", "carry on"), setOf("give away", "throw away"))

    private fun c6Phrasal(): GenSkill {
        val ps = rows("phrasal").map { Triple(it[0].s, it[1].s, it[2].ss) }
        val meanOf = ps.associate { it.first to it.second }
        fun clash(a: String, b: String) = a == b || meanOf[a] == meanOf[b] || PV_CONFLICT.any { a in it && b in it }
        fun wrongs(p: String) = ps.map { it.first }.filter { !clash(p, it) }.sortedBy { if (it.substringBefore(" ") == p.substringBefore(" ")) 0 else 1 }
        return skill(
            "en6.phrasal", 6, "Phrasal verbs", "up", "words",
            qt("frame", 1, ps.size, 2) { s, r ->
                val (p, m, fs) = ps[s[0]]
                val f = fs.getOrNull(s[1]) ?: return@qt null
                val w = wrongs(p)
                val fit = { x: String -> if (f.startsWith("___")) cap(x) else x }
                ask(f, fit(p), (w.take(3).shuffled(r) + w.drop(3).shuffled(r)).map(fit), "To $p means to $m.", r, keep = true)
            },
            qt("mean", 2, ps.size) { s, r ->
                val (p, m, _) = ps[s[0]]
                ask("What does '$p' mean?", m, ps.filter { !clash(p, it.first) }.map { it.second }, "To $p means to $m.", r)
            },
            tft("tf", 3, ps.size, 3) { s, _ ->
                val (p, m, _) = ps[s[0]]
                if (s[1] == 0) tf("To $p means to $m.", true, "To $p means to $m.")
                else {
                    val o = ps.filter { !clash(p, it.first) }.map { it.second }
                    tf("To $p means to ${o[(s[0] * 3 + s[1] * 11) % o.size]}.", false, "To $p means to $m.")
                }
            },
        )
    }

    private fun c6Confuse(): GenSkill {
        val sets = t["confuse"]!!.jsonArray.map { st0 -> st0.jsonArray.map { w -> w.ss } }
        data class E(val set: Int, val word: String, val k: Int, val frame: String)
        val es = sets.flatMapIndexed { i, ws -> ws.flatMap { w -> w.drop(1).mapIndexed { k, f -> E(i, w[0], k, f) } } }
        val words = sets.map { ws -> ws.map { it[0] } }
        fun fit(f: String, w: String) = if (f.startsWith("___")) cap(w) else w
        fun q(e: E, r: Random): Question? {
            val others = words[e.set] - e.word
            return ask(e.frame, fit(e.frame, e.word), others.map { fit(e.frame, it) }, "Here we need ${e.word}, not ${others.joinToString(" or ")}.", r)
        }
        return skill(
            "en6.confuse", 6, "Lose or loose?", "vs", "words",
            qt("easy", 1, es.size) { s, r -> es[s[0]].takeIf { it.set < 12 }?.let { q(it, r) } },
            qt("hard", 2, es.size) { s, r -> es[s[0]].takeIf { it.set >= 12 }?.let { q(it, r) } },
            tft("tf", 3, es.size) { s, _ ->
                val e = es[s[0]]
                val others = words[e.set] - e.word
                val ok = s[0] % 2 == 0
                val w = if (ok) e.word else others[s[0] % others.size]
                tf("This sentence is right: ${e.frame.replace("___", fit(e.frame, w))}", ok, "Here we need ${e.word}, not ${others.joinToString(" or ")}.")
            },
        )
    }

    private fun errQ(sentence: String, wrong: String, why: String, r: Random): Question? {
        val ws = sentence.removeSuffix(".").split(" ").map { it.trim(',', '.', '!') }
        if (wrong !in ws) return null
        val others = ws.filter { it != wrong && it.lowercase() !in SMALL && it.length > 1 }.distinct()
        if (others.size < 2) return null
        return ask("Which word is wrong? $sentence", wrong, others.shuffled(r).take(3), why, r)
    }

    private fun c6ErrorSpot(): GenSkill {
        val er = rows("errors").map { it.ss }.filter { !it[0].endsWith("every day.") }
        val subs3 = rows("svSubj").filter { it[1].s == "3s" }.map { it[0].s }
        val vps = rows("svVp").map { it[0].s to it[1].s }
        val tsub = rows("tenseSubj").map { it[0].s }
        val irrVp = rows("tenseVp").map { it[0].s to it[1].s }.filter { lex[it.first]?.irr == true && regPast(it.first) != pastOf(it.first) }
        val irrN = listOf("mouse", "goose", "sheep", "deer", "child", "man", "woman", "calf", "wolf", "ox").mapNotNull { w -> lex[w]?.plural?.let { w to it } }
        val places = listOf("garden", "park", "field", "village")
        val foods = listOf("apple", "orange", "egg", "idli", "onion")
        return skill(
            "en6.errorspot", 6, "Spot the mistake", "oops", "grammar",
            qt("agree", 1, subs3.size, vps.size) { s, r ->
                val sub = subs3[s[0]]; val (b, s3p) = vps[s[1]]
                val wrongV = b.substringBefore(" ")
                if (wrongV == "have") return@qt null
                errQ("$sub ${wrongV} ${b.substringAfter(" ")} every day.", wrongV, "With ${lowSubj(sub)}, we say ${s3p.substringBefore(" ")}.", r)
            },
            qt("past", 2, tsub.size, irrVp.size) { s, r ->
                val sub = tsub[s[0]]; val (v, o) = irrVp[s[1]]
                val w = regPast(v)
                errQ("Yesterday, ${lowSubj(sub)} $w $o.", w, "${cap(v)} changes to ${pastOf(v)}, not $w.", r)
            },
            qt("plural", 2, irrN.size, places.size) { s, r ->
                val (sg, pl) = irrN[s[0]]
                val w = if (sg == "ox") "oxes" else sg + "s"
                errQ("I saw three $w in the ${places[s[1]]}.", w, "${cap(sg)} changes to $pl, not $w.", r)
            },
            qt("article", 2, names.size, foods.size) { s, r ->
                val f = foods[s[1]]
                errQ("${names[s[0]]} ate a $f today.", "a", "${cap(f)} starts with a vowel sound, so we say an.", r)
            },
            qt("table", 3, er.size) { s, r ->
                val (c, wrong, right, why) = er[s[0]]
                val ws = c.removeSuffix(".").split(" ")
                val i = ws.indexOfFirst { it.trim(',', '.') == right }
                if (i < 0 || wrong == right) return@qt null
                val bad = ws.toMutableList().also { it[i] = wrong }.joinToString(" ") + "."
                errQ(bad.replaceFirstChar { it.uppercaseChar() }, wrong, why, r)
            },
        )
    }

    private fun c6WordForm(): GenSkill {
        val wf = rows("wordForm").map { Triple(it[0].s, it[1].s, it[2].s) }.filter { it.third != "growing" }
        val noV = strs("wordFormNoV").toSet()
        val withV = wf.filter { it.first !in noV && it.first != it.second }
        val fr = rows("wordFormFrames").map { Triple(it[0].s, it[1].s, it[2].ss) }
        val nounsSet = wf.map { it.second }.toSet(); val adjSet = wf.map { it.third }.toSet()
        val cards = wf.flatMap { (v, n, a) -> listOfNotNull(if (n != v || v in noV) n to true else null, a to false) }.distinctBy { it.first }
        return skill(
            "en6.wordform", 6, "Noun, verb, adjective", "-ion", "words",
            qt("noun", 1, withV.size) { s, r ->
                val (v, n, a) = withV[s[0]]
                ask("What is the noun form of $v?", n, listOf(a, v + "ness", v + "al", v + "ment").filter { it != n }, "The noun from $v is $n.", r)
            },
            qt("adj", 2, wf.size) { s, r ->
                val (v, n, a) = wf[s[0]]
                val base = if (v in noV) n else v
                ask("What is the adjective form of $base?", a, listOf(n, base + "ful", base + "ous", base + "ive").filter { it != a && it != base }, "The adjective from $base is $a.", r)
            },
            qt("frame", 3, fr.size) { s, r ->
                val (f, a, w) = fr[s[0]]
                val kind = if (a in nounsSet) "a noun" else if (a in adjSet) "an adjective" else "this word"
                ask(f, a, w, "We need $kind here: $a.", r)
            },
            tft("tf", 2, wf.size, 2) { s, _ ->
                val (v, n, a) = wf[s[0]]
                val base = if (v in noV) n else v
                if (s[1] == 0) tf("${cap(a)} is the adjective form of $base.", true, "The adjective from $base is $a.")
                else if (n != base) tf("${cap(n)} is the adjective form of $base.", false, "${cap(n)} is a noun; the adjective is $a.") else null
            },
            st("sort", 3, cards.size) { s, _ ->
                val (w, noun) = cards[s[0]]
                sortQ(w, "Noun", "Adjective", noun, if (noun) "${cap(w)} is a noun: it names something." else "${cap(w)} is an adjective: it describes.")
            },
        )
    }

    private val FIG_NAME = mapOf("s" to "Simile", "m" to "Metaphor", "p" to "Personification", "a" to "Alliteration", "o" to "Onomatopoeia", "h" to "Hyperbole")
    private val FIG_WHY = mapOf(
        "s" to "It compares using like or as, so it is a simile.", "m" to "It says one thing is another, so it is a metaphor.",
        "p" to "It gives a thing human actions, so it is personification.", "a" to "The same first sound repeats, so it is alliteration.",
        "o" to "The word sounds like the noise, so it is onomatopoeia.", "h" to "It exaggerates on purpose, so it is hyperbole.",
    )

    private fun figSkill(id: String, grade: Int, title: String, badge: String, key: String, sortPair: Pair<String, String>): GenSkill {
        val ls = rows(key).map { it[0].s to it[1].s }
        val kinds = ls.map { it.second }.distinct()
        val sortable = ls.filterIndexed { i, (_, k) -> i % 2 == 0 && (k == sortPair.first || k == sortPair.second) }
        return skill(
            id, grade, title, badge, "words",
            st("sort", 1, sortable.size) { s, _ ->
                val (l, k) = sortable[s[0]]
                sortQ(l, FIG_NAME[sortPair.first]!!, FIG_NAME[sortPair.second]!!, k == sortPair.first, FIG_WHY[k]!!)
            },
            qt("which", 2, ls.size) { s, r ->
                val (l, k) = ls[s[0]]
                ask("Which figure of speech is this? $l", FIG_NAME[k]!!, kinds.filter { it != k }.map { FIG_NAME[it]!! }, FIG_WHY[k]!!, r)
            },
            tft("tf", 3, ls.size, 2) { s, _ ->
                val (l, k) = ls[s[0]]
                val claim = if (s[1] == 0) k else kinds.filter { it != k }[s[0] % (kinds.size - 1)]
                val nm = FIG_NAME[claim]!!.lowercase()
                tf("\"$l\" is ${if (claim == "p") "" else "${art(nm)} "}$nm.", claim == k, FIG_WHY[k]!!)
            },
        )
    }

    private fun c6Fig() = figSkill("en6.figures", 6, "Simile or metaphor?", "like", "fig6", "s" to "m")

    // ================================================================ Class 7
    fun c7(): List<GenSkill> = listOf(c7Clauses(), c7Relative(), c7Cond(), c7RepQ(), c7Roots(), figSkill("en7.figures", 7, "Alliteration and more", "wow", "fig7", "a" to "o"),
        c7Colloc(), c7Punct(), c7Analogy2(), oneWordSkill("en7.oneword", 7, "One word for many", "1w", 6, 7), seqSkill("en7.sequence", 7, "Put events in order", "1-5", "seq7", short = false))

    private val CONJ_WHY = mapOf(
        "because" to "Because gives a reason.", "as" to "As can give a reason or a time.", "since" to "Since gives a reason.",
        "although" to "Although shows a surprising contrast.", "though" to "Though shows a surprising contrast.",
        "when" to "When tells us the time.", "if" to "If gives a condition.", "unless" to "Unless means if not.",
        "before" to "Before shows what happened first.", "after" to "After shows what happened later.", "while" to "While means at the same time.",
        "until" to "Until means up to that time.", "till" to "Till means up to that time.", "so" to "So that shows a purpose.",
    )

    private fun c7Clauses(): GenSkill {
        val cs = rows("clauses").map { listOf(it[0].s, it[1].s) to (it[2].ss to it[3].ss) }
        fun sent(main: String, sub: String, k: Int) = if (k == 0) "${cap(main)} $sub." else "${cap(sub)}, $main."
        return skill(
            "en7.clauses", 7, "Main and sub clauses", "cl", "grammar",
            qt("main", 1, cs.size, 2) { s, r ->
                val (main, sub) = cs[s[0]].first
                if (main.length > 24 || sub.length > 24) return@qt null
                ask("Which part is the main clause? ${sent(main, sub, s[1])}", main, listOf(sub), "${cap(main)} makes sense on its own.", r)
            },
            qt("sub", 2, cs.size, 2) { s, r ->
                val (main, sub) = cs[s[0]].first
                if (main.length > 24 || sub.length > 24) return@qt null
                ask("Which part is the subordinate clause? ${sent(main, sub, s[1])}", sub, listOf(main), "${cap(sub)} cannot stand alone.", r)
            },
            tft("tf", 2, cs.size, 2, 2) { s, _ ->
                val (main, sub) = cs[s[0]].first
                val x = if (s[2] == 0) main else sub
                val p = "In \"${sent(main, sub, s[1])}\" the main clause is \"$x\"."
                if (p.length > 90) return@tft null
                tf(p, s[2] == 0, "${cap(main)} makes sense on its own.")
            },
            qt("join", 3, cs.size) { s, r ->
                val (main, sub) = cs[s[0]].first
                val wrong = cs[s[0]].second.second
                val conj = if (sub.startsWith("so that")) "so that" else sub.substringBefore(" ")
                val rest = sub.removePrefix(conj).trim()
                ask("Pick the joining word: ${cap(main)} ___ $rest.", conj, wrong, CONJ_WHY[conj.substringBefore(" ")] ?: "It joins the two ideas.", r)
            },
        )
    }

    private fun c7Relative(): GenSkill {
        val ps = strs("relPerson"); val pc = strs("relPersonCl"); val pe = strs("relEnds")
        val th = strs("relThing"); val tc = strs("relThingCl"); val te = strs("relThingEnds")
        val wh = rows("relWhose").map { it.ss }
        val wr = rows("relWhere").map { it[0].s to it[1].s }
        val REL = listOf("who", "which", "whose", "where")
        return skill(
            "en7.relative", 7, "Who, which, whose", "who", "grammar",
            qt("who", 1, ps.size, pc.size) { s, r ->
                ask("${ps[s[0]]} ___ ${pc[s[1]]} ${pe[(s[0] + s[1]) % pe.size]}.", "who", REL - "who", "We use who for people.", r)
            },
            qt("which", 1, th.size, tc.size) { s, r ->
                ask("${th[s[0]]} ___ ${tc[s[1]]} ${te[(s[0] + s[1]) % te.size]}.", "which", REL - "which", "We use which for things.", r)
            },
            qt("whose", 2, wh.size) { s, r ->
                val (p, c, e) = wh[s[0]]
                ask("$p ___ $c $e.", "whose", REL - "whose", "Whose shows that something belongs to someone.", r)
            },
            qt("whereWhen", 2, wr.size) { s, r ->
                val (f, a) = wr[s[0]]
                ask(f, a, listOf("where", "when", "who", "which") - a, if (a == "where") "We use where for places." else "We use when for times.", r)
            },
            tft("tf", 3, ps.size, pc.size) { s, _ ->
                val ok = (s[0] + s[1]) % 2 == 0
                tf("${ps[s[0]]} ${if (ok) "who" else "which"} ${pc[s[1]]} ${pe[(s[0] + s[1]) % pe.size]}.", ok, "We use who, not which, for people.")
            },
        )
    }

    private fun c7Cond(): GenSkill {
        val rs = rows("cond1p").map { it[0].s to it[1].s }
        val subs = listOf("I" to "I", "you" to "you", "we" to "pl", "they" to "pl", "he" to "3s", "she" to "3s")
        val c0 = rows("cond0").map { Triple(it[0].s, it[1].s, it[2].ss) }
        val c2 = rows("cond2").map { Triple(it[0].s, it[1].s, it[2].ss) }
        val c1 = rows("cond1").map { listOf(it[0].s, it[1].s, it[2].s) to it[3].ss } 
        val c1If = rows("cond1If").map { Triple(it[0].s, it[1].s, it[2].ss) }
        fun vr(x: String) = x.substringBefore(" ") to x.substringAfter(" ", "")
        fun ph(v: String, rest: String) = if (rest.isEmpty()) v else "$v $rest"
        val W1 = "First conditional: if + present, then will + verb."
        val W2 = "Second conditional: if + past, then would + verb."
        val curated = c0.map { Triple(it.first, it.second, it.third) to "For facts that are always true, use the present." } +
            c2.map { Triple(it.first, it.second, it.third) to W2 } + c1If.map { Triple(it.first, it.second, it.third) to W1 } +
            c1.map { (a, w) -> Triple("${a[0]} ${a[1]}", a[2], w) to W1 }
        return skill(
            "en7.conditionals", 7, "If it rains…", "if", "grammar",
            qt("result1", 1, rs.size, subs.size) { s, r ->
                val (c, res) = rs[s[0]]; val (sb, k) = subs[s[1]]
                val (cv, cr) = vr(c); val (rv, rr) = vr(res)
                ask("If $sb ${ph(pres(k, cv), cr)}, $sb ___ $rr. ($rv)".replace(" .", "."), "will $rv", listOf("would $rv", pastOf(rv), ingOf(rv)), W1, r)
            },
            qt("if1", 1, rs.size, subs.size) { s, r ->
                val (c, res) = rs[s[0]]; val (sb, k) = subs[s[1]]
                val (cv, cr) = vr(c)
                ask("If $sb ___ $cr, $sb will $res. ($cv)".replace("___ ,", "___,"), pres(k, cv), listOf("will $cv", pastOf(cv), "would $cv"), W1, r)
            },
            qt("result2", 2, rs.size, subs.size) { s, r ->
                val (c, res) = rs[s[0]]; val (sb, _) = subs[s[1]]
                val (cv, cr) = vr(c); val (rv, rr) = vr(res)
                ask("If $sb ${ph(pastOf(cv), cr)}, $sb ___ $rr. ($rv)".replace(" .", "."), "would $rv", listOf("will $rv", pastOf(rv), ingOf(rv)), W2, r)
            },
            qt("if2", 2, rs.size, subs.size) { s, r ->
                val (c, res) = rs[s[0]]; val (sb, k) = subs[s[1]]
                val (cv, cr) = vr(c)
                if (pastOf(cv) == pres(k, cv)) return@qt null
                ask("If $sb ___ $cr, $sb would $res. ($cv)".replace("___ ,", "___,"), pastOf(cv), listOf(pres(k, cv), "will $cv", "would $cv"), W2, r)
            },
            qt("curated", 3, curated.size) { s, r ->
                val (q, why) = curated[s[0]]
                ask(q.first, q.second, q.third, why, r)
            },
        )
    }

    private fun c7RepQ(): GenSkill {
        val qs = rows("repq").map { listOf(it[0].s, it[1].s, it[2].s) to it[3].ss }
        val sp = strs("repqSpeakers")
        val female = setOf("Riya asked me", "Mum asked me")
        val cs = rows("repc").map { listOf(it[0].s, it[1].s, it[2].s) to it[3].ss }
        val csp = strs("repcSpeakers")
        val fem2 = setOf("Mum told me", "Grandma told me")
        fun needF(x: String) = " her " in " $x " || " she " in " $x "
        fun whyQ(rep: String, a: String) = if (rep.startsWith("if")) "A yes-or-no question is reported with if: $a." else "In a reported question, the verb moves back: $a."
        return skill(
            "en7.reportedq", 7, "Reported questions", "ask", "grammar",
            qt("question", 1, qs.size, sp.size) { s, r ->
                val (q, w) = qs[s[0]]; val (d, rep, a) = q; val who = sp[s[1]]
                if (needF(rep) && who !in female) return@qt null
                ask("$d $who $rep", a, w, whyQ(rep, a), r)
            },
            qt("command", 2, cs.size, csp.size) { s, r ->
                val (q, w) = cs[s[0]]; val (d, rep, a) = q; val who = csp[s[1]]
                if (needF(rep) && who !in fem2) return@qt null
                ask("$d $who $rep", a, w, if (a.startsWith("not")) "Do not becomes not to: $a." else "A command is reported with to and a verb: $a.", r)
            },
            tft("tf", 3, qs.size, sp.size, 2) { s, _ ->
                val (q, w) = qs[s[0]]; val (d, rep, a) = q; val who = sp[s[1]]
                if (needF(rep) && who !in female) return@tft null
                val fill = if (s[2] == 0) a else w[0]
                tf("$d becomes: $who ${rep.replace("___", fill)}", s[2] == 0, whyQ(rep, a))
            },
        )
    }

    private fun c7Roots(): GenSkill {
        val rs = rows("roots").map { Triple(it[0].s, it[1].s, it[2].ss) }
        val means = rs.map { it.second }.distinct()
        val allEx = rs.flatMap { it.third }.distinct()
        fun hasMeaning(w: String, m: String) = rs.any { it.second == m && w.contains(it.first) }
        return skill(
            "en7.roots", 7, "Roots: bio, tele", "bio", "words",
            qt("meaning", 1, rs.size, 3) { s, r ->
                val (root, m, ex) = rs[s[0]]
                val e = ex.getOrNull(s[1]) ?: return@qt null
                ask("What does '$root' mean in '$e'?", m, means.filter { it != m && !e.contains(rs.first { r0 -> r0.second == it }.first) }, "${cap(root)} means $m, as in $e.", r)
            },
            qt("which", 2, rs.size, 3) { s, r ->
                val (root, m, ex) = rs[s[0]]
                val e = ex.getOrNull(s[1]) ?: return@qt null
                ask("Which word has a root meaning '$m'?", e, allEx.filter { !hasMeaning(it, m) }, "${cap(e)} has $root, which means $m.", r)
            },
            tft("tf", 3, rs.size, 3, 2) { s, _ ->
                val (root, m, ex) = rs[s[0]]
                val e = ex.getOrNull(s[1]) ?: return@tft null
                if (s[2] == 0) tf("In '$e', '$root' means $m.", true, "${cap(root)} means $m.")
                else {
                    val o = means.filter { it != m }[(s[0] * 7 + s[1]) % (means.size - 1)]
                    tf("In '$e', '$root' means $o.", false, "${cap(root)} means $m, not $o.")
                }
            },
        )
    }

    private fun c7Colloc(): GenSkill {
        val md = map("makeDo"); val stl = map("sayTell")
        val mdL = md.flatMap { (v, ps) -> ps.map { it to v } }
        val stL = stl.flatMap { (v, ps) -> ps.map { it to v } }
        val mdSet = mdL.map { "___ ${it.first}" }.toSet()
        val vc = rows("verbColl").map { Triple(it[0].s, it[1].s, it[2].ss) }.filter { it.first !in mdSet }
        val ac = rows("adjColl").map { Triple(it[0].s, it[1].s, it[2].ss) }
        fun tfT(id: String, list: List<Pair<String, String>>, a: String, b: String) = tft(id, 3, list.size, 2) { s, _ ->
            val (p, v) = list[s[0]]
            val claim = if (s[1] == 0) v else (if (v == a) b else a)
            tf("We say \"$claim $p\".", claim == v, "We say $v $p.")
        }
        return skill(
            "en7.colloc", 7, "Make or do? Heavy rain", "do", "words",
            st("makeDo", 1, mdL.size) { s, _ ->
                val (p, v) = mdL[s[0]]
                sortQ("___ $p", "make", "do", v == "make", "We say $v $p.")
            },
            qt("verb", 1, vc.size) { s, r ->
                val (f, a, w) = vc[s[0]]
                ask(f, a, w, "We say ${f.replace("___", a)}.", r)
            },
            st("sayTell", 2, stL.size) { s, _ ->
                val (p, v) = stL[s[0]]
                sortQ("___ $p", "say", "tell", v == "say", "We say $v $p.")
            },
            qt("adj", 2, ac.size) { s, r ->
                val (f, a, w) = ac[s[0]]
                ask(f, a, w, "We say ${f.replace("___", a)}.", r)
            },
            tfT("mdTf", mdL, "make", "do"), tfT("stTf", stL, "say", "tell"),
        )
    }

    private fun c7Punct(): GenSkill {
        val starts = strs("punctListStart")
        val lists = obj("punctLists").mapValues { it.value.ss }
        val combos = (0 until nCk(6, 3).toInt()).map { combo(6, 3, it.toLong()) } + (0 until nCk(6, 4).toInt()).map { combo(6, 4, it.toLong()) }
        val semi = rows("punctSemi").map { it[0].s }
        val comma = rows("punctComma").map { it[0].s }
        val speech = rows("speech").map { it[0].s to it[1].s }
        val M = listOf("Colon (:)", "Semicolon (;)", "Comma (,)", "Question mark (?)", "Apostrophe (')")
        fun listText(st0: String, c: IntArray): String? {
            val items = c.map { lists[st0]!!.getOrNull(it) ?: return null }
            return items.dropLast(1).joinToString(", ") + " and " + items.last()
        }
        fun variants(n: String, w: String) = listOf("$n said, \"$w.\"", "$n said \"$w.\"", "$n said, $w.", "$n said, \"$w\"")
        return skill(
            "en7.punct", 7, "Colons, ; and quotes", ":", "writing",
            qt("colon", 1, starts.size, combos.size) { s, r ->
                val st0 = starts[s[0]]
                val lt = listText(st0, combos[s[1]]) ?: return@qt null
                ask("Which mark goes in the gap? ${st0}___ $lt.", M[0], listOf(M[1], M[2], M[3]), "A colon comes before a list.", r)
            },
            qt("semi", 2, semi.size) { s, r ->
                ask("Which mark goes in the gap? ${semi[s[0]]}", M[1], listOf(M[3], M[4]), "A semicolon joins two closely linked sentences.", r, n = 3)
            },
            qt("comma", 2, comma.size) { s, r ->
                val f = comma[s[0]]
                ask("Which mark goes in the gap? $f", M[2], listOf(M[0], M[1], M[3]), "A comma comes after ${f.substringBefore("___")} at the start.", r)
            },
            qt("speech", 2, speech.size) { s, r ->
                val (n, w) = speech[s[0]]
                val v = variants(n, w)
                if (v.any { it.length > 24 }) return@qt null
                ask("Which is punctuated correctly?", v[0], v.drop(1), "Put a comma before the spoken words, and quotes around them.", r)
            },
            tft("speechTf", 3, speech.size, 3) { s, _ ->
                val (n, w) = speech[s[0]]
                val v = variants(n, w)
                tf("This is punctuated correctly: ${v[s[1]]}", s[1] == 0, "Put a comma before the spoken words, and quotes around them.")
            },
            tft("colonTf", 3, starts.size, 12) { s, _ ->
                val st0 = starts[s[0]]
                val lt = listText(st0, combos[s[1] * 3]) ?: return@tft null
                val ok = s[1] % 2 == 0
                tf("This is punctuated correctly: $st0${if (ok) ":" else ";"} $lt.", ok, "A colon, not a semicolon, comes before a list.")
            },
        )
    }

    private fun c7Analogy2(): GenSkill {
        val an = obj("analogy2").mapValues { e -> e.value.jsonArray.map { it.jsonArray[0].s to it.jsonArray[1].s } }
        fun pl(c: String) = lex[c]?.plural ?: (c + "s")
        fun why(rel: String, c: String, d: String) = when (rel) {
            "part" -> "${cap(art(c))} $c is part of ${art(d)} $d."
            "tool" -> "${cap(art(d))} $d uses ${withArt(c)}."
            "place" -> "${cap(art(d))} $d is where ${art(c)} $c works."
            "syn" -> "${cap(c)} and $d mean the same."
            "opp" -> "${cap(c)} and $d are opposites."
            else -> "${cap(art(d))} $d is a group of ${pl(c)}."
        }
        fun tmpl(rel: String, tier: Int): Template {
            val rs = an[rel].orEmpty()
            return qt(rel, tier, rs.size, rs.size) { s, r ->
                if (s[0] == s[1]) return@qt null
                val (a, b) = rs[s[0]]; val (c, d) = rs[s[1]]
                if (b == d) return@qt null
                ask("${cap(a)} is to $b as $c is to ___.", d, rs.map { it.second }.filter { it != d } , why(rel, c, d), r)
            }
        }
        return skill("en7.analogy", 7, "Analogies: part, tool", "::", "words",
            tmpl("syn", 1), tmpl("opp", 1), tmpl("part", 2), tmpl("group", 2), tmpl("tool", 3), tmpl("place", 3))
    }
}
