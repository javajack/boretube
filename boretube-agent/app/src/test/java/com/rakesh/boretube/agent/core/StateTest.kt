package com.rakesh.boretube.agent.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate

class TvTimeTest {
    private val guard = PackageGuard(Fixtures.profile)
    private val day = LocalDate.of(2026, 10, 26)

    @Test fun countsOnlyScreenOnNonHdmiAppTime() {
        val c = TvTimeCounter()
        var t = 1_000_000L
        c.tick(t, day, true, true)
        t += 1000; c.tick(t, day, true, TvTimeCounter.counts("org.smarttube.stable", guard))
        t += 1000; c.tick(t, day, false, TvTimeCounter.counts("org.smarttube.stable", guard)) // screen off
        t += 1000; c.tick(t, day, true, TvTimeCounter.counts("com.realtek.tv.passthrough", guard)) // HDMI
        t += 1000; c.tick(t, day, true, TvTimeCounter.counts("com.gathin.tvhome", guard)) // Home
        t += 1000; c.tick(t, day, true, TvTimeCounter.counts(null, guard))
        t += 1000; c.tick(t, day, true, TvTimeCounter.counts("com.netflix.ninja", guard))
        assertEquals(2000, c.usedMs(day))
    }

    @Test fun gapsAreNotCountedAndMidnightResets() {
        val c = TvTimeCounter()
        c.tick(0, day, true, true)
        c.tick(60_000, day, true, true) // 60 s gap: agent was dead
        assertEquals(0, c.usedMs(day))
        c.tick(61_000, day, true, true)
        assertEquals(1000, c.usedMs(day))
        val next = day.plusDays(1)
        c.tick(62_000, next, true, true)
        assertEquals(0, c.usedMs(next))
        assertEquals(0, c.usedMinutes(day))
    }

    @Test fun usedMinutes() {
        val c = TvTimeCounter(TvTimeState(day.toString(), 61 * 60_000L + 59_000, 0))
        assertEquals(61, c.usedMinutes(day))
    }
}

class BreakStateTest {
    @Test fun breakExpiresAndUnmutesOnce() {
        val b = BreakState().startBreak(0, 10).copy(mutedByAgent = true)
        assertTrue(b.breakActive(9 * 60_000L))
        assertFalse(b.breakActive(10 * 60_000L))
        val s1 = MuteLatch.step(b, 5 * 60_000L, wantMute = true)
        assertTrue(s1.mute)
        val s2 = MuteLatch.step(s1.state, 11 * 60_000L, wantMute = false)
        assertTrue(s2.unmuteOnce)
        assertNull(s2.state.breakEndsAt)
        val s3 = MuteLatch.step(s2.state, 12 * 60_000L, wantMute = false)
        assertFalse(s3.unmuteOnce)
    }

    @Test fun neverUnmutesATvTheAgentDidNotMute() {
        val s = MuteLatch.step(BreakState(), 0, wantMute = false)
        assertFalse(s.unmuteOnce)
    }

    @Test fun muteForAndRestore() {
        val m = BreakState().startMuteFor(1000, 30)
        assertEquals(1000 + 30 * 60_000L, m.muteEndsAt)
        assertTrue(m.muteForActive(1001))
        assertEquals(BreakState(), m.restore())
        assertEquals(1000 + 24 * 60 * 60_000L, BreakState().startBreak(1000, 99_999).breakEndsAt) // capped 24 h
    }

    @Test fun persistsAcrossRestarts() {
        val b = BreakState(breakEndsAt = 123, muteEndsAt = 456, mutedByAgent = true)
        assertEquals(b, BreakState.parse(b.toJson()))
        assertEquals(BreakState(), BreakState.parse(null))
        assertEquals(BreakState(), BreakState.parse("{garbage"))
    }

    @Test fun expiredWhileAgentWasDeadStillUnmutesOnce() {
        // Persisted state from before a TV restart; break already over at load.
        val loaded = BreakState.parse(BreakState(breakEndsAt = 1000, mutedByAgent = true).toJson())
        val s = MuteLatch.step(loaded, 5000, wantMute = false)
        assertTrue(s.unmuteOnce)
    }
}

class SafetyGuardTest {
    private val min = 60_000L

    @Test fun threeBootsEachAfterAShortSessionEnterSafeMode() {
        var s = SafetyState()
        s = SafetyGuard.recordBoot(s, "a", 0, prevUpMs = 3 * 60 * min)
        s = SafetyGuard.recordBoot(s, "b", 0, prevUpMs = 2 * min)
        assertEquals(Mode.normal, s.mode)
        s = SafetyGuard.recordBoot(s, "c", 0, prevUpMs = 90_000)
        assertEquals(Mode.safe, s.mode)
        assertTrue(s.modeReason.startsWith("boot loop"))
        assertEquals(3, s.bootCount)
        assertFalse(SafetyGuard.canEnforce(s))
        assertFalse(SafetyGuard.canWrite(s, Risk.low, "fp"))
    }

    @Test fun powerCutsWithTheClockStuckAtOneDateDoNotTrip() {
        // After a power cut the VU3 boots at 2026-05-15 12:14 until NTP: the
        // same wall-clock minute every time. Each session lasted a while.
        val stuck = 1_778_827_488_501L
        var s = SafetyState()
        for (id in listOf("a", "b", "c", "d")) {
            s = SafetyGuard.recordBoot(s, id, stuck, prevUpMs = 20 * min)
        }
        assertEquals(Mode.normal, s.mode)
        assertEquals(4, s.bootCount)
    }

    @Test fun aLongSessionBreaksTheRunAndDuplicateBootIdsDoNotCount() {
        var s = SafetyState()
        s = SafetyGuard.recordBoot(s, "a", 0, prevUpMs = min)
        s = SafetyGuard.recordBoot(s, "a", 1, prevUpMs = 10) // LOCKED_BOOT + BOOT + service restart: same boot
        s = SafetyGuard.recordBoot(s, "a", 2, prevUpMs = 10)
        s = SafetyGuard.recordBoot(s, "b", 3, prevUpMs = 30 * min)
        s = SafetyGuard.recordBoot(s, "c", 4, prevUpMs = min)
        assertEquals(Mode.normal, s.mode)
        assertEquals(3, s.bootCount)
    }

    @Test fun anUnknownPreviousSessionIsNotShort() {
        var s = SafetyState()
        for (id in listOf("a", "b", "c")) s = SafetyGuard.recordBoot(s, id, 0, prevUpMs = null)
        assertEquals(Mode.normal, s.mode)
    }

    @Test fun leavingSafeModeClearsTheBurst() {
        var s = SafetyState()
        for (id in listOf("a", "b", "c")) s = SafetyGuard.recordBoot(s, id, 0, prevUpMs = min)
        assertEquals(Mode.safe, s.mode)
        s = SafetyGuard.setMode(s, Mode.normal, "phone")
        assertEquals(Mode.normal, s.mode)
        s = SafetyGuard.recordBoot(s, "d", 0, prevUpMs = min)
        assertEquals(Mode.normal, s.mode)
    }

    @Test fun buildGate() {
        val s = SafetyState()
        assertTrue(SafetyGuard.buildChangedSinceApproval(s, "fp1"))
        assertTrue(SafetyGuard.canWrite(s, Risk.low, "fp1"))
        assertFalse(SafetyGuard.canWrite(s, Risk.high, "fp1"))
        val a = SafetyGuard.approveBuild(s, "fp1")
        assertTrue(SafetyGuard.canWrite(a, Risk.high, "fp1"))
        assertFalse("OTA changed the fingerprint", SafetyGuard.canWrite(a, Risk.high, "fp2"))
        assertTrue(SafetyGuard.buildChangedSinceApproval(a, "fp2"))
        assertFalse(SafetyGuard.canWrite(SafetyGuard.setMode(a, Mode.paused, ""), Risk.low, "fp1"))
    }
}

class JournalTest {
    @Test fun ringBufferKeepsNewest1000AndPersists() {
        var saved = ""
        val j = Journal(1000) { saved = it.toJson() }
        for (i in 1..1005) j.add(JournalEntry(i.toLong(), "op", "t$i", ok = true, source = "agent"))
        assertEquals(1000, j.size)
        assertEquals(6L, j.all().first().time)
        assertEquals(listOf(1004L, 1005L), j.since(1003).map { it.time })
        val reloaded = Journal(1000, Journal.parseEntries(saved))
        assertEquals(j.all(), reloaded.all())
        assertTrue(Journal.parseEntries("not json").isEmpty())
    }
}

class SoundPolicyTest {
    @Test fun verdicts() {
        val v = VolumeState(16, 0, 100, false)
        assertEquals(SoundPath.audioManager, SoundPolicy.verdict(v, v.copy(muted = true), SoundPolicy.Expect.MUTED))
        assertEquals(SoundPath.adbKeys, SoundPolicy.verdict(v, v, SoundPolicy.Expect.MUTED))
        assertEquals(SoundPath.audioManager, SoundPolicy.verdict(v, v.copy(level = 15), SoundPolicy.Expect.LOWER))
        assertEquals(SoundPath.adbKeys, SoundPolicy.verdict(v, v, SoundPolicy.Expect.LOWER))
        assertNull("at minimum: can't tell", SoundPolicy.verdict(v.copy(level = 0), v.copy(level = 0), SoundPolicy.Expect.LOWER))
        assertNull(SoundPolicy.verdict(v, null, SoundPolicy.Expect.UNMUTED))
        assertEquals(14, SoundPolicy.clampKeys(VolumeState(44, 0, 100, false), 30).size)
        assertEquals(SoundPath.untested, SoundPath.parse("bogus"))
    }
}

class PermissionHealTest {
    private val all = PermissionState(usageAccess = true, overlay = true, notifications = true)
    private val afterReboot = PermissionState(usageAccess = false, overlay = false, notifications = true)

    @Test fun periodicReGrantsEverything() {
        assertEquals(PermissionHeal.ALL_COMMANDS, PermissionHeal.plan(all, SelfAdb.ok, null, 0, periodic = true))
    }

    @Test fun missingAfterRebootIsReGrantedWithRetryGap() {
        val cmds = PermissionHeal.plan(afterReboot, SelfAdb.ok, null, 0, periodic = false)
        assertEquals(listOf(
            "appops set com.rakesh.boretube.agent GET_USAGE_STATS allow",
            "appops set com.rakesh.boretube.agent SYSTEM_ALERT_WINDOW allow",
        ), cmds)
        assertTrue(PermissionHeal.plan(afterReboot, SelfAdb.ok, 0, 10_000, periodic = false).isEmpty())
        assertEquals(2, PermissionHeal.plan(afterReboot, SelfAdb.ok, 0, 31_000, periodic = false).size)
        assertTrue(PermissionHeal.plan(all, SelfAdb.ok, null, 0, periodic = false).isEmpty())
    }

    @Test fun withoutSelfAdbThePhoneMustGrantAndAgentIsLimited() {
        assertTrue(PermissionHeal.plan(afterReboot, SelfAdb.needsApproval, null, 0, periodic = true).isEmpty())
        assertTrue(PermissionHeal.phoneMustGrant(afterReboot, SelfAdb.needsApproval))
        assertFalse(PermissionHeal.phoneMustGrant(afterReboot, SelfAdb.ok))
        assertEquals(listOf("selfAdb needsApproval", "usageAccess missing", "overlay missing"),
            PermissionHeal.limitedReasons(afterReboot, SelfAdb.needsApproval))
        assertTrue(PermissionHeal.limitedReasons(all, SelfAdb.ok).isEmpty())
        val h = PermissionHeal.health(afterReboot, SelfAdb.unavailable).associateBy { it.id }
        assertEquals("error", h["usageAccess"]!!.status)
        assertEquals("error", h["overlay"]!!.status)
        assertTrue(h["overlay"]!!.detail.contains("phone must re-grant"))
        assertEquals("warn", h["selfAdb"]!!.status)
    }
}
