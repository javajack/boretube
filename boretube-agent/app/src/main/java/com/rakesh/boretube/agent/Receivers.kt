package com.rakesh.boretube.agent

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.UserManager

/**
 * BOOT_COMPLETED, LOCKED_BOOT_COMPLETED and MY_PACKAGE_REPLACED start the guard.
 * Both boot broadcasts arrive on the VU3; starting twice is harmless (the service
 * is a singleton and boots are de-duplicated by boot_id).
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_LOCKED_BOOT_COMPLETED -> {
                // Credential storage (prefs) is not available until unlock; BOOT_COMPLETED follows.
                val um = ctx.getSystemService(Context.USER_SERVICE) as UserManager
                if (um.isUserUnlocked) GuardService.start(ctx)
            }
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> GuardService.start(ctx)
        }
    }
}

/**
 * PACKAGE_ADDED/REPLACED/CHANGED → watchdog. Since Android 8 these implicit
 * broadcasts no longer reach manifest receivers, so the running service also
 * registers for them at runtime; this manifest entry is a best-effort backup.
 */
class PackageReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val pkg = intent.data?.schemeSpecificPart
        val c = GuardService.controller
        if (c != null) c.onPackageEvent(pkg) else GuardService.start(ctx, pkg ?: "")
    }
}
