package __PACKAGE__

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Foreground service that watches which app is on screen. When an app with a
 * limit reaches its warning level it posts a notification; when the limit is
 * reached it draws a popup in the middle of the screen.
 */
class MonitorService : Service() {

    companion object {
        @Volatile
        var running = false
        private const val CH_MONITOR = "ls_monitor"
        private const val CH_ALERTS = "ls_alerts"
        private const val NOTIF_MONITOR = 4201
        private const val POLL_MS = 2000L
        private const val SNOOZE_MS = 5 * 60 * 1000L
        private const val CACHE_MS = 10_000L
    }

    private val handler = Handler(Looper.getMainLooper())
    private var lastQuery = 0L
    private var current: String? = null
    private var pending = false
    private val snooze = HashMap<String, Long>()
    private val notified = HashSet<String>()
    private val usedCache = HashMap<String, Pair<Long, Long>>() // pkg -> (computedAt, seconds)

    private var overlay: View? = null
    private var overlayPkg: String? = null

    private val tick = object : Runnable {
        override fun run() {
            try {
                check()
            } catch (e: Exception) {
                // Keep the monitor alive whatever happens in one pass.
            }
            handler.postDelayed(this, POLL_MS)
        }
    }

    // ------------------------------------------------------------ lifecycle
    override fun onCreate() {
        super.onCreate()
        createChannels()
        val n = foregroundNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF_MONITOR, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_MONITOR, n)
        }
        running = true
        lastQuery = System.currentTimeMillis() - 15_000L
        handler.post(tick)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int = START_STICKY

    override fun onDestroy() {
        running = false
        handler.removeCallbacks(tick)
        removeOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    // ------------------------------------------------------------ monitoring
    @Suppress("DEPRECATION")
    private fun updateCurrent(now: Long) {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val events = usm.queryEvents(lastQuery, now)
        val ev = UsageEvents.Event()
        var changed = false
        while (events.hasNextEvent()) {
            events.getNextEvent(ev)
            val pkg = ev.packageName ?: continue
            when (ev.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> if (current != pkg) {
                    current = pkg
                    changed = true
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> if (current == pkg) {
                    current = null
                    changed = true
                }
            }
        }
        lastQuery = now - 1000L // small overlap so no event is missed at the boundary
        if (changed) {
            if (current != null) pending = true
            if (overlayPkg != null && overlayPkg != current) removeOverlay()
        }
    }

    private fun usedSeconds(pkg: String, now: Long): Long {
        val cached = usedCache[pkg]
        if (cached != null && now - cached.first < CACHE_MS) {
            return cached.second + (now - cached.first) / 1000L
        }
        val secs = UsageReader.secondsByPackage(this, UsageReader.startOfDay(now), now)[pkg] ?: 0L
        usedCache[pkg] = Pair(now, secs)
        return secs
    }

    private fun check() {
        val now = System.currentTimeMillis()
        updateCurrent(now)
        val pkg = current ?: return
        val limit = LimitStore.load(this).firstOrNull { it.pkg == pkg }
        if (limit == null) {
            removeOverlay()
            return
        }

        val used = usedSeconds(pkg, now)
        val limitSeconds = limit.minutes * 60L
        val day = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(now))

        if (used >= limitSeconds) {
            if (notified.add("over|$day|$pkg")) {
                alert(pkg.hashCode(), "Daily limit reached", "You've hit your daily limit for ${limit.name}.")
            }
            val until = snooze[pkg] ?: 0L
            if (overlay == null && now >= until && (pending || until > 0L)) {
                showOverlay(limit, used, limitSeconds)
                pending = false
                snooze.remove(pkg)
            }
        } else if (used * 100.0 / limitSeconds >= limit.warnPercent) {
            if (notified.add("warn|$day|$pkg")) {
                val left = limitSeconds - used
                alert(pkg.hashCode() + 1, "Almost at your limit", "${fmt(left)} left for ${limit.name} today.")
            }
        }
    }

    // ------------------------------------------------------------ text
    private fun fmt(seconds: Long): String {
        val s = if (seconds < 0) 0 else seconds
        val h = s / 3600
        val m = (s % 3600) / 60
        return if (h > 0) "${h}h ${m}m" else "${m}m"
    }

    // ------------------------------------------------------------ notifications
    private fun createChannels() {
        if (Build.VERSION.SDK_INT < 26) return
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(
            NotificationChannel(CH_MONITOR, "Limit monitor", NotificationManager.IMPORTANCE_MIN)
                .apply { description = "Shows while Learn Sphere watches your limits." }
        )
        nm.createNotificationChannel(
            NotificationChannel(CH_ALERTS, "Limit alerts", NotificationManager.IMPORTANCE_HIGH)
                .apply { description = "Warnings before and when you reach an app limit." }
        )
    }

    private fun launchIntent(): PendingIntent? {
        val i = packageManager.getLaunchIntentForPackage(packageName) ?: return null
        return PendingIntent.getActivity(this, 0, i, PendingIntent.FLAG_IMMUTABLE)
    }

    private fun foregroundNotification(): Notification =
        NotificationCompat.Builder(this, CH_MONITOR)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("Learn Sphere is watching your limits")
            .setContentText("Tap to open")
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setContentIntent(launchIntent())
            .build()

    private fun alert(id: Int, title: String, text: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(
            id,
            NotificationCompat.Builder(this, CH_ALERTS)
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle(title)
                .setContentText(text)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(launchIntent())
                .build()
        )
    }

    // ------------------------------------------------------------ overlay popup
    private fun dp(v: Int): Int =
        TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP, v.toFloat(), resources.displayMetrics
        ).toInt()

    private fun rounded(color: Int, radiusDp: Int): GradientDrawable =
        GradientDrawable().apply {
            setColor(color)
            cornerRadius = dp(radiusDp).toFloat()
        }

    private fun goHome() {
        startActivity(
            Intent(Intent.ACTION_MAIN)
                .addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    private fun showOverlay(limit: LimitStore.Limit, used: Long, limitSeconds: Long) {
        if (!Settings.canDrawOverlays(this)) return
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val title = TextView(this).apply {
            text = "Time's up!"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 28f)
            setTypeface(typeface, Typeface.BOLD)
            gravity = Gravity.CENTER
        }
        val message = TextView(this).apply {
            text = "You are overusing ${limit.name}. You've used it for ${fmt(used)} today " +
                "and your limit was ${fmt(limitSeconds)}."
            setTextColor(0xFF9EA3D6.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.2f)
        }
        val close = Button(this).apply {
            text = "Close ${limit.name}"
            isAllCaps = false
            setTextColor(0xFF121536.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 16f)
            setTypeface(typeface, Typeface.BOLD)
            background = rounded(0xFFF5B544.toInt(), 18)
            setOnClickListener {
                removeOverlay()
                goHome()
            }
        }
        val more = Button(this).apply {
            text = "5 more minutes"
            isAllCaps = false
            setTextColor(0xFF9EA3D6.toInt())
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            background = null
            setOnClickListener {
                snooze[limit.pkg] = System.currentTimeMillis() + SNOOZE_MS
                removeOverlay()
            }
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(26), dp(30), dp(26), dp(18))
            background = rounded(0xFF121536.toInt(), 32)
            addView(title)
            addView(message, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(10) })
            addView(close, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(52)
            ).apply { topMargin = dp(22) })
            addView(more, LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(46)
            ).apply { topMargin = dp(4) })
        }

        val root = FrameLayout(this).apply {
            setBackgroundColor(0xB8121536.toInt())
            val width = minOf(dp(340), resources.displayMetrics.widthPixels - dp(48))
            addView(card, FrameLayout.LayoutParams(
                width, FrameLayout.LayoutParams.WRAP_CONTENT, Gravity.CENTER
            ))
        }

        val type = if (Build.VERSION.SDK_INT >= 26)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            type,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        )

        try {
            wm.addView(root, params)
            overlay = root
            overlayPkg = limit.pkg
        } catch (e: Exception) {
            overlay = null
            overlayPkg = null
        }
    }

    private fun removeOverlay() {
        val v = overlay ?: return
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(v)
        } catch (e: Exception) {
            // already gone
        }
        overlay = null
        overlayPkg = null
    }
}
