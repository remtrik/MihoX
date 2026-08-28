package org.remtrik.mihox.service.modules

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.pm.ServiceInfo
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.remtrik.mihox.common.GlobalState
import org.remtrik.mihox.common.buildServiceNotification
import org.remtrik.mihox.common.startForegroundSafely
import org.remtrik.mihox.service.Module
import org.remtrik.mihox.service.State
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.launch

class NotificationModule(service: Service) : Module(service) {
    private var scope = CoroutineScope(SupervisorJob())
    private var paramsJob: Job? = null

    override suspend fun install() {
        scope = CoroutineScope(SupervisorJob())
        ensureChannel()
        val params = State.notificationParamsFlow.value
        val notification = buildNotification(params.title, params.stopText)
        val fgType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
        } else {
            0
        }
        service.startForegroundSafely(GlobalState.NOTIFICATION_ID, notification, fgType)

        paramsJob = scope.launch {
            State.notificationParamsFlow.collectLatest { params ->
                val n = buildNotification(params.title, params.stopText)
                ContextCompat.getSystemService(service, NotificationManager::class.java)
                    ?.notify(GlobalState.NOTIFICATION_ID, n)
            }
        }
    }

    override suspend fun uninstall() {
        paramsJob?.cancel()
        scope.cancel()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            service.stopForeground(Service.STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            service.stopForeground(true)
        }
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = service.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (manager.getNotificationChannel(GlobalState.NOTIFICATION_CHANNEL) != null) return
        val channel = NotificationChannel(
            GlobalState.NOTIFICATION_CHANNEL,
            service.getString(org.remtrik.mihox.common.R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        )
        manager.createNotificationChannel(channel)
    }

    private fun buildNotification(title: String, stopText: String = ""): android.app.Notification {
        return service.buildServiceNotification(
            org.remtrik.mihox.service.R.drawable.ic_notification,
            title,
            stopText,
        )
    }
}
