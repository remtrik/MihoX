package org.remtrik.mihox

import android.app.Activity
import android.os.Bundle
import org.remtrik.mihox.extensions.wrapAction

class TempActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        when (intent.action) {
            wrapAction("START") -> {
                GlobalState.handleStart()
            }

            wrapAction("STOP") -> {
                GlobalState.handleStop()
            }

            wrapAction("CHANGE") -> {
                GlobalState.handleToggle()
            }
            
            wrapAction("RECONNECT") -> {
                GlobalState.handleReconnect()
            }
        }
        finishAndRemoveTask()
    }
}