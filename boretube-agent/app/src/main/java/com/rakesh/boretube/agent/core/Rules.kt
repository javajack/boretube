package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeParseException

@Serializable
data class AllowedApps(
    /** off | allowlist | blocklist */
    val mode: String = "off",
    val packages: List<String> = emptyList(),
)

@Serializable
data class VolumeLimit(val maxPercent: Int = 100, val enabled: Boolean = false)

@Serializable
data class ScheduleWindow(
    /** ISO weekdays the window *starts* on: 1 = Monday … 7 = Sunday. */
    val days: List<Int> = listOf(1, 2, 3, 4, 5, 6, 7),
    val from: String,
    val to: String,
)

@Serializable
data class TvTimeRules(
    val schedule: List<ScheduleWindow> = emptyList(),
    /** 0 = no daily limit. */
    val dailyLimitMin: Int = 0,
)

@Serializable
data class Override(
    /** allowApp | muteUntil | breakUntil */
    val kind: String,
    val pkg: String? = null,
    val until: String,
)

/** The rules document (contract v1). */
@Serializable
data class Rules(
    val version: Int = 0,
    val updatedBy: String = "",
    val updatedAt: String = "",
    /** sneaky | explicit */
    val style: String = "sneaky",
    val allowedApps: AllowedApps = AllowedApps(),
    val volumeLimit: VolumeLimit = VolumeLimit(),
    val alwaysMute: Boolean = false,
    val tvTime: TvTimeRules = TvTimeRules(),
    val overrides: List<Override> = emptyList(),
    val stockYouTubeAllowed: Boolean = false,
    /** Optional (agent 1.1.0+): Shorts detection and enforcement. Absent = off. */
    val shorts: ShortsRules? = null,
) {
    fun toJson(): String = AgentJson.encodeToString(serializer(), this)

    /** Throws IllegalArgumentException describing the first problem. */
    fun validate() {
        require(style in STYLES) { "style must be sneaky|explicit" }
        require(allowedApps.mode in APP_MODES) { "allowedApps.mode must be off|allowlist|blocklist" }
        for (p in allowedApps.packages) require(TvShell.isValidPackage(p)) { "invalid package \"$p\"" }
        require(volumeLimit.maxPercent in 0..100) { "volumeLimit.maxPercent must be 0..100" }
        require(tvTime.dailyLimitMin in 0..(24 * 60)) { "tvTime.dailyLimitMin must be 0..1440" }
        for (w in tvTime.schedule) {
            require(w.days.isNotEmpty() && w.days.all { it in 1..7 }) { "schedule days must be 1..7" }
            requireNotNull(parseHhMm(w.from)) { "bad schedule time \"${w.from}\"" }
            requireNotNull(parseHhMm(w.to)) { "bad schedule time \"${w.to}\"" }
        }
        for (o in overrides) {
            require(o.kind in OVERRIDE_KINDS) { "override kind must be allowApp|muteUntil|breakUntil" }
            if (o.kind == "allowApp") {
                require(o.pkg != null && TvShell.isValidPackage(o.pkg)) { "allowApp override needs a valid pkg" }
            }
            requireNotNull(parseIsoInstant(o.until, ZoneId.systemDefault())) { "bad override until \"${o.until}\"" }
        }
        shorts?.let {
            require(it.mode in ShortsRules.MODES) { "shorts.mode must be off|block|budget|report|cooldown" }
            require(it.perDay in 0..1000) { "shorts.perDay must be 0..1000" }
            require(it.cooldownMin == null || it.cooldownMin in 1..120) { "shorts.cooldownMin must be 1..120" }
        }
    }

    companion object {
        val STYLES = setOf("sneaky", "explicit")
        val APP_MODES = setOf("off", "allowlist", "blocklist")
        val OVERRIDE_KINDS = setOf("allowApp", "muteUntil", "breakUntil")

        fun parse(text: String): Rules = AgentJson.decodeFromString(serializer(), text)

        fun parseHhMm(s: String): LocalTime? {
            val m = Regex("^(\\d{1,2}):(\\d{2})$").matchEntire(s.trim()) ?: return null
            val h = m.groupValues[1].toInt()
            val min = m.groupValues[2].toInt()
            if (h == 24 && min == 0) return LocalTime.MIDNIGHT
            if (h !in 0..23 || min !in 0..59) return null
            return LocalTime.of(h, min)
        }

        /** ISO with offset/Z, or a local date-time interpreted in [zone]. */
        fun parseIsoInstant(s: String, zone: ZoneId): Instant? {
            try { return OffsetDateTime.parse(s).toInstant() } catch (_: DateTimeParseException) {}
            try { return Instant.parse(s) } catch (_: DateTimeParseException) {}
            try { return LocalDateTime.parse(s).atZone(zone).toInstant() } catch (_: DateTimeParseException) {}
            return null
        }
    }
}

/** Outcome of `PUT /v1/rules`. */
sealed class RulesPut {
    data class Accepted(val rules: Rules) : RulesPut()
    data class Conflict(val current: Rules) : RulesPut()
    data class Invalid(val message: String) : RulesPut()
}

object RulesUpdate {
    /**
     * Accepts [incomingText] only when its `version` equals [current]'s. The
     * stored document gets `version + 1`; `updatedAt` defaults to [nowIso].
     */
    fun put(current: Rules, incomingText: String, nowIso: String): RulesPut {
        val incoming = try {
            Rules.parse(incomingText)
        } catch (e: Exception) {
            return RulesPut.Invalid("bad rules JSON: ${e.message}")
        }
        if (incoming.version != current.version) return RulesPut.Conflict(current)
        try {
            incoming.validate()
        } catch (e: IllegalArgumentException) {
            return RulesPut.Invalid(e.message ?: "invalid rules")
        }
        return RulesPut.Accepted(
            incoming.copy(
                version = current.version + 1,
                updatedAt = incoming.updatedAt.ifEmpty { nowIso },
            ),
        )
    }
}
