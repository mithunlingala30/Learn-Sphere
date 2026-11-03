package __PACKAGE__

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/** Limits pushed from Flutter, kept on the phone so the monitor works offline. */
object LimitStore {
    private const val PREFS = "learnsphere"
    private const val KEY = "limits"

    data class Limit(val pkg: String, val name: String, val minutes: Int, val warnPercent: Int)

    fun save(ctx: Context, limits: List<Limit>) {
        val arr = JSONArray()
        for (l in limits) {
            arr.put(
                JSONObject()
                    .put("pkg", l.pkg)
                    .put("name", l.name)
                    .put("minutes", l.minutes)
                    .put("warn", l.warnPercent)
            )
        }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY, arr.toString()).apply()
    }

    fun load(ctx: Context): List<Limit> {
        val raw = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map {
                val o = arr.getJSONObject(it)
                Limit(
                    o.getString("pkg"),
                    o.optString("name", o.getString("pkg")),
                    o.optInt("minutes", 30),
                    o.optInt("warn", 80)
                )
            }
        } catch (e: Exception) {
            emptyList()
        }
    }
}
