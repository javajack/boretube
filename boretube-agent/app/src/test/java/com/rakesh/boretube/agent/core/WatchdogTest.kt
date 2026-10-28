package com.rakesh.boretube.agent.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WatchdogTest {
    private val p = Fixtures.profile
    private val yt = "com.google.android.youtube.tv"
    private val ytm = "com.google.android.youtube.tvmusic"
    private val promos = "com.sony.dtv.promos"
    private val good = "googletts.google-speech-apk_20251028.02_p2.827711934"
    private val approved = SafetyState(approvedFingerprint = "fp1")

    private fun snap(vararg s: Pair<String, AppState>): PackageSnapshot {
        val m = s.toMap()
        return PackageSnapshot(
            all = m.filterValues { it != AppState.absent }.keys,
            installed = m.filterValues { it == AppState.enabled || it == AppState.disabled }.keys,
            disabled = m.filterValues { it == AppState.disabled }.keys,
        )
    }

    private fun input(
        snapshot: PackageSnapshot,
        tts: PackageVersion? = PackageVersion(good, false),
        safety: SafetyState = approved,
        fp: String = "fp1",
        allowed: Boolean = false,
        keep: Set<String> = setOf(promos),
        profile: DeviceProfile = p,
        launcher: LauncherHealth? = null,
    ) = WatchdogInput(profile, snapshot, tts, launcher, allowed, keep, safety, fp)

    @Test fun removesStockYouTubeAndDisablesCompanion() {
        val plan = Watchdog.plan(input(snap(yt to AppState.enabled, ytm to AppState.enabled)))
        assertEquals(listOf("stockYouTubeOff" to yt, "disableApp" to ytm), plan.ops.map { it.op to it.target })
        assertEquals("pm uninstall -k --user 0 $yt", plan.ops[0].command)
        assertEquals(Risk.low, plan.ops[0].risk)
    }

    @Test fun stockYouTubeAllowedOrAlreadyRemoved() {
        assertTrue(Watchdog.plan(input(snap(yt to AppState.enabled), allowed = true)).ops.isEmpty())
        assertTrue(Watchdog.plan(input(snap(yt to AppState.notInstalled, ytm to AppState.disabled))).ops.isEmpty())
    }

    @Test fun speechRollbackOnlyForUpdatedNonKnownGood() {
        val upd = PackageVersion("googletts.google-speech-apk_20260928", updatedSystemApp = true)
        val plan = Watchdog.plan(input(snap(), tts = upd))
        assertEquals("speechRollback", plan.ops.single().op)
        assertEquals("pm uninstall-system-updates com.google.android.tts", plan.ops.single().command)
        assertTrue(Watchdog.plan(input(snap(), tts = PackageVersion(good, true))).ops.isEmpty()) // known-good
        assertTrue(Watchdog.plan(input(snap(), tts = PackageVersion("x", false))).ops.isEmpty()) // factory
        assertTrue(Watchdog.plan(input(snap(), tts = upd, profile = p.copy(knownGood = emptyMap()))).ops.isEmpty())
    }

    @Test fun otaGateHoldsCleanupButNotLowRiskOps() {
        val s = snap(promos to AppState.enabled, yt to AppState.enabled)
        val upd = PackageVersion("new", true)
        val ota = Watchdog.plan(input(s, tts = upd, fp = "fp2-after-ota"))
        assertEquals(setOf("stockYouTubeOff", "speechRollback"), ota.ops.map { it.op }.toSet())
        assertEquals(listOf("applyCleanup" to promos), ota.pending.map { it.op to it.target })
        assertTrue(ota.notes.any { it.contains("not approved") })
        val ok = Watchdog.plan(input(s, tts = upd))
        assertTrue(ok.ops.any { it.op == "applyCleanup" && it.target == promos })
        assertTrue(ok.pending.isEmpty())
        // Never approved at all: also pending.
        assertEquals(1, Watchdog.plan(input(s, safety = SafetyState())).pending.size)
    }

    @Test fun cleanupOnlyReappliesKeepDisabledPackages() {
        val s = snap(promos to AppState.enabled, "com.android.gallery3d" to AppState.enabled)
        val plan = Watchdog.plan(input(s, keep = setOf(promos)))
        assertEquals(listOf(promos), plan.ops.map { it.target })
    }

    @Test fun neverTouchIsNeverPlanned() {
        // A (bad) profile that lists protected packages as cleanup / stock YouTube.
        val bad = p.copy(
            cleanup = p.cleanup + ProfilePackage("com.google.android.apps.tv.launcherx") + ProfilePackage("com.android.vending"),
            stockYouTube = StockYouTubeSpec("com.google.android.tungsten.setupwraith", listOf("com.google.android.apps.tv.dreamx")),
        )
        val s = snap(
            "com.google.android.apps.tv.launcherx" to AppState.enabled, "com.android.vending" to AppState.enabled,
            "com.google.android.tungsten.setupwraith" to AppState.enabled, "com.google.android.apps.tv.dreamx" to AppState.enabled,
        )
        val plan = Watchdog.plan(input(s, profile = bad, keep = setOf("com.google.android.apps.tv.launcherx", "com.android.vending")))
        val guard = PackageGuard(bad)
        assertTrue(plan.ops.none { guard.isProtected(it.target) })
        assertTrue(plan.pending.none { guard.isProtected(it.target) })
        assertTrue(plan.notes.any { it.contains("never-touch") })
    }

    @Test fun pausedAndSafePlanNothing() {
        val s = snap(yt to AppState.enabled)
        for (m in listOf(Mode.paused, Mode.safe)) {
            val plan = Watchdog.plan(input(s, safety = approved.copy(mode = m)))
            assertTrue(plan.ops.isEmpty() && plan.pending.isEmpty())
        }
    }

    @Test fun keepDisabledCapture() {
        val s = snap(promos to AppState.disabled, "com.sonyliv" to AppState.notInstalled, "com.android.gallery3d" to AppState.enabled)
        assertEquals(setOf(promos, "com.sonyliv"), Watchdog.keepDisabled(p, null, s))
        assertEquals(setOf("x"), Watchdog.keepDisabled(p, setOf("x"), s))
        assertEquals(setOf("y"), Watchdog.keepDisabled(p.copy(keepDisabled = listOf("y")), setOf("x"), s))
    }

    @Test fun launcherFixIsGatedAndKeepsExistingEntries() {
        val broken = LauncherHealth("x/y.Z", false, listOf("com.other/.Svc"), helperEnabled = false, a11yEnabled = true, rawServices = "com.other/.Svc")
        val plan = Watchdog.plan(input(snap(), launcher = broken))
        val op = plan.ops.single()
        assertEquals("fixLauncher", op.op)
        assertTrue(op.command.contains("'com.other/.Svc:com.gathin.tvhome/.HomeKeyService'"))
        assertEquals(1, Watchdog.plan(input(snap(), launcher = broken, fp = "other")).pending.size)
    }

    @Test fun executorRunsVerifiesAndJournals() {
        val tv = FakeTv(mapOf(yt to AppState.enabled, ytm to AppState.enabled, promos to AppState.enabled), ttsVersion = "new", ttsUpdated = true)
        val sh: ShellPort = tv
        val plan = Watchdog.plan(input(TvReader.snapshot(sh), tts = TvReader.tts(sh)))
        val j = Journal()
        val res = OpExecutor(sh, p, j) { 42L }.execute(plan.ops, "watchdog")
        assertEquals(4, res.size)
        assertTrue(res.all { it.ok && it.source == "watchdog" })
        assertEquals(AppState.notInstalled, tv.state[yt])
        assertEquals(AppState.disabled, tv.state[ytm])
        assertEquals(AppState.disabled, tv.state[promos])
        assertEquals(good, tv.ttsVersion)
        assertEquals(4, j.size)
        assertEquals("cmd package install-existing $yt", j.all().first().undo)
        // Second run is a no-op.
        assertTrue(Watchdog.plan(input(TvReader.snapshot(sh), tts = TvReader.tts(sh))).ops.isEmpty())
    }

    @Test fun executorRefusesProtectedTargets() {
        val tv = FakeTv(mapOf("com.android.vending" to AppState.enabled))
        val j = Journal()
        val e = OpExecutor(tv, p, j) { 1L }.executeOne(
            PlannedOp("disableApp", "com.android.vending", "pm disable-user --user 0 com.android.vending", Risk.low), "watchdog",
        )
        assertFalse(e.ok)
        assertEquals(AppState.enabled, tv.state["com.android.vending"])
        assertTrue(tv.commands.isEmpty())
    }
}

class RestorePlannerTest {
    private val p = Fixtures.profile
    private val yt = "com.google.android.youtube.tv"

    @Test fun undoBoretubeRevertsOnlyItsOwnSuccessfulWrites() {
        val journal = listOf(
            JournalEntry(1, "applyCleanup", "com.sony.dtv.promos", "enabled", "disabled", true, "watchdog"),
            JournalEntry(2, "stockYouTubeOff", yt, "enabled", "notInstalled", true, "watchdog"),
            JournalEntry(3, "disableApp", "com.sonyliv", "enabled", "enabled", false, "watchdog"), // failed
            JournalEntry(4, "mute", "sound", "", "", true, "rule"),
            JournalEntry(5, "speechRollback", TvShell.TTS_PACKAGE, "new", "old", true, "watchdog"),
        )
        val snap = PackageSnapshot(
            all = setOf("com.sony.dtv.promos", yt, "com.sonyliv"),
            installed = setOf("com.sony.dtv.promos", "com.sonyliv"),
            disabled = setOf("com.sony.dtv.promos"),
        )
        val plan = RestorePlanner.undoBoretube(p, journal, listOf(ExternalStep("disableApp", "com.sony.dtv.sonyselect")), snap)
        assertEquals(
            listOf("installExisting" to yt, "enableApp" to "com.sony.dtv.promos", "removeAgent" to TvShell.AGENT_PACKAGE),
            plan.steps.map { it.op to it.target },
        )
        assertTrue(plan.notes.any { it.contains("speech") })
    }

    @Test fun backToStockReenablesEverythingButNeverTouch() {
        val all = Watchdog.cleanupTargets(p) + yt + "com.google.android.youtube.tvmusic"
        val snap = PackageSnapshot(all.toSet(), all.toSet() - yt, all.toSet() - yt)
        val plan = RestorePlanner.backToStock(p, snap, null, alsoRemoveLauncherHelper = false)
        val targets = plan.steps.map { it.target }
        assertTrue(targets.containsAll(Watchdog.cleanupTargets(p)))
        assertTrue(plan.steps.any { it.op == "installExisting" && it.target == yt })
        assertTrue(plan.steps.any { it.op == "enableApp" && it.target == "com.google.android.youtube.tvmusic" })
        assertEquals("removeAgent", plan.steps.last().op)
        val guard = PackageGuard(p)
        assertTrue(plan.steps.dropLast(1).none { guard.isProtected(it.target) })
        assertTrue(plan.notes.contains("custom launcher left alone"))

        val withBad = p.copy(cleanup = p.cleanup + ProfilePackage("com.google.android.apps.tv.dreamx"))
        val s2 = PackageSnapshot(setOf("com.google.android.apps.tv.dreamx"), setOf("com.google.android.apps.tv.dreamx"), setOf("com.google.android.apps.tv.dreamx"))
        assertTrue(RestorePlanner.backToStock(withBad, s2, null, false).steps.none { it.target == "com.google.android.apps.tv.dreamx" })
    }

    @Test fun backToStockCanRemoveLauncherHelperAndExecutes() {
        val tv = FakeTv(mapOf("com.sony.dtv.promos" to AppState.disabled, yt to AppState.notInstalled))
        val launcher = TvReader.launcher(tv, p.launcher)
        val plan = RestorePlanner.backToStock(p, TvReader.snapshot(tv), launcher, alsoRemoveLauncherHelper = true)
        assertTrue(plan.steps.any { it.op == "removeLauncherHelper" })
        val j = Journal()
        val res = OpExecutor(tv, p, j) { 7L }.execute(plan.steps, "agent")
        assertTrue(res.all { it.ok })
        assertEquals(AppState.enabled, tv.state["com.sony.dtv.promos"])
        assertEquals(AppState.enabled, tv.state[yt])
        assertEquals("null", tv.a11y)
        assertEquals(plan.steps.size, j.size)
        assertTrue(j.all().last().after.contains("left to the phone"))
    }
}
