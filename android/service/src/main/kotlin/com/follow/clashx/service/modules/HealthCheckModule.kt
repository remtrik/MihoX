package com.follow.clashx.service.modules

import android.app.Service
import com.follow.clashx.common.GlobalState
import com.follow.clashx.core.Core
import com.follow.clashx.core.InvokeInterface
import com.follow.clashx.service.Module
import com.follow.clashx.service.State
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

class HealthCheckModule(service: Service) : Module(service) {
    // Dedicated scope so both the periodic loop AND network-triggered checks are
    // cancelled the instant the module is uninstalled (service stop), releasing
    // checkLock / the InvokeInterface callback instead of lingering on the
    // process-wide scope for up to CHECK_TIMEOUT_MS.
    private var scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var periodicJob: Job? = null
    private val checkLock = Mutex()

    @Volatile
    private var consecutiveFailures = 0

    override suspend fun install() {
        runCatching { scope.cancel() }
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        consecutiveFailures = 0
        periodicJob = scope.launch {
            while (true) {
                delay(INTERVAL_MS)
                runCheck("periodic")
            }
        }
    }

    override suspend fun uninstall() {
        runCatching { scope.cancel() }
        periodicJob = null
        consecutiveFailures = 0
    }

    /** Fire a one-shot check on the module's own scope (cancelled on uninstall). */
    fun scheduleCheck(reason: String) {
        scope.launch { runCheck(reason) }
    }

    suspend fun runCheck(reason: String) {
        if (State.runTime == 0L) return
        checkLock.withLock {
            val ok = runCatching {
                withTimeoutOrNull(CHECK_TIMEOUT_MS) {
                    suspendCancellableCoroutine { cont ->
                        val action = """{"id":"hc_${System.currentTimeMillis()}","method":"healthCheck","data":""}"""
                        Core.invokeAction(action, object : InvokeInterface {
                            override fun onResult(result: String) {
                                if (cont.isActive) cont.resume(true)
                            }
                        })
                    }
                }
            }.getOrNull()

            if (ok == true) {
                if (consecutiveFailures > 0) {
                    GlobalState.log("HealthCheck ($reason): recovered after $consecutiveFailures failures")
                }
                consecutiveFailures = 0
            } else {
                consecutiveFailures++
                GlobalState.log("HealthCheck ($reason): failed ($consecutiveFailures consecutive)")
                recover()
            }
        }
    }

    private fun recover() {
        GlobalState.log("HealthCheck: resetting connections (attempt $consecutiveFailures)")
        runCatching { Core.resetConnections() }
            .onFailure { GlobalState.log("HealthCheck: resetConnections failed: ${it.message}") }
    }

    companion object {
        private const val INTERVAL_MS = 5 * 60 * 1000L
        private const val CHECK_TIMEOUT_MS = 30_000L
    }
}
