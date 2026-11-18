package com.sheva.dompetku

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/** Local alarms contain only hashed account/occurrence keys and a bill count. */
class BillReminderScheduler(private val context: Context) {
    private val prefs = context.getSharedPreferences("dompetku_bill_reminders", Context.MODE_PRIVATE)
    private val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val notifications = NotificationManagerCompat.from(context)

    fun permission(): String {
        if (Build.VERSION.SDK_INT >= 33 && ContextCompat.checkSelfPermission(
                context, Manifest.permission.POST_NOTIFICATIONS,
            ) != PackageManager.PERMISSION_GRANTED
        ) return if (prefs.getBoolean("asked", false)) "denied" else "default"
        if (!notifications.areNotificationsEnabled()) return "denied"
        if (Build.VERSION.SDK_INT >= 26) {
            val manager = context.getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL)?.importance == NotificationManager.IMPORTANCE_NONE) return "denied"
        }
        return "granted"
    }

    fun activate(account: String): Map<String, Any?> {
        require(ACCOUNT.matches(account))
        if (prefs.getString("account", null) != account) {
            clearAlarms()
            check(prefs.edit().putString("account", account).commit())
        }
        val pending = prefs.getString("pending_open", null)
        check(prefs.edit().remove("pending_open").commit())
        return mapOf(
            "enabled" to prefs.getBoolean("enabled.$account", false),
            "permission" to permission(),
            "recommend" to !prefs.getBoolean("recommended.$account", false),
            "pendingOpen" to pending,
        )
    }

    fun askedPermission() { check(prefs.edit().putBoolean("asked", true).commit()) }
    fun dismissRecommendation(account: String) {
        check(prefs.edit().putBoolean("recommended.$account", true).commit())
    }
    fun setEnabled(account: String, enabled: Boolean) {
        require(account == prefs.getString("account", null))
        check(prefs.edit().putBoolean("enabled.$account", enabled)
            .putBoolean("recommended.$account", true).commit())
        if (!enabled) clearAlarms()
    }

    fun deactivate(account: String?) {
        if (account == null || prefs.getString("account", null) == account) {
            clearAlarms()
            check(prefs.edit().remove("account").remove("pending_open").commit())
        }
    }

    fun rememberOpen(account: String?) {
        if (account != null && ACCOUNT.matches(account)) {
            check(prefs.edit().putString("pending_open", account).commit())
        }
    }
    fun acknowledgeOpen(account: String?) {
        if (prefs.getString("pending_open", null) == account) {
            check(prefs.edit().remove("pending_open").commit())
        }
    }

    fun replace(account: String, values: List<Map<String, Any?>>) {
        if (account != prefs.getString("account", null) || !prefs.getBoolean("enabled.$account", false)) return
        val rows = JSONArray()
        for (value in values) {
            val day = value["day"] as? String ?: error("Invalid day")
            val phase = value["phase"] as? String ?: error("Invalid phase")
            val keys = (value["keys"] as? List<*>)?.filterIsInstance<String>() ?: error("Invalid keys")
            require(DAY.matches(day) && phase in listOf("today", "tomorrow") && keys.isNotEmpty() && keys.all { ACCOUNT.matches(it) })
            rows.put(JSONObject().put("day", day).put("phase", phase).put("keys", JSONArray(keys.distinct())))
        }
        // Cancel old intents before atomically replacing the persisted plan.
        clearAlarms(clearDelivered = false)
        check(prefs.edit().putString("schedule", rows.toString()).commit())
        reschedule()
    }

    fun reschedule() {
        val account = prefs.getString("account", null) ?: return
        if (!prefs.getBoolean("enabled.$account", false) || permission() != "granted") return
        createChannel()
        val rows = schedule()
        for (index in 0 until rows.length()) {
            val row = rows.getJSONObject(index)
            if (row.getString("day") < today() || unseen(row, account).isEmpty()) continue
            // Inexact alarms need no exact-alarm permission and respect Doze.
            val whenMillis = maxOf(time(row.getString("day")), System.currentTimeMillis() + 1000)
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMillis, alarmIntent(account, row))
        }
    }

    fun deliver(account: String, id: String) {
        if (account != prefs.getString("account", null) || !prefs.getBoolean("enabled.$account", false) || permission() != "granted") return
        val rows = schedule()
        val row = (0 until rows.length()).map { rows.getJSONObject(it) }.firstOrNull { rowId(it) == id } ?: return
        if (row.getString("day") != today() || System.currentTimeMillis() < time(today())) return
        val keys = unseen(row, account)
        if (keys.isEmpty()) return
        createChannel()
        val open = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(OPEN_ACCOUNT, account)
            data = Uri.Builder().scheme("dompetku-bill-open").authority(account).appendPath(id).build()
        }
        val tap = PendingIntent.getActivity(context, id.hashCode(), open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val phase = if (row.getString("phase") == "today") "hari ini" else "besok"
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_bill_notification)
            .setContentTitle("Pengingat tagihan")
            .setContentText("${keys.size} tagihan jatuh tempo $phase. Buka DompetKu untuk memeriksa.")
            .setContentIntent(tap)
            .setAutoCancel(true)
            .setVisibility(NotificationCompat.VISIBILITY_PRIVATE)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .build()
        try {
            notifications.notify("dompetku-bills", id.hashCode(), notification)
            val delivered = prefs.getStringSet("delivered.$account", emptySet())!!.toMutableSet()
            delivered.addAll(keys.map { "${today()}:$it" })
            delivered.removeAll { it.substringBefore(':') < today() }
            check(prefs.edit().putStringSet("delivered.$account", delivered).commit())
        } catch (_: SecurityException) { /* Permission can be revoked between checks. */ }
    }

    private fun unseen(row: JSONObject, account: String): List<String> {
        val delivered = prefs.getStringSet("delivered.$account", emptySet())!!
        val keys = row.getJSONArray("keys")
        return (0 until keys.length()).map { keys.getString(it) }
            .filter { !delivered.contains("${row.getString("day")}:$it") }
    }

    private fun clearAlarms(clearDelivered: Boolean = true) {
        val account = prefs.getString("account", null)
        if (account != null) {
            val rows = schedule()
            for (index in 0 until rows.length()) {
                val row = rows.getJSONObject(index)
                val pending = alarmIntent(account, row)
                alarms.cancel(pending)
                pending.cancel()
                notifications.cancel("dompetku-bills", rowId(row).hashCode())
            }
        }
        val edit = prefs.edit().remove("schedule")
        // Retain delivery markers across logout/reopen to avoid repeated alerts.
        if (clearDelivered) edit.remove("pending_open")
        check(edit.commit())
    }
    private fun schedule(): JSONArray = try { JSONArray(prefs.getString("schedule", "[]")) } catch (_: Exception) { JSONArray() }
    private fun rowId(row: JSONObject) = "${row.getString("day")}.${row.getString("phase")}"
    private fun alarmIntent(account: String, row: JSONObject): PendingIntent {
        val intent = Intent(context, BillReminderReceiver::class.java).apply {
            data = Uri.Builder().scheme("dompetku-bill").authority(account).appendPath(rowId(row)).build()
        }
        return PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }
    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= 26) context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(NotificationChannel(CHANNEL, "Pengingat tagihan", NotificationManager.IMPORTANCE_DEFAULT))
    }
    private fun today() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(java.util.Date())
    private fun time(day: String): Long {
        val parts = day.split('-').map { it.toInt() }
        return Calendar.getInstance().apply {
            clear()
            set(parts[0], parts[1] - 1, parts[2], 9, 0, 0)
        }.timeInMillis
    }
    companion object {
        const val OPEN_ACCOUNT = "dompetku_bill_account"
        private const val CHANNEL = "dompetku_bill_reminders"
        private val ACCOUNT = Regex("^[a-f0-9]{64}$")
        private val DAY = Regex("^\\d{4}-\\d{2}-\\d{2}$")
    }
}

class BillReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val uri = intent.data ?: return
        val account = uri.host ?: return
        val id = uri.lastPathSegment ?: return
        BillReminderScheduler(context).deliver(account, id)
    }
}

class BillReminderRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action in listOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_TIME_CHANGED,
                Intent.ACTION_TIMEZONE_CHANGED, Intent.ACTION_MY_PACKAGE_REPLACED)) {
            BillReminderScheduler(context).reschedule()
        }
    }
}
