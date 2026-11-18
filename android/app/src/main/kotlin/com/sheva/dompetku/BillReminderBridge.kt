package com.sheva.dompetku

import android.Manifest
import android.os.Build
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

class BillReminderBridge(private val activity: MainActivity, messenger: BinaryMessenger) {
    private val scheduler = BillReminderScheduler(activity)
    private val channel = MethodChannel(messenger, "com.sheva.dompetku/bill_reminders")
    private var permissionResult: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                val account = call.argument<String>("account")
                when (call.method) {
                    "activate" -> result.success(scheduler.activate(requireNotNull(account)))
                    "deactivate" -> { scheduler.deactivate(account); result.success(null) }
                    "ackOpen" -> { scheduler.acknowledgeOpen(account); result.success(null) }
                    "dismissRecommendation" -> { scheduler.dismissRecommendation(requireNotNull(account)); result.success(null) }
                    "setEnabled" -> { scheduler.setEnabled(requireNotNull(account), call.argument<Boolean>("enabled") == true); result.success(null) }
                    "replaceSchedule" -> {
                        scheduler.replace(requireNotNull(account), call.argument<List<Map<String, Any?>>>("reminders") ?: emptyList())
                        result.success(null)
                    }
                    "requestPermission" -> {
                        if (Build.VERSION.SDK_INT < 33 || scheduler.permission() == "granted") result.success(scheduler.permission())
                        else if (permissionResult != null) result.error("permission-busy", "Permintaan izin masih berlangsung.", null)
                        else {
                            scheduler.askedPermission()
                            permissionResult = result
                            ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                result.error("reminders-unavailable", "Pengingat belum dapat diperbarui.", null)
            }
        }
    }
    fun onPermissionResult(requestCode: Int) {
        if (requestCode != REQUEST) return
        permissionResult?.success(scheduler.permission())
        permissionResult = null
    }
    fun opened(account: String?) {
        scheduler.rememberOpen(account)
        if (account != null) channel.invokeMethod("openBills", account)
    }
    companion object { const val REQUEST = 5721 }
}
