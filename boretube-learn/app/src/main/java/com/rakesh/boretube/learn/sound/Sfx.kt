package com.rakesh.boretube.learn.sound

/** Every sound the app plays (spec §6). [res] is the file in res/raw (rendered by tools/sfx.py). */
@Suppress("EnumEntryName")
enum class Sfx {
    select, back, focus_bazaar, focus_garden, focus_trail, enter_bazaar,
    q_show, right_1, right_2, right_3, right_4, right_5, miss, learn_open, followup_win,
    catch_drop, catch_move, catch_right, catch_miss,
    build_ten, build_one, build_undo, build_hit, card_flip, card_back, pair_match,
    star_1, star_2, star_3, level_done_bazaar,
    aha, combo, sort_left, sort_right, order_1, order_2, order_3, order_4, order_5, tf_flip,
    run_start, run_milestone, run_end, run_record, star_gold;

    val res: String get() = name

    companion object {
        /** Right answers in a row climb the scale: 1st → right_1 … 5th and on → right_5. */
        fun right(streak: Int): Sfx = entries[right_1.ordinal + (streak.coerceIn(1, 5) - 1)]

        fun star(n: Int): Sfx = entries[star_1.ordinal + (n.coerceIn(1, 3) - 1)]

        /** The [n]th tile placed in an Order puzzle climbs the scale. */
        fun order(n: Int): Sfx = entries[order_1.ordinal + (n.coerceIn(1, 5) - 1)]
    }
}

/** At most one tick per [minGapMs] (held arrow keys must not machine-gun). */
class TickGate(private val minGapMs: Long) {
    private var last = Long.MIN_VALUE / 2

    fun allow(nowMs: Long): Boolean {
        if (nowMs - last < minGapMs) return false
        last = nowMs
        return true
    }
}

/** What screens use to make sound. Everything is silent while sounds are off. */
interface Sounds {
    fun play(s: Sfx)
    fun right(streak: Int) = play(Sfx.right(streak))

    /** A focus tick, rate-limited. */
    fun tick(s: Sfx)

    object Silent : Sounds {
        override fun play(s: Sfx) {}
        override fun tick(s: Sfx) {}
    }
}
