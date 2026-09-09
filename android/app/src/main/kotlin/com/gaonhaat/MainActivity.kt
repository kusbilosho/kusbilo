package com.kusbilo

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "kusbilo/audio_mode"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "setAudioMode") {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                // OS ko "voice call" mode me daalta hai — isse hi phone ka
                // built-in echo canceller sahi se kaam karta hai. Iske bina
                // mic apni hi speaker ki awaaz sun leta hai aur app galti se
                // samajh leta hai buyer bol raha hai, AI ko beech me kaat deta hai.
                audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
                // Asli call jaisa: default earpiece (speaker OFF). Speakerphone
                // par mic-se-speaker ka echo path lamba ho jaata hai, jisse
                // built-in AEC ko cancel karna zyada mushkil hota hai — isiliye
                // pehle yahan speaker forced-on tha to hi thoda "khar-khar"/echo
                // sunayi deta tha. Earpiece default rakhne se AEC bahut behtar
                // kaam karta hai, bilkul real phone call jaisa.
                audioManager.isSpeakerphoneOn = false
                // MODE_IN_COMMUNICATION akela kaafi nahi hai Bluetooth ke liye —
                // jab tak hum explicitly SCO (Synchronous Connection-Oriented)
                // link start nahi karte, Android audio ko hamesha phone ke
                // earpiece pe hi route karega, chahe headset connected ho ya
                // na ho. Isi wajah se pehle Bluetooth connected hone par bhi
                // awaaz sirf earpiece se aa rahi thi. Ye do lines Bluetooth
                // headset ke mic+speaker ko actually activate karti hain.
                audioManager.isBluetoothScoOn = true
                audioManager.startBluetoothSco()
                result.success(null)
            } else if (call.method == "stopAudioMode") {
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
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

    override fun onDestroy() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.stopBluetoothSco()
        audioManager.isBluetoothScoOn = false
        audioManager.mode = AudioManager.MODE_NORMAL
        audioManager.isSpeakerphoneOn = false
        super.onDestroy()
    }
}
