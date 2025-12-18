package com.pushin

import android.app.AppOpsManager
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import android.os.Build
import android.provider.Settings
import android.util.Base64
import java.io.ByteArrayOutputStream

/// PUSHIN' UsageStats Native Module
///
/// Integrates with Android UsageStatsManager:
/// - Detects foreground app changes via polling
/// - Requests PACKAGE_USAGE_STATS permission
/// - Returns installed apps list for block selection
///
/// Play Store Compliance:
/// - No Accessibility Service abuse
/// - Clear privacy policy for usage data
/// - Permission justified (time management)
class UsageStatsModule(private val context: Context) {

    private val usageStatsManager: UsageStatsManager =
        context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager

    /// Check if PACKAGE_USAGE_STATS permission is granted
    ///
    /// This is a system permission that requires Settings deep-link
    fun hasUsageStatsPermission(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /// Request PACKAGE_USAGE_STATS permission
    ///
    /// Opens Android Settings > Apps > Special Access > Usage Access
    fun requestUsageStatsPermission() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
        context.startActivity(intent)
    }

    /// Get current foreground app
    ///
    /// Returns map with:
    /// - packageName: com.instagram.android
    /// - appName: Instagram
    ///
    /// Uses UsageStatsManager to find most recently used app
    fun getForegroundApp(): Map<String, String> {
        if (!hasUsageStatsPermission()) {
            return mapOf(
                "packageName" to "",
                "appName" to "",
                "error" to "Permission not granted"
            )
        }

        val now = System.currentTimeMillis()
        // Query last 1 minute of usage
        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            now - 1000 * 60,
            now
        )

        // Find most recently used app
        val recentApp = stats.maxByOrNull { it.lastTimeUsed }

        return if (recentApp != null) {
            mapOf(
                "packageName" to recentApp.packageName,
                "appName" to getAppName(recentApp.packageName)
            )
        } else {
            mapOf(
                "packageName" to "",
                "appName" to ""
            )
        }
    }

    /// Get installed apps list for block selection UI
    ///
    /// Returns list of maps with:
    /// - packageName: com.instagram.android
    /// - name: Instagram
    /// - iconData: Base64 encoded PNG
    ///
    /// Filters out system apps (only user-installed apps)
    fun getInstalledApps(): List<Map<String, String>> {
        val pm = context.packageManager
        val apps = pm.getInstalledApplications(PackageManager.GET_META_DATA)

        return apps
            .filter { app ->
                // Only user-installed apps
                (app.flags and ApplicationInfo.FLAG_SYSTEM) == 0
            }
            .map { app ->
                val name = pm.getApplicationLabel(app).toString()
                val packageName = app.packageName
                val icon = pm.getApplicationIcon(app)
                val iconBase64 = encodeIconToBase64(icon)

                mapOf(
                    "packageName" to packageName,
                    "name" to name,
                    "iconData" to iconBase64
                )
            }
            .sortedBy { it["name"] }
    }

    /// Get today's usage stats for analytics
    ///
    /// Returns map of packageName -> seconds used today
    fun getTodayUsageStats(): Map<String, Int> {
        if (!hasUsageStatsPermission()) {
            return emptyMap()
        }

        val now = System.currentTimeMillis()
        val startOfDay = getStartOfDay(now)

        val stats = usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startOfDay,
            now
        )

        return stats.associate { stat ->
            val seconds = (stat.totalTimeInForeground / 1000).toInt()
            stat.packageName to seconds
        }
    }

    /// Get start of today (midnight) timestamp
    private fun getStartOfDay(timestamp: Long): Long {
        val calendar = java.util.Calendar.getInstance()
        calendar.timeInMillis = timestamp
        calendar.set(java.util.Calendar.HOUR_OF_DAY, 0)
        calendar.set(java.util.Calendar.MINUTE, 0)
        calendar.set(java.util.Calendar.SECOND, 0)
        calendar.set(java.util.Calendar.MILLISECOND, 0)
        return calendar.timeInMillis
    }

    /// Get app name from package name
    private fun getAppName(packageName: String): String {
        val pm = context.packageManager
        return try {
            val appInfo = pm.getApplicationInfo(packageName, 0)
            pm.getApplicationLabel(appInfo).toString()
        } catch (e: PackageManager.NameNotFoundException) {
            packageName
        }
    }

    /// Encode app icon to Base64 string
    private fun encodeIconToBase64(drawable: Drawable): String {
        return try {
            val bitmap = drawableToBitmap(drawable)
            val outputStream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
            val byteArray = outputStream.toByteArray()
            Base64.encodeToString(byteArray, Base64.NO_WRAP)
        } catch (e: Exception) {
            ""
        }
    }

    /// Convert Drawable to Bitmap
    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable) {
            return drawable.bitmap
        }

        val bitmap = Bitmap.createBitmap(
            drawable.intrinsicWidth,
            drawable.intrinsicHeight,
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}




















