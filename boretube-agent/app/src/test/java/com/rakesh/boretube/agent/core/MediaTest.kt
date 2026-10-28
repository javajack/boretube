package com.rakesh.boretube.agent.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

private const val ST = "org.smarttube.stable"

private fun track(title: String, dur: Long? = null, pkg: String = ST) = MediaTrack(pkg, title, "Channel • 1M views", dur)

/** Drives a timeline + detector the way MediaGuard does, one sample per [stepMs]. */
private class Sim(val pkg: String = ST) {
    var t = 5_000_000L
    val tl = MediaTimeline()
    val det = ShortsDetector()
    val steps = mutableListOf<ShortsStep>()
    val active get() = steps.lastOrNull()?.active == true
    val everActive get() = steps.any { it.active }
    val counted get() = steps.sumOf { it.newShorts }

    fun feed(sample: MediaSample?) {
        val done = tl.update(sample, t)
        steps += det.step(tl.pkg, done, tl.current, tl.playClockMs)
    }

    /** Plays [title] for [ms]; [pos] starts at [from]. */
    fun play(title: String, ms: Long, dur: Long? = null, state: PlayState = PlayState.playing, from: Long = 0, stepMs: Long = 1_000) {
        var p = from
        var left = ms
        while (left > 0) {
            feed(MediaSample(pkg, track(title, dur, pkg), state, p, if (state == PlayState.playing) 1f else 0f, t))
            val s = minOf(stepMs, left)
            t += s
            if (state == PlayState.playing) p += s
            left -= s
        }
    }

    fun shorts(n: Int, secs: Long = 9, dur: Long? = null, prefix: String = "Short") {
        for (i in 1..n) {
            feed(MediaSample(pkg, track("$prefix $i", dur, pkg), PlayState.none, 0, 0f, t)); t += 300
            feed(MediaSample(pkg, track("$prefix $i", dur, pkg), PlayState.buffering, 0, 0f, t)); t += 300
            play("$prefix $i", secs * 1000, dur)
        }
    }
}

class MediaDumpTest {
    private val out = MediaDumpTest::class.java.classLoader!!.getResource("media_session_vu3.txt")!!.readText()

    @Test fun parsesTheVu3Dump() {
        val snap = MediaDump.parse(out, 99)
        assertEquals(MediaSource.dumpsys, snap.source)
        assertEquals(listOf(ST, "com.android.bluetooth", "com.android.bluetooth", "com.netflix.ninja"), snap.sessions.map { it.pkg })
        val st = snap.sessions[0]
        assertTrue(st.active)
        assertEquals(PlayState.paused, st.state)
        assertEquals(5526L, st.positionMs)
        assertEquals(0f, st.speed)
        assertEquals(4837213L, st.updatedElapsed)
        assertTrue(st.track!!.title.startsWith("Saamp wala ai tiktok #viral"))
        assertEquals("Synth Toon FX • 8.3M views • 1 month ago", st.track!!.artist)
        assertNull(st.track!!.durationMs)
        assertEquals(PlayState.error, snap.sessions[1].state)
        assertNull(snap.sessions[1].track)
        assertEquals(PlayState.none, snap.sessions[3].state)
        assertFalse(snap.sessions[3].active)
        assertEquals(st, snap.primary(ST))
        assertNull(snap.primary("com.android.tv.settings"))
        assertNull("paused session is not picked without a foreground", snap.primary(null))
    }

    @Test fun descriptionSplitsOnTheLastSeparator() {
        val t = MediaDump.trackFromDescription(ST, "Cats, dogs, and more, Pet Channel • 2M views, null")!!
        assertEquals("Cats, dogs, and more", t.title)
        assertEquals("Pet Channel • 2M views", t.artist)
        assertNull(MediaDump.trackFromDescription(ST, "null, null, null"))
        assertEquals("Solo", MediaDump.trackFromDescription(ST, "Solo")!!.title)
    }

    @Test fun androidStateCodes() {
        assertEquals(PlayState.none, PlayState.fromAndroid(0))
        assertEquals(PlayState.stopped, PlayState.fromAndroid(1))
        assertEquals(PlayState.paused, PlayState.fromAndroid(2))
        assertEquals(PlayState.playing, PlayState.fromAndroid(3))
        assertEquals(PlayState.buffering, PlayState.fromAndroid(6))
        assertEquals(PlayState.error, PlayState.fromAndroid(7))
        assertEquals(PlayState.playing, PlayState.fromDumpName("PLAYING"))
    }
}

class MediaTimelineTest {
    @Test fun livePositionFollowsTheAndroidModel() {
        val s = MediaSample(ST, track("A", 60_000), PlayState.playing, positionMs = 5_000, speed = 1f, updatedElapsed = 1_000)
        assertEquals(8_000, s.livePositionMs(4_000))
        assertEquals(52_000L, s.remainingMs(4_000))
        assertEquals(11_000, s.copy(speed = 2f).livePositionMs(4_000))
        assertEquals(5_000, s.copy(state = PlayState.paused).livePositionMs(4_000))
        assertEquals(5_000, s.livePositionMs(500)) // clock before `updated`: no negative step
        assertEquals(60_000, s.livePositionMs(500_000)) // clamped to the duration
        assertEquals(0L, s.remainingMs(500_000))
        assertNull(s.copy(track = track("A")).remainingMs(4_000))
        assertEquals(5_000L + 499_000, s.copy(track = track("A")).livePositionMs(500_000))
    }

    @Test fun trackChangesAndPlayClock() {
        val tl = MediaTimeline()
        fun smp(title: String?, state: PlayState = PlayState.playing) =
            MediaSample(ST, title?.let { track(it) }, state, 0, 1f, 0)
        assertNull(tl.update(smp("A"), 0))
        assertNull(tl.update(smp("A"), 1_000))
        assertNull(tl.update(smp("A", PlayState.paused), 2_000))
        assertNull(tl.update(smp("A", PlayState.paused), 60_000)) // paused: no play time
        assertEquals(2_000, tl.playClockMs)
        assertNull(tl.update(smp(null, PlayState.none), 61_000)) // between titles: keeps A
        assertEquals("A", tl.current!!.track.title)
        val done = tl.update(smp("B"), 62_000)!!
        assertEquals("A", done.track.title)
        assertTrue(done.finished)
        assertEquals(2_000, done.playedMs)
        assertEquals(2_000, tl.current!!.startPlayMs)
        tl.update(smp("B"), 63_000)
        tl.update(smp("B"), 400_000) // a long gap (agent asleep) counts at most 10 s
        assertEquals(2_000 + 1_000 + 10_000, tl.playClockMs)
        // Another package: reset.
        val other = tl.update(MediaSample("com.netflix.ninja", track("N", pkg = "com.netflix.ninja"), PlayState.playing), 401_000)
        assertNull(other)
        assertEquals("com.netflix.ninja", tl.pkg)
        assertEquals(0, tl.playClockMs)
        assertEquals("N", tl.update(null, 402_000)!!.track.title) // none: finishes the current track
        assertNull(tl.pkg)
    }
}

class ShortsDetectorTest {
    @Test fun shortsRhythmIsDetected() {
        val s = Sim()
        s.shorts(2)
        assertFalse(s.everActive)
        s.shorts(1, prefix = "More")
        assertTrue(s.active)
        assertEquals(1, s.steps.count { it.started })
        assertEquals(3, s.counted)
        s.shorts(4, prefix = "Again")
        assertTrue(s.active)
        assertEquals(1, s.steps.count { it.started })
        assertEquals(7, s.counted)
    }

    @Test fun normalVideoNeverTriggers() {
        val s = Sim()
        s.play("Long documentary", 20 * 60_000L)
        assertFalse(s.everActive)
        assertEquals(0, s.counted)
    }

    @Test fun oneShortishVideoThenNormalNeverTriggers() {
        val s = Sim()
        s.play("Trailer", 60_000)
        s.play("Movie review", 15 * 60_000L)
        s.play("Another short-ish clip", 50_000)
        s.play("Lecture", 10 * 60_000L)
        assertFalse(s.everActive)
    }

    @Test fun seekingIsNotANewTitle() {
        val s = Sim()
        s.play("Cartoon", 20_000)
        s.play("Cartoon", 20_000, from = 300_000) // seek forward
        s.play("Cartoon", 20_000, from = 10_000) // seek back
        s.play("Cartoon", 20_000, from = 0) // restart
        assertFalse(s.everActive)
        assertEquals(1, s.tl.current!!.seq)
    }

    @Test fun pausedTimeDoesNotCount() {
        // A Short paused for 5 minutes is still a short (9 s played).
        val s = Sim()
        s.shorts(1)
        s.play("Short 1", 5 * 60_000L, state = PlayState.paused, from = 9_000)
        s.shorts(2, prefix = "Next")
        assertTrue(s.active)
        // A normal video watched 2 min around a pause is long: no session after it.
        val n = Sim()
        n.play("Normal", 60_000)
        n.play("Normal", 10 * 60_000L, state = PlayState.paused, from = 60_000)
        n.play("Normal", 60_000, from = 60_000)
        n.shorts(2)
        assertFalse(n.everActive)
    }

    @Test fun flashingTitlesAreIgnored() {
        val s = Sim()
        for (i in 1..6) s.play("Flash $i", 500, stepMs = 250)
        s.play("Real video", 3 * 60_000L)
        assertFalse(s.everActive)
    }

    @Test fun durationKnownPath() {
        // Known short durations count right away, even when a short loops past 90 s.
        val s = Sim()
        s.shorts(2, dur = 30_000)
        s.play("Looping short", 100_000, dur = 45_000)
        assertTrue(s.active)
        // Known long videos skipped quickly are not Shorts, but they ARE video
        // hopping (the behaviour the user asked to catch, 2026-10-29).
        val n = Sim()
        n.shorts(5, secs = 15, dur = 12 * 60_000L)
        assertTrue(n.everActive)
        assertEquals("hopping", n.steps.last { it.active }.kind)
        // A normal long-ish video (2.5 min known) after one short: no session.
        val m = Sim()
        m.shorts(1, dur = 20_000)
        m.play("Music video", 150_000, dur = 150_000)
        assertFalse(m.everActive)
    }

    @Test fun longVideoEndsTheSession() {
        val s = Sim()
        s.shorts(4)
        assertTrue(s.active)
        s.play("Full episode", 95_000)
        assertFalse(s.active)
    }

    @Test fun otherAppsAreNotWatched() {
        val s = Sim("com.netflix.ninja")
        s.shorts(6)
        assertFalse(s.everActive)
    }
}

class ShortsCountTest {
    @Test fun budgetCountsAndResetsAtMidnight() {
        var c = ShortsCount()
        c = c.add("2026-10-29", 3, 100)
        c = c.add("2026-10-29", 0, 200)
        assertEquals(3, c.count)
        assertEquals(100L, c.lastDetectedAt)
        assertFalse(c.overBudget("2026-10-29", 3))
        c = c.add("2026-10-29", 1, 300)
        assertTrue(c.overBudget("2026-10-29", 3))
        assertFalse("new local day", c.overBudget("2026-10-30", 3))
        val next = c.forDay("2026-10-30")
        assertEquals(0, next.count)
        assertEquals(300L, next.lastDetectedAt)
        assertEquals(1, c.add("2026-10-30", 1, 400).count)
    }
}

class EndAfterTest {
    private val now = 1_800_000_000_000L
    private fun smp(title: String = "Episode 1", state: PlayState = PlayState.playing, pos: Long = 10_000, dur: Long? = null, at: Long = 1_000) =
        MediaSample(ST, track(title, dur), state, pos, 1f, at)

    private fun armed(dur: Long? = null, capMin: Int? = null): EndAfterState =
        EndAfter.arm(smp(dur = dur), now, capMin, null).first!!

    @Test fun armNeedsAVideo() {
        assertNull(EndAfter.arm(null, now, null, null).first)
        assertNull(EndAfter.arm(MediaSample(ST, null, PlayState.playing), now, null, null).first)
        assertNull(EndAfter.arm(smp(state = PlayState.stopped), now, null, null).first)
        val s = armed()
        assertTrue(s.armed)
        assertEquals(now + 45 * 60_000L, s.capAt)
        assertEquals(60, s.breakMin)
        assertEquals("Episode 1", s.title)
        assertEquals(now + 10 * 60_000L, EndAfter.arm(smp(), now, 10, 30).first!!.capAt)
        assertEquals(30, EndAfter.arm(smp(), now, 10, 30).first!!.breakMin)
    }

    @Test fun titleChangeTriggers() {
        val w = EndAfterWatcher()
        val s = armed()
        assertNull(w.check(s, smp(), 2_000, now + 1_000))
        assertNull("seek is not a new video", w.check(s, smp(pos = 500_000), 3_000, now + 2_000))
        assertNull("pause is not an end", w.check(s, smp(state = PlayState.paused), 4_000, now + 3_000))
        assertEquals("nextVideo", w.check(s, smp("Episode 2"), 5_000, now + 4_000))
    }

    @Test fun stopTriggers() {
        val w = EndAfterWatcher()
        val s = armed()
        assertEquals("stopped", w.check(s, smp(state = PlayState.stopped), 2_000, now))
        assertEquals("stopped", w.check(s, smp(state = PlayState.error), 2_000, now))
        // NONE is debounced (SmartTube passes through NONE between items).
        assertNull(w.check(s, smp(state = PlayState.none), 2_000, now))
        assertNull(w.check(s, smp(state = PlayState.none), 4_000, now))
        assertNull(w.check(s, smp(state = PlayState.buffering), 4_500, now))
        assertNull(w.check(s, smp(state = PlayState.none), 5_000, now))
        assertEquals("stopped", w.check(s, smp(state = PlayState.none), 8_000, now))
        // Session gone for 5 s.
        w.clear()
        assertNull(w.check(s, null, 10_000, now))
        assertNull(w.check(s, null, 14_000, now))
        assertEquals("stopped", w.check(s, null, 15_000, now))
    }

    @Test fun nearEndTriggersWhenDurationKnown() {
        val w = EndAfterWatcher()
        val s = armed(dur = 60_000)
        assertNull(w.check(s, smp(pos = 50_000, dur = 60_000, at = 1_000), 1_000, now))
        assertNull(w.check(s, smp(pos = 50_000, dur = 60_000, at = 1_000), 7_000, now)) // live 56 s
        assertEquals("ended", w.check(s, smp(pos = 50_000, dur = 60_000, at = 1_000), 9_000, now)) // live 58 s
        // Unknown duration: never "ended", only the other triggers.
        val u = armed()
        assertNull(w.check(u, smp(pos = 10_000_000), 9_000, now))
    }

    @Test fun capTriggers() {
        val w = EndAfterWatcher()
        val s = armed(capMin = 1)
        assertNull(w.check(s, smp(), 1_000, now + 59_000))
        assertEquals("cap", w.check(s, smp(), 1_000, now + 60_000))
        assertNull(w.check(EndAfterState(), smp(), 1_000, now + 60_000))
    }
}

class MediaGuardTest {
    private val today = "2026-10-29"
    private var t = 9_000_000L
    private var wall = 1_800_000_000_000L

    private fun snap(title: String?, state: PlayState = PlayState.playing, dur: Long? = null, pos: Long = 0, source: MediaSource = MediaSource.dumpsys) =
        MediaSnapshot(source, listOf(MediaSample(ST, title?.let { track(it, dur) }, state, pos, 1f, t)))

    /** Feeds [title] for [secs] seconds; returns all outcomes. */
    private fun run(g: MediaGuard, rules: Rules, title: String?, secs: Int, enforce: Boolean = true, state: PlayState = PlayState.playing): List<MediaOutcome> =
        (1..secs).map {
            g.step(snap(title, state), ST, t, wall, today, rules, enforce).also { t += 1_000; wall += 1_000 }
        }

    private fun shorts(g: MediaGuard, rules: Rules, n: Int, enforce: Boolean = true, prefix: String = "S") =
        (1..n).flatMap { run(g, rules, "$prefix $it", 9, enforce) }

    private fun rules(mode: String, perDay: Int = 0, style: String = "explicit") =
        Rules(style = style, shorts = ShortsRules(mode, perDay))

    @Test fun blockClosesWithTheExplicitCard() {
        val g = MediaGuard()
        val out = shorts(g, rules("block"), 3)
        val closes = out.mapNotNull { it.close }
        assertEquals(1, closes.size)
        assertEquals(ST, closes[0].pkg)
        assertEquals("shortsBlock", closes[0].reason)
        assertTrue(closes[0].forceStop)
        assertEquals(MediaGuard.BLOCK_TITLE, closes[0].card!!.message)
        assertEquals("Pick a full video instead.", closes[0].card!!.sub)
        assertEquals(listOf("shorts", "shorts"), out.flatMap { it.notes }.map { it.op })
        assertEquals(3, g.shortsCount.count)
        assertNotNull(g.shortsCount.lastDetectedAt)
        // Sneaky style: no card.
        val sneaky = shorts(MediaGuard(), rules("block", style = "sneaky"), 3).mapNotNull { it.close }
        assertNull(sneaky.single().card)
    }

    /** No session at all for [secs] seconds (SmartTube between Shorts). */
    private fun gap(g: MediaGuard, rules: Rules, secs: Int): List<MediaOutcome> =
        (1..secs).map {
            g.step(MediaSnapshot.NONE, ST, t, wall, today, rules, true).also { t += 1_000; wall += 1_000 }
        }

    private fun listenerShort(g: MediaGuard, rules: Rules, title: String, durMs: Long, secs: Int): List<MediaOutcome> =
        (1..secs).map {
            val s = MediaSnapshot(MediaSource.listener, listOf(MediaSample(ST, track(title, durMs), PlayState.playing, 0, 1f, t)))
            g.step(s, ST, t, wall, today, rules, true).also { t += 1_000; wall += 1_000 }
        }

    // Replays the pattern recorded on the VU3 (2026-10-29): SmartTube drops its
    // session for ~4–5 s between Shorts, then a new one appears with the next
    // title and a known duration (18 s, 35 s, 73 s, 23 s, 18 s).
    @Test fun shortsAcrossSessionGapsAreDetected() {
        val g = MediaGuard()
        val r = rules("block")
        val out = mutableListOf<MediaOutcome>()
        for ((title, dur) in listOf("Border" to 18_000L, "Dandiya" to 35_000L, "Supercar" to 73_000L, "RPG-7" to 23_000L)) {
            out += gap(g, r, 5)
            out += listenerShort(g, r, title, dur, 10)
        }
        val closes = out.mapNotNull { it.close }
        assertTrue("Shorts across session gaps must be blocked", closes.isNotEmpty())
        assertEquals("shortsBlock", closes.first().reason)
    }

    // Replays the VU3 recording of 2026-10-29 02:38: six full-length films
    // (40-120 min) hopped through in about a minute, ~10 s each with session
    // gaps. Length is irrelevant: this is the Shorts-binge behaviour.
    @Test fun hoppingThroughLongVideosIsCaught() {
        val g = MediaGuard()
        val r = rules("block")
        val out = mutableListOf<MediaOutcome>()
        for (title in listOf("Chillar Party", "Anand", "Ramayan", "Nana", "Khadi", "Yeshwant")) {
            out += gap(g, r, 2)
            out += listenerShort(g, r, title, 6_000_000, 9)
        }
        val close = out.mapNotNull { it.close }.firstOrNull()
        assertNotNull("hopping through long videos must be caught", close)
        assertEquals(MediaGuard.HOP_TITLE, close!!.card!!.message)
    }

    @Test fun watchingTwoLongVideosProperlyIsFine() {
        val g = MediaGuard()
        val r = rules("block")
        val out = listenerShort(g, r, "Film A", 6_000_000, 200) + gap(g, r, 3) +
            listenerShort(g, r, "Film B", 6_000_000, 200)
        assertTrue(out.none { it.close != null })
    }

    @Test fun aLongGapStartsOver() {
        val g = MediaGuard()
        val r = rules("block")
        listenerShort(g, r, "A", 20_000, 10)
        listenerShort(g, r, "B", 20_000, 10)
        gap(g, r, 70) // left the app for over a minute
        val out = listenerShort(g, r, "C", 20_000, 10)
        assertTrue(out.none { it.close != null })
    }

    @Test fun neverActsWhilePausedOrSafe() {
        val g = MediaGuard()
        val out = shorts(g, rules("block"), 5, enforce = false)
        assertTrue(out.all { it.close == null })
        assertEquals("still reported", "shorts", out.flatMap { it.notes }.single().op)
    }

    @Test fun budgetBlocksAfterN() {
        val g = MediaGuard()
        val r = rules("budget", perDay = 4)
        val first = shorts(g, r, 4)
        assertTrue(first.all { it.close == null })
        assertEquals(4, g.shortsCount.count)
        val fifth = run(g, r, "S 5", 9)
        assertEquals("shortsBudget", fifth.mapNotNull { it.close }.single().reason)
        assertEquals(MediaGuard.BUDGET_TITLE, fifth.mapNotNull { it.close }.single().card!!.message)
        assertEquals("budget", g.shortsDoc(r, today).mode)
        assertEquals(5, g.shortsDoc(r, today).todayCount)
        assertEquals(4, g.shortsDoc(r, today).perDay)
        assertEquals("next day", 0, g.shortsDoc(r, "2026-10-30").todayCount)
    }

    @Test fun reportOnlyJournalsAndOffIsSilent() {
        val g = MediaGuard()
        val out = shorts(g, rules("report"), 6)
        assertTrue(out.all { it.close == null })
        assertEquals(1, out.flatMap { it.notes }.size)
        assertTrue(out.flatMap { it.notes }.single().after.contains("mode report"))
        val off = MediaGuard()
        val o = shorts(off, Rules(), 6)
        assertTrue(o.all { it.close == null && it.notes.isEmpty() })
        assertEquals("counted for status even when off", 6, off.shortsCount.count)
        assertTrue(off.shortsDoc(Rules(), today).active)
        assertEquals("off", off.shortsDoc(Rules(), today).mode)
    }

    @Test fun endAfterFiresOnTheNextTitleAndSurvivesRestart() {
        val g = MediaGuard()
        run(g, Rules(), "Episode 1", 3)
        val armed = g.arm(snap("Episode 1"), ST, wall, null, 30)
        assertTrue(armed.ok)
        assertEquals("Episode 1", g.endAfterDoc().title)
        assertTrue(g.endAfterDoc().armed)
        assertTrue(run(g, Rules(), "Episode 1", 30).all { it.endAfterFired == null })
        // Agent restart: a new MediaGuard from the persisted state.
        val persisted = EndAfterState.parse(g.endAfter.toJson())
        assertEquals(g.endAfter, persisted)
        val g2 = MediaGuard(endAfter = persisted)
        val out = run(g2, Rules(), "Episode 2 (autoplay)", 1).single()
        assertEquals("nextVideo", out.endAfterFired)
        assertEquals(30, out.endAfterBreakMin)
        assertEquals("endAfter", out.notes.single().op)
        assertFalse(g2.endAfter.armed)
        assertFalse(g2.endAfterDoc().armed)
    }

    @Test fun endAfterWithoutMediaOnlyCaps() {
        val g = MediaGuard(endAfter = EndAfterState(true, wall, wall + 5_000, ST, "X", "$ST|X|", 60))
        repeat(4) { assertNull(g.step(MediaSnapshot.NONE, ST, t, wall, today, Rules(), true).endAfterFired); t += 1_000; wall += 1_000 }
        wall += 1_000
        assertEquals("cap", g.step(MediaSnapshot.NONE, ST, t, wall, today, Rules(), true).endAfterFired)
    }

    @Test fun armFailsWithoutMediaAndCancelWorks() {
        val g = MediaGuard()
        assertFalse(g.arm(MediaSnapshot.NONE, ST, wall, null, null).ok)
        assertFalse(g.cancelEndAfter())
        assertTrue(g.arm(snap("A"), ST, wall, 10, null).ok)
        assertTrue(g.cancelEndAfter())
        assertFalse(g.endAfter.armed)
    }

    @Test fun mediaDocShowsTheFollowedSession() {
        val g = MediaGuard()
        g.step(MediaSnapshot(MediaSource.listener, listOf(MediaSample(ST, track("A", 600_000), PlayState.playing, 10_000, 1f, t))), ST, t + 2_000, wall, today, Rules(), true)
        val d = g.mediaDoc(t + 5_000)!!
        assertEquals(ST, d.pkg)
        assertEquals("A", d.title)
        assertEquals("playing", d.state)
        assertEquals(15_000, d.positionMs)
        assertEquals(600_000L, d.durationMs)
        assertEquals(585_000L, d.remainingMs)
        assertEquals("listener", d.source)
        g.step(MediaSnapshot.NONE, ST, t, wall, today, Rules(), true)
        assertNull(g.mediaDoc(t))
    }
}

class MediaJsonTest {
    @Test fun rulesShortsRoundTrip() {
        val r = Rules.parse("""{"version":4,"shorts":{"mode":"budget","perDay":5,"later":1}}""")
        r.validate()
        assertEquals(ShortsRules("budget", 5), r.shorts)
        assertEquals(r, Rules.parse(r.toJson()))
        assertTrue(r.toJson().contains("\"shorts\":{\"mode\":\"budget\",\"perDay\":5}"))
        // Absent stays absent (older phones round-trip unchanged).
        val old = Rules.parse("""{"version":2,"alwaysMute":true}""")
        assertNull(old.shorts)
        assertFalse(old.toJson().contains("shorts"))
        assertEquals("off", Rules.parse("""{"shorts":{}}""").shorts!!.mode)
    }

    @Test fun rulesShortsValidation() {
        val cur = Rules(version = 0)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"shorts":{"mode":"block"}}""", "now") is RulesPut.Accepted)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"shorts":{"mode":"sometimes"}}""", "now") is RulesPut.Invalid)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"shorts":{"mode":"budget","perDay":-1}}""", "now") is RulesPut.Invalid)
    }

    @Test fun statusMediaFieldsRoundTrip() {
        val s = StatusDoc(
            agentId = "a", version = "1.1.0", uptimeSec = 1, bootCount = 1, selfAdb = "ok", mode = "normal",
            now = NowDoc(ST, 10, 0, 100, false), activeRulesVersion = 1, breakDoc = BreakDoc(false, null),
            health = listOf(HealthItem("mediaAccess", "ok")), buildFingerprint = "fp", buildChangedSinceApproval = false,
            clockSkewWarn = false,
            media = MediaDoc(ST, "A", "C", "playing", 1_000, 60_000, 59_000, "listener"),
            endAfter = EndAfterDoc(true, 1, 2, "A", ST, 60),
            shorts = ShortsDoc("budget", 3, 5, true, 10),
        )
        val text = AgentJson.encodeToString(StatusDoc.serializer(), s)
        assertEquals(s, AgentJson.decodeFromString(StatusDoc.serializer(), text))
        // Older status JSON (no media fields) still decodes.
        val minimal = text.replace(Regex(",\"media\":\\{[^}]*\\},\"endAfter\":\\{[^}]*\\},\"shorts\":\\{[^}]*\\}"), "")
        assertFalse(minimal.contains("endAfter"))
        val old = AgentJson.decodeFromString(StatusDoc.serializer(), minimal)
        assertNull(old.media)
        assertFalse(old.endAfter.armed)
        assertEquals("off", old.shorts.mode)
        // Unknown-duration media omits durationMs/remainingMs.
        val m = AgentJson.encodeToString(MediaDoc.serializer(), MediaDoc(ST, "A", null, "paused", 5, source = "dumpsys"))
        assertFalse(m.contains("durationMs"))
        assertFalse(m.contains("remainingMs"))
    }

    @Test fun endAfterAndCountStateRoundTrip() {
        val e = EndAfterState(true, 1, 2, ST, "A, B", "$ST|A, B|C", 15, 90_000)
        assertEquals(e, EndAfterState.parse(e.toJson()))
        assertEquals(EndAfterState(), EndAfterState.parse("garbage"))
        assertEquals(EndAfterState(), EndAfterState.parse(null))
        val c = ShortsCount("2026-10-29", 7, 123)
        assertEquals(c, AgentJson.decodeFromString(ShortsCount.serializer(), AgentJson.encodeToString(ShortsCount.serializer(), c)))
    }

    @Test fun actionValidation() {
        assertNull(ActionRequest("endAfter").validate())
        assertNull(ActionRequest("endAfter", capMin = 45, breakMin = 60).validate())
        assertNotNull(ActionRequest("endAfter", capMin = 0).validate())
        assertNotNull(ActionRequest("endAfter", breakMin = 1441).validate())
        assertNull(ActionRequest("cancelEndAfter").validate())
    }
}

class MediaHealTest {
    private val all = PermissionState(usageAccess = true, overlay = true, notifications = true)

    @Test fun listenerGrantIsSelfHealed() {
        val cmd = "cmd notification allow_listener com.rakesh.boretube.agent/com.rakesh.boretube.agent.android.MediaListenerService"
        assertEquals(cmd, PermissionHeal.MEDIA_CMD)
        assertTrue(cmd in PermissionHeal.plan(all, SelfAdb.ok, null, 0, periodic = true))
        assertEquals(listOf(cmd), PermissionHeal.plan(all.copy(mediaAccess = false), SelfAdb.ok, null, 0, periodic = false))
        assertTrue(PermissionHeal.plan(all.copy(mediaAccess = false), SelfAdb.unavailable, null, 0, periodic = false).isEmpty())
        assertTrue(PermissionHeal.plan(all, SelfAdb.ok, null, 0, periodic = false).isEmpty())
        assertFalse("optional: not a phone re-grant", PermissionHeal.phoneMustGrant(all.copy(mediaAccess = false), SelfAdb.unavailable))
        assertTrue(PermissionHeal.limitedReasons(all.copy(mediaAccess = false), SelfAdb.ok).isEmpty())
    }

    @Test fun mediaAccessHealth() {
        assertEquals("ok", PermissionHeal.mediaHealth(all, SelfAdb.ok).status)
        val fb = PermissionHeal.mediaHealth(all.copy(mediaAccess = false), SelfAdb.ok)
        assertEquals("mediaAccess", fb.id)
        assertEquals("warn", fb.status)
        assertTrue(fb.detail.contains("dumpsys"))
        assertTrue(PermissionHeal.mediaHealth(all.copy(mediaAccess = false), SelfAdb.unavailable).detail.contains("allow_listener"))
    }
}
