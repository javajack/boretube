package com.rakesh.boretube.agent.core

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream

class RulesJsonTest {
    private val contractExample = """
        {
          "version": 3,
          "updatedBy": "phone name",
          "updatedAt": "2026-10-28T10:00:00Z",
          "style": "sneaky",
          "allowedApps": {"mode": "allowlist", "packages": ["org.smarttube.stable"]},
          "volumeLimit": {"maxPercent": 30, "enabled": true},
          "alwaysMute": false,
          "tvTime": {"schedule": [{"days": [1, 2, 3, 4, 5], "from": "21:00", "to": "07:00"}], "dailyLimitMin": 0},
          "overrides": [{"kind": "allowApp", "pkg": "com.google.android.youtube.tv", "until": "2026-10-28T23:00:00+05:30"}],
          "stockYouTubeAllowed": false,
          "futureField": {"ignored": true}
        }
    """.trimIndent()

    @Test fun roundTripsTheContractDocument() {
        val r = Rules.parse(contractExample)
        r.validate()
        assertEquals(3, r.version)
        assertEquals(30, r.volumeLimit.maxPercent)
        assertEquals(listOf(1, 2, 3, 4, 5), r.tvTime.schedule.single().days)
        assertEquals(r, Rules.parse(r.toJson()))
        assertEquals(Rules(), Rules.parse("{}"))
    }

    @Test fun putRequiresTheCurrentVersion() {
        val cur = Rules(version = 3)
        val ok = RulesUpdate.put(cur, contractExample, "2026-10-28T11:00:00Z")
        assertTrue(ok is RulesPut.Accepted)
        assertEquals(4, (ok as RulesPut.Accepted).rules.version)
        assertEquals("2026-10-28T10:00:00Z", ok.rules.updatedAt)

        val stale = RulesUpdate.put(Rules(version = 5), contractExample, "now")
        assertTrue(stale is RulesPut.Conflict)
        assertEquals(5, (stale as RulesPut.Conflict).current.version)
    }

    @Test fun putRejectsInvalidDocuments() {
        val cur = Rules(version = 0)
        assertTrue(RulesUpdate.put(cur, "{not json", "now") is RulesPut.Invalid)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"style":"loud"}""", "now") is RulesPut.Invalid)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"volumeLimit":{"maxPercent":150}}""", "now") is RulesPut.Invalid)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"tvTime":{"schedule":[{"days":[8],"from":"21:00","to":"07:00"}]}}""", "now") is RulesPut.Invalid)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"tvTime":{"schedule":[{"from":"25:00","to":"07:00"}]}}""", "now") is RulesPut.Invalid)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"allowedApps":{"mode":"allowlist","packages":["a;rm -rf"]}}""", "now") is RulesPut.Invalid)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"overrides":[{"kind":"allowApp","until":"2026-10-28T23:00:00Z"}]}""", "now") is RulesPut.Invalid)
        assertTrue(RulesUpdate.put(cur, """{"version":0,"overrides":[{"kind":"muteUntil","until":"tomorrow"}]}""", "now") is RulesPut.Invalid)
    }

    @Test fun isoAndClockParsing() {
        val z = Fixtures.ZONE
        assertEquals(Rules.parseIsoInstant("2026-10-28T17:30:00Z", z), Rules.parseIsoInstant("2026-10-28T23:00:00+05:30", z))
        assertEquals(Rules.parseIsoInstant("2026-10-28T17:30:00Z", z), Rules.parseIsoInstant("2026-10-28T23:00:00", z))
        assertNull(Rules.parseIsoInstant("nope", z))
        assertEquals(java.time.LocalTime.MIDNIGHT, Rules.parseHhMm("24:00"))
        assertNull(Rules.parseHhMm("7"))
    }

    @Test fun profileParsesThePhoneAsset() {
        val p = Fixtures.profile
        assertEquals("sony-bravia-vu3", p.id)
        assertEquals(18, p.cleanup.size)
        assertEquals("com.google.android.youtube.tv", p.stockYouTube!!.pkg)
        assertTrue("com.gathin.tvhome" in p.neverTouch)
        assertEquals("googletts.google-speech-apk_20251028.02_p2.827711934", p.knownGood[TvShell.TTS_PACKAGE])
        assertEquals(p, DeviceProfile.parse(p.toJson()))
        assertEquals(ProfilePackage("a.b"), DeviceProfile.parse("""{"cleanup":["a.b"]}""").cleanup.single())
    }

    @Test(expected = IllegalArgumentException::class)
    fun profileRejectsBadPackages() {
        DeviceProfile.parse("""{"cleanup":[{"pkg":"x; reboot"}]}""")
    }

    @Test fun guardSets() {
        val g = PackageGuard(Fixtures.profile)
        for (pkg in listOf("com.gathin.tvhome", TvShell.LAUNCHERX, "com.android.systemui", TvShell.AGENT_PACKAGE, "com.realtek.dtv")) {
            assertTrue(pkg, g.isStopProtected(pkg))
        }
        assertFalse("SmartTube is never-touch but stoppable", g.isStopProtected("org.smarttube.stable"))
        assertTrue(g.isProtected("org.smarttube.stable"))
        assertTrue(g.isProtected("com.android.vending"))
        assertTrue(PackageGuard(null).isProtected("com.google.android.gms"))
    }
}

class HttpTest {
    private val token = "a".repeat(64)

    private class FakeApi : AgentApi {
        var rules = Rules(version = 2)
        var phoneTime: Long? = null
        val actions = mutableListOf<ActionRequest>()
        var mode = Mode.normal
        override fun status() = StatusDoc(
            agentId = "id1", version = "1.0.0", uptimeSec = 5, bootCount = 1, selfAdb = "ok", mode = mode.name,
            now = NowDoc("org.smarttube.stable", 16, 0, 100, false), activeRulesVersion = rules.version,
            breakDoc = BreakDoc(false, null), health = listOf(HealthItem("selfAdb", "ok")), buildFingerprint = "fp",
            buildChangedSinceApproval = false, clockSkewWarn = false,
        )
        override fun rules() = rules
        override fun putRules(body: String): RulesPut {
            val r = RulesUpdate.put(rules, body, "now")
            if (r is RulesPut.Accepted) rules = r.rules
            return r
        }
        override fun action(req: ActionRequest): ActionResult { actions += req; return ActionResult(true, req.action) }
        override fun journal(since: Long) = listOf(JournalEntry(10, "mute", "sound", ok = true, source = "agent")).filter { it.time > since }
        override fun setMode(mode: Mode): ActionResult { this.mode = mode; return ActionResult(true) }
        override fun approveBuild() = ActionResult(true, "fp")
        override fun pushProfile(body: String): ActionResult { DeviceProfile.parse(body); return ActionResult(true) }
        override fun restore(req: RestoreRequest) = RestoreResult(true, RestorePlan(req.target, emptyList(), emptyList()), mode = "paused")
        override fun watchdog(req: WatchdogRequest) = WatchdogReport(true, WatchdogPlan(emptyList(), emptyList(), listOf("dry=${req.dryRun}")))
        override fun phoneTimeHint(phoneEpochMs: Long) { phoneTime = phoneEpochMs }
    }

    private val api = FakeApi()
    private val router = Router({ token }, api)

    /** Sends raw bytes through Router.serve as if over a socket; returns status + body. */
    private fun raw(request: String): Pair<Int, String> {
        val out = ByteArrayOutputStream()
        Router.serve(router, ByteArrayInputStream(request.toByteArray()), out)
        val text = out.toString("UTF-8")
        val status = text.substringAfter("HTTP/1.1 ").substringBefore(' ').toInt()
        val head = text.substringBefore("\r\n\r\n")
        val body = text.substringAfter("\r\n\r\n")
        val len = Regex("Content-Length: (\\d+)").find(head)!!.groupValues[1].toInt()
        assertEquals(len, body.toByteArray().size)
        return status to body
    }

    private fun req(method: String, path: String, body: String = "", auth: String? = "Bearer $token", extra: String = ""): Pair<Int, String> {
        val b = body.toByteArray()
        val sb = StringBuilder("$method $path HTTP/1.1\r\nHost: tv:8790\r\n")
        if (auth != null) sb.append("Authorization: $auth\r\n")
        sb.append(extra)
        if (b.isNotEmpty()) sb.append("Content-Type: application/json\r\nContent-Length: ${b.size}\r\n")
        sb.append("\r\n").append(body)
        return raw(sb.toString())
    }

    @Test fun missingOrWrongTokenIs401() {
        assertEquals(401, req("GET", "/v1/status", auth = null).first)
        assertEquals(401, req("GET", "/v1/status", auth = "Bearer nope").first)
        assertEquals(401, req("GET", "/v1/status", auth = "Basic $token").first)
        assertEquals(401, req("POST", "/v1/action", """{"action":"mute"}""", auth = null).first)
        assertTrue(api.actions.isEmpty())
        assertFalse(Auth.authorized("Bearer ", ""))
    }

    @Test fun statusHasTheContractFields() {
        val (s, body) = req("GET", "/v1/status")
        assertEquals(200, s)
        val o = Json.parseToJsonElement(body).jsonObject
        for (k in listOf("agentId", "version", "api", "uptimeSec", "bootCount", "selfAdb", "mode", "now", "activeRulesVersion",
            "break", "health", "buildFingerprint", "buildChangedSinceApproval", "clockSkewWarn")) {
            assertTrue("missing $k", o.containsKey(k))
        }
        assertEquals(1, o["api"]!!.jsonPrimitive.int)
        val now = o["now"]!!.jsonObject
        for (k in listOf("foreground", "volume", "min", "max", "muted")) assertTrue(now.containsKey(k))
        assertTrue(o["break"]!!.jsonObject.containsKey("active"))
    }

    @Test fun rulesGetPutAnd409() {
        val (s, body) = req("GET", "/v1/rules")
        assertEquals(200, s)
        assertEquals(2, Rules.parse(body).version)
        val (s2, b2) = req("PUT", "/v1/rules", """{"version":2,"alwaysMute":true}""")
        assertEquals(200, s2)
        assertEquals(3, Rules.parse(b2).version)
        val (s3, b3) = req("PUT", "/v1/rules", """{"version":2,"alwaysMute":false}""")
        assertEquals(409, s3)
        val cur = Rules.parse(b3)
        assertEquals(3, cur.version)
        assertTrue(cur.alwaysMute)
        assertEquals(400, req("PUT", "/v1/rules", """{"version":3,"style":"x"}""").first)
    }

    @Test fun actionsAreValidated() {
        assertEquals(200, req("POST", "/v1/action", """{"action":"break","minutes":30}""").first)
        assertEquals(400, req("POST", "/v1/action", """{"action":"break"}""").first)
        assertEquals(400, req("POST", "/v1/action", """{"action":"volume","value":101}""").first)
        assertEquals(400, req("POST", "/v1/action", """{"action":"reboot"}""").first)
        assertEquals(400, req("POST", "/v1/action", "{oops").first)
        assertEquals(listOf("break"), api.actions.map { it.action })
    }

    @Test fun journalSinceModeRestoreProfileWatchdog() {
        val (s, body) = req("GET", "/v1/journal?since=5")
        assertEquals(200, s)
        assertEquals(1, Json.parseToJsonElement(body).jsonArray.size)
        assertEquals(0, Json.parseToJsonElement(req("GET", "/v1/journal?since=10").second).jsonArray.size)
        assertEquals(400, req("GET", "/v1/journal?since=yesterday").first)
        assertEquals(200, req("POST", "/v1/mode", """{"mode":"paused"}""").first)
        assertEquals(Mode.paused, api.mode)
        assertEquals(400, req("POST", "/v1/mode", """{"mode":"off"}""").first)
        assertEquals(200, req("POST", "/v1/restore", """{"target":"stock","dryRun":true}""").first)
        assertEquals(400, req("POST", "/v1/restore", """{"target":"factory"}""").first)
        assertEquals(200, req("POST", "/v1/profile", Fixtures.profileJson).first)
        assertEquals(400, req("POST", "/v1/profile", """{"cleanup":["bad pkg"]}""").first)
        assertEquals(200, req("POST", "/v1/approveBuild").first)
        assertTrue(req("GET", "/v1/watchdog").second.contains("dry=true"))
        assertTrue(req("POST", "/v1/watchdog", """{"dryRun":false}""").second.contains("dry=false"))
    }

    @Test fun unknownPathsAndMethods() {
        assertEquals(404, req("GET", "/", auth = null).first)
        assertEquals(404, req("GET", "/v1/nope").first)
        assertEquals(405, req("DELETE", "/v1/rules").first)
    }

    @Test fun phoneTimeHeaderIsPassedOn() {
        req("GET", "/v1/status", extra = "X-Phone-Time: 1761638400000\r\n")
        assertEquals(1761638400000L, api.phoneTime)
        req("GET", "/v1/status", extra = "X-Phone-Time: 2026-10-28T10:00:00Z\r\n")
        assertEquals(java.time.Instant.parse("2026-10-28T10:00:00Z").toEpochMilli(), api.phoneTime)
        assertTrue(ClockSkew.warn(ClockSkew.skewMs(200_000, 0)))
        assertFalse(ClockSkew.warn(ClockSkew.skewMs(0, 119_000)))
        assertFalse(ClockSkew.warn(null))
    }

    @Test fun parserHandlesMalformedInput() {
        assertEquals(400, raw("GARBAGE\r\n\r\n").first)
        assertEquals(400, raw("GET /v1/status HTTP/1.1\r\nBadHeader\r\n\r\n").first)
        assertEquals(413, raw("POST /v1/rules HTTP/1.1\r\nContent-Length: 999999999\r\n\r\n").first)
        assertEquals(411, raw("POST /v1/rules HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n").first)
        assertEquals(400, raw("POST /v1/rules HTTP/1.1\r\nContent-Length: 10\r\n\r\nabc").first)
        // Clean EOF: no response at all.
        val out = ByteArrayOutputStream()
        Router.serve(router, ByteArrayInputStream(ByteArray(0)), out)
        assertEquals(0, out.size())
    }

    @Test fun requestParsing() {
        val r = HttpRequest.parse(ByteArrayInputStream(
            "PUT /v1/rules?a=1&b=x%20y HTTP/1.1\r\nAUTHORIZATION: Bearer t\r\nContent-Length: 2\r\n\r\n{}".toByteArray(),
        ))!!
        assertEquals("PUT", r.method)
        assertEquals("/v1/rules", r.path)
        assertEquals(mapOf("a" to "1", "b" to "x y"), r.query)
        assertEquals("Bearer t", r.header("Authorization"))
        assertEquals("{}", r.body)
    }
}
