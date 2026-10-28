package com.rakesh.boretube.agent.android

import android.service.notification.NotificationListenerService

/**
 * Exists only so TV Guard can hold notification-listener access, which
 * MediaSessionManager.getActiveSessions requires. Granted over ADB:
 * `cmd notification allow_listener com.rakesh.boretube.agent/com.rakesh.boretube.agent.android.MediaListenerService`
 * (re-applied by the permission self-heal). It reads no notifications.
 */
class MediaListenerService : NotificationListenerService()
