package com.rakesh.boretube.agent.android

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.database.ContentObserver
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.PowerManager
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import com.rakesh.boretube.agent.BuildConfig
import com.rakesh.boretube.agent.core.ActionRequest
import com.rakesh.boretube.agent.core.ActionResult
import com.rakesh.boretube.agent.core.AgentApi
import com.rakesh.boretube.agent.core.BreakDoc
import com.rakesh.boretube.agent.core.BrainBreakGate
import com.rakesh.boretube.learn.core.BrainBreakSession
import com.rakesh.boretube.agent.core.BreakState
import com.rakesh.boretube.agent.core.Card
import com.rakesh.boretube.agent.core.CardMood
import com.rakesh.boretube.agent.core.ClockSkew
import com.rakesh.boretube.agent.core.Decision
import com.rakesh.boretube.agent.core.DeviceProfile
import com.rakesh.boretube.agent.core.HealthItem
import com.rakesh.boretube.agent.core.JournalEntry
import com.rakesh.boretube.learn.core.LearnState
import com.rakesh.boretube.learn.core.Learner
import com.rakesh.boretube.agent.core.LearningDoc
import com.rakesh.boretube.learn.core.Maths
import com.rakesh.boretube.agent.core.MediaGuard
import com.rakesh.boretube.agent.core.MediaOutcome
import com.rakesh.boretube.agent.core.MediaSnapshot
import com.rakesh.boretube.agent.core.Mode
import com.rakesh.boretube.agent.core.NowDoc
import com.rakesh.boretube.agent.core.Observed
import com.rakesh.boretube.agent.core.OpExecutor
import com.rakesh.boretube.agent.core.PackageGuard
import com.rakesh.boretube.agent.core.PermissionHeal
import com.rakesh.boretube.agent.core.PermissionState
import com.rakesh.boretube.agent.core.PlayClock
import com.rakesh.boretube.agent.core.PlayState
import com.rakesh.boretube.learn.core.Question
import com.rakesh.boretube.learn.core.QuizScreen
import com.rakesh.boretube.agent.core.RestorePlan
import com.rakesh.boretube.agent.core.RestorePlanner
import com.rakesh.boretube.agent.core.RestoreRequest
import com.rakesh.boretube.agent.core.RestoreResult
import com.rakesh.boretube.agent.core.Router
import com.rakesh.boretube.agent.core.RuleEngine
import com.rakesh.boretube.agent.core.Rules
import com.rakesh.boretube.agent.core.RulesPut
import com.rakesh.boretube.agent.core.RulesUpdate
import com.rakesh.boretube.agent.core.SafetyGuard
import com.rakesh.boretube.agent.core.SelfAdb
import com.rakesh.boretube.agent.core.StatusDoc
import com.rakesh.boretube.agent.core.TvReader
import com.rakesh.boretube.agent.core.TvShell
import com.rakesh.boretube.agent.core.TvTimeCounter
import com.rakesh.boretube.agent.core.Watchdog
import com.rakesh.boretube.agent.core.WatchdogInput
import com.rakesh.boretube.agent.core.WatchdogPlan
import com.rakesh.boretube.agent.core.WatchdogReport
import com.rakesh.boretube.agent.core.WatchdogRequest
import com.rakesh.boretube.agent.core.WeekDoc
import java.io.File
import java.time.Instant
import java.time.LocalDate
import java.time.ZonedDateTime
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.random.Random

/**
 * The agent's brain: owns state, runs the 1 s enforcement loop, the watchdog,
 * permission self-heal, and implements the HTTP API.
 *
 * Threads: `guard` (enforcement tick + instant actions, serialised), `slow`
 * (self-ADB probing, self-heal, watchdog, restore). Shared state is guarded by
 * [lock]; shell I/O happens outside it.
 */
class GuardController(private val ctx: Context) : AgentApi {
    val store = AgentStore(ctx)
    private val shell = Shell(ctx.filesDir)
    private val sound = SoundController(ctx, shell, store)
    private val fgw = ForegroundWatcher(ctx, shell)
    private val overlay = Overlay(ctx)
    private val media = MediaWatcher(ctx, shell)
    private val journal = store.loadJournal()
    private val power = ctx.getSystemService(Context.POWER_SERVICE) as PowerManager

    private val lock = Any()
    private var rules: Rules = store.rules
    private var profile: DeviceProfile? = store.profile
    private var breakState: BreakState = store.breakState
    private var safety = store.safety
    private val tvTime = TvTimeCounter(store.tvTime)
    /** Shorts + end-after-this-one; touched on the guard thread only (status reads volatile fields). */
    private val mediaGuard = MediaGuard(store.shortsCount, store.endAfter, store.cooldownUntil)
    /** Brain breaks: the learner (guarded by [lock]), the window, the `every` play clock (guard thread). */
    private var learn: LearnState = store.learnState
    private val playClock = PlayClock()
    private val bbOpen = AtomicBoolean(false)
    @Volatile private var bbPkg: String? = null
    @Volatile private var bbTrigger = ""
    private val brainBreak = BrainBreakWindow(ctx, object : BrainBreakWindow.Host {
        override fun answered(q: Question, correct: Boolean, ms: Long) {
            synchronized(lock) {
                learn = Learner.record(learn, q, correct, ms, System.currentTimeMillis(), LocalDate.now())
                store.learnState = learn
            }
        }

        override fun closed(done: QuizScreen.Done?, summary: String, why: String) {
            if (done != null) synchronized(lock) {
                learn = Learner.roundDone(learn, done.learned, LocalDate.now())
                store.learnState = learn
            }
            record("brainBreak", bbTrigger, if (done != null) "done" else why, summary, done != null || why == "phone", "agent")
            val pkg = bbPkg
            bbPkg = null
            playClock.reset()
            bbOpen.set(false)
            // After the window is gone, so a fallback key event reaches the app. Only when that app is
            // still in front: after Home mid-quiz, playing it would bring back sound behind the launcher.
            guardExec.schedule({
                safely("resume") {
                    val fg = fgw.poll()
                    if (pkg != null && fg == pkg) media(pkg, play = true)
                    else if (pkg != null) record("brainBreak", pkg, "not resumed", "${fg ?: "nothing"} in front", true, "agent")
                }
            }, 300, TimeUnit.MILLISECONDS)
        }
    })
    private val fingerprint: String = Build.FINGERPRINT
    private var skewMs: Long? = null
    private val startedElapsed = SystemClock.elapsedRealtime()

    @Volatile private var observed = Observed(null, null)
    @Volatile private var activeReasons: List<String> = emptyList()
    private var lastHealAt: Long? = null
    private var lastPeriodicHeal = 0L
    private var lastTvTimeSave = 0L
    private var watchdogDueBoot = true
    private var pkgEventAt = 0L
    private var lastQuickCheckAt = 0L
    private var lastPlan: WatchdogPlan? = null
    private val lastClose = HashMap<String, Long>()
    private val restoring = AtomicBoolean(false)

    private val guardExec: ScheduledExecutorService =
        Executors.newSingleThreadScheduledExecutor { Thread(it, "guard").apply { isDaemon = true } }
    private val slowExec: ScheduledExecutorService =
        Executors.newSingleThreadScheduledExecutor { Thread(it, "slow").apply { isDaemon = true } }
    private val soundTickPending = AtomicBoolean(false)

    private var http: HttpServer? = null
    private var nsd: NsdAnnouncer? = null
    private var observerThread: HandlerThread? = null
    private var volumeObserver: ContentObserver? = null
    private var receiver: BroadcastReceiver? = null

    // ── lifecycle ──

    fun start() {
        synchronized(lock) {
            safety = SafetyGuard.recordBoot(safety, bootId(), System.currentTimeMillis())
            store.safety = safety
        }
        if (safety.mode == Mode.safe && safety.modeReason.startsWith("boot loop")) {
            record("safeMode", "agent", "", safety.modeReason, true, "agent")
        }
        store.token
        store.ensureExternalFiles()
        shell.ensureConnected()
        guardExec.scheduleWithFixedDelay({ safely("tick") { tick() } }, 1, 1, TimeUnit.SECONDS)
        slowExec.scheduleWithFixedDelay({ safely("housekeeping") { housekeeping() } }, 0, 5, TimeUnit.SECONDS)
        val router = Router({ store.token }, this)
        http = HttpServer(router).also { it.start() }
        nsd = NsdAnnouncer(ctx, store.agentId, BuildConfig.VERSION_NAME).also { it.start(HttpServer.PORT) }
        registerListeners()
        media.start()
    }

    fun stop() {
        brainBreak.shutdown()
        unregisterListeners()
        media.stop()
        http?.stop()
        nsd?.stop()
        guardExec.shutdownNow()
        slowExec.shutdownNow()
        shell.close()
        store.tvTime = tvTime.state
    }

    private inline fun safely(what: String, block: () -> Unit) {
        try { block() } catch (e: Throwable) { Log.w(TAG, "$what failed", e) }
    }

    private fun bootId(): String = try {
        File("/proc/sys/kernel/random/boot_id").readText().trim()
    } catch (_: Exception) {
        // Boot wall-clock time, to the minute.
        ((System.currentTimeMillis() - SystemClock.elapsedRealtime()) / 60_000).toString()
    }

    private fun registerListeners() {
        val t = HandlerThread("observers").apply { start() }
        observerThread = t
        val h = Handler(t.looper)
        // Volume settings change → re-assert mute/clamp right away (target ~200 ms).
        val obs = object : ContentObserver(h) {
            override fun onChange(selfChange: Boolean) = soundEvent()
        }
        ctx.contentResolver.registerContentObserver(Settings.System.CONTENT_URI, true, obs)
        volumeObserver = obs
        val r = object : BroadcastReceiver() {
            override fun onReceive(c: Context, i: Intent) {
                when (i.action) {
                    Intent.ACTION_PACKAGE_ADDED, Intent.ACTION_PACKAGE_REPLACED, Intent.ACTION_PACKAGE_CHANGED ->
                        onPackageEvent(i.data?.schemeSpecificPart)
                    else -> soundEvent()
                }
            }
        }
        val sf = IntentFilter().apply {
            addAction("android.media.VOLUME_CHANGED_ACTION")
            addAction("android.media.STREAM_MUTE_CHANGED_ACTION")
        }
        val pf = IntentFilter().apply {
            addAction(Intent.ACTION_PACKAGE_ADDED)
            addAction(Intent.ACTION_PACKAGE_REPLACED)
            addAction(Intent.ACTION_PACKAGE_CHANGED)
            addDataScheme("package")
        }
        if (Build.VERSION.SDK_INT >= 33) {
            ctx.registerReceiver(r, sf, null, h, Context.RECEIVER_EXPORTED)
            ctx.registerReceiver(r, pf, null, h, Context.RECEIVER_EXPORTED)
        } else {
            ctx.registerReceiver(r, sf, null, h)
            ctx.registerReceiver(r, pf, null, h)
        }
        receiver = r
    }

    private fun unregisterListeners() {
        volumeObserver?.let { ctx.contentResolver.unregisterContentObserver(it) }
        receiver?.let { try { ctx.unregisterReceiver(it) } catch (_: Exception) {} }
        observerThread?.quitSafely()
    }

    private fun soundEvent() {
        if (soundTickPending.compareAndSet(false, true)) {
            guardExec.execute { soundTickPending.set(false); safely("soundTick") { tick(soundOnly = true) } }
        }
    }

    /** PACKAGE_ADDED/REPLACED/CHANGED: run the watchdog after a 10 s debounce. */
    fun onPackageEvent(pkg: String?) {
        if (pkg == TvShell.AGENT_PACKAGE) return
        synchronized(lock) { pkgEventAt = System.currentTimeMillis() }
    }

    // ── enforcement loop ──

    private fun permissions() = PermissionState(
        usageAccess = fgw.usageAccessAllowed(),
        overlay = overlay.allowed(),
        notifications = Build.VERSION.SDK_INT < 33 ||
            ctx.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED,
        mediaAccess = media.listenerGranted(),
    )

    private fun tick(soundOnly: Boolean = false) {
        val now = System.currentTimeMillis()
        val zdt = ZonedDateTime.now()
        val fg = if (soundOnly) fgw.foreground else fgw.poll(now)
        val vol = sound.read()
        val screenOn = power.isInteractive
        val (r, b, p, s) = synchronized(lock) { Quad(rules, breakState, profile, safety) }
        val guard = PackageGuard(p)
        if (!soundOnly) {
            val st = tvTime.tick(now, zdt.toLocalDate(), screenOn, TvTimeCounter.counts(fg, guard))
            if (now - lastTvTimeSave > 10_000) { store.tvTime = st; lastTvTimeSave = now }
        }
        val obs = Observed(fg, vol, screenOn, tvTime.usedMs(zdt.toLocalDate()))
        observed = obs
        // The media step may start a break (end after this one): re-read the break state after it.
        val b0 = if (!soundOnly) { mediaStep(fg, now, zdt.toLocalDate(), r, SafetyGuard.canEnforce(s), guard, p); synchronized(lock) { breakState } } else b
        if (!SafetyGuard.canEnforce(s)) { activeReasons = emptyList(); return }
        val res = RuleEngine.decide(r, b0, zdt, obs, guard)
        activeReasons = res.active
        synchronized(lock) {
            if (breakState == b0 && res.breakState != b0) { breakState = res.breakState; store.breakState = breakState }
        }
        for (d in res.decisions) {
            if (soundOnly && d is Decision.CloseApp) continue
            apply(d, now, guard, p)
        }
    }

    /** Shorts detection/enforcement and end-after-this-one, once per 1 s tick. */
    private fun mediaStep(fg: String?, now: Long, today: LocalDate, r: Rules, canEnforce: Boolean, guard: PackageGuard, p: DeviceProfile?) {
        val beforeCount = mediaGuard.shortsCount
        val beforeEnd = mediaGuard.endAfter
        val beforeCooldown = mediaGuard.cooldownUntil
        val out: MediaOutcome = mediaGuard.step(
            media.snapshot, fg, SystemClock.elapsedRealtime(), now, today.toString(), r, canEnforce,
        )
        if (mediaGuard.shortsCount != beforeCount) store.shortsCount = mediaGuard.shortsCount
        if (mediaGuard.endAfter != beforeEnd) store.endAfter = mediaGuard.endAfter
        if (mediaGuard.cooldownUntil != beforeCooldown) store.cooldownUntil = mediaGuard.cooldownUntil
        for (n in out.notes) record(n.op, n.target, n.before, n.after, n.ok, "rule")
        out.close?.let { d ->
            if (!guard.isHome(d.pkg)) apply(d.copy(forceStop = !guard.isStopProtected(d.pkg)), now, guard, p)
        }
        out.endAfterFired?.let { startBreak(now, out.endAfterBreakMin, "endAfter ${it}") }
        out.brainBreak?.let { startBrainBreak("hopping", it).let { res -> if (!res.ok) record("brainBreak", "hopping", "not opened", res.detail, true, "rule") } }
        val lr = r.learning
        if (lr != null && lr.enabled && lr.trigger == "every" && canEnforce) {
            val f = out.followed
            val playing = !bbOpen.get() && f != null && f.state == PlayState.playing && f.pkg in MediaSnapshot.COOLDOWN_PACKAGES
            if (playClock.step(playing, SystemClock.elapsedRealtime()) >= lr.everyMin * 60_000L) {
                val res = startBrainBreak("every", f?.pkg)
                // Refused (a break, a cool-down…): wait another full interval rather than retry every second.
                if (!res.ok) { playClock.reset(); record("brainBreak", "every", "not opened", res.detail, true, "rule") }
            }
        }
    }

    /**
     * Opens a brain break over the video (guard thread): pauses the followed
     * session, plans the round from the child's state and shows the quiz.
     */
    private fun startBrainBreak(trigger: String, pkgHint: String?): ActionResult {
        val now = System.currentTimeMillis()
        val (r, b, s) = synchronized(lock) { Triple(rules, breakState, safety) }
        BrainBreakGate.refuse(
            r.learning, s.mode,
            breakActive = b.breakEndsAt?.let { it > now } == true,
            cooldownRunning = mediaGuard.cooldownUntil?.let { it > now } == true,
            showing = bbOpen.get(),
            overlayAllowed = brainBreak.allowed(),
        )?.let { return ActionResult(false, it) }
        if (!bbOpen.compareAndSet(false, true)) return ActionResult(false, "a brain break is already on screen")
        val lr = r.learning!!
        val (questions, skill) = synchronized(lock) {
            learn = Learner.forGrade(learn, lr.grade)
            store.learnState = learn
            Learner.plan(learn, lr.perBreak, now, Random.Default) to Maths.LADDER[learn.rung].title
        }
        val pkg = pkgHint ?: mediaGuard.followed?.takeIf { it.state == PlayState.playing }?.pkg
        bbPkg = pkg
        bbTrigger = trigger
        media(pkg, play = false)
        brainBreak.open(BrainBreakSession(questions) { Maths.easierThan(it, Random.Default) }, lr.lang, lr.voice)
        record("brainBreak", trigger, pkg ?: "no video", "opened: ${questions.size} questions, $skill", true, "agent")
        return ActionResult(true, "brain break on the TV: ${questions.size} questions")
    }

    /** Pauses or plays [pkg]'s video: media-session transport controls, else a media key over self-ADB. */
    private fun media(pkg: String?, play: Boolean) {
        if (pkg == null) return
        if (media.transport(pkg, play)) return
        if (shell.state == SelfAdb.ok) {
            try { shell.run("input keyevent ${if (play) 126 else 127}", urgent = true) } catch (_: Exception) {}
        }
    }

    private fun learningDoc(r: Rules): LearningDoc {
        val lr = r.learning ?: return LearningDoc(false)
        val l = synchronized(lock) { learn }
        val today = LocalDate.now()
        val wk = l.week.takeIf { it.week == Learner.weekOf(today) }
        return LearningDoc(
            enabled = lr.enabled,
            showing = bbOpen.get(),
            trigger = lr.trigger,
            grade = lr.grade,
            skill = Maths.LADDER.getOrNull(Learner.forGrade(l, lr.grade).rung)?.title,
            voice = if (!lr.voice) "off" else brainBreak.voiceStatus,
            week = WeekDoc(wk?.breaks ?: 0, wk?.right ?: 0, wk?.learned ?: 0),
            stronger = Learner.stronger(l, today),
            playedMin = if (lr.trigger == "every") (playClock.playedMs / 60_000).toInt() else null,
        )
    }

    /** Starts a break (the `break` action and end-after-this-one). Enforced right away in normal mode. */
    private fun startBreak(now: Long, minutes: Int, why: String): ActionResult {
        val mode = synchronized(lock) { safety.mode }
        val paused = if (mode == Mode.paused) " (agent paused: not enforced)" else ""
        val b = setBreak { it.startBreak(now, minutes).copy(mutedByAgent = mode == Mode.normal || it.mutedByAgent) }
        record("break", "$minutes min", why, "until ${Instant.ofEpochMilli(b.breakEndsAt!!)}", true, "agent")
        if (mode == Mode.normal) { stopForeground(); sound.setMuted(true) }
        return ActionResult(true, "break until ${Instant.ofEpochMilli(b.breakEndsAt)}$paused")
    }

    private data class Quad<A, B, C, D>(val a: A, val b: B, val c: C, val d: D)

    private fun apply(d: Decision, now: Long, guard: PackageGuard, p: DeviceProfile?) {
        when (d) {
            is Decision.CloseApp -> {
                val last = lastClose[d.pkg] ?: 0
                if (now - last < 3_000) return
                lastClose[d.pkg] = now
                d.card?.let { overlay.show(it) }
                val (ok, detail) = closeApp(d.pkg, d.forceStop && !guard.isStopProtected(d.pkg), p)
                record("closeApp", d.pkg, d.reason, detail, ok, "rule")
            }
            is Decision.Mute -> {
                val before = observed.volume
                val ok = sound.setMuted(true)
                if (logDue("mute", ok, now)) record("mute", "sound", "$before", "${sound.read()}", ok, "rule", reason = d.reason)
            }
            is Decision.Unmute -> {
                val ok = sound.setMuted(false)
                record("unmute", "sound", "agent mute ended", "${sound.read()}", ok, "rule")
            }
            is Decision.ClampVolume -> {
                val before = observed.volume
                val ok = sound.clampTo(d.maxLevel)
                if (logDue("clamp", ok, now)) record("clampVolume", "max ${d.maxLevel}", "$before", "${sound.read()}", ok, "rule")
            }
        }
    }

    private val lastLog = HashMap<String, Pair<Long, Boolean>>()

    /** Rule re-mutes/clamps can fire every second while a kid fights the remote: journal at most every 30 s per outcome. */
    private fun logDue(key: String, ok: Boolean, now: Long): Boolean {
        val prev = lastLog[key]
        if (prev != null && prev.second == ok && now - prev.first < 30_000) return false
        lastLog[key] = now to ok
        return true
    }

    /** Force-stop (+HOME) over self-ADB, else HOME only; without self-ADB, start the home activity. */
    private fun closeApp(pkg: String, forceStop: Boolean, p: DeviceProfile?): Pair<Boolean, String> {
        try {
            if (shell.state == SelfAdb.ok) {
                if (forceStop) {
                    val parts = TvShell.sections(shell.run(TvShell.stopCommand(pkg, home = true), urgent = true).stdout)
                    val marks = parts.getOrElse(2) { "" }
                    fgw.assume(null)
                    return marks.contains("stopped") to "force-stopped${if (marks.contains("home")) " + HOME" else ""}"
                }
                val r = shell.run(TvShell.HOME_KEY_COMMAND, urgent = true)
                fgw.assume(null)
                return r.ok to "HOME key (stop-protected)"
            }
        } catch (e: Exception) {
            Log.w(TAG, "close over self-ADB failed: ${e.message}")
        }
        return startHome(p) to "home activity (limited: no self-ADB)"
    }

    private fun startHome(p: DeviceProfile?): Boolean = try {
        val i = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        p?.launcher?.homeActivity?.takeIf { TvShell.isValidComponent(it) }?.let {
            i.component = ComponentName.unflattenFromString(it)
        }
        ctx.startActivity(i)
        fgw.assume(null)
        true
    } catch (e: Exception) {
        false
    }

    private fun record(
        op: String, target: String, before: String, after: String, ok: Boolean, source: String,
        reason: String? = null, undo: String? = null,
    ): JournalEntry {
        val e = JournalEntry(
            System.currentTimeMillis(), op, target,
            if (reason != null) "$before ($reason)" else before, after, ok, source, undo,
        )
        journal.add(e)
        return e
    }

    // ── housekeeping: self-ADB, self-heal, watchdog ──

    private fun housekeeping() {
        val now = System.currentTimeMillis()
        shell.ensureConnected(now)
        store.ensureExternalFiles()
        if (shell.state != SelfAdb.ok) return
        heal(now, periodic = lastPeriodicHeal == 0L || now - lastPeriodicHeal >= PermissionHeal.PERIOD_MS)
        if (restoring.get()) return
        val (p, mode, evAt) = synchronized(lock) { Triple(profile, safety.mode, pkgEventAt) }
        if (p == null || mode != Mode.normal) return
        val sixHours = now - store.lastWatchdogAt >= WATCHDOG_PERIOD_MS
        val pkgDue = evAt != 0L && now - evAt >= PACKAGE_SETTLE_MS
        val ytBack = now - lastQuickCheckAt >= QUICK_CHECK_MS && run {
            lastQuickCheckAt = now
            stockYouTubeBack(p)
        }
        val trigger = when {
            watchdogDueBoot -> "boot"
            pkgDue -> "package"
            ytBack -> "quick"
            sixHours -> "periodic"
            else -> return
        }
        watchdogDueBoot = false
        if (pkgDue) synchronized(lock) { if (pkgEventAt == evAt) pkgEventAt = 0 }
        runWatchdog(trigger, dryRun = false)
    }

    /** Re-grants the app-ops the TV resets on reboot, then verifies. */
    private fun heal(now: Long, periodic: Boolean) {
        val before = permissions()
        val cmds = PermissionHeal.plan(before, shell.state, lastHealAt, now, periodic)
        if (cmds.isEmpty()) return
        lastHealAt = now
        if (periodic) lastPeriodicHeal = now
        var ok = true
        for (c in cmds) {
            ok = try { shell.run(c).ok && ok } catch (_: Exception) { false }
        }
        val after = permissions()
        val usageWorks = !after.usageAccess || fgw.usageEventsWork(now)
        if (before != after || !ok) {
            record(
                "selfGrant", TvShell.AGENT_PACKAGE, "$before", "$after usageEvents=$usageWorks",
                ok && after.usageAccess && after.overlay, "agent",
            )
        }
    }

    /**
     * Cheap in-app check (no shell): stock YouTube installed and enabled for
     * this user while not allowed. Backs up package events, which can be
     * missed (e.g. `install-existing`, OTA restores).
     */
    private fun stockYouTubeBack(p: DeviceProfile): Boolean {
        val yt = p.stockYouTube?.pkg ?: return false
        val r = synchronized(lock) { rules }
        if (stockYouTubeAllowed(r, p)) return false
        return try {
            ctx.packageManager.getApplicationInfo(yt, 0).enabled
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun stockYouTubeAllowed(r: Rules, p: DeviceProfile): Boolean {
        if (r.stockYouTubeAllowed) return true
        val yt = p.stockYouTube?.pkg ?: return false
        val now = System.currentTimeMillis()
        return r.overrides.any {
            it.kind == "allowApp" && it.pkg == yt &&
                (Rules.parseIsoInstant(it.until, java.time.ZoneId.systemDefault())?.toEpochMilli() ?: 0) > now
        }
    }

    private fun runWatchdog(trigger: String, dryRun: Boolean): WatchdogReport {
        val (p, r, s) = synchronized(lock) { Triple(profile, rules, safety) }
        if (p == null) return WatchdogReport(false, null, detail = "no profile pushed")
        if (shell.state != SelfAdb.ok) return WatchdogReport(false, null, detail = "self-ADB ${shell.state.name}")
        val sh = shell.slow
        val snap = TvReader.snapshot(sh)
        val keep = Watchdog.keepDisabled(p, store.capturedKeepDisabled, snap) ?: emptySet()
        if (p.keepDisabled == null && store.capturedKeepDisabled == null && !dryRun) store.capturedKeepDisabled = keep
        val input = WatchdogInput(
            profile = p, snapshot = snap, tts = TvReader.tts(sh),
            launcher = p.launcher?.let { TvReader.launcher(sh, it) },
            stockYouTubeAllowed = stockYouTubeAllowed(r, p), keepDisabled = keep,
            safety = s, fingerprint = fingerprint,
        )
        val plan = Watchdog.plan(input)
        lastPlan = plan
        if (dryRun) return WatchdogReport(true, plan, detail = "dry run")
        val results = OpExecutor(sh, p, journal) { System.currentTimeMillis() }.execute(plan.ops, "watchdog")
        store.lastWatchdogAt = System.currentTimeMillis()
        record(
            "watchdog", trigger, "", "${results.count { it.ok }}/${results.size} ops ok, ${plan.pending.size} pending",
            results.all { it.ok }, "watchdog",
        )
        return WatchdogReport(results.all { it.ok }, plan, results)
    }

    // ── instant actions ──

    private fun <T> onGuard(block: () -> T): T = guardExec.submit(Callable { block() }).get(30, TimeUnit.SECONDS)

    private fun stopForeground(): ActionResult {
        val p = synchronized(lock) { profile }
        val guard = PackageGuard(p)
        var fg = fgw.poll()
        if ((fg == null || guard.isHome(fg)) && shell.state == SelfAdb.ok) {
            fg = try { TvShell.parseTopResumed(shell.run(TvShell.FOREGROUND_COMMAND, urgent = true).stdout) } catch (_: Exception) { fg }
        }
        if (fg == null) return ActionResult(true, "No foreground app found")
        if (guard.isHome(fg)) return ActionResult(true, "Already on the home screen")
        val (ok, detail) = closeApp(fg, !guard.isStopProtected(fg), p)
        record("stopApp", fg, "foreground", detail, ok, "agent")
        return ActionResult(ok, "$fg: $detail")
    }

    private fun setBreak(update: (BreakState) -> BreakState) = synchronized(lock) {
        breakState = update(breakState)
        store.breakState = breakState
        breakState
    }

    override fun action(req: ActionRequest): ActionResult = onGuard {
        val mode = synchronized(lock) { safety.mode }
        if (mode == Mode.safe && req.action !in setOf("unmute", "restore", "endBreak", "previewCard")) {
            return@onGuard ActionResult(false, "safe mode: report only")
        }
        val now = System.currentTimeMillis()
        val paused = if (mode == Mode.paused) " (agent paused: not enforced)" else ""
        when (req.action) {
            "mute" -> ActionResult(sound.setMuted(true).also { record("mute", "sound", "", "${sound.read()}", it, "agent") }, "${sound.read()}")
            "unmute" -> ActionResult(sound.setMuted(false).also { record("unmute", "sound", "", "${sound.read()}", it, "agent") }, "${sound.read()}")
            "volume" -> {
                val ok = sound.setPercent(req.value!!)
                record("volume", "${req.value}%", "${observed.volume}", "${sound.read()}", ok, "agent")
                ActionResult(ok, "${sound.read()}")
            }
            "stop" -> stopForeground()
            "bore" -> {
                val s = stopForeground()
                val m = sound.setMuted(true)
                record("mute", "sound", "bore", "${sound.read()}", m, "agent")
                ActionResult(s.ok && m, "stop: ${s.detail}; mute: $m")
            }
            "restore" -> {
                setBreak { it.restore() }
                if (mediaGuard.cancelEndAfter()) store.endAfter = mediaGuard.endAfter
                val cooled = mediaGuard.endCooldown()
                if (cooled) store.cooldownUntil = null
                val ok = sound.setMuted(false)
                val what = if (cooled) "breaks, timed mutes and video cool-down ended" else "breaks and timed mutes ended"
                record("restore", "sound", what, "${sound.read()}", ok, "agent")
                ActionResult(ok, if (cooled) "breaks and cool-down ended, sound on" else "breaks ended, sound on")
            }
            "break" -> startBreak(now, req.minutes!!, "")
            "previewCard" -> {
                // Display only: shows a sample card for 8 s, whatever the style or mode.
                val mood = CardMood.entries.firstOrNull { it.name == req.mood } ?: CardMood.asleep
                if (!overlay.allowed()) ActionResult(false, "no overlay permission")
                else {
                    overlay.show(Card.preview(mood))
                    record("previewCard", mood.name, "", "shown ${Overlay.SHOW_MS / 1000} s", true, "agent")
                    ActionResult(true, "card ${mood.name} shown for ${Overlay.SHOW_MS / 1000} s")
                }
            }
            "endAfter" -> {
                val res = mediaGuard.arm(media.snapshot, fgw.foreground, now, req.capMin, req.breakMin)
                if (res.ok) store.endAfter = mediaGuard.endAfter
                record("endAfter", mediaGuard.endAfter.pkg ?: "media", "armed", res.detail, res.ok, "agent")
                ActionResult(res.ok, res.detail + if (res.ok) paused else "")
            }
            "cancelEndAfter" -> {
                val was = mediaGuard.cancelEndAfter()
                store.endAfter = mediaGuard.endAfter
                record("cancelEndAfter", "media", if (was) "armed" else "not armed", "cancelled", true, "agent")
                ActionResult(true, if (was) "end-after cancelled" else "end-after was not armed")
            }
            "endBreak" -> {
                setBreak { it.endBreak() }
                record("endBreak", "break", "", "ended", true, "agent")
                ActionResult(true, "break ended; sound comes back if nothing else mutes")
            }
            "muteFor" -> {
                val b = setBreak { it.startMuteFor(now, req.minutes!!).copy(mutedByAgent = mode == Mode.normal || it.mutedByAgent) }
                if (mode == Mode.normal) sound.setMuted(true)
                record("muteFor", "${req.minutes} min", "", "until ${Instant.ofEpochMilli(b.muteEndsAt!!)}", true, "agent")
                ActionResult(true, "muted until ${Instant.ofEpochMilli(b.muteEndsAt)}$paused")
            }
            "brainBreak" -> startBrainBreak("phone", null)
            "endBrainBreak" -> {
                if (!bbOpen.get()) ActionResult(true, "no brain break on screen")
                else { brainBreak.close("phone"); ActionResult(true, "brain break closed") }
            }
            else -> ActionResult(false, "unknown action")
        }
    }

    // ── API ──

    override fun status(): StatusDoc {
        val (r, b, s, p) = synchronized(lock) { Quad(rules, breakState, safety, profile) }
        val now = System.currentTimeMillis()
        val perms = permissions()
        val selfAdb = shell.state
        val o = observed
        val plan = lastPlan
        val skew = skewMs
        val limited = PermissionHeal.limitedReasons(perms, selfAdb)
        val health = PermissionHeal.health(perms, selfAdb).toMutableList()
        health += HealthItem("profile", if (p != null) "ok" else "warn", p?.id ?: "no profile pushed")
        health += HealthItem(
            "build", if (SafetyGuard.buildApproved(s, fingerprint)) "ok" else "warn",
            if (SafetyGuard.buildApproved(s, fingerprint)) "approved" else "cleanup re-apply pending approval of this build",
        )
        health += HealthItem(
            "watchdog", if ((plan?.pending?.size ?: 0) == 0) "ok" else "warn",
            if (store.lastWatchdogAt == 0L) "not run yet" else "last run ${Instant.ofEpochMilli(store.lastWatchdogAt)}; ${plan?.pending?.size ?: 0} pending",
        )
        health += HealthItem("sound", "ok", sound.path.name)
        health += PermissionHeal.mediaHealth(perms, selfAdb)
        if (ClockSkew.warn(skew)) health += HealthItem("clock", "warn", "TV clock is ${skew!! / 1000} s off the phone")
        if (s.mode != Mode.normal) health += HealthItem("mode", "warn", "${s.mode}: ${s.modeReason}")
        val breakEnd = b.breakEndsAt?.takeIf { it > now }
        return StatusDoc(
            agentId = store.agentId,
            version = BuildConfig.VERSION_NAME,
            uptimeSec = (SystemClock.elapsedRealtime() - startedElapsed) / 1000,
            bootCount = s.bootCount,
            selfAdb = selfAdb.name,
            mode = s.mode.name,
            modeReason = s.modeReason,
            now = NowDoc(o.foreground, o.volume?.level, o.volume?.min, o.volume?.max, o.volume?.muted),
            activeRulesVersion = r.version,
            breakDoc = BreakDoc(breakEnd != null, breakEnd),
            muteForEndsAt = b.muteEndsAt?.takeIf { it > now },
            health = health,
            buildFingerprint = fingerprint,
            approvedFingerprint = s.approvedFingerprint,
            buildChangedSinceApproval = SafetyGuard.buildChangedSinceApproval(s, fingerprint),
            clockSkewWarn = ClockSkew.warn(skew),
            clockSkewSec = skew?.div(1000),
            limited = limited.isNotEmpty(),
            limitedReasons = limited,
            needsPhoneGrant = PermissionHeal.phoneMustGrant(perms, selfAdb),
            soundPath = sound.path.name,
            activeReasons = activeReasons,
            watchdogPending = plan?.pending?.size ?: 0,
            lastWatchdogAt = store.lastWatchdogAt.takeIf { it > 0 },
            profileId = p?.id,
            media = mediaGuard.mediaDoc(SystemClock.elapsedRealtime()),
            endAfter = mediaGuard.endAfterDoc(),
            shorts = mediaGuard.shortsDoc(r, LocalDate.now().toString(), now),
            learning = learningDoc(r),
        )
    }

    override fun rules(): Rules = synchronized(lock) { rules }

    override fun putRules(body: String): RulesPut = synchronized(lock) {
        val r = RulesUpdate.put(rules, body, Instant.now().toString())
        if (r is RulesPut.Accepted) {
            rules = r.rules
            store.rules = rules
            journal.add(JournalEntry(System.currentTimeMillis(), "rules", "v${r.rules.version}", "", r.rules.updatedBy, true, "agent"))
        }
        r
    }

    override fun journal(since: Long): List<JournalEntry> = journal.since(since)

    override fun setMode(mode: Mode): ActionResult {
        val prev = synchronized(lock) {
            val p = safety.mode
            safety = SafetyGuard.setMode(safety, mode, "set by phone")
            store.safety = safety
            p
        }
        record("mode", "agent", prev.name, mode.name, true, "agent")
        if (mode != Mode.normal && bbOpen.get()) brainBreak.close("agent ${mode.name}")
        if (mode == Mode.normal) shell.kick()
        return ActionResult(true, "mode ${mode.name}")
    }

    override fun approveBuild(): ActionResult {
        synchronized(lock) {
            safety = SafetyGuard.approveBuild(safety, fingerprint)
            store.safety = safety
        }
        record("approveBuild", fingerprint, "", "approved", true, "agent")
        return ActionResult(true, fingerprint)
    }

    override fun pushProfile(body: String): ActionResult {
        val p = DeviceProfile.parse(body)
        synchronized(lock) {
            profile = p
            store.profile = p
            store.capturedKeepDisabled = null
            pkgEventAt = System.currentTimeMillis() - 10_000 // run the watchdog on the next housekeeping pass
        }
        record("profile", p.id, "", "${p.cleanup.size} cleanup, ${p.neverTouch.size} never-touch", true, "agent")
        return ActionResult(true, "profile ${p.id} stored")
    }

    override fun restore(req: RestoreRequest): RestoreResult {
        if (shell.state != SelfAdb.ok) {
            return RestoreResult(false, RestorePlan(req.target, emptyList(), emptyList()),
                mode = safety.mode.name, detail = "self-ADB ${shell.state.name}: run the restore from the phone over ADB")
        }
        if (!restoring.compareAndSet(false, true)) {
            return RestoreResult(false, RestorePlan(req.target, emptyList(), emptyList()),
                mode = safety.mode.name, detail = "a restore is already running")
        }
        try {
            return slowExec.submit(Callable { doRestore(req) }).get(5, TimeUnit.MINUTES)
        } finally {
            restoring.set(false)
        }
    }

    private fun doRestore(req: RestoreRequest): RestoreResult {
        val p = synchronized(lock) { profile }
        val sh = shell.slow
        val snap = TvReader.snapshot(sh)
        val plan = when (req.target) {
            RestorePlanner.STOCK -> {
                if (p == null) return RestoreResult(false, RestorePlan(req.target, emptyList(), emptyList()),
                    mode = safety.mode.name, detail = "no profile pushed")
                RestorePlanner.backToStock(p, snap, p.launcher?.let { TvReader.launcher(sh, it) }, req.alsoRemoveLauncherHelper)
            }
            else -> RestorePlanner.undoBoretube(p, journal.all(), req.journal, snap)
        }
        if (req.dryRun) return RestoreResult(true, plan, mode = safety.mode.name, detail = "dry run")
        record("restore", req.target, "", "${plan.steps.size} steps", true, "agent")
        val results = OpExecutor(sh, p, journal) { System.currentTimeMillis() }.execute(plan.steps, "agent")
        val wasMuted = synchronized(lock) {
            val m = breakState.mutedByAgent
            breakState = BreakState()
            store.breakState = breakState
            safety = SafetyGuard.setMode(safety, Mode.paused, "after restore ${req.target}")
            store.safety = safety
            m
        }
        if (wasMuted) onGuard { sound.setMuted(false) }
        record("mode", "agent", "", "paused (after restore)", true, "agent")
        return RestoreResult(results.all { it.ok }, plan, results, Mode.paused.name, "restore ${req.target} done; agent paused")
    }

    override fun watchdog(req: WatchdogRequest): WatchdogReport =
        slowExec.submit(Callable { runWatchdog("phone", req.dryRun) }).get(5, TimeUnit.MINUTES)

    override fun phoneTimeHint(phoneEpochMs: Long) {
        val skew = ClockSkew.skewMs(System.currentTimeMillis(), phoneEpochMs)
        val wasWarn = ClockSkew.warn(skewMs)
        skewMs = skew
        if (ClockSkew.warn(skew) && !wasWarn) record("clockSkew", "tv clock", "", "${skew / 1000} s off the phone", false, "agent")
    }

    companion object {
        private const val TAG = "BoretubeGuard"
        const val WATCHDOG_PERIOD_MS = 6 * 3600_000L
        const val QUICK_CHECK_MS = 60_000L
        const val PACKAGE_SETTLE_MS = 3_000L
    }
}
