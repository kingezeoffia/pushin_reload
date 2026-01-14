package com.pushin

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * Boot Receiver to restart AppBlockingService after device reboot.
 *
 * This ensures app blocking continues to work after the device is restarted.
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
        private const val PREFS_NAME = "pushin_blocking_prefs"
        private const val KEY_SERVICE_ENABLED = "service_enabled"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.d(TAG, "Boot completed, checking if service should be started")

            // Check if service was previously enabled
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            val serviceEnabled = prefs.getBoolean(KEY_SERVICE_ENABLED, false)

            if (serviceEnabled) {
                Log.d(TAG, "Service was enabled, restarting...")
                val serviceIntent = Intent(context, AppBlockingService::class.java).apply {
                    action = AppBlockingService.ACTION_START_SERVICE
                }

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent)
                } else {
                    context.startService(serviceIntent)
                }
            } else {
                Log.d(TAG, "Service was not enabled, skipping restart")
            }
        }
    }
}
