package com.rakesh.boretube.agent.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.ZoneId
import java.time.ZoneOffset

private const val SMART = "org.smarttube.stable"
private const val KIDS = "com.google.android.apps.youtube.kids"
private const val NETFLIX = "com.netflix.ninja"
private const val LAUNCHER = "com.google.android.tvlauncher"

class CooldownTest {
    private val zone: ZoneId = ZoneOffset.UTC
    private val today = "2026-10-29"
    private var t = 9_000_000L
    /** 2026-10-29T10:00:00Z */
    private var wall = Instant.parse("2026-10-29T10:00:00Z").toEpochMilli()

    private fun rules(min: Int? = null, style: String = "explicit", mode: String = "cooldown") =
        Rules(style = style, shorts = ShortsRules(mode, cooldownMin = min))

    private fun step(g: MediaGuard, r: Rules, fg: String?, title: String? = null, pkg: String = fg ?: SMART, enforce: Boolean = true): MediaOutcome {
        val snap = if (title == null) MediaSnapshot.NONE else MediaSnapshot(
            MediaSource.listener,
            listOf(MediaSample(pkg, MediaTrack(pkg, title, "C", 20_000), PlayState.playing, 0, 1f, t)),
        )
        return g.step(snap, fg, t, wall, today, r, enforce).also { t += 1_000; wall += 1_000 }
    }

    /** Three ~9 s Shorts in SmartTube: a Shorts session. */
    private fun shorts(g: MediaGuard, r: Rules, enforce: Boolean = true): List<MediaOutcome> =
        (1..3).flatMap { i -> (1..9).map { step(g, r, SMART, "Short $i", enforce = enforce) } }

    @Test fun sessionStartsTheCooldownAndClosesTheApp() {
        val g = MediaGuard(zone = zone)
        val start = wall
        val out = shorts(g, rules(15))
        val closes = out.mapNotNull { it.close }
        val close = closes.first()
        // The sim keeps SmartTube in front: it is closed again (every 5 s) with the "still resting" card.
        assertTrue(closes.drop(1).all { it.reason == "shortsCooldown" && it.card!!.message == MediaGuard.COOLDOWN_AGAIN_TITLE })
        assertEquals(SMART, close.pkg)
        assertEquals("shortsCooldown", close.reason)
        assertTrue(close.forceStop)
        val until = g.cooldownUntil!!
        // 15 min from the moment of detection.
        assertEquals(start + out.indexOfFirst { it.close != null } * 1_000L + 15 * 60_000L, until)
        val card = close.card!!
        assertEquals(MediaGuard.COOLDOWN_TITLE, card.message)
        assertEquals(CardMood.asleep, card.mood)
        assertEquals(MediaGuard.COOLDOWN_SHORTS_SUB, card.sub)
        assertEquals(java.time.format.DateTimeFormatter.ofPattern("HH:mm").format(Instant.ofEpochMilli(until).atZone(zone)), card.backAt)
        assertTrue(card.subLine!!.endsWith("Back at ${card.backAt}."))
        val notes = out.flatMap { it.notes }
        assertEquals(listOf("shorts", "cooldown"), notes.map { it.op }.distinct())
        assertEquals(closes.size, notes.count { it.op == "cooldown" })
        assertTrue(notes.first { it.op == "cooldown" }.after.contains("15 min"))
        // Status.
        val doc = g.shortsDoc(rules(15), today, wall)
        assertEquals("cooldown", doc.mode)
        assertEquals(15, doc.cooldownMin)
        assertEquals(until, doc.cooldownUntil)
    }

    @Test fun defaultIsTenMinutes() {
        val g = MediaGuard(zone = zone)
        shorts(g, rules())
        val left = g.cooldownUntil!! - wall
        assertTrue(left in (10 * 60_000L - 20_000)..(10 * 60_000L))
        assertEquals(10, g.shortsDoc(rules(), today, wall).cooldownMin)
    }

    @Test fun everyVideoAppIsClosedAgainDuringTheCooldown() {
        val g = MediaGuard(zone = zone)
        val r = rules(10)
        shorts(g, r)
        val until = g.cooldownUntil!!
        // On the launcher: nothing to do.
        assertNull(step(g, r, LAUNCHER).close)
        // YouTube Kids comes to the foreground: closed with the "back at" card, journaled.
        val kids = step(g, r, KIDS, "Cartoon")
        assertEquals(KIDS, kids.close!!.pkg)
        assertEquals("shortsCooldown", kids.close!!.reason)
        assertEquals(MediaGuard.COOLDOWN_AGAIN_TITLE, kids.close!!.card!!.message)
        assertEquals(CardMood.asleep, kids.close!!.card!!.mood)
        assertNotNull(kids.close!!.card!!.backAt)
        assertEquals("cooldown", kids.notes.single().op)
        assertEquals(KIDS, kids.notes.single().target)
        // Netflix is kept closed too, although it is not followed for Shorts.
        assertEquals(NETFLIX, step(g, r, NETFLIX).close!!.pkg)
        // A failing close is retried, but at most every 5 s (no journal spam).
        val again = (1..10).map { step(g, r, NETFLIX) }
        assertEquals(2, again.count { it.close != null })
        // Unknown foreground but a video session still playing: closed.
        t += 10_000
        assertEquals(SMART, step(g, r, null, "Some video", pkg = SMART).close!!.pkg)
        // Other apps are left alone.
        assertNull(step(g, r, "com.android.tv.settings").close)
        assertEquals(until, g.cooldownUntil)
    }

    @Test fun cooldownEndsOnTimeAndIsJournaled() {
        val g = MediaGuard(zone = zone)
        val r = rules(1)
        shorts(g, r)
        wall = g.cooldownUntil!! - 1_000
        assertNotNull(step(g, r, KIDS, "A").close)
        val end = step(g, r, KIDS, "A")
        assertNull(end.close)
        assertEquals("ended", end.notes.single { it.op == "cooldown" }.after)
        assertNull(g.cooldownUntil)
        assertNull(g.shortsDoc(r, today, wall).cooldownUntil)
    }

    @Test fun survivesARestart() {
        val g = MediaGuard(zone = zone)
        val r = rules(10)
        shorts(g, r)
        val persisted = g.cooldownUntil
        val g2 = MediaGuard(cooldownUntil = persisted, zone = zone)
        assertEquals(persisted, g2.shortsDoc(r, today, wall).cooldownUntil)
        assertEquals(SMART, step(g2, r, SMART, "Anything").close!!.pkg)
    }

    @Test fun restoreEndsIt() {
        val g = MediaGuard(zone = zone)
        val r = rules(10)
        shorts(g, r)
        assertTrue(g.endCooldown())
        assertFalse(g.endCooldown())
        assertNull(g.cooldownUntil)
        assertNull(step(g, r, KIDS, "A").close)
    }

    @Test fun safeOrPausedNeverEnforce() {
        val g = MediaGuard(zone = zone)
        val r = rules(10)
        val out = shorts(g, r, enforce = false)
        assertTrue(out.all { it.close == null })
        assertNull("no cool-down starts while paused/safe", g.cooldownUntil)
        // A cool-down already running is not enforced while paused/safe either.
        val g2 = MediaGuard(cooldownUntil = wall + 300_000, zone = zone)
        assertNull(step(g2, r, KIDS, "A", enforce = false).close)
        assertNotNull(step(g2, r, KIDS, "A", enforce = true).close)
    }

    @Test fun switchingCooldownOffEndsIt() {
        val g = MediaGuard(cooldownUntil = wall + 300_000, zone = zone)
        val out = step(g, rules(mode = "block"), KIDS, "A")
        assertNull(out.close)
        assertNull(g.cooldownUntil)
        assertTrue(out.notes.single().after.contains("mode block"))
    }

    @Test fun aClockJumpBackDoesNotStrandTheTv() {
        val g = MediaGuard(cooldownUntil = wall + 5 * 3600_000L, zone = zone)
        assertNull(step(g, rules(10), KIDS, "A").close)
        assertNull(g.cooldownUntil)
    }

    @Test fun sneakyStyleClosesWithoutACard() {
        val g = MediaGuard(zone = zone)
        val r = rules(10, style = "sneaky")
        val closes = shorts(g, r).mapNotNull { it.close }
        assertTrue(closes.isNotEmpty() && closes.all { it.card == null })
        assertNull(step(g, r, KIDS, "A").close!!.card)
    }

    @Test fun hoppingSessionStartsItToo() {
        val g = MediaGuard(zone = zone)
        val r = rules(10)
        val out = (1..6).flatMap { i ->
            (1..9).map {
                val s = MediaSnapshot(MediaSource.listener, listOf(MediaSample(SMART, MediaTrack(SMART, "Film $i", "C", 6_000_000), PlayState.playing, 0, 1f, t)))
                g.step(s, SMART, t, wall, today, r, true).also { t += 1_000; wall += 1_000 }
            }
        }
        val close = out.mapNotNull { it.close }.first()
        assertEquals(MediaGuard.COOLDOWN_HOP_SUB, close.card!!.sub)
        assertNotNull(g.cooldownUntil)
    }

    @Test fun otherModesAreUnchanged() {
        val g = MediaGuard(zone = zone)
        val close = shorts(g, rules(mode = "block")).mapNotNull { it.close }.single()
        assertEquals("shortsBlock", close.reason)
        assertEquals(CardMood.calm, close.card!!.mood)
        assertNull(g.cooldownUntil)
        assertNull(step(g, rules(mode = "block"), KIDS, "A").close)
        assertNull(g.shortsDoc(rules(mode = "block"), today, wall).cooldownMin)
    }

    @Test fun rulesValidateCooldown() {
        val cur = Rules(version = 0)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"shorts":{"mode":"cooldown"}}""", "now") is RulesPut.Accepted)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"shorts":{"mode":"cooldown","cooldownMin":120}}""", "now") is RulesPut.Accepted)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"shorts":{"mode":"cooldown","cooldownMin":0}}""", "now") is RulesPut.Invalid)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"shorts":{"mode":"cooldown","cooldownMin":121}}""", "now") is RulesPut.Invalid)
        val r = Rules.parse("""{"shorts":{"mode":"cooldown","cooldownMin":20}}""")
        assertEquals(20, r.shorts!!.cooldownMinutes)
        assertTrue(r.toJson().contains("\"cooldownMin\":20"))
        assertFalse(Rules.parse("""{"shorts":{"mode":"block"}}""").toJson().contains("cooldownMin"))
    }
}

class CardTest {
    @Test fun subLineAddsBackAt() {
        assertEquals("Back at 07:00.", Card("TV time is over", "07:00").subLine)
        assertEquals("Rest. Back at 07:00.", Card("X", "07:00", "Rest.").subLine)
        assertEquals("Rest.", Card("X", null, "Rest.").subLine)
        assertNull(Card("X", null).subLine)
    }

    @Test fun previewsAndActionValidation() {
        for (m in CardMood.entries) assertEquals(m, Card.preview(m).mood)
        assertNull(ActionRequest("previewCard").validate())
        assertNull(ActionRequest("previewCard", mood = "calm").validate())
        assertNotNull(ActionRequest("previewCard", mood = "angry").validate())
    }
}
