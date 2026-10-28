package com.rakesh.boretube.agent

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import com.rakesh.boretube.agent.android.GuardController

/**
 * Foreground service ("TV Guard is on", low importance). Started by BootReceiver
 * and by the phone: `am start-foreground-service -n com.rakesh.boretube.agent/.GuardService`
 * (exported, but only callers holding android.permission.DUMP, i.e. the ADB shell).
 */
class GuardService : Service() {

    override fun onCreate() {
        super.onCreate()
        goForeground()
        synchronized(GuardService::class.java) {
            if (controller == null) {
                controller = GuardController(applicationContext).also {
                    try { it.start() } catch (e: Exception) { Log.e(TAG, "start failed", e) }
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        goForeground()
        intent?.getStringExtra(EXTRA_PACKAGE_EVENT)?.let { controller?.onPackageEvent(it) }
        return START_STICKY
    }

    private fun goForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "TV Guard", NotificationManager.IMPORTANCE_LOW).apply {
                    setShowBadge(false)
                },
            )
        }
        val n = Notification.Builder(this, CHANNEL)
            .setContentTitle("TV Guard is on")
            .setSmallIcon(R.drawable.ic_guard)
            .setOngoing(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .build()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, n)
        }
    }

    override fun onDestroy() {
        synchronized(GuardService::class.java) {
            controller?.stop()
            controller = null
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val TAG = "BoretubeService"
        private const val CHANNEL = "guard"
        private const val NOTIFICATION_ID = 1
        const val EXTRA_PACKAGE_EVENT = "packageEvent"

        /** Holds the application context only (no leak of an Activity/Service). */
        @SuppressLint("StaticFieldLeak")
        @Volatile var controller: GuardController? = null
            private set

        fun start(ctx: Context, packageEvent: String? = null) {
            val i = Intent(ctx, GuardService::class.java)
            packageEvent?.let { i.putExtra(EXTRA_PACKAGE_EVENT, it) }
            try {
                ctx.startForegroundService(i)
            } catch (e: Exception) {
                Log.w(TAG, "could not start service: ${e.message}")
            }
        }
    }
}
