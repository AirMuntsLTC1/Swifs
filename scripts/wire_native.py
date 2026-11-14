#!/usr/bin/env python3
"""Makes Gradle build the C++ core into the app, and allows the app to reach the local PHP server.

Runs in CI from the app folder, after `flutter create` generates android/:
    python3 ../scripts/wire_native.py
Safe to run twice.
"""
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
    if 'android.permission.INTERNET' not in text:
        text = text.replace(
            '<application',
            '<uses-permission android:name="android.permission.INTERNET" />\n    <application',
            1,
        )
    if 'usesCleartextTraffic' not in text:
        # Lets the app talk to the local PHP server over http://127.0.0.1
        text = text.replace('<application', '<application\n        android:usesCleartextTraffic="true"', 1)
    manifest.write_text(text, encoding='utf-8')
    print('manifest: internet permission and local http allowed')


if __name__ == '__main__':
    patch_gradle()
    patch_manifest()


