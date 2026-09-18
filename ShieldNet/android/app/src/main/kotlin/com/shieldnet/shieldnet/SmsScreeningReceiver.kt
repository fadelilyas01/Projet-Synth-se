package com.shieldnet.shieldnet

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import android.util.Log

class SmsScreeningReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "ShieldNetSms"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            
            for (sms in messages) {
                val rawNumber = sms.displayOriginatingAddress
                if (!rawNumber.isNullOrEmpty()) {
                    val phoneHash = ShieldNetDatabaseHelper.hashPhoneNumber(context, rawNumber)
                    Log.d(TAG, "SMS reçu depuis $rawNumber -> Hash: $phoneHash")
                    
                    if (ShieldNetDatabaseHelper.isNumberBlacklisted(context, phoneHash)) {
                        Log.w(TAG, "SMS SPAM bloqué depuis le numéro: $rawNumber (hash: $phoneHash)")
                        // Avorte la diffusion du SMS
                        abortBroadcast()
                    }
                }
            }
        }
    }
}

