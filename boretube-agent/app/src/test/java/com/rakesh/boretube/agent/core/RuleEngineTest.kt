package com.rakesh.boretube.agent.core

import com.rakesh.boretube.agent.core.Fixtures.at
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RuleEngineTest {
    private val guard = PackageGuard(Fixtures.profile)
    private val smart = "org.smarttube.stable"
    private val netflix = "com.netflix.ninja"
    private val loud = VolumeState(60, 0, 100, false)

    private fun decide(
        rules: Rules,
        fg: String? = smart,
        vol: VolumeState? = VolumeState(10, 0, 100, false),
        now: java.time.ZonedDateTime = at(26, 12),
        b: BreakState = BreakState(),
        usedMs: Long = 0,
        screenOn: Boolean = true,
    ) = RuleEngine.decide(rules, b, now, Observed(fg, vol, screenOn, usedMs), guard)

    private fun closes(r: EngineResult) = r.decisions.filterIsInstance<Decision.CloseApp>()

    // ── schedule ──

    private val nightly = TvTimeRules(schedule = listOf(ScheduleWindow(listOf(1, 2, 3, 4, 5), "21:00", "07:00")))

    @Test fun scheduleBlocksInsideWindowAndAcrossMidnight() {
        val r = Rules(tvTime = nightly)
        assertEquals(1, closes(decide(r, now = at(26, 22))).size) // Mon 22:00
        assertEquals(1, closes(decide(r, now = at(27, 2))).size) // Tue 02:00 (Mon's window)
        assertEquals(0, closes(decide(r, now = at(27, 7))).size) // 07:00 end is exclusive
        assertEquals(0, closes(decide(r, now = at(26, 20, 59))).size)
    }

    @Test fun weekdayMappingUsesTheDayTheWindowStarts() {
        val r = Rules(tvTime = nightly)
        // Fri 2026-10-30 23:00 blocked; Sat 02:00 still Friday's window.
        assertEquals(1, closes(decide(r, now = at(30, 23))).size)
        assertEquals(1, closes(decide(r, now = at(31, 2))).size)
        // Sat 22:00 not blocked (6 not in days); Mon 02:00 not blocked (Sunday's window).
        assertEquals(0, closes(decide(r, now = at(31, 22))).size)
        assertEquals(0, closes(decide(r, now = at(26, 2))).size)
        assertEquals(java.time.DayOfWeek.MONDAY, at(26, 0).dayOfWeek)
    }

    @Test fun scheduleBackAtAndFullDay() {
        val end = Schedule.activeWindowEnd(nightly.schedule, at(27, 2))!!
        assertEquals(at(27, 7), end)
        val allDay = listOf(ScheduleWindow(listOf(7), "00:00", "00:00"))
        assertEquals(at(26, 0), Schedule.activeWindowEnd(allDay, ZonedDateTimeHelper.sunday(25, 15)))
        assertNull(Schedule.activeWindowEnd(allDay, at(26, 15)))
        // Same-day window.
        val day = listOf(ScheduleWindow(listOf(1), "13:00", "15:30"))
        assertEquals(at(26, 15, 30), Schedule.activeWindowEnd(day, at(26, 14)))
        assertNull(Schedule.activeWindowEnd(day, at(26, 16)))
    }

    // ── daily limit ──

    @Test fun dailyLimit() {
        val r = Rules(tvTime = TvTimeRules(dailyLimitMin = 60))
        assertEquals(0, closes(decide(r, usedMs = 59 * 60_000L)).size)
        val hit = decide(r.copy(style = "explicit"), usedMs = 60 * 60_000L)
        val c = closes(hit).single()
        assertEquals("dailyLimit", c.reason)
        assertEquals("00:00", c.card!!.backAt)
        assertTrue("dailyLimit" in hit.active)
        // 0 = no limit.
        assertEquals(0, closes(decide(Rules(), usedMs = 999 * 60_000L)).size)
    }

    // ── allow / block lists ──

    @Test fun allowlistBlocksEverythingElse() {
        val r = Rules(allowedApps = AllowedApps("allowlist", listOf(smart)))
        assertEquals(0, closes(decide(r, fg = smart)).size)
        assertEquals("appNotAllowed", closes(decide(r, fg = netflix)).single().reason)
    }

    @Test fun blocklistBlocksOnlyListed() {
        val r = Rules(allowedApps = AllowedApps("blocklist", listOf(netflix)))
        assertEquals(1, closes(decide(r, fg = netflix)).size)
        assertEquals(0, closes(decide(r, fg = smart)).size)
        assertEquals(0, closes(decide(Rules(allowedApps = AllowedApps("off", listOf(netflix))), fg = netflix)).size)
    }

    @Test fun homeSettingsInputsAndAgentAreNeverClosedByAppRules() {
        val r = Rules(allowedApps = AllowedApps("allowlist", emptyList()))
        for (pkg in listOf("com.gathin.tvhome", TvShell.LAUNCHERX, "com.android.tv.settings",
            "com.realtek.tv.passthrough", TvShell.AGENT_PACKAGE, "com.android.systemui")) {
            assertEquals(pkg, 0, closes(decide(r, fg = pkg)).size)
        }
        assertEquals(0, closes(decide(r, fg = null)).size)
    }

    @Test fun hdmiIsExemptFromAppRulesButNotTvTime() {
        val hdmi = "com.realtek.tv.passthrough"
        val c = closes(decide(Rules(tvTime = nightly), fg = hdmi, now = at(26, 22))).single()
        assertFalse("input packages are stop-protected: HOME only", c.forceStop)
    }

    @Test fun screenOffDoesNotClose() {
        assertEquals(0, closes(decide(Rules(tvTime = nightly), now = at(26, 22), screenOn = false)).size)
    }

    // ── overrides ──

    @Test fun allowAppOverrideUntilExpiry() {
        val until = at(26, 23).toOffsetDateTime().toString()
        val r = Rules(
            allowedApps = AllowedApps("blocklist", listOf(netflix)),
            tvTime = nightly,
            overrides = listOf(Override("allowApp", netflix, until)),
        )
        assertEquals(0, closes(decide(r, fg = netflix, now = at(26, 22))).size)
        assertEquals(1, closes(decide(r, fg = netflix, now = at(26, 23, 1))).size)
        assertEquals("other apps still blocked", 1, closes(decide(r, fg = smart, now = at(26, 22))).size)
    }

    @Test fun muteUntilAndBreakUntilOverrides() {
        val r = Rules(overrides = listOf(Override("muteUntil", null, at(26, 13).toInstant().toString())))
        assertTrue(decide(r, now = at(26, 12)).decisions.any { it is Decision.Mute })
        // Expired: no mute (and no unmute since the agent never muted).
        assertTrue(decide(r, now = at(26, 14)).decisions.none { it is Decision.Mute || it is Decision.Unmute })

        val br = Rules(overrides = listOf(Override("breakUntil", null, at(26, 13).toInstant().toString())))
        val d = decide(br, now = at(26, 12))
        assertEquals("break", closes(d).single().reason)
        assertTrue(d.decisions.any { it is Decision.Mute })
        assertEquals(at(26, 13).toInstant().toEpochMilli(), d.breakEndsAt)
    }

    // ── style ──

    @Test fun styleDecidesTheCard() {
        val base = Rules(allowedApps = AllowedApps("blocklist", listOf(netflix)))
        assertNull(closes(decide(base, fg = netflix)).single().card)
        val explicit = closes(decide(base.copy(style = "explicit"), fg = netflix)).single()
        assertEquals("This app isn't allowed", explicit.card!!.message)
        assertTrue(explicit.forceStop)
        val sched = closes(decide(Rules(style = "explicit", tvTime = nightly), now = at(26, 22))).single()
        assertEquals("TV time is over · back at 07:00", sched.card!!.text)
        assertEquals(CardMood.guard, explicit.card!!.mood)
        assertEquals(CardMood.asleep, sched.card!!.mood)
        assertEquals("Back at 07:00.", sched.card!!.subLine)
    }

    // ── sound ──

    @Test fun alwaysMuteAndClamp() {
        val r = Rules(alwaysMute = true)
        val d = decide(r, vol = loud)
        assertTrue(d.decisions.any { it is Decision.Mute })
        assertTrue(d.breakState.mutedByAgent)
        // Already muted: no repeat.
        assertTrue(decide(r, vol = loud.copy(muted = true)).decisions.none { it is Decision.Mute })

        val c = decide(Rules(volumeLimit = VolumeLimit(30, true)), vol = loud).decisions.filterIsInstance<Decision.ClampVolume>()
        assertEquals(30, c.single().maxLevel)
        assertTrue(decide(Rules(volumeLimit = VolumeLimit(30, false)), vol = loud).decisions.none { it is Decision.ClampVolume })
        assertTrue(decide(Rules(volumeLimit = VolumeLimit(30, true)), vol = loud.copy(level = 30)).decisions.none { it is Decision.ClampVolume })
    }

    @Test fun breakClosesAndMutesUntilEndThenUnmutesOnce() {
        val start = at(26, 12).toInstant().toEpochMilli()
        val b = BreakState().startBreak(start, 30)
        val during = decide(Rules(), b = b, now = at(26, 12, 10), vol = loud)
        assertEquals("break", closes(during).single().reason)
        assertTrue(during.decisions.any { it is Decision.Mute })
        val after = decide(Rules(), b = during.breakState, now = at(26, 12, 31), vol = loud.copy(muted = true))
        assertTrue(after.decisions.any { it is Decision.Unmute })
        assertEquals(0, closes(after).size)
        assertNull(after.breakState.breakEndsAt)
        val later = decide(Rules(), b = after.breakState, now = at(26, 12, 32), vol = loud)
        assertTrue("unmute only once", later.decisions.none { it is Decision.Unmute })
    }
}

object ZonedDateTimeHelper {
    fun sunday(day: Int, hh: Int) = java.time.ZonedDateTime.of(2026, 10, day, hh, 0, 0, 0, Fixtures.ZONE)
}
