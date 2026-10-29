package com.rakesh.boretube.agent.android

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.graphics.Typeface
import android.os.SystemClock
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import android.view.KeyEvent
import android.view.View
import android.view.animation.DecelerateInterpolator
import com.rakesh.boretube.learn.core.Question
import com.rakesh.boretube.learn.core.QuizScreen
import com.rakesh.boretube.learn.core.Visual
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.sin

/**
 * The brain-break quiz, drawn natively (design/Brain Break mocks, 1280×720
 * units scaled to the window, content inside the 5% TV-safe margin). The
 * remote drives it: ◀ ▶ move between answer tiles, OK picks or continues, ▲
 * reads the question again. Back and media keys are swallowed; volume keys
 * pass through. No red anywhere: a miss is a sunflower "learn it" moment.
 */
class QuizView(
    ctx: Context,
    /** en | hi | enHi */
    private val lang: String,
    private val voiceHint: Boolean,
    private val listener: Listener,
) : View(ctx) {

    interface Listener {
        fun onPick(choice: Int, ms: Long)
        fun onNext()
        fun onReplay()
    }

    private var screen: QuizScreen? = null
    /** Main-question outcomes so far (for the progress pills). */
    private var marks: List<Boolean> = emptyList()
    private var focus = 0
    private var shownAt = 0L
    /** Done screen: seconds until the video starts by itself. */
    var countdown = 0
        set(v) { field = v; invalidate() }

    private var focusT = 1f
    private var fadeT = 1f
    private val focusAnim = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 120
        interpolator = DecelerateInterpolator()
        addUpdateListener { focusT = it.animatedValue as Float; invalidate() }
    }
    private val fadeAnim = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 200
        interpolator = DecelerateInterpolator()
        addUpdateListener { fadeT = it.animatedValue as Float; invalidate() }
    }

    private val tubby = Tubby()
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeCap = Paint.Cap.ROUND
        strokeJoin = Paint.Join.ROUND
    }
    private val display = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { typeface = TvCardView.headline(ctx) }
    private val body = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Typeface.create("sans-serif", Typeface.NORMAL) }
    private val medium = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL) }

    // Design-space → pixels.
    private var u = 1f
    private var ox = 0f
    private var oy = 0f
    private fun x(v: Float) = ox + v * u
    private fun y(v: Float) = oy + v * u
    private fun s(v: Float) = v * u

    init {
        isFocusable = true
        isFocusableInTouchMode = true
    }

    fun show(next: QuizScreen, outcomes: List<Boolean>) {
        screen = next
        marks = outcomes
        focus = 0
        shownAt = SystemClock.uptimeMillis()
        focusT = 1f
        fadeAnim.start()
        invalidate()
    }

    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) {
        u = min(w / 1280f, h / 720f)
        ox = (w - 1280f * u) / 2f
        oy = (h - 720f * u) / 2f
    }

    // ── keys ──

    override fun dispatchKeyEvent(e: KeyEvent): Boolean {
        when (e.keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN, KeyEvent.KEYCODE_VOLUME_MUTE ->
                return super.dispatchKeyEvent(e)
        }
        if (e.action != KeyEvent.ACTION_DOWN) return true
        val sc = screen ?: return true
        val now = SystemClock.uptimeMillis()
        when (e.keyCode) {
            KeyEvent.KEYCODE_DPAD_LEFT -> moveFocus(-1)
            KeyEvent.KEYCODE_DPAD_RIGHT -> moveFocus(1)
            KeyEvent.KEYCODE_DPAD_UP -> if (e.repeatCount == 0) listener.onReplay()
            KeyEvent.KEYCODE_DPAD_CENTER, KeyEvent.KEYCODE_ENTER, KeyEvent.KEYCODE_NUMPAD_ENTER,
            KeyEvent.KEYCODE_BUTTON_A, KeyEvent.KEYCODE_SPACE -> {
                // A held or carried-over OK must not answer the next screen.
                if (e.repeatCount > 0 || now - shownAt < INPUT_GRACE_MS) return true
                if (sc is QuizScreen.Ask) listener.onPick(focus, now - shownAt) else listener.onNext()
            }
            // Everything else (Back, media keys, digits, …) is swallowed.
        }
        return true
    }

    private fun moveFocus(d: Int) {
        val a = screen as? QuizScreen.Ask ?: return
        val f = (focus + d).coerceIn(0, a.q.options.lastIndex)
        if (f == focus) return
        focus = f
        focusAnim.start()
    }

    // ── drawing ──

    override fun onDraw(c: Canvas) {
        if (width == 0 || height == 0) return
        fill.color = NAVY
        c.drawRect(0f, 0f, width.toFloat(), height.toFloat(), fill)
        val sc = screen ?: return
        val layer = if (fadeT < 1f) c.saveLayerAlpha(0f, 0f, width.toFloat(), height.toFloat(), (fadeT * 255).toInt()) else -1
        when (sc) {
            is QuizScreen.Ask -> drawAsk(c, sc)
            is QuizScreen.Right -> drawRight(c, sc)
            is QuizScreen.Learn -> drawLearn(c, sc)
            is QuizScreen.Done -> drawDone(c, sc)
        }
        if (layer >= 0) c.restoreToCount(layer)
    }

    private fun prompt(q: Question) = if (lang == "hi") q.promptHi ?: q.prompt else q.prompt
    private fun hindiLine(q: Question) = if (lang == "enHi") q.promptHi?.takeIf { it != q.prompt } else null

    /** Header: small Tubby + title on the left; progress pills on the right (Ask/Right). */
    private fun header(c: Canvas, title: String, mood: TubbyMood, index: Int?, of: Int?, current: Boolean?) {
        tubby.draw(c, mood, x(89f), y(55f), s(55f))
        display.textSize = s(34f)
        display.color = CREAM
        baseline(c, title, x(89f + 55f + 21f), y(55f + 27f), display)
        if (index == null || of == null) return
        body.textSize = s(21f)
        body.color = MUTED
        val label = "${index + 1} of $of"
        val lw = body.measureText(label)
        var right = x(1280f - 89f)
        baseline(c, label, right - lw, y(82f), body)
        right -= lw + s(21f)
        for (i in of - 1 downTo 0) {
            val wide = i == index
            val w = s(if (wide) 34f else 13f)
            fill.color = when {
                i < index -> if (marks.getOrNull(i) == true) MINT else SUNFLOWER
                i == index -> when (current) { true -> MINT; else -> CORAL }
                else -> PILL
            }
            c.drawRoundRect(RectF(right - w, y(76f), right, y(89f)), s(8f), s(8f), fill)
            right -= w + s(13f)
        }
    }

    private fun drawAsk(c: Canvas, a: QuizScreen.Ask) {
        val q = a.q
        header(c, if (a.followUp) "Now try this one" else "Quick brain break!", TubbyMood.calm, a.index, a.of, null)
        val pies = q.visual is Visual.Pies
        val tileH = if (pies) 233f else 144f
        val tilesTop = 610f - tileH
        // The question, centred in the band between the header and the tiles.
        val bandTop = 130f
        val bandBottom = tilesTop - 34f
        val hi = hindiLine(q)
        when (val v = q.visual) {
            is Visual.Objects -> {
                val promptSize = fit(prompt(q), display, 55f, 1100f)
                display.textSize = s(promptSize)
                display.color = CREAM
                val pw = display.measureText(prompt(q))
                var hw = 0f
                if (hi != null) { medium.textSize = s(34f); hw = medium.measureText(hi) + s(34f) }
                val left = (1280f * u - pw - hw) / 2f + ox
                baseline(c, prompt(q), left, y(bandTop + 40f), display)
                if (hi != null) { medium.color = MUTED; baseline(c, hi, left + pw + s(34f), y(bandTop + 40f), medium) }
                drawMangoes(c, v.count, 640f, (bandTop + 80f + bandBottom) / 2f, bandBottom - bandTop - 90f)
            }
            is Visual.Clock -> {
                display.textSize = s(fit(prompt(q), display, 55f, 700f))
                display.color = CREAM
                baseline(c, prompt(q), x(89f), y(bandTop + 90f), display)
                if (hi != null) { medium.textSize = s(34f); medium.color = MUTED; baseline(c, hi, x(89f), y(bandTop + 150f), medium) }
                val r = ((bandBottom - bandTop) / 2f - 8f).coerceAtMost(130f)
                drawClock(c, v.hour, v.minute, 1280f - 89f - r - 40f, (bandTop + bandBottom) / 2f, r)
            }
            is Visual.Pies -> {
                display.textSize = s(fit(prompt(q), display, 55f, 1100f))
                display.color = CREAM
                baseline(c, prompt(q), x(89f), y(bandTop + 100f), display)
                val sub = if (hi != null) medium else body
                sub.textSize = s(26f)
                sub.color = MUTED
                baseline(c, hi ?: "Same-size pizzas. Pick the bigger share.", x(89f), y(bandTop + 150f), sub)
            }
            else -> {
                val p = prompt(q)
                val size = fit(p, display, 144f, 1100f, min = 43f)
                display.textSize = s(size)
                display.color = CREAM
                val big = size >= 89f
                val cy = (bandTop + bandBottom) / 2f + if (big) 40f else 10f
                centered(c, p, 640f, cy, display)
                if (hi != null) { medium.textSize = s(34f); medium.color = MUTED; centered(c, hi, 640f, cy + (if (big) 70f else 55f), medium) }
            }
        }
        tiles(c, q, tilesTop, tileH) { i -> if (i == focus) TileStyle.Focus else TileStyle.Normal }
        // Remote hint.
        body.textSize = s(21f)
        body.color = MUTED
        val hy = y(665f)
        chevron(c, x(89f), hy, pointLeft = true)
        chevron(c, x(89f + 34f), hy, pointLeft = false)
        baseline(c, "to move · OK to choose", x(89f + 68f), hy + s(7f), body)
        if (voiceHint) {
            val t = "▲ hear it again"
            baseline(c, t, x(1280f - 89f) - body.measureText(t), hy + s(7f), body)
        }
    }

    private fun drawRight(c: Canvas, r: QuizScreen.Right) {
        header(c, "Quick brain break!", TubbyMood.calm, r.index, r.of, true)
        val q = r.q
        val tw = 200f
        display.textSize = s(55f)
        val factSize = fit(q.fact, display, 55f, 640f)
        display.textSize = s(factSize)
        val colW = maxOf(display.measureText(q.fact) / u, 300f)
        val groupW = tw + 55f + colW
        val left = 640f - groupW / 2f
        val cy = 300f
        tubby.draw(c, TubbyMood.cheer, x(left), y(cy - Tubby.heightFor(tw) / 2f), s(tw))
        val tx = x(left + tw + 55f)
        display.textSize = s(89f)
        display.color = CREAM
        baseline(c, "Yes!", tx, y(cy - 30f), display)
        display.textSize = s(factSize)
        baseline(c, q.fact, tx, y(cy + 45f), display)
        body.textSize = s(26f)
        body.color = MUTED
        baseline(c, if (r.index + 1 < r.of) "Next one coming…" else "That was the last one!", tx, y(cy + 95f), body)
        val tileH = if (q.visual is Visual.Pies) 233f else 144f
        tiles(c, q, 610f - tileH, tileH) { i -> if (i == q.answer) TileStyle.Right else TileStyle.Dim }
    }

    private fun drawLearn(c: Canvas, l: QuizScreen.Learn) {
        val q = l.q
        header(c, "Almost! Let's learn this one.", TubbyMood.think, null, null, null)
        val colL = 89f
        val colW = (1280f - 2 * 89f) * 0.618f - 34f
        // The fact, with the answer in sunflower.
        val fact = q.fact
        display.textSize = s(fit(fact, display, 89f, colW))
        val ans = q.answerText
        var fx = x(colL)
        val fy = y(250f)
        display.color = CREAM
        if (fact.endsWith(ans)) {
            val head = fact.removeSuffix(ans)
            baseline(c, head, fx, fy, display)
            fx += display.measureText(head)
            display.color = SUNFLOWER
            baseline(c, ans, fx, fy, display)
        } else {
            display.color = SUNFLOWER
            baseline(c, fact, fx, fy, display)
        }
        // "You picked 54" with the pick struck through.
        body.textSize = s(26f)
        body.color = MUTED
        val lead = "You picked "
        baseline(c, lead, x(colL), y(305f), body)
        val pick = q.options.getOrNull(l.picked) ?: ""
        body.isStrikeThruText = true
        baseline(c, pick, x(colL) + body.measureText(lead), y(305f), body)
        body.isStrikeThruText = false
        // The one-line why.
        medium.textSize = s(34f)
        medium.color = CREAM
        val why = StaticLayout.Builder.obtain(q.explain, 0, q.explain.length, medium, s(colW).toInt())
            .setAlignment(Layout.Alignment.ALIGN_NORMAL).setLineSpacing(0f, 1.25f).setIncludePad(false).setMaxLines(3).build()
        c.save(); c.translate(x(colL), y(345f)); why.draw(c); c.restore()
        // The picture.
        val rx = colL + colW + 55f
        val rw = 1280f - 89f - rx
        val cx = rx + rw / 2f
        when (val v = q.learnVisual) {
            is Visual.Dots -> drawDots(c, v, rx, 170f, rw, 300f)
            is Visual.Objects -> drawMangoes(c, v.count, cx, 320f, 260f, maxWidth = rw, numbered = true)
            is Visual.Pies -> drawPies(c, v, rx, 200f, rw)
            is Visual.Clock -> drawClock(c, v.hour, v.minute, cx, 320f, 140f)
            // Brain breaks are maths only; banks' pictures live in boretube Learn.
            is Visual.Picture, null -> tubby.draw(c, TubbyMood.think, x(cx - 110f), y(200f), s(220f))
        }
        // Footer: the promise that it comes back, and Got it.
        body.textSize = s(21f)
        body.color = MUTED
        baseline(c, "We'll ask this one again soon.", x(89f), y(640f), body)
        button(c, "Got it", 1280f - 89f, 576f, play = false)
    }

    private fun drawDone(c: Canvas, d: QuizScreen.Done) {
        val colW = (1280f - 2 * 89f) * 0.382f
        val cx = 89f + colW / 2f
        tubby.draw(c, TubbyMood.cheer, x(cx - 130f), y(150f), s(260f))
        display.textSize = s(55f)
        display.color = CREAM
        val title = StaticLayout.Builder.obtain(DONE_TITLE, 0, DONE_TITLE.length, display, s(colW).toInt())
            .setAlignment(Layout.Alignment.ALIGN_CENTER).setLineSpacing(0f, 1.05f).setIncludePad(false).build()
        c.save(); c.translate(x(89f), y(150f + Tubby.heightFor(260f) + 34f)); title.draw(c); c.restore()

        val rx = 89f + colW + 89f
        val rw = 1280f - 89f - rx
        body.textSize = s(26f)
        body.color = MUTED
        baseline(c, summary(d.right, d.learned), x(rx), y(150f), body)
        var top = 190f
        for (row in d.rows.take(5)) {
            val rowH = 55f
            if (row.correct) tick(c, x(rx), y(top + 10f), s(34f), MINT) else star(c, x(rx), y(top + 10f), s(34f))
            display.textSize = s(fit(row.q.fact, display, 26f, rw - 300f))
            display.color = CREAM
            baseline(c, row.q.fact, x(rx + 55f), y(top + 36f), display)
            body.textSize = s(21f)
            body.color = if (row.correct) MINT else SUNFLOWER
            val tag = if (row.correct) "Right" else "Learned"
            baseline(c, tag, x(rx + rw) - body.measureText(tag), y(top + 35f), body)
            fill.color = HAIRLINE
            c.drawRect(x(rx), y(top + rowH - 1f), x(rx + rw), y(top + rowH), fill)
            top += rowH
        }
        val by = maxOf(top + 34f, 470f)
        val bw = button(c, "Back to your video", rx, by, play = true, alignLeft = true)
        if (countdown > 0) {
            body.textSize = s(21f)
            body.color = MUTED
            baseline(c, "Starts by itself in $countdown", x(rx + bw + 34f), y(by + 52f), body)
        }
    }

    private fun summary(right: Int, learned: Int): String {
        val r = "$right right"
        return when (learned) {
            0 -> "$r. Brilliant!"
            1 -> "$r, 1 new thing learned."
            else -> "$r, $learned new things learned."
        }
    }

    // ── pieces ──

    private enum class TileStyle { Normal, Focus, Right, Dim }

    private inline fun tiles(c: Canvas, q: Question, top: Float, h: Float, style: (Int) -> TileStyle) {
        val n = q.options.size
        val left = 89f + 13f
        val gap = 34f
        val w = (1280f - 2 * left - gap * (n - 1)) / n
        val pies = (q.visual as? Visual.Pies)?.fractions
        val pips = (q.visual as? Visual.Objects) != null
        for (i in 0 until n) {
            val st = style(i)
            val tx = left + i * (w + gap)
            val k = when (st) {
                TileStyle.Focus -> 1f + 0.06f * focusT
                TileStyle.Right -> 1.06f
                else -> 1f
            }
            val cxT = tx + w / 2f
            val cyT = top + h / 2f
            val r = RectF(x(cxT - w * k / 2f), y(cyT - h * k / 2f), x(cxT + w * k / 2f), y(cyT + h * k / 2f))
            val alpha = if (st == TileStyle.Dim) 77 else 255
            if (st == TileStyle.Focus) {
                fill.color = CORAL
                c.drawRoundRect(RectF(r.left - s(5f), r.top - s(5f), r.right + s(5f), r.bottom + s(5f)), s(26f), s(26f), fill)
            }
            fill.color = when (st) { TileStyle.Focus -> CREAM; TileStyle.Right -> MINT; else -> TILE }
            fill.alpha = alpha
            c.drawRoundRect(r, s(21f), s(21f), fill)
            fill.alpha = 255
            val ink = when (st) { TileStyle.Focus -> INK; TileStyle.Right -> MINT_INK; else -> CREAM }
            val label = q.options[i]
            val frac = pies?.firstOrNull { "${it.first}/${it.second}" == label }
            var labelY = cyT + 20f
            if (frac != null) {
                drawPie(c, cxT, top + 80f, 55f, frac.first, frac.second, alpha, onCream = st == TileStyle.Focus)
                labelY = top + h - 34f
            } else if (pies != null) {
                // "Same": an equals sign above the word.
                stroke.color = ink
                stroke.alpha = alpha
                stroke.strokeWidth = s(9f)
                c.drawLine(x(cxT - 30f), y(top + 66f), x(cxT + 30f), y(top + 66f), stroke)
                c.drawLine(x(cxT - 30f), y(top + 94f), x(cxT + 30f), y(top + 94f), stroke)
                stroke.alpha = 255
                labelY = top + h - 34f
            } else if (pips) {
                labelY = cyT + 4f
            }
            display.textSize = s(fit(label, display, if (pies != null) 43f else 55f, w - 26f))
            display.color = ink
            display.alpha = alpha
            val lw = display.measureText(label)
            val tickW = if (st == TileStyle.Right) s(48f) else 0f
            val lx = x(cxT) - (lw + tickW) / 2f
            if (st == TileStyle.Right) tick(c, lx, y(labelY - 38f), s(40f), MINT_INK)
            baseline(c, label, lx + tickW, y(labelY), display)
            display.alpha = 255
            if (pips) label.toIntOrNull()?.let { drawPips(c, it, cxT, cyT + 34f, alpha) }
        }
    }

    /** "OK"-style button; returns its width (design units). */
    private fun button(c: Canvas, text: String, edge: Float, top: Float, play: Boolean, alignLeft: Boolean = false): Float {
        display.textSize = s(34f)
        val iconW = if (play) 55f else 0f
        val w = 55f + iconW + display.measureText(text) / u + 55f
        val left = if (alignLeft) edge else edge - w
        val r = RectF(x(left), y(top), x(left + w), y(top + 89f))
        fill.color = CORAL
        c.drawRoundRect(RectF(r.left - s(5f), r.top - s(5f), r.right + s(5f), r.bottom + s(5f)), s(26f), s(26f), fill)
        fill.color = CREAM
        c.drawRoundRect(r, s(21f), s(21f), fill)
        if (play) {
            fill.color = INK
            val p = Path().apply {
                moveTo(x(left + 55f), y(top + 28f)); lineTo(x(left + 55f + 30f), y(top + 44.5f)); lineTo(x(left + 55f), y(top + 61f)); close()
            }
            c.drawPath(p, fill)
        }
        display.color = INK
        baseline(c, text, x(left + 55f + iconW), y(top + 57f), display)
        return w
    }

    private fun drawMangoes(c: Canvas, n: Int, cx: Float, cy: Float, maxH: Float, maxWidth: Float = 1100f, numbered: Boolean = false) {
        val perRow = if (n <= 5) n else (n + 1) / 2
        val rows = if (n <= 5) 1 else 2
        val gap = 21f
        val w = min(min(96f, (maxWidth - gap * (perRow - 1)) / perRow), (maxH - gap * (rows - 1)) / rows * 80f / 90f)
        val h = w * 90f / 80f
        var k = 0
        for (row in 0 until rows) {
            val inRow = if (row == 0) perRow else n - perRow
            val rowW = inRow * w + (inRow - 1) * gap
            val top = cy - (rows * h + (rows - 1) * gap) / 2f + row * (h + gap)
            for (i in 0 until inRow) {
                val left = cx - rowW / 2f + i * (w + gap)
                mango(c, left, top, w)
                k++
                if (numbered) {
                    body.textSize = s(21f)
                    body.color = INK
                    centered(c, "$k", left + w / 2f, top + h * 0.62f, body)
                }
            }
        }
    }

    private fun mango(c: Canvas, left: Float, top: Float, w: Float) {
        c.save()
        c.translate(x(left), y(top))
        val k = s(w) / 80f
        c.scale(k, k)
        fill.color = MINT
        c.drawPath(LEAF, fill)
        fill.color = SUNFLOWER
        c.drawPath(MANGO, fill)
        stroke.color = SUNFLOWER_SOFT
        stroke.strokeWidth = 5f
        c.drawPath(SHINE, stroke)
        c.restore()
    }

    private fun drawPips(c: Canvas, n: Int, cx: Float, top: Float, alpha: Int) {
        val d = 13f
        val gap = 6f
        val perRow = if (n <= 6) n else (n + 1) / 2
        fill.color = SUNFLOWER
        fill.alpha = alpha
        for (row in 0..1) {
            val inRow = if (row == 0) min(perRow, n) else n - perRow
            if (inRow <= 0) break
            val rw = inRow * d + (inRow - 1) * gap
            for (i in 0 until inRow) {
                c.drawCircle(x(cx - rw / 2f + i * (d + gap) + d / 2f), y(top + row * (d + gap) + d / 2f), s(d / 2f), fill)
            }
        }
        fill.alpha = 255
    }

    private fun drawDots(c: Canvas, v: Visual.Dots, left: Float, top: Float, w: Float, h: Float) {
        val cell = min(w / v.cols, h / v.rows).coerceAtMost(34f)
        val gw = cell * v.cols
        val gh = cell * v.rows
        val l = left + (w - gw) / 2f
        for (r in 0 until v.rows) for (col in 0 until v.cols) {
            fill.color = if (v.splitAt in 1..col) CORAL else SUNFLOWER
            c.drawCircle(x(l + col * cell + cell / 2f), y(top + r * cell + cell / 2f), s(cell * 0.36f), fill)
        }
        body.textSize = s(21f)
        body.color = MUTED
        val caption = when {
            v.splitAt > 0 && v.splitAt * 2 == v.cols -> "${v.rows} rows of ${v.cols} · two halves of ${v.rows * v.splitAt}"
            v.rows == 1 -> "${v.splitAt} and ${v.cols - v.splitAt} more"
            else -> "${v.rows} rows of ${v.cols}"
        }
        centered(c, caption, left + w / 2f, top + gh + 40f, body)
    }

    private fun drawPies(c: Canvas, v: Visual.Pies, left: Float, top: Float, w: Float) {
        val n = v.fractions.size
        val r = min(80f, (w - 34f * (n - 1)) / n / 2f)
        val total = n * 2 * r + (n - 1) * 34f
        var cx = left + (w - total) / 2f + r
        for ((a, b) in v.fractions) {
            drawPie(c, cx, top + r, r, a, b, 255, onCream = false)
            display.textSize = s(34f)
            display.color = CREAM
            centered(c, "$a/$b", cx, top + 2 * r + 55f, display)
            cx += 2 * r + 34f
        }
    }

    private fun drawPie(c: Canvas, cx: Float, cy: Float, r: Float, num: Int, den: Int, alpha: Int, onCream: Boolean) {
        val box = RectF(x(cx - r), y(cy - r), x(cx + r), y(cy + r))
        fill.color = if (onCream) PIE_EMPTY_ON_CREAM else PILL
        fill.alpha = alpha
        c.drawOval(box, fill)
        fill.color = CORAL
        fill.alpha = alpha
        c.drawArc(box, -90f, 360f * num / den, true, fill)
        fill.alpha = 255
        stroke.color = if (onCream) CREAM else NAVY
        stroke.alpha = alpha
        stroke.strokeWidth = s(3f)
        for (i in 0 until den) {
            val a = Math.toRadians(-90.0 + 360.0 * i / den)
            c.drawLine(x(cx), y(cy), x(cx + r * cos(a).toFloat()), y(cy + r * sin(a).toFloat()), stroke)
        }
        stroke.alpha = 255
    }

    private fun drawClock(c: Canvas, hour: Int, minute: Int, cx: Float, cy: Float, r: Float) {
        fill.color = CREAM
        c.drawCircle(x(cx), y(cy), s(r), fill)
        fill.color = INK
        // Hour dots, except at 12, 3, 6 and 9 where the numbers are.
        for (i in 0 until 12) {
            if (i % 3 == 0) continue
            val a = Math.toRadians(i * 30.0)
            c.drawCircle(x(cx + (r - 16f) * sin(a).toFloat()), y(cy - (r - 16f) * cos(a).toFloat()), s(3.5f), fill)
        }
        body.textSize = s(r * 0.2f)
        body.color = INK
        for (i in listOf(12, 3, 6, 9)) {
            val a = Math.toRadians(i * 30.0)
            centered(c, "$i", cx + (r - 44f) * sin(a).toFloat(), cy - (r - 44f) * cos(a).toFloat() + r * 0.07f, body)
        }
        val ha = Math.toRadians((hour % 12) * 30.0 + minute * 0.5)
        val ma = Math.toRadians(minute * 6.0)
        stroke.color = INK
        stroke.strokeWidth = s(10f)
        c.drawLine(x(cx), y(cy), x(cx + r * 0.5f * sin(ha).toFloat()), y(cy - r * 0.5f * cos(ha).toFloat()), stroke)
        stroke.color = CORAL
        stroke.strokeWidth = s(7f)
        c.drawLine(x(cx), y(cy), x(cx + r * 0.78f * sin(ma).toFloat()), y(cy - r * 0.78f * cos(ma).toFloat()), stroke)
        fill.color = INK
        c.drawCircle(x(cx), y(cy), s(8f), fill)
    }

    private fun tick(c: Canvas, left: Float, top: Float, size: Float, color: Int) {
        stroke.color = color
        stroke.strokeWidth = size * 3f / 24f
        val k = size / 24f
        val p = Path().apply { moveTo(left + 5f * k, top + 12.5f * k); lineTo(left + 9.5f * k, top + 17f * k); lineTo(left + 19f * k, top + 7.5f * k) }
        c.drawPath(p, stroke)
    }

    private fun star(c: Canvas, left: Float, top: Float, size: Float) {
        val k = size / 24f
        stroke.color = SUNFLOWER
        stroke.strokeWidth = 2.5f * k
        val pts = floatArrayOf(12f, 3f, 14.6f, 8.6f, 20.6f, 9.3f, 16.1f, 13.4f, 17.3f, 19.4f, 12f, 16.4f, 6.7f, 19.4f, 7.9f, 13.4f, 3.4f, 9.3f, 9.4f, 8.6f)
        val p = Path()
        for (i in pts.indices step 2) {
            val px = left + pts[i] * k
            val py = top + pts[i + 1] * k
            if (i == 0) p.moveTo(px, py) else p.lineTo(px, py)
        }
        p.close()
        c.drawPath(p, stroke)
    }

    /** A 24-unit ◀ or ▶ chevron with its left edge at [left] (pixels), centred on [cy]. */
    private fun chevron(c: Canvas, left: Float, cy: Float, pointLeft: Boolean) {
        stroke.color = MUTED
        stroke.strokeWidth = s(2.5f)
        val k = s(24f) / 24f
        val top = cy - 12f * k
        val p = if (pointLeft) Path().apply { moveTo(left + 15f * k, top + 6f * k); lineTo(left + 9f * k, top + 12f * k); lineTo(left + 15f * k, top + 18f * k) }
        else Path().apply { moveTo(left + 9f * k, top + 6f * k); lineTo(left + 15f * k, top + 12f * k); lineTo(left + 9f * k, top + 18f * k) }
        c.drawPath(p, stroke)
    }

    // ── text helpers ──

    /** The largest size ≤ [max] (design units, steps of 4) at which [t] fits [width]. */
    private fun fit(t: String, p: TextPaint, max: Float, width: Float, min: Float = 21f): Float {
        var size = max
        while (size > min) {
            p.textSize = s(size)
            if (p.measureText(t) <= s(width)) break
            size -= 4f
        }
        return size
    }

    /** Draws [t] with its baseline at [base] (pixels). */
    private fun baseline(c: Canvas, t: String, left: Float, base: Float, p: Paint) = c.drawText(t, left, base, p)

    /** Draws [t] centred on ([cx], [cy]) in design units (cy = the visual middle). */
    private fun centered(c: Canvas, t: String, cx: Float, cy: Float, p: Paint) {
        val fm = p.fontMetrics
        c.drawText(t, x(cx) - p.measureText(t) / 2f, y(cy) - (fm.ascent + fm.descent) / 2f, p)
    }

    companion object {
        const val DONE_TITLE = "Brain break done!"
        /** OK presses this soon after a screen appears are ignored (carry-over, held keys). */
        const val INPUT_GRACE_MS = 350L

        private val NAVY = Color.parseColor("#12132A")
        private val TILE = Color.parseColor("#23254A")
        private val PILL = Color.parseColor("#3A3C66")
        private val HAIRLINE = Color.parseColor("#2C2E55")
        private val CREAM = Color.parseColor("#FFF8F1")
        private val MUTED = Color.parseColor("#B9BAD6")
        private val INK = Color.parseColor("#1C1D3A")
        private val CORAL = Color.parseColor("#FF6B4A")
        private val MINT = Color.parseColor("#1FBF8F")
        private val MINT_INK = Color.parseColor("#0B2B22")
        private val SUNFLOWER = Color.parseColor("#FFB020")
        private val SUNFLOWER_SOFT = Color.parseColor("#FFD27A")
        private val PIE_EMPTY_ON_CREAM = Color.parseColor("#E6DCCB")

        // Mango, viewBox 0 0 80 90 (the mock's SVG).
        private val LEAF = Path().apply { moveTo(40f, 16f); cubicTo(40f, 8f, 46f, 4f, 54f, 4f); cubicTo(50f, 10f, 46f, 14f, 40f, 16f); close() }
        private val MANGO = Path().apply {
            moveTo(40f, 14f); cubicTo(62f, 14f, 74f, 34f, 72f, 54f); cubicTo(70f, 76f, 52f, 86f, 36f, 84f)
            cubicTo(18f, 82f, 8f, 66f, 10f, 48f); cubicTo(12f, 28f, 24f, 14f, 40f, 14f); close()
        }
        private val SHINE = Path().apply { moveTo(24f, 36f); cubicTo(28f, 28f, 34f, 24f, 40f, 24f) }
    }
}
