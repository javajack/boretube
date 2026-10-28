package com.rakesh.boretube_mobile

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * FlutterFragmentActivity is required by local_auth (biometric prompt).
 *
 * The `boretube/multicast` channel holds a WifiManager.MulticastLock while
 * mDNS discovery runs; without it many phones drop multicast packets.
 */
class MainActivity : FlutterFragmentActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

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
        super.onDestroy()
    }
}
