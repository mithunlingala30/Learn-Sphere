package __PACKAGE__

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Bridges Flutter to usage stats, permissions and the limit monitor. */
class MainActivity : FlutterActivity() {

    private fun hasNotificationPermission(): Boolean {
        val granted = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        return granted && NotificationManagerCompat.from(this).areNotificationsEnabled()
    }

    private fun open(intent: Intent) {
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "learnsphere/native")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "status" -> result.success(
                            mapOf(
                                "usageAccess" to UsageReader.hasUsageAccess(this),
                                "overlay" to Settings.canDrawOverlays(this),
                                "notifications" to hasNotificationPermission(),
                                "monitoring" to MonitorService.running
                            )
                        )

                        "getUsage" -> {
                            val start = call.argument<Number>("start")!!.toLong()
                            val end = call.argument<Number>("end")!!.toLong()
                            result.success(
                                if (UsageReader.hasUsageAccess(this))
                                    UsageReader.usageBetween(this, start, end)
                                else emptyList<Map<String, Any>>()
                            )
                        }

                        "installedApps" -> result.success(UsageReader.installedApps(this))

                        "openUsageSettings" -> {
                            open(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.success(null)
                        }

                        "openOverlaySettings" -> {
                            open(
                                Intent(
                                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                    Uri.parse("package:$packageName")
                                )
                            )
                            result.success(null)
                        }

                        "requestNotifications" -> {
                            if (Build.VERSION.SDK_INT >= 33 &&
                                ContextCompat.checkSelfPermission(
                                    this, Manifest.permission.POST_NOTIFICATIONS
                                ) != PackageManager.PERMISSION_GRANTED
                            ) {
                                requestPermissions(
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1001
                                )
                            } else {
                                open(
                                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                        .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                                )
                            }
                            result.success(null)
                        }

                        "setLimits" -> {
                            val raw = call.argument<List<Map<String, Any?>>>("limits") ?: emptyList()
                            val limits = raw.map {
                                LimitStore.Limit(
                                    it["package"] as String,
                                    (it["name"] as? String) ?: (it["package"] as String),
                                    (it["minutes"] as Number).toInt(),
                                    (it["warnPercent"] as? Number)?.toInt() ?: 80
                                )
                            }
                            LimitStore.save(this, limits)
                            result.success(null)
                        }

                        "startMonitoring" -> {
                            if (UsageReader.hasUsageAccess(this) &&
                                Settings.canDrawOverlays(this) &&
                                !MonitorService.running
                            ) {
                                ContextCompat.startForegroundService(
                                    this, Intent(this, MonitorService::class.java)
                                )
                            }
                            result.success(null)
                        }

                        "stopMonitoring" -> {
                            stopService(Intent(this, MonitorService::class.java))
                            result.success(null)
                        }

                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("native_error", e.message, null)
                }
            }
    }
}
