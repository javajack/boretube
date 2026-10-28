package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable
import java.time.LocalDate
import java.time.ZonedDateTime

/** Blocked-window maths for `tvTime.schedule`. */
object Schedule {
    /**
     * If [now] falls inside a blocked window, returns when that window ends.
     * A window starts on each listed ISO weekday at `from` and runs to the next
     * `to`; when `to <= from` it crosses midnight into the following day (so a
     * Friday 21:00–07:00 window also covers Saturday 02:00). `from == to` blocks
     * the whole day (24 h). Overlapping windows extend to the latest end.
     */
    fun activeWindowEnd(schedule: List<ScheduleWindow>, now: ZonedDateTime): ZonedDateTime? {
        var end: ZonedDateTime? = null
        for (w in schedule) {
            val from = Rules.parseHhMm(w.from) ?: continue
            val to = Rules.parseHhMm(w.to) ?: continue
            // A window that started today or yesterday can cover now (max 24 h long).
            for (back in 0L..1L) {
                val startDay = now.toLocalDate().minusDays(back)
                if (startDay.dayOfWeek.value !in w.days) continue
                val start = startDay.atTime(from).atZone(now.zone)
                val stop = if (to.isAfter(from)) startDay.atTime(to).atZone(now.zone)
                else startDay.plusDays(1).atTime(to).atZone(now.zone)
                if (!now.isBefore(start) && now.isBefore(stop)) {
                    if (end == null || stop.isAfter(end)) end = stop
                }
            }
        }
        return end
    }
}

/** Persisted daily TV-time counter. */
@Serializable
data class TvTimeState(val day: String = "", val usedMs: Long = 0, val lastTickMs: Long = 0)

/**
 * TV-time accounting: counts only while the screen is on and a real app (not
 * Home, not an HDMI/tuner input) is in the foreground. Resets at local midnight.
 * Gaps longer than [maxGapMs] (agent dead, TV asleep) are not counted.
 */
class TvTimeCounter(var state: TvTimeState = TvTimeState(), private val maxGapMs: Long = 5_000) {

    fun tick(nowMs: Long, today: LocalDate, screenOn: Boolean, counts: Boolean): TvTimeState {
        val day = today.toString()
        var s = state
        if (s.day != day) s = TvTimeState(day = day, usedMs = 0, lastTickMs = nowMs)
        val gap = nowMs - s.lastTickMs
        val add = if (screenOn && counts && gap in 1..maxGapMs) gap else 0
        s = s.copy(usedMs = s.usedMs + add, lastTickMs = nowMs)
        state = s
        return s
    }

    fun usedMinutes(today: LocalDate): Long = if (state.day == today.toString()) state.usedMs / 60_000 else 0

    fun usedMs(today: LocalDate): Long = if (state.day == today.toString()) state.usedMs else 0

    companion object {
        /** Whether this foreground counts as TV time. */
        fun counts(foreground: String?, guard: PackageGuard): Boolean =
            foreground != null && !guard.isHome(foreground) && !guard.isInput(foreground) &&
                foreground != TvShell.AGENT_PACKAGE
    }
}
