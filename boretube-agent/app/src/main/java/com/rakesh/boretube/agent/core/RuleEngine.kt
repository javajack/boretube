package com.rakesh.boretube.agent.core

import java.time.Instant
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter

/** What the TV looks like right now. */
data class Observed(
    val foreground: String?,
    val volume: VolumeState?,
    val screenOn: Boolean = true,
    /** Today's counted TV time. */
    val tvTimeUsedMs: Long = 0,
)

/** The explicit-style full-screen card. */
data class Card(val message: String, val backAt: String?, val sub: String? = null) {
    val text: String get() = if (backAt != null) "$message · back at $backAt" else if (sub != null) "$message $sub" else message
}

sealed class Decision {
    /** Close [pkg]: force-stop it (unless stop-protected), then HOME; show [card] when explicit. */
    data class CloseApp(val pkg: String, val forceStop: Boolean, val reason: String, val card: Card?) : Decision()
    data class Mute(val reason: String) : Decision()
    /** The once-only unmute after every mute reason ended. */
    data class Unmute(val reason: String) : Decision()
    /** Step the volume down to [maxLevel]. */
    data class ClampVolume(val maxLevel: Int, val reason: String) : Decision()
}

data class EngineResult(
    val decisions: List<Decision>,
    val breakState: BreakState,
    /** Active reasons, for status ("break", "alwaysMute", "tvTimeSchedule", ...). */
    val active: List<String>,
    val breakEndsAt: Long?,
)

/** Pure rule evaluation. No Android, no I/O. */
object RuleEngine {
    private val HHMM = DateTimeFormatter.ofPattern("HH:mm")

    /** Never closed by any rule. */
    private val NEVER_ENFORCE = setOf(TvShell.AGENT_PACKAGE, "android", "com.android.systemui")

    /** App rules (allow/block lists) don't apply to settings and system plumbing. */
    private val APP_RULE_EXEMPT = setOf(
        "com.android.tv.settings", "com.android.settings", "com.google.android.katniss",
        "com.google.android.tungsten.setupwraith",
    )

    fun decide(
        rules: Rules,
        breakState: BreakState,
        now: ZonedDateTime,
        observed: Observed,
        guard: PackageGuard,
    ): EngineResult {
        val nowMs = now.toInstant().toEpochMilli()
        val zone = now.zone
        val live = rules.overrides.mapNotNull { o ->
            val until = Rules.parseIsoInstant(o.until, zone) ?: return@mapNotNull null
            if (until.toEpochMilli() > nowMs) o to until.toEpochMilli() else null
        }
        val allowNow = live.filter { it.first.kind == "allowApp" }.mapNotNull { it.first.pkg }.toSet()
        val overrideMute = live.any { it.first.kind == "muteUntil" }
        val overrideBreakEnd = live.filter { it.first.kind == "breakUntil" }.maxOfOrNull { it.second }
        val breakEnd = listOfNotNull(breakState.breakEndsAt?.takeIf { it > nowMs }, overrideBreakEnd).maxOrNull()

        val active = mutableListOf<String>()
        if (breakEnd != null) active += "break"
        if (rules.alwaysMute) active += "alwaysMute"
        if (breakState.muteForActive(nowMs)) active += "muteFor"
        if (overrideMute) active += "muteUntil"

        val wantMute = breakEnd != null || rules.alwaysMute || breakState.muteForActive(nowMs) || overrideMute
        val decisions = mutableListOf<Decision>()

        // ── app / TV-time ──
        val fg = observed.foreground
        val explicit = rules.style == "explicit"
        fun backAt(ms: Long) = HHMM.format(Instant.ofEpochMilli(ms).atZone(zone))
        val scheduleEnd = Schedule.activeWindowEnd(rules.tvTime.schedule, now)
        val limitMs = rules.tvTime.dailyLimitMin * 60_000L
        val limitHit = rules.tvTime.dailyLimitMin > 0 && observed.tvTimeUsedMs >= limitMs
        if (scheduleEnd != null) active += "tvTimeSchedule"
        if (limitHit) active += "dailyLimit"

        if (fg != null && observed.screenOn && !guard.isHome(fg) && fg !in NEVER_ENFORCE) {
            val close: Pair<String, Card>? = when {
                breakEnd != null -> "break" to Card("Break time", backAt(breakEnd))
                fg in allowNow -> null
                scheduleEnd != null -> "tvTimeSchedule" to Card("TV time is over", HHMM.format(scheduleEnd))
                limitHit -> "dailyLimit" to Card(
                    "Today's TV time is used up",
                    HHMM.format(now.toLocalDate().plusDays(1).atStartOfDay(zone)),
                )
                appRuleBlocks(rules.allowedApps, fg, guard) -> "appNotAllowed" to Card("This app isn't allowed", null)
                else -> null
            }
            if (close != null) {
                decisions += Decision.CloseApp(
                    pkg = fg,
                    forceStop = !guard.isStopProtected(fg),
                    reason = close.first,
                    card = if (explicit) close.second else null,
                )
            }
        }

        // ── sound ──
        val step = MuteLatch.step(breakState, nowMs, wantMute)
        val vol = observed.volume
        if (step.mute && vol?.muted != true) decisions += Decision.Mute(active.firstOrNull() ?: "rule")
        if (step.unmuteOnce) decisions += Decision.Unmute("mute reasons ended")
        if (rules.volumeLimit.enabled && vol != null) {
            val maxLevel = vol.levelForPercent(rules.volumeLimit.maxPercent)
            if (vol.level > maxLevel) decisions += Decision.ClampVolume(maxLevel, "volumeLimit")
        }
        return EngineResult(decisions, step.state, active, breakEnd)
    }

    fun appRuleBlocks(apps: AllowedApps, pkg: String, guard: PackageGuard): Boolean {
        if (guard.isInput(pkg) || guard.isStopProtected(pkg) || pkg in APP_RULE_EXEMPT) return false
        return when (apps.mode) {
            "allowlist" -> pkg !in apps.packages
            "blocklist" -> pkg in apps.packages
            else -> false
        }
    }
}
