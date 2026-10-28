package com.rakesh.boretube.agent.android

import android.annotation.SuppressLint
import android.content.Context
import android.content.SharedPreferences
import com.rakesh.boretube.agent.core.AgentJson
import com.rakesh.boretube.agent.core.BreakState
import com.rakesh.boretube.agent.core.DeviceProfile
import com.rakesh.boretube.agent.core.Journal
import com.rakesh.boretube.agent.core.Rules
import com.rakesh.boretube.agent.core.SafetyState
import com.rakesh.boretube.agent.core.SoundPath
import com.rakesh.boretube.agent.core.TvTimeState
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import java.io.File
import java.security.SecureRandom

/**
 * Everything the agent persists. SharedPreferences for small state, a file for
 * the journal, and the token / agent_id in getExternalFilesDir(null)
 * (= /sdcard/Android/data/com.rakesh.boretube.agent/files/, readable by ADB shell).
 */
@SuppressLint("ApplySharedPref") // commit(): rules/break/safety must survive a crash right after a change
class AgentStore(private val ctx: Context) {
    private val prefs: SharedPreferences = ctx.getSharedPreferences("agent", Context.MODE_PRIVATE)
    private val journalFile = File(ctx.filesDir, "journal.json")
    private val externalDir: File? get() = ctx.getExternalFilesDir(null)

    // ── identity ──

    val agentId: String by lazy {
        val id = prefs.getString(K_AGENT_ID, null) ?: randomHex(8).also { prefs.edit().putString(K_AGENT_ID, it).apply() }
        writeExternal("agent_id", id)
        id
    }

    /** Bearer token: created once, mirrored to the external file for the phone to `cat`. */
    val token: String by lazy {
        val t = prefs.getString(K_TOKEN, null) ?: randomHex(32).also { prefs.edit().putString(K_TOKEN, it).apply() }
        writeExternal("token", t)
        t
    }

    /** Re-writes token / agent_id files if someone deleted them. */
    fun ensureExternalFiles() {
        val dir = externalDir ?: return
        if (!File(dir, "token").exists()) writeExternal("token", token)
        if (!File(dir, "agent_id").exists()) writeExternal("agent_id", agentId)
    }

    private fun writeExternal(name: String, value: String) {
        try {
            val dir = externalDir ?: return
            dir.mkdirs()
            val tmp = File(dir, "$name.tmp")
            tmp.writeText(value)
            tmp.renameTo(File(dir, name))
        } catch (_: Exception) {
            // External storage not mounted yet; ensureExternalFiles retries.
        }
    }

    // ── typed state ──

    var rules: Rules
        get() = prefs.getString(K_RULES, null)?.let { runCatching { Rules.parse(it) }.getOrNull() } ?: Rules()
        set(v) { prefs.edit().putString(K_RULES, v.toJson()).commit() }

    var profile: DeviceProfile?
        get() = prefs.getString(K_PROFILE, null)?.let { runCatching { DeviceProfile.parse(it) }.getOrNull() }
        set(v) { prefs.edit().apply { if (v == null) remove(K_PROFILE) else putString(K_PROFILE, v.toJson()) }.commit() }

    var breakState: BreakState
        get() = BreakState.parse(prefs.getString(K_BREAK, null))
        set(v) { prefs.edit().putString(K_BREAK, v.toJson()).commit() }

    var safety: SafetyState
        get() = prefs.getString(K_SAFETY, null)?.let {
            runCatching { AgentJson.decodeFromString(SafetyState.serializer(), it) }.getOrNull()
        } ?: SafetyState()
        set(v) { prefs.edit().putString(K_SAFETY, AgentJson.encodeToString(SafetyState.serializer(), v)).commit() }

    var tvTime: TvTimeState
        get() = prefs.getString(K_TVTIME, null)?.let {
            runCatching { AgentJson.decodeFromString(TvTimeState.serializer(), it) }.getOrNull()
        } ?: TvTimeState()
        set(v) { prefs.edit().putString(K_TVTIME, AgentJson.encodeToString(TvTimeState.serializer(), v)).apply() }

    var soundPath: SoundPath
        get() = SoundPath.parse(prefs.getString(K_SOUND, null))
        set(v) { prefs.edit().putString(K_SOUND, v.name).apply() }

    /** Cleanup packages captured as "keep disabled" when the profile has no keepDisabled. */
    var capturedKeepDisabled: Set<String>?
        get() = prefs.getString(K_KEEP, null)?.let {
            runCatching { AgentJson.decodeFromString(ListSerializer(String.serializer()), it).toSet() }.getOrNull()
        }
        set(v) {
            prefs.edit().apply {
                if (v == null) remove(K_KEEP)
                else putString(K_KEEP, AgentJson.encodeToString(ListSerializer(String.serializer()), v.sorted()))
            }.apply()
        }

    var lastWatchdogAt: Long
        get() = prefs.getLong(K_LAST_WD, 0)
        set(v) { prefs.edit().putLong(K_LAST_WD, v).apply() }

    // ── journal ──

    fun loadJournal(): Journal = Journal(1000, Journal.parseEntries(readJournal())) { saveJournal(it) }

    private fun readJournal(): String? = try { if (journalFile.exists()) journalFile.readText() else null } catch (_: Exception) { null }

    @Synchronized
    private fun saveJournal(j: Journal) {
        try {
            val tmp = File(ctx.filesDir, "journal.json.tmp")
            tmp.writeText(j.toJson())
            tmp.renameTo(journalFile)
        } catch (_: Exception) {
        }
    }

    companion object {
        private const val K_AGENT_ID = "agentId"
        private const val K_TOKEN = "token"
        private const val K_RULES = "rules"
        private const val K_PROFILE = "profile"
        private const val K_BREAK = "break"
        private const val K_SAFETY = "safety"
        private const val K_TVTIME = "tvTime"
        private const val K_SOUND = "soundPath"
        private const val K_KEEP = "keepDisabled"
        private const val K_LAST_WD = "lastWatchdogAt"

        fun randomHex(bytes: Int): String {
            val b = ByteArray(bytes)
            SecureRandom().nextBytes(b)
            return b.joinToString("") { "%02x".format(it) }
        }
    }
}
