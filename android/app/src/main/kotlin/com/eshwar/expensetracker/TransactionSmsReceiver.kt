package com.eshwar.expensetracker

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/** Persists incoming transaction SMS even when no Flutter activity is running. */
class TransactionSmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val parts = Telephony.Sms.Intents.getMessagesFromIntent(intent)
        if (parts.isEmpty()) return
        val body = parts.joinToString("") { it.messageBody.orEmpty() }
        // Only queue financial candidates; full validation happens in Dart.
        if (!Regex("(?i)(?:rs\\.?|inr|₹)\\s*\\d").containsMatchIn(body)) return
        if (!Regex("(?i)\\b(debited|credited|spent|paid|sent|received|withdrawn|deducted|charged|refund)\\b")
                .containsMatchIn(body)) return
        if (Regex("(?i)\\b(otp|verification code|one.time.password)\\b").containsMatchIn(body)) return
        NotificationChannelBridge.initialize(context)
        val pending = goAsync()
        NotificationChannelBridge.enqueueNotification(
            "sms:${parts.first().originatingAddress.orEmpty()}",
            "", body, parts.first().timestampMillis,
        ) { pending.finish() }
    }
}
