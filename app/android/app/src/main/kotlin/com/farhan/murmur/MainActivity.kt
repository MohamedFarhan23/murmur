package com.farhan.murmur

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var launch: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        // Opens the system share sheet; see lib/platform/share.dart.
        MethodChannel(messenger, "com.farhan.murmur/share")
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
        // Quick transcribe from the home-screen widget; see lib/platform/launch.dart.
        launch = MethodChannel(messenger, "com.farhan.murmur/launch").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "consumeQuick" -> {
                        val quick = intent?.action == QuickWidget.ACTION_QUICK
                        if (quick) intent.action = Intent.ACTION_MAIN
                        result.success(quick)
                    }
                    "moveToBack" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Kept until Dart consumes it, in case Dart isn't listening yet.
        setIntent(intent)
        if (intent.action == QuickWidget.ACTION_QUICK) launch?.invokeMethod("quick", null)
    }
}
