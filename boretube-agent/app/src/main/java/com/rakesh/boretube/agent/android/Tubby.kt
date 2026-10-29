package com.rakesh.boretube.agent.android

import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import com.rakesh.boretube.agent.core.CardMood

enum class TubbyMood {
    asleep, calm, guard,
    /** Brain break: a right answer, the done screen. */
    cheer,
    /** Brain break: the learn screen. */
    think;

    companion object {
        fun of(m: CardMood): TubbyMood = when (m) {
            CardMood.asleep -> asleep
            CardMood.calm -> calm
            CardMood.guard -> guard
        }
    }
}

/**
 * The mascot, drawn natively on a Canvas (the mock's SVG geometry, viewBox
 * 0 0 120 110). Shared by the TV card and the brain-break quiz. Not
 * thread-safe: one instance per view, used on the UI thread.
 */
class Tubby {
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val zPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = Typeface.create("sans-serif", Typeface.BOLD)
        color = CREAM
    }

    /** Draws Tubby with its top-left at ([left], [top]), [width] wide (height = width × 110/120). */
    fun draw(c: Canvas, mood: TubbyMood, left: Float, top: Float, width: Float) {
        val k = width / 120f
        c.save()
        c.translate(left, top)
        c.scale(k, k)
        // Antennae and legs in cream: they must read on the navy background.
        stroke.color = CREAM
        stroke.strokeWidth = 5f
        c.drawLine(44f, 14f, 34f, 2f, stroke)
        c.drawLine(76f, 14f, 86f, 2f, stroke)
        if (mood == TubbyMood.cheer) {
            // Arms up.
            stroke.color = CORAL
            stroke.strokeWidth = 7f
            c.drawLine(8f, 52f, -6f, 34f, stroke)
            c.drawLine(112f, 52f, 126f, 34f, stroke)
        }
        fill.color = when (mood) {
            TubbyMood.asleep, TubbyMood.think -> SUNFLOWER
            TubbyMood.calm -> SKY
            TubbyMood.guard -> MINT
            TubbyMood.cheer -> CORAL
        }
        c.drawRoundRect(BODY, 26f, 26f, fill)
        fill.color = if (mood == TubbyMood.asleep) SCREEN_NIGHT else CREAM
        c.drawRoundRect(SCREEN, 18f, 18f, fill)
        when (mood) {
            TubbyMood.asleep -> {
                stroke.color = CREAM
                stroke.strokeWidth = 4.5f
                c.drawPath(SLEEP_EYES, stroke)
                stroke.strokeWidth = 4f
                c.drawPath(SLEEP_MOUTH, stroke)
            }
            TubbyMood.calm -> {
                eyes(c)
                stroke.color = INK
                stroke.strokeWidth = 5f
                c.drawPath(SMILE, stroke)
                cheeks(c)
            }
            TubbyMood.guard -> {
                eyes(c)
                stroke.color = INK
                stroke.strokeWidth = 5f
                c.drawLine(50f, 65f, 70f, 65f, stroke)
                fill.color = INK
                c.drawPath(GUARD_SHIELD, fill)
                stroke.color = MINT
                stroke.strokeWidth = 3.5f
                c.drawPath(GUARD_CHECK, stroke)
            }
            TubbyMood.cheer -> {
                stroke.color = INK
                stroke.strokeWidth = 5f
                c.drawPath(HAPPY_EYES, stroke)
                fill.color = INK
                c.drawPath(OPEN_SMILE, fill)
                cheeks(c)
            }
            TubbyMood.think -> {
                eyes(c)
                stroke.color = INK
                stroke.strokeWidth = 4f
                c.drawLine(37f, 38f, 52f, 35f, stroke)
                c.drawCircle(64f, 67f, 5f, stroke)
            }
        }
        fill.color = CREAM
        c.drawRoundRect(LEG_L, 4f, 4f, fill)
        c.drawRoundRect(LEG_R, 4f, 4f, fill)
        c.restore()
        if (mood == TubbyMood.asleep) {
            // The "z z", drawn unscaled so the glyphs rasterise at their real size.
            zPaint.textSize = 14f * k
            c.drawText("z", left + 88f * k, top + 42f * k, zPaint)
            zPaint.textSize = 10f * k
            c.drawText("z", left + 96f * k, top + 33f * k, zPaint)
        }
    }

    private fun eyes(c: Canvas) {
        fill.color = INK
        c.drawCircle(45f, 50f, 6f, fill)
        c.drawCircle(75f, 50f, 6f, fill)
    }

    private fun cheeks(c: Canvas) {
        fill.color = CORAL
        fill.alpha = (0.55f * 255).toInt()
        c.drawCircle(33f, 64f, 5f, fill)
        c.drawCircle(87f, 64f, 5f, fill)
        fill.alpha = 255
    }

    companion object {
        /** Height for a given width. */
        fun heightFor(width: Float) = width * 110f / 120f

        private val CREAM = Color.parseColor("#FFF8F1")
        private val SUNFLOWER = Color.parseColor("#FFB020")
        private val SKY = Color.parseColor("#3A8DFF")
        private val MINT = Color.parseColor("#1FBF8F")
        private val CORAL = Color.parseColor("#FF6B4A")
        private val INK = Color.parseColor("#1C1D3A")
        private val SCREEN_NIGHT = Color.parseColor("#2A2B4D")

        private val BODY = RectF(6f, 14f, 114f, 94f)
        private val SCREEN = RectF(18f, 25f, 102f, 83f)
        private val LEG_L = RectF(32f, 94f, 42f, 106f)
        private val LEG_R = RectF(78f, 94f, 88f, 106f)
        private val SLEEP_EYES = Path().apply {
            moveTo(38f, 52f); quadTo(45f, 58f, 52f, 52f) // M38 52 Q45 58 52 52
            moveTo(68f, 52f); quadTo(75f, 58f, 82f, 52f) // M68 52 Q75 58 82 52
        }
        private val SLEEP_MOUTH = Path().apply { moveTo(54f, 68f); quadTo(60f, 71f, 66f, 68f) }
        private val SMILE = Path().apply { moveTo(48f, 64f); quadTo(60f, 74f, 72f, 64f) }
        private val HAPPY_EYES = Path().apply {
            moveTo(38f, 52f); quadTo(45f, 44f, 52f, 52f)
            moveTo(68f, 52f); quadTo(75f, 44f, 82f, 52f)
        }
        private val OPEN_SMILE = Path().apply { moveTo(46f, 61f); quadTo(60f, 80f, 74f, 61f); close() }
        /** M96 60 l14 5 v10 c0 8-6 13-14 15-8-2-14-7-14-15 V65z */
        private val GUARD_SHIELD = Path().apply {
            moveTo(96f, 60f); lineTo(110f, 65f); lineTo(110f, 75f)
            cubicTo(110f, 83f, 104f, 88f, 96f, 90f)
            cubicTo(88f, 88f, 82f, 83f, 82f, 75f)
            lineTo(82f, 65f); close()
        }
        /** M90 76 l4 4 8-8 */
        private val GUARD_CHECK = Path().apply { moveTo(90f, 76f); lineTo(94f, 80f); lineTo(102f, 72f) }
    }
}
