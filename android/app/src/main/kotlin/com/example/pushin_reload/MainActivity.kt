package com.example.pushin_reload

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.provider.Settings
import android.util.Log
import com.pushin.AppBlockingService
import com.pushin.UsageStatsModule
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val USAGE_STATS_CHANNEL = "com.pushin.usagestats"
    private val BLOCKING_SERVICE_CHANNEL = "com.pushin.blockingservice"
    private val BLOCKING_EVENTS_CHANNEL = "com.pushin.blockingevents"
    private val INTENT_CHANNEL = "com.pushin.intent"

    private lateinit var usageStatsModule: UsageStatsModule
    private var eventSink: EventChannel.EventSink? = null
    private var intentMethodChannel: MethodChannel? = null

    companion object {
        private const val TAG = "MainActivity"
    }

    // Broadcast receiver for events from the blocking service
    private val blockingEventsReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                "com.pushin.EMERGENCY_UNLOCK_USED" -> {
                    val blockedApp = intent.getStringExtra("blocked_app")
                    val durationMinutes = intent.getIntExtra("duration_minutes", 5)
                    eventSink?.success(mapOf(
                        "event" to "emergency_unlock_used",
                        "blocked_app" to blockedApp,
                        "duration_minutes" to durationMinutes
                    ))
                }
                "com.pushin.BLOCKED_APP_DETECTED" -> {
                    val blockedApp = intent.getStringExtra("blocked_app")
                    eventSink?.success(mapOf(
                        "event" to "blocked_app_detected",
                        "blocked_app" to blockedApp
                    ))
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize UsageStats module
        usageStatsModule = UsageStatsModule(this)

        // Register UsageStats method channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            USAGE_STATS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageStatsPermission" -> {
                    result.success(usageStatsModule.hasUsageStatsPermission())
                }
                "requestUsageStatsPermission" -> {
                    usageStatsModule.requestUsageStatsPermission()
                    result.success(null)
                }
                "getForegroundApp" -> {
                    result.success(usageStatsModule.getForegroundApp())
                }
                "getInstalledApps" -> {
                    result.success(usageStatsModule.getInstalledApps())
                }
                "getTodayUsageStats" -> {
                    result.success(usageStatsModule.getTodayUsageStats())
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Register Blocking Service method channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BLOCKING_SERVICE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }
                "requestOverlayPermission" -> {
                    val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(null)
                }
                "startBlockingService" -> {
                    startBlockingService()
                    result.success(true)
                }
                "stopBlockingService" -> {
                    stopBlockingService()
                    result.success(true)
                }
                "updateBlockedApps" -> {
                    val apps = call.argument<List<String>>("apps") ?: listOf()
                    updateBlockedApps(apps)
                    result.success(true)
                }
                "setUnlocked" -> {
                    val durationSeconds = call.argument<Int>("duration_seconds") ?: 0
                    setServiceUnlocked(durationSeconds)
                    result.success(true)
                }
                "setLocked" -> {
                    setServiceLocked()
                    result.success(true)
                }
                "activateEmergencyUnlock" -> {
                    val durationMinutes = call.argument<Int>("duration_minutes") ?: 5
                    activateEmergencyUnlock(durationMinutes)
                    result.success(true)
                }
                "setEmergencyUnlockEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: true
                    saveEmergencyUnlockEnabled(enabled)
                    result.success(null)
                }
                "setEmergencyUnlockMinutes" -> {
                    val minutes = call.argument<Int>("minutes") ?: 10
                    saveEmergencyUnlockMinutes(minutes)
                    result.success(null)
                }
                "isServiceRunning" -> {
                    result.success(isBlockingServiceRunning())
                }
                "dismissOverlay" -> {
                    dismissServiceOverlay()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Register Blocking Events channel
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BLOCKING_EVENTS_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // Register Intent channel for handling app launch intents
        intentMethodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            INTENT_CHANNEL
        )

        // Register broadcast receiver
        val filter = IntentFilter().apply {
            addAction("com.pushin.EMERGENCY_UNLOCK_USED")
            addAction("com.pushin.BLOCKED_APP_DETECTED")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(blockingEventsReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(blockingEventsReceiver, filter)
        }

        // Handle initial intent
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return

        val action = intent.getStringExtra("action")
        val blockedApp = intent.getStringExtra("blocked_app")

        Log.d(TAG, "handleIntent: action=$action, blockedApp=$blockedApp")

        if (action == "start_workout") {
            // Send to Flutter via method channel
            intentMethodChannel?.invokeMethod("onStartWorkoutIntent", mapOf(
                "action" to action,
                "blocked_app" to blockedApp
            ))
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        try {
            unregisterReceiver(blockingEventsReceiver)
        } catch (e: Exception) {
            Log.w(TAG, "Receiver not registered: ${e.message}")
        }
    }

    private fun startBlockingService() {
        Log.d(TAG, "Starting blocking service")
        val intent = Intent(this, AppBlockingService::class.java).apply {
            action = AppBlockingService.ACTION_START_SERVICE
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopBlockingService() {
        Log.d(TAG, "Stopping blocking service")
        val intent = Intent(this, AppBlockingService::class.java).apply {
            action = AppBlockingService.ACTION_STOP_SERVICE
        }
        startService(intent)
    }

    private fun updateBlockedApps(apps: List<String>) {
        Log.d(TAG, "Updating blocked apps: $apps")
        val intent = Intent(this, AppBlockingService::class.java).apply {
            action = AppBlockingService.ACTION_UPDATE_BLOCKED_APPS
            putStringArrayListExtra(AppBlockingService.EXTRA_BLOCKED_APPS, ArrayList(apps))
        }
        startService(intent)
    }

    private fun setServiceUnlocked(durationSeconds: Int) {
        Log.d(TAG, "Setting service unlocked for $durationSeconds seconds")
        val intent = Intent(this, AppBlockingService::class.java).apply {
            action = AppBlockingService.ACTION_SET_UNLOCKED
            putExtra(AppBlockingService.EXTRA_UNLOCK_DURATION_SECONDS, durationSeconds)
        }
        startService(intent)
    }

    private fun setServiceLocked() {
        Log.d(TAG, "Setting service locked")
        val intent = Intent(this, AppBlockingService::class.java).apply {
            action = AppBlockingService.ACTION_SET_LOCKED
        }
        startService(intent)
    }

    private fun activateEmergencyUnlock(durationMinutes: Int) {
        Log.d(TAG, "Activating emergency unlock for $durationMinutes minutes")
        val intent = Intent(this, AppBlockingService::class.java).apply {
            action = AppBlockingService.ACTION_EMERGENCY_UNLOCK
            putExtra(AppBlockingService.EXTRA_EMERGENCY_DURATION_MINUTES, durationMinutes)
        }
        startService(intent)
    }

    private fun saveEmergencyUnlockEnabled(enabled: Boolean) {
        val prefs = getSharedPreferences("pushin_blocking_prefs", Context.MODE_PRIVATE)
        prefs.edit().putBoolean("emergency_unlock_enabled", enabled).apply()
        Log.d(TAG, "Saved emergency unlock enabled to Android SharedPreferences: $enabled")
    }

    private fun saveEmergencyUnlockMinutes(minutes: Int) {
        val prefs = getSharedPreferences("pushin_blocking_prefs", Context.MODE_PRIVATE)
        prefs.edit().putInt("emergency_unlock_minutes", minutes).apply()
        Log.d(TAG, "Saved emergency unlock minutes to Android SharedPreferences: $minutes")
    }

    private fun dismissServiceOverlay() {
        Log.d(TAG, "Dismissing service overlay")
        val intent = Intent(this, AppBlockingService::class.java).apply {
            action = AppBlockingService.ACTION_DISMISS_OVERLAY
        }
        startService(intent)
    }

    private fun isBlockingServiceRunning(): Boolean {
        // Check if service is running via shared preferences
        val prefs = getSharedPreferences("pushin_blocking_prefs", Context.MODE_PRIVATE)
        return prefs.getBoolean("service_enabled", false)
    }
}
