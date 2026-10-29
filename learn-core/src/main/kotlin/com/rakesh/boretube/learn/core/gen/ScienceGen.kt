package com.rakesh.boretube.learn.core.gen

import com.rakesh.boretube.learn.core.Format
import com.rakesh.boretube.learn.core.GenSkill
import com.rakesh.boretube.learn.core.Maths
import com.rakesh.boretube.learn.core.Opt
import com.rakesh.boretube.learn.core.Template
import com.rakesh.boretube.learn.core.Visual
import com.rakesh.boretube.learn.core.gq
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlin.random.Random

/**
 * Generated Science skills for Classes 6 and 7 (NCERT Curiosity, spec P2b).
 * [data] reads a file from content/data by name; the tables live in
 * `science.json` (built by boretube-learn/tools/content/data/science_data.py).
 * Skills are subject "evs" (the Nature Trail land), ids `sc6.*` / `sc7.*`.
 *
 * Most skills are made from classification tables by the same few kinds of
 * question (name the class, true/false, sort, pick one, "A or B, both or
 * neither?"), plus curated facts, orders and chains, and a few skills of
 * pure rules with exact integer arithmetic (length, temperature, speed,
 * time, mirrors).
 */
object ScienceGen {
    private val json = Json { ignoreUnknownKeys = true }

    fun skills(data: (String) -> String?): List<GenSkill> {
        val text = data("science.json") ?: return emptyList()
        val d = try {
            json.decodeFromString(SciData.serializer(), text)
        } catch (_: Exception) {
            return emptyList()
        }
        return Build(d).skills()
    }
}

@Serializable
internal class SciData(
    val tables: Map<String, STable> = emptyMap(),
    val facts: Map<String, List<SFact>> = emptyMap(),
    val tfs: Map<String, List<STf>> = emptyMap(),
    val orders: Map<String, List<SOrder>> = emptyMap(),
    val chains: Map<String, List<SChain>> = emptyMap(),
    val movers: List<SMover> = emptyList(),
)

@Serializable
internal class STable(val ask: String = "", val card: String = "{X}", val classes: List<SClass>, val items: List<SRow>)

@Serializable
internal class SClass(val id: String, val label: String, val sing: String, val both: String = "", val which: String = "", val why: String)

@Serializable
internal class SRow(
    val x: String,
    val np: String = "",
    val c: String,
    val also: List<String> = emptyList(),
    val skip: List<String> = emptyList(),
    val why: String = "",
    val pic: String = "",
    val src: String = "",
)

@Serializable
internal class SFact(val q: String, val a: String, val w: List<String>, val why: String, val t: Int = 1, val pic: String = "", val src: String = "")

@Serializable
internal class STf(val s: String, val v: Boolean, val why: String, val t: Int = 1, val pic: String = "", val src: String = "")

@Serializable
internal class SOrder(val ask: String, val items: List<String>, val why: String, val t: Int = 2, val min: Int = 3, val max: Int = 5, val src: String = "")

@Serializable
internal class SChain(
    val id: String,
    val items: List<String>,
    val art: String = "",
    val t: Int = 2,
    val why: String,
    val next: String = "",
    val prev: String = "",
    val adj: String = "",
    val cmp: String = "",
    val cmpWhy: String = "",
    val pos: String = "",
    val cyclic: Boolean = false,
    val src: String = "",
)

@Serializable
internal class SMover(
    val x: String,
    val np: String,
    val unit: String,
    val du: String,
    val tu: String,
    val speeds: List<Int>,
    val times: List<Int>,
    val pic: String = "",
    val src: String = "",
)

/** Which generic templates a table gives a skill, and at what tier (0 = none). */
private class Use(
    val name: String,
    val classify: Int = 1,
    val tf: Int = 1,
    val sort: Int = 0,
    /** Sort baskets (class ids) for a table with more than two classes. */
    val sortPair: Pair<String, String>? = null,
    val pick: Int = 2,
    /** 0 = default (2 for two classes, 3 for more). */
    val pair: Int = 0,
)

private class Build(val d: SciData) {
    // ------------------------------------------------------------ text helpers

    private fun cap(s: String) = s.replaceFirstChar { it.uppercaseChar() }

    private fun fits(s: String) =
        s.isNotBlank() && Maths.wordCount(s) <= Maths.MAX_EXPLAIN_WORDS && s.endsWith(".") && !Regex("[.!?]\\s").containsMatchIn(s)

    /** The first explanation that fits the rules (one sentence, ≤ 12 words). */
    private fun ex(vararg c: String): String = c.firstOrNull { fits(it) } ?: c.last()

    private fun np(r: SRow) = r.np.ifBlank { r.x }

    private fun fill(f: String, r: SRow) =
        f.replace("{X}", cap(r.x)).replace("{x}", r.x).replace("{Np}", cap(np(r))).replace("{np}", np(r))

    private fun pic(id: String): Visual? = id.takeIf { it.isNotBlank() }?.let { Visual.Picture(it) }

    /** Indian grouping from 10,000 up (1000 stays plain, as NCERT writes it). */
    private fun num(n: Int): String {
        val neg = n < 0
        val s = kotlin.math.abs(n).toString()
        if (s.length <= 4) return (if (neg) "−" else "") + s
        val last3 = s.takeLast(3)
        var rest = s.dropLast(3)
        val parts = ArrayList<String>()
        while (rest.length > 2) { parts.add(0, rest.takeLast(2)); rest = rest.dropLast(2) }
        if (rest.isNotEmpty()) parts.add(0, rest)
        return (if (neg) "−" else "") + parts.joinToString(",") + "," + last3
    }

    private fun deg(v: Int) = (if (v < 0) "−${-v}" else "$v") + " °C"

    /** Tenths as a one-place decimal: 374 → "37.4". */
    private fun tenths(v: Int) = if (v % 10 == 0) "${v / 10}" else "${v / 10}.${v % 10}"

    private fun plural(n: Int, unit: String) = if (n == 1) "1 $unit" else "$n ${unit}s"

    /** [ans] plus the first distinct wrongs among [cands] (up to 3), shuffled. */
    private fun opts(ans: String, cands: List<String>, r: Random): Pair<List<String>, Int>? {
        val w = cands.filter { it != ans }.distinct().take(3)
        if (w.size < 2) return null
        return Opt.of(ans, w, r)
    }

    private fun opts(ans: Int, cands: List<Int>, r: Random, f: (Int) -> String): Pair<List<String>, Int>? =
        opts(f(ans), cands.filter { it > 0 && it != ans }.distinct().map(f), r)

    // ------------------------------------------------------------ tables

    private fun truth(r: SRow, cls: String): Boolean? = when {
        r.c == cls || cls in r.also -> true
        cls in r.skip -> null
        else -> false
    }

    private val pairCache = HashMap<Int, List<IntArray>>()

    private fun pairsOf(n: Int): List<IntArray> = pairCache.getOrPut(n) {
        val out = ArrayList<IntArray>()
        for (i in 0 until n) for (j in i + 1 until n) out += intArrayOf(i, j)
        out
    }

    private fun tableTemplates(u: Use): List<Template> {
        val t = d.tables[u.name] ?: return emptyList()
        val cls = t.classes
        val byId = cls.associateBy { it.id }
        val items = t.items
        val out = ArrayList<Template>()
        val k = u.name

        if (u.classify > 0) out += Template("${k}C", u.classify, intArrayOf(items.size)) { s, r ->
            val row = items[s[0]]
            val me = byId[row.c] ?: return@Template null
            val wrong = cls.filter { truth(row, it.id) == false }
            val labels = if (cls.size <= 4) {
                cls.filter { it.id == row.c || it in wrong }.map { it.label }
            } else {
                (wrong.shuffled(r).take(3) + me).map { it.label }.shuffled(r)
            }
            if (labels.size < 2 || (cls.size > 2 && labels.size < 3)) return@Template null
            gq(fill(t.ask, row), labels to labels.indexOf(me.label), ex(row.why, me.why), visual = pic(row.pic))
        }

        if (u.tf > 0) out += Template("${k}T", u.tf, intArrayOf(items.size, cls.size), Format.truefalse) { s, _ ->
            val row = items[s[0]]
            val c = cls[s[1]]
            val v = truth(row, c.id) ?: return@Template null
            val real = byId[row.c] ?: return@Template null
            val why = if (v) ex(if (row.c == c.id) row.why else "", "${cap(np(row))} ${c.sing}.", c.why)
            else ex(row.why, "${cap(np(row))} ${real.sing}.", real.why)
            gq("${cap(np(row))} ${c.sing}.", Opt.trueFalse(v), why, visual = pic(row.pic))
        }

        if (u.sort > 0) {
            val (l, rt) = u.sortPair?.let { byId[it.first] to byId[it.second] } ?: (cls.getOrNull(0) to cls.getOrNull(1))
            if (l != null && rt != null) out += Template("${k}S", u.sort, intArrayOf(items.size), Format.sort) { s, _ ->
                val row = items[s[0]]
                val a = truth(row, l.id) ?: return@Template null
                val b = truth(row, rt.id) ?: return@Template null
                if (a == b) return@Template null
                gq(fill(t.card, row), Opt.baskets(l.label, rt.label, a), ex(row.why, if (a) l.why else rt.why), visual = pic(row.pic))
            }
        }

        cls.forEachIndexed { ci, c ->
            if (c.which.isBlank()) return@forEachIndexed
            if (u.pick > 0) out += Template("${k}K$ci", u.pick, intArrayOf(items.size)) { s, r ->
                val row = items[s[0]]
                if (truth(row, c.id) != true) return@Template null
                val wrongs = items.filter { truth(it, c.id) == false }.map { it.x }.shuffled(r)
                if (wrongs.size < 3) return@Template null
                gq("${c.which}?", Opt.of(row.x, wrongs, r) ?: return@Template null, ex(if (row.c == c.id) row.why else "", c.why))
            }
            val pt = if (u.pair > 0) u.pair else if (cls.size > 2) 3 else 2
            val pairs = pairsOf(items.size)
            out += Template("${k}P$ci", pt, intArrayOf(pairs.size)) { s, _ ->
                val (i, j) = pairs[s[0]].let { it[0] to it[1] }
                val a = items[i]
                val b = items[j]
                val ta = truth(a, c.id) ?: return@Template null
                val tb = truth(b, c.id) ?: return@Template null
                if (!ta && !tb && (i * 31 + j * 17 + ci) % (if (cls.size > 2) 3 else 2) != 0) return@Template null
                val prompt = "${c.which}: ${a.x} or ${b.x}?"
                if (prompt.length > 90) return@Template null
                val options = listOf(a.x, b.x, "Both", "Neither")
                if (options.map { it.lowercase() }.toSet().size != 4) return@Template null
                val ans = when { ta && tb -> 2; ta -> 0; tb -> 1; else -> 3 }
                val why = when (ans) {
                    2 -> ex(if (c.both.isNotBlank()) "${cap(np(a))} and ${np(b)} ${c.both}." else "", c.why)
                    3 -> ex("Neither ${np(a)} nor ${np(b)} ${c.sing}.", c.why)
                    else -> {
                        val (y, n) = if (ans == 0) a to b else b to a
                        val nc = byId[n.c]
                        ex(if (nc != null) "${cap(np(y))} ${c.sing}; ${np(n)} ${nc.sing}." else "", "Only ${np(y)} ${c.sing}.", c.why)
                    }
                }
                gq(prompt, options to ans, why)
            }
        }
        return out
    }

    // ------------------------------------------------------------ facts, statements, orders, chains

    private fun factTemplates(skill: String): List<Template> {
        val out = ArrayList<Template>()
        d.facts[skill].orEmpty().groupBy { it.t.coerceIn(1, 3) }.toSortedMap().forEach { (tier, fs) ->
            out += Template("F$tier", tier, intArrayOf(fs.size)) { s, r ->
                val f = fs[s[0]]
                gq(f.q, Opt.of(f.a, f.w.shuffled(r), r) ?: return@Template null, f.why, visual = pic(f.pic))
            }
        }
        d.tfs[skill].orEmpty().groupBy { it.t.coerceIn(1, 3) }.toSortedMap().forEach { (tier, ts) ->
            out += Template("V$tier", tier, intArrayOf(ts.size), Format.truefalse) { s, _ ->
                val f = ts[s[0]]
                gq(f.s, Opt.trueFalse(f.v), f.why, visual = pic(f.pic))
            }
        }
        return out
    }

    private class OrderQ(val ask: String, val items: List<String>, val why: String)

    private fun subsets(n: Int, k: Int): List<IntArray> {
        val out = ArrayList<IntArray>()
        fun go(start: Int, acc: IntArray, depth: Int) {
            if (depth == k) { out += acc.copyOf(); return }
            for (i in start until n) { acc[depth] = i; go(i + 1, acc, depth + 1) }
        }
        go(0, IntArray(k), 0)
        return out
    }

    private fun orderTemplates(skill: String): List<Template> {
        val byTier = sortedMapOf<Int, MutableList<OrderQ>>()
        for (o in d.orders[skill].orEmpty()) {
            val n = o.items.size
            for (k in maxOf(3, o.min)..minOf(5, o.max, n)) for (sub in subsets(n, k)) {
                byTier.getOrPut(o.t.coerceIn(1, 3)) { ArrayList() } += OrderQ(o.ask, sub.map { o.items[it] }, o.why)
            }
        }
        return byTier.map { (tier, qs) ->
            Template("O$tier", tier, intArrayOf(qs.size), Format.order) { s, r ->
                val q = qs[s[0]]
                val shown = q.items.shuffled(r)
                gq(q.ask, shown to shown.indexOf(q.items[0]), q.why, fact = q.items.joinToString(" → "), order = q.items)
            }
        }
    }

    private val ORD = listOf("first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth")

    private fun chainTemplates(skill: String): List<Template> {
        val out = ArrayList<Template>()
        d.chains[skill].orEmpty().forEachIndexed { ix, c ->
            val xs = c.items
            val n = xs.size
            fun after(i: Int) = if (i + 1 < n) i + 1 else if (c.cyclic) 0 else -1
            fun before(i: Int) = if (i > 0) i - 1 else if (c.cyclic) n - 1 else -1
            fun the(s: String) = c.art + s
            if (c.next.isNotBlank()) out += Template("N$ix", c.t, intArrayOf(n, 2)) { s, r ->
                val i = s[0]
                val j = if (s[1] == 0) after(i) else before(i)
                if (j < 0) return@Template null
                val wrongs = xs.filterIndexed { k, _ -> k != i && k != j }.shuffled(r)
                if (wrongs.size < 2) return@Template null
                val prompt = (if (s[1] == 0) c.next else c.prev).replace("{x}", xs[i])
                val why = if (s[1] == 0) ex(cap("after ${the(xs[i])} comes ${the(xs[j])}."), c.why)
                else ex(cap("just before ${the(xs[i])} comes ${the(xs[j])}."), c.why)
                gq(prompt, Opt.of(xs[j], wrongs, r) ?: return@Template null, why)
            }
            if (c.adj.isNotBlank()) out += Template("A$ix", c.t, intArrayOf(n, n), Format.truefalse) { s, _ ->
                val (a, b) = s[0] to s[1]
                if (a == b) return@Template null
                val v = after(a) == b
                if (after(a) < 0) return@Template null
                val st = cap(c.adj.replace("{a}", xs[a]).replace("{b}", xs[b]))
                gq(st, Opt.trueFalse(v), ex(cap("after ${the(xs[a])} comes ${the(xs[after(a)])}."), c.why))
            }
            if (c.cmp.isNotBlank()) out += Template("M$ix", 3, intArrayOf(n, n), Format.truefalse) { s, _ ->
                val (a, b) = s[0] to s[1]
                if (a == b) return@Template null
                val st = cap(c.cmp.replace("{a}", xs[a]).replace("{b}", xs[b]))
                val why = c.cmpWhy.replace("{A}", cap(xs[a])).replace("{a}", xs[a]).replace("{b}", xs[b])
                    .replace("{i}", "${a + 1}").replace("{j}", "${b + 1}")
                gq(st, Opt.trueFalse(a < b), ex(why, c.why))
            }
            if (c.pos.isNotBlank()) out += Template("Q$ix", 1, intArrayOf(n)) { s, r ->
                val i = s[0]
                val wrongs = listOf(i - 1, i + 1, i - 2, i + 2).filter { k -> k in 0 until n }.map { k -> xs[k] }
                gq(c.pos.replace("{n}", ORD[i]), Opt.of(xs[i], wrongs, r) ?: return@Template null, c.why)
            }
        }
        return out
    }

    // ------------------------------------------------------------ rule skills

    /** sc6.length: metric conversions with exact integers. */
    private fun lengthTemplates(): List<Template> {
        val units = listOf(Triple("km", "m", 1000), Triple("m", "cm", 100), Triple("cm", "mm", 10))
        val maxBig = listOf(20, 50, 50)
        val conv = Template("Lconv", 1, intArrayOf(6, 50)) { s, r ->
            val (big, small, f) = units[s[0] % 3]
            val n = s[1] + 1
            if (n > maxBig[s[0] % 3]) return@Template null
            if (s[0] < 3) {
                val ans = n * f
                gq("$n $big = ___ $small", opts(ans, listOf(ans * 10, ans / 10, n * (f / 10).coerceAtLeast(1) * 100, ans + f), r) { num(it) }
                    ?: return@Template null, "1 $big = ${num(f)} $small, so $n $big = ${num(ans)} $small.")
            } else {
                val v = n * f
                gq("${num(v)} $small = ___ $big", opts(n, listOf(n * 10, n * 100, v / 100, n + 1), r) { num(it) }
                    ?: return@Template null, "1 $big = ${num(f)} $small, so ${num(v)} $small = $n $big.")
            }
        }
        // a big + b small, where b runs in steps that fit the unit.
        fun small(kind: Int, b: Int): Int? = when (kind) {
            0 -> (b + 1) * 50
            1 -> (b + 1) * 5
            else -> (b + 1).takeIf { it <= 9 }
        }
        fun mixed(a: Int, big: String, b: Int, sm: String) = if (b == 0) "$a $big" else "$a $big $b $sm"
        val join = Template("Ljoin", 2, intArrayOf(3, 9, 19)) { s, r ->
            val (big, sm, f) = units[s[0]]
            val a = s[1] + 1
            val b = small(s[0], s[2]) ?: return@Template null
            val ans = a * f + b
            gq("$a $big $b $sm = ___ $sm", opts(ans, listOf(a * f * 10 + b, a * (f / 10) + b, a * f + b * 10, ans + f), r) { num(it) }
                ?: return@Template null, "$a $big = ${num(a * f)} $sm, and ${num(a * f)} + $b = ${num(ans)} $sm.")
        }
        val split = Template("Lsplit", 2, intArrayOf(3, 9, 19)) { s, r ->
            val (big, sm, f) = units[s[0]]
            val a = s[1] + 1
            val b = small(s[0], s[2]) ?: return@Template null
            val ans = a * f + b
            val c = listOf(mixed(a * 10, big, b, sm), mixed(a, big, b * 10, sm).takeIf { b * 10 < f * 10 } ?: "", mixed(a + 1, big, b, sm),
                if (a > 1) mixed(a - 1, big, b, sm) else "").filter { it.isNotBlank() }
            gq("${num(ans)} $sm = ___", opts(mixed(a, big, b, sm), c, r) ?: return@Template null,
                "${num(ans)} = ${num(a * f)} + $b, so it is ${mixed(a, big, b, sm)}.")
        }
        val deltas = listOf(-50, -45, -10, -5, 0, 5, 10, 45, 50)
        val longer = Template("Llonger", 3, intArrayOf(5, 20, deltas.size)) { s, _ ->
            val m = s[0] + 1
            val c = s[1] * 5
            val a = m * 100 + c
            val b = a + deltas[s[2]]
            val aS = mixed(m, "m", c, "cm")
            val bS = "$b cm"
            val ans = when { a > b -> 0; b > a -> 1; else -> 2 }
            val why = when (ans) {
                0 -> "$aS = $a cm, more than $b cm."
                1 -> "$aS = $a cm, less than $b cm."
                else -> "$aS = $a cm, the same as $b cm."
            }
            gq("Which is longer: $aS or $bS?", listOf(aS, bS, "both are equal") to ans, why)
        }
        val add = Template("Ladd", 3, intArrayOf(4, 9, 4, 9)) { s, r ->
            val m1 = s[0] + 1; val c1 = (s[1] + 1) * 10; val m2 = s[2] + 1; val c2 = (s[3] + 1) * 10
            val tot = m1 * 100 + c1 + m2 * 100 + c2
            val ans = mixed(tot / 100, "m", tot % 100, "cm")
            val c = listOf(
                if (c1 + c2 >= 100) "${m1 + m2} m ${c1 + c2} cm" else "",
                mixed(tot / 100 + 1, "m", tot % 100, "cm"),
                mixed(tot / 100 - 1, "m", tot % 100, "cm").takeIf { tot / 100 > 1 } ?: "",
                mixed(tot / 100, "m", (tot % 100 + 10) % 100, "cm"),
            ).filter { it.isNotBlank() }
            gq("One ribbon is ${mixed(m1, "m", c1, "cm")} and another is ${mixed(m2, "m", c2, "cm")}. What is their total length?",
                opts(ans, c, r) ?: return@Template null, "${m1 * 100 + c1} cm + ${m2 * 100 + c2} cm = $tot cm, which is $ans.")
        }
        return listOf(conv, join, split, longer, add)
    }

    /** sc6.temperature: reading scales, ranges, rises and falls (whole degrees and tenths). */
    private fun tempTemplates(): List<Template> {
        val lab = Template("Hlab", 1, intArrayOf(13, 9)) { s, r ->
            val k = s[1] + 1
            if (s[0] == 12) {
                val v = -k
                return@Template gq("Each small mark is 1 °C. The liquid ends $k marks below 0 °C. What is the reading?",
                    opts(deg(v), listOf(deg(k), deg(v - 1), deg(v + 1).takeIf { v + 1 < 0 } ?: deg(10 - k)), r) ?: return@Template null,
                    "Marks below 0 °C count down: −1, −2, −3 and so on.")
            }
            val base = s[0] * 10 - 10
            val v = base + k
            if (v > 110) return@Template null
            gq("Each small mark is 1 °C. The liquid ends $k marks above ${deg(base)}. What is the reading?",
                opts(deg(v), listOf(deg(v + 1), deg(v - 1), deg(base + 10 - k), deg(base + 10 * k).takeIf { base + 10 * k <= 110 } ?: deg(v + 2)), r)
                    ?: return@Template null, "$k marks of 1 °C above ${deg(base)} gives ${deg(v)}.")
        }
        val clin = Template("Hclin", 2, intArrayOf(7, 9)) { s, r ->
            val b = 35 + s[0]
            val k = s[1] + 1
            val v = b * 10 + k
            val c = listOf(v + 1, v - 1, v + 10, v - 10).filter { it in 351..419 && it % 10 != 0 }.map { "${tenths(it)} °C" }
            gq("A clinical thermometer has marks of 0.1 °C. The liquid ends $k marks above $b °C. Reading?",
                opts("${tenths(v)} °C", c, r) ?: return@Template null, "$k marks of 0.1 °C above $b °C gives ${tenths(v)} °C.")
        }
        val clinVals = listOf(-5, 0, 10, 20, 25, 30, 36, 37, 38, 39, 40, 41, 45, 50, 60, 80, 100)
        val labVals = listOf(-20, -15, -5, 0, 20, 37, 50, 80, 100, 105, 120, 150, 200)
        val canClin = Template("Hcan", 2, intArrayOf(2, 17), Format.truefalse) { s, _ ->
            if (s[0] == 0) {
                val t = clinVals[s[1]]
                gq("A clinical thermometer can measure ${deg(t)}.", Opt.trueFalse(t in 35..42), "A clinical thermometer reads only from 35 °C to 42 °C.")
            } else {
                val t = labVals.getOrNull(s[1]) ?: return@Template null
                gq("A laboratory thermometer can measure ${deg(t)}.", Opt.trueFalse(t in -10..110), "A lab thermometer reads from about −10 °C to 110 °C.")
            }
        }
        val fever = listOf(365, 368, 370, 372, 380, 385, 390, 395, 400, 405)
        val feverT = Template("Hfever", 2, intArrayOf(fever.size), Format.truefalse) { s, _ ->
            val v = fever[s[0]]
            gq("A body temperature of ${tenths(v)} °C means a fever.", Opt.trueFalse(v >= 380),
                if (v >= 380) "A fever is a body temperature well above 37 °C." else "Normal body temperature is about 37 °C.")
        }
        val rise = Template("Hrise", 2, intArrayOf(19, 14)) { s, r ->
            val a = 12 + s[0]
            val up = 2 + s[1]
            val b = a + up
            if (b > 45) return@Template null
            gq("Morning: $a °C. Afternoon: $b °C. By how much did the temperature rise?",
                opts(up, listOf(a + b, up + 1, up - 1, b), r) { "$it °C" } ?: return@Template null, "$b − $a = $up, so it rose by $up °C.")
        }
        val fall = Template("Hfall", 3, intArrayOf(14, 10)) { s, r ->
            val day = 2 + s[0]
            val night = -(s[1] + 1)
            val drop = day - night
            gq("In Leh one winter day it was ${deg(day)} by day and ${deg(night)} at night. How much did it fall?",
                opts(drop, listOf(day + night, drop + 1, drop - 1, -night), r) { "$it °C" } ?: return@Template null,
                "${deg(day)} to 0 °C is $day, then ${-night} more makes $drop.")
        }
        val vals = listOf(-15, -10, -8, -5, -3, -1, 0, 2, 5, 8, 12, 15, 20, 25, 30, 37, 40)
        fun cmp(id: String, tier: Int, neg: Boolean) = Template(id, tier, intArrayOf(vals.size, vals.size, 2)) { s, _ ->
            val (i, j) = s[0] to s[1]
            if (i >= j) return@Template null
            val a = vals[i]; val b = vals[j]
            if ((a < 0 || b < 0) != neg) return@Template null
            val cold = s[2] == 0
            val ans = if (cold) 0 else 1
            gq("Which is ${if (cold) "colder" else "hotter"}: ${deg(a)} or ${deg(b)}?", listOf(deg(a), deg(b)) to ans,
                if (cold) "On the scale, ${deg(a)} is below ${deg(b)}, so colder." else "On the scale, ${deg(b)} is above ${deg(a)}, so hotter.")
        }
        return listOf(lab, clin, canClin, feverT, rise, fall, cmp("Hcmp1", 1, false), cmp("Hcmp2", 2, true))
    }

    /** sc7.speed: speed = distance ÷ time on realistic movers, exact integers. */
    private fun speedTemplates(): List<Template> {
        val mv = d.movers
        if (mv.isEmpty()) return emptyList()
        val maxS = mv.maxOf { it.speeds.size }
        val maxT = mv.maxOf { it.times.size }
        fun tu(m: SMover, t: Int) = plural(t, m.tu)
        val speed = Template("Sspeed", 1, intArrayOf(mv.size, maxS, maxT)) { s, r ->
            val m = mv[s[0]]; val sp = m.speeds.getOrNull(s[1]) ?: return@Template null; val t = m.times.getOrNull(s[2]) ?: return@Template null
            val dist = sp * t
            gq("${cap(m.np)} covers ${num(dist)} ${m.du} in ${tu(m, t)}. What is its speed?",
                opts(sp, listOf(if (t > 1) dist * t else 0, if (t > 1) dist else 0, sp + 5, sp * 2, sp + 10), r) { "$it ${m.unit}" } ?: return@Template null,
                "Speed = distance ÷ time = ${num(dist)} ÷ $t = $sp ${m.unit}.", visual = pic(m.pic))
        }
        val far = Template("Sdist", 2, intArrayOf(mv.size, maxS, maxT)) { s, r ->
            val m = mv[s[0]]; val sp = m.speeds.getOrNull(s[1]) ?: return@Template null; val t = m.times.getOrNull(s[2]) ?: return@Template null
            if (t == 1) return@Template null
            val dist = sp * t
            gq("${cap(m.np)} moves at $sp ${m.unit} for ${tu(m, t)}. How far does it go?",
                opts(dist, listOf(sp + t, dist + sp, dist - sp, sp), r) { "${num(it)} ${m.du}" } ?: return@Template null,
                "Distance = speed × time = $sp × $t = ${num(dist)} ${m.du}.", visual = pic(m.pic))
        }
        val time = Template("Stime", 2, intArrayOf(mv.size, maxS, maxT)) { s, r ->
            val m = mv[s[0]]; val sp = m.speeds.getOrNull(s[1]) ?: return@Template null; val t = m.times.getOrNull(s[2]) ?: return@Template null
            val dist = sp * t
            val step = if (m.times.size > 1) m.times[1] - m.times[0] else 1
            gq("${cap(m.np)} covers ${num(dist)} ${m.du} at $sp ${m.unit}. How long does it take?",
                opts(t, listOf(t + step, t - step, t * 2, t + 2 * step), r) { tu(m, it) } ?: return@Template null,
                "Time = distance ÷ speed = ${num(dist)} ÷ $sp = ${tu(m, t)}.", visual = pic(m.pic))
        }
        val cmp = Template("Scmp", 3, intArrayOf(mv.size, 20, 20)) { s, _ ->
            val m = mv[s[0]]
            if (s[1] == s[2]) return@Template null
            val s1 = m.speeds.getOrNull(s[1] / 4) ?: return@Template null; val t1 = m.times.getOrNull(s[1] % 4) ?: return@Template null
            val s2 = m.speeds.getOrNull(s[2] / 4) ?: return@Template null; val t2 = m.times.getOrNull(s[2] % 4) ?: return@Template null
            if (t1 == t2) return@Template null
            val name = m.x
            val ans = when { s1 > s2 -> 0; s2 > s1 -> 1; else -> 2 }
            gq("${cap(name)} A covers ${num(s1 * t1)} ${m.du} in ${tu(m, t1)}; ${name} B covers ${num(s2 * t2)} ${m.du} in ${tu(m, t2)}. Which is faster?",
                listOf("${name} A", "${name} B", "same speed") to ans,
                "${cap(name)} A goes $s1 ${m.unit}; ${name} B goes $s2 ${m.unit}.", visual = pic(m.pic))
        }
        val unit = Template("Sunit", 3, intArrayOf(10, 2)) { s, r ->
            val k = s[0] + 1
            val kmh = 18 * k; val ms = 5 * k
            if (s[1] == 0) gq("$kmh km/h = ___ m/s", opts(ms, listOf(kmh, ms * 2, ms + 1, ms * 10), r) { "$it m/s" } ?: return@Template null,
                "18 km/h = 5 m/s, so $kmh km/h = $ms m/s.")
            else gq("$ms m/s = ___ km/h", opts(kmh, listOf(ms, kmh + 18, ms * 60, kmh * 2), r) { "$it km/h" } ?: return@Template null,
                "5 m/s = 18 km/h, so $ms m/s = $kmh km/h.")
        }
        val uniform = Template("Sunif", 2, intArrayOf(mv.size, maxS, 4), Format.truefalse) { s, _ ->
            val m = mv[s[0]]; val sp = m.speeds.getOrNull(s[1]) ?: return@Template null
            val ds = when (s[2]) { 0 -> listOf(sp, sp, sp); 1 -> listOf(sp, 2 * sp, sp); 2 -> listOf(2 * sp, sp, sp); else -> listOf(sp, sp, 2 * sp) }
            val v = s[2] == 0
            gq("${cap(m.np)} covers ${ds[0]} ${m.du}, then ${ds[1]} ${m.du}, then ${ds[2]} ${m.du}, one each ${m.tu}. Its motion is uniform.",
                Opt.trueFalse(v), if (v) "Equal distances in equal times means uniform motion." else "Unequal distances in equal times means non-uniform motion.")
        }
        return listOf(speed, far, time, cmp, unit, uniform)
    }

    /** sc7.timePendulum: time units and pendulum periods (tenths of a second). */
    private fun timeTemplates(): List<Template> {
        val kinds = listOf(Triple("hour", "minute", 60), Triple("minute", "second", 60), Triple("day", "hour", 24))
        val maxN = listOf(12, 30, 7)
        val conv = Template("Tconv", 1, intArrayOf(6, 30)) { s, r ->
            val (big, sm, f) = kinds[s[0] % 3]
            val n = s[1] + 1
            if (n > maxN[s[0] % 3]) return@Template null
            if (s[0] < 3) gq("${plural(n, big)} = ___ ${sm}s", opts(n * f, listOf(n * 100, n * 10, n * f + f, n * f - f), r) { num(it) } ?: return@Template null,
                "1 $big = $f ${sm}s, so ${plural(n, big)} = ${num(n * f)} ${sm}s.")
            else gq("${num(n * f)} ${sm}s = ___ ${if (n == 1) big else big + "s"}", opts(n, listOf(n * 10, n + 1, n * f / 100, n * 2), r) { num(it) }
                ?: return@Template null, "1 $big = $f ${sm}s, so ${num(n * f)} ${sm}s = ${plural(n, big)}.")
        }
        fun both(a: Int, big: String, b: Int, sm: String) = "${plural(a, big)} ${plural(b, sm)}"
        val join = Template("Tjoin", 2, intArrayOf(2, 9, 11)) { s, r ->
            val (big, sm, _) = kinds[s[0]]
            val a = s[1] + 1; val b = (s[2] + 1) * 5
            val ans = a * 60 + b
            gq("${both(a, big, b, sm)} = ___ ${sm}s", opts(ans, listOf(a * 100 + b, a * 10 + b, ans + 60, ans + 10), r) { num(it) } ?: return@Template null,
                "${plural(a, big)} = ${a * 60} ${sm}s, plus $b makes $ans.")
        }
        val split = Template("Tsplit", 2, intArrayOf(2, 9, 11)) { s, r ->
            val (big, sm, _) = kinds[s[0]]
            val a = s[1] + 1; val b = (s[2] + 1) * 5
            val tot = a * 60 + b
            val c = listOf(if (tot >= 100 && tot % 100 < 60) both(tot / 100, big, tot % 100, sm) else "", both(a + 1, big, b, sm),
                if (b + 10 < 60) both(a, big, b + 10, sm) else "", if (a > 1) both(a - 1, big, b, sm) else "").filter { it.isNotBlank() }
            gq("$tot ${sm}s = ___", opts(both(a, big, b, sm), c, r) ?: return@Template null, "$tot = ${a * 60} + $b, so it is ${both(a, big, b, sm)}.")
        }
        val ns = listOf(10, 20, 25, 30, 40, 50)
        val ps = listOf(5, 10, 15, 20, 25, 30)
        val period = Template("Tperiod", 2, intArrayOf(ns.size, ps.size)) { s, r ->
            val n = ns[s[0]]; val p = ps[s[1]]; val tot = n * p
            val c = listOf(p + 5, p - 5, p * 2, tot).filter { it > 0 }.map { "${tenths(it)} s" }
            gq("A pendulum makes $n oscillations in ${tenths(tot)} seconds. What is its time period?",
                opts("${tenths(p)} s", c, r) ?: return@Template null, "Time period = ${tenths(tot)} ÷ $n = ${tenths(p)} seconds.", visual = pic("clock"))
        }
        val total = Template("Ttotal", 2, intArrayOf(ns.size, ps.size)) { s, r ->
            val n = ns[s[0]]; val p = ps[s[1]]; val tot = n * p
            val c = listOf(tot + p, tot - p, tot * 2, n * 10 + p).filter { it > 0 }.map { "${tenths(it)} s" }
            gq("A pendulum's time period is ${tenths(p)} s. How long do $n oscillations take?",
                opts("${tenths(tot)} s", c, r) ?: return@Template null, "$n × ${tenths(p)} = ${tenths(tot)} seconds.", visual = pic("clock"))
        }
        val len = Template("Tlen", 3, intArrayOf(9, 9)) { s, _ ->
            if (s[0] == s[1]) return@Template null
            val a = (s[0] + 2) * 10; val b = (s[1] + 2) * 10
            gq("Pendulum A is $a cm long and pendulum B is $b cm long. Which has the longer time period?",
                listOf("pendulum A", "pendulum B", "both the same") to (if (a > b) 0 else 1), "A longer string gives a longer time period.")
        }
        val masses = listOf(10, 20, 50, 100, 200)
        val mass = Template("Tmass", 3, intArrayOf(5, 5)) { s, _ ->
            if (s[0] >= s[1]) return@Template null
            gq("Two pendulums are both 50 cm long. Bob A is ${masses[s[0]]} g and bob B is ${masses[s[1]]} g. Which has the longer time period?",
                listOf("pendulum A", "pendulum B", "both the same") to 2, "Time period depends on length, not on the bob's mass.")
        }
        return listOf(conv, join, split, period, total, len, mass)
    }

    /** sc7.light: plane-mirror distances. */
    private fun mirrorTemplates(): List<Template> {
        val image = Template("Mimage", 2, intArrayOf(15, 2)) { s, r ->
            val dd = s[0] + 1
            if (s[1] == 0) gq("You stand $dd m in front of a plane mirror. How far is your image from you?",
                opts(2 * dd, listOf(dd, 2 * dd + 2, dd + 1), r) { "$it m" } ?: return@Template null,
                "Your image is $dd m behind the mirror: ${2 * dd} m from you.", visual = pic("mirror"))
            else gq("You stand $dd m in front of a plane mirror. How far is your image from the mirror?",
                opts(dd, listOf(2 * dd, dd + 1, dd + 2), r) { "$it m" } ?: return@Template null,
                "The image is as far behind as you are in front.", visual = pic("mirror"))
        }
        val pencil = Template("Mpencil", 2, intArrayOf(20)) { s, r ->
            val dd = (s[0] + 1) * 5
            gq("A pencil is $dd cm in front of a plane mirror. How far behind the mirror is its image?",
                opts(dd, listOf(2 * dd, dd + 5, dd / 2), r) { "$it cm" } ?: return@Template null,
                "The image is as far behind as the pencil is in front.", visual = pic("pencil"))
        }
        val walk = Template("Mwalk", 3, intArrayOf(11, 11, 2)) { s, r ->
            val dd = s[0] + 2; val k = s[1] + 1
            val toward = s[2] == 0
            if (toward && k >= dd || !toward && k > 5) return@Template null
            val now = if (toward) dd - k else dd + k
            gq("You stand $dd m from a plane mirror and walk $k m ${if (toward) "towards it" else "back"}. How far is your image from you now?",
                opts(2 * now, listOf(now, 2 * dd, 2 * dd + (if (toward) -k else k)), r) { "$it m" } ?: return@Template null,
                "You are $now m away; the image is ${2 * now} m from you.", visual = pic("mirror"))
        }
        return listOf(image, pencil, walk)
    }

    // ------------------------------------------------------------ links (sc6.plantTypes)

    private fun linkTemplates(): List<Template> {
        val veins = d.tables["veins"]?.items?.associateBy { it.x } ?: return emptyList()
        val roots = d.tables["roots"]?.items?.associateBy { it.x } ?: return emptyList()
        val both = veins.keys.filter { it in roots }.sorted()
        return (0..1).map { dir -> Template(if (dir == 0) "Xroot" else "Xvein", 3, intArrayOf(both.size, 1)) { s0, _ ->
            val s = intArrayOf(s0[0], dir)
            val p = both[s[0]]
            val v = veins.getValue(p).c; val rt = roots.getValue(p).c
            if ((v == "par") != (rt == "fib")) return@Template null
            if (s[1] == 0) gq("${cap(p)} has ${if (v == "par") "parallel" else "net-like"} leaf veins. What roots will it most likely have?",
                Opt.baskets("taproot", "fibrous roots", rt == "tap"),
                if (v == "par") "Parallel leaf veins usually go with fibrous roots." else "Net-like leaf veins usually go with a taproot.")
            else gq("${cap(p)} has ${if (rt == "tap") "a taproot" else "fibrous roots"}. What leaf veins will it most likely have?",
                Opt.baskets("parallel", "reticulate", v == "par"),
                if (rt == "tap") "A taproot usually goes with net-like reticulate veins." else "Fibrous roots usually go with parallel leaf veins.")
        }}
    }

    // ------------------------------------------------------------ skills

    private fun skill(id: String, grade: Int, title: String, badge: String, strand: String, uses: List<Use>, extra: List<Template> = emptyList()): GenSkill? {
        val ts = uses.flatMap { tableTemplates(it) } + factTemplates(id) + orderTemplates(id) + chainTemplates(id) + extra
        if (ts.isEmpty()) return null
        return GenSkill(id, grade, "evs", title, badge, ts, strand = strand)
    }

    fun skills(): List<GenSkill> = listOfNotNull(
        // Class 6 (CU6)
        skill("sc6.plantTypes", 6, "Plant types", "Leaf", "herbs, shrubs, trees, veins and roots", listOf(
            Use("habitUp"), Use("habitWeak", sort = 1), Use("veins", classify = 1, sort = 1), Use("roots", sort = 1)), linkTemplates()),
        skill("sc6.nutrients", 6, "Food and nutrients", "Food", "nutrients, food tests and deficiency diseases", listOf(
            Use("nutrients"), Use("starchTest", sort = 1), Use("fatTest", sort = 1), Use("proteinTest", sort = 1))),
        skill("sc6.magnets", 6, "Magnets", "Mag", "magnetic materials and poles", listOf(Use("magnetic", sort = 1))),
        skill("sc6.length", 6, "Measuring length", "cm", "metric units and conversions", emptyList(), lengthTemplates()),
        skill("sc6.motion", 6, "Types of motion", "Move", "linear, circular and oscillatory motion", listOf(
            Use("motion", sort = 1, sortPair = "lin" to "cir"))),
        skill("sc6.materials", 6, "Materials", "Mat", "lustre, solubility, floating and transparency", listOf(
            Use("lustre", sort = 1), Use("dissolve", sort = 1), Use("mixes", sort = 1), Use("floats", sort = 1), Use("seeThrough"))),
        skill("sc6.temperature", 6, "Temperature", "Temp", "thermometers and °C", emptyList(), tempTemplates()),
        skill("sc6.waterStates", 6, "States of water", "H2O", "evaporation, condensation, melting and freezing", listOf(
            Use("waterChange", sort = 1, sortPair = "ev" to "co"), Use("waterState"))),
        skill("sc6.separation", 6, "Separating mixtures", "Mix", "handpicking to evaporation", listOf(Use("separate"))),
        skill("sc6.lifeSigns", 6, "Signs of life", "Life", "living things, germination and life cycles", listOf(Use("living", sort = 1))),
        skill("sc6.resources", 6, "Nature's treasures", "Eco", "renewable resources and fossil fuels", listOf(
            Use("renewable", sort = 1), Use("fossil", sort = 1, pair = 3))),
        skill("sc6.space", 6, "Beyond Earth", "Sky", "planets, stars and satellites", listOf(Use("planetKind", sort = 1))),
        // Class 7 (CU7)
        skill("sc7.acidBase", 7, "Acids and bases", "pH", "acidic, basic, neutral and neutralisation", listOf(
            Use("acidBase", sort = 1, sortPair = "acid" to "base"))),
        skill("sc7.indicators", 7, "Indicators", "Lit", "litmus, turmeric and China rose", listOf(
            Use("redLitmus", classify = 0, sort = 1, pick = 0), Use("blueLitmus", classify = 0, sort = 1, pick = 0),
            Use("turmeric", classify = 0, sort = 1, pick = 0), Use("chinaRose", classify = 0, sort = 1, pick = 0))),
        skill("sc7.circuits", 7, "Electric circuits", "Bulb", "conductors, insulators and glowing bulbs", listOf(Use("conductor", sort = 1))),
        skill("sc7.metals", 7, "Metals and non-metals", "Fe", "properties and uses of elements", listOf(Use("metal", sort = 1), Use("elemState"))),
        skill("sc7.changes", 7, "Physical or chemical", "Chem", "changes, reversibility and rusting", listOf(Use("change", sort = 1))),
        skill("sc7.heatFlow", 7, "Heat transfer", "Heat", "conduction, convection and radiation", listOf(Use("heatWay"), Use("heatCond", sort = 1))),
        skill("sc7.speed", 7, "Speed", "km/h", "speed, distance and time", emptyList(), speedTemplates()),
        skill("sc7.timePendulum", 7, "Time and pendulums", "Time", "time units and the simple pendulum", emptyList(), timeTemplates()),
        skill("sc7.animalLife", 7, "Animal life processes", "Gut", "digestion and breathing", listOf(
            Use("organJob", tf = 2), Use("breathe", sort = 1, sortPair = "lungs" to "gills"))),
        skill("sc7.plantLife", 7, "Plant life processes", "Sap", "photosynthesis and transport in plants", listOf(
            Use("plantPart"), Use("plantOrgan"), Use("photo"))),
        skill("sc7.light", 7, "Light and mirrors", "Ray", "shadows, mirrors and lateral inversion", listOf(
            Use("mirrorLetter", sort = 1), Use("shadow", sort = 1), Use("luminous", sort = 1)), mirrorTemplates()),
        skill("sc7.earthMoon", 7, "Earth, Moon and Sun", "Moon", "phases, eclipses, day and year", emptyList()),
    )
}
