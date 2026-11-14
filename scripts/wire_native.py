import pathlib
import sys

def patch_gradle() -> None:
    kts = pathlib.Path('android/app/build.gradle.kts')
    groovy = pathlib.Path('android/app/build.gradle')
    
    if kts.exists():
        path = kts
        block = """
    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }
"""
    elif groovy.exists():
        path = groovy
        block = """
    externalNativeBuild {
        cmake {
            path "src/main/cpp/CMakeLists.txt"
        }
    }
"""
    else:
        sys.exit('android/app/build.gradle not found. Run flutter create first.')

    text = path.read_text(encoding='utf-8')
    if 'externalNativeBuild' in text:
        print('gradle: C++ build already wired')
        return
        
    assert 'android {' in text, 'android { block not found in ' + path.name
    text = text.replace('android {', 'android {' + block, 1)
    path.write_text(text, encoding='utf-8')
    print('gradle: C++ core will be built into the app')


def patch_manifest() -> None:
    manifest = pathlib.Path('android/app/src/main/AndroidManifest.xml')
    text = manifest.read_text(encoding='utf-8')

    permissions = """<uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    """

    if 'READ_MEDIA_IMAGES' not in text:
        text = text.replace('<application', permissions + '<application', 1)

    if 'usesCleartextTraffic' not in text:
        text = text.replace('<application', '<application\n        android:usesCleartextTraffic="true"', 1)

    manifest.write_text(text, encoding='utf-8')
    print('manifest: permissions and local http allowed')


def patch_main_activity() -> None:
    path = pathlib.Path('android/app/src/main/kotlin/com/swifs/swifs/MainActivity.kt')
    if not path.exists(): 
        return
    
    text = path.read_text(encoding='utf-8')
    if 'NotificationManager' in text: 
        return

    text = text.replace(
        'import io.flutter.embedding.android.FlutterActivity',
        'import io.flutter.embedding.android.FlutterActivity\nimport io.flutter.embedding.engine.FlutterEngine\nimport io.flutter.plugin.common.MethodChannel\nimport com.swifs.native.NotificationManager'
    )
    
    activity_block = """
    private val CHANNEL = "com.swifs.native/notifications"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val nativeManager = NotificationManager(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
"""
    
    text = text.replace('class MainActivity: FlutterActivity() {', 'class MainActivity: FlutterActivity() {' + activity_block)
    path.write_text(text, encoding='utf-8')
    print('main_activity: Notification channel wired')


if __name__ == '__main__':
    patch_gradle()
    patch_manifest()
    patch_main_activity()
