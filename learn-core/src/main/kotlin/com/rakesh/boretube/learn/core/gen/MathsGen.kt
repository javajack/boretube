package com.rakesh.boretube.learn.core.gen

import com.rakesh.boretube.learn.core.Format
import com.rakesh.boretube.learn.core.GenSkill
import com.rakesh.boretube.learn.core.Opt
import com.rakesh.boretube.learn.core.Question
import com.rakesh.boretube.learn.core.Template
import com.rakesh.boretube.learn.core.Visual
import com.rakesh.boretube.learn.core.gq
import kotlin.math.abs
import kotlin.random.Random

/**
 * Generated Maths skills (spec P2b): extra tracks per class, KG to Class 7,
 * beside the ladder (which stays as it is). Everything is rules plus a small
 * Indian word-problem table below, so [data] isn't needed. Arithmetic is
 * exact: Int/Long, fractions as reduced pairs, decimals as scaled ints.
 */
object MathsGen {
    fun skills(@Suppress("UNUSED_PARAMETER") data: (String) -> String?): List<GenSkill> =
        kg() + c1() + c2() + c3() + c4() + c5() + c6() + c7()

    // ───────────────────────── helpers ─────────────────────────

    private const val MI = "−"
    private const val X = "×"
    private val Q = Format.quickfire
    private val TF = Format.truefalse
    private val SO = Format.sort
    private val OR = Format.order

    private fun tp(id: String, tier: Int, vararg dims: Int, kind: Format = Q, b: (IntArray, Random) -> Question?) =
        Template(id, tier, dims, kind, b)

    private fun sk(
        id: String, grade: Int, title: String, badge: String, strand: String,
        vararg ts: Template, extra: List<Format> = emptyList(),
    ): GenSkill {
        require(title.length <= 22) { "$id: title too long" }
        require(badge.length <= 4) { "$id: badge too long" }
        val f = ts.map { it.kind }.distinct() + extra
        return GenSkill(id, grade, "maths", title, badge, ts.toList(), formats = f, strand = strand)
    }

    private fun gcd(a: Int, b: Int): Int = if (b == 0) abs(a) else gcd(b, a % b)
    private fun lcm(a: Int, b: Int): Int = a / gcd(a, b) * b

    /** Plain number with a real minus sign. */
    private fun s(n: Int) = if (n < 0) "$MI${-n}" else "$n"

    /** Indian grouping (5,700 and 1,23,45,678), as NCERT writes numbers of four digits and more. */
    private fun ind(n: Long, all: Boolean = true): String {
        if (n < 0) return MI + ind(-n, all)
        val t = n.toString()
        if (t.length <= 3 || (t.length == 4 && !all)) return t
        val last = t.takeLast(3)
        var head = t.dropLast(3)
        val parts = ArrayList<String>()
        while (head.length > 2) { parts.add(0, head.takeLast(2)); head = head.dropLast(2) }
        parts.add(0, head)
        return parts.joinToString(",") + "," + last
    }

    private fun intl(n: Long): String = n.toString().reversed().chunked(3).joinToString(",").reversed()

    /** Numbers in options: Indian grouping from 10,000 up. */
    private fun g(n: Int): String = ind(n.toLong())

    /** [ans] plus three distinct wrongs (preferred first, then neighbours), shuffled. */
    private fun nums(ans: Int, wrongs: List<Int?>, r: Random, min: Int = 0, f: (Int) -> String = ::g, count: Int = 4): Pair<List<String>, Int> {
        val picked = LinkedHashSet<Int>()
        for (w in wrongs) if (w != null && w != ans && w >= min && picked.size < count - 1) picked += w
        var d = 1
        while (picked.size < count - 1) {
            for (c in listOf(ans + d, ans - d)) if (c != ans && c >= min && picked.size < count - 1) picked += c
            d++
        }
        val all = (picked + ans).shuffled(r)
        return all.map(f) to all.indexOf(ans)
    }

    private fun rs(n: Int) = "₹${g(n)}"

    private fun tf(stmt: String, ok: Boolean, why: String, spoken: String = stmt) =
        gq(stmt, Opt.trueFalse(ok), why, fact = why.removeSuffix("."), spoken = spoken)

    private fun sortQ(prompt: String, left: String, right: String, isLeft: Boolean, why: String) =
        gq(prompt, Opt.baskets(left, right, isLeft), why, fact = if (isLeft) left else right)

    /** An order question: [items] are first to last. */
    private fun ord(prompt: String, items: List<String>, r: Random, why: String): Question? {
        if (items.toSet().size != items.size) return null
        val shown = items.shuffled(r)
        return gq(prompt, shown to shown.indexOf(items[0]), why, fact = items.joinToString(", "), order = items)
    }

    /** Text options; null when fewer than [need] distinct wrongs. */
    private fun texts(ans: String, wrongs: List<String?>, r: Random, need: Int = 2, count: Int = 4): Pair<List<String>, Int>? {
        val w = LinkedHashSet<String>()
        for (x in wrongs) if (x != null && !x.equals(ans, true) && w.size < count - 1) w += x
        if (w.size < need) return null
        return Opt.of(ans, w.toList(), r, count)
    }

    // Signs, in a fixed order so the remote buttons never move.
    private val SIGNS = listOf("<", ">", "=")
    private fun sign(c: Int) = when { c < 0 -> "<"; c > 0 -> ">"; else -> "=" }
    private fun signQ(a: String, b: String, c: Int, why: String, spoken: String) =
        gq("Which sign? $a __ $b", SIGNS to SIGNS.indexOf(sign(c)), why, fact = "$a ${sign(c)} $b", spoken = spoken)

    private fun digits(n: Long) = n.toString().map { it - '0' }

    private val PLACE = listOf("ones", "tens", "hundreds", "thousands", "ten thousands", "lakhs", "ten lakhs", "crores", "ten crores")

    /** Why the bigger of two whole numbers is bigger (one sentence). */
    private fun cmpWhy(a: Long, b: Long, f: (Long) -> String): String {
        if (a == b) return "Both are the same number."
        val big = maxOf(a, b)
        val (da, db) = digits(a) to digits(b)
        if (da.size != db.size) return "${f(big)} has more digits, so it is bigger."
        val i = da.indices.first { da[it] != db[it] }
        val hi = maxOf(da[i], db[i])
        val lo = minOf(da[i], db[i])
        val place = PLACE[da.size - 1 - i]
        return if (i == 0 && da.size <= 4) "$hi $place beats $lo $place, so ${f(big)} is bigger."
        else if (i == 0) "The first digit $hi beats $lo, so ${f(big)} is bigger."
        else "First digits match; then $hi beats $lo, so ${f(big)} is bigger."
    }

    /** Exact fractions, always reduced (so equal values are equal objects). */
    private class Fr private constructor(val n: Int, val d: Int) {
        override fun equals(other: Any?) = other is Fr && other.n == n && other.d == d
        override fun hashCode() = n * 31 + d
        operator fun plus(o: Fr) = of(n * o.d + o.n * d, d * o.d)
        operator fun minus(o: Fr) = of(n * o.d - o.n * d, d * o.d)
        operator fun times(o: Fr) = of(n * o.n, d * o.d)
        operator fun div(o: Fr) = of(n * o.d, d * o.n)
        fun cmp(o: Fr) = (n.toLong() * o.d).compareTo(o.n.toLong() * d)
        /** 3/4, 7/4, 2. */
        val plain: String get() = if (d == 1) s(n) else "${s(n)}/$d"
        /** 3/4, 1 3/4, 2 (positive values). */
        val mixed: String get() = when {
            d == 1 -> s(n)
            n < d -> "$n/$d"
            else -> "${n / d} ${n % d}/$d"
        }
        override fun toString() = plain
        companion object {
            fun of(n: Int, d: Int): Fr {
                require(d != 0)
                val sg = if (d < 0) -1 else 1
                val g = gcd(abs(n), abs(d)).coerceAtLeast(1)
                return Fr(sg * n / g, sg * d / g)
            }
        }
    }

    /** Fraction options: distinct values, never the answer's value, all positive. */
    private fun fracs(ans: Fr, wrongs: List<Fr?>, r: Random, show: (Fr) -> String, need: Int = 2): Pair<List<String>, Int>? {
        val w = LinkedHashSet<Fr>()
        for (x in wrongs) if (x != null && x != ans && x.n > 0 && w.size < 3) w += x
        if (w.size < need) return null
        val all = (w + ans).toList().shuffled(r)
        val shown = all.map(show)
        if (shown.toSet().size != shown.size) return null
        return shown to all.indexOf(ans)
    }

    private fun frOrNull(n: Int, d: Int) = if (d <= 0 || n <= 0) null else Fr.of(n, d)

    /** Number names (Indian system, no "and"). */
    private val ONES = listOf(
        "zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten",
        "eleven", "twelve", "thirteen", "fourteen", "fifteen", "sixteen", "seventeen", "eighteen", "nineteen",
    )
    private val TENS = listOf("", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy", "eighty", "ninety")
    private fun name99(n: Int): String = if (n < 20) ONES[n] else TENS[n / 10] + if (n % 10 > 0) "-" + ONES[n % 10] else ""
    private fun nameIn(n: Long): String {
        if (n == 0L) return "zero"
        val out = ArrayList<String>()
        val cr = (n / 10_000_000).toInt()
        val la = ((n / 100_000) % 100).toInt()
        val th = ((n / 1000) % 100).toInt()
        val hu = ((n / 100) % 10).toInt()
        val re = (n % 100).toInt()
        if (cr > 0) out += "${name99(cr)} crore"
        if (la > 0) out += "${name99(la)} lakh"
        if (th > 0) out += "${name99(th)} thousand"
        if (hu > 0) out += "${ONES[hu]} hundred"
        if (re > 0) out += name99(re)
        return out.joinToString(" ")
    }
    private fun tens(n: Int) = if (n == 1) "1 ten" else "$n tens"
    private fun ones(n: Int) = if (n == 1) "1 one" else "$n ones"
    private fun cap(w: String) = w.replaceFirstChar { it.uppercase() }

    /** A spread of n-digit-ish numbers: [lo] + (i × a big prime) mod [span], distinct for i < span. */
    private fun spread(i: Int, lo: Long, span: Long): Long = lo + (i.toLong() * 7919L) % span

    // ── Word-problem table (names balanced by gender; ₹ prices realistic) ──

    private class Kid(val name: String, val girl: Boolean) {
        val he get() = if (girl) "she" else "he"
        val heCap get() = if (girl) "She" else "He"
        val him get() = if (girl) "her" else "him"
        val his get() = if (girl) "her" else "his"
    }

    private val KIDS = listOf(
        Kid("Riya", true), Kid("Aarav", false), Kid("Meera", true), Kid("Kabir", false), Kid("Anaya", true),
        Kid("Vihaan", false), Kid("Zoya", true), Kid("Arjun", false), Kid("Diya", true), Kid("Ishaan", false),
    )

    /** A different child, of the other gender (the list alternates). */
    private fun friend(i: Int) = KIDS[(i + 5) % KIDS.size]

    private class Thing(val one: String, val many: String, val pic: String = one) {
        fun n(k: Int) = if (k == 1) "1 $one" else "$k $many"
        fun w(k: Int) = if (k == 1) one else many
    }

    private val THINGS = listOf(
        Thing("mango", "mangoes"), Thing("apple", "apples"), Thing("pencil", "pencils"), Thing("balloon", "balloons"),
        Thing("banana", "bananas"), Thing("laddoo", "laddoos", "ladoo"), Thing("shell", "shells"), Thing("ball", "balls"),
        Thing("kite", "kites"), Thing("crayon", "crayons"),
    )

    private class Item(val one: String, val many: String, val price: Int, val pic: String? = null) {
        val a get() = (if (one[0] in "aeiou") "an " else "a ") + one
    }

    private val SHOP = listOf(
        Item("pencil", "pencils", 5, "pencil"), Item("chocolate", "chocolates", 10), Item("pen", "pens", 10, "pen"),
        Item("samosa", "samosas", 15, "samosa"), Item("kite", "kites", 20, "kite"), Item("biscuit packet", "biscuit packets", 20),
        Item("ice cream", "ice creams", 25, "icecream"), Item("comic", "comics", 30), Item("notebook", "notebooks", 35, "notebook"),
        Item("ball", "balls", 45, "ball"), Item("crayon box", "crayon boxes", 60, "crayon"), Item("cricket ball", "cricket balls", 70, "ball"),
        Item("pair of socks", "pairs of socks", 80, "sock"), Item("toy car", "toy cars", 85, "car"), Item("storybook", "storybooks", 95, "book"),
        Item("geometry box", "geometry boxes", 110), Item("water bottle", "water bottles", 120, "bottle"),
        Item("lunch box", "lunch boxes", 150), Item("torch", "torches", 180, "torch"), Item("school bag", "school bags", 450, "schoolbag"),
    )

    // ───────────────────────── KG ─────────────────────────

    private fun kg() = listOf(kgAfter(), kgPattern(), kgAdd5(), kgSub5(), kgFirst(), kgBigSmall(), kgShapes())

    private fun kgAfter() = sk(
        "mak.after", 0, "Before and after", "1→2", "the number before, after and between",
        tp("after", 1, 2, 10) { p, r ->
            val n = p[1]
            val a = n + 1
            val prompt = if (p[0] == 0) "What comes just after $n?" else "Which number is 1 more than $n?"
            gq(prompt, nums(a, listOf(n - 1, n + 2, n), r), "Count on from $n: the next number is $a.", "After $n comes $a",
                visual = if (n > 0) Visual.Objects(n) else null)
        },
        tp("after20", 2, 2, 10) { p, r ->
            val n = 10 + p[1]
            val a = n + 1
            val prompt = if (p[0] == 0) "What comes just after $n?" else "Which number is 1 more than $n?"
            gq(prompt, nums(a, listOf(n - 1, n + 2, n), r), "Count on from $n: the next number is $a.", "After $n comes $a",
                visual = Visual.Objects(n))
        },
        tp("before", 2, 2, 19) { p, r ->
            val n = p[1] + 2
            val a = n - 1
            val prompt = if (p[0] == 0) "What comes just before $n?" else "Which number is 1 less than $n?"
            gq(prompt, nums(a, listOf(n + 1, n - 2, n), r), "Count back from $n: just before it is $a.", "Before $n comes $a",
                visual = Visual.Objects(n))
        },
        tp("between", 3, 19) { p, r ->
            val a = p[0]
            val m = a + 1
            gq("What comes between $a and ${a + 2}?", nums(m, listOf(a, a + 2, a + 3), r), "$a, $m, ${a + 2}: $m is in the middle.", "$m is between $a and ${a + 2}")
                .copy(learnVisual = Visual.Objects(a + 2))
        },
        tp("tf", 2, 2, 20, 3, kind = TF) { p, _ ->
            val n = p[1]
            if (p[0] == 0) {
                val c = when (p[2]) { 0 -> n + 1; 1 -> n + 2; else -> n - 1 }
                if (c < 0) return@tp null
                tf("$c comes just after $n.", c == n + 1, "Just after $n comes ${n + 1}.").copy(visual = if (n > 0) Visual.Objects(n) else null)
            } else {
                val m = n + 1
                val c = when (p[2]) { 0 -> m - 1; 1 -> m - 2; else -> m + 1 }
                if (c < 0) return@tp null
                tf("$c comes just before $m.", c == m - 1, "Just before $m comes ${m - 1}.").copy(visual = Visual.Objects(m))
            }
        },
        tp("order", 1, 10, 10, 10, kind = OR) { p, r ->
            val (a, b, c) = Triple(p[0] + 1, p[1] + 1, p[2] + 1)
            if (!(a < b && b < c)) return@tp null
            ord("Put in order, smallest first.", listOf("$a", "$b", "$c"), r, "Count up: $a, $b, $c.")
        },
        tp("order4", 3, 17, 4, 4, 4, kind = OR) { p, r ->
            val a = p[0] + 1
            val b = a + p[1] + 1
            val c = b + p[2] + 1
            val d = c + p[3] + 1
            if (d > 20) return@tp null
            ord("Put in order, smallest first.", listOf("$a", "$b", "$c", "$d"), r, "Count up: $a, $b, $c, $d.")
        },
    )

    private val SYM = listOf("●", "▲", "■", "★", "◆", "♥")
    private val SYM_NAME = listOf("circle", "triangle", "square", "star", "diamond", "heart")

    private fun patternT(id: String, tier: Int, units: List<IntArray>) = tp(id, tier, units.size, 6, 6, 6, 3) { p, r ->
        val u = units[p[0]]
        val k = u.max() + 1
        val sy = intArrayOf(p[1], p[2], p[3])
        if (k == 2 && p[3] != 0) return@tp null
        if ((0 until k).map { sy[it] }.toSet().size != k) return@tp null
        val len = u.size * 2 + p[4]
        val seq = (0 until len).map { sy[u[it % u.size]] }
        val ans = SYM[sy[u[len % u.size]]]
        val used = (0 until k).map { SYM[sy[it]] }
        val extra = SYM[(sy.sum() + len) % 6].takeIf { it !in used } ?: SYM.first { it !in used }
        val unit = u.joinToString(" ") { SYM[sy[it]] }
        gq(
            "What comes next? ${seq.joinToString(" ") { SYM[it] }}", Opt.of(ans, used.filter { it != ans } + extra, r)!!,
            "The $unit part repeats, so $ans comes next.",
            spoken = "What comes next? ${seq.joinToString(", ") { SYM_NAME[it] }}",
        )
    }

    private fun kgPattern() = sk(
        "mak.pattern", 0, "What comes next", "●▲●", "repeating patterns",
        patternT("ab", 1, listOf(intArrayOf(0, 1))),
        patternT("aab", 2, listOf(intArrayOf(0, 0, 1), intArrayOf(0, 1, 1), intArrayOf(0, 0, 1, 1))),
        patternT("abc", 3, listOf(intArrayOf(0, 1, 2), intArrayOf(0, 1, 1, 2), intArrayOf(0, 0, 1, 2))),
        picPatternT("picAb", 1, listOf(intArrayOf(0, 1))),
        picPatternT("picAab", 2, listOf(intArrayOf(0, 0, 1), intArrayOf(0, 1, 1), intArrayOf(0, 0, 1, 1))),
        picPatternT("picAbc", 3, listOf(intArrayOf(0, 1, 2), intArrayOf(0, 1, 1, 2))),
    )

    private val PIC_SETS = listOf(
        listOf("apple", "banana", "mango", "orange", "grapes", "strawberry"),
        listOf("cat", "dog", "cow", "duck", "hen", "fish"),
        listOf("circle", "square", "triangle", "diamond", "oval", "rectangle"),
        listOf("ball", "kite", "drum", "car", "boat", "bell"),
    )

    /** Patterns of picture words, answered with pictures. */
    private fun picPatternT(id: String, tier: Int, units: List<IntArray>) = tp(id, tier, units.size, PIC_SETS.size, 6, 6, 6, 2) { p, r ->
        val u = units[p[0]]
        val set = PIC_SETS[p[1]]
        val k = u.max() + 1
        val sy = intArrayOf(p[2], p[3], p[4])
        if (k == 2 && p[4] != 0) return@tp null
        if ((0 until k).map { sy[it] }.toSet().size != k) return@tp null
        val len = u.size * 2 + p[5]
        val seq = (0 until len).map { set[sy[u[it % u.size]]] }
        val ans = set[sy[u[len % u.size]]]
        val used = (0 until k).map { set[sy[it]] }
        val extra = set[(sy.sum() + len) % 6].takeIf { it !in used } ?: set.first { it !in used }
        val unit = u.joinToString(", ") { set[sy[it]] }
        gq("What comes next? ${seq.joinToString(", ")}, ?", Opt.of("pic:$ans", (used.filter { it != ans } + extra).map { "pic:$it" }, r)!!,
            "The $unit part repeats, so $ans comes next.", ans, visual = Visual.Picture(seq.last()))
    }

    /** Pairs a, b ≥ 1 with a + b ≤ [max]. */
    private fun addFacts(max: Int) = (1 until max).flatMap { a -> (1..max - a).map { b -> a to b } }

    private val F5 = addFacts(5)
    private val F10 = addFacts(10)

    private fun kgAdd5() = sk(
        "mak.add5", 0, "Adding to 5", "1+1", "putting together, up to 5",
        tp("pic", 1, F5.size) { p, r ->
            val (a, b) = F5[p[0]]
            val s = a + b
            gq("$a + $b = ?", nums(s, listOf(s + 1, s - 1, a), r, min = 1), "Count all the dots: $a and $b make $s.", "$a + $b = $s",
                visual = Visual.Dots(1, s, a))
        },
        tp("things", 1, THINGS.size, F5.size) { p, r ->
            val t = THINGS[p[0]]
            val (a, b) = F5[p[1]]
            val s = a + b
            gq("${t.n(a)} and $b more. How many ${t.many} in all?", nums(s, listOf(s + 1, s - 1, b), r, min = 1),
                "$a and $b more make $s.", "$a + $b = $s", visual = Visual.Dots(1, s, a))
        },
        tp("tf", 2, F10.size, 3, kind = TF) { p, _ ->
            val (a, b) = F10[p[0]]
            val s = a + b
            val c = when (p[1]) { 0 -> s; 1 -> s + 1; else -> s - 1 }
            tf("$a + $b = $c", c == s, "$a and $b more make $s.").copy(visual = Visual.Dots(1, s, a), learnVisual = Visual.Dots(1, s, a))
        },
        tp("story", 2, KIDS.size, THINGS.size, F5.size) { p, r ->
            val k = KIDS[p[0]]
            val t = THINGS[p[1]]
            val (a, b) = F5[p[2]]
            val s = a + b
            gq("${k.name} has ${t.n(a)}. ${k.heCap} gets $b more. How many ${t.many} now?", nums(s, listOf(s + 1, s - 1, b), r, min = 1),
                "$a and $b more make $s ${t.many}.", "$a + $b = $s", visual = Visual.Dots(1, s, a))
        },
        tp("need", 3, KIDS.size, THINGS.size, F5.size) { p, r ->
            val k = KIDS[p[0]]
            val t = THINGS[p[1]]
            val (a, b) = F5[p[2]]
            val s = a + b
            gq("${k.name} has ${t.n(a)}. ${k.heCap} wants $s. How many more does ${k.he} need?", nums(b, listOf(s, a, b + 1), r),
                "$a and $b more make $s, so ${k.he} needs $b.", "$a + $b = $s", visual = Visual.Dots(1, s, a))
        },
    )

    /** a − b with 1 ≤ b ≤ a ≤ [max]. */
    private fun subFacts(max: Int) = (1..max).flatMap { a -> (1..a).map { b -> a to b } }
    private val S5 = subFacts(5)

    private fun kgSub5() = sk(
        "mak.sub5", 0, "Taking away to 5", "5−1", "taking away, up to 5",
        tp("pic", 1, S5.size) { p, r ->
            val (a, b) = S5[p[0]]
            val d = a - b
            gq("$a $MI $b = ?", nums(d, listOf(d + 1, a + b, a), r), "Take $b away from $a: $d left.", "$a $MI $b = $d",
                visual = Visual.Dots(1, a, d))
        },
        tp("things", 1, THINGS.size, S5.size) { p, r ->
            val t = THINGS[p[0]]
            val (a, b) = S5[p[1]]
            val d = a - b
            gq("${t.n(a)}. Take away $b. How many are left?", nums(d, listOf(d + 1, a + b, a), r), "Take $b away from $a: $d left.",
                "$a $MI $b = $d", visual = Visual.Dots(1, a, d))
        },
        tp("tf", 1, S5.size, 3, kind = TF) { p, _ ->
            val (a, b) = S5[p[0]]
            val d = a - b
            val c = when (p[1]) { 0 -> d; 1 -> d + 1; else -> a + b }
            tf("$a $MI $b = $c", c == d, "Take $b away from $a: $d left.", "$a take away $b is $c").copy(visual = Visual.Objects(a), learnVisual = Visual.Dots(1, a, d))
        },
        tp("story", 2, KIDS.size, THINGS.size, S5.size) { p, r ->
            val k = KIDS[p[0]]
            val t = THINGS[p[1]]
            val (a, b) = S5[p[2]]
            val d = a - b
            gq("${k.name} has ${t.n(a)}. ${k.heCap} gives $b to ${friend(p[0]).name}. How many are left?",
                nums(d, listOf(d + 1, a + b, b), r), "$a take away $b leaves $d.", "$a $MI $b = $d", visual = Visual.Objects(a))
                .copy(learnVisual = Visual.Dots(1, a, d))
        },
        tp("gave", 3, KIDS.size, THINGS.size, S5.size) { p, r ->
            val k = KIDS[p[0]]
            val t = THINGS[p[1]]
            val (a, b) = S5[p[2]]
            val d = a - b
            gq("${k.name} had ${t.n(a)}. Now ${k.he} has $d. How many did ${k.he} give away?",
                nums(b, listOf(a, d, a + d), r), "From $a down to $d is $b, so ${k.he} gave $b.", "$a $MI $d = $b", visual = Visual.Objects(a))
                .copy(learnVisual = Visual.Dots(1, a, d))
        },
    )

    /** The [i]-th arrangement of 4 of the 6 symbols (360 of them). */
    private fun line4(i: Int): List<Int> {
        val pool = (0..5).toMutableList()
        var x = i
        return List(4) { val k = x % pool.size; x /= pool.size; pool.removeAt(k) }
    }

    private val ORDINAL = listOf("first", "second", "third", "fourth")

    private fun kgFirst() = sk(
        "mak.first", 0, "First, second, last", "1st", "position in a line",
        tp("ends", 1, 360, 2) { p, r ->
            val set = PIC_SETS[p[0] % PIC_SETS.size]
            val l = line4(p[0]).map { set[it] }
            val pos = if (p[1] == 0) 0 else 3
            val word = if (p[1] == 0) "first" else "last"
            val ans = l[pos]
            val why = if (pos == 0) "Read from the left: the $ans is first." else "The last one, at the right end, is the $ans."
            gq("Left to right: ${l.joinToString(", ")}. Which is $word?", Opt.of("pic:$ans", (l - ans).map { "pic:$it" }, r)!!, why, ans)
        },
        tp("mid", 2, 360, 2) { p, r ->
            val set = PIC_SETS[p[0] % PIC_SETS.size]
            val l = line4(p[0]).map { set[it] }
            val pos = p[1] + 1
            val ans = l[pos]
            gq("Left to right: ${l.joinToString(", ")}. Which is ${ORDINAL[pos]}?", Opt.of("pic:$ans", (l - ans).map { "pic:$it" }, r)!!,
                "Count from the left: ${l.take(pos + 1).joinToString(", ")}, so the $ans is ${ORDINAL[pos]}.", ans)
        },
        tp("next", 3, 360, 2, 3) { p, r ->
            val set = PIC_SETS[p[0] % PIC_SETS.size]
            val l = line4(p[0]).map { set[it] }
            val after = p[1] == 0
            val ref = if (after) p[2] else p[2] + 1
            val pos = if (after) ref + 1 else ref - 1
            val ans = l[pos]
            val w = if (after) "just after" else "just before"
            gq("Left to right: ${l.joinToString(", ")}. Which is $w the ${l[ref]}?", Opt.of("pic:$ans", (l - ans).map { "pic:$it" }, r)!!,
                "${cap(w)} the ${l[ref]} comes the $ans.", ans, visual = Visual.Picture(l[ref]))
        },
    )

    private val SIZES = listOf(
        listOf("ant", "bee", "ladybird", "snail", "pea"),
        listOf("mouse", "apple", "cup", "spoon", "ball"),
        listOf("cat", "chair", "bucket", "school bag", "dog"),
        listOf("cow", "car", "bed", "horse", "auto"),
        listOf("elephant", "bus", "train", "ship", "house"),
    )

    private fun picOf(w: String) = when (w) { "pea" -> "peas"; "school bag" -> "schoolbag"; else -> w }

    private fun an(w: String) = (if (w[0] in "aeiou") "an " else "a ") + w

    private fun bigPair(id: String, tier: Int, pairs: List<Pair<Int, Int>>) = tp(id, tier, pairs.size, 5, 5, 2, 2) { p, r ->
        val (ci, cj) = pairs[p[0]]
        val x = SIZES[ci][p[1]]
        val y = SIZES[cj][p[2]]
        val (first, second) = if (p[3] == 0) x to y else y to x
        val bigger = p[4] == 0
        val ans = if (bigger) y else x // cj is the bigger class
        val why = "${cap(an(y))} is much bigger than ${an(x)}."
        gq("Which is ${if (bigger) "bigger" else "smaller"}: ${an(first)} or ${an(second)}?",
            Opt.of("pic:${picOf(ans)}", listOf("pic:${picOf(if (ans == x) y else x)}"), r, 2)!!, why, ans)
    }

    private fun kgBigSmall() = sk(
        "mak.bigSmall", 0, "Big and small", "big", "comparing sizes",
        bigPair("far", 1, listOf(0 to 3, 0 to 4, 1 to 4)),
        bigPair("near", 2, listOf(0 to 2, 1 to 3, 2 to 4)),
        tp("three", 3, 5, 5, 5, 2) { p, r ->
            val a = SIZES[0][p[0]]
            val b = SIZES[2][p[1]]
            val c = SIZES[4][p[2]]
            val biggest = p[3] == 0
            val shown = listOf(b, c, a, b, c).drop(p[0] % 3).take(3)
            val ans = if (biggest) c else a
            gq("Which is the ${if (biggest) "biggest" else "smallest"}: ${an(shown[0])}, ${an(shown[1])} or ${an(shown[2])}?",
                Opt.of("pic:${picOf(ans)}", listOf(a, b, c).filter { it != ans }.map { "pic:${picOf(it)}" }, r)!!,
                if (biggest) "${cap(an(c))} is bigger than both the others." else "${cap(an(a))} is smaller than both the others.")
        },
        tp("tf", 2, 12, 5, 5, 2, kind = TF) { p, _ ->
            val pairs = listOf(0 to 2, 0 to 3, 0 to 4, 1 to 3, 1 to 4, 2 to 4)
            val (lo, hi) = pairs[p[0] % 6]
            val swap = p[0] >= 6
            val small = SIZES[lo][p[1]]
            val big = SIZES[hi][p[2]]
            val (subj, obj) = if (swap) small to big else big to small
            val word = if (p[3] == 0) "bigger" else "smaller"
            val ok = (subj == big) == (word == "bigger")
            tf("${cap(an(subj))} is $word than ${an(obj)}.", ok, "${cap(an(big))} is much bigger than ${an(small)}.")
                .copy(visual = Visual.Picture(picOf(subj)), learnVisual = Visual.Picture(picOf(big)))
        },
    )

    private val SH2 = listOf("circle", "square", "triangle", "rectangle", "oval", "diamond")
    private val SIDES = mapOf("circle" to 0, "oval" to 0, "triangle" to 3, "square" to 4, "rectangle" to 4, "diamond" to 4)
    private val SH3 = listOf("cube", "cone", "cylinder", "sphere")

    /** Everyday things and their shape (picture id, words, shape). Only clear cases. */
    private class Shaped(val pic: String, val word: String, val shape: String)

    private val SHAPED = listOf(
        Shaped("ball", "ball", "sphere"), Shaped("orange", "orange", "sphere"), Shaped("watermelon", "watermelon", "sphere"),
        Shaped("globe", "globe", "sphere"), Shaped("earth", "Earth", "sphere"),
        Shaped("giftbox", "gift box", "cube"),
        Shaped("candle", "candle", "cylinder"), Shaped("drum", "drum", "cylinder"), Shaped("battery", "battery", "cylinder"),
        Shaped("clock", "clock", "circle"), Shaped("plate", "plate", "circle"),
        Shaped("door", "door", "rectangle"), Shaped("book", "book", "rectangle"), Shaped("phone", "phone", "rectangle"),
        Shaped("tv", "TV", "rectangle"), Shaped("blackboard", "blackboard", "rectangle"), Shaped("notebook", "notebook", "rectangle"),
    )

    private fun aw(w: String) = if (w[0].lowercaseChar() in "aeiou") "an $w" else "a $w"
    private fun rolls(shape: String) = shape != "cube"

    private fun findT(id: String, tier: Int, set: List<String>) = tp(id, tier, set.size, 3) { p, r ->
        val x = set[p[0]]
        val prompt = when (p[1]) { 0 -> "Which one is ${aw(x)}?"; 1 -> "Find the $x."; else -> "Which picture shows ${aw(x)}?" }
        val others = set.filter { it != x }
        gq(prompt, Opt.of("pic:$x", others.map { "pic:$it" }, r)!!, "This is ${aw(x)}.", x)
    }

    private fun thisOrT(id: String, tier: Int, set: List<String>) = tp(id, tier, set.size, set.size, 2) { p, r ->
        if (p[0] == p[1]) return@tp null
        val (x, y) = set[p[0]] to set[p[1]]
        val (a, b) = if (p[2] == 0) x to y else y to x
        gq("Is this ${aw(a)} or ${aw(b)}?", Opt.of(x, listOf(y), r, 2)!!, "This is ${aw(x)}.", x, visual = Visual.Picture(x))
    }

    private fun kgShapes() = sk(
        "mak.shapes", 0, "Shapes around us", "▲●", "flat and solid shapes, and everyday things",
        findT("find2", 1, SH2),
        thisOrT("this2", 1, SH2),
        tp("name2", 1, SH2.size) { p, r ->
            val x = SH2[p[0]]
            gq("What shape is this?", Opt.of(x, SH2.filter { it != x }, r)!!, "This is ${aw(x)}.", x, visual = Visual.Picture(x))
        },
        findT("find3", 2, SH3),
        thisOrT("this3", 2, SH3),
        tp("name3", 2, SH3.size) { p, r ->
            val x = SH3[p[0]]
            gq("What solid shape is this?", Opt.of(x, SH3.filter { it != x }, r)!!, "This is ${aw(x)}.", x, visual = Visual.Picture(x))
        },
        tp("like", 2, SHAPED.size) { p, r ->
            val o = SHAPED[p[0]]
            val fam = if (o.shape in SH3) SH3 else SH2
            gq("What shape is ${aw(o.word)} like?", Opt.of(o.shape, fam.filter { it != o.shape }, r)!!, "${cap(aw(o.word))} is shaped like ${aw(o.shape)}.", o.shape,
                visual = Visual.Picture(o.pic))
        },
        tp("likeOr", 2, SHAPED.size, 3, 2) { p, r ->
            val o = SHAPED[p[0]]
            val fam = if (o.shape in SH3) SH3 else SH2
            val other = fam.filter { it != o.shape }.getOrNull(p[1]) ?: return@tp null
            val (a, b) = if (p[2] == 0) o.shape to other else other to o.shape
            gq("Is ${aw(o.word)} shaped like ${aw(a)} or ${aw(b)}?", Opt.of(o.shape, listOf(other), r, 2)!!,
                "${cap(aw(o.word))} is shaped like ${aw(o.shape)}.", o.shape, visual = Visual.Picture(o.pic))
        },
        tp("sides", 3, SH2.size, 2) { p, r ->
            val x = SH2[p[0]]
            val n = SIDES.getValue(x)
            val w = if (p[1] == 0) "sides" else "corners"
            val why = if (n == 0) "${cap(aw(x))} is round, so it has no $w." else "Count them: ${aw(x)} has $n $w."
            gq("How many $w does ${aw(x)} have?", nums(n, listOf(n + 1, if (n == 0) 1 else n - 1, if (n == 3) 4 else 3), r), why, "$n $w",
                visual = Visual.Picture(x))
        },
        tp("roll", 3, SH3.size + SHAPED.size, kind = TF) { p, _ ->
            val (pic, word, shape) = if (p[0] < SH3.size) Triple(SH3[p[0]], SH3[p[0]], SH3[p[0]])
            else SHAPED[p[0] - SH3.size].let { Triple(it.pic, it.word, it.shape) }
            if (shape !in SH3) return@tp null
            val y = rolls(shape)
            tf("${cap(aw(word))} can roll.", y,
                if (y) "${cap(aw(word))} has a curved side, so it rolls." else "${cap(aw(word))} has only flat faces, so it doesn't roll.")
                .copy(visual = Visual.Picture(pic), learnVisual = Visual.Picture(pic))
        },
        tp("tf", 3, SHAPED.size, 3, kind = TF) { p, _ ->
            val o = SHAPED[p[0]]
            val fam = if (o.shape in SH3) SH3 else SH2
            val said = if (p[1] == 0) o.shape else fam.filter { it != o.shape }.getOrNull(p[1] - 1) ?: return@tp null
            tf("${cap(aw(o.word))} is shaped like ${aw(said)}.", said == o.shape, "${cap(aw(o.word))} is shaped like ${aw(o.shape)}.")
                .copy(visual = Visual.Picture(o.pic), learnVisual = Visual.Picture(o.pic))
        },
    )

    // ───────────────────────── Class 1 ─────────────────────────

    private fun c1() = listOf(c1Names(), c1Compare(), c1Bridge(), c1Sub20(), c1Story(), c1Skip(), c1Tens())

    /** Mangoes up to 20; rows of ten dots for whole tens. */
    private fun numVisual(n: Int): Visual? = when {
        n in 1..20 -> Visual.Objects(n)
        n in 30..90 && n % 10 == 0 -> Visual.Dots(n / 10, 10)
        else -> null
    }

    private fun nameWhy(n: Int): String {
        val w = cap(name99(n))
        return when {
            n < 10 -> "$w is written $n."
            n < 20 -> "$w is 1 ten and ${n - 10} ones: $n."
            n % 10 == 0 -> "$w is ${n / 10} tens: $n."
            else -> "$w is ${n / 10} tens and ${ones(n % 10)}: $n."
        }
    }

    /** Mistakes when reading a number name: teen/ty mix-ups, swapped digits, one off. */
    private fun nameWrongs(n: Int): List<Int?> = listOf(
        if (n in 13..19) (n - 10) * 10 else if (n in 30..90 && n % 10 == 0) n / 10 + 10 else null,
        if (n in 10..99 && n % 10 != 0 && n % 10 != n / 10) (n % 10) * 10 + n / 10 else null,
        n + 1, n - 1, n + 10, n - 10,
    )

    private fun namesT(id: String, tier: Int, lo: Int, hi: Int, toNum: Boolean) = tp(id, tier, hi - lo + 1) { p, r ->
        val n = lo + p[0]
        val w = nameWrongs(n).filterNotNull().filter { it in 0..99 }.distinct()
        val v = numVisual(n)
        if (toNum) gq("Which number is ${name99(n)}?", nums(n, w, r), nameWhy(n), "${name99(n)} = $n", visual = v)
        else gq("How do we write $n in words?", texts(name99(n), w.filter { it != n }.map { name99(it) }, r)!!, nameWhy(n), "$n = ${name99(n)}", visual = v)
    }

    private fun c1Names() = sk(
        "ma1.names99", 1, "Number names", "one", "numbers to 99 in words",
        namesT("toNum1", 1, 0, 20, true), namesT("toWord1", 1, 0, 20, false),
        namesT("toNum2", 2, 21, 99, true), namesT("toWord2", 2, 21, 99, false),
        tp("tf", 3, 90, 3, kind = TF) { p, _ ->
            val n = 10 + p[0]
            val shown = when (p[1]) {
                0 -> n
                1 -> nameWrongs(n)[1] ?: return@tp null
                else -> nameWrongs(n)[0] ?: (n + 10).takeIf { it <= 99 } ?: return@tp null
            }
            tf("${cap(name99(n))} is written $shown.", shown == n, nameWhy(n)).copy(learnVisual = numVisual(n))
        },
    )

    private fun c1Compare() = sk(
        "ma1.compare", 1, "Compare to 99", "<>", "more, less or equal with < > =",
        tp("tens", 1, 9, 9, 10, 3) { p, _ ->
            val (ta, tb) = p[0] + 1 to p[1] + 1
            if (ta == tb) return@tp null
            val a = 10 * ta + p[2]
            val b = 10 * tb + (p[2] + 3 * p[3] + 1) % 10
            val w = if (ta < tb) "less" else "more"
            signQ("$a", "$b", a.compareTo(b), "${tens(ta)} is $w than ${tens(tb)}, so $a ${sign(a.compareTo(b))} $b.", "Is $a more or less than $b?")
        },
        tp("ones", 2, 9, 10, 10) { p, _ ->
            val t = p[0] + 1
            if (p[1] == p[2]) return@tp null
            val a = 10 * t + p[1]
            val b = 10 * t + p[2]
            val w = if (p[1] < p[2]) "less" else "more"
            signQ("$a", "$b", a.compareTo(b), "Same tens, so look at ones: ${p[1]} is $w than ${p[2]}.", "Is $a more or less than $b?")
        },
        tp("parts", 3, 9, 9, 4) { p, _ ->
            val t = p[0] + 1
            val o = p[1] + 1
            val v = 10 * t + o
            val b = when (p[2]) {
                0 -> v
                1 -> if (o != t) 10 * o + t else return@tp null
                2 -> v + 1
                else -> if (t >= 2) v - 10 else return@tp null
            }
            if (b !in 10..99) return@tp null
            val c = v.compareTo(b)
            val why = if (c == 0) "${t * 10} + $o makes $v, the same as $b."
            else "${t * 10} + $o makes $v, and $v is ${if (c < 0) "less" else "more"} than $b."
            signQ("${t * 10} + $o", "$b", c, why, "Is ${t * 10} plus $o more, less, or the same as $b?")
        },
        tp("tf", 2, 90, 4, 2, kind = TF) { p, _ ->
            val a = 10 + p[0]
            val b = when (p[1]) {
                0 -> if (a % 10 != 0 && a % 10 != a / 10) (a % 10) * 10 + a / 10 else return@tp null
                1 -> a + 10
                2 -> a - 1
                else -> a + 1
            }
            if (b !in 10..99) return@tp null
            val sg = if (p[2] == 0) ">" else "<"
            val ok = if (sg == ">") a > b else a < b
            tf("$a $sg $b", ok, "${maxOf(a, b)} is more than ${minOf(a, b)}.", "$a is ${if (sg == ">") "more" else "less"} than $b")
        },
        tp("order", 2, 9, 9, 9, 4, kind = OR) { p, r ->
            val t = intArrayOf(p[0] + 1, p[1] + 1, p[2] + 1)
            if (!(t[0] < t[1] && t[1] < t[2])) return@tp null
            val n = List(3) { 10 * t[it] + (p[3] * 3 + it * 7) % 10 }
            ord("Put in order, smallest first.", n.map { "$it" }, r, "Smaller tens come first: ${n.joinToString(", ")}.")
        },
        extra = listOf(Format.catch),
    )

    private fun makeTenWhy(a: Int, b: Int): String {
        val (big, small) = if (a >= b) a to b else b to a
        val need = 10 - big
        return "Make 10: $big + $need = 10, then ${small - need} more makes ${a + b}."
    }

    private val BRIDGE = (2..9).flatMap { a -> (2..9).map { b -> a to b } }.filter { it.first + it.second >= 11 }

    private fun c1Bridge() = sk(
        "ma1.bridge", 1, "Add by making 10", "+10", "adding to 20 by making a ten",
        tp("ten", 1, 9) { p, r ->
            val a = p[0] + 1
            gq("$a + ? = 10", nums(10 - a, listOf(11 - a, 9 - a, a), r), "$a and ${10 - a} make 10.", "$a + ${10 - a} = 10", visual = Visual.Dots(1, 10, a))
        },
        tp("teen", 1, 9, 9) { p, r ->
            val a = 10 + p[0]
            val b = p[1] + 1
            if (a % 10 + b > 9) return@tp null
            val s = a + b
            gq("$a + $b = ?", nums(s, listOf(s + 1, s - 1, s + 10, s - 10), r, min = 1), "Add the ones: ${a % 10} + $b = ${s % 10}, so $s.", "$a + $b = $s", visual = Visual.Dots(1, s, a))
        },
        tp("bridge", 2, BRIDGE.size) { p, r ->
            val (a, b) = BRIDGE[p[0]]
            val s = a + b
            gq("$a + $b = ?", nums(s, listOf(s - 1, s + 1, s - 10), r, min = 1), makeTenWhy(a, b), "$a + $b = $s", visual = Visual.Dots(1, s, a))
        },
        tp("missing", 3, BRIDGE.size, 2) { p, r ->
            val (a, b) = BRIDGE[p[0]]
            val s = a + b
            val prompt = if (p[1] == 0) "$a + ? = $s" else "? + $b = $s"
            val ans = if (p[1] == 0) b else a
            val known = if (p[1] == 0) a else b
            gq(prompt, nums(ans, listOf(ans + 1, ans - 1, s - 10, known), r, min = 1),
                "$known + ${10 - known} = 10, and ${s - 10} more makes $s, so $ans.", "$a + $b = $s", visual = Visual.Objects(s))
                .copy(learnVisual = Visual.Dots(1, s, a))
        },
        tp("tf", 2, BRIDGE.size, 3, kind = TF) { p, _ ->
            val (a, b) = BRIDGE[p[0]]
            val s = a + b
            val c = when (p[1]) { 0 -> s; 1 -> s + 1; else -> s - 1 }
            tf("$a + $b = $c", c == s, makeTenWhy(a, b)).copy(visual = Visual.Dots(1, s, a), learnVisual = Visual.Dots(1, s, a))
        },
        extra = listOf(Format.catch, Format.pairs),
    )

    private val CROSS = (11..18).flatMap { a -> ((a % 10 + 1)..9).map { b -> a to b } }.filter { it.first - it.second >= 2 }

    private fun crossWhy(a: Int, b: Int): String {
        val o = a % 10
        return "$a $MI $b: take $o to reach 10, then ${b - o} more gives ${a - b}."
    }

    private fun c1Sub20() = sk(
        "ma1.sub20", 1, "Take away to 20", "13−5", "taking away within 20",
        tp("plain", 1, 10, 10) { p, r ->
            val a = 10 + p[0]
            val b = p[1] + 1
            if (b > a % 10 && a != 10) return@tp null
            if (a == 10 && b > 9) return@tp null
            val d = a - b
            val why = if (a == 10) "Count back $b from 10: $d." else "Take $b from the ${a % 10} ones: $d."
            gq("$a $MI $b = ?", nums(d, listOf(d + 1, d - 1, a + b, d + 10), r), why, "$a $MI $b = $d", visual = Visual.Dots(1, a, d))
        },
        tp("cross", 2, CROSS.size) { p, r ->
            val (a, b) = CROSS[p[0]]
            val d = a - b
            val flip = 10 + (b - a % 10) // took the smaller ones digit from the bigger
            gq("$a $MI $b = ?", nums(d, listOf(flip, d + 1, d - 1), r), crossWhy(a, b), "$a $MI $b = $d", visual = Visual.Dots(1, a, d))
        },
        tp("missing", 3, CROSS.size, 2) { p, r ->
            val (a, b) = CROSS[p[0]]
            val d = a - b
            (if (p[1] == 0) gq("$a $MI ? = $d", nums(b, listOf(b + 1, b - 1, a + d), r, min = 1), "$a $MI $b = $d, so the missing number is $b.", "$a $MI $b = $d", visual = Visual.Objects(a))
            else gq("? $MI $b = $d", nums(a, listOf(d - b, a + 1, a - 1), r, min = 1), "$d + $b = $a, so $a $MI $b = $d.", "$a $MI $b = $d")).copy(learnVisual = Visual.Dots(1, a, d))
        },
        tp("tf", 2, CROSS.size, 3, kind = TF) { p, _ ->
            val (a, b) = CROSS[p[0]]
            val d = a - b
            val c = when (p[1]) { 0 -> d; 1 -> 10 + (b - a % 10); else -> d + 1 }
            tf("$a $MI $b = $c", c == d, crossWhy(a, b), "$a take away $b is $c").copy(visual = Visual.Objects(a), learnVisual = Visual.Dots(1, a, d))
        },
        extra = listOf(Format.catch, Format.pairs),
    )

    private val STORY_ADD = (5..12).flatMap { a -> (2..8).map { b -> a to b } }
    private val STORY_SUB = (9..20).flatMap { a -> (2..8).map { b -> a to b } }
    private val STORY_CMP = (6..20).flatMap { x -> (1..9).map { d -> x to x - d } }.filter { it.second >= 2 }

    private fun c1Story() = sk(
        "ma1.story", 1, "Story sums", "+?", "one-step word problems",
        tp("add", 1, KIDS.size, 8, STORY_ADD.size) { p, r ->
            val k = KIDS[p[0]]
            val t = THINGS[p[1]]
            val (a, b) = STORY_ADD[p[2]]
            val s = a + b
            gq("${k.name} has ${t.n(a)}. ${friend(p[0]).name} gives ${k.him} $b more. How many does ${k.he} have now?",
                nums(s, listOf(s + 1, s - 1, a - b, s + 10), r, min = 1), "Add: $a + $b = $s ${t.many}.", "$a + $b = $s", visual = Visual.Picture(t.pic))
                .copy(learnVisual = Visual.Dots(1, s, a))
        },
        tp("sub", 2, KIDS.size, 5, STORY_SUB.size) { p, r ->
            val k = KIDS[p[0]]
            val t = THINGS[p[1] + 5]
            val (a, b) = STORY_SUB[p[2]]
            val d = a - b
            gq("${k.name} had ${t.n(a)}. ${k.heCap} gave $b to ${friend(p[0]).name}. How many are left?",
                nums(d, listOf(a + b, d + 1, d - 1), r, min = 1), "Take away: $a $MI $b leaves ${t.n(d)}.", "$a $MI $b = $d", visual = Visual.Picture(t.pic))
                .copy(learnVisual = Visual.Dots(1, a, d))
        },
        tp("cmp", 3, KIDS.size, 5, STORY_CMP.size) { p, r ->
            val k = KIDS[p[0]]
            val f = friend(p[0])
            val t = THINGS[(p[1] * 2 + p[0]) % THINGS.size]
            val (x, y) = STORY_CMP[p[2]]
            val d = x - y
            gq("${k.name} has ${t.n(x)}. ${f.name} has ${t.n(y)}. How many more does ${k.name} have?",
                nums(d, listOf(x + y, d + 1, d - 1, y), r, min = 1), "Find the difference: $x $MI $y = $d.", "$x $MI $y = $d", visual = Visual.Picture(t.pic))
                .copy(learnVisual = Visual.Dots(1, x, y))
        },
    )

    private val STEPS = listOf(2, 5, 10)

    private fun c1Skip() = sk(
        "ma1.skip", 1, "Skip counting", "2s5s", "counting in 2s, 5s and 10s",
        tp("fwd", 1, 3, 48) { p, r ->
            val st = STEPS[p[0]]
            val start = p[1] * st
            val ans = start + 4 * st
            if (ans > 100) return@tp null
            val seq = (0..3).map { start + it * st }
            gq("Count by ${st}s: ${seq.joinToString(", ")}, ?", nums(ans, listOf(seq[3] + 1, ans + st, ans - 1), r),
                "Counting by ${st}s, add $st each time: $ans.", "${seq[3]} + $st = $ans",
                visual = if (start == 0 && st <= 5) Visual.Dots(4, st) else null)
                .copy(learnVisual = if (ans / st <= 10 && start == 0) Visual.Dots(ans / st, st) else null)
        },
        tp("back", 2, 3, 48) { p, r ->
            val st = STEPS[p[0]]
            val top = (p[1] + 4) * st
            if (top > 100) return@tp null
            val seq = (0..3).map { top - it * st }
            val ans = top - 4 * st
            gq("Count back by ${st}s: ${seq.joinToString(", ")}, ?", nums(ans, listOf(seq[3] - 1, ans - st, seq[3] + st), r),
                "Counting back by ${st}s, take $st away each time: $ans.", "${seq[3]} $MI $st = $ans")
        },
        tp("gap", 3, 3, 48, 3) { p, r ->
            val st = STEPS[p[0]]
            val start = p[1] * st
            if (start + 4 * st > 100) return@tp null
            val seq = (0..4).map { start + it * st }
            val gap = p[2] + 1
            val ans = seq[gap]
            val shown = seq.mapIndexed { i, v -> if (i == gap) "?" else "$v" }
            gq("Fill the gap: ${shown.joinToString(", ")}", nums(ans, listOf(seq[gap - 1] + 1, ans + st, ans - 1), r),
                "${seq[gap - 1]} + $st = $ans, the missing number.", "${seq[gap - 1]} + $st = $ans")
        },
        tp("order", 2, 3, 48, kind = OR) { p, r ->
            val st = STEPS[p[0]]
            val start = p[1] * st
            if (start + 3 * st > 100) return@tp null
            val seq = (0..3).map { start + it * st }
            ord("Count by ${st}s: put in order, smallest first.", seq.map { "$it" }, r, "Add $st each time: ${seq.joinToString(", ")}.")
        },
        extra = listOf(Format.catch),
    )

    private fun c1Tens() = sk(
        "ma1.tens10", 1, "10 more, 10 less", "±10", "10 more, 10 less, 1 more, 1 less",
        tp("tens", 1, 2, 10) { p, r ->
            val n = p[1] * 10
            val more = p[0] == 0
            val ans = if (more) n + 10 else n - 10
            if (ans !in 0..100) return@tp null
            gq("What is 10 ${if (more) "more" else "less"} than $n?", nums(ans, listOf(if (more) n + 1 else n - 1, if (more) n - 10 else n + 10, n), r),
                "${if (more) "Add" else "Take away"} 1 ten: ${tens(n / 10)} becomes ${tens(ans / 10)}.", "$n ${if (more) "+" else MI} 10 = $ans",
                visual = if (n > 0) Visual.Dots(n / 10, 10) else null)
        },
        tp("any", 2, 2, 89) { p, r ->
            val n = 11 + p[1]
            if (n % 10 == 0) return@tp null
            val more = p[0] == 0
            val ans = if (more) n + 10 else n - 10
            if (ans !in 1..99) return@tp null
            gq("What is 10 ${if (more) "more" else "less"} than $n?", nums(ans, listOf(if (more) n + 1 else n - 1, if (more) n - 10 else n + 10, ans + 1), r),
                "Only the tens change: $n ${if (more) "+" else MI} 10 = $ans.", "$n ${if (more) "+" else MI} 10 = $ans")
        },
        tp("two", 3, 2, 2, 80) { p, r ->
            val n = 11 + p[2]
            val t = if (p[0] == 0) 10 else -10
            val o = if (p[1] == 0) 1 else -1
            val mid = n + t
            val ans = mid + o
            if (mid !in 1..99 || ans !in 1..99) return@tp null
            fun w(v: Int) = if (v > 0) "add $v" else "take away ${-v}"
            fun op(v: Int) = if (v > 0) "+ $v" else "$MI ${-v}"
            gq("Start at $n. ${cap(w(t))}, then ${w(o)}. Where are you?", nums(ans, listOf(mid, n + o, n - t + o, ans + 2 * o), r),
                "$n ${op(t)} = $mid, then $mid ${op(o)} = $ans.", "$n ${op(t)} ${op(o)} = $ans")
        },
        tp("tf", 2, 2, 89, 3, kind = TF) { p, _ ->
            val n = 11 + p[1]
            val more = p[0] == 0
            val ans = if (more) n + 10 else n - 10
            if (ans !in 1..99) return@tp null
            val c = when (p[2]) { 0 -> ans; 1 -> if (more) n + 1 else n - 1; else -> if (more) n - 10 else n + 10 }
            if (c !in 0..109) return@tp null
            tf("10 ${if (more) "more" else "less"} than $n is $c.", c == ans, "Only the tens change: $n ${if (more) "+" else MI} 10 = $ans.")
        },
        extra = listOf(Format.catch),
    )

    // ───────────────────────── Class 2 ─────────────────────────

    private fun c2() = listOf(c2Place(), c2Order(), c2AddCarry(), c2SubBorrow(), c2OddEven(), c2Missing(), c2Calendar(), c2Units())

    private fun hto(h: Int, t: Int, o: Int) = 100 * h + 10 * t + o
    private fun htoWhy(n: Int) = "$n is ${n / 100} hundreds, ${tens(n / 10 % 10)} and ${ones(n % 10)}."

    private fun c2Place() = sk(
        "ma2.place3", 2, "Hundreds, tens, ones", "HTO", "place value to 999",
        tp("digit", 1, 9, 10, 10, 3) { p, r ->
            val d = intArrayOf(p[0] + 1, p[1], p[2])
            if (d.toSet().size != 3) return@tp null
            val n = hto(d[0], d[1], d[2])
            val place = p[3] // 0 ones, 1 tens, 2 hundreds
            val ans = d[2 - place]
            val extra = (0..9).first { it !in d.toList() }
            gq("Which digit is in the ${PLACE[place]} place of $n?", Opt.of("$ans", (d.toList() - ans + extra).map { "$it" }, r)!!, htoWhy(n), "The ${PLACE[place]} digit of $n is $ans")
        },
        tp("value", 2, 9, 10, 10, 3) { p, r ->
            val d = intArrayOf(p[0] + 1, p[1], p[2])
            if (d.toSet().size != 3) return@tp null
            val place = p[3]
            val dig = d[2 - place]
            if (dig == 0) return@tp null
            val n = hto(d[0], d[1], d[2])
            val v = dig * listOf(1, 10, 100)[place]
            gq("What is the value of the $dig in $n?", nums(v, listOf(dig, dig * 10, dig * 100, dig * 1000), r),
                "The $dig is in the ${PLACE[place]} place, so it means $v.", "$dig in $n means $v")
        },
        tp("expand", 2, 9, 10, 10) { p, r ->
            val (h, t, o) = Triple(p[0] + 1, p[1], p[2])
            val n = hto(h, t, o)
            val parts = listOfNotNull("${h * 100}", if (t > 0) "${t * 10}" else null, if (o > 0) "$o" else null)
            val joined = "${h * 100}".dropLast(2) + (if (t > 0) "${t * 10}" else "") + (if (o > 0) "$o" else "")
            gq("${parts.joinToString(" + ")} = ?", nums(n, listOf(hto(h, o, t).takeIf { t != o }, joined.toIntOrNull(), hto(t, h, o).takeIf { t > 0 && t != h }, n + 10), r, min = 100),
                "${parts.joinToString(" + ")} makes $n.", "${parts.joinToString(" + ")} = $n")
        },
        tp("words", 3, 9, 10, 10) { p, r ->
            val (h, t, o) = Triple(p[0] + 1, p[1], p[2])
            if (t != 0 && o != 0) return@tp null
            if (t == 0 && o == 0) return@tp null
            val n = hto(h, t, o)
            val said = if (t == 0) "$h hundreds and ${ones(o)}" else "$h hundreds and ${tens(t)}"
            val short = if (t == 0) h * 10 + o else h * 10 + t
            gq("$said = ?", nums(n, listOf(short, if (t == 0) hto(h, o, 0) else hto(h, 0, t), n + 100), r, min = 10),
                "No ${if (t == 0) "tens" else "ones"}, so write 0 there: $n.", "$said = $n")
        },
        tp("mixed", 3, 9, 9, 9) { p, r ->
            val (h, t, o) = Triple(p[0] + 1, p[1] + 1, p[2] + 1)
            if (setOf(h, t, o).size != 3) return@tp null
            val n = hto(h, t, o)
            gq("${ones(o)}, $h hundreds and ${tens(t)} = ?", nums(n, listOf(hto(o, h, t), hto(h, o, t), hto(t, o, h)), r, min = 100),
                "Hundreds first, then tens, then ones: $n.", "$n")
        },
    )

    private fun c2Order() = sk(
        "ma2.order999", 2, "Compare and order", "<>", "comparing and ordering numbers to 999",
        tp("cmp", 1, 9, 10, 10, 4) { p, _ ->
            val (h, t, o) = Triple(p[0] + 1, p[1], p[2])
            val a = hto(h, t, o)
            val b = when (p[3]) {
                0 -> if (t != o) hto(h, o, t) else return@tp null
                1 -> if (t != 0 && t != h) hto(t, h, o) else return@tp null
                2 -> a + 10
                else -> a - 100
            }
            if (b !in 100..999) return@tp null
            signQ("$a", "$b", a.compareTo(b), cmpWhy(a.toLong(), b.toLong()) { "$it" }, "Is $a more or less than $b?")
        },
        tp("tf", 1, 9, 10, 10, kind = TF) { p, _ ->
            val (h, t, o) = Triple(p[0] + 1, p[1], p[2])
            if (t == o) return@tp null
            val a = hto(h, t, o)
            val b = hto(h, o, t)
            val sg = if ((h + t + o) % 2 == 0) ">" else "<"
            tf("$a $sg $b", if (sg == ">") a > b else a < b, cmpWhy(a.toLong(), b.toLong()) { "$it" }, "$a is ${if (sg == ">") "more" else "less"} than $b")
        },
        tp("order", 2, 9, 9, 9, kind = OR) { p, r ->
            val (h, t, o) = Triple(p[0] + 1, p[1] + 1, p[2] + 1)
            if (setOf(h, t, o).size != 3) return@tp null
            val n = listOf(hto(h, t, o), hto(h, o, t), hto(t, h, o)).sorted()
            ord("Put in order, smallest first.", n.map { "$it" }, r, "Compare hundreds first: ${n.joinToString(", ")}.")
        },
        tp("order4", 3, 9, 9, 9, kind = OR) { p, r ->
            val (h, t, o) = Triple(p[0] + 1, p[1] + 1, p[2] + 1)
            if (!(h < t && t < o)) return@tp null
            val n = listOf(hto(h, t, o), hto(h, o, t), hto(t, h, o), hto(o, t, h)).sorted()
            ord("Put in order, smallest first.", n.map { "$it" }, r, "Hundreds first, then tens: ${n.joinToString(", ")}.")
        },
        tp("biggest", 2, 9, 9, 9, 2) { p, r ->
            val (h, t, o) = Triple(p[0] + 1, p[1] + 1, p[2] + 1)
            if (!(h < t && t < o)) return@tp null
            val n = listOf(hto(h, t, o), hto(h, o, t), hto(t, o, h), hto(o, h, t))
            val big = p[3] == 0
            val ans = if (big) n.max() else n.min()
            gq("Which is the ${if (big) "biggest" else "smallest"}?", texts("$ans", n.filter { it != ans }.map { "$it" }, r)!!,
                "Look at the hundreds first: $ans has the ${if (big) "most" else "fewest"}.", "$ans is the ${if (big) "biggest" else "smallest"}")
        },
        tp("make", 3, 10, 10, 10, 2) { p, r ->
            val (a, b, c) = Triple(p[0], p[1], p[2])
            if (!(a < b && b < c)) return@tp null
            val big = p[3] == 0
            val shown = "$c, $a and $b"
            if (big) {
                val ans = hto(c, b, a)
                gq("Make the biggest 3-digit number with $shown.", nums(ans, listOf(hto(c, a, b), hto(b, c, a), if (a > 0) hto(a, b, c) else null), r, min = 100),
                    "Biggest digit first: $c, then $b, then $a makes $ans.", "$ans")
            } else {
                val lead = if (a == 0) b else a
                val rest = listOf(a, b, c) - lead
                val ans = hto(lead, rest[0], rest[1])
                val why = if (a == 0) "0 can't go first, so start with $b: $ans." else "Smallest digit first: $a, then $b, then $c makes $ans."
                gq("Make the smallest 3-digit number with $shown.", nums(ans, listOf(hto(lead, rest[1], rest[0]), hto(rest[0], lead, rest[1]), if (a == 0) 10 * b + c else hto(c, b, a)), r, min = 10),
                    why, "$ans")
            }
        },
    )

    /** Column sums without carrying (a mistake): each place on its own, mod 10. */
    private fun noCarry(a: Int, b: Int): Int {
        var x = a; var y = b; var m = 1; var out = 0
        while (x > 0 || y > 0) { out += ((x % 10 + y % 10) % 10) * m; x /= 10; y /= 10; m *= 10 }
        return out
    }

    /** Column take-away, smaller digit from bigger in each place (a mistake). */
    private fun noBorrow(a: Int, b: Int): Int {
        var x = a; var y = b; var m = 1; var out = 0
        while (x > 0 || y > 0) { out += abs(x % 10 - y % 10) * m; x /= 10; y /= 10; m *= 10 }
        return out
    }

    private fun addWhy(a: Int, b: Int): String {
        val ones = a % 10 + b % 10
        val ta = a / 10
        val tb = b / 10
        return if (ones < 10) "Ones: ${a % 10} + ${b % 10} = $ones; tens: $ta + $tb = ${ta + tb}; so ${a + b}."
        else "Ones make $ones, carry 1; tens make $ta + $tb + 1 = ${ta + tb + 1}: ${a + b}."
    }

    private fun subWhy(a: Int, b: Int): String {
        val (oa, ob, ta, tb) = listOf(a % 10, b % 10, a / 10, b / 10)
        return if (oa >= ob) "Ones: $oa $MI $ob = ${oa - ob}; tens: $ta $MI $tb = ${ta - tb}; so ${a - b}."
        else "Borrow a ten: ${oa + 10} $MI $ob = ${oa + 10 - ob}; tens: ${ta - 1} $MI $tb = ${ta - 1 - tb}; so ${a - b}."
    }

    /** b for 2-digit sums: distinct per (a, k). */
    private fun bOf(a: Int, k: Int) = 11 + 9 * k + a % 9

    private fun c2AddCarry() = sk(
        "ma2.addCarry", 2, "Add with carrying", "+",
        "2-digit adding, with and without carrying",
        tp("plain", 1, 90, 9) { p, r ->
            val a = 10 + p[0]
            val b = bOf(a, p[1])
            if (a % 10 + b % 10 >= 10 || a / 10 + b / 10 >= 10) return@tp null
            val s = a + b
            gq("$a + $b = ?", nums(s, listOf(s + 10, s - 10, s + 1, s - 1), r, min = 1), addWhy(a, b), "$a + $b = $s")
        },
        tp("carry", 2, 90, 9) { p, r ->
            val a = 10 + p[0]
            val b = bOf(a, p[1])
            if (b > 99 || a % 10 + b % 10 < 10) return@tp null
            val s = a + b
            val side = "${a / 10 + b / 10}${a % 10 + b % 10}".toInt()
            gq("$a + $b = ?", nums(s, listOf(s - 10, side, s + 1, s + 10), r, min = 1), addWhy(a, b), "$a + $b = $s")
        },
        tp("digit", 3, 90, 9, 2) { p, r ->
            val a = 10 + p[0]
            val b = bOf(a, p[1])
            if (b > 99) return@tp null
            val s = a + b
            val tensGone = p[2] == 0
            val dig = if (tensGone) a / 10 else a % 10
            val shown = if (tensGone) "_${a % 10}" else "${a / 10}_"
            gq("$shown + $b = $s. Which digit is missing?", nums(dig, listOf(dig + 1, dig - 1, dig + 2), r, f = { "$it" }).takeIf { (o, _) -> o.all { it.length == 1 } }
                ?: nums(dig, listOf(dig - 1, dig - 2, dig - 3), r, f = { "$it" }),
                "$a + $b = $s, so the missing digit is $dig.", "$a + $b = $s")
        },
        tp("tf", 2, 90, 9, 2, kind = TF) { p, _ ->
            val a = 10 + p[0]
            val b = bOf(a, p[1])
            if (b > 99 || a % 10 + b % 10 < 10) return@tp null
            val s = a + b
            val c = if (p[2] == 0) s else s - 10
            tf("$a + $b = $c", c == s, addWhy(a, b))
        },
        extra = listOf(Format.catch),
    )

    private fun c2SubBorrow() = sk(
        "ma2.subBorrow", 2, "Take away, borrowing", "−",
        "2-digit taking away, with and without borrowing",
        tp("plain", 1, 80, 9) { p, r ->
            val a = 20 + p[0]
            val b = bOf(a, p[1])
            if (b >= a || a % 10 < b % 10) return@tp null
            val d = a - b
            gq("$a $MI $b = ?", nums(d, listOf(d + 10, d - 10, d + 1, d - 1), r, min = 1), subWhy(a, b), "$a $MI $b = $d")
        },
        tp("borrow", 2, 80, 9) { p, r ->
            val a = 20 + p[0]
            val b = bOf(a, p[1])
            if (b >= a || a % 10 >= b % 10) return@tp null
            val d = a - b
            gq("$a $MI $b = ?", nums(d, listOf(noBorrow(a, b), d + 10, d + 1, d - 1), r, min = 1), subWhy(a, b), "$a $MI $b = $d")
        },
        tp("digit", 3, 80, 9, 2) { p, r ->
            val a = 20 + p[0]
            val b = bOf(a, p[1])
            if (b >= a) return@tp null
            val d = a - b
            val onesGone = p[2] == 0
            val dig = if (onesGone) b % 10 else b / 10
            val shown = if (onesGone) "${b / 10}_" else "_${b % 10}"
            gq("$a $MI $shown = $d. Which digit is missing?", nums(dig, listOf(dig + 1, dig - 1, dig + 2), r, f = { "$it" }).takeIf { (o, _) -> o.all { it.length == 1 } }
                ?: nums(dig, listOf(dig - 1, dig - 2, dig - 3), r, f = { "$it" }),
                "$a $MI $b = $d, so the missing digit is $dig.", "$a $MI $b = $d")
        },
        tp("tf", 2, 80, 9, 2, kind = TF) { p, _ ->
            val a = 20 + p[0]
            val b = bOf(a, p[1])
            if (b >= a || a % 10 >= b % 10) return@tp null
            val d = a - b
            val c = if (p[2] == 0) d else noBorrow(a, b)
            tf("$a $MI $b = $c", c == d, subWhy(a, b), "$a take away $b is $c")
        },
        extra = listOf(Format.catch),
    )

    private fun oddWhy(n: Int) = "It ends in ${n % 10}, so $n is ${if (n % 2 == 0) "even" else "odd"}."

    private fun c2OddEven() = sk(
        "ma2.oddEven", 2, "Odd and even", "odd", "odd and even numbers",
        tp("small", 1, 30, kind = SO) { p, _ ->
            val n = p[0] + 1
            sortQ("Is $n odd or even?", "Odd", "Even", n % 2 == 1, oddWhy(n)).copy(visual = if (n <= 20) Visual.Objects(n) else null)
        },
        tp("big", 2, 170, kind = SO) { p, _ ->
            val n = 31 + p[0]
            sortQ("Is $n odd or even?", "Odd", "Even", n % 2 == 1, oddWhy(n))
        },
        tp("sum", 3, 30, 20, kind = SO) { p, _ ->
            val (a, b) = p[0] + 1 to p[1] + 1
            val s = a + b
            sortQ("Is $a + $b odd or even?", "Odd", "Even", s % 2 == 1, "$a + $b = $s, which ends in ${s % 10}, so ${if (s % 2 == 0) "even" else "odd"}.")
        },
        tp("pick", 2, 2, 150) { p, r ->
            val even = p[0] == 0
            val ans = if (even) 12 + 2 * p[1] else 11 + 2 * p[1]
            gq("Which number is ${if (even) "even" else "odd"}?", nums(ans, listOf(ans + 1, ans - 1, ans + 3, ans - 3), r), oddWhy(ans), "$ans is ${if (even) "even" else "odd"}")
        },
        extra = listOf(Format.catch),
    )

    private fun c2Missing() = sk(
        "ma2.missing", 2, "Missing numbers", "_+5", "the missing number in a sum",
        tp("add", 1, 19, 19, 2) { p, r ->
            val (a, b) = p[0] + 1 to p[1] + 1
            val s = a + b
            if (s > 20) return@tp null
            val ansLeft = p[2] == 0
            val ans = if (ansLeft) a else b
            val known = if (ansLeft) b else a
            gq(if (ansLeft) "? + $b = $s" else "$a + ? = $s", nums(ans, listOf(s + known, ans + 1, ans - 1, s), r, min = 1),
                "$s $MI $known = $ans, so $a + $b = $s.", "$a + $b = $s", visual = Visual.Objects(s))
                .copy(learnVisual = Visual.Dots(1, s, known))
        },
        tp("sub", 2, 20, 19, 2) { p, r ->
            val a = p[0] + 2
            val b = p[1] + 1
            if (b >= a) return@tp null
            val d = a - b
            if (p[2] == 0) gq("$a $MI ? = $d", nums(b, listOf(a + d, b + 1, b - 1), r, min = 1), "$a $MI $b = $d, so the missing number is $b.", "$a $MI $b = $d")
            else gq("? $MI $b = $d", nums(a, listOf(d - b, a + 1, a - 1), r, min = 1), "$d + $b = $a, so $a $MI $b = $d.", "$a $MI $b = $d")
        },
        tp("big", 3, 70, 8, 2) { p, r ->
            val a = 11 + p[0]
            val b = 11 + 9 * p[1] + a % 7
            val s = a + b
            if (s > 99) return@tp null
            if (p[2] == 0) gq("? + $b = $s", nums(a, listOf(s + b, a + 10, a - 10, a + 1), r, min = 1), "$s $MI $b = $a, so $a + $b = $s.", "$a + $b = $s")
            else gq("$s $MI ? = $a", nums(b, listOf(s + a, b + 10, b - 10, b + 1), r, min = 1), "$s $MI $b = $a, so the missing number is $b.", "$s $MI $b = $a")
        },
        extra = listOf(Format.catch, Format.pairs),
    )

    private val DAYS = listOf("Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday")
    private val MONTHS = listOf("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")
    private val MONTH_DAYS = listOf(31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31)

    private fun c2Calendar() = sk(
        "ma2.calendar", 2, "Days and months", "Mon", "days of the week and months of the year",
        tp("day", 1, 7, 2) { p, r ->
            val after = p[1] == 0
            val ans = DAYS[(p[0] + if (after) 1 else 6) % 7]
            gq("What day comes just ${if (after) "after" else "before"} ${DAYS[p[0]]}?",
                Opt.of(ans, listOf(DAYS[(p[0] + if (after) 6 else 1) % 7], DAYS[(p[0] + if (after) 2 else 5) % 7], DAYS[p[0]]), r)!!,
                "Just ${if (after) "after" else "before"} ${DAYS[p[0]]} comes $ans.", "$ans")
        },
        tp("month", 1, 12, 2) { p, r ->
            val after = p[1] == 0
            val ans = MONTHS[(p[0] + if (after) 1 else 11) % 12]
            gq("What month comes just ${if (after) "after" else "before"} ${MONTHS[p[0]]}?",
                Opt.of(ans, listOf(MONTHS[(p[0] + if (after) 11 else 1) % 12], MONTHS[(p[0] + if (after) 2 else 10) % 12], MONTHS[p[0]]), r)!!,
                "Just ${if (after) "after" else "before"} ${MONTHS[p[0]]} comes $ans.", "$ans")
        },
        tp("days", 2, 7, 5, 2) { p, r ->
            val k = p[1] + 2
            val after = p[2] == 0
            val sg = if (after) 1 else -1
            val ans = DAYS[(p[0] + sg * k).mod(7)]
            gq("What day is $k days ${if (after) "after" else "before"} ${DAYS[p[0]]}?",
                Opt.of(ans, listOf(DAYS[(p[0] + sg * (k + 1)).mod(7)], DAYS[(p[0] + sg * (k - 1)).mod(7)], DAYS[(p[0] - sg * k).mod(7)]), r)!!,
                "Count $k days ${if (after) "on" else "back"} from ${DAYS[p[0]]}: $ans.", "$ans")
        },
        tp("months", 2, 12, 4, 2) { p, r ->
            val k = p[1] + 2
            val after = p[2] == 0
            val sg = if (after) 1 else -1
            val ans = MONTHS[(p[0] + sg * k).mod(12)]
            gq("What month is $k months ${if (after) "after" else "before"} ${MONTHS[p[0]]}?",
                Opt.of(ans, listOf(MONTHS[(p[0] + sg * (k + 1)).mod(12)], MONTHS[(p[0] + sg * (k - 1)).mod(12)], MONTHS[(p[0] - sg * k).mod(12)]), r)!!,
                "Count $k months ${if (after) "on" else "back"} from ${MONTHS[p[0]]}: $ans.", "$ans")
        },
        tp("long", 3, 7, 7, 2) { p, r ->
            val k = p[1] + 8
            val after = p[2] == 0
            val sg = if (after) 1 else -1
            val ans = DAYS[(p[0] + sg * k).mod(7)]
            val prompt = if (after) "Today is ${DAYS[p[0]]}. What day will it be in $k days?" else "Today is ${DAYS[p[0]]}. What day was it $k days ago?"
            gq(prompt, Opt.of(ans, listOf(DAYS[(p[0] + sg * (k + 1)).mod(7)], DAYS[(p[0] + sg * (k - 1)).mod(7)], DAYS[(p[0] - sg * k).mod(7)]), r)!!,
                "$k days is 1 week and ${k - 7} more, so $ans.", "$ans")
        },
        tp("len", 2, 12) { p, r ->
            if (p[0] == 1) return@tp null
            val n = MONTH_DAYS[p[0]]
            gq("How many days are there in ${MONTHS[p[0]]}?", nums(n, listOf(if (n == 31) 30 else 31, 28, 7), r), "${MONTHS[p[0]]} has $n days.", "$n days")
        },
        tp("lenTf", 3, 12, 2, kind = TF) { p, _ ->
            if (p[0] == 1) return@tp null
            val n = MONTH_DAYS[p[0]]
            val said = if (p[1] == 0) n else if (n == 31) 30 else 31
            tf("${MONTHS[p[0]]} has $said days.", said == n, "${MONTHS[p[0]]} has $n days.")
        },
        tp("order", 2, 9, 3, 3, 3, kind = OR) { p, r ->
            val a = p[0]
            val b = a + p[1] + 1
            val c = b + p[2] + 1
            val d = c + p[3] + 1
            val m = if (d <= 11) listOf(a, b, c, d) else if (c <= 11 && p[3] == 2) listOf(a, b, c) else return@tp null
            ord("Put the months in order, as they come in a year.", m.map { MONTHS[it] }, r, "The year goes ${m.joinToString(", ") { MONTHS[it] }}.")
        },
        extra = listOf(Format.catch),
    )

    /** A measure for "which unit?": [pre] v [unit] [post]. Tier 1 cm/m, 2 kg/L, 3 g/mL/km. */
    private class Meas(val pre: String, val v: Int, val unit: String, val post: String, val what: String) {
        val tier = when (unit) { "cm", "m" -> 1; "kg", "L" -> 2; else -> 3 }
        fun say(u: String) = "$pre $v $u${if (post.isEmpty()) "" else " $post"}."
        val pic: String? get() = UNIT_PICS.firstOrNull { (k, _) -> pre.contains(k, true) }?.second
    }

    private val MEAS = listOf(
        Meas("A pencil is about", 15, "cm", "long", "the length of a pencil"),
        Meas("A crayon is about", 8, "cm", "long", "the length of a crayon"),
        Meas("A spoon is about", 15, "cm", "long", "the length of a spoon"),
        Meas("A notebook is about", 25, "cm", "long", "the length of a notebook"),
        Meas("A cup is about", 10, "cm", "tall", "the height of a cup"),
        Meas("A shoe is about", 20, "cm", "long", "the length of a shoe"),
        Meas("A leaf is about", 6, "cm", "long", "the length of a leaf"),
        Meas("A comb is about", 12, "cm", "long", "the length of a comb"),
        Meas("A piece of chalk is about", 6, "cm", "long", "the length of a piece of chalk"),
        Meas("A water bottle is about", 25, "cm", "tall", "the height of a water bottle"),
        Meas("A door is about", 2, "m", "tall", "the height of a door"),
        Meas("A classroom is about", 8, "m", "long", "the length of a classroom"),
        Meas("A bus is about", 10, "m", "long", "the length of a bus"),
        Meas("A tall tree is about", 12, "m", "tall", "the height of a tall tree"),
        Meas("A saree is about", 5, "m", "long", "the length of a saree"),
        Meas("A swimming pool is about", 25, "m", "long", "the length of a swimming pool"),
        Meas("A cricket pitch is about", 20, "m", "long", "the length of a cricket pitch"),
        Meas("A school corridor is about", 30, "m", "long", "the length of a school corridor"),
        Meas("A skipping rope is about", 2, "m", "long", "the length of a skipping rope"),
        Meas("A flagpole is about", 6, "m", "tall", "the height of a flagpole"),
        Meas("A bag of rice weighs about", 5, "kg", "", "the weight of a bag of rice"),
        Meas("A watermelon weighs about", 3, "kg", "", "the weight of a watermelon"),
        Meas("A school bag weighs about", 4, "kg", "", "the weight of a school bag"),
        Meas("A full gas cylinder weighs about", 30, "kg", "", "the weight of a gas cylinder"),
        Meas("A pumpkin weighs about", 2, "kg", "", "the weight of a pumpkin"),
        Meas("A goat weighs about", 30, "kg", "", "the weight of a goat"),
        Meas("A child of seven weighs about", 22, "kg", "", "the weight of a child"),
        Meas("A sack of potatoes weighs about", 25, "kg", "", "the weight of a sack of potatoes"),
        Meas("A bucket holds about", 10, "L", "of water", "the water in a bucket"),
        Meas("A big bottle holds about", 1, "L", "of water", "the water in a big bottle"),
        Meas("A jug holds about", 2, "L", "of water", "the water in a jug"),
        Meas("A water tank holds about", 500, "L", "", "the water in a tank"),
        Meas("A big cooking pot holds about", 5, "L", "", "the water in a big pot"),
        Meas("A car's petrol tank holds about", 35, "L", "", "the petrol in a car's tank"),
        Meas("A milk can holds about", 20, "L", "of milk", "the milk in a milk can"),
        Meas("An apple weighs about", 150, "g", "", "the weight of an apple"),
        Meas("A coin weighs about", 5, "g", "", "the weight of a coin"),
        Meas("A pencil weighs about", 6, "g", "", "the weight of a pencil"),
        Meas("A biscuit weighs about", 10, "g", "", "the weight of a biscuit"),
        Meas("A letter weighs about", 20, "g", "", "the weight of a letter"),
        Meas("A banana weighs about", 120, "g", "", "the weight of a banana"),
        Meas("A teaspoon holds about", 5, "mL", "", "the medicine in a teaspoon"),
        Meas("A glass holds about", 200, "mL", "of water", "the water in a glass"),
        Meas("A cup of tea is about", 150, "mL", "", "the tea in a cup"),
        Meas("A small ink bottle holds about", 60, "mL", "", "the ink in a small bottle"),
        Meas("A juice box holds about", 200, "mL", "", "the juice in a juice box"),
        Meas("Delhi to Agra is about", 230, "km", "", "the distance from Delhi to Agra"),
        Meas("Mumbai to Pune is about", 150, "km", "", "the distance from Mumbai to Pune"),
        Meas("A long walk is about", 5, "km", "", "the length of a long walk"),
        Meas("A marathon is about", 42, "km", "long", "the length of a marathon"),
    )

    private val UNIT_PICS = listOf(
        "pencil" to "pencil", "crayon" to "crayon", "teaspoon" to "spoon", "spoon" to "spoon", "notebook" to "notebook",
        "cup" to "cup", "shoe" to "shoe", "leaf" to "leaf", "comb" to "comb", "bottle" to "bottle", "door" to "door",
        "bus" to "bus", "tree" to "tree", "saree" to "saree", "rope" to "rope", "rice" to "rice", "watermelon" to "watermelon",
        "school bag" to "schoolbag", "pumpkin" to "pumpkin", "goat" to "goat", "potatoes" to "potato", "bucket" to "bucket",
        "cooking pot" to "pot", "petrol" to "car", "milk" to "milk", "apple" to "apple", "banana" to "banana", "glass" to "glass",
        "marathon" to "shoe",
    )

    private fun family(u: String) = when (u) { "cm", "m", "km" -> listOf("cm", "m", "km"); "g", "kg" -> listOf("g", "kg"); else -> listOf("mL", "L") }
    private fun unitWrongs(u: String) = family(u).filter { it != u } + listOf("kg", "L", "m", "cm").filter { it !in family(u) }

    private fun unitsT(tier: Int): List<Template> {
        val rows = MEAS.filter { it.tier == tier }
        return listOf(
            tp("fill$tier", tier, rows.size) { p, r ->
                val m = rows[p[0]]
                gq("${m.pre} ${m.v} __${if (m.post.isEmpty()) "" else " " + m.post}. Which unit?", Opt.of(m.unit, unitWrongs(m.unit), r)!!,
                    m.say(m.unit), m.say(m.unit).removeSuffix("."), visual = m.pic?.let { Visual.Picture(it) })
            },
            tp("which$tier", tier, rows.size) { p, r ->
                val m = rows[p[0]]
                gq("Which unit would you use for ${m.what}?", Opt.of(m.unit, unitWrongs(m.unit), r)!!, m.say(m.unit), m.unit, visual = m.pic?.let { Visual.Picture(it) })
            },
            tp("tf$tier", tier, rows.size, 3, kind = TF) { p, _ ->
                val m = rows[p[0]]
                val said = if (p[1] == 0) m.unit else family(m.unit).filter { it != m.unit }.getOrNull(p[1] - 1) ?: return@tp null
                tf(m.say(said), said == m.unit, m.say(m.unit)).let { q -> m.pic?.let { q.copy(visual = Visual.Picture(it), learnVisual = Visual.Picture(it)) } ?: q }
            },
        )
    }

    private fun c2Units() = sk(
        "ma2.units", 2, "Which unit?", "cm", "choosing cm, m, km, g, kg, mL or L",
        *(unitsT(1) + unitsT(2) + unitsT(3)).toTypedArray(),
        tp("sortLen", 1, MEAS.size, kind = SO) { p, _ ->
            val m = MEAS[p[0]]
            if (m.unit != "cm" && m.unit != "m") return@tp null
            sortQ("Measure ${m.what}: cm or m?", "cm", "m", m.unit == "cm", m.say(m.unit))
        },
        tp("sortKgL", 2, MEAS.size, kind = SO) { p, _ ->
            val m = MEAS[p[0]]
            if (m.unit != "kg" && m.unit != "L") return@tp null
            sortQ("Measure ${m.what}: kg or L?", "kg", "L", m.unit == "kg", m.say(m.unit))
        },
    )
    private fun c3() = listOf(c3Num(), c3AddSub(), c3Mul10(), c3Change(), c3Convert(), c3Rule(), c3Round(), c3Quarter())

    private fun thou(n: Int) = if (n == 1) "1 thousand" else "$n thousands"
    private fun hund(n: Int) = if (n == 1) "1 hundred" else "$n hundreds"
    private fun n4Why(n: Int) = "$n is ${thou(n / 1000)}, ${hund(n / 100 % 10)}, ${tens(n / 10 % 10)} and ${ones(n % 10)}."

    private fun c3Num() = sk(
        "ma3.num9999", 3, "Numbers to 9999", "9999", "4-digit numbers: names and place value",
        tp("name", 1, 9, 10, 10, 3) { p, r ->
            val (th, h, t) = Triple(p[0] + 1, p[1], p[2])
            val o = (p[1] + p[2] + 3 * p[3]) % 10
            val n = th * 1000 + h * 100 + t * 10 + o
            val w = listOf(th * 1000 + t * 100 + h * 10 + o, th * 1000 + h * 100 + o * 10 + t, th * 100 + h * 10 + t, n + 1000, n - 100)
            gq("Which number is ${nameIn(n.toLong())}?", nums(n, w.filter { it >= 100 }, r, min = 100, f = { "$it" }), n4Why(n), "${nameIn(n.toLong())} = $n")
        },
        tp("value", 2, 9, 10, 10, 4) { p, r ->
            val d = intArrayOf(p[0] + 1, p[1], p[2], (p[0] + 2 * p[1] + p[2] + 3) % 10)
            if (d.toSet().size != 4) return@tp null
            val n = d[0] * 1000 + d[1] * 100 + d[2] * 10 + d[3]
            val place = p[3]
            val dig = d[3 - place]
            if (dig == 0) return@tp null
            val v = dig * listOf(1, 10, 100, 1000)[place]
            gq("What is the value of the $dig in $n?", nums(v, listOf(dig, dig * 10, dig * 100, dig * 1000), r, f = { "$it" }),
                "The $dig is in the ${PLACE[place]} place, so it means $v.", "$dig in $n means $v")
        },
        tp("next", 2, 9, 10, 4) { p, r ->
            val (th, h) = p[0] + 1 to p[1]
            val (n, step) = when (p[2]) {
                0 -> th * 1000 + h * 100 + 99 to 1
                1 -> th * 1000 + h * 100 to -1
                2 -> th * 1000 + h * 100 + 95 to 10
                else -> th * 1000 + 950 + h to 100
            }
            val ans = n + step
            if (ans !in 1000..9999 || (step == 100 && th == 9)) return@tp null
            val q = if (step > 0) "What is $step more than $n?" else "What is 1 less than $n?"
            val why = when (step) {
                1 -> "$n + 1 = $ans: the 99 rolls over to 100."
                -1 -> "Count back one from $n: $ans."
                10 -> "$n + 10 = $ans, into the next hundred."
                else -> "$n + 100 = $ans, into the next thousand."
            }
            gq(q, nums(ans, listOf(ans + 10, ans - 10, ans + 100, ans - 100, ans - 1000).filter { it in 1000..9999 && it != n }, r, f = { "$it" }), why, "$n ${if (step > 0) "+ $step" else "$MI 1"} = $ans")
        },
        tp("tf", 3, 9, 10, 10, 3, kind = TF) { p, _ ->
            val (th, h, t) = Triple(p[0] + 1, p[1], p[2])
            val o = (p[1] * 3 + p[2]) % 10
            if (h != 0 && t != 0 && o != 0) return@tp null
            val n = th * 1000 + h * 100 + t * 10 + o
            val shown = when (p[3]) {
                0 -> n
                1 -> (th * 1000 + t * 100 + h * 10 + o).takeIf { it != n } ?: return@tp null
                else -> (th * 1000 + h * 100 + o * 10 + t).takeIf { it != n } ?: return@tp null
            }
            tf("${cap(nameIn(n.toLong()))} is written $shown.", shown == n, n4Why(n))
        },
    )

    private fun a3(i: Int) = 101 + 9 * i
    private fun b3(i: Int, j: Int) = 111 + 67 * j + i % 10

    private fun carries(a: Int, b: Int) = a % 10 + b % 10 >= 10 || a / 10 % 10 + b / 10 % 10 >= 10
    private fun borrows(a: Int, b: Int) = a % 10 < b % 10 || a / 10 % 10 < b / 10 % 10
    private fun col(a: Int, b: Int, op: String) =
        "Hundreds ${a / 100} $op ${b / 100}, tens ${a / 10 % 10} $op ${b / 10 % 10}, ones ${a % 10} $op ${b % 10}"

    private fun carryWhy(a: Int, b: Int): String {
        val o = a % 10 + b % 10
        val t = a / 10 % 10 + b / 10 % 10 + if (o >= 10) 1 else 0
        return when {
            o >= 10 && t >= 10 -> "Ones make $o and tens make $t, carry both: ${a + b}."
            o >= 10 -> "Ones make $o, so carry 1 ten: $a + $b = ${a + b}."
            else -> "Tens make $t, so carry 1 hundred: $a + $b = ${a + b}."
        }
    }

    private val STORY3 = (0 until 40).map { i -> Triple(200 + (i * 137) % 500, 100 + (i * 71) % 250, 50 + (i * 53) % 200) }

    private fun c3AddSub() = sk(
        "ma3.addSub3", 3, "3-digit add and take", "+−", "adding and taking away 3-digit numbers",
        tp("add", 1, 89, 12) { p, r ->
            val (a, b) = a3(p[0]) to b3(p[0], p[1])
            if (a + b > 999 || carries(a, b)) return@tp null
            val s = a + b
            gq("$a + $b = ?", nums(s, listOf(s + 100, s - 10, s + 10, s + 1), r), "${col(a, b, "+")}: $s.", "$a + $b = $s")
        },
        tp("addCarry", 2, 89, 12) { p, r ->
            val (a, b) = a3(p[0]) to b3(p[0], p[1])
            if (a + b > 999 || !carries(a, b)) return@tp null
            val s = a + b
            gq("$a + $b = ?", nums(s, listOf(noCarry(a, b), s - 10, s + 10, s - 100), r), carryWhy(a, b), "$a + $b = $s")
        },
        tp("sub", 1, 89, 12) { p, r ->
            val (a, b) = b3(p[0], p[1]) to a3(p[0])
            if (a <= b || borrows(a, b)) return@tp null
            val d = a - b
            gq("$a $MI $b = ?", nums(d, listOf(d + 100, d - 10, d + 10, d + 1), r), "${col(a, b, MI)}: $d.", "$a $MI $b = $d")
        },
        tp("subBorrow", 2, 89, 12) { p, r ->
            val (a, b) = b3(p[0], p[1]) to a3(p[0])
            if (a <= b || !borrows(a, b)) return@tp null
            val d = a - b
            gq("$a $MI $b = ?", nums(d, listOf(noBorrow(a, b), d + 10, d - 10, d + 100), r), "Borrow where the top digit is smaller: $a $MI $b = $d.", "$a $MI $b = $d")
        },
        tp("gotGave", 3, KIDS.size, STORY3.size) { p, r ->
            val k = KIDS[p[0]]
            val (n, a, b) = STORY3[p[1]]
            val m = n + a
            if (m > 999) return@tp null
            val ans = m - b
            gq("${k.name} had $n stickers. ${k.heCap} got $a more, then gave away $b. How many now?",
                nums(ans, listOf(m, n - b, m + b, ans + 10, ans - 100), r), "$n + $a = $m, then $m $MI $b = $ans.", "$n + $a $MI $b = $ans")
        },
        tp("shop", 3, THINGS.size, STORY3.size) { p, r ->
            val t = THINGS[p[0]]
            val (n, a, b) = STORY3[p[1]]
            val ans = n - a - b
            if (ans < 1) return@tp null
            gq("A shop had $n ${t.many}. It sold $a in the morning and $b in the evening. How many are left?",
                nums(ans, listOf(n - a, n - b, a + b, ans + 10, ans + 100), r), "$a + $b = ${a + b} sold, and $n $MI ${a + b} = $ans.", "$n $MI $a $MI $b = $ans")
        },
        tp("school", 3, STORY3.size, 3) { p, r ->
            val (n, a, b) = STORY3[p[0]]
            val bb = b + 100 * p[1]
            val all = n + a
            if (all > 999 || bb >= all) return@tp null
            val ans = all - bb
            gq("A school has $n girls and $a boys. $bb children go on a trip. How many stay at school?",
                nums(ans, listOf(all, n - bb, all + bb, ans + 10, ans - 100), r), "$n + $a = $all, then $all $MI $bb = $ans.", "$n + $a $MI $bb = $ans")
        },
    )

    private fun c3Mul10() = sk(
        "ma3.mul10", 3, "Times 10 and 100", "×10", "multiplying by 10, 100 and tens",
        tp("x10", 1, 2, 98) { p, r ->
            val n = p[1] + 2
            val m = if (p[0] == 0) 10 else 100
            val ans = n * m
            val zeros = if (m == 10) "one zero" else "two zeros"
            gq("$n $X $m = ?", nums(ans, listOf(ans * 10, ans / 10, n + m, ans + n), r), "$n $X $m: put $zeros after $n to get ${g(ans)}.", "$n $X $m = ${g(ans)}")
        },
        tp("tens", 2, 9, 3, 8) { p, r ->
            val d = p[0] + 1
            val z = listOf(10, 100, 1000)[p[1]]
            val a = d * z
            val b = p[2] + 2
            val ans = a * b
            gq("$a $X $b = ?", nums(ans, listOf(ans / 10, ans * 10, a + b, ans + a), r), "$d $X $b = ${d * b}, then add the zeros: ${g(ans)}.", "$a $X $b = ${g(ans)}")
        },
        tp("tensTens", 3, 8, 8) { p, r ->
            val (a, b) = p[0] + 2 to p[1] + 2
            val ans = a * b * 100
            gq("${a * 10} $X ${b * 10} = ?", nums(ans, listOf(ans / 10, ans * 10, (a + b) * 10), r), "$a $X $b = ${a * b}, then two zeros: ${g(ans)}.", "${a * 10} $X ${b * 10} = ${g(ans)}")
        },
        tp("missing", 3, 2, 98) { p, r ->
            val n = p[1] + 2
            val m = if (p[0] == 0) 10 else 100
            val c = n * m
            gq("? $X $m = ${g(c)}", nums(n, listOf(c, n * 10, n / 10, n + 1), r, min = 1), "$n $X $m = ${g(c)}, so take ${if (m == 10) "one zero" else "two zeros"} off.", "$n $X $m = ${g(c)}")
        },
        tp("tf", 2, 2, 98, 2, kind = TF) { p, _ ->
            val n = p[1] + 2
            val m = if (p[0] == 0) 10 else 100
            val ans = n * m
            val c = if (p[2] == 0) ans else if (m == 10) ans * 10 else ans / 10
            tf("$n $X $m = ${g(c)}", c == ans, "$n $X $m: put ${if (m == 10) "one zero" else "two zeros"} after $n to get ${g(ans)}.")
        },
        extra = listOf(Format.catch, Format.pairs),
    )

    private val NOTES = listOf(10, 20, 50, 100, 200, 500)

    private fun c3Change() = sk(
        "ma3.change", 3, "Bills and change", "₹", "shop totals and change from a note",
        tp("total", 1, 20, 20) { p, r ->
            if (p[0] >= p[1]) return@tp null
            val (x, y) = SHOP[p[0]] to SHOP[p[1]]
            val s = x.price + y.price
            if (s > 500) return@tp null
            gq("${cap(x.a)} costs ₹${x.price} and ${y.a} costs ₹${y.price}. What is the total?", nums(s, listOf(s + 10, s - 10, y.price - x.price, s + 1), r, min = 1, f = ::rs),
                "Add the prices: ₹${x.price} + ₹${y.price} = ₹$s.", "₹${x.price} + ₹${y.price} = ₹$s", visual = (x.pic ?: y.pic)?.let { Visual.Picture(it) })
        },
        tp("change", 2, KIDS.size, 20, 2) { p, r ->
            val k = KIDS[p[0]]
            val it = SHOP[p[1]]
            val note = NOTES.filter { n -> n > it.price && n >= 50 }.getOrNull(p[2]) ?: return@tp null
            val c = note - it.price
            gq("${k.name} buys ${it.a} for ₹${it.price} and pays with a ₹$note note. How much change?",
                nums(c, listOf(c + 10, c - 10, it.price, noBorrow(note, it.price)), r, min = 1, f = ::rs), "Change = ₹$note $MI ₹${it.price} = ₹$c.", "₹$note $MI ₹${it.price} = ₹$c", visual = it.pic?.let { Visual.Picture(it) })
        },
        tp("two", 3, 20, 20, 2) { p, r ->
            if (p[0] >= p[1]) return@tp null
            val (x, y) = SHOP[p[0]] to SHOP[p[1]]
            val k = KIDS[(p[0] + p[1]) % KIDS.size]
            val t = x.price + y.price
            val note = NOTES.filter { it > t && it >= 50 }.getOrNull(p[2]) ?: return@tp null
            val c = note - t
            gq("${k.name} buys ${x.a} (₹${x.price}) and ${y.a} (₹${y.price}). ${k.heCap} pays ₹$note. How much change?",
                nums(c, listOf(note - x.price, note - y.price, t, c + 10), r, min = 1, f = ::rs),
                "₹${x.price} + ₹${y.price} = ₹$t, and ₹$note $MI ₹$t = ₹$c.", "₹$note $MI ₹$t = ₹$c", visual = (y.pic ?: x.pic)?.let { Visual.Picture(it) })
        },
        tp("enough", 2, 20, 20, 2, kind = TF) { p, _ ->
            if (p[0] >= p[1]) return@tp null
            val (x, y) = SHOP[p[0]] to SHOP[p[1]]
            val t = x.price + y.price
            val above = NOTES.firstOrNull { it >= t } ?: return@tp null
            val below = NOTES.lastOrNull { it < t } ?: return@tp null
            val note = if (p[2] == 0) above else below
            val ok = t <= note
            val why = if (ok) "₹${x.price} + ₹${y.price} = ₹$t, which is not more than ₹$note."
            else "₹${x.price} + ₹${y.price} = ₹$t, which is more than ₹$note."
            tf("₹$note is enough for ${x.a} (₹${x.price}) and ${y.a} (₹${y.price}).", ok, why)
        },
    )

    private class Unit2(val big: String, val small: String, val f: Int)

    private val UNITS = listOf(Unit2("m", "cm", 100), Unit2("kg", "g", 1000), Unit2("L", "mL", 1000), Unit2("km", "m", 1000))

    private fun part(u: Unit2, k: Int) = if (u.f == 100) 5 * (k + 1) else 50 * (k + 1)

    private fun c3Convert() = sk(
        "ma3.convert", 3, "Changing units", "m→cm", "m and cm, kg and g, L and mL, km and m",
        tp("big", 1, 4, 20) { p, r ->
            val u = UNITS[p[0]]
            val n = p[1] + 1
            val ans = n * u.f
            val other = if (u.f == 100) 1000 else 100
            gq("$n ${u.big} = ? ${u.small}", nums(ans, listOf(ans * 10, ans / 10, n * other, n + u.f), r, min = 1),
                "1 ${u.big} = ${u.f} ${u.small}, so $n ${u.big} = ${g(ans)} ${u.small}.", "$n ${u.big} = ${g(ans)} ${u.small}")
        },
        tp("small", 1, 4, 20) { p, r ->
            val u = UNITS[p[0]]
            val n = p[1] + 1
            val c = n * u.f
            gq("${g(c)} ${u.small} = ? ${u.big}", nums(n, listOf(n * 10, c / 100, n + 1, c / 10), r, min = 1),
                "1 ${u.big} = ${u.f} ${u.small}, so ${g(c)} ${u.small} = $n ${u.big}.", "${g(c)} ${u.small} = $n ${u.big}")
        },
        tp("mix", 2, 4, 9, 19) { p, r ->
            val u = UNITS[p[0]]
            val n = p[1] + 1
            val pt = part(u, p[2])
            val ans = n * u.f + pt
            val glued = "$n$pt".toInt()
            gq("$n ${u.big} $pt ${u.small} = ? ${u.small}", nums(ans, listOf(glued, n * u.f + pt * 10, n * u.f, ans + u.f), r, min = 1),
                "$n ${u.big} = ${g(n * u.f)} ${u.small}, and $pt more makes ${g(ans)}.", "$n ${u.big} $pt ${u.small} = ${g(ans)} ${u.small}")
        },
        tp("split", 2, 4, 9, 19) { p, r ->
            val u = UNITS[p[0]]
            val n = p[1] + 1
            val pt = part(u, p[2])
            val c = n * u.f + pt
            fun w(a: Int, b: Int) = "$a ${u.big} $b ${u.small}"
            val ans = w(n, pt)
            val wr = listOf(if (pt % 10 == 0) w(n, pt / 10) else null, w(n * 10, pt / 10).takeIf { u.f == 100 && pt % 10 == 0 } , w(n + 1, pt), w(n, u.f - pt).takeIf { u.f - pt != pt }, w(n - 1, pt).takeIf { n > 1 })
            gq("${g(c)} ${u.small} = ?", texts(ans, wr, r)!!, "${g(n * u.f)} ${u.small} is $n ${u.big}, and $pt ${u.small} is left.", "${g(c)} ${u.small} = $ans")
        },
        tp("left", 3, 4, 5, 19) { p, r ->
            val u = UNITS[p[0]]
            val n = p[1] + 1
            val pt = part(u, p[2])
            val ans = n * u.f - pt
            gq("$n ${u.big} $MI $pt ${u.small} = ? ${u.small}", nums(ans, listOf(n * u.f + pt, ans + u.f / 10, u.f - pt, pt), r, min = 1),
                "$n ${u.big} = ${g(n * u.f)} ${u.small}, and ${g(n * u.f)} $MI $pt = ${g(ans)}.", "${g(n * u.f)} $MI $pt = ${g(ans)} ${u.small}")
        },
        tp("cmp", 3, 4, 9, 19) { p, r ->
            val u = UNITS[p[0]]
            val n = p[1] + 1
            val k = p[2]
            val x = when {
                k < 9 -> n * u.f - part(u, k * 2)
                k == 9 -> n * u.f
                else -> n * u.f + part(u, (k - 10) * 2)
            }
            if (x <= 0) return@tp null
            val a = "$n ${u.big}"
            val b = "${g(x)} ${u.small}"
            val ans = when { x < n * u.f -> a; x > n * u.f -> b; else -> "Same" }
            val opts = listOf(a, b, "Same")
            gq("Which is more: $a or $b?", opts to opts.indexOf(ans),
                "$a = ${g(n * u.f)} ${u.small}, so ${if (ans == "Same") "they are the same" else "$ans is more"}.", if (ans == "Same") "$a = $b" else "$ans is more")
        },
        extra = listOf(Format.catch),
    )

    private fun c3Rule() = sk(
        "ma3.rule", 3, "Number patterns", "+3?", "finding and using a number rule",
        tp("plus", 1, 20, 8) { p, r ->
            val (s, k) = p[0] + 1 to p[1] + 2
            val seq = (0..3).map { s + it * k }
            val ans = s + 4 * k
            gq("What comes next? ${seq.joinToString(", ")}, ?", nums(ans, listOf(ans + 1, ans - 1, seq[3] + k + 1, ans + k), r),
                "Each number is $k more, so ${seq[3]} + $k = $ans.", "${seq[3]} + $k = $ans")
        },
        tp("minus", 2, 30, 8) { p, r ->
            val (s, k) = 50 + p[0] to p[1] + 2
            val seq = (0..3).map { s - it * k }
            val ans = s - 4 * k
            if (ans < 0) return@tp null
            gq("What comes next? ${seq.joinToString(", ")}, ?", nums(ans, listOf(ans + 1, ans - 1, seq[3] + k, ans - k), r),
                "Each number is $k less, so ${seq[3]} $MI $k = $ans.", "${seq[3]} $MI $k = $ans")
        },
        tp("rule", 2, 20, 8, 2) { p, r ->
            val k = p[1] + 2
            val up = p[2] == 0
            val s = if (up) p[0] + 1 else 40 + p[0]
            val seq = (0..3).map { if (up) s + it * k else s - it * k }
            if (seq.any { it < 0 }) return@tp null
            val ans = if (up) "+$k" else "$MI$k"
            val wr = if (up) listOf("+${k + 1}", "+${k - 1}", "$MI$k", "${X}2") else listOf("$MI${k + 1}", "$MI${k - 1}", "+$k")
            gq("What is the rule? ${seq.joinToString(", ")}", texts(ans, wr.filter { it != "+1" || k != 2 }, r)!!,
                "${seq[1]} ${if (up) MI else "+"} ${seq[0]}... each step ${if (up) "adds" else "takes away"} $k.".let {
                    if (up) "${seq[1]} $MI ${seq[0]} = $k, and each step adds $k." else "${seq[0]} $MI ${seq[1]} = $k, and each step takes away $k."
                }, "The rule is $ans")
        },
        tp("times", 3, 12, 2) { p, r ->
            val s = p[0] + 1
            val m = p[1] + 2
            val seq = (0..3).map { var v = s; repeat(it) { v *= m }; v }
            val ans = seq[3] * m
            gq("What comes next? ${seq.joinToString(", ")}, ?", nums(ans, listOf(seq[3] + (seq[3] - seq[2]), ans + s, ans - seq[2]), r),
                "Each number is $m times the last: ${seq[3]} $X $m = $ans.", "${seq[3]} $X $m = $ans")
        },
        tp("alt", 3, 10, 5, 5) { p, r ->
            val s = p[0] + 1
            val (a, b) = p[1] + 2 to p[2] + 2
            if (a == b) return@tp null
            val seq = listOf(s, s + a, s + a + b, s + 2 * a + b, s + 2 * a + 2 * b)
            val ans = s + 3 * a + 2 * b
            gq("What comes next? ${seq.joinToString(", ")}, ?", nums(ans, listOf(seq[4] + b, ans + 1, ans - 1), r),
                "Steps go +$a, +$b in turn, so add $a next: $ans.", "${seq[4]} + $a = $ans")
        },
        tp("gap", 3, 20, 8, 3) { p, r ->
            val (s, k) = p[0] + 1 to p[1] + 2
            val seq = (0..4).map { s + it * k }
            val gap = p[2] + 1
            val ans = seq[gap]
            gq("Fill the gap: ${seq.mapIndexed { i, v -> if (i == gap) "?" else "$v" }.joinToString(", ")}", nums(ans, listOf(ans + 1, ans - 1, seq[gap - 1] + k + 1), r),
                "Each step adds $k: ${seq[gap - 1]} + $k = $ans.", "${seq[gap - 1]} + $k = $ans")
        },
        extra = listOf(Format.catch),
    )

    private fun round(n: Int, to: Int) = (n + to / 2) / to * to

    private fun roundWhy(n: Int, to: Int): String {
        val lo = n / to * to
        val hi = lo + to
        return when {
            n - lo == to / 2 -> "$n is halfway, so we round up to $hi."
            n - lo < to / 2 -> "$n is nearer $lo than $hi."
            else -> "$n is nearer $hi than $lo."
        }
    }

    private fun roundQ(n: Int, to: Int, r: Random): Question {
        val ans = round(n, to)
        val lo = n / to * to
        val other = if (ans == lo) lo + to else lo
        val near = if (to == 100) round(n, 10) else null
        return gq("Round $n to the nearest $to.", nums(ans, listOf(other, near, ans + to, n), r), roundWhy(n, to), "$n rounds to $ans")
    }

    private fun c3Round() = sk(
        "ma3.round", 3, "Rounding off", "≈", "rounding to the nearest 10 and 100, and estimating",
        tp("ten2", 1, 90) { p, r ->
            val n = 10 + p[0]
            if (n % 10 == 0) return@tp null
            roundQ(n, 10, r)
        },
        tp("ten3", 2, 9, 10, 10) { p, r ->
            val n = hto(p[0] + 1, p[1], p[2])
            if (n % 10 == 0) return@tp null
            roundQ(n, 10, r)
        },
        tp("hundred", 2, 9, 10, 10) { p, r ->
            val n = hto(p[0] + 1, p[1], p[2])
            if (n % 100 == 0 || n % 10 == 0) return@tp null
            roundQ(n, 100, r)
        },
        tp("est", 3, 8, 10, 8, 3) { p, r ->
            val a = 10 * (p[0] + 1) + p[1]
            val b = 10 * (p[2] + 1) + (p[1] + 3 * p[3] + 2) % 10
            if (a % 10 == 0 || b % 10 == 0) return@tp null
            val (ra, rb) = round(a, 10) to round(b, 10)
            val ans = ra + rb
            gq("Round to tens, then add: $a + $b is about?", nums(ans, listOf(a + b, ans + 10, ans - 10), r),
                "$a is about $ra and $b is about $rb, so $ans.", "$ra + $rb = $ans")
        },
        tp("tf", 2, 90, 2, kind = TF) { p, _ ->
            val n = 10 + p[0]
            if (n % 10 == 0) return@tp null
            val ans = round(n, 10)
            val lo = n / 10 * 10
            val said = if (p[1] == 0) ans else if (ans == lo) lo + 10 else lo
            tf("$n rounded to the nearest 10 is $said.", said == ans, roundWhy(n, 10))
        },
    )

    private fun clk(h: Int, m: Int) = "${(h - 1).mod(12) + 1}:${"%02d".format(m)}"
    private fun hr(h: Int) = (h - 1).mod(12) + 1
    private fun said(h: Int, m: Int) = when (m) {
        0 -> "${hr(h)} o'clock"
        15 -> "quarter past ${hr(h)}"
        30 -> "half past ${hr(h)}"
        else -> "quarter to ${hr(h + 1)}"
    }

    private fun quarterWhy(h: Int, m: Int) = when (m) {
        15 -> "The long hand is on 3, so it is quarter past ${hr(h)}."
        30 -> "The long hand is on 6, so it is half past ${hr(h)}."
        else -> "The long hand is on 9, so it is quarter to ${hr(h + 1)}."
    }

    private fun c3Quarter() = sk(
        "ma3.quarter", 3, "Quarter past and to", "¼", "quarter past, half past, quarter to, and durations",
        tp("read", 1, 12, 3) { p, r ->
            val h = p[0] + 1
            val m = 15 * (p[1] + 1)
            val ans = said(h, m)
            val wr = when (m) {
                15 -> listOf("quarter to ${hr(h)}", "half past ${hr(h)}", "quarter past ${hr(h + 1)}")
                30 -> listOf("quarter past ${hr(h)}", "half past ${hr(h + 1)}", "quarter to ${hr(h + 1)}")
                else -> listOf("quarter to ${hr(h)}", "quarter past ${hr(h)}", "half past ${hr(h)}")
            }
            gq("What time is it?", Opt.of(ans, wr, r)!!, quarterWhy(h, m), "It is $ans", spoken = "What time does the clock show?",
                visual = Visual.Clock(h, m))
        },
        tp("words", 2, 12, 3, 2) { p, r ->
            val h = p[0] + 1
            val m = 15 * (p[1] + 1)
            if (p[2] == 0) {
                val ans = said(h, m)
                val wr = listOf(said(h, 60 - m).takeIf { m != 30 } ?: "quarter to ${hr(h)}", if (m == 45) "quarter to ${hr(h)}" else "quarter to ${hr(h + 1)}".takeIf { m != 45 } ?: "", said(h + 1, m))
                gq("${clk(h, m)} is the same as?", texts(ans, wr.filter { it.isNotEmpty() }, r)!!, quarterWhy(h, m), "${clk(h, m)} is $ans", visual = Visual.Clock(h, m))
            } else {
                val ans = clk(h, m)
                val wr = listOf(if (m == 45) clk(h + 1, 45) else clk(h, 60 - m).takeIf { m != 30 } ?: clk(h, 15), clk(h, 60 - m).takeIf { m != 30 } ?: clk(h + 1, 30), clk(h + 1, m), clk(h - 1, m))
                gq("Write ${said(h, m)} as a clock time.", texts(ans, wr, r)!!, quarterWhy(h, m), "${said(h, m)} is $ans")
            }
        },
        tp("between", 2, 12, 4, 6) { p, r ->
            val h = p[0] + 1
            val sm = 15 * p[1]
            val d = 15 * (p[2] + 1)
            val start = h * 60 + sm
            val end = start + d
            fun mins(x: Int) = "$x minutes"
            val wr = listOf(d + 15, d - 15, 60 - d, d + 60).filter { it > 0 && it != d }.map(::mins)
            gq("How many minutes from ${clk(h, sm)} to ${clk(end / 60, end % 60)}?", texts(mins(d), wr, r)!!,
                "From ${clk(h, sm)} to ${clk(end / 60, end % 60)} is ${d / 15} quarter hours: $d minutes.", "$d minutes", visual = Visual.Clock(h, sm))
        },
        tp("after", 3, 12, 4, 6, 2) { p, r ->
            val h = p[0] + 1
            val sm = 15 * p[1]
            val d = 15 * (p[2] + 1)
            val after = p[3] == 0
            val start = h * 60 + sm
            val end = if (after) start + d else start - d
            fun c(x: Int) = clk(x.floorDiv(60), x.mod(60))
            val steps = (1..d / 15).map { c(if (after) start + 15 * it else start - 15 * it) }
            val wr = listOf(c(end + 15), c(end - 15), c(if (after) start - d else start + d), clk(h, end.mod(60)))
            gq("What time is it $d minutes ${if (after) "after" else "before"} ${clk(h, sm)}?", texts(c(end), wr, r)!!,
                "Count ${if (after) "on" else "back"} in quarters: ${steps.joinToString(", ")}.", "${c(end)}", visual = Visual.Clock(h, sm))
        },
        tp("tf", 2, 12, 3, 2, kind = TF) { p, _ ->
            val h = p[0] + 1
            val m = 15 * (p[1] + 1)
            val shown = if (p[2] == 0) clk(h, m) else if (m == 45) clk(h + 1, 45) else clk(h, 60 - m).takeIf { m != 30 } ?: clk(h + 1, 30)
            tf("${cap(said(h, m))} is $shown.", shown == clk(h, m), "${cap(said(h, m))} is ${clk(h, m)}.").copy(learnVisual = Visual.Clock(h, m))
        },
    )

    // ───────────────────────── Class 4 ─────────────────────────

    private fun c4() = listOf(c4Lakh(), c4Mul2x2(), c4DivRem(), c4Factors(), c4Equiv(), c4CompFrac(), c4Time24(), c4Area())

    private fun six(i: Int) = spread(i, 100_000, 900_000)

    private fun digitOnce(n: Long, pos: Int): Int? {
        val t = n.toString()
        val d = t[t.length - 1 - pos]
        return if (t.count { it == d } == 1) d - '0' else null
    }

    /** Swap a zero with its neighbour: the place-value slips in reading big numbers. */
    private fun zeroSlips(n: Long): List<Long> {
        val t = n.toString().toCharArray()
        val out = ArrayList<Long>()
        for (i in 0 until t.size - 1) {
            if ((t[i] == '0') != (t[i + 1] == '0')) {
                val c = t.copyOf(); val x = c[i]; c[i] = c[i + 1]; c[i + 1] = x
                if (c[0] != '0') out += String(c).toLong()
            }
        }
        return out.distinct().filter { it != n }
    }

    private fun c4Lakh() = sk(
        "ma4.lakh", 4, "Lakhs: 1,00,000", "lakh", "6-digit numbers the Indian way",
        tp("commas", 1, 400) { p, r ->
            val n = six(p[0])
            val t = n.toString()
            val ans = ind(n, true)
            val wr = listOf(intl(n), t.reversed().chunked(2).joinToString(",").reversed(), t.take(2) + "," + t.drop(2))
            gq("Put in the commas the Indian way: $t", texts(ans, wr, r)!!, "Indian commas: 3 digits from the right, then every 2.", ans)
        },
        tp("place", 1, 300, 6) { p, r ->
            val n = six(p[0])
            val pos = p[1]
            val d = digitOnce(n, pos) ?: return@tp null
            val ans = cap(PLACE[pos])
            val wr = listOfNotNull(PLACE.getOrNull(pos + 1)?.takeIf { pos < 5 }, PLACE.getOrNull(pos - 1), PLACE.getOrNull(pos + 2)?.takeIf { pos < 4 }, PLACE.getOrNull(pos - 2)).map(::cap)
            gq("In ${ind(n)}, which place is the $d in?", texts(ans, wr, r)!!, "Counting from the right, place ${pos + 1} is the ${PLACE[pos]} place.", "The $d is in the ${PLACE[pos]} place")
        },
        tp("value", 2, 300, 6) { p, r ->
            val n = six(p[0])
            val pos = p[1]
            val d = digitOnce(n, pos) ?: return@tp null
            if (d == 0) return@tp null
            var v = d.toLong(); repeat(pos) { v *= 10 }
            val wr = listOf(v * 10, v / 10, v * 100, v / 100).filter { it >= d && it != v }.map { ind(it, true) }
            gq("What is the value of the $d in ${ind(n)}?", texts(ind(v, true), wr, r)!!, "The $d is in the ${PLACE[pos]} place, so it means ${ind(v, true)}.", "${ind(v, true)}")
        },
        tp("next", 2, 9, 10, 4) { p, r ->
            val (a, b) = (p[0] + 1).toLong() to p[1].toLong()
            val (n, step) = when (p[2]) {
                0 -> a * 100_000 + b * 10_000 - 1 to 1L
                1 -> a * 100_000 + b * 10_000 to -1L
                2 -> a * 100_000 + b * 10_000 + 9_500 to 1000L
                else -> a * 100_000 + 95_000 + b * 100 to 10_000L
            }
            val ans = n + step
            val stepS = ind(kotlin.math.abs(step), true)
            val wr = listOf(ans + 10_000, ans - 10_000, ans + 1000, ans - 1000, ans + 100_000).filter { it > 0 && it != n }.map { ind(it, true) }
            val why = when (step) {
                1L -> "Add 1 to ${ind(n, true)}: the 9s roll over, giving ${ind(ans, true)}."
                -1L -> "Count back one from ${ind(n, true)}: ${ind(ans, true)}."
                else -> "${ind(n, true)} + $stepS = ${ind(ans, true)}."
            }
            gq(if (step > 0) "What is $stepS more than ${ind(n, true)}?" else "What is 1 less than ${ind(n, true)}?", texts(ind(ans, true), wr, r)!!, why, ind(ans, true))
        },
        tp("name", 3, 400) { p, r ->
            val base = six(p[0]).toString().toCharArray()
            base[1 + p[0] % 3] = '0'
            base[3 + (p[0] / 3) % 3] = '0'
            val n = String(base).toLong()
            val wr = zeroSlips(n).map { ind(it, true) }
            gq("Which number is ${nameIn(n)}?", texts(ind(n, true), wr, r) ?: return@tp null, "Lakhs, then thousands, then the rest: ${ind(n, true)}.", "${nameIn(n)} = ${ind(n, true)}")
        },
        tp("tf", 2, 300, 2, kind = TF) { p, _ ->
            val n = six(p[0])
            val pos = (p[0] / 7) % 6
            val d = digitOnce(n, pos) ?: return@tp null
            val said = if (p[1] == 0) pos else if (pos < 5) pos + 1 else pos - 1
            tf("In ${ind(n)}, the $d is in the ${PLACE[said]} place.", said == pos, "Counting from the right, place ${pos + 1} is the ${PLACE[pos]} place.")
        },
    )

    private fun mulWhy(a: Int, b: Int) = "$a $X ${b / 10 * 10} = ${a * (b / 10 * 10)}, $a $X ${b % 10} = ${a * (b % 10)}, total ${g(a * b)}."

    private fun mulWrongs(a: Int, b: Int): List<Int> {
        val p = a * b
        return listOf(a * (b % 10) + a * (b / 10), (a / 10) * (b / 10) * 100 + (a % 10) * (b % 10), p + 10, p - 10, p + 100)
    }

    private val CRATES = listOf(
        "A crate holds %d mangoes. How many mangoes are in %d crates?",
        "A bus has %d seats. How many seats are there on %d buses?",
        "A box has %d pieces of chalk. How many pieces are in %d boxes?",
        "A row has %d chairs. How many chairs are in %d rows?",
        "A book has %d pages. How many pages are in %d such books?",
        "A packet has %d biscuits. How many biscuits are in %d packets?",
    )

    private fun c4Mul2x2() = sk(
        "ma4.mul2x2", 4, "2-digit × 2-digit", "××", "multiplying two 2-digit numbers",
        tp("x10s", 1, 88, 8) { p, r ->
            val a = 12 + p[0]
            val b = (p[1] + 2) * 10
            if (a % 10 == 0) return@tp null
            val ans = a * b
            gq("$a $X $b = ?", nums(ans, listOf(ans / 10, ans * 10, ans + b, ans - b), r), "$a $X ${b / 10} = ${a * b / 10}, then add a zero: ${g(ans)}.", "$a $X $b = ${g(ans)}")
        },
        tp("teens", 2, 38, 9) { p, r ->
            val a = 12 + p[0]
            val b = 11 + p[1]
            if (a % 10 == 0) return@tp null
            gq("$a $X $b = ?", nums(a * b, mulWrongs(a, b), r), mulWhy(a, b), "$a $X $b = ${a * b}")
        },
        tp("big", 3, 40, 30) { p, r ->
            val a = 21 + 2 * p[0]
            val b = 21 + 2 * p[1] + p[0] % 2
            if (a % 10 == 0 || b % 10 == 0 || b > 99) return@tp null
            gq("$a $X $b = ?", nums(a * b, mulWrongs(a, b), r), mulWhy(a, b), "$a $X $b = ${g(a * b)}")
        },
        tp("story", 3, CRATES.size, 38, 15) { p, r ->
            val a = 12 + p[1]
            val b = 11 + p[2]
            if (a % 10 == 0) return@tp null
            gq(CRATES[p[0]].format(a, b), nums(a * b, mulWrongs(a, b) + (a + b), r), mulWhy(a, b), "$a $X $b = ${g(a * b)}")
        },
        extra = listOf(Format.catch),
    )

    private fun qr(q: Int, rem: Int) = if (rem == 0) "$q" else "$q r $rem"

    private val SHARE = listOf(
        listOf("%d children sit %d to a bench.", "How many benches are needed?", "How many benches are full?", "How many children are on the last bench?"),
        listOf("%d laddoos are packed %d to a box.", "How many boxes are needed for all?", "How many boxes are full?", "How many laddoos are left over?"),
        listOf("%d mangoes are put %d in a bag.", "How many bags are needed for all?", "How many bags are full?", "How many mangoes are left over?"),
        listOf("%d people take autos, %d in each.", "How many autos are needed?", "How many autos are full?", "How many people ride in the last auto?"),
    )

    private fun c4DivRem() = sk(
        "ma4.divRem", 4, "Division, remainders", "r", "long division with remainders",
        tp("exact", 1, 8, 20) { p, r ->
            val d = p[0] + 2
            val q = p[1] + 11
            val n = d * q
            gq("$n ÷ $d = ?", nums(q, listOf(q + 1, q - 1, q + 10, n - d), r, min = 1), "$d $X $q = $n, so $n ÷ $d = $q.", "$n ÷ $d = $q")
        },
        tp("rem", 2, 8, 19, 8) { p, r ->
            val d = p[0] + 2
            val q = p[1] + 2
            val rem = p[2] + 1
            if (rem >= d) return@tp null
            val n = d * q + rem
            val wr = listOf(qr(q - 1, rem + d), qr(q + 1, rem), qr(q, (rem + 1) % d), qr(q, d - rem).takeIf { d - rem != rem }, qr(q - 1, rem))
            gq("$n ÷ $d = ?", texts(qr(q, rem), wr, r)!!, "$d $X $q = ${d * q}, and $n $MI ${d * q} leaves $rem.", "$n ÷ $d = ${qr(q, rem)}")
        },
        tp("story", 3, 8, 12, 8, 3) { p, r ->
            val d = p[0] + 2
            val q = p[1] + 2
            val rem = p[2] + 1
            if (rem >= d) return@tp null
            val n = d * q + rem
            val ctx = SHARE[(d + q) % SHARE.size]
            val kind = p[3]
            val ans = when (kind) { 0 -> q + 1; 1 -> q; else -> rem }
            val why = when (kind) {
                0 -> "$n ÷ $d = $q r $rem, so $q full and 1 more: ${q + 1}."
                1 -> "$n ÷ $d = $q r $rem, so $q are full."
                else -> "$n ÷ $d = $q r $rem, so $rem are left."
            }
            gq("${ctx[0].format(n, d)} ${ctx[1 + kind]}", nums(ans, listOf(q, q + 1, rem, d), r, min = 1), why, "$n ÷ $d = $q r $rem")
        },
    )

    private fun factorSort(id: String, tier: Int, target: Int, upTo: Int) = tp(id, tier, upTo, kind = SO) { p, _ ->
        val n = p[0] + 1
        val yes = target % n == 0
        sortQ("Is $n a factor of $target?", "Factor of $target", "Not a factor", yes,
            if (yes) "$target ÷ $n = ${target / n}, so $n is a factor." else "$target ÷ $n leaves a remainder, so $n is not a factor.")
    }

    private val TARGETS = listOf(12, 16, 18, 20, 24, 28, 30, 32, 36, 40, 42, 44, 45, 48, 50, 54, 56, 60, 63, 64, 66, 70, 72, 75, 78, 80, 84, 88, 90, 96, 98, 100)
    private val COMMON = (6..36).flatMap { a -> (a + 1..60).map { b -> a to b } }.filter { (a, b) -> gcd(a, b) >= 2 && b % a != 0 }

    private fun c4Factors() = sk(
        "ma4.factors", 4, "Factors and multiples", "fac", "factors, multiples and common factors",
        factorSort("f24", 1, 24, 30),
        factorSort("f36", 2, 36, 40),
        factorSort("f60", 3, 60, 60),
        tp("pickF", 2, TARGETS.size, 6) { p, r ->
            val t = TARGETS[p[0]]
            val fs = (2 until t).filter { t % it == 0 }
            val f = fs.getOrNull(p[1]) ?: return@tp null
            val wr = listOf(f + 1, f - 1, f + 2, f + 3, f - 2).filter { it > 1 && it < t && t % it != 0 }
            gq("Which is a factor of $t?", nums(f, wr, r, min = 2).takeIf { (o, _) -> o.count { t % it.toInt() == 0 } == 1 } ?: return@tp null,
                "$t ÷ $f = ${t / f}, so $f is a factor of $t.", "$f is a factor of $t")
        },
        tp("pickM", 2, 9, 10) { p, r ->
            val n = p[0] + 2
            val k = p[1] + 2
            val m = n * k
            val wr = listOf(m + 1, m - 1, m + 2, n + k, m + n - 1).filter { it % n != 0 }
            gq("Which is a multiple of $n?", nums(m, wr, r, min = 2).takeIf { (o, _) -> o.count { it.toInt() % n == 0 } == 1 } ?: return@tp null,
                "$n $X $k = $m, so $m is a multiple of $n.", "$m is a multiple of $n")
        },
        tp("common", 3, COMMON.size) { p, r ->
            val (a, b) = COMMON[p[0]]
            val c = gcd(a, b)
            val onlyA = (2..a).firstOrNull { a % it == 0 && b % it != 0 } ?: return@tp null
            val onlyB = (2..b).firstOrNull { b % it == 0 && a % it != 0 } ?: return@tp null
            val neither = (2..60).first { a % it != 0 && b % it != 0 && it != onlyA && it != onlyB }
            gq("Which is a common factor of $a and $b?", Opt.of("$c", listOf("$onlyA", "$onlyB", "$neither"), r)!!,
                "$c divides both $a and $b exactly.", "$c is a common factor of $a and $b")
        },
        tp("tf", 1, 11, 25, 2, kind = TF) { p, _ ->
            val n = p[0] + 2
            val k = p[1] + 2
            val m = if (p[2] == 0) n * k else n * k + 1 + k % (n - 1)
            val yes = m % n == 0
            tf("$n is a factor of $m.", yes, if (yes) "$m ÷ $n = ${m / n}, so $n is a factor." else "$m ÷ $n leaves a remainder, so $n is not a factor.")
        },
    )

    /** Reduced proper fractions with bottoms 2..10. */
    private val BASE_FR = (2..10).flatMap { d -> (1 until d).filter { gcd(it, d) == 1 }.map { it to d } }

    /** Fraction options shown as written (not reduced); values must all differ. */
    private fun rawFracs(ans: Pair<Int, Int>, wrongs: List<Pair<Int, Int>?>, r: Random): Pair<List<String>, Int>? {
        val seen = HashSet<Fr>()
        val av = Fr.of(ans.first, ans.second)
        seen += av
        val w = ArrayList<Pair<Int, Int>>()
        for (x in wrongs) {
            if (x == null || x.first <= 0 || x.second <= 0 || w.size >= 3) continue
            if (seen.add(Fr.of(x.first, x.second))) w += x
        }
        if (w.size < 2) return null
        val all = (w + ans).shuffled(r)
        return all.map { "${it.first}/${it.second}" } to all.indexOf(ans)
    }

    private fun pies(a: Pair<Int, Int>, b: Pair<Int, Int>): Visual? = if (a.second <= 12 && b.second <= 12) Visual.Pies(listOf(a, b)) else null

    private fun c4Equiv() = sk(
        "ma4.equivFrac", 4, "Equal fractions", "2/4", "equivalent fractions and simplest form",
        tp("top", 1, BASE_FR.size, 5, 2) { p, r ->
            val (n, d) = BASE_FR[p[0]]
            val m = p[1] + 2
            val (bn, bd) = n * m to d * m
            val q = if (p[2] == 0) gq("$n/$d = ?/$bd", nums(bn, listOf(n + bd - d, bn + 1, bn - 1, bd - bn), r, min = 1), "Multiply top and bottom by $m: $n/$d = $bn/$bd.", "$n/$d = $bn/$bd")
            else gq("$n/$d = $bn/?", nums(bd, listOf(d + bn - n, bd + 1, bd - 1, bd + d), r, min = 1), "Multiply top and bottom by $m: $n/$d = $bn/$bd.", "$n/$d = $bn/$bd")
            q.copy(learnVisual = pies(n to d, bn to bd))
        },
        tp("which", 2, BASE_FR.size, 5) { p, r ->
            val (n, d) = BASE_FR[p[0]]
            val m = p[1] + 2
            val ans = n * m to d * m
            val opts = rawFracs(ans, listOf(n + m to d + m, n * m to d * m + 1, n * m + 1 to d * m, n to d * m, n * m to d), r) ?: return@tp null
            gq("Which is equal to $n/$d?", opts, "Multiply top and bottom of $n/$d by $m: ${ans.first}/${ans.second}.", "$n/$d = ${ans.first}/${ans.second}")
                .copy(learnVisual = pies(n to d, ans))
        },
        tp("simplest", 3, BASE_FR.size, 5) { p, r ->
            val (n, d) = BASE_FR[p[0]]
            val m = p[1] + 2
            val (bn, bd) = n * m to d * m
            val opts = rawFracs(n to d, listOf(n to bd, bn to d, d to n, n + 1 to d), r) ?: return@tp null
            gq("Write $bn/$bd in its simplest form.", opts, "Divide top and bottom by $m: $bn/$bd = $n/$d.", "$bn/$bd = $n/$d")
        },
        tp("tf", 2, BASE_FR.size, 5, 2, kind = TF) { p, _ ->
            val (n, d) = BASE_FR[p[0]]
            val m = p[1] + 2
            val (bn, bd) = n * m to d * m
            if (p[2] == 0) tf("$n/$d = $bn/$bd", true, "Multiply top and bottom of $n/$d by $m: $bn/$bd.")
            else tf("$n/$d = ${n + m - 1}/${d + m - 1}", false, "$n/$d is $bn/$bd; adding the same number changes it.")
        },
    )

    /** Fractions with bottoms up to 8, reduced, smallest first (distinct values). */
    private val SMALL_FR = (2..8).flatMap { d -> (1 until d).filter { gcd(it, d) == 1 }.map { Fr.of(it, d) } }.sortedWith { a, b -> a.cmp(b) }

    private fun frWhy(n1: Int, d1: Int, n2: Int, d2: Int): String {
        val l = lcm(d1, d2)
        val (a, b) = n1 * (l / d1) to n2 * (l / d2)
        return "$n1/$d1 = $a/$l and $n2/$d2 = $b/$l, so $n1/$d1 ${sign(a.compareTo(b))} $n2/$d2."
    }

    private fun c4CompFrac() = sk(
        "ma4.compFrac", 4, "Bigger fraction", "3/4>", "comparing and ordering fractions",
        tp("same", 1, 10, 11, 11) { p, _ ->
            val d = p[0] + 3
            val (a, b) = p[1] + 1 to p[2] + 1
            if (a >= d || b >= d || a == b) return@tp null
            val big = if (a > b) "$a/$d" else "$b/$d"
            signQ("$a/$d", "$b/$d", a.compareTo(b), "Same bottom number, so $big has more parts and is bigger.", "Is $a over $d more or less than $b over $d?")
                .copy(visual = Visual.Pies(listOf(a to d, b to d)), learnVisual = Visual.Pies(listOf(a to d, b to d)))
        },
        tp("sameTop", 2, 6, 11, 11) { p, _ ->
            val n = p[0] + 1
            val (d1, d2) = p[1] + 2 to p[2] + 2
            if (d1 <= n || d2 <= n || d1 == d2) return@tp null
            val c = d2.compareTo(d1)
            val big = if (c > 0) "$n/$d1" else "$n/$d2"
            signQ("$n/$d1", "$n/$d2", c, "Same top, and bigger bottom means smaller pieces, so $big is bigger.", "Is $n over $d1 more or less than $n over $d2?")
                .copy(learnVisual = Visual.Pies(listOf(n to d1, n to d2)))
        },
        tp("unlike", 3, 8, 8, 8, 8) { p, _ ->
            val (d1, n1, d2, n2) = listOf(p[0] + 2, p[1] + 1, p[2] + 2, p[3] + 1)
            if (n1 >= d1 || n2 >= d2 || d1 == d2 || n1 == n2) return@tp null
            val c = Fr.of(n1, d1).cmp(Fr.of(n2, d2))
            signQ("$n1/$d1", "$n2/$d2", c, frWhy(n1, d1, n2, d2), "Is $n1 over $d1 more, less, or the same as $n2 over $d2?")
                .copy(learnVisual = Visual.Pies(listOf(n1 to d1, n2 to d2)))
        },
        tp("tf", 2, 6, 6, 6, 6, kind = TF) { p, _ ->
            val (d1, n1, d2, n2) = listOf(p[0] + 2, p[1] + 1, p[2] + 2, p[3] + 1)
            if (n1 >= d1 || n2 >= d2 || d1 == d2) return@tp null
            val c = Fr.of(n1, d1).cmp(Fr.of(n2, d2))
            if (c == 0) return@tp null
            tf("$n1/$d1 > $n2/$d2", c > 0, frWhy(n1, d1, n2, d2), "$n1 over $d1 is more than $n2 over $d2")
        },
        tp("orderSame", 1, 9, 10, 10, 10, kind = OR) { p, r ->
            val d = p[0] + 4
            val t = listOf(p[1] + 1, p[2] + 1, p[3] + 1)
            if (!(t[0] < t[1] && t[1] < t[2] && t[2] < d)) return@tp null
            ord("Put in order, smallest first.", t.map { "$it/$d" }, r, "Same bottom number, so fewer parts come first.")
        },
        tp("order", 3, 19, 10, 10, kind = OR) { p, r ->
            val i = p[0]
            val j = i + 1 + p[1]
            val k = j + 1 + p[2]
            if (k >= SMALL_FR.size) return@tp null
            val f = listOf(SMALL_FR[i], SMALL_FR[j], SMALL_FR[k])
            if (f.map { it.d }.toSet().size == 1) return@tp null
            ord("Put in order, smallest first.", f.map { it.plain }, r, "With a common bottom number, they go ${f.joinToString(", ") { it.plain }}.")
        },
        tp("half", 2, 10, 11, kind = SO) { p, _ ->
            val b = p[0] + 3
            val a = p[1] + 1
            if (a >= b || 2 * a == b) return@tp null
            val more = 2 * a > b
            sortQ("Is $a/$b more or less than 1/2?", "More than 1/2", "Less than 1/2", more,
                "Double the top: ${2 * a} is ${if (more) "more" else "less"} than $b, so ${if (more) "more" else "less"} than 1/2.")
        },
    )

    private fun t24(h: Int, m: Int) = "%02d:%02d".format(h, m)
    private fun t12(h: Int, m: Int) = "${(h + 11) % 12 + 1}:${"%02d".format(m)} ${if (h < 12) "am" else "pm"}"
    private fun dur(h: Int, m: Int) = when { h == 0 -> "$m min"; m == 0 -> "$h h"; else -> "$h h $m min" }

    private fun to24Why(h: Int, m: Int) = when {
        h == 0 -> "Just after midnight the hour is 00: ${t12(h, m)} is ${t24(h, m)}."
        h == 12 -> "Noon stays 12, so ${t12(h, m)} is ${t24(h, m)}."
        h > 12 -> "For pm, add 12 to the hour: ${t12(h, m)} is ${t24(h, m)}."
        else -> "Morning hours stay the same: ${t12(h, m)} is ${t24(h, m)}."
    }

    private fun c4Time24() = sk(
        "ma4.time24", 4, "24-hour clock", "24h", "24-hour time and how long a trip takes",
        tp("to24", 1, 24, 12) { p, r ->
            val (h, m) = p[0] to 5 * p[1]
            gq("What is ${t12(h, m)} in 24-hour time?", texts(t24(h, m), listOf(t24((h + 12) % 24, m), t24((h + 1) % 24, m), t24((h + 23) % 24, m)), r)!!,
                to24Why(h, m), "${t12(h, m)} = ${t24(h, m)}")
        },
        tp("to12", 1, 24, 12) { p, r ->
            val (h, m) = p[0] to 5 * p[1]
            gq("What is ${t24(h, m)} in am or pm time?", texts(t12(h, m), listOf(t12((h + 12) % 24, m), t12((h + 14) % 24, m), t12((h + 1) % 24, m)), r)!!,
                to24Why(h, m), "${t24(h, m)} = ${t12(h, m)}")
        },
        tp("hours", 2, 15, 6, 8) { p, r ->
            val (h, m) = p[0] + 6 to 10 * p[1]
            val d = p[2] + 1
            if (h + d > 23) return@tp null
            gq("A bus leaves at ${t24(h, m)} and arrives at ${t24(h + d, m)}. How long is the trip?",
                texts(dur(d, 0), listOf(dur(d + 1, 0), dur(d - 1, 0).takeIf { d > 1 }, dur(d + 2, 0), dur(d, 30)), r)!!,
                "From ${t24(h, m)} to ${t24(h + d, m)} is ${t24(h + d, m).take(2).toInt()} $MI $h = $d hours.", dur(d, 0))
        },
        tp("trip", 3, 16, 6, 6, 5) { p, r ->
            val (h, sm) = p[0] + 5 to 10 * p[1]
            val dm = listOf(5, 15, 25, 35, 45, 55)[p[2]]
            val dh = p[3]
            val start = h * 60 + sm
            val end = start + dh * 60 + dm
            if (end >= 24 * 60) return@tp null
            val (eh, em) = end / 60 to end % 60
            val ans = dur(dh, dm)
            val naive = dur(eh - h, abs(em - sm))
            val wr = listOf(naive, dur(dh + 1, dm), dur(dh, 60 - dm), dur(dh + 1, 60 - dm))
            val mid = start + dh * 60
            gq("A train leaves at ${t24(h, sm)} and reaches at ${t24(eh, em)}. How long is the journey?", texts(ans, wr, r)!!,
                if (dh == 0) "From ${t24(h, sm)} to ${t24(eh, em)} is $dm min." else "${t24(h, sm)} + $dh h = ${t24(mid / 60, mid % 60)}, and $dm min more is ${t24(eh, em)}.", ans)
        },
        tp("tf", 2, 24, 4, 2, kind = TF) { p, _ ->
            val (h, m) = p[0] to 15 * p[1]
            val shown = if (p[2] == 0) t12(h, m) else t12((h + 12) % 24, m)
            tf("${t24(h, m)} is $shown.", p[2] == 0, to24Why(h, m))
        },
    )

    private fun c4Area() = sk(
        "ma4.area", 4, "Area of rectangles", "cm²", "area by counting squares and length × breadth",
        tp("count", 1, 8, 8) { p, r ->
            val (rows, cols) = p[0] + 2 to p[1] + 2
            val a = rows * cols
            gq("A rectangle is $cols squares across and $rows squares down. How many squares cover it?", nums(a, listOf(2 * (rows + cols), rows + cols, a + rows), r, min = 1),
                "$rows rows of $cols squares: $rows $X $cols = $a.", "$rows $X $cols = $a", visual = Visual.Dots(rows, cols))
        },
        tp("rect", 1, 11, 11) { p, r ->
            val (l, b) = p[0] + 2 to p[1] + 2
            if (l < b) return@tp null
            val a = l * b
            gq("What is the area of a rectangle $l cm by $b cm?", nums(a, listOf(2 * (l + b), l + b, a + l), r, min = 1, f = { "$it sq cm" }),
                "Area = length $X breadth = $l $X $b = $a sq cm.", "$l $X $b = $a sq cm")
        },
        tp("square", 2, 14) { p, r ->
            val s = p[0] + 2
            gq("A square has sides of $s m. What is its area?", nums(s * s, listOf(4 * s, 2 * s, s * s + s), r, min = 1, f = { "$it sq m" }),
                "Area = side $X side = $s $X $s = ${s * s} sq m.", "$s $X $s = ${s * s} sq m")
        },
        tp("garden", 2, 16, 8) { p, r ->
            val (l, b) = p[0] + 10 to p[1] + 2
            val a = l * b
            gq("A garden is $l m long and $b m wide. What is its area?", nums(a, listOf(2 * (l + b), l + b, a - l), r, min = 1, f = { "$it sq m" }),
                "Area = length $X breadth = $l $X $b = $a sq m.", "$l $X $b = $a sq m")
        },
        tp("side", 3, 14, 11) { p, r ->
            val (l, b) = p[0] + 2 to p[1] + 2
            if (l <= b) return@tp null
            val a = l * b
            gq("A rectangle has area $a sq cm and length $l cm. What is its breadth?", nums(b, listOf(a - l, b + 1, b - 1, l), r, min = 1, f = { "$it cm" }),
                "$a ÷ $l = $b, so the breadth is $b cm.", "$a ÷ $l = $b cm")
        },
        tp("tiles", 3, 10, 10, 3) { p, r ->
            val (l, b) = p[0] + 3 to p[1] + 2
            if (l < b) return@tp null
            val rate = listOf(20, 50, 100)[p[2]]
            val a = l * b
            val c = a * rate
            gq("A floor is $l m by $b m. Tiles cost ₹$rate per sq m. What do the tiles cost?", nums(c, listOf(2 * (l + b) * rate, a, c + rate, (l + b) * rate), r, min = 1, f = ::rs),
                "Area = $l $X $b = $a sq m, and $a $X ₹$rate = ₹${g(c)}.", "₹${g(c)}")
        },
        tp("tf", 2, 11, 11, kind = TF) { p, _ ->
            val (l, b) = p[0] + 2 to p[1] + 2
            if (l < b) return@tp null
            val a = l * b
            val per = 2 * (l + b)
            if (a == per) return@tp null
            val shown = if ((l + b) % 2 == 0) a else per
            tf("A $l cm by $b cm rectangle has area $shown sq cm.", shown == a, "Area = $l $X $b = $a sq cm; $per cm is the perimeter.")
        },
    )
    // ───────────────────────── Class 5 ─────────────────────────

    private fun c5() = listOf(c5Crore(), c5Prime(), c5LcmHcf(), c5AddFrac(), c5FracQty(), c5Unitary(), c5AreaPer(), c5Table())

    private val BIG_FACTS = listOf(
        "1 lakh = 1,00,000" to true, "1 crore = 1,00,00,000" to true, "1 crore = 100 lakh" to true, "1 million = 10 lakh" to true,
        "10 million = 1 crore" to true, "1 lakh = 100 thousand" to true, "1 billion = 100 crore" to true,
        "1 crore = 10 lakh" to false, "1 million = 1 lakh" to false, "1 lakh = 10,000" to false, "1 crore = 1 million" to false,
        "1 billion = 10 crore" to false, "10 lakh = 1 crore" to false, "1 lakh = 1 million" to false,
    )
    private val BIG_WHY = mapOf(
        "lakh" to "1 lakh = 1,00,000, which is 100 thousand.",
        "crore" to "1 crore = 100 lakh = 10 million.",
        "million" to "1 million = 10 lakh.",
        "billion" to "1 billion = 100 crore.",
    )

    private fun c5Crore() = sk(
        "ma5.crore", 5, "Lakhs and crores", "cr", "big numbers: Indian and international commas",
        tp("lakhs", 1, 30, 20) { p, r ->
            val x = (p[0] + 1).toLong()
            val y = p[1].toLong()
            val n = x * 100_000 + y * 1000
            val wr = (zeroSlips(n) + listOf(n * 10, n / 10, x * 100_000 + y * 10_000)).filter { it != n }.map { ind(it, true) }
            gq("Which number is ${nameIn(n)}?", texts(ind(n, true), wr, r)!!, "$x lakh is ${ind(x * 100_000, true)}, so the number is ${ind(n, true)}.", ind(n, true))
        },
        tp("crores", 2, 20, 30) { p, r ->
            val x = (p[0] + 1).toLong()
            val y = p[1].toLong()
            val n = x * 10_000_000 + y * 100_000
            val wr = (zeroSlips(n) + listOf(n * 10, n / 10, x * 10_000_000 + y * 1_000_000)).filter { it != n }.map { ind(it, true) }
            gq("Which number is ${nameIn(n)}?", texts(ind(n, true), wr, r)!!, "$x crore is ${ind(x * 10_000_000, true)}, so the number is ${ind(n, true)}.", ind(n, true))
        },
        tp("intl", 2, 300) { p, r ->
            val n = spread(p[0], 1_000_000, 89_000_000) / 1000 * 1000
            val wr = listOf(intl(n * 10), intl(n / 10), intl(n * 100))
            gq("Write ${ind(n, true)} with international commas.", texts(intl(n), wr, r)!!, "International commas go every 3 digits from the right.", intl(n))
        },
        tp("facts", 1, BIG_FACTS.size, kind = TF) { p, _ ->
            val (st, ok) = BIG_FACTS[p[0]]
            val key = listOf("billion", "million", "crore", "lakh").first { it in st }
            tf(st, ok, BIG_WHY.getValue(key))
        },
        tp("lakhThou", 1, 50, 2, kind = TF) { p, _ ->
            val x = p[0] + 2
            val shown = if (p[1] == 0) 100 * x else 10 * x
            tf("$x lakh = ${ind(shown.toLong(), true)} thousand", shown == 100 * x, "1 lakh is 100 thousand, so $x lakh is ${ind(100L * x, true)} thousand.")
        },
        tp("cmp", 3, 300, 3) { p, _ ->
            val a = spread(p[0], 1_000_000, 98_000_000)
            val t = a.toString()
            val b = when (p[1]) {
                0 -> { val i = 1 + p[0] % (t.length - 2); val c = t.toCharArray(); val x = c[i]; c[i] = c[i + 1]; c[i + 1] = x; String(c).toLong() }
                1 -> a / 10
                else -> a + 100_000
            }
            if (b == a) return@tp null
            signQ(ind(a, true), ind(b, true), a.compareTo(b), cmpWhy(a, b) { ind(it, true) }, "Is ${ind(a, true)} more or less than ${ind(b, true)}?")
        },
        tp("order", 3, 200, kind = OR) { p, r ->
            val a = spread(p[0], 1_000_000, 9_000_000)
            val t = a.toString()
            val b = (t[1].toString() + t[0] + t.drop(2)).toLong()
            val c = if (p[0] % 2 == 0) a * 10 + 5 else a / 10
            val v = listOf(a, b, c).distinct().sorted()
            if (v.size < 3) return@tp null
            ord("Put in order, smallest first.", v.map { ind(it, true) }, r, "Fewer digits come first, then compare from the left.")
        },
    )

    private fun isPrime(n: Int) = n >= 2 && (2..kotlin.math.sqrt(n.toDouble()).toInt()).none { n % it == 0 }
    private fun spf(n: Int) = (2..n).first { n % it == 0 }
    private fun primeWhy(n: Int) = if (isPrime(n)) "$n has only two factors: 1 and $n."
    else "$n = ${spf(n)} $X ${n / spf(n)}, so it has more than two factors."

    private fun divWhy(n: Int, d: Int): String {
        val yes = n % d == 0
        val sum = digits(n.toLong()).sum()
        return when (d) {
            2 -> "$n ends in ${n % 10}, ${if (yes) "an even" else "an odd"} digit, so ${if (yes) "yes" else "no"}."
            3, 9 -> "The digits add to $sum, ${if (yes) "a" else "not a"} multiple of $d."
            5 -> "$n ends in ${n % 10}, so ${if (yes) "yes" else "no"}."
            else -> if (yes) "$n ends in 0, so yes." else "$n doesn't end in 0, so no."
        }
    }

    private val PRIMES = (11..199).filter { isPrime(it) }
    private val COMPOSITES = (51..200).filter { !isPrime(it) }

    private fun c5Prime() = sk(
        "ma5.prime", 5, "Prime or composite", "pr", "primes, composites and divisibility by 2, 3, 5, 9, 10",
        tp("small", 1, 49, kind = SO) { p, _ ->
            val n = p[0] + 2
            sortQ("Is $n prime or composite?", "Prime", "Composite", isPrime(n), primeWhy(n))
        },
        tp("big", 2, 150, kind = SO) { p, _ ->
            val n = p[0] + 51
            sortQ("Is $n prime or composite?", "Prime", "Composite", isPrime(n), primeWhy(n))
        },
        tp("pickP", 2, PRIMES.size) { p, r ->
            val n = PRIMES[p[0]]
            val wr = (1..30).flatMap { listOf(n + 2 * it, n - 2 * it) }.filter { it > 3 && !isPrime(it) && it % 2 == 1 }
            gq("Which number is prime?", nums(n, wr, r, min = 4).takeIf { (o, _) -> o.count { isPrime(it.toInt()) } == 1 } ?: return@tp null,
                primeWhy(n), "$n is prime")
        },
        tp("pickC", 2, COMPOSITES.size) { p, r ->
            val n = COMPOSITES[p[0]]
            val wr = (1..40).flatMap { listOf(n + it, n - it) }.filter { isPrime(it) }
            gq("Which number is composite?", nums(n, wr, r, min = 2).takeIf { (o, _) -> o.count { !isPrime(it.toInt()) } == 1 } ?: return@tp null,
                primeWhy(n), "$n is composite")
        },
        tp("div", 3, 2, 150, 5, kind = TF) { p, _ ->
            val d = listOf(2, 3, 5, 9, 10)[p[2]]
            val n = if (p[0] == 0) (d * ((100 + d - 1) / d + p[1])).takeIf { it <= 999 } ?: return@tp null
            else (101 + p[1] * 6).takeIf { it % d != 0 } ?: return@tp null
            tf("$n is divisible by $d.", n % d == 0, divWhy(n, d))
        },
    )

    private val LCM_CTX = listOf(
        "Two bells ring every %d and %d minutes. They ring together now. In how many minutes will they ring together again?" to "minutes",
        "Two lights blink every %d and %d seconds. They blink together now. After how many seconds will they blink together again?" to "seconds",
        "Buses leave a stop every %d and %d minutes. Two leave together now. When will two leave together again (in minutes)?" to "minutes",
    )
    private val HCF_CTX = listOf(
        "Two ribbons are %d m and %d m long. They are cut into equal pieces, as long as possible. How long is each piece?" to "m",
        "Two ropes, %d m and %d m long, are cut into equal pieces with none left. What is the longest each piece can be?" to "m",
    )
    private fun hcfWrongs(a: Int, b: Int): List<Int> {
        val g = gcd(a, b)
        return listOf((2 until g).lastOrNull { g % it == 0 } ?: 1, g * 2, minOf(a, b), b - a, lcm(a, b))
    }

    private fun c5LcmHcf() = sk(
        "ma5.lcmHcf", 5, "LCM and HCF", "lcm", "lowest common multiple and highest common factor",
        tp("lcm", 1, 11, 11) { p, r ->
            val (a, b) = p[0] + 2 to p[1] + 2
            if (a >= b) return@tp null
            val l = lcm(a, b)
            gq("LCM of $a and $b = ?", nums(l, listOf(a * b, l * 2, b, gcd(a, b)), r, min = 1), "$l is the smallest number both $a and $b go into.", "LCM of $a and $b = $l")
        },
        tp("hcf", 1, 37, 37) { p, r ->
            val (a, b) = p[0] + 4 to p[1] + 4
            if (a >= b || gcd(a, b) < 2) return@tp null
            val g = gcd(a, b)
            gq("HCF of $a and $b = ?", nums(g, hcfWrongs(a, b), r, min = 1), "$g is the biggest number that divides both $a and $b.", "HCF of $a and $b = $g")
        },
        tp("bells", 2, 11, 11, LCM_CTX.size) { p, r ->
            val (a, b) = p[0] + 2 to p[1] + 2
            if (a >= b || b % a == 0) return@tp null
            val (txt, unit) = LCM_CTX[p[2]]
            val l = lcm(a, b)
            gq(txt.format(a, b), nums(l, listOf(a * b, a + b, l * 2, l + a), r, min = 2, f = { "$it $unit" }),
                "Together again at the LCM: $l is the first time both match.", "LCM of $a and $b = $l")
        },
        tp("ribbon", 2, 37, 37, HCF_CTX.size) { p, r ->
            val (a, b) = p[0] + 4 to p[1] + 4
            if (a >= b || gcd(a, b) < 2) return@tp null
            val (txt, unit) = HCF_CTX[p[2]]
            val g = gcd(a, b)
            gq(txt.format(a, b), nums(g, hcfWrongs(a, b), r, min = 1, f = { "$it $unit" }),
                "The longest equal piece is the HCF of $a and $b: $g.", "HCF of $a and $b = $g")
        },
        tp("lcm3", 3, 11, 11, 11) { p, r ->
            val (a, b, c) = Triple(p[0] + 2, p[1] + 2, p[2] + 2)
            if (!(a < b && b < c)) return@tp null
            val l = lcm(lcm(a, b), c)
            if (l == c) return@tp null
            gq("LCM of $a, $b and $c = ?", nums(l, listOf(a * b * c, lcm(a, b), lcm(b, c), l * 2), r, min = 1), "$l is the smallest number $a, $b and $c all go into.", "LCM = $l")
        },
        tp("hcf3", 3, 9, 7, 7, 7) { p, r ->
            val g = p[0] + 2
            val (x, y, z) = Triple(p[1] + 1, p[2] + 1, p[3] + 1)
            if (!(x < y && y < z) || gcd(gcd(x, y), z) != 1) return@tp null
            val (a, b, c) = Triple(g * x, g * y, g * z)
            gq("HCF of $a, $b and $c = ?", nums(g, listOf(gcd(a, b), gcd(b, c), a, g * 2), r, min = 1), "$g is the biggest number that divides $a, $b and $c.", "HCF = $g")
        },
    )

    private fun c5AddFrac() = sk(
        "ma5.addFrac", 5, "Adding fractions", "1/2+", "adding and taking away fractions",
        tp("like", 1, 10, 11, 11) { p, r ->
            val d = p[0] + 3
            val (a, b) = p[1] + 1 to p[2] + 1
            if (a + b > d) return@tp null
            val ans = Fr.of(a + b, d)
            val o = fracs(ans, listOf(frOrNull(a + b, 2 * d), frOrNull(a + b + 1, d), frOrNull(abs(a - b), d), frOrNull(a + b - 1, d)), r, { it.mixed }) ?: return@tp null
            val why = if (ans.d != d) "Add the tops: ${a + b}/$d, which is ${ans.mixed}." else "Same bottom number, so add the tops: ${a + b}/$d."
            gq("$a/$d + $b/$d = ?", o, why, "$a/$d + $b/$d = ${ans.mixed}")
        },
        tp("likeSub", 1, 10, 11, 11) { p, r ->
            val d = p[0] + 3
            val (a, b) = p[1] + 1 to p[2] + 1
            if (a >= d || b >= a) return@tp null
            val ans = Fr.of(a - b, d)
            val o = fracs(ans, listOf(frOrNull(a - b, 0), frOrNull(a + b, d), frOrNull(a - b + 1, d), frOrNull(a - b, 2 * d)), r, { it.mixed }) ?: return@tp null
            val why = if (ans.d != d) "Take away the tops: ${a - b}/$d, which is ${ans.mixed}." else "Same bottom number, so take away the tops: ${a - b}/$d."
            gq("$a/$d $MI $b/$d = ?", o, why, "$a/$d $MI $b/$d = ${ans.mixed}")
        },
        tp("multiple", 2, 5, 3, 5, 11, 2) { p, r ->
            val d1 = p[0] + 2
            val m = p[1] + 2
            val d2 = d1 * m
            val (n1, n2) = p[2] + 1 to p[3] + 1
            if (n1 >= d1 || n2 >= d2 || gcd(n1, d1) != 1) return@tp null
            val plus = p[4] == 0
            val f1 = Fr.of(n1, d1)
            val f2 = Fr.of(n2, d2)
            val ans = if (plus) f1 + f2 else f1 - f2
            if (ans.n <= 0 || Fr.of(n2, d2).d != d2) return@tp null
            val op = if (plus) "+" else MI
            val top = if (plus) n1 * m + n2 else n1 * m - n2
            val o = fracs(ans, listOf(frOrNull(if (plus) n1 + n2 else n1 - n2, if (plus) d1 + d2 else d2 - d1), frOrNull(if (plus) n1 + n2 else abs(n1 - n2), d2), ans + Fr.of(1, d2), frOrNull(top + 1, d2)), r, { it.mixed }) ?: return@tp null
            gq("$n1/$d1 $op $n2/$d2 = ?", o, "$n1/$d1 = ${n1 * m}/$d2, so ${n1 * m}/$d2 $op $n2/$d2 = ${ans.mixed}.", "$n1/$d1 $op $n2/$d2 = ${ans.mixed}")
        },
        tp("unlike", 3, 8, 8, 8, 8, 2) { p, r ->
            val (d1, n1, d2, n2) = listOf(p[0] + 2, p[1] + 1, p[2] + 2, p[3] + 1)
            if (d1 >= d2 || n1 >= d1 || n2 >= d2 || d2 % d1 == 0 || gcd(n1, d1) != 1 || gcd(n2, d2) != 1) return@tp null
            val plus = p[4] == 0
            val f1 = Fr.of(n1, d1)
            val f2 = Fr.of(n2, d2)
            val ans = if (plus) f1 + f2 else f1 - f2
            if (ans.n <= 0) return@tp null
            val l = lcm(d1, d2)
            val (x, y) = n1 * (l / d1) to n2 * (l / d2)
            val op = if (plus) "+" else MI
            val raw = if (plus) x + y else x - y
            val o = fracs(ans, listOf(frOrNull(if (plus) n1 + n2 else abs(n1 - n2), if (plus) d1 + d2 else d2 - d1), frOrNull(if (plus) n1 + n2 else abs(n1 - n2), d1 * d2), frOrNull(raw + 1, l), frOrNull(raw, l + 1)), r, { it.mixed }) ?: return@tp null
            val tail = if (Fr.of(raw, l).mixed != "$raw/$l") " = ${ans.mixed}" else ""
            gq("$n1/$d1 $op $n2/$d2 = ?", o, "Make the bottoms $l: $x/$l $op $y/$l = $raw/$l$tail.", "$n1/$d1 $op $n2/$d2 = ${ans.mixed}")
        },
    )

    private val PROPER = (3..10).flatMap { d -> (2 until d).filter { gcd(it, d) == 1 }.map { it to d } }

    private fun c5FracQty() = sk(
        "ma5.fracQty", 5, "Fraction of a number", "3/5", "a fraction of a number or an amount",
        tp("unit", 1, 8, 14) { p, r ->
            val d = p[0] + 3
            val k = p[1] + 2
            val t = d * k
            gq("1/$d of $t = ?", nums(k, listOf(k + 1, k - 1, t - k, t / 2), r, min = 1), "Share $t into $d equal parts: each part is $k.", "1/$d of $t = $k")
                .copy(learnVisual = Visual.Pies(listOf(1 to d)))
        },
        tp("money", 1, 8, 10) { p, r ->
            val d = p[0] + 3
            val k = (p[1] + 1) * 10
            val t = d * k
            gq("1/$d of ₹$t = ?", nums(k, listOf(k + 10, k - 10, t - k, t / 2), r, min = 1, f = ::rs), "Share ₹$t into $d equal parts: each is ₹$k.", "1/$d of ₹$t = ₹$k")
        },
        tp("many", 2, PROPER.size, 11) { p, r ->
            val (n, d) = PROPER[p[0]]
            val k = p[1] + 2
            val t = d * k
            gq("$n/$d of $t = ?", nums(n * k, listOf(k, t - n * k, n * k + k, n * k - k, n * t), r, min = 1),
                "1/$d of $t is $k, so $n/$d is $n $X $k = ${n * k}.", "$n/$d of $t = ${n * k}")
                .copy(learnVisual = Visual.Pies(listOf(n to d)))
        },
        tp("spend", 3, KIDS.size, PROPER.size, 6, 2) { p, r ->
            val k = KIDS[p[0]]
            val (n, d) = PROPER[p[1]]
            val part = (p[2] + 1) * 10
            val t = d * part
            val spent = n * part
            val left = p[3] == 1
            val ans = if (left) t - spent else spent
            gq("${k.name} has ₹$t. ${k.heCap} spends $n/$d of it. How much ${if (left) "is left" else "does ${k.he} spend"}?",
                nums(ans, listOf(if (left) spent else t - spent, part, ans + part, ans - part), r, min = 1, f = ::rs),
                if (left) "${k.heCap} spends $n $X ₹$part = ₹$spent, so ₹${t - spent} is left." else "1/$d of ₹$t is ₹$part, so $n/$d is ₹$spent.",
                "₹$ans")
        },
        tp("class", 3, PROPER.size, 8) { p, r ->
            val (n, d) = PROPER[p[0]]
            val k = p[1] + 2
            val t = d * k
            val girls = n * k
            gq("A class has $t children, and $n/$d of them are girls. How many boys are there?", nums(t - girls, listOf(girls, k, t - k, t - girls + k), r, min = 1),
                "Girls: $n/$d of $t = $girls, so boys: $t $MI $girls = ${t - girls}.", "${t - girls} boys")
        },
    )

    private val RATES = listOf(
        listOf("A car goes %d km on %d L of petrol. How far does it go on %d L?", "km", "12", "14", "15", "16", "18", "20"),
        listOf("%s reads %d pages in %d days. How many pages in %d days?", "pages", "5", "6", "8", "10", "12", "15"),
        listOf("A tap fills %d L in %d minutes. How much does it fill in %d minutes?", "L", "3", "4", "5", "6", "8", "10"),
        listOf("%d bags of rice weigh %d kg. How much do %d bags weigh?", "kg", "5", "10", "15", "20", "25", "30"),
    )

    private val UNIT_SHOP = SHOP.filter { it.price <= 120 }

    private fun c5Unitary() = sk(
        "ma5.unitary", 5, "Unitary method", "1→n", "from many to one, then to many",
        tp("one", 1, UNIT_SHOP.size, 9) { p, r ->
            val it = UNIT_SHOP[p[0]]
            val c = p[1] + 2
            val t = c * it.price
            gq("$c ${it.many} cost ₹$t. What does 1 ${it.one} cost?", nums(it.price, listOf(t - c, it.price + 5, it.price - 5, t / (c + 1)), r, min = 1, f = ::rs),
                "₹$t ÷ $c = ₹${it.price} for one.", "₹${it.price} each", visual = it.pic?.let { Visual.Picture(it) })
        },
        tp("many", 2, UNIT_SHOP.size, 9, 8) { p, r ->
            val it = UNIT_SHOP[p[0]]
            val c1 = p[1] + 2
            val c2 = p[2] + 2
            if (c1 == c2) return@tp null
            val t = c1 * it.price
            val ans = c2 * it.price
            gq("$c1 ${it.many} cost ₹$t. What do $c2 ${it.many} cost?", nums(ans, listOf(t + (c2 - c1), t, ans + it.price, ans - it.price, t * c2), r, min = 1, f = ::rs),
                "One costs ₹$t ÷ $c1 = ₹${it.price}, so $c2 cost ₹$ans.", "₹$ans", visual = it.pic?.let { Visual.Picture(it) })
        },
        tp("rate", 3, RATES.size, 6, 8, 6) { p, r ->
            val ctx = RATES[p[0]]
            val u = ctx[2 + p[1]].toInt()
            val c1 = p[2] + 2
            val c2 = p[3] + 2
            if (c1 == c2) return@tp null
            val t = u * c1
            val ans = u * c2
            val prompt = when (p[0]) {
                0 -> ctx[0].format(t, c1, c2)
                1 -> ctx[0].format(KIDS[(c1 + c2 + p[1]) % KIDS.size].name, t, c1, c2)
                2 -> ctx[0].format(t, c1, c2)
                else -> ctx[0].format(c1, t, c2)
            }
            gq(prompt, nums(ans, listOf(t + (c2 - c1), t * c2, ans + u, ans - u), r, min = 1, f = { "$it ${ctx[1]}" }),
                "For 1: $t ÷ $c1 = $u, so for $c2: $u $X $c2 = $ans.", "$ans ${ctx[1]}")
        },
    )

    private fun c5AreaPer() = sk(
        "ma5.areaPer", 5, "Area and perimeter", "P,A", "perimeter, area and shapes made of rectangles",
        tp("perim", 1, 18, 14) { p, r ->
            val (l, b) = p[0] + 3 to p[1] + 2
            if (l <= b) return@tp null
            val per = 2 * (l + b)
            gq("What is the perimeter of a rectangle $l cm by $b cm?", nums(per, listOf(l * b, l + b, 2 * l + b), r, min = 1, f = { "$it cm" }),
                "Perimeter = 2 $X ($l + $b) = 2 $X ${l + b} = $per cm.", "$per cm")
        },
        tp("square", 1, 24, 2) { p, r ->
            val s = p[0] + 2
            val area = p[1] == 1
            if (s == 4) return@tp null
            if (area) gq("A square has sides of $s m. What is its area?", nums(s * s, listOf(4 * s, 2 * s, s * s + s), r, min = 1, f = { "$it sq m" }),
                "Area = $s $X $s = ${s * s} sq m.", "${s * s} sq m")
            else gq("A square has sides of $s m. What is its perimeter?", nums(4 * s, listOf(s * s, 2 * s, s + 4), r, min = 1, f = { "$it m" }),
                "Perimeter = 4 $X $s = ${4 * s} m.", "${4 * s} m")
        },
        tp("side", 2, 24) { p, r ->
            val s = p[0] + 2
            gq("A square has a perimeter of ${4 * s} cm. How long is each side?", nums(s, listOf(2 * s, 4 * s - 4, s + 1, s - 1), r, min = 1, f = { "$it cm" }),
                "A square has 4 equal sides: ${4 * s} ÷ 4 = $s cm.", "$s cm")
        },
        tp("lshape", 3, 6, 6, 6, 6) { p, r ->
            val (l1, b1, l2, b2) = listOf(p[0] + 4, p[1] + 2, p[2] + 2, p[3] + 1)
            if (b1 > l1 || b2 > l2 || l2 >= l1) return@tp null
            val a = l1 * b1 + l2 * b2
            gq("An L-shape is made of a $l1 m by $b1 m rectangle and a $l2 m by $b2 m rectangle. What is its area?",
                nums(a, listOf((l1 + l2) * (b1 + b2), l1 * b1, 2 * (l1 + b1) + 2 * (l2 + b2), a + 2), r, min = 1, f = { "$it sq m" }),
                "Add the parts: ${l1 * b1} + ${l2 * b2} = $a sq m.", "$a sq m")
        },
        tp("pond", 3, 8, 8, 5, 5) { p, r ->
            val (bl, bb) = p[0] + 10 to p[1] + 6
            val (l, b) = p[2] + 2 to p[3] + 2
            val a = bl * bb - l * b
            gq("A garden is $bl m by $bb m. A pond in it is $l m by $b m. What area is grass?",
                nums(a, listOf(bl * bb + l * b, bl * bb, (bl - l) * (bb - b)), r, min = 1, f = { "$it sq m" }),
                "Garden minus pond: ${bl * bb} $MI ${l * b} = $a sq m.", "$a sq m")
        },
        tp("tf", 2, 18, 14, kind = TF) { p, _ ->
            val (l, b) = p[0] + 3 to p[1] + 2
            if (l <= b) return@tp null
            val per = 2 * (l + b)
            if (per == l * b) return@tp null
            val shown = if ((l * 3 + b) % 2 == 0) per else l * b
            tf("A $l cm by $b cm rectangle has a perimeter of $shown cm.", shown == per, "Perimeter = 2 $X ($l + $b) = $per cm; ${l * b} is the area.")
        },
    )

    private class Topic(val title: String, val verb: String, val noun: String, val base: String)

    private val TOPICS = listOf(
        Topic("Books read", "read", "books", "read"), Topic("Runs scored", "scored", "runs", "score"), Topic("Mangoes picked", "picked", "mangoes", "pick"),
        Topic("Stickers collected", "collected", "stickers", "collect"), Topic("Trees planted", "planted", "trees", "plant"), Topic("Kites flown", "flew", "kites", "fly"),
    )

    /** Four children and four different values from a seed (null on a tie). */
    private fun table(s: Int, v: Int): List<Pair<String, Int>>? {
        val names = (0..3).map { KIDS[(s + it * 3) % KIDS.size].name }
        val vals = (0..3).map { 4 + (v * 7 + it * 11 + (v / 4) * it * 5) % 37 }
        if (vals.toSet().size < 4) return null
        return names.zip(vals)
    }

    private fun tableText(t: Topic, rows: List<Pair<String, Int>>) = "${t.title}: " + rows.joinToString(", ") { "${it.first} ${it.second}" } + "."

    private fun c5Table() = sk(
        "ma5.table", 5, "Read a table", "tab", "reading and comparing data in a table",
        tp("most", 1, TOPICS.size, 10, 20, 2) { p, r ->
            val t = TOPICS[p[0]]
            val rows = table(p[1], p[2]) ?: return@tp null
            val most = p[3] == 0
            val ans = if (most) rows.maxBy { it.second } else rows.minBy { it.second }
            gq("${tableText(t, rows)} Who ${t.verb} the ${if (most) "most" else "fewest"}?", Opt.of(ans.first, rows.map { it.first } - ans.first, r)!!,
                "${ans.first} has ${ans.second}, the ${if (most) "biggest" else "smallest"} number in the table.", "${ans.first}: ${ans.second}")
        },
        tp("total", 2, TOPICS.size, 10, 20) { p, r ->
            val t = TOPICS[p[0]]
            val rows = table(p[1], p[2]) ?: return@tp null
            val sum = rows.sumOf { it.second }
            gq("${tableText(t, rows)} How many ${t.noun} in all?", nums(sum, listOf(sum + 10, sum - 10, sum - rows[3].second, sum + 1), r, min = 1),
                "Add them: ${rows.joinToString(" + ") { "${it.second}" }} = $sum.", "$sum ${t.noun}")
        },
        tp("diff", 2, TOPICS.size, 10, 20) { p, r ->
            val t = TOPICS[p[0]]
            val rows = table(p[1], p[2]) ?: return@tp null
            val hi = rows.maxBy { it.second }
            val lo = rows.minBy { it.second }
            val d = hi.second - lo.second
            gq("${tableText(t, rows)} How many more ${t.noun} did ${hi.first} ${t.base} than ${lo.first}?", nums(d, listOf(hi.second + lo.second, d + 1, d - 1, d + 10), r, min = 1),
                "${hi.second} $MI ${lo.second} = $d.", "$d more")
        },
        tp("together", 3, TOPICS.size, 10, 20) { p, r ->
            val t = TOPICS[p[0]]
            val rows = table(p[1], p[2]) ?: return@tp null
            val (a, b, c) = Triple(rows[0], rows[1], rows[2])
            val d = a.second + b.second - c.second
            if (d <= 0) return@tp null
            gq("${tableText(t, rows)} How many more ${t.noun} did ${a.first} and ${b.first} ${t.base} together than ${c.first}?",
                nums(d, listOf(a.second + b.second, a.second + b.second + c.second, d + 1, d - 10), r, min = 1),
                "${a.second} + ${b.second} = ${a.second + b.second}, and ${a.second + b.second} $MI ${c.second} = $d.", "$d more")
        },
    )
    // ───────────────────────── Class 6 ─────────────────────────

    private fun c6() = listOf(c6Figurate(), c6Divis(), c6PrimeFac(), c6PerimArea(), c6Mixed(), c6Tricks(), c6Circle())

    private fun tri(n: Int) = n * (n + 1) / 2
    private fun nth(n: Int) = "$n" + when { n % 100 in 11..13 -> "th"; n % 10 == 1 -> "st"; n % 10 == 2 -> "nd"; n % 10 == 3 -> "rd"; else -> "th" }

    private fun c6Figurate() = sk(
        "ma6.figurate", 6, "Square and triangle", "n²", "square numbers, triangular numbers and odd sums",
        tp("sq", 1, 150, kind = SO) { p, _ ->
            val n = p[0] + 1
            val k = kotlin.math.sqrt(n.toDouble()).toInt()
            val yes = k * k == n
            sortQ("Is $n a square number?", "Square number", "Not square", yes,
                if (yes) "$k $X $k = $n, so it is a square number." else "$k $X $k = ${k * k} and ${k + 1} $X ${k + 1} = ${(k + 1) * (k + 1)}, so no.")
        },
        tp("tri", 2, 120, kind = SO) { p, _ ->
            val n = p[0] + 1
            val k = (1..20).first { tri(it) >= n }
            val yes = tri(k) == n
            sortQ("Is $n a triangular number?", "Triangular", "Not triangular", yes,
                if (yes) "1 + 2 + … + $k = $n, so it is triangular." else "Triangular numbers go ${tri(k - 1)}, ${tri(k)}, so $n is not one.")
        },
        tp("next", 1, 2, 18) { p, r ->
            val k = p[1] + 1
            if (p[0] == 0) {
                val seq = (0..2).map { (k + it) * (k + it) }
                val m = k + 3
                gq("What comes next? ${seq.joinToString(", ")}, ?", nums(m * m, listOf(seq[2] + (seq[2] - seq[1]), m * m + 1, m * m - 1, m * 2), r),
                    "These are square numbers: $m $X $m = ${m * m}.", "$m $X $m = ${m * m}")
            } else {
                val seq = (0..2).map { tri(k + it) }
                gq("What comes next? ${seq.joinToString(", ")}, ?", nums(tri(k + 3), listOf(seq[2] + (seq[2] - seq[1]), tri(k + 3) + 1, tri(k + 3) - 1), r),
                    "Each step adds one more: ${seq[2]} + ${k + 3} = ${tri(k + 3)}.", "${seq[2]} + ${k + 3} = ${tri(k + 3)}")
            }
        },
        tp("odd", 2, 14) { p, r ->
            val n = p[0] + 2
            val prompt = if (n <= 5) (1..n).joinToString(" + ") { "${2 * it - 1}" } + " = ?" else "What do the first $n odd numbers add up to?"
            gq(prompt, nums(n * n, listOf(n * (n + 1), (2 * n - 1) * 2, n * n + 1, n * n - 1), r), "The first $n odd numbers add up to $n $X $n = ${n * n}.", "${n * n}")
        },
        tp("nth", 2, 2, 18) { p, r ->
            val n = p[1] + 3
            if (p[0] == 0) gq("What is the ${nth(n)} square number?", nums(n * n, listOf(2 * n, n * (n + 1), (n - 1) * (n - 1), tri(n)), r), "The ${nth(n)} square number is $n $X $n = ${n * n}.", "${n * n}")
            else gq("What is the ${nth(n)} triangular number?", nums(tri(n), listOf(n * n, tri(n - 1), tri(n + 1), 2 * n), r), "1 + 2 + … + $n = ${tri(n)}.", "${tri(n)}")
        },
        tp("sumTo", 3, 26) { p, r ->
            val n = p[0] + 5
            gq("1 + 2 + 3 + … + $n = ?", nums(tri(n), listOf(n * (n + 1), n * n, tri(n - 1)), r), "Pair the ends: $n $X ${n + 1} ÷ 2 = ${tri(n)}.", "${tri(n)}")
        },
        tp("pairSum", 3, 18) { p, r ->
            val n = p[0] + 2
            val ans = (n + 1) * (n + 1)
            gq("${tri(n)} + ${tri(n + 1)} = ?", nums(ans, listOf(ans + 1, ans - 1, ans + n), r), "Next-door triangular numbers add to a square: ${n + 1} $X ${n + 1}.", "$ans")
        },
    )

    private fun fourDigit(i: Int, d: Int, yes: Boolean): Int {
        var n = 1000 + (i * 7919) % 9000
        if (yes) { n -= n % d; if (n < 1000) n += d } else if (n % d == 0) n += 1
        return n
    }

    private fun div11(n: Int): Pair<Int, Int> {
        val ds = digits(n.toLong())
        return ds.filterIndexed { i, _ -> i % 2 == 0 }.sum() to ds.filterIndexed { i, _ -> i % 2 == 1 }.sum()
    }

    private fun divisWhy(n: Int, d: Int): String {
        val yes = n % d == 0
        return when (d) {
            4 -> "The last two digits, ${"%02d".format(n % 100)}, are ${if (yes) "" else "not "}a multiple of 4."
            8 -> "The last three digits, ${"%03d".format(n % 1000)}, are ${if (yes) "" else "not "}a multiple of 8."
            else -> {
                val (x, y) = div11(n)
                if (yes) "Alternate digit sums $x and $y differ by ${abs(x - y)}, so yes."
                else "Alternate sums $x and $y differ by ${abs(x - y)}, not 0 or 11."
            }
        }
    }

    private fun divisSort(id: String, tier: Int, d: Int) = tp(id, tier, 250, kind = SO) { p, _ ->
        val n = fourDigit(p[0], d, p[0] % 2 == 0)
        sortQ("Is $n divisible by $d?", "Divisible by $d", "Not by $d", n % d == 0, divisWhy(n, d))
    }

    private fun c6Divis() = sk(
        "ma6.divis", 6, "Divisible by 4, 8, 11", "÷11", "divisibility tests for 4, 8 and 11",
        divisSort("by4", 1, 4), divisSort("by8", 2, 8), divisSort("by11", 3, 11),
        tp("pick", 2, 3, 100) { p, r ->
            val d = listOf(4, 8, 11)[p[0]]
            val n = fourDigit(p[1], d, true)
            val wr = listOf(n + 2, n - 2, n + 1, n - 1, n + 3, n + 10).filter { it % d != 0 }
            gq("Which number is divisible by $d?", nums(n, wr, r, f = { "$it" }), divisWhy(n, d), "$n ÷ $d = ${n / d}")
        },
        tp("tf", 3, 3, 150, kind = TF) { p, _ ->
            val d = listOf(4, 8, 11)[p[0]]
            val n = fourDigit(p[1] + 300, d, p[1] % 2 == 1)
            tf("$n is divisible by $d.", n % d == 0, divisWhy(n, d))
        },
    )

    private fun pfac(n: Int): List<Int> {
        val out = ArrayList<Int>()
        var x = n
        var f = 2
        while (x > 1) { while (x % f == 0) { out += f; x /= f }; f++ }
        return out
    }
    private fun prod(l: List<Int>) = l.joinToString(" $X ")
    private fun nextPrime(n: Int) = (n + 1..n + 100).first { isPrime(it) }

    private val SEMI = (4..100).filter { pfac(it).size == 2 }
    private val TREES = (12..200).filter { pfac(it).size in 3..6 }
    private val ODD_COMP = (15..299 step 2).filter { !isPrime(it) }

    private fun c6PrimeFac() = sk(
        "ma6.primeFac", 6, "Prime factors", "2×3", "prime factorisation and co-primes",
        tp("two", 1, SEMI.size) { p, r ->
            val n = SEMI[p[0]]
            val (a, b) = pfac(n)
            val wr = listOf("1 $X $n", prod(listOf(a, a, b)), prod(listOf(a, nextPrime(b))), if (a > 2) prod(listOf(2, n / 2)).takeIf { n % 2 == 0 } else null)
            gq("What are the prime factors of $n?", texts(prod(listOf(a, b)), wr, r)!!, "$n = $a $X $b, and both are prime.", "$n = ${prod(listOf(a, b))}")
        },
        tp("tree", 2, TREES.size) { p, r ->
            val n = TREES[p[0]]
            val f = pfac(n)
            val ans = prod(f)
            val split = prod(listOf(f[0], n / f[0]))
            val extra = prod(listOf(2) + f)
            val swapped = prod(listOf(nextPrime(f[0])) + f.drop(1))
            val wr = listOf(split, swapped, extra, prod(f.dropLast(1))).filter { it.length <= 24 }
            gq("What is the prime factorisation of $n?", texts(ans, wr, r)!!, "Keep dividing by primes: $n = $ans.", "$n = $ans")
        },
        tp("smallest", 2, ODD_COMP.size) { p, r ->
            val n = ODD_COMP[p[0]]
            val s = spf(n)
            val big = pfac(n).last()
            gq("What is the smallest prime factor of $n?", nums(s, listOf(big, 1, nextPrime(s), 3, 5, 7), r, min = 1).takeIf { (o, _) -> o.count { n % it.toInt() == 0 && it.toInt() < s && it != "1" } == 0 } ?: return@tp null,
                "$n ÷ $s = ${n / s}, and no smaller prime divides it.", "$s")
        },
        tp("coprime", 3, 27, 27, kind = TF) { p, _ ->
            val (a, b) = p[0] + 4 to p[1] + 4
            if (a >= b) return@tp null
            val g = gcd(a, b)
            tf("$a and $b are co-prime.", g == 1, if (g == 1) "$a and $b share no factor except 1." else "$a and $b share the factor $g.")
        },
    )

    private val SAME_AREA = listOf(12, 16, 18, 24, 30, 36, 40, 48, 60, 64, 72, 80, 90, 96, 100)

    private fun c6PerimArea() = sk(
        "ma6.perimArea", 6, "Missing sides", "P=", "missing sides, fencing cost, same area",
        tp("sqSide", 1, 24, 2) { p, r ->
            val s = p[0] + 2
            if (p[1] == 0) gq("A square has a perimeter of ${4 * s} cm. How long is each side?", nums(s, listOf(2 * s, 4 * s - 4, s + 1), r, min = 1, f = { "$it cm" }),
                "4 equal sides: ${4 * s} ÷ 4 = $s cm.", "$s cm")
            else gq("A square has an area of ${s * s} sq cm. How long is each side?", nums(s, listOf(s * s / 2, s * s / 4, s + 1), r, min = 1, f = { "$it cm" }),
                "$s $X $s = ${s * s}, so each side is $s cm.", "$s cm")
        },
        tp("breadthP", 1, 18, 17) { p, r ->
            val (l, b) = p[0] + 3 to p[1] + 2
            if (b >= l) return@tp null
            val per = 2 * (l + b)
            gq("A rectangle has a perimeter of $per cm and a length of $l cm. What is its breadth?", nums(b, listOf(per - l, per - 2 * l, per / 2), r, min = 1, f = { "$it cm" }),
                "Half of $per is ${per / 2}, and ${per / 2} $MI $l = $b cm.", "$b cm")
        },
        tp("lengthA", 2, 18, 17) { p, r ->
            val (l, b) = p[0] + 3 to p[1] + 2
            if (b >= l) return@tp null
            val a = l * b
            gq("A rectangle has an area of $a sq m and a breadth of $b m. What is its length?", nums(l, listOf(a - b, a / 2, l + 1, l - 1), r, min = 1, f = { "$it m" }),
                "$a ÷ $b = $l, so the length is $l m.", "$l m")
        },
        tp("fence", 3, 16, 12, 5) { p, r ->
            val (l, b) = p[0] + 5 to p[1] + 3
            if (b >= l) return@tp null
            val rate = 5 * (p[2] + 1)
            val per = 2 * (l + b)
            gq("A park is $l m by $b m. Fencing costs ₹$rate a metre. What does fencing it cost?",
                nums(per * rate, listOf(l * b * rate, (l + b) * rate, per * rate + 2 * rate), r, min = 1, f = ::rs),
                "Perimeter = 2 $X ($l + $b) = $per m, so $per $X ₹$rate = ₹${g(per * rate)}.", "₹${g(per * rate)}")
        },
        tp("same", 3, SAME_AREA.size, 6, 6) { p, r ->
            val a = SAME_AREA[p[0]]
            val fs = (1..a).filter { a % it == 0 && it * it <= a }.map { a / it to it }
            val i = p[1]
            val j = p[2]
            if (i >= j || j >= fs.size) return@tp null
            val (l1, b1) = fs[i]
            val (l2, b2) = fs[j]
            val (p1, p2) = 2 * (l1 + b1) to 2 * (l2 + b2)
            val o1 = "$l1 by $b1"
            val o2 = "$l2 by $b2"
            val ans = if (p1 > p2) o1 else o2
            val opts = listOf(o1, o2, "Same")
            gq("Both have area $a sq cm. Which has the bigger perimeter: $o1 or $o2 (cm)?", opts to opts.indexOf(ans),
                "Perimeters: $p1 cm and $p2 cm; $ans wins.", "$ans")
        },
    )

    /** Fractions above 1 with bottoms 2..6 (not whole), smallest first. */
    private val ABOVE1 = (2..6).flatMap { d -> (d + 1 until 3 * d).filter { it % d != 0 && gcd(it, d) == 1 }.map { Fr.of(it, d) } }.sortedWith { a, b -> a.cmp(b) }

    private fun c6Mixed() = sk(
        "ma6.mixed", 6, "Mixed numbers", "1½", "improper fractions, mixed numbers and adding them",
        tp("toMixed", 1, 9, 30) { p, r ->
            val d = p[0] + 2
            val n = d + 1 + p[1]
            if (n % d == 0 || gcd(n, d) != 1 || n > 4 * d) return@tp null
            val f = Fr.of(n, d)
            val (q, rem) = n / d to n % d
            val o = fracs(f, listOf(Fr.of(n + d, d), if (rem != q) Fr.of(rem * d + q, d) else null, Fr.of(n - d, d).takeIf { q > 1 }, Fr.of(n + 1, d)), r, { it.mixed }) ?: return@tp null
            gq("Write $n/$d as a mixed number.", o, "$n ÷ $d = $q with $rem left, so $n/$d = ${f.mixed}.", "$n/$d = ${f.mixed}")
        },
        tp("toImproper", 1, 9, 30) { p, r ->
            val d = p[0] + 2
            val n = d + 1 + p[1]
            if (n % d == 0 || gcd(n, d) != 1 || n > 4 * d) return@tp null
            val (q, rem) = n / d to n % d
            val o = rawFracs(n to d, listOf(q + rem to d, q * d - rem to d, q * rem to d, n to q * d), r) ?: return@tp null
            gq("${Fr.of(n, d).mixed} = ?", o, "$q $X $d + $rem = $n, so ${Fr.of(n, d).mixed} = $n/$d.", "${Fr.of(n, d).mixed} = $n/$d")
        },
        tp("order", 2, 18, 8, 8, kind = OR) { p, r ->
            val i = p[0]
            val j = i + 1 + p[1]
            val k = j + 1 + p[2]
            if (k >= ABOVE1.size) return@tp null
            val f = listOf(ABOVE1[i], ABOVE1[j], ABOVE1[k])
            val shown = f.mapIndexed { x, v -> if ((x + i) % 2 == 0) v.mixed else v.plain }
            ord("Put in order, smallest first.", shown, r, "As mixed numbers: ${f.joinToString(", ") { it.mixed }}.")
        },
        tp("add", 3, 3, 3, 12, 12, 2) { p, r ->
            val (w1, w2) = p[0] + 1 to p[1] + 1
            val f1 = SMALL_FR.filter { it.d <= 6 }.getOrNull(p[2]) ?: return@tp null
            val f2 = SMALL_FR.filter { it.d <= 6 }.getOrNull(p[3]) ?: return@tp null
            if (f1.d == f2.d && p[4] == 0 && f1 == f2) return@tp null
            val a = Fr.of(w1, 1) + f1
            val b = Fr.of(w2, 1) + f2
            val plus = p[4] == 0
            val ans = if (plus) a + b else a - b
            if (ans.n <= 0 || ans.d == 1) return@tp null
            val op = if (plus) "+" else MI
            val wholes = if (plus) w1 + w2 else w1 - w2
            val naive = if (plus) frOrNull(wholes * (f1.d + f2.d) + f1.n + f2.n, f1.d + f2.d) else null
            val o = fracs(ans, listOf(naive, ans + Fr.of(1, 1), ans - Fr.of(1, 1), ans + Fr.of(1, lcm(f1.d, f2.d))), r, { it.mixed }) ?: return@tp null
            val parts = if (plus) f1 + f2 else f1 - f2
            val why = if (plus) "Wholes: $w1 + $w2 = $wholes; parts: ${f1.plain} + ${f2.plain} = ${parts.mixed}; total ${ans.mixed}."
            else "As fractions: ${a.plain} $MI ${b.plain} = ${ans.plain}${if (ans.mixed != ans.plain) " = ${ans.mixed}" else ""}."
            gq("${a.mixed} $op ${b.mixed} = ?", o, why, "${a.mixed} $op ${b.mixed} = ${ans.mixed}")
        },
    )

    private fun glue(vararg d: Int) = d.joinToString("").toInt()

    private fun trickWhy(n: Int, m: Int): String = when (m) {
        5 -> "$n $X 5 is half of $n $X 10: ${10 * n} ÷ 2 = ${5 * n}."
        9 -> "$n $X 9 = $n $X 10 $MI $n = ${10 * n} $MI $n = ${9 * n}."
        11 -> if (n / 10 + n % 10 < 10) "Put ${n / 10} + ${n % 10} = ${n / 10 + n % 10} between ${n / 10} and ${n % 10}: ${11 * n}."
        else "$n $X 11 = ${10 * n} + $n = ${11 * n}."
        25 -> "$n $X 25 = $n $X 100 ÷ 4 = ${100 * n} ÷ 4 = ${25 * n}."
        99 -> "$n $X 99 = ${100 * n} $MI $n = ${99 * n}."
        else -> "$n $X 101 = ${100 * n} + $n = ${101 * n}."
    }

    private fun trickWrongs(n: Int, m: Int): List<Int> = when (m) {
        5 -> listOf(5 * n + 5, 5 * n - 5, 10 * n, 5 * n + 10)
        9 -> listOf(10 * n - 9, 9 * n + 9, 9 * n - 9, 9 * n + 10)
        11 -> listOf(glue(n / 10, (n / 10 + n % 10) % 10, n % 10), 11 * n + 11, 11 * n - 11, 11 * n + 100)
        25 -> listOf(25 * n + 25, 25 * n - 25, 50 * n, 20 * n)
        99 -> listOf(100 * n - 99, 99 * n + 100, 99 * n - 100, 99 * n + 1)
        else -> listOf(110 * n, 101 * n + 100, 101 * n - 100, 11 * n)
    }

    private fun trickT(id: String, tier: Int, m: Int, lo: Int, hi: Int) = tp(id, tier, hi - lo + 1) { p, r ->
        val n = lo + p[0]
        if (n % 10 == 0) return@tp null
        gq("$n $X $m = ?", nums(n * m, trickWrongs(n, m), r, min = 1), trickWhy(n, m), "$n $X $m = ${g(n * m)}")
    }

    private fun c6Tricks() = sk(
        "ma6.tricks", 6, "Mental maths tricks", "×11", "shortcuts for ×5, ×9, ×11, ×25, ×99, ×101",
        trickT("x5", 1, 5, 11, 99), trickT("x9", 2, 9, 11, 99), trickT("x11", 2, 11, 11, 99),
        trickT("x25", 3, 25, 4, 48), trickT("x99", 3, 99, 11, 60), trickT("x101", 3, 101, 11, 99),
        tp("tf", 2, 3, 89, 2, kind = TF) { p, _ ->
            val m = listOf(5, 9, 11)[p[0]]
            val n = 11 + p[1]
            if (n % 10 == 0) return@tp null
            val shown = if (p[2] == 0) n * m else trickWrongs(n, m)[0]
            if (p[2] == 1 && shown == n * m) return@tp null
            tf("$n $X $m = ${g(shown)}", shown == n * m, trickWhy(n, m))
        },
        extra = listOf(Format.catch, Format.pairs),
    )

    private fun half(n: Int) = if (n % 2 == 0) "${n / 2}" else "${n / 2}.5"

    private val CIRCLE_FACTS = listOf(
        "A diameter is the longest chord of a circle." to true, "A radius joins the centre to the circle." to true,
        "Every diameter passes through the centre." to true, "A diameter is twice as long as a radius." to true,
        "All radii of a circle are equal." to true, "A chord joins two points on a circle." to true,
        "A diameter is a chord." to true, "A circle has many diameters." to true,
        "Every chord passes through the centre." to false, "A radius is longer than a diameter." to false,
        "A circle has only one diameter." to false, "The centre lies on the circle." to false,
        "A radius is a chord." to false, "A diameter is half a radius." to false,
    )

    private fun c6Circle() = sk(
        "ma6.circle", 6, "Parts of a circle", "r,d", "radius, diameter and chords",
        tp("d", 1, 40, 2) { p, r ->
            val rr = p[0] + 1
            val u = if (p[1] == 0) "cm" else "m"
            gq("A circle has a radius of $rr $u. What is its diameter?", texts("${2 * rr} $u", listOf("$rr $u", "${half(rr)} $u", "${3 * rr} $u", "${2 * rr + 2} $u"), r)!!,
                "Diameter = 2 $X radius = 2 $X $rr = ${2 * rr} $u.", "${2 * rr} $u")
        },
        tp("r", 1, 79, 2) { p, r ->
            val d = p[0] + 2
            val u = if (p[1] == 0) "cm" else "m"
            gq("A circle has a diameter of $d $u. What is its radius?", texts("${half(d)} $u", listOf("${2 * d} $u", "$d $u", "${half(d + 2)} $u"), r)!!,
                "Radius = diameter ÷ 2 = $d ÷ 2 = ${half(d)} $u.", "${half(d)} $u")
        },
        tp("chord", 2, 30, 2) { p, r ->
            val rr = p[0] + 1
            val u = if (p[1] == 0) "cm" else "m"
            gq("How long is the longest chord of a circle of radius $rr $u?", texts("${2 * rr} $u", listOf("$rr $u", "${4 * rr} $u", "${half(rr)} $u"), r)!!,
                "The longest chord is a diameter: 2 $X $rr = ${2 * rr} $u.", "${2 * rr} $u")
        },
        tp("facts", 2, CIRCLE_FACTS.size, kind = TF) { p, _ ->
            val (st, ok) = CIRCLE_FACTS[p[0]]
            tf(st, ok, if (ok) "Yes: ${st.replaceFirstChar { it.lowercase() }}" else "No: a diameter is the longest chord, through the centre.")
        },
        tp("fits", 3, 14, 30, kind = TF) { p, _ ->
            val rr = p[0] + 2
            val c = p[1] + 1
            val ok = c <= 2 * rr
            tf("A circle of radius $rr cm can have a chord $c cm long.", ok,
                if (ok) "The longest chord is 2 $X $rr = ${2 * rr} cm, and $c fits." else "The longest chord is only ${2 * rr} cm, less than $c.")
        },
    )

    // ───────────────────────── Class 7 ─────────────────────────

    private fun c7() = listOf(c7Order(), c7Decimals(), c7Letters(), c7Triangle(), c7Integers(), c7Mean(), c7FracMul())

    private fun c7Order() = sk(
        "ma7.exprOrder", 7, "Brackets first", "( )", "order of operations: brackets, × and ÷ first",
        tp("mulFirst", 1, 20, 8, 8, 2) { p, r ->
            val a = p[0] + 1
            val (b, c) = p[1] + 2 to p[2] + 2
            val bc = b * c
            if (p[3] == 0) gq("$a + $b $X $c = ?", nums(a + bc, listOf((a + b) * c, a + b + c, a + bc + 1), r), "Multiply first: $b $X $c = $bc, then $a + $bc = ${a + bc}.", "$a + $b $X $c = ${a + bc}")
            else {
                if (bc <= a) return@tp null
                gq("$b $X $c $MI $a = ?", nums(bc - a, listOf(if (c > a) b * (c - a) else null, bc + a, bc - a - 1), r), "Multiply first: $b $X $c = $bc, then $bc $MI $a = ${bc - a}.", "$b $X $c $MI $a = ${bc - a}")
            }
        },
        tp("brackets", 2, 20, 8, 8, 2) { p, r ->
            val a = p[0] + 1
            val (b, c) = p[1] + 2 to p[2] + 2
            if (p[3] == 0) gq("($a + $b) $X $c = ?", nums((a + b) * c, listOf(a + b * c, a + b + c, (a + b) * c + c), r), "Brackets first: $a + $b = ${a + b}, then ${a + b} $X $c = ${(a + b) * c}.", "${(a + b) * c}")
            else {
                if (a <= b) return@tp null
                gq("$c $X ($a $MI $b) = ?", nums(c * (a - b), listOf(c * a - b, c * a, c * (a - b) + c), r), "Brackets first: $a $MI $b = ${a - b}, then $c $X ${a - b} = ${c * (a - b)}.", "${c * (a - b)}")
            }
        },
        tp("div", 2, 9, 9, 20) { p, r ->
            val (b, q) = p[0] + 2 to p[1] + 2
            val a = p[2] + 1
            val x = b * q
            gq("$x ÷ $b + $a = ?", nums(q + a, listOf(if (x % (b + a) == 0) x / (b + a) else null, q + a + 1, x + a, q * a), r, min = 1),
                "Divide first: $x ÷ $b = $q, then $q + $a = ${q + a}.", "${q + a}")
        },
        tp("which", 3, 8, 8, 8, 4) { p, r ->
            val (a, b, c) = Triple(p[0] + 2, p[1] + 2, p[2] + 2)
            val ex = listOf("($a + $b) $X $c" to (a + b) * c, "$a + $b $X $c" to a + b * c, "$a $X $b + $c" to a * b + c, "$a $X ($b + $c)" to a * (b + c))
            if (ex.map { it.second }.toSet().size != 4) return@tp null
            val (e, v) = ex[p[3]]
            gq("Which one equals $v?", Opt.of(e, ex.map { it.first } - e, r)!!, "$e = $v, doing brackets and $X first.", "$e = $v")
        },
        tp("two", 3, 8, 8, 8, 8) { p, r ->
            val (a, b, c, d) = listOf(p[0] + 2, p[1] + 2, p[2] + 2, p[3] + 2)
            val ans = a * b - c * d
            if (ans <= 0) return@tp null
            gq("$a $X $b $MI $c $X $d = ?", nums(ans, listOf((a * b - c) * d, ans + 1, a * (b - c) * d, ans + d), r, min = 1),
                "Both $X first: ${a * b} $MI ${c * d} = $ans.", "$ans")
        },
        extra = listOf(Format.catch),
    )

    /** Thousandths as a decimal string: 4200 → 4.2, 60 → 0.06, 5000 → 5. */
    private fun dz(v: Int): String {
        val neg = v < 0
        val a = abs(v)
        val f = "%03d".format(a % 1000).trimEnd('0')
        return (if (neg) MI else "") + "${a / 1000}" + if (f.isEmpty()) "" else ".$f"
    }

    private fun decs(ans: Int, wrongs: List<Int?>, r: Random) = nums(ans, wrongs, r, min = 1, f = ::dz)

    private fun c7Decimals() = sk(
        "ma7.decimals", 7, "Decimals: + − ×", "0.5", "adding, taking away, multiplying and dividing decimals",
        tp("add1", 1, 60, 12, 2) { p, r ->
            val a = 11 + (p[0] * 13) % 89
            val b = 11 + (p[1] * 17 + p[0]) % 89
            val plus = p[2] == 0
            if (!plus && a <= b) return@tp null
            if (a % 10 == 0 || b % 10 == 0) return@tp null
            val ans = if (plus) a + b else a - b
            val slip = if (plus) noCarry(a, b) else noBorrow(a, b)
            val op = if (plus) "+" else MI
            gq("${dz(a * 100)} $op ${dz(b * 100)} = ?", decs(ans * 100, listOf(slip * 100, ans * 10, ans * 100 + 100, ans * 100 - 100), r),
                "Line up the points: ${dz(a * 100)} $op ${dz(b * 100)} = ${dz(ans * 100)}.", "${dz(ans * 100)}")
        },
        tp("addMix", 2, 60, 20, 2) { p, r ->
            val a = 11 + (p[0] * 13) % 89
            val b = 101 + (p[1] * 37 + p[0] * 3) % 899
            val plus = p[2] == 0
            if (a % 10 == 0 || b % 10 == 0) return@tp null
            val ah = a * 10
            if (!plus && ah <= b) return@tp null
            val ans = if (plus) ah + b else ah - b
            val mis = if (plus) a + b else abs(b - a)
            val op = if (plus) "+" else MI
            gq("${dz(a * 100)} $op ${dz(b * 10)} = ?", decs(ans * 10, listOf(mis * 10, ans * 10 + 100, ans * 10 - 100, ans * 10 + 1000), r),
                "Write ${dz(a * 100)} as ${dz(a * 100)}0, then ${dz(a * 100)}0 $op ${dz(b * 10)} = ${dz(ans * 10)}.", "${dz(ans * 10)}")
        },
        tp("mulWhole", 2, 99, 8) { p, r ->
            val x = p[0] + 1
            val w = p[1] + 2
            if (x % 10 == 0) return@tp null
            val ans = x * w * 100
            gq("${dz(x * 100)} $X $w = ?", decs(ans, listOf(ans / 10, ans * 10, ans + 100), r),
                "$x tenths $X $w = ${x * w} tenths, which is ${dz(ans)}.", "${dz(ans)}")
        },
        tp("mulDec", 3, 29, 9) { p, r ->
            val a = p[0] + 1
            val b = p[1] + 1
            if (a % 10 == 0) return@tp null
            val ans = a * b * 10
            gq("${dz(a * 100)} $X ${dz(b * 100)} = ?", decs(ans, listOf(ans * 10, ans / 10, ans * 100), r),
                "$a $X $b = ${a * b}, and two decimal places give ${dz(ans)}.", "${dz(ans)}")
        },
        tp("div10", 3, 200, 2) { p, r ->
            val x = 11 + (p[0] * 47) % 989
            if (x % 10 == 0) return@tp null
            val big = x * 100
            val by = if (p[1] == 0) 10 else 100
            val ans = big / by
            if (big % by != 0) return@tp null
            gq("${dz(big)} ÷ $by = ?", decs(ans, listOf(big * by, ans * 10, ans / 10), r),
                "Dividing by $by moves the point ${if (by == 10) "one place" else "two places"} left: ${dz(ans)}.", "${dz(ans)}")
        },
        tp("cmp", 1, 9, 10, 10, kind = TF) { p, _ ->
            val a = p[0] + 1
            val (b1, b2) = p[1] to p[2]
            if (b2 == 0) return@tp null
            val av = a * 10
            val bv = b1 * 10 + b2
            val x = "0.$a"
            val y = "0.$b1$b2"
            val flip = (a + b1 + b2) % 2 == 0
            val stmt = if (flip) "$y > $x" else "$x > $y"
            val ok = if (flip) bv > av else av > bv
            tf(stmt, ok, "$x is 0.${a}0, and $av hundredths is ${if (av > bv) "more" else "less"} than $bv.")
        },
        tp("order", 2, 9, 9, kind = OR) { p, r ->
            val (a, b) = p[0] + 1 to p[1] + 1
            if (a == b) return@tp null
            val v = listOf(10 * a, 100 * a, 100 * a + 10 * b, 100 * b).distinct().sorted()
            if (v.size < 4) return@tp null
            ord("Put in order, smallest first.", v.map(::dz), r, "Compare tenths first, then hundredths: ${v.joinToString(", ") { dz(it) }}.")
        },
        extra = listOf(Format.catch),
    )

    private val LETTERS = listOf("x", "y", "p")
    private fun term(c: Int, l: String) = if (c == 1) l else "$c$l"

    private fun c7Letters() = sk(
        "ma7.letters", 7, "Letter-numbers", "3x+2", "using letters for numbers: values and like terms",
        tp("value", 1, 8, 9, 8) { p, r ->
            val (a, b, x) = Triple(p[0] + 2, p[1] + 1, p[2] + 2)
            val ans = a * x + b
            gq("Find ${a}x + $b when x = $x.", nums(ans, listOf(glue(a, x) + b, a + x + b, a * (x + b), ans + 1), r, min = 1),
                "${a}x means $a $X x, so $a $X $x + $b = $ans.", "$ans")
        },
        tp("like", 2, 12, 12, 3, 2) { p, r ->
            val (a, b) = p[0] + 1 to p[1] + 1
            val l = LETTERS[p[2]]
            val plus = p[3] == 0
            if (!plus && a <= b) return@tp null
            val c = if (plus) a + b else a - b
            val ans = term(c, l)
            val wr = listOf(term(if (plus) a * b else a + b, l), "$c", "$c$l²", term(c + 1, l))
            gq("${term(a, l)} ${if (plus) "+" else MI} ${term(b, l)} = ?", texts(ans, wr, r)!!,
                "${if (plus) "Add" else "Take away"} the numbers in front: $a ${if (plus) "+" else MI} $b = $c, so $ans.", ans)
        },
        tp("expand", 3, 8, 9, 2) { p, r ->
            val (m, c) = p[0] + 2 to p[1] + 1
            val op = if (p[2] == 0) "+" else MI
            val ans = "${m}x $op ${m * c}"
            val wr = listOf("${m}x $op $c", "x $op ${m * c}", "${m}x $op ${m + c}", "${m + 1}x $op ${m * c}")
            gq("Which is the same as $m(x $op $c)?", texts(ans, wr, r)!!, "Multiply both terms by $m: $ans.", "$m(x $op $c) = $ans")
        },
        tp("two", 3, 5, 5, 6, 6) { p, r ->
            val (ca, cb) = p[0] + 2 to p[1] + 2
            val (a, b) = p[2] + 1 to p[3] + 1
            if (ca == cb && a == b) return@tp null
            val ans = ca * a + cb * b
            gq("Find ${ca}a + ${cb}b when a = $a and b = $b.", nums(ans, listOf(ca * b + cb * a, ca + a + cb + b, ans + 1, ans - 1), r, min = 1),
                "$ca $X $a + $cb $X $b = ${ca * a} + ${cb * b} = $ans.", "$ans")
        },
        tp("tf", 2, 8, 9, 8, kind = TF) { p, _ ->
            val (a, b, x) = Triple(p[0] + 2, p[1] + 1, p[2] + 2)
            val ans = a * x + b
            val shown = if ((a + b + x) % 2 == 0) ans else glue(a, x) + b
            tf("When x = $x, ${a}x + $b = $shown.", shown == ans, "${a}x means $a $X x, so $a $X $x + $b = $ans.")
        },
    )

    private fun deg(n: Int) = "$n°"

    private fun c7Triangle() = sk(
        "ma7.triangle", 7, "Triangle facts", "△", "angle sum, exterior angle, which sides make a triangle",
        tp("third", 1, 24, 24) { p, r ->
            val (a, b) = 20 + 5 * p[0] to 20 + 5 * p[1]
            val c = 180 - a - b
            if (c < 10 || a > b) return@tp null
            gq("Two angles of a triangle are ${deg(a)} and ${deg(b)}. What is the third angle?", nums(c, listOf(360 - a - b, 180 - a, a + b, c + 10), r, min = 1, f = ::deg),
                "Angles add to 180°: 180 $MI $a $MI $b = ${deg(c)}.", deg(c))
        },
        tp("ext", 2, 24, 24) { p, r ->
            val (a, b) = 20 + 5 * p[0] to 20 + 5 * p[1]
            val c = 180 - a - b
            if (c < 10 || a > b) return@tp null
            gq("A triangle has angles ${deg(a)} and ${deg(b)}. What is the exterior angle at the third corner?",
                nums(a + b, listOf(c, 360 - a - b, (a + b) / 2, a + b + 10), r, min = 1, f = ::deg),
                "An exterior angle equals the two far angles: ${deg(a)} + ${deg(b)} = ${deg(a + b)}.", deg(a + b))
        },
        tp("sides", 2, 15, 15, 15, kind = SO) { p, _ ->
            val (a, b, c) = Triple(p[0] + 1, p[1] + 1, p[2] + 1)
            if (!(a <= b && b <= c)) return@tp null
            val ok = a + b > c
            sortQ("Can sides of $a cm, $b cm and $c cm make a triangle?", "Triangle", "No triangle", ok,
                if (ok) "$a + $b = ${a + b}, more than $c, so they can." else "$a + $b = ${a + b}, not more than $c, so they cannot.")
        },
        tp("kind", 3, 34, 34, kind = SO) { p, _ ->
            val (a, b) = 5 * (p[0] + 1) to 5 * (p[1] + 1)
            val c = 180 - a - b
            if (!(a <= b && b <= c) || c == 90 || a < 10) return@tp null
            val acute = c < 90
            sortQ("A triangle has angles ${deg(a)}, ${deg(b)} and ${deg(c)}. Acute or obtuse?", "Acute-angled", "Obtuse-angled", acute,
                "The biggest angle, ${deg(c)}, is ${if (acute) "less" else "more"} than 90°.")
        },
        tp("tf", 1, 24, 24, 2, kind = TF) { p, _ ->
            val (a, b) = 20 + 5 * p[0] to 20 + 5 * p[1]
            val c = 180 - a - b
            if (c < 10 || a > b) return@tp null
            val shown = if (p[1] % 2 == p[2]) c else c + 10
            tf("A triangle can have angles ${deg(a)}, ${deg(b)} and ${deg(shown)}.", shown == c,
                if (shown == c) "$a + $b + $c = 180°, so yes." else "$a + $b + $shown = ${a + b + shown}°, not 180°.")
        },
    )

    private fun br(n: Int) = if (n < 0) "(${s(n)})" else "$n"
    private fun ints(ans: Int, wrongs: List<Int?>, r: Random) = nums(ans, wrongs, r, min = -1000, f = ::s)

    private fun c7Integers() = sk(
        "ma7.integers", 7, "Integer operations", "−3", "adding, taking away, multiplying and dividing integers",
        tp("addSub", 1, 25, 25, 2) { p, r ->
            val (a, b) = p[0] - 12 to p[1] - 12
            if (a == 0 || b == 0 || (a > 0 && b > 0)) return@tp null
            val plus = p[2] == 0
            val ans = if (plus) a + b else a - b
            val other = if (plus) a - b else a + b
            val why = when {
                plus -> "Start at ${s(a)} and move ${abs(b)} ${if (b > 0) "right" else "left"}: ${s(ans)}."
                b < 0 -> "Taking away ${s(b)} is adding ${-b}: ${s(a)} + ${-b} = ${s(ans)}."
                else -> "Start at ${s(a)} and move $b left: ${s(ans)}."
            }
            gq("${br(a)} ${if (plus) "+" else MI} ${br(b)} = ?", ints(ans, listOf(-ans, other, ans + 1, -other), r), why, s(ans))
        },
        tp("mulDiv", 2, 25, 25, 2) { p, r ->
            val (a, b) = p[0] - 12 to p[1] - 12
            if (a == 0 || b == 0 || (a > 0 && b > 0) || abs(a) == 1 || abs(b) == 1) return@tp null
            val same = (a > 0) == (b > 0)
            val rule = if (same) "Same signs give plus" else "Different signs give minus"
            if (p[2] == 0) {
                val ans = a * b
                gq("${br(a)} $X ${br(b)} = ?", ints(ans, listOf(-ans, a + b, ans + b), r), "$rule: ${abs(a)} $X ${abs(b)} = ${abs(ans)}, so ${s(ans)}.", s(ans))
            } else {
                val x = a * b
                gq("${br(x)} ÷ ${br(b)} = ?", ints(a, listOf(-a, x + b, a + 1), r), "$rule: ${abs(x)} ÷ ${abs(b)} = ${abs(a)}, so ${s(a)}.".let {
                    val sm = (x > 0) == (b > 0); "${if (sm) "Same signs give plus" else "Different signs give minus"}: ${abs(x)} ÷ ${abs(b)} = ${abs(a)}, so ${s(a)}."
                }, s(a))
            }
        },
        tp("two", 3, 13, 19, 19) { p, r ->
            val (a, b, c) = Triple(p[0] - 6, p[1] - 9, p[2] - 9)
            if (a == 0 || b == 0 || c == 0 || abs(a) == 1 || abs(b) == 1 || (a > 0 && b > 0)) return@tp null
            val ab = a * b
            val ans = ab + c
            gq("${br(a)} $X ${br(b)} + ${br(c)} = ?", ints(ans, listOf(a * (b + c), -ab + c, ab - c), r),
                "First ${br(a)} $X ${br(b)} = ${s(ab)}, then ${s(ab)} + ${br(c)} = ${s(ans)}.", s(ans))
        },
        tp("tf", 2, 25, 25, 2, kind = TF) { p, _ ->
            val (a, b) = p[0] - 12 to p[1] - 12
            if (a == 0 || b == 0 || (a > 0 && b > 0) || abs(a) == 1 || abs(b) == 1) return@tp null
            val ans = a * b
            val shown = if (p[2] == 0) ans else -ans
            val same = (a > 0) == (b > 0)
            tf("${br(a)} $X ${br(b)} = ${s(shown)}", shown == ans, "${if (same) "Same signs give plus" else "Different signs give minus"}: ${s(ans)}.")
        },
        extra = listOf(Format.catch),
    )

    /** [n] values from a seed; the last is nudged so the sum divides by [n]. */
    /** [n] values in 1..[k], different lists for different seeds. */
    private fun seqOf(seed: Int, n: Int, k: Int): List<Int> {
        var span = 1L
        repeat(n) { span *= k }
        var h = seed.toLong() * 7919 % span
        return List(n) { val v = 1 + (h % k).toInt(); h /= k; v }
    }

    private fun meanList(n: Int, seed: Int): List<Int> {
        var span = 1
        repeat(n - 1) { span *= 20 }
        var h = ((seed / 4).toLong() * 7919 % span).toInt()
        val v = ArrayList<Int>()
        repeat(n - 1) { v += 1 + h % 20; h /= 20 }
        v += (n - v.sum() % n) % n + n * (seed % 4 + 1)
        return v
    }

    private val MEAN_CTX = listOf(
        Triple("Runs in %d matches: %s. What is the mean score?", "runs", 10),
        Triple("Marks in %d tests: %s. What is the mean mark?", "marks", 5),
        Triple("Rain on %d days (mm): %s. What is the mean rainfall?", "mm", 2),
    )

    private fun c7Mean() = sk(
        "ma7.mean", 7, "Mean, median, mode", "avg", "mean, median, mode and range",
        tp("mean", 1, 3, 300) { p, r ->
            val n = p[0] + 3
            val v = meanList(n, p[1])
            val sum = v.sum()
            val m = sum / n
            val med = v.sorted()[n / 2]
            gq("What is the mean of ${v.joinToString(", ")}?", nums(m, listOf(sum, med, m + 1, m - 1), r, min = 1), "Add them: $sum, then ÷ $n gives $m.", "Mean = $m")
        },
        tp("median", 2, 400) { p, r ->
            val v = seqOf(p[0], 5, 40)
            if (v.toSet().size < 5) return@tp null
            val sorted = v.sorted()
            val med = sorted[2]
            gq("What is the median of ${v.joinToString(", ")}?", nums(med, listOf(v[2], sorted[1], sorted[3], v.sum() / 5), r, min = 1),
                "In order: ${sorted.joinToString(", ")}, so the middle is $med.", "Median = $med")
        },
        tp("mode", 2, 300) { p, r ->
            val base = seqOf(p[0], 5, 30)
            if (base.toSet().size < 5) return@tp null
            val m = base[p[0] % 5]
            val v = (base + m).let { l -> val k = (p[0] / 5) % 6; l.drop(k) + l.take(k) }
            gq("What is the mode of ${v.joinToString(", ")}?", Opt.of("$m", (base - m).take(3).map { "$it" }, r)!!, "$m appears twice; the others appear once.", "Mode = $m")
        },
        tp("range", 3, 300) { p, r ->
            val v = seqOf(p[0], 6, 60).map { it + 2 }
            val (hi, lo) = v.max() to v.min()
            gq("What is the range of ${v.joinToString(", ")}?", nums(hi - lo, listOf(hi, hi + lo, hi - lo + 1, v.last() - v.first()), r, min = 1),
                "Highest $hi $MI lowest $lo = ${hi - lo}.", "Range = ${hi - lo}")
        },
        tp("story", 3, MEAN_CTX.size, 200) { p, r ->
            val (txt, unit, k) = MEAN_CTX[p[0]]
            val n = 5
            val v = meanList(n, p[1] + 7)
            val adj = if (k == 10) v.map { it + 10 } else v.map { it * k }
            val sum = adj.sum()
            val m = sum / n
            gq(txt.format(n, adj.joinToString(", ")), nums(m, listOf(sum, adj.sorted()[2], m + 1, m - 1), r, min = 1, f = { "$it $unit" }),
                "Add them: $sum, then ÷ $n gives $m $unit.", "Mean = $m $unit")
        },
    )

    private fun c7FracMul() = sk(
        "ma7.fracMul", 7, "Fractions × and ÷", "×÷", "multiplying and dividing fractions",
        tp("whole", 1, BASE_FR.size, 11) { p, r ->
            val (n, d) = BASE_FR[p[0]]
            val w = p[1] + 2
            val ans = Fr.of(n * w, d)
            val o = fracs(ans, listOf(frOrNull(n, d * w), frOrNull(n + w, d), Fr.of(n, d), ans + Fr.of(1, d)), r, { it.mixed }) ?: return@tp null
            val why = if (ans.plain != "${n * w}/$d") "$n/$d $X $w = ${n * w}/$d = ${ans.mixed}." else "Multiply the top: $n/$d $X $w = ${n * w}/$d = ${ans.mixed}."
            gq("$n/$d $X $w = ?", o, why, "$n/$d $X $w = ${ans.mixed}")
        },
        tp("frac", 2, 8, 8, 8, 8) { p, r ->
            val (d1, n1, d2, n2) = listOf(p[0] + 2, p[1] + 1, p[2] + 2, p[3] + 1)
            if (n1 >= d1 || n2 >= d2 || gcd(n1, d1) != 1 || gcd(n2, d2) != 1) return@tp null
            val ans = Fr.of(n1 * n2, d1 * d2)
            val o = fracs(ans, listOf(frOrNull(n1 + n2, d1 + d2), frOrNull(n1 * n2, d1 + d2), Fr.of(n1 * d2, d1 * n2), Fr.of(n1, d1) + Fr.of(n2, d2)), r, { it.mixed }) ?: return@tp null
            gq("$n1/$d1 $X $n2/$d2 = ?", o, "Tops: $n1 $X $n2 = ${n1 * n2}; bottoms: $d1 $X $d2 = ${d1 * d2}; so ${ans.mixed}.", "${ans.mixed}")
        },
        tp("div", 3, 8, 8, 8, 8) { p, r ->
            val (d1, n1, d2, n2) = listOf(p[0] + 2, p[1] + 1, p[2] + 2, p[3] + 1)
            if (n1 >= d1 || n2 >= d2 || gcd(n1, d1) != 1 || gcd(n2, d2) != 1) return@tp null
            val f1 = Fr.of(n1, d1)
            val f2 = Fr.of(n2, d2)
            val ans = f1 / f2
            val o = fracs(ans, listOf(f1 * f2, Fr.of(d1, n1) * f2, f2 / f1, ans + Fr.of(1, 1)), r, { it.mixed }) ?: return@tp null
            gq("$n1/$d1 ÷ $n2/$d2 = ?", o, "Flip $n2/$d2 and multiply: $n1/$d1 $X $d2/$n2 = ${ans.mixed}.", "${ans.mixed}")
        },
        tp("wholeDiv", 3, 12, 8, 2) { p, r ->
            val w = p[0] + 2
            val d = p[1] + 2
            if (p[2] == 0) gq("$w ÷ 1/$d = ?", nums(w * d, listOf(w + d, w * d + d, w * d - w), r, min = 1).let { (o, i) -> o to i }.let { base ->
                    fracs(Fr.of(w * d, 1), listOf(Fr.of(w, d), Fr.of(w + d, 1), Fr.of(w * d + d, 1)), r, { it.mixed }) ?: base
                }, "There are $d of 1/$d in each whole: $w $X $d = ${w * d}.", "${w * d}")
            else gq("1/$d ÷ $w = ?", fracs(Fr.of(1, d * w), listOf(Fr.of(w, d), Fr.of(1, d + w), Fr.of(d, w)), r, { it.mixed }) ?: return@tp null,
                "Share 1/$d into $w equal parts: 1/${d * w}.", "1/${d * w}")
        },
    )
}
