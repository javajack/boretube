package com.rakesh.boretube.agent.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class TvShellTest {
    @Test fun parsesStreamMusicFromTheVu3() {
        val v = TvShell.parseVolume(Fixtures.volumeOut(16, false))!!
        assertEquals(VolumeState(16, 0, 100, false), v)
        assertEquals(16, v.percent)
        assertTrue(TvShell.parseVolume(Fixtures.volumeOut(0, true))!!.muted)
    }

    @Test fun volumeParserIgnoresOtherStreamsAndMissingBlock() {
        assertNull(TvShell.parseVolume("- STREAM_RING:\n   Muted: false\n   streamVolume:5"))
        assertNull(TvShell.parseVolume(""))
        val two = "- STREAM_MUSIC:\n   Muted: true\n   Min: 0\n   Max: 15\n   streamVolume:7\n\n- STREAM_ALARM:\n   streamVolume:3"
        assertEquals(VolumeState(7, 0, 15, true), TvShell.parseVolume(two))
    }

    @Test fun levelForPercentRoundsDown() {
        val v = VolumeState(50, 0, 15, false)
        assertEquals(4, v.levelForPercent(30)) // 4.5 → 4, never above the cap
        assertEquals(15, v.levelForPercent(100))
        assertEquals(0, v.levelForPercent(-5))
    }

    @Test fun parsesTopResumedActivity() {
        val out = "    topResumedActivity=ActivityRecord{7026b25 u0 com.gathin.tvhome/.MainActivity t3678}"
        assertEquals("com.gathin.tvhome", TvShell.parseTopResumed(out))
        assertEquals("org.smarttube.stable",
            TvShell.parseTopResumed("topResumedActivity=ActivityRecord{1 u0 org.smarttube.stable/com.liskovsoft.Splash t9}"))
        assertNull(TvShell.parseTopResumed("topResumedActivity=null"))
    }

    @Test fun packageSnapshotStates() {
        val out = Fixtures.pmList("a.enabled", "b.disabled", "c.removed") + "\n---\n" +
            Fixtures.pmList("a.enabled", "b.disabled") + "\n---\n" + Fixtures.pmList("b.disabled")
        val s = PackageSnapshot.parse(out)
        assertEquals(AppState.enabled, s.state("a.enabled"))
        assertEquals(AppState.disabled, s.state("b.disabled"))
        assertEquals(AppState.notInstalled, s.state("c.removed"))
        assertEquals(AppState.absent, s.state("d.nothing"))
    }

    @Test fun packageVersionAndSpeechDecision() {
        val good = "googletts.google-speech-apk_20251028.02_p2.827711934"
        val factory = TvShell.parsePackageVersion(
            "    versionName=$good\n    pkgFlags=[ SYSTEM HAS_CODE ALLOW_CLEAR_USER_DATA ]\n    User 0: ceDataInode=252603 installed=true hidden=false",
        )!!
        assertEquals(good, factory.versionName)
        assertFalse(factory.updatedSystemApp)
        assertEquals(true, factory.installedForUser0)
        assertFalse(TvShell.decideSpeechRollback(factory, good).needed)
        assertTrue(TvShell.decideSpeechRollback(factory, good).atKnownGood)

        val updated = PackageVersion("googletts.google-speech-apk_20260928.01", updatedSystemApp = true)
        assertTrue(TvShell.decideSpeechRollback(updated, good).needed)
        // Differs but not an update: nothing to roll back to.
        val other = PackageVersion("googletts.other", updatedSystemApp = false)
        assertFalse(TvShell.decideSpeechRollback(other, good).needed)
        assertFalse(TvShell.decideSpeechRollback(null, good).needed)
    }

    @Test fun launcherHealth() {
        val spec = Fixtures.profile.launcher
        val ok = TvShell.parseLauncherHealth(
            "priority=0\ncom.google.android.apps.tv.launcherx/.MainActivity\n---\ncom.gathin.tvhome/.HomeKeyService\n---\n1", spec,
        )
        assertTrue(ok.helperEnabled)
        assertTrue(ok.ok)
        assertFalse(ok.homeIsLauncher)
        val broken = TvShell.parseLauncherHealth("x/y.Z\n---\nnull\n---\n0", spec)
        assertFalse(broken.ok)
        assertEquals("", broken.rawServices)
        assertEquals("com.gathin.tvhome/com.gathin.tvhome.HomeKeyService", TvShell.normalizeComponent("com.gathin.tvhome/.HomeKeyService"))
    }

    @Test fun commandsMatchTvOps() {
        assertEquals("pm disable-user --user 0 com.x", TvShell.enableCommand("com.x", false))
        assertEquals("pm enable com.x", TvShell.enableCommand("com.x", true))
        assertEquals("pm uninstall -k --user 0 com.google.android.youtube.tv", TvShell.removeForUserCommand("com.google.android.youtube.tv"))
        assertEquals("cmd package install-existing com.google.android.youtube.tv", TvShell.installExistingCommand("com.google.android.youtube.tv"))
        assertEquals(
            "dumpsys activity activities | grep -m1 topResumedActivity; echo ---; pidof com.x; echo ---; " +
                "am force-stop com.x && echo stopped; input keyevent KEYCODE_HOME && echo home; echo ---; pidof com.x",
            TvShell.stopCommand("com.x", home = true),
        )
        assertTrue(TvShell.setMutedCommand(true).contains("grep -q 'Muted: false'"))
        assertTrue(TvShell.setMutedCommand(false).contains("grep -q 'Muted: true'"))
    }

    @Test(expected = IllegalArgumentException::class)
    fun rejectsShellInjectionInPackageNames() {
        TvShell.enableCommand("com.x; reboot", false)
    }
}
