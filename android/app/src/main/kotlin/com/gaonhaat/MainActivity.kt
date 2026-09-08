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
                audioManager.isSpeakerphoneOn = true
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.mode = AudioManager.MODE_NORMAL
        audioManager.isSpeakerphoneOn = false
        super.onDestroy()
    }
}
