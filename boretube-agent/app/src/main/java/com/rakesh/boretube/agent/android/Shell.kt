package com.rakesh.boretube.agent.android

import android.util.Log
import com.rakesh.boretube.agent.core.SelfAdb
import com.rakesh.boretube.agent.core.ShellPort
import com.rakesh.boretube.agent.core.ShellResult
import dadb.AdbKeyPair
import dadb.Dadb
import java.io.File
import java.io.IOException
import java.net.ConnectException
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/**
 * Self-ADB: dadb to localhost:5555 with the agent's own RSA key (kept in the
 * app's files dir). The first connect makes the TV show "Allow USB debugging?"
 * for this key; the phone guides the parent to tick "Always allow". While the
 * prompt is pending [state] reads [SelfAdb.needsApproval].
 *
 * Two lanes (separate ADB connections) so urgent commands (stop, HOME, keys)
 * never queue behind slow `pm` writes of the watchdog.
 */
class Shell(filesDir: File, private val host: String = "localhost", private val port: Int = 5555) {
    @Volatile var state: SelfAdb = SelfAdb.unavailable
        private set
    @Volatile var lastError: String = ""
        private set

    private val privFile = File(filesDir, "adbkey")
    private val pubFile = File(filesDir, "adbkey.pub")
    private val keyPair: AdbKeyPair by lazy {
        if (!privFile.exists() || !pubFile.exists()) AdbKeyPair.generate(privFile, pubFile)
        AdbKeyPair.read(privFile, pubFile)
    }

    private val lanes = arrayOfNulls<Dadb>(2)
    private val laneLocks = arrayOf(Any(), Any())
    private val probeExec = Executors.newSingleThreadExecutor { Thread(it, "selfadb-probe").apply { isDaemon = true } }
    private var probing: Future<*>? = null
    private var nextProbeAt = 0L
    private var backoffMs = 2_000L

    /** As a [ShellPort] on the slow lane. */
    val slow: ShellPort = ShellPort { run(it, urgent = false) }
    val fast: ShellPort = ShellPort { run(it, urgent = true) }

    private fun open(): Dadb = Dadb.create(host, port, keyPair, CONNECT_TIMEOUT_MS, SOCKET_TIMEOUT_MS, true)

    /**
     * Connects in the background if not connected, with backoff (2 s doubling to
     * 30 s): adbd may not be up right after boot. Non-blocking.
     */
    @Synchronized
    fun ensureConnected(now: Long = System.currentTimeMillis()) {
        if (state == SelfAdb.ok) return
        if (probing?.isDone == false || now < nextProbeAt) return
        probing = probeExec.submit { probe() }
    }

    /** Forces a reprobe soon (e.g. the phone said "Allow" was tapped). */
    @Synchronized
    fun kick() {
        nextProbeAt = 0
        backoffMs = 2_000L
    }

    private fun probe() {
        val d = try { open() } catch (e: Exception) { fail(SelfAdb.unavailable, e); return }
        val call = Executors.newSingleThreadExecutor()
        try {
            val f = call.submit<String> { d.shell("echo ok").output }
            val out = try {
                f.get(APPROVAL_HINT_MS, TimeUnit.MILLISECONDS)
            } catch (_: TimeoutException) {
                // TCP is up but the handshake hangs: the TV is showing the Allow prompt.
                state = SelfAdb.needsApproval
                lastError = "waiting for Allow on the TV"
                f.get(SOCKET_TIMEOUT_MS.toLong(), TimeUnit.MILLISECONDS)
            }
            if (out.trim() == "ok") {
                synchronized(laneLocks[1]) { lanes[1]?.closeQuietly(); lanes[1] = d }
                synchronized(this) { backoffMs = 2_000L }
                state = SelfAdb.ok
                lastError = ""
            } else {
                d.closeQuietly()
                fail(SelfAdb.unavailable, IOException("probe answered \"$out\""))
            }
        } catch (e: Exception) {
            d.closeQuietly()
            val cause = (e.cause ?: e)
            fail(if (cause is ConnectException) SelfAdb.unavailable else SelfAdb.needsApproval, cause)
        } finally {
            call.shutdownNow()
        }
    }

    private fun fail(s: SelfAdb, e: Throwable) {
        state = s
        lastError = "${e.javaClass.simpleName}: ${e.message}"
        Log.w(TAG, "self-ADB $s: $lastError")
        synchronized(this) {
            nextProbeAt = System.currentTimeMillis() + backoffMs
            backoffMs = (backoffMs * 2).coerceAtMost(30_000L)
        }
    }

    /** Runs [cmd]; one reconnect on a dropped connection. Throws IOException when self-ADB is down. */
    fun run(cmd: String, urgent: Boolean = false): ShellResult {
        if (state != SelfAdb.ok) throw IOException("self-ADB ${state.name}")
        val lane = if (urgent) 0 else 1
        synchronized(laneLocks[lane]) {
            for (attempt in 0..1) {
                val d = lanes[lane] ?: open().also { lanes[lane] = it }
                try {
                    val r = d.shell(cmd)
                    return ShellResult(r.output, r.errorOutput, r.exitCode)
                } catch (e: IOException) {
                    d.closeQuietly()
                    lanes[lane] = null
                    if (attempt == 1) {
                        fail(if (e is ConnectException) SelfAdb.unavailable else SelfAdb.needsApproval, e)
                        throw e
                    }
                }
            }
        }
        throw IOException("unreachable")
    }

    fun close() {
        for (i in lanes.indices) synchronized(laneLocks[i]) { lanes[i]?.closeQuietly(); lanes[i] = null }
        probeExec.shutdownNow()
    }

    private fun Dadb.closeQuietly() = try { close() } catch (_: Exception) {}

    companion object {
        private const val TAG = "BoretubeShell"
        const val CONNECT_TIMEOUT_MS = 3_000
        const val SOCKET_TIMEOUT_MS = 60_000
        const val APPROVAL_HINT_MS = 4_000L
    }
}
