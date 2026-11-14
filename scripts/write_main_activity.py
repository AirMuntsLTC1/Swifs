# Writes MainActivity.kt with the native notification channel. Runs in CI after flutter create.
# Replaces string patching of the template, which did not match the generated file.
import pathlib, sys

APP_DIR = pathlib.Path('app/android/app')
if not APP_DIR.exists():
    sys.exit('app/android/app not found. Run flutter create first.')

target = APP_DIR / 'src/main/kotlin/com/swifs/swifs/MainActivity.kt'
target.parent.mkdir(parents=True, exist_ok=True)

KOTLIN = '''package com.swifs.swifs

import com.swifs.native.NotificationManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.swifs.native/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val nativeManager = NotificationManager(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "showNotification") {
                    val id = call.argument<Int>("id") ?: 0
                    val title = call.argument<String>("title") ?: ""
                    val body = call.argument<String>("body") ?: ""
                    val avatarUrl = call.argument<String>("avatarUrl")
                    nativeManager.showNotification(id, title, body, avatarUrl)
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }
}
'''

target.write_text(KOTLIN, encoding='utf-8')
print(f'MainActivity.kt written: {target}')
