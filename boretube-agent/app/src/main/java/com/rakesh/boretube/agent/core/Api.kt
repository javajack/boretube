package com.rakesh.boretube.agent.core

import kotlinx.serialization.Serializable
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.io.InputStream
import java.io.OutputStream

const val API_VERSION = 1

@Serializable
data class NowDoc(val foreground: String?, val volume: Int?, val min: Int?, val max: Int?, val muted: Boolean?)

@Serializable
data class BreakDoc(val active: Boolean, val endsAt: Long?)

/** `GET /v1/status` (contract v1, plus a few extra fields the phone may ignore). */
@Serializable
data class StatusDoc(
    val agentId: String,
    val version: String,
    val api: Int = API_VERSION,
    val uptimeSec: Long,
    val bootCount: Int,
    /** `sys.boot.reason` of this boot (`cold` after a power cut), if readable. */
    val bootReason: String? = null,
    /** ok | needsApproval | unavailable */
    val selfAdb: String,
    /** normal | safe | paused */
    val mode: String,
    val modeReason: String = "",
    val now: NowDoc,
    val activeRulesVersion: Int,
    @kotlinx.serialization.SerialName("break") val breakDoc: BreakDoc,
    val muteForEndsAt: Long? = null,
    val health: List<HealthItem>,
    val buildFingerprint: String?,
    val approvedFingerprint: String? = null,
    val buildChangedSinceApproval: Boolean,
    val clockSkewWarn: Boolean,
    val clockSkewSec: Long? = null,
    /** True when self-ADB or a permission is missing (phone shows "limited"). */
    val limited: Boolean = false,
    val limitedReasons: List<String> = emptyList(),
    /** The phone should re-run the ADB grant commands (self-heal impossible). */
    val needsPhoneGrant: Boolean = false,
    /** audioManager | adbKeys | untested */
    val soundPath: String = "untested",
    val activeReasons: List<String> = emptyList(),
    val watchdogPending: Int = 0,
    val lastWatchdogAt: Long? = null,
    val profileId: String? = null,
    /** Agent 1.1.0+: the followed media session (absent when none or no media access). */
    val media: MediaDoc? = null,
    val endAfter: EndAfterDoc = EndAfterDoc(false),
    val shorts: ShortsDoc = ShortsDoc("off", 0),
    /** Agent 1.4.0+: brain breaks. */
    val learning: LearningDoc = LearningDoc(false),
)

@Serializable
data class ActionRequest(
    val action: String,
    val value: Int? = null,
    val minutes: Int? = null,
    /** endAfter: cap in minutes (default 45). */
    val capMin: Int? = null,
    /** endAfter: break length once the video is over (default 60). */
    val breakMin: Int? = null,
    /** previewCard (1.3.0+): asleep | calm | guard (default asleep). */
    val mood: String? = null,
) {
    fun validate(): String? = when (action) {
        "mute", "unmute", "stop", "bore", "restore", "endBreak", "cancelEndAfter", "brainBreak", "endBrainBreak" -> null
        "previewCard" -> if (mood != null && CardMood.entries.none { it.name == mood }) "previewCard mood must be asleep|calm|guard" else null
        "endAfter" -> when {
            capMin != null && capMin !in 1..1440 -> "endAfter capMin must be 1..1440"
            breakMin != null && breakMin !in 1..1440 -> "endAfter breakMin must be 1..1440"
            else -> null
        }
        "volume" -> if (value == null || value !in 0..100) "volume needs value 0..100" else null
        "break", "muteFor" -> if (minutes == null || minutes !in 1..1440) "$action needs minutes 1..1440" else null
        else -> "unknown action \"$action\""
    }
}

@Serializable
data class ActionResult(val ok: Boolean, val detail: String = "")

@Serializable
data class ModeRequest(val mode: String)

@Serializable
data class RestoreRequest(
    val target: String,
    val dryRun: Boolean = false,
    val alsoRemoveLauncherHelper: Boolean = false,
    /** Optional phone-side journal steps to undo too (undoBoretube). */
    val journal: List<ExternalStep> = emptyList(),
)

@Serializable
data class RestoreResult(
    val ok: Boolean,
    val plan: RestorePlan,
    val results: List<JournalEntry> = emptyList(),
    val mode: String,
    val detail: String = "",
)

@Serializable
data class WatchdogRequest(val dryRun: Boolean = true)

@Serializable
data class WatchdogReport(
    val ok: Boolean,
    val plan: WatchdogPlan?,
    val results: List<JournalEntry> = emptyList(),
    val detail: String = "",
)

/** What the HTTP layer needs from the agent. Implemented by GuardController; faked in tests. */
interface AgentApi {
    fun status(): StatusDoc
    fun rules(): Rules
    fun putRules(body: String): RulesPut
    fun action(req: ActionRequest): ActionResult
    fun journal(since: Long): List<JournalEntry>
    fun setMode(mode: Mode): ActionResult
    fun approveBuild(): ActionResult
    /** Throws IllegalArgumentException for an invalid profile. */
    fun pushProfile(body: String): ActionResult
    fun restore(req: RestoreRequest): RestoreResult
    fun watchdog(req: WatchdogRequest): WatchdogReport
    fun phoneTimeHint(phoneEpochMs: Long)
}

/** Routes `/v1/...` requests with bearer auth. Pure; tested with in-memory streams. */
class Router(private val token: () -> String, private val api: AgentApi) {

    fun handle(req: HttpRequest): HttpResponse = try {
        route(req)
    } catch (e: IllegalArgumentException) {
        error(400, e.message ?: "bad request")
    } catch (e: kotlinx.serialization.SerializationException) {
        error(400, "bad JSON: ${e.message}")
    } catch (e: Exception) {
        error(500, "${e.javaClass.simpleName}: ${e.message}")
    }

    private fun route(req: HttpRequest): HttpResponse {
        if (!req.path.startsWith("/v1/")) return error(404, "not found")
        if (!Auth.authorized(req.header("authorization"), token())) return error(401, "missing or wrong token")
        ClockSkew.parsePhoneTime(req.header("x-phone-time"))?.let { api.phoneTimeHint(it) }
        val j = AgentJson
        return when (req.method to req.path) {
            "GET" to "/v1/status" -> ok(j.encodeToString(StatusDoc.serializer(), api.status()))
            "GET" to "/v1/rules" -> ok(api.rules().toJson())
            "PUT" to "/v1/rules" -> when (val r = api.putRules(req.body)) {
                is RulesPut.Accepted -> ok(r.rules.toJson())
                is RulesPut.Conflict -> HttpResponse(409, r.current.toJson())
                is RulesPut.Invalid -> error(400, r.message)
            }
            "POST" to "/v1/action" -> {
                val a = j.decodeFromString(ActionRequest.serializer(), req.body)
                a.validate()?.let { return error(400, it) }
                ok(j.encodeToString(ActionResult.serializer(), api.action(a)))
            }
            "GET" to "/v1/journal" -> {
                val since = req.query["since"]?.let { it.toLongOrNull() ?: return error(400, "since must be epoch ms") } ?: 0L
                ok(j.encodeToString(ListSerializer(JournalEntry.serializer()), api.journal(since)))
            }
            "POST" to "/v1/mode" -> {
                val m = j.decodeFromString(ModeRequest.serializer(), req.body)
                val mode = Mode.parse(m.mode) ?: return error(400, "mode must be normal|paused|safe")
                ok(j.encodeToString(ActionResult.serializer(), api.setMode(mode)))
            }
            "POST" to "/v1/approveBuild" -> ok(j.encodeToString(ActionResult.serializer(), api.approveBuild()))
            "POST" to "/v1/profile" -> ok(j.encodeToString(ActionResult.serializer(), api.pushProfile(req.body)))
            "POST" to "/v1/restore" -> {
                val r = j.decodeFromString(RestoreRequest.serializer(), req.body)
                if (r.target != RestorePlanner.UNDO && r.target != RestorePlanner.STOCK) {
                    return error(400, "target must be undoBoretube|stock")
                }
                ok(j.encodeToString(RestoreResult.serializer(), api.restore(r)))
            }
            "GET" to "/v1/watchdog" -> ok(j.encodeToString(WatchdogReport.serializer(), api.watchdog(WatchdogRequest(dryRun = true))))
            "POST" to "/v1/watchdog" -> {
                val w = if (req.body.isBlank()) WatchdogRequest(dryRun = false)
                else j.decodeFromString(WatchdogRequest.serializer(), req.body)
                ok(j.encodeToString(WatchdogReport.serializer(), api.watchdog(w)))
            }
            else -> if (KNOWN.contains(req.path)) error(405, "method not allowed") else error(404, "not found")
        }
    }

    private fun ok(body: String) = HttpResponse(200, body)

    companion object {
        private val KNOWN = setOf(
            "/v1/status", "/v1/rules", "/v1/action", "/v1/journal", "/v1/mode",
            "/v1/approveBuild", "/v1/profile", "/v1/restore", "/v1/watchdog",
        )

        fun error(status: Int, message: String) = HttpResponse(
            status,
            buildJsonObject { put("error", JsonPrimitive(message)); put("status", status) }.toString(),
        )

        /** Reads one request from [input], answers on [output]. Used by the socket server and tests. */
        fun serve(router: Router, input: InputStream, output: OutputStream) {
            val resp = try {
                val req = HttpRequest.parse(input) ?: return
                router.handle(req)
            } catch (e: HttpParseException) {
                error(e.status, e.message ?: "bad request")
            }
            resp.write(output)
        }
    }
}
