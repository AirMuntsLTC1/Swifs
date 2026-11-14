package com.swifs.native

import android.content.Context
import android.os.Build
import io.flutter.plugin.common.MethodChannel

class NativeBridge(private val context: Context) {
    fun register(channel: MethodChannel) {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPlatformInfo" -> result.success(mapOf(
                    "platform" to "android",
                    "sdkInt" to Build.VERSION.SDK_INT,
                    "manufacturer" to Build.MANUFACTURER,
                    "model" to Build.MODEL
                ))
                "scheduleSync" -> {
                    // TODO: WorkManager one-time periodic sync
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
