package com.example.pushin_reload

import com.pushin.UsageStatsModule
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val USAGE_STATS_CHANNEL = "com.pushin.usagestats"
    private lateinit var usageStatsModule: UsageStatsModule

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize UsageStats module
        usageStatsModule = UsageStatsModule(this)

        // Register method channel
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
    }
}
