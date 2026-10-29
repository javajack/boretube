package com.rakesh.boretube.learn.core

import kotlin.random.Random

/** A picture beside a question (drawn by the quiz view). */
sealed class Visual {
    /** [count] things to count, e.g. mangoes. */
    data class Objects(val count: Int, val kind: String = "mango") : Visual()
    /** A [rows]×[cols] dot array; the first [splitAt] columns in the second colour (0 = one colour). */
    data class Dots(val rows: Int, val cols: Int, val splitAt: Int = 0) : Visual()
    /** Same-size pies, each shaded num/den. */
    data class Pies(val fractions: List<Pair<Int, Int>>) : Visual()
    data class Clock(val hour: Int, val minute: Int) : Visual()
    /** A picture from the app's library, by id (written banks). */
    data class Picture(val id: String) : Visual()
}

/**
 * One brain-break question. [options] holds 3–4 distinct answers, [answer]
 * indexes the right one. [explain] is the one-line "why" on the learn screen
 * (one sentence, ≤ [Maths.MAX_EXPLAIN_WORDS] words). [key] rebuilds the same
 * question later (spaced repetition).
 */
data class Question(
    val key: String,
    val skill: String,
    val prompt: String,
    val promptHi: String?,
    val spoken: String,
    val spokenHi: String?,
    val options: List<String>,
    val answer: Int,
    /** The full fact for the "Yes!" and summary screens, e.g. "7 × 8 = 56". */
    val fact: String,
    val explain: String,
    val visual: Visual? = null,
    /** The picture on the learn screen (null = none). */
    val learnVisual: Visual? = null,
    /** 1 easy, 2 medium, 3 hard (generated skills; the ladder is 1). */
    val tier: Int = 1,
    /** Put in order: the items, first to last ([options] holds them shuffled). */
    val order: List<String>? = null,
) {
    val answerText: String get() = options[answer]
}

/** A rung of the ladder: picks parameters and builds the question from them. */
class Skill(
    val id: String,
    /** CBSE class: 0 = KG. */
    val grade: Int,
    val title: String,
    private val pickParams: (Random) -> IntArray,
    private val buildQ: (IntArray, Random) -> Question,
    /** An easier fact to win right after a miss (null = the rung below). */
    val easier: ((IntArray) -> IntArray?)? = null,
) {
    fun next(r: Random): Question = buildQ(pickParams(r), r)
    fun build(p: IntArray, r: Random): Question = buildQ(p, r)
}

/**
 * The maths ladder, KG to Class 7, after NCERT's learning outcomes. Wrong
 * options are real mistakes (neighbouring multiple, off by one, swapped
 * digits, forgot the carry), never random numbers.
 */
object Maths {
    const val MAX_EXPLAIN_WORDS = 12
    const val MAX_GRADE = 7

    private const val TIMES = "×"
    private const val MINUS = "−"

    /** Fills [wrongs] (deduped, never the answer, never < [min]) up to [count] − 1 with nearby numbers, shuffled. */
    fun numberOptions(answer: Int, wrongs: List<Int>, r: Random, count: Int = 4, min: Int = 0): Pair<List<String>, Int> {
        val picked = LinkedHashSet<Int>()
        for (w in wrongs) if (w != answer && w >= min && picked.size < count - 1) picked += w
        var d = 1
        while (picked.size < count - 1) {
            for (c in listOf(answer + d, answer - d)) if (c != answer && c >= min && picked.size < count - 1) picked += c
            d++
        }
        val all = (picked + answer).shuffled(r)
        return all.map { fmt(it) } to all.indexOf(answer)
    }

    private fun fmt(n: Int) = if (n < 0) "$MINUS${-n}" else "$n"

    private fun textOptions(answer: String, wrongs: List<String>, r: Random): Pair<List<String>, Int> {
        val all = (wrongs.filter { it != answer }.distinct() + answer).shuffled(r)
        return all to all.indexOf(answer)
    }

    private fun swapDigits(n: Int): Int? =
        if (n in 10..99 && n % 10 != n / 10 && n % 10 != 0) (n % 10) * 10 + n / 10 else null

    private fun q(
        key: String, skill: String, prompt: String, promptHi: String?, spoken: String, spokenHi: String?,
        opts: Pair<List<String>, Int>, fact: String, explain: String, visual: Visual? = null, learnVisual: Visual? = null,
    ) = Question(key, skill, prompt, promptHi, spoken, spokenHi, opts.first, opts.second, fact, explain, visual, learnVisual)

    private fun key(id: String, vararg p: Int) = (listOf(id) + p.map { it.toString() }).joinToString(":")

    // ── KG ──

    private val count10 = Skill("count10", 0, "Counting to 10",
        { r -> intArrayOf(r.nextInt(1, 11)) },
        { p, r ->
            val n = p[0]
            q(key("count10", n), "count10", "How many mangoes?", "कितने आम हैं?",
                "How many mangoes?", "कितने आम हैं?",
                numberOptions(n, listOf(n - 1, n + 1, n + 2), r, min = 1), "$n mangoes",
                "Count them one by one: there are $n.",
                Visual.Objects(n), Visual.Objects(n))
        })

    private val biggest10 = Skill("biggest10", 0, "Which is more",
        { r -> (1..10).shuffled(r).take(4).toIntArray() },
        { p, r ->
            val max = p.max()
            val opts = p.toList().shuffled(r)
            q(key("biggest10", *p), "biggest10", "Which number is the biggest?", "सबसे बड़ी संख्या कौन सी है?",
                "Which number is the biggest?", "सबसे बड़ी संख्या कौन सी है?",
                opts.map { "$it" } to opts.indexOf(max), "$max is the biggest",
                "$max comes last when we count, so it is biggest.")
        })

    // ── Class 1 ──

    private val add10 = Skill("add10", 1, "Adding within 10",
        { r -> val a = r.nextInt(1, 9); intArrayOf(a, r.nextInt(1, 11 - a)) },
        { p, r ->
            val (a, b) = p[0] to p[1]
            val s = a + b
            q(key("add10", a, b), "add10", "$a + $b = ?", null, "What is $a plus $b?", "$a और $b मिलाकर कितने होते हैं?",
                numberOptions(s, listOf(s - 1, s + 1, kotlin.math.abs(a - b)), r, min = 1), "$a + $b = $s",
                "Start at $a and count on $b more: $s.",
                learnVisual = Visual.Dots(1, s, a))
        })

    private val sub10 = Skill("sub10", 1, "Taking away within 10",
        { r -> val a = r.nextInt(2, 11); intArrayOf(a, r.nextInt(1, a)) },
        { p, r ->
            val (a, b) = p[0] to p[1]
            val d = a - b
            q(key("sub10", a, b), "sub10", "$a $MINUS $b = ?", null, "What is $a take away $b?", "$a में से $b घटाओ तो कितने बचते हैं?",
                numberOptions(d, listOf(d + 1, d - 1, a + b), r), "$a $MINUS $b = $d",
                "Start at $a and count back $b: $d.")
        })

    private val next20 = Skill("next20", 1, "Counting to 20",
        { r -> intArrayOf(r.nextInt(1, 20)) },
        { p, r ->
            val n = p[0]
            q(key("next20", n), "next20", "What comes after $n?", "$n के बाद कौन सी संख्या आती है?",
                "What number comes after $n?", "$n के बाद कौन सी संख्या आती है?",
                numberOptions(n + 1, listOf(n - 1, n + 2, n), r, min = 0), "After $n comes ${n + 1}",
                "Count on from $n: the next number is ${n + 1}.")
        })

    // ── Class 2 ──

    private val make10 = Skill("make10", 2, "Adding past 10",
        { r -> val a = r.nextInt(6, 10); intArrayOf(a, r.nextInt(11 - a, 10)) },
        { p, r ->
            val (a, b) = p[0] to p[1]
            val s = a + b
            val rest = b - (10 - a)
            q(key("make10", a, b), "make10", "$a + $b = ?", null, "What is $a plus $b?", "$a और $b मिलाकर कितने होते हैं?",
                numberOptions(s, listOf(s - 1, s + 1, s - 10), r, min = 1), "$a + $b = $s",
                "Make 10 first: $a + ${10 - a} = 10, then $rest more is $s.")
        })

    private val placeValue = Skill("placeValue", 2, "Tens and ones",
        { r -> intArrayOf(r.nextInt(11, 100).let { if (it % 10 == 0) it + 1 else it }) },
        { p, r ->
            val n = p[0]
            val t = n / 10
            val o = n % 10
            q(key("placeValue", n), "placeValue", "How many tens are in $n?", "$n में कितनी दहाइयाँ हैं?",
                "How many tens are in $n?", "$n में कितनी दहाइयाँ हैं?",
                numberOptions(t, listOf(o, t * 10, t + 1), r, min = 0), "$n has $t tens",
                "$n is $t ${if (t == 1) "ten" else "tens"} and $o ${if (o == 1) "one" else "ones"}.")
        })

    private val add100 = Skill("add100", 2, "Adding within 100",
        { r ->
            val a = r.nextInt(11, 80)
            intArrayOf(a, r.nextInt(11, 100 - a).coerceAtLeast(11)).takeIf { it[0] + it[1] < 100 } ?: intArrayOf(23, 45)
        },
        { p, r ->
            val (a, b) = p[0] to p[1]
            val s = a + b
            val tens = (a / 10 + b / 10) * 10
            val ones = a % 10 + b % 10
            val noCarry = tens + ones % 10
            q(key("add100", a, b), "add100", "$a + $b = ?", null, "What is $a plus $b?", "$a और $b मिलाकर कितने होते हैं?",
                numberOptions(s, listOf(noCarry, s + 10, s - 1, s - 10), r, min = 1), "$a + $b = $s",
                if (ones < 10) "Tens: ${a / 10 * 10} + ${b / 10 * 10} = $tens, ones: ${a % 10} + ${b % 10} = $ones, so $s."
                else "Tens make $tens, ones make $ones, so $tens + $ones = $s.")
        })

    // ── Tables (Class 3: ×2–5, ×10; Class 4: ×6–9) ──

    fun tablesExplain(a: Int, b: Int): String {
        val p = a * b
        return when (b) {
            2 -> "$a $TIMES 2 is $a doubled: $a + $a = $p."
            3 -> "$a $TIMES 3 is $a + $a + $a = $p."
            4 -> "$a $TIMES 4: double $a is ${a * 2}, double again is $p."
            5 -> "$a $TIMES 5 is half of ${a * 10}, which is $p."
            6, 7 -> "$a $TIMES $b is $a $TIMES ${b - 1} plus one more $a: ${a * (b - 1)} + $a = $p."
            8 -> "$a $TIMES 8 is $a $TIMES 4 doubled: ${a * 4} + ${a * 4} = $p."
            9 -> "$a $TIMES 9 is $a $TIMES 10 take away $a: ${a * 10} $MINUS $a = $p."
            10 -> "$a $TIMES 10: put a zero after $a to get $p."
            else -> "$a $TIMES $b is $b groups of $a, which is $p."
        }
    }

    private fun tablesQ(id: String, a: Int, b: Int, r: Random): Question {
        val p = a * b
        val split = when {
            b == 10 -> 0
            b % 2 == 0 -> b / 2
            else -> b - 1
        }
        return q(key(id, a, b), id, "$a $TIMES $b = ?", null, "What is $a times $b?", "$a गुणा $b कितना होता है?",
            numberOptions(p, listOfNotNull(a * (b - 1), a * (b + 1), (a + 1) * b, swapDigits(p), p - 2), r, min = 1),
            "$a $TIMES $b = $p", tablesExplain(a, b), learnVisual = Visual.Dots(a, b, split))
    }

    /** The easier table fact after a miss: 7×8 → 7×4, 7×9 → 7×10, 7×5 → 7×10, 7×7 → 7×6. */
    private fun easierTable(p: IntArray): IntArray? {
        val (a, b) = p[0] to p[1]
        val e = when (b) {
            2 -> return null
            3 -> 2
            5, 9 -> 10
            10 -> return null
            else -> if (b % 2 == 0) b / 2 else b - 1
        }
        return intArrayOf(a, e)
    }

    private val tablesLow = Skill("tablesLow", 3, "Tables of 2, 3, 4, 5 and 10",
        { r -> intArrayOf(r.nextInt(2, 11), listOf(2, 3, 4, 5, 10).random(r)) },
        { p, r -> tablesQ("tablesLow", p[0], p[1], r) },
        easier = ::easierTable)

    private val money = Skill("money", 3, "Money",
        { r ->
            val notes = listOf(10, 20, 50)
            val coins = listOf(1, 2, 5)
            intArrayOf(notes.random(r), notes.random(r), coins.random(r))
        },
        { p, r ->
            val s = p.sum()
            val run1 = p[0] + p[1]
            q(key("money", *p), "money", "₹${p[0]} + ₹${p[1]} + ₹${p[2]} = ?", "कुल कितने रुपये?",
                "How much money is ${p[0]} rupees, ${p[1]} rupees and ${p[2]} rupees?", "कुल कितने रुपये हुए?",
                numberOptions(s, listOf(s + 10, s - 10, s + 1, run1), r, min = 1).let { (o, i) -> o.map { "₹$it" } to i },
                "₹${p[0]} + ₹${p[1]} + ₹${p[2]} = ₹$s",
                "Add them one by one: ${p[0]}, then $run1, then $s.")
        })

    private val clock = Skill("clock", 3, "Telling the time",
        { r -> intArrayOf(r.nextInt(1, 13), if (r.nextBoolean()) 0 else 30) },
        { p, r ->
            val (h, m) = p[0] to p[1]
            fun t(hh: Int, mm: Int) = "${(hh - 1).mod(12) + 1}:${"%02d".format(mm)}"
            val right = t(h, m)
            val wrongs = if (m == 0) listOf(t(12, h * 5 % 60).takeIf { h != 12 } ?: "6:00", t(h + 1, 0), t(h, 30))
            else listOf(t(h + 1, 30), t(h + 1, 0), t(6, 0).takeIf { h != 6 } ?: "12:30")
            val explain = if (m == 0) "The long hand is on 12, the short hand is on $h."
            else "The long hand is on 6, so it is half past $h."
            q(key("clock", h, m), "clock", "What time is it?", "घड़ी में कितने बजे हैं?",
                "What time does the clock show?", "घड़ी में कितने बजे हैं?",
                textOptions(right, wrongs, r), "It is $right", explain, Visual.Clock(h, m), Visual.Clock(h, m))
        })

    // ── Class 4 ──

    private val tablesHigh = Skill("tablesHigh", 4, "Tables of 6, 7, 8 and 9",
        { r -> intArrayOf(r.nextInt(2, 11), r.nextInt(6, 10)) },
        { p, r -> tablesQ("tablesHigh", p[0], p[1], r) },
        easier = ::easierTable)

    private val divide = Skill("divide", 4, "Division facts",
        { r -> intArrayOf(r.nextInt(2, 11), r.nextInt(2, 11)) },
        { p, r ->
            val (a, b) = p[0] to p[1]
            val n = a * b
            q(key("divide", a, b), "divide", "$n ÷ $a = ?", null, "What is $n divided by $a?", "$n को $a से भाग दो तो कितना?",
                numberOptions(b, listOf(b + 1, b - 1, a), r, min = 1), "$n ÷ $a = $b",
                "$a $TIMES $b = $n, so $n ÷ $a = $b.")
        })

    private val mul21 = Skill("mul21", 4, "2-digit times 1-digit",
        { r -> intArrayOf(r.nextInt(11, 50).let { if (it % 10 == 0) it + 1 else it }, r.nextInt(2, 10)) },
        { p, r ->
            val (a, b) = p[0] to p[1]
            val t = a / 10 * 10
            val o = a % 10
            val n = a * b
            val forgotCarry = t * b + (o * b) % 10
            q(key("mul21", a, b), "mul21", "$a $TIMES $b = ?", null, "What is $a times $b?", "$a गुणा $b कितना होता है?",
                numberOptions(n, listOf(forgotCarry, n + b, n - 10, n + 10), r, min = 1), "$a $TIMES $b = $n",
                "$t $TIMES $b = ${t * b}, $o $TIMES $b = ${o * b}, so $n.")
        })

    // ── Class 5 ──

    private val fractionPairs = listOf(
        intArrayOf(3, 4, 2, 3), intArrayOf(1, 2, 1, 3), intArrayOf(2, 3, 1, 2), intArrayOf(1, 4, 1, 3),
        intArrayOf(3, 5, 1, 2), intArrayOf(5, 8, 3, 4), intArrayOf(1, 2, 2, 4), intArrayOf(2, 6, 1, 3),
        intArrayOf(3, 4, 6, 8), intArrayOf(2, 5, 1, 2), intArrayOf(5, 6, 3, 4), intArrayOf(1, 6, 1, 4),
    )

    private val fractions = Skill("fractions", 5, "Comparing fractions",
        { r -> fractionPairs.random(r).let { if (r.nextBoolean()) it else intArrayOf(it[2], it[3], it[0], it[1]) } },
        { p, r ->
            val (an, ad, bn, bd) = listOf(p[0], p[1], p[2], p[3])
            val cmp = (an * bd).compareTo(bn * ad)
            val fa = "$an/$ad"
            val fb = "$bn/$bd"
            val opts = listOf(fa, fb, "Same")
            val right = when { cmp > 0 -> fa; cmp < 0 -> fb; else -> "Same" }
            val explain = when {
                cmp == 0 -> "Look at the pizzas: $fa and $fb cover the same."
                else -> "Look at the pizzas: $right has more orange than ${if (right == fa) fb else fa}."
            }
            q(key("fractions", *p), "fractions", "Which is more pizza?", "कौन सा हिस्सा ज़्यादा है?",
                "Which is more pizza, $an out of $ad or $bn out of $bd?", "कौन सा हिस्सा ज़्यादा है?",
                opts to opts.indexOf(right), if (cmp == 0) "$fa = $fb" else "$right is more",
                explain, Visual.Pies(listOf(an to ad, bn to bd)), Visual.Pies(listOf(an to ad, bn to bd)))
        })

    private val halfOf = Skill("halfOf", 5, "Half and quarter of",
        { r -> if (r.nextBoolean()) intArrayOf(2, r.nextInt(3, 50) * 2) else intArrayOf(4, r.nextInt(2, 25) * 4) },
        { p, r ->
            val (d, n) = p[0] to p[1]
            val a = n / d
            val word = if (d == 2) "Half" else "A quarter"
            q(key("halfOf", d, n), "halfOf", "1/$d of $n = ?", "$n का 1/$d कितना है?",
                "What is one ${if (d == 2) "half" else "quarter"} of $n?", "$n का 1/$d कितना है?",
                numberOptions(a, listOf(n / (if (d == 2) 4 else 2), a + 1, n - a), r, min = 1), "1/$d of $n = $a",
                if (d == 2) "$word of $n: share it into 2 equal groups of $a."
                else "$word is half of half: $n, then ${n / 2}, then $a.")
        })

    private val decimals = Skill("decimals", 5, "Comparing decimals",
        { r ->
            val a = r.nextInt(1, 10)
            val b = a * 10 - r.nextInt(1, 10)
            if (r.nextBoolean()) intArrayOf(a, 1, b, 2) else intArrayOf(b, 2, a, 1)
        },
        { p, r ->
            fun s(v: Int, places: Int) = if (places == 1) "0.$v" else "0.${"%02d".format(v)}"
            val x = s(p[0], p[1])
            val y = s(p[2], p[3])
            val xv = if (p[1] == 1) p[0] * 10 else p[0]
            val yv = if (p[3] == 1) p[2] * 10 else p[2]
            val big = if (xv > yv) x else y
            val bigV = maxOf(xv, yv)
            val smallV = minOf(xv, yv)
            val opts = listOf(x, y, "Same")
            // The one-place number, written in hundredths (0.5 → 0.50).
            val (short, long) = if (p[1] == 1) x to s(p[0] * 10, 2) else y to s(p[2] * 10, 2)
            q(key("decimals", *p), "decimals", "Which is bigger?", "कौन सी संख्या बड़ी है?",
                "Which is bigger, $x or $y?", "कौन सी संख्या बड़ी है?",
                opts to opts.indexOf(big), "$big is bigger",
                "$short is $long, and $bigV hundredths beats $smallV.")
        })

    // ── Class 6 ──

    private val percent = Skill("percent", 6, "Percentages",
        { r ->
            when (r.nextInt(3)) {
                0 -> intArrayOf(10, r.nextInt(2, 51) * 10)
                1 -> intArrayOf(50, r.nextInt(2, 51) * 2)
                else -> intArrayOf(25, r.nextInt(2, 26) * 4)
            }
        },
        { p, r ->
            val (pc, n) = p[0] to p[1]
            val a = n * pc / 100
            val explain = when (pc) {
                10 -> "10% means split into 10 parts: $n ÷ 10 = $a."
                50 -> "50% is half: half of $n is $a."
                else -> "25% is half of half: $n, then ${n / 2}, then $a."
            }
            q(key("percent", pc, n), "percent", "$pc% of $n = ?", "$n का $pc% कितना है?",
                "What is $pc percent of $n?", "$n का $pc प्रतिशत कितना है?",
                numberOptions(a, listOf(a * 10, n - a, a + pc / 5, a * 2), r, min = 1), "$pc% of $n = $a", explain)
        })

    private val negatives = Skill("negatives", 6, "Negative numbers",
        { r -> intArrayOf(-r.nextInt(1, 10), r.nextInt(1, 13)) },
        { p, r ->
            val (a, b) = p[0] to p[1]
            val s = a + b
            q(key("negatives", a, b), "negatives", "${fmt(a)} + $b = ?", null,
                "What is minus ${-a} plus $b?", "माइनस ${-a} और $b मिलाकर कितना?",
                numberOptions(s, listOf(-s, a - b, s + 1, s - 1).filter { it != s }, r, min = Int.MIN_VALUE), "${fmt(a)} + $b = ${fmt(s)}",
                "Start at ${fmt(a)} and move $b steps up: you reach ${fmt(s)}.")
        })

    // ── Class 7 ──

    private val equations = Skill("equations", 7, "One-step equations",
        { r ->
            when (r.nextInt(3)) {
                0 -> intArrayOf(0, r.nextInt(2, 20), r.nextInt(1, 20)) // x + b = c
                1 -> intArrayOf(1, r.nextInt(2, 20), r.nextInt(1, 20)) // x − b = c
                else -> intArrayOf(2, r.nextInt(2, 10), r.nextInt(2, 13)) // b × x = c
            }
        },
        { p, r ->
            val (kind, b, x) = Triple(p[0], p[1], p[2])
            // kind 1 reads p[2] as c in x − b = c, so x = c + b.
            val (prompt, explain, wrongs) = when (kind) {
                0 -> Triple("x + $b = ${x + b}", "Take $b from both sides: x = ${x + b} $MINUS $b = $x.", listOf(x + 2 * b, x + 1, x - 1))
                1 -> Triple("x $MINUS $b = $x", "Add $b to both sides: x = $x + $b = ${x + b}.", listOf(x - b, x + b + 1, x))
                else -> Triple("$b x = ${b * x}", "Divide both sides by $b: x = ${b * x} ÷ $b = $x.", listOf(b * x - b, x + 1, x - 1))
            }
            val ans = if (kind == 1) x + b else x
            q(key("equations", *p), "equations", "$prompt, x = ?", null, "If $prompt, what is x?", "अगर $prompt, तो x कितना है?",
                numberOptions(ans, wrongs, r, min = Int.MIN_VALUE), "x = $ans", explain)
        })

    /** Easy to hard. A child sits on one rung; rounds warm up on the rung below. */
    val LADDER: List<Skill> = listOf(
        count10, biggest10,
        add10, sub10, next20,
        make10, placeValue, add100,
        tablesLow, money, clock,
        tablesHigh, divide, mul21,
        fractions, halfOf, decimals,
        percent, negatives,
        equations,
    )

    fun indexOf(skillId: String): Int = LADDER.indexOfFirst { it.id == skillId }

    fun skill(id: String): Skill? = LADDER.firstOrNull { it.id == id }

    /** The first rung of [grade] (clamped to 0..[MAX_GRADE]). */
    fun firstRung(grade: Int): Int = LADDER.indexOfFirst { it.grade >= grade.coerceIn(0, MAX_GRADE) }

    /** The lowest rung a child of [grade] may drop to (one class below). */
    fun minRung(grade: Int): Int = firstRung(grade - 1)

    /** The highest rung a child of [grade] may climb to (one class above). */
    fun maxRung(grade: Int): Int = LADDER.indexOfLast { it.grade <= (grade + 1).coerceIn(0, MAX_GRADE) }

    /** Rebuilds the question a [Question.key] names (spaced repetition), or null if unknown. */
    fun fromKey(key: String, r: Random): Question? {
        val parts = key.split(":")
        val s = skill(parts[0]) ?: return null
        val p = parts.drop(1).map { it.toIntOrNull() ?: return null }.toIntArray()
        return try { s.build(p, r) } catch (_: Exception) { null }
    }

    /**
     * An easier question to win right after missing [q]: the skill's own easier
     * fact (7×8 → 7×4), else a question from the rung below.
     */
    fun easierThan(q: Question, r: Random): Question? {
        val s = skill(q.skill) ?: return null
        val p = q.key.split(":").drop(1).mapNotNull { it.toIntOrNull() }.toIntArray()
        s.easier?.invoke(p)?.let { return s.build(it, r) }
        val i = indexOf(q.skill)
        return if (i > 0) LADDER[i - 1].next(r) else s.next(r)
    }

    /** Words in [s] that hold a letter or digit (operators and punctuation don't count). */
    fun wordCount(s: String): Int = s.split(Regex("\\s+")).count { w -> w.any { it.isLetterOrDigit() } }
}
