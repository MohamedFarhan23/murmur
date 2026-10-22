package com.farhan.murmur

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Opens the system share sheet; see lib/platform/share.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.farhan.murmur/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "text") return@setMethodCallHandler result.notImplemented()
                val send = Intent(Intent.ACTION_SEND).apply {
                    type = "text/plain"
                    putExtra(Intent.EXTRA_TEXT, call.argument<String>("text"))
                    call.argument<String>("subject")?.let { putExtra(Intent.EXTRA_SUBJECT, it) }
                }
                startActivity(Intent.createChooser(send, null))
                result.success(null)
            }
    }
}
