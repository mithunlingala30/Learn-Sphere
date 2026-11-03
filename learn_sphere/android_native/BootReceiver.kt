package __PACKAGE__

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.core.content.ContextCompat

/** Restarts the limit monitor after the phone reboots. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (LimitStore.load(context).isEmpty()) return
        if (!UsageReader.hasUsageAccess(context) || !Settings.canDrawOverlays(context)) return
        try {
            ContextCompat.startForegroundService(
                context, Intent(context, MonitorService::class.java)
            )
        } catch (e: Exception) {
            // Some Android versions block this; the app restarts it on next open.
        }
    }
}
