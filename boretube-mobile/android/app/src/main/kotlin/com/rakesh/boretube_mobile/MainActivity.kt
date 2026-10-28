package com.rakesh.boretube_mobile

import android.content.Context
import android.net.wifi.WifiManager
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity is required by local_auth (biometric prompt).
 *
 * The `boretube/multicast` channel holds a WifiManager.MulticastLock while
 * mDNS discovery runs; without it many phones drop multicast packets.
 *
 * While the app is on screen it also holds a low-latency WifiLock. Without
 * it the radio power-saves between polls, TV replies get lost and TCP
 * retransmit back-off turns a 0.3 s ADB command into 6-8 s.
 */
class MainActivity : FlutterFragmentActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null
    private var latencyLock: WifiManager.WifiLock? = null

    override fun onResume() {
        super.onResume()
        val lock = latencyLock ?: run {
            val wifi = applicationContext
                .getSystemService(Context.WIFI_SERVICE) as WifiManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                WifiManager.WIFI_MODE_FULL_LOW_LATENCY
            } else {
                @Suppress("DEPRECATION")
                WifiManager.WIFI_MODE_FULL_HIGH_PERF
            }
            wifi.createWifiLock(mode, "boretube-latency").apply {
                setReferenceCounted(false)
            }
        }
        latencyLock = lock
        if (!lock.isHeld) lock.acquire()
    }

    override fun onPause() {
        latencyLock?.let { if (it.isHeld) it.release() }
        super.onPause()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "boretube/multicast",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquire" -> {
                    try {
                        acquire()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("multicast", e.message, null)
                    }
                }
                "release" -> {
                    release()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun acquire() {
        val lock = multicastLock ?: run {
            val wifi = applicationContext
                .getSystemService(Context.WIFI_SERVICE) as WifiManager
            wifi.createMulticastLock("boretube-mdns").apply {
                setReferenceCounted(false)
            }
        }
        multicastLock = lock
        if (!lock.isHeld) lock.acquire()
    }

    private fun release() {
        multicastLock?.let { if (it.isHeld) it.release() }
    }

    override fun onDestroy() {
        release()
        multicastLock = null
        latencyLock?.let { if (it.isHeld) it.release() }
        latencyLock = null
        super.onDestroy()
    }
}
