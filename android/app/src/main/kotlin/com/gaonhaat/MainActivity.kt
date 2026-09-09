package com.kusbilo

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "kusbilo/audio_mode"

    // Android sirf ye batata hai ki SCO (Bluetooth headset) connection
    // bana ki nahi, iss broadcast ke through — synchronously pata nahi
    // chalta. Jab tak ye receiver "connected" na bole, hum
    // isBluetoothScoOn ko true nahi karte, warna agar headset available
    // hi nahi hai (ya connect hone mein time lag raha hai) to audio ek
    // "phantom" Bluetooth path pe chala jaata hai jo kahin nahi jaata —
    // na earpiece, na speaker, na Bluetooth — aur call bilkul silent ho
    // jaati hai.
    private var scoReceiver: BroadcastReceiver? = null
    private var scoReceiverRegistered = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (call.method == "setAudioMode") {
                // OS ko "voice call" mode me daalta hai — isse hi phone ka
                // built-in echo canceller sahi se kaam karta hai. Iske bina
                // mic apni hi speaker ki awaaz sun leta hai aur app galti se
                // samajh leta hai buyer bol raha hai, AI ko beech me kaat deta hai.
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                // Asli call jaisa: default earpiece (speaker OFF) jab tak
                // Bluetooth actually connect na ho jaaye (neeche receiver
                // dekho). Speakerphone par mic-se-speaker ka echo path lamba
                // ho jaata hai, jisse built-in AEC ko cancel karna zyada
                // mushkil hota hai.
                audioManager.isSpeakerphoneOn = false
                audioManager.isBluetoothScoOn = false

                registerScoReceiver(audioManager)
                // Sirf request karta hai — connection turant nahi banta.
                // Agar koi Bluetooth headset connected/available nahi hai to
                // ye silently kuch nahi karega aur normal earpiece/speaker
                // path hi chalta rahega.
                audioManager.startBluetoothSco()
                result.success(null)
            } else if (call.method == "stopAudioMode") {
                unregisterScoReceiver()
                audioManager.stopBluetoothSco()
                audioManager.isBluetoothScoOn = false
                audioManager.mode = AudioManager.MODE_NORMAL
                audioManager.isSpeakerphoneOn = false
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun registerScoReceiver(audioManager: AudioManager) {
        if (scoReceiverRegistered) return
        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                val state = intent.getIntExtra(
                    AudioManager.EXTRA_SCO_AUDIO_STATE,
                    AudioManager.SCO_AUDIO_STATE_ERROR
                )
                if (state == AudioManager.SCO_AUDIO_STATE_CONNECTED) {
                    // Ab hi Bluetooth headset ka mic/speaker actually ready
                    // hai — tabhi audio ko us path pe bhejna safe hai.
                    audioManager.isBluetoothScoOn = true
                } else if (state == AudioManager.SCO_AUDIO_STATE_DISCONNECTED) {
                    // Headset disconnect ho gaya (ya connect hi nahi hua) —
                    // wapas normal earpiece/speaker path pe fall back karo,
                    // taaki audio kabhi bhi silent na ho.
                    audioManager.isBluetoothScoOn = false
                }
            }
        }
        val filter = IntentFilter(AudioManager.ACTION_SCO_AUDIO_STATE_UPDATED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(receiver, filter)
        }
        scoReceiver = receiver
        scoReceiverRegistered = true
    }

    private fun unregisterScoReceiver() {
        if (!scoReceiverRegistered) return
        scoReceiver?.let { unregisterReceiver(it) }
        scoReceiver = null
        scoReceiverRegistered = false
    }

    override fun onDestroy() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        unregisterScoReceiver()
        audioManager.stopBluetoothSco()
        audioManager.isBluetoothScoOn = false
        audioManager.mode = AudioManager.MODE_NORMAL
        audioManager.isSpeakerphoneOn = false
        super.onDestroy()
    }
}
