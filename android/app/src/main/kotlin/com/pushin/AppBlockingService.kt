package com.pushin

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.TextView
import androidx.core.app.NotificationCompat

/**
 * PUSHIN' App Blocking Foreground Service
 *
 * Runs in background to monitor app usage and show blocking overlay
 * when user attempts to open a blocked app.
 *
 * Features:
 * - Foreground service with notification (required by Android)
 * - Polls UsageStatsManager every 1 second
 * - Shows system overlay when blocked app detected
 * - Handles "Start Workout" and "Emergency Unlock" actions
 * - Respects UNLOCKED state (doesn't block when user has earned time)
 */
class AppBlockingService : Service() {

    companion object {
        private const val TAG = "AppBlockingService"
        private const val CHANNEL_ID = "pushin_blocking_channel"
        private const val NOTIFICATION_ID = 1001
        private const val POLL_INTERVAL_MS = 1000L

        // Shared preferences keys
        private const val PREFS_NAME = "pushin_blocking_prefs"
        private const val KEY_BLOCKED_APPS = "blocked_apps"
        private const val KEY_IS_UNLOCKED = "is_unlocked"
        private const val KEY_UNLOCK_EXPIRY = "unlock_expiry"
        private const val KEY_EMERGENCY_UNLOCK_ACTIVE = "emergency_unlock_active"
        private const val KEY_EMERGENCY_UNLOCK_EXPIRY = "emergency_unlock_expiry"
        private const val KEY_EMERGENCY_UNLOCK_MINUTES = "emergency_unlock_minutes"
        private const val KEY_SERVICE_ENABLED = "service_enabled"

        // Intent actions
        const val ACTION_START_SERVICE = "com.pushin.START_BLOCKING_SERVICE"
        const val ACTION_STOP_SERVICE = "com.pushin.STOP_BLOCKING_SERVICE"
        const val ACTION_UPDATE_BLOCKED_APPS = "com.pushin.UPDATE_BLOCKED_APPS"
        const val ACTION_SET_UNLOCKED = "com.pushin.SET_UNLOCKED"
        const val ACTION_SET_LOCKED = "com.pushin.SET_LOCKED"
        const val ACTION_EMERGENCY_UNLOCK = "com.pushin.EMERGENCY_UNLOCK"
        const val ACTION_DISMISS_OVERLAY = "com.pushin.DISMISS_OVERLAY"

        // Intent extras
        const val EXTRA_BLOCKED_APPS = "blocked_apps"
        const val EXTRA_UNLOCK_DURATION_SECONDS = "unlock_duration_seconds"
        const val EXTRA_EMERGENCY_DURATION_MINUTES = "emergency_duration_minutes"
    }

    private lateinit var windowManager: WindowManager
    private lateinit var usageStatsManager: UsageStatsManager
    private lateinit var prefs: SharedPreferences
    private lateinit var handler: Handler

    private var overlayView: View? = null
    private var isOverlayShowing = false
    private var currentBlockedApp: String? = null
    private var lastForegroundPackage: String? = null

    private val pollRunnable = object : Runnable {
        override fun run() {
            checkForegroundApp()
            handler.postDelayed(this, POLL_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Service created")

        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        handler = Handler(Looper.getMainLooper())

        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "Service started with action: ${intent?.action}")

        when (intent?.action) {
            ACTION_START_SERVICE -> {
                startForegroundService()
                startPolling()
            }
            ACTION_STOP_SERVICE -> {
                stopPolling()
                hideOverlay()
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }
            ACTION_UPDATE_BLOCKED_APPS -> {
                val apps = intent.getStringArrayListExtra(EXTRA_BLOCKED_APPS) ?: arrayListOf()
                updateBlockedApps(apps)
            }
            ACTION_SET_UNLOCKED -> {
                val durationSeconds = intent.getIntExtra(EXTRA_UNLOCK_DURATION_SECONDS, 0)
                setUnlocked(durationSeconds)
            }
            ACTION_SET_LOCKED -> {
                setLocked()
            }
            ACTION_EMERGENCY_UNLOCK -> {
                val durationMinutes = intent.getIntExtra(EXTRA_EMERGENCY_DURATION_MINUTES, 5)
                activateEmergencyUnlock(durationMinutes)
            }
            ACTION_DISMISS_OVERLAY -> {
                hideOverlay()
            }
        }

        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "Service destroyed")
        stopPolling()
        hideOverlay()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "PUSHIN App Blocking",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors app usage and helps you stay focused"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startForegroundService() {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        prefs.edit().putBoolean(KEY_SERVICE_ENABLED, true).apply()
        Log.d(TAG, "Foreground service started")
    }

    private fun createNotification(): Notification {
        // Intent to open the app
        val openAppIntent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("PUSHIN' Active")
            .setContentText("Monitoring apps to help you stay focused")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun startPolling() {
        handler.removeCallbacks(pollRunnable)
        handler.post(pollRunnable)
        Log.d(TAG, "Polling started")
    }

    private fun stopPolling() {
        handler.removeCallbacks(pollRunnable)
        Log.d(TAG, "Polling stopped")
    }

    private fun checkForegroundApp() {
        // Check if blocking is enabled
        if (!prefs.getBoolean(KEY_SERVICE_ENABLED, true)) {
            return
        }

        // Check if user is unlocked (earned screen time)
        if (isUserUnlocked()) {
            if (isOverlayShowing) {
                hideOverlay()
            }
            return
        }

        // Check if emergency unlock is active
        if (isEmergencyUnlockActive()) {
            if (isOverlayShowing) {
                hideOverlay()
            }
            return
        }

        // Get current foreground app
        val foregroundPackage = getForegroundPackage()
        if (foregroundPackage == null || foregroundPackage == lastForegroundPackage) {
            return
        }

        lastForegroundPackage = foregroundPackage
        Log.d(TAG, "Foreground app changed: $foregroundPackage")

        // Skip if it's our own app
        if (foregroundPackage == packageName) {
            if (isOverlayShowing) {
                hideOverlay()
            }
            return
        }

        // Check if this app is blocked
        val blockedApps = getBlockedApps()
        if (blockedApps.contains(foregroundPackage)) {
            Log.d(TAG, "Blocked app detected: $foregroundPackage")
            currentBlockedApp = foregroundPackage
            showOverlay(foregroundPackage)
        } else {
            if (isOverlayShowing) {
                hideOverlay()
            }
        }
    }

    private fun getForegroundPackage(): String? {
        val now = System.currentTimeMillis()
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            now - 60000,
            now
        )

        return stats.maxByOrNull { it.lastTimeUsed }?.packageName
    }

    private fun getBlockedApps(): Set<String> {
        return prefs.getStringSet(KEY_BLOCKED_APPS, emptySet()) ?: emptySet()
    }

    private fun updateBlockedApps(apps: List<String>) {
        prefs.edit().putStringSet(KEY_BLOCKED_APPS, apps.toSet()).apply()
        Log.d(TAG, "Updated blocked apps: $apps")
    }

    private fun isUserUnlocked(): Boolean {
        val isUnlocked = prefs.getBoolean(KEY_IS_UNLOCKED, false)
        if (!isUnlocked) return false

        val expiryTime = prefs.getLong(KEY_UNLOCK_EXPIRY, 0)
        if (expiryTime > 0 && System.currentTimeMillis() > expiryTime) {
            // Unlock has expired
            setLocked()
            return false
        }

        return true
    }

    private fun setUnlocked(durationSeconds: Int) {
        val expiryTime = if (durationSeconds > 0) {
            System.currentTimeMillis() + (durationSeconds * 1000L)
        } else {
            0L
        }

        prefs.edit()
            .putBoolean(KEY_IS_UNLOCKED, true)
            .putLong(KEY_UNLOCK_EXPIRY, expiryTime)
            .apply()

        hideOverlay()
        Log.d(TAG, "User unlocked for $durationSeconds seconds")
    }

    private fun setLocked() {
        prefs.edit()
            .putBoolean(KEY_IS_UNLOCKED, false)
            .putLong(KEY_UNLOCK_EXPIRY, 0)
            .apply()

        Log.d(TAG, "User locked")
    }

    private fun isEmergencyUnlockActive(): Boolean {
        val isActive = prefs.getBoolean(KEY_EMERGENCY_UNLOCK_ACTIVE, false)
        if (!isActive) return false

        val expiryTime = prefs.getLong(KEY_EMERGENCY_UNLOCK_EXPIRY, 0)
        if (expiryTime > 0 && System.currentTimeMillis() > expiryTime) {
            // Emergency unlock has expired
            prefs.edit()
                .putBoolean(KEY_EMERGENCY_UNLOCK_ACTIVE, false)
                .putLong(KEY_EMERGENCY_UNLOCK_EXPIRY, 0)
                .apply()
            return false
        }

        return true
    }

    private fun activateEmergencyUnlock(durationMinutes: Int) {
        val expiryTime = System.currentTimeMillis() + (durationMinutes * 60 * 1000L)

        prefs.edit()
            .putBoolean(KEY_EMERGENCY_UNLOCK_ACTIVE, true)
            .putLong(KEY_EMERGENCY_UNLOCK_EXPIRY, expiryTime)
            .apply()

        hideOverlay()
        Log.d(TAG, "Emergency unlock activated for $durationMinutes minutes")
    }

    private fun showOverlay(blockedPackage: String) {
        if (isOverlayShowing) return

        // Check overlay permission
        if (!Settings.canDrawOverlays(this)) {
            Log.w(TAG, "Overlay permission not granted")
            // Open settings to request permission
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
            return
        }

        try {
            val layoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                } else {
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE
                },
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
            }

            // Make overlay touchable
            layoutParams.flags = layoutParams.flags and WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE.inv()

            overlayView = createOverlayView(blockedPackage)
            windowManager.addView(overlayView, layoutParams)
            isOverlayShowing = true

            Log.d(TAG, "Overlay shown for: $blockedPackage")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show overlay: ${e.message}")
        }
    }

    private fun createOverlayView(blockedPackage: String): View {
        val view = View.inflate(this, getOverlayLayoutId(), null)

        // If layout resource not found, create programmatically
        return createOverlayViewProgrammatically(blockedPackage)
    }

    private fun getOverlayLayoutId(): Int {
        return resources.getIdentifier("blocking_overlay", "layout", packageName)
    }

    private fun createOverlayViewProgrammatically(blockedPackage: String): View {
        val context = this

        // Create overlay programmatically using Android views
        val layout = android.widget.LinearLayout(context).apply {
            orientation = android.widget.LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(0xF0121218.toInt()) // Dark background with opacity
            setPadding(48, 48, 48, 48)
        }

        // App name
        val appName = getAppName(blockedPackage)

        // Icon
        val iconView = android.widget.ImageView(context).apply {
            setImageResource(android.R.drawable.ic_lock_lock)
            layoutParams = android.widget.LinearLayout.LayoutParams(120, 120).apply {
                bottomMargin = 32
            }
            setColorFilter(0xFF6060FF.toInt())
        }
        layout.addView(iconView)

        // Title
        val titleView = TextView(context).apply {
            text = "Unblock $appName"
            textSize = 28f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 16
            }
        }
        layout.addView(titleView)

        // Subtitle
        val subtitleView = TextView(context).apply {
            text = "Complete a quick workout to access this app"
            textSize = 16f
            setTextColor(0x99FFFFFF.toInt())
            gravity = Gravity.CENTER
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 48
            }
        }
        layout.addView(subtitleView)

        // Start Workout Button
        val startButton = Button(context).apply {
            text = "Start Workout"
            textSize = 18f
            setTextColor(0xFF1A1A2E.toInt())
            setBackgroundColor(0xFFFFFFFF.toInt())
            setPadding(64, 24, 64, 24)
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = 16
                leftMargin = 32
                rightMargin = 32
            }
            setOnClickListener {
                onStartWorkoutClicked()
            }
        }
        layout.addView(startButton)

        // Emergency Unlock Button
        val emergencyButton = Button(context).apply {
            text = "Emergency Unlock"
            textSize = 16f
            setTextColor(0xFFEF4444.toInt())
            setBackgroundColor(0x00000000)
            setPadding(64, 16, 64, 16)
            layoutParams = android.widget.LinearLayout.LayoutParams(
                android.widget.LinearLayout.LayoutParams.MATCH_PARENT,
                android.widget.LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                leftMargin = 32
                rightMargin = 32
            }
            setOnClickListener {
                onEmergencyUnlockClicked()
            }
        }
        layout.addView(emergencyButton)

        return layout
    }

    private fun getAppName(packageName: String): String {
        return try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            packageManager.getApplicationLabel(appInfo).toString()
        } catch (e: Exception) {
            packageName
        }
    }

    private fun onStartWorkoutClicked() {
        hideOverlay()

        // Launch PUSHIN app
        val intent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("action", "start_workout")
            putExtra("blocked_app", currentBlockedApp)
        }
        intent?.let { startActivity(it) }
    }

    private fun onEmergencyUnlockClicked() {
        // Get emergency unlock duration from settings (default 10 minutes if not set)
        val durationMinutes = prefs.getInt(KEY_EMERGENCY_UNLOCK_MINUTES, 10)
        
        // Activate emergency unlock
        activateEmergencyUnlock(durationMinutes)

        // Send broadcast to Flutter app to update state
        val intent = Intent("com.pushin.EMERGENCY_UNLOCK_USED").apply {
            putExtra("blocked_app", currentBlockedApp)
            putExtra("duration_minutes", durationMinutes)
        }
        sendBroadcast(intent)
    }

    private fun hideOverlay() {
        if (isOverlayShowing && overlayView != null) {
            try {
                windowManager.removeView(overlayView)
                overlayView = null
                isOverlayShowing = false
                Log.d(TAG, "Overlay hidden")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to hide overlay: ${e.message}")
            }
        }
    }
}
