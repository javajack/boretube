package com.rakesh.boretube.agent.android

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.util.Log
import com.rakesh.boretube.agent.core.API_VERSION
import com.rakesh.boretube.agent.core.Router
import java.net.InetAddress
import java.net.InetSocketAddress
import java.net.ServerSocket
import java.net.Socket
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Small ServerSocket HTTP/1.1 server on :8790 (LAN only), one request per connection. */
class HttpServer(private val router: Router, private val port: Int = PORT) {
    @Volatile private var server: ServerSocket? = null
    private val pool = Executors.newFixedThreadPool(4) { Thread(it, "http-worker").apply { isDaemon = true } }
    private var acceptThread: Thread? = null

    fun start() {
        if (acceptThread != null) return
        acceptThread = Thread({ loop() }, "http-accept").apply { isDaemon = true; start() }
    }

    private fun loop() {
        while (!Thread.currentThread().isInterrupted) {
            try {
                val s = ServerSocket().apply { reuseAddress = true; bind(InetSocketAddress(port)) }
                server = s
                while (!s.isClosed) {
                    val c = s.accept()
                    pool.execute { handle(c) }
                }
            } catch (e: Exception) {
                if (Thread.currentThread().isInterrupted) return
                Log.w(TAG, "server: ${e.message}; retrying")
                try { Thread.sleep(2_000) } catch (_: InterruptedException) { return }
            }
        }
    }

    private fun handle(c: Socket) {
        c.use {
            try {
                if (!isLan(c.inetAddress)) return
                c.soTimeout = 10_000
                Router.serve(router, c.getInputStream(), c.getOutputStream())
            } catch (e: Exception) {
                Log.d(TAG, "request: ${e.message}")
            }
        }
    }

    fun stop() {
        acceptThread?.interrupt()
        try { server?.close() } catch (_: Exception) {}
        pool.shutdownNow()
        pool.awaitTermination(1, TimeUnit.SECONDS)
    }

    companion object {
        const val PORT = 8790
        private const val TAG = "BoretubeHttp"

        fun isLan(a: InetAddress): Boolean =
            a.isLoopbackAddress || a.isSiteLocalAddress || a.isLinkLocalAddress ||
                // IPv6 unique-local fc00::/7
                (a.address.size == 16 && (a.address[0].toInt() and 0xfe) == 0xfc)
    }
}

/** Announces `_boretube._tcp` with TXT id / ver / api. */
class NsdAnnouncer(ctx: Context, private val agentId: String, private val version: String) {
    private val nsd = ctx.getSystemService(Context.NSD_SERVICE) as NsdManager
    private var listener: NsdManager.RegistrationListener? = null

    fun start(port: Int) {
        if (listener != null) return
        val info = NsdServiceInfo().apply {
            serviceName = "boretube-${agentId.take(8)}"
            serviceType = "_boretube._tcp"
            setPort(port)
            setAttribute("id", agentId)
            setAttribute("ver", version)
            setAttribute("api", API_VERSION.toString())
        }
        val l = object : NsdManager.RegistrationListener {
            override fun onServiceRegistered(i: NsdServiceInfo) { Log.i(TAG, "registered ${i.serviceName}") }
            override fun onRegistrationFailed(i: NsdServiceInfo, code: Int) { Log.w(TAG, "register failed $code"); listener = null }
            override fun onServiceUnregistered(i: NsdServiceInfo) {}
            override fun onUnregistrationFailed(i: NsdServiceInfo, code: Int) {}
        }
        listener = l
        try { nsd.registerService(info, NsdManager.PROTOCOL_DNS_SD, l) } catch (e: Exception) { listener = null }
    }

    fun stop() {
        listener?.let { try { nsd.unregisterService(it) } catch (_: Exception) {} }
        listener = null
    }

    companion object { private const val TAG = "BoretubeNsd" }
}
