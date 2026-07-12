package org.remtrik.mihox

import android.app.Application
import android.content.Context

class MihoXApplication : Application() {
    companion object {
        private lateinit var instance: MihoXApplication
        fun getAppContext(): Context {
            return instance.applicationContext
        }
    }

    override fun onCreate() {
        super.onCreate()
        instance = this
    }
}