package com.shieldnet.shieldnet

import android.content.Context
import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.Q)
class ShieldNetCallScreeningService : CallScreeningService() {

    companion object {
        private const val TAG = "ShieldNetScreening"
    }

    private fun isContactsOnlyEnabled(): Boolean {
        return try {
            val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            if (flutterPrefs.getBoolean("flutter.settings_contacts_only", false)) {
                return true
            }
            val nativePrefs = getSharedPreferences("shieldnet_prefs", Context.MODE_PRIVATE)
            nativePrefs.getBoolean("contacts_only_mode", false)
        } catch (e: Exception) {
            false
        }
    }

    private fun isContact(phoneNumber: String): Boolean {
        return try {
            val uri = android.net.Uri.withAppendedPath(
                android.provider.ContactsContract.PhoneLookup.CONTENT_FILTER_URI,
                android.net.Uri.encode(phoneNumber)
            )
            val projection = arrayOf(android.provider.ContactsContract.PhoneLookup._ID)
            contentResolver.query(uri, projection, null, null, null)?.use { cursor ->
                cursor.moveToFirst()
            } ?: false
        } catch (e: Exception) {
            Log.e(TAG, "Erreur vérification contact: ${e.message}")
            false
        }
    }

    override fun onScreenCall(callDetails: Call.Details) {
        val handle = callDetails.handle
        val rawNumber = handle?.schemeSpecificPart

        if (rawNumber == null) {
            respondToCall(callDetails, CallResponse.Builder().build())
            return
        }

        // 1. Calcul du hash HMAC-SHA256 avec normalisation E.164
        val phoneHash = ShieldNetDatabaseHelper.hashPhoneNumber(applicationContext, rawNumber)
        Log.d(TAG, "Appel entrant reçu: $rawNumber -> Empreinte: $phoneHash")

        // 1.5 PRIORITÉ ABSOLUE : Vérification d'Urgence & Liste Blanche (Immunité Totale)
        if (ShieldNetDatabaseHelper.isEmergencyNumber(applicationContext, rawNumber, phoneHash)) {
            Log.i(TAG, "IMMUNITÉ ACCORDÉE : Appel d'urgence ou contact prioritaire autorisé sans délai ($rawNumber)")
            respondToCall(callDetails, CallResponse.Builder().build())
            return
        }

        // 2. Interrogation directe de la base SQLite partagée (Spam avéré)
        if (ShieldNetDatabaseHelper.isNumberBlacklisted(applicationContext, phoneHash)) {
            Log.w(TAG, "APPEL SPAM BLOQUÉ EN TEMPS RÉEL PAR SHIELDNET ! Empreinte: $phoneHash")
            val response = CallResponse.Builder()
                .setDisallowCall(true)            
                .setRejectCall(true)              
                .setSkipCallLog(false)            
                .setSkipNotification(true)        
                .build()

            respondToCall(callDetails, response)
            return
        }

        // 3. Vérification du Mode Bouclier Strict (Contacts uniquement)
        if (isContactsOnlyEnabled()) {
            val inContacts = isContact(rawNumber)
            if (!inContacts) {
                Log.w(TAG, "APPEL INCONNU REJETÉ (Mode Contacts Uniquement actif) : $rawNumber")
                val response = CallResponse.Builder()
                    .setDisallowCall(true)
                    .setRejectCall(true)
                    .setSkipCallLog(false)
                    .setSkipNotification(false)
                    .build()

                respondToCall(callDetails, response)
                return
            } else {
                Log.d(TAG, "Numéro identifié dans les contacts : $rawNumber")
            }
        }

        Log.d(TAG, "Numéro vérifié et autorisé.")
        respondToCall(callDetails, CallResponse.Builder().build())
    }
}
