package __PACKAGE__

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import java.util.Calendar

/** Reads per-app foreground time from Android's UsageStatsManager. */
object UsageReader {

    fun hasUsageAccess(ctx: Context): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= 29) {
            ops.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun startOfDay(now: Long): Long {
        val c = Calendar.getInstance()
        c.timeInMillis = now
        c.set(Calendar.HOUR_OF_DAY, 0)
        c.set(Calendar.MINUTE, 0)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis
    }

    /** package -> seconds in the foreground between [start] and [end] (epoch ms). */
    @Suppress("DEPRECATION")
    fun secondsByPackage(ctx: Context, start: Long, end: Long): Map<String, Long> {
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(start, end)
        val ev = UsageEvents.Event()
        val resumedAt = HashMap<String, Long>()
        val totals = HashMap<String, Long>()

        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            val pkg = ev.packageName ?: continue
            when (ev.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> resumedAt[pkg] = ev.timeStamp
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    val s = resumedAt.remove(pkg)
                    if (s != null && ev.timeStamp >= s) {
                        totals[pkg] = (totals[pkg] ?: 0L) + (ev.timeStamp - s)
                    }
                }
            }
        }
        // Apps still on screen right now.
        for ((pkg, s) in resumedAt) {
            if (end >= s) totals[pkg] = (totals[pkg] ?: 0L) + (end - s)
        }
        return totals.mapValues { it.value / 1000L }
    }

    private fun homePackage(ctx: Context): String? {
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        return ctx.packageManager.resolveActivity(intent, PackageManager.MATCH_DEFAULT_ONLY)
            ?.activityInfo?.packageName
    }

    fun label(ctx: Context, pkg: String): String {
        return try {
            val pm = ctx.packageManager
            pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
        } catch (e: Exception) {
            pkg
        }
    }

    /** Apps the person can launch, with their usage; system chrome and this app are left out. */
    fun usageBetween(ctx: Context, start: Long, end: Long): List<Map<String, Any>> {
        val pm = ctx.packageManager
        val home = homePackage(ctx)
        return secondsByPackage(ctx, start, end)
            .filter { (pkg, secs) ->
                secs >= 1 && pkg != ctx.packageName && pkg != home &&
                    pm.getLaunchIntentForPackage(pkg) != null
            }
            .map { (pkg, secs) ->
                mapOf<String, Any>("package" to pkg, "name" to label(ctx, pkg), "seconds" to secs)
            }
            .sortedByDescending { it["seconds"] as Long }
    }

    fun installedApps(ctx: Context): List<Map<String, Any>> {
        val pm = ctx.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .map { it.activityInfo.packageName to it.loadLabel(pm).toString() }
            .filter { it.first != ctx.packageName }
            .distinctBy { it.first }
            .sortedBy { it.second.lowercase() }
            .map { mapOf<String, Any>("package" to it.first, "name" to it.second) }
    }
}
