#!/usr/bin/env python3
"""Makes Gradle build the C++ core into the app, and adds Android permissions."""
import pathlib
import sys

CMAKE_BLOCK_GROOVY = (
    '    externalNativeBuild {\n'
    '        cmake {\n'
    '            path "src/main/cpp/CMakeLists.txt"\n'
    '        }\n'
    '    }\n'
)
CMAKE_BLOCK_KTS = (
    '    externalNativeBuild {\n'
    '        cmake {\n'
    '            path = file("src/main/cpp/CMakeLists.txt")\n'
    '        }\n'
    '    }\n'
)


def patch_gradle() -> None:
    kts = pathlib.Path('android/app/build.gradle.kts')
    groovy = pathlib.Path('android/app/build.gradle')
    if kts.exists():
        path, block = kts, CMAKE_BLOCK_KTS
    elif groovy.exists():
        path, block = groovy, CMAKE_BLOCK_GROOVY
    else:
        sys.exit('android/app/build.gradle not found. Run flutter create first.')

    text = path.read_text(encoding='utf-8')
    if 'externalNativeBuild' in text:
        print('gradle: C++ build already wired')
        return
    assert 'android {' in text, 'android { block not found in ' + path.name
    text = text.replace('android {', 'android {\n' + block, 1)
    path.write_text(text, encoding='utf-8')
    print('gradle: C++ core will be built into the app')


def patch_manifest() -> None:
    manifest = pathlib.Path('android/app/src/main/AndroidManifest.xml')
    text = manifest.read_text(encoding='utf-8')

    permissions = (
        '<uses-permission android:name="android.permission.INTERNET" />\n'
        '    <uses-permission android:name="android.permission.CAMERA" />\n'
        '    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />\n'
        '    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />\n'
        '    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />\n'
        '    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />\n'
        '    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />\n'
        '    '
    )

    if 'READ_MEDIA_IMAGES' not in text:
        # Add all permissions right before <application
        text = text.replace('<application', permissions + '<application', 1)

    if 'usesCleartextTraffic' not in text:
        text = text.replace('<application', '<application\n        android:usesCleartextTraffic="true"', 1)

    manifest.write_text(text, encoding='utf-8')
    print('manifest: permissions and local http allowed')


if __name__ == '__main__':
    patch_gradle()
    patch_manifest()
