package com.rakesh.boretube.agent.android

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import com.rakesh.boretube.agent.core.Card
import com.rakesh.boretube.agent.core.CardMood
import kotlin.math.hypot
import kotlin.math.min

/**
 * The TV card, drawn natively (no bitmaps, no extra views): a soft navy radial
 * gradient, a few dots, Tubby (mood by reason) on the left and the text column
 * on the right. Geometry follows the 1280×720 design mock
 * (design/project/TvCard.dc.html), scaled to the window; Tubby uses the mock's
 * SVG geometry (viewBox 0 0 120 110). Content stays inside a 5% TV-safe margin.
 */
class TvCardView(ctx: Context) : View(ctx) {
    private var card: Card = Card("", null)
    private var dirty = true

    private val bg = Paint()
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
    private val kickerPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = Typeface.create("sans-serif", Typeface.BOLD)
        color = SUNFLOWER_SOFT
    }
    private val headPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { color = CREAM }
    private val subPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = Typeface.create("sans-serif", Typeface.NORMAL)
        color = LAVENDER
    }
    private val footPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        color = MUTED
    }

    // Layout, recomputed when the size or the card changes.
    private var u = 1f
    private var tubbyLeft = 0f
    private var tubbyTop = 0f
    private var tubbyScale = 1f
    private var textLeft = 0f
    private var textTop = 0f
    private var head: StaticLayout? = null
    private var sub: StaticLayout? = null
    private var footText: CharSequence = ""
    private var kickerH = 0f
    private var footH = 0f

    init {
        headPaint.typeface = headline(ctx)
    }

    fun bind(c: Card) {
        card = c
        dirty = true
        invalidate()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        bg.shader = RadialGradient(
            0.3f * w, 0.3f * h, hypot(0.7f * w, 0.7f * h).coerceAtLeast(1f),
            intArrayOf(NAVY_LIGHT, NAVY_DARK), floatArrayOf(0f, 0.7f), Shader.TileMode.CLAMP,
        )
        dirty = true
    }

    private fun layoutCard() {
        val w = width.toFloat()
        val h = height.toFloat()
        u = min(w / 1280f, h / 720f)
        val safeX = 0.05f * w
        val safeY = 0.05f * h
        val tubbyW = 0.25f * w
        val tubbyH = tubbyW * 110f / 120f
        val gap = 72f * u
        val textW = min(600f * u, w - 2 * safeX - tubbyW - gap).coerceAtLeast(100f)
        val left = ((w - (tubbyW + gap + textW)) / 2f).coerceAtLeast(safeX)
        tubbyScale = tubbyW / 120f
        tubbyLeft = left
        tubbyTop = (h - tubbyH) / 2f
        textLeft = left + tubbyW + gap

        kickerPaint.textSize = 26f * u
        kickerPaint.letterSpacing = 2f / 26f
        subPaint.textSize = 32f * u
        footPaint.textSize = 22f * u
        kickerH = kickerPaint.fontMetrics.let { it.descent - it.ascent }
        footH = maxOf(26f * u, footPaint.fontMetrics.let { it.descent - it.ascent })
        val tw = textW.toInt()
        sub = card.subLine?.let { build(it, subPaint, tw, 1.4f, 4) }
        footText = TextUtils.ellipsize(FOOTER, footPaint, textW - 40f * u, TextUtils.TruncateAt.END)

        // Headline: 84 (mock) down to 52 until it fits in 3 lines and the column fits the safe area.
        val maxH = h - 2 * safeY
        var size = 84f
        while (true) {
            headPaint.textSize = size * u
            headPaint.letterSpacing = -1.5f / 84f
            val l = build(card.message, headPaint, tw, 1.02f, 4)
            head = l
            if ((l.lineCount <= 3 && columnHeight() <= maxH) || size <= 52f) break
            size -= 4f
        }
        textTop = ((h - columnHeight()) / 2f).coerceAtLeast(safeY)
        dirty = false
    }

    private fun columnHeight(): Float {
        val g = 18f * u
        var hgt = kickerH + g + (head?.height ?: 0)
        sub?.let { hgt += g + it.height }
        return hgt + g + 8f * u + footH
    }

    /** StaticLayout whose line height is [lineHeight] × the text size (CSS line-height). */
    private fun build(text: CharSequence, p: TextPaint, width: Int, lineHeight: Float, maxLines: Int): StaticLayout {
        val fm = p.fontMetrics
        val natural = (fm.descent - fm.ascent).coerceAtLeast(1f)
        return StaticLayout.Builder.obtain(text, 0, text.length, p, width)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setLineSpacing(0f, lineHeight * p.textSize / natural)
            .setIncludePad(false)
            .setMaxLines(maxLines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .build()
    }

    override fun onDraw(c: Canvas) {
        if (width == 0 || height == 0) return
        if (dirty) layoutCard()
        val w = width.toFloat()
        val h = height.toFloat()
        c.drawRect(0f, 0f, w, h, bg)
        for (d in DOTS) {
            fill.color = d.color
            fill.alpha = (d.alpha * 255).toInt()
            c.drawCircle(d.x / 1280f * w, d.y / 720f * h, d.r * u, fill)
        }
        fill.alpha = 255
        drawTubby(c, card.mood)
        drawText(c)
    }

    private fun drawText(c: Canvas) {
        val g = 18f * u
        var y = textTop
        c.drawText(KICKER, textLeft, y - kickerPaint.fontMetrics.ascent, kickerPaint)
        y += kickerH + g
        head?.let { c.save(); c.translate(textLeft, y); it.draw(c); c.restore(); y += it.height }
        sub?.let { y += g; c.save(); c.translate(textLeft, y); it.draw(c); c.restore(); y += it.height }
        y += g + 8f * u
        // Footer: shield (24-unit icon drawn at 26) + 14 gap + text, centred on one line.
        val icon = 26f * u
        c.save()
        c.translate(textLeft, y + (footH - icon) / 2f)
        c.scale(icon / 24f, icon / 24f)
        stroke.color = MINT
        stroke.strokeWidth = 2.2f
        c.drawPath(SHIELD, stroke)
        c.restore()
        val fm = footPaint.fontMetrics
        val base = y + footH / 2f - (fm.ascent + fm.descent) / 2f
        c.drawText(footText, 0, footText.length, textLeft + icon + 14f * u, base, footPaint)
    }

    private fun drawTubby(c: Canvas, mood: CardMood) {
        val k = tubbyScale
        c.save()
        c.translate(tubbyLeft, tubbyTop)
        c.scale(k, k)
        // Antennae and legs in cream: they must read on the navy background.
        stroke.color = CREAM
        stroke.strokeWidth = 5f
        c.drawLine(44f, 14f, 34f, 2f, stroke)
        c.drawLine(76f, 14f, 86f, 2f, stroke)
        fill.color = when (mood) {
            CardMood.asleep -> SUNFLOWER
            CardMood.calm -> SKY
            CardMood.guard -> MINT
        }
        c.drawRoundRect(BODY, 26f, 26f, fill)
        fill.color = if (mood == CardMood.asleep) SCREEN_NIGHT else CREAM
        c.drawRoundRect(SCREEN, 18f, 18f, fill)
        when (mood) {
            CardMood.asleep -> {
                stroke.color = CREAM
                stroke.strokeWidth = 4.5f
                c.drawPath(SLEEP_EYES, stroke)
                stroke.strokeWidth = 4f
                c.drawPath(SLEEP_MOUTH, stroke)
            }
            CardMood.calm -> {
                eyes(c)
                stroke.color = INK
                stroke.strokeWidth = 5f
                c.drawPath(SMILE, stroke)
                fill.color = CORAL
                fill.alpha = (0.55f * 255).toInt()
                c.drawCircle(33f, 64f, 5f, fill)
                c.drawCircle(87f, 64f, 5f, fill)
                fill.alpha = 255
            }
            CardMood.guard -> {
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
        }
        fill.color = CREAM
        c.drawRoundRect(LEG_L, 4f, 4f, fill)
        c.drawRoundRect(LEG_R, 4f, 4f, fill)
        c.restore()
        if (mood == CardMood.asleep) {
            // The "z z", drawn unscaled so the glyphs rasterise at their real size.
            zPaint.textSize = 14f * k
            c.drawText("z", tubbyLeft + 88f * k, tubbyTop + 42f * k, zPaint)
            zPaint.textSize = 10f * k
            c.drawText("z", tubbyLeft + 96f * k, tubbyTop + 33f * k, zPaint)
        }
    }

    private fun eyes(c: Canvas) {
        fill.color = INK
        c.drawCircle(45f, 50f, 6f, fill)
        c.drawCircle(75f, 50f, 6f, fill)
    }

    private class Dot(val x: Float, val y: Float, val r: Float, val color: Int, val alpha: Float)

    companion object {
        const val KICKER = "TUBBY SAYS"
        const val FOOTER = "Set by your family with boretube"

        private val NAVY_LIGHT = Color.parseColor("#2D2F66")
        private val NAVY_DARK = Color.parseColor("#15162E")
        private val CREAM = Color.parseColor("#FFF8F1")
        private val SUNFLOWER_SOFT = Color.parseColor("#FFD27A")
        private val SUNFLOWER = Color.parseColor("#FFB020")
        private val SKY = Color.parseColor("#3A8DFF")
        private val MINT = Color.parseColor("#1FBF8F")
        private val CORAL = Color.parseColor("#FF6B4A")
        private val INK = Color.parseColor("#1C1D3A")
        private val SCREEN_NIGHT = Color.parseColor("#2A2B4D")
        private val LAVENDER = Color.parseColor("#D8D9F2")
        private val MUTED = Color.parseColor("#A9AACB")

        /** Mock positions (centres, 1280×720 space): the four from the mock plus four sparser ones. */
        private val DOTS = listOf(
            Dot(145f, 115f, 5f, SUNFLOWER_SOFT, 1f),
            Dot(263f, 73f, 3f, CREAM, 0.7f),
            Dot(1096f, 134f, 4f, CREAM, 0.6f),
            Dot(957f, 597f, 3f, SUNFLOWER_SOFT, 0.8f),
            Dot(1185f, 430f, 3f, CREAM, 0.35f),
            Dot(92f, 565f, 4f, SUNFLOWER_SOFT, 0.5f),
            Dot(640f, 52f, 2.5f, CREAM, 0.45f),
            Dot(430f, 668f, 3f, CREAM, 0.4f),
        )

        // Tubby, viewBox 0 0 120 110.
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
        /** M96 60 l14 5 v10 c0 8-6 13-14 15-8-2-14-7-14-15 V65z */
        private val GUARD_SHIELD = Path().apply {
            moveTo(96f, 60f); lineTo(110f, 65f); lineTo(110f, 75f)
            cubicTo(110f, 83f, 104f, 88f, 96f, 90f)
            cubicTo(88f, 88f, 82f, 83f, 82f, 75f)
            lineTo(82f, 65f); close()
        }
        /** M90 76 l4 4 8-8 */
        private val GUARD_CHECK = Path().apply { moveTo(90f, 76f); lineTo(94f, 80f); lineTo(102f, 72f) }
        /** Footer icon, viewBox 24: M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z */
        private val SHIELD = Path().apply {
            moveTo(12f, 3f); lineTo(20f, 6f); lineTo(20f, 12f)
            cubicTo(20f, 17f, 16.5f, 20f, 12f, 21f)
            cubicTo(7.5f, 20f, 4f, 17f, 4f, 12f)
            lineTo(4f, 6f); close()
        }

        @Volatile private var headlineFace: Typeface? = null

        /** Bricolage Grotesque ExtraBold (the variable font's default instance is wght 800, opsz 96). Loaded once. */
        fun headline(ctx: Context): Typeface {
            headlineFace?.let { return it }
            val f = try {
                Typeface.Builder(ctx.assets, "fonts/BricolageGrotesque-Variable.ttf")
                    .setFontVariationSettings("'wght' 800, 'opsz' 96")
                    .build()
            } catch (_: Exception) {
                null
            } ?: Typeface.create("sans-serif-black", Typeface.NORMAL)
            headlineFace = f
            return f
        }
    }
}
