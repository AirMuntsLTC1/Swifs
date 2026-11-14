import pathlib

p = pathlib.Path('android/app/build.gradle')
if not p.exists():
    print('build.gradle not found, skipping optimization')
    exit(0)

s = p.read_text()
block = '''    packagingOptions {
        jniLibs { useLegacyPackaging = true }
        resources { excludes += setOf(
            'META-INF/*.kotlin_module', 'META-INF/*.version',
            'META-INF/AL2.0', 'META-INF/LGPL2.1',
            'META-INF/LICENSE*', 'META-INF/NOTICE*',
            'META-INF/DEPENDENCIES', 'META-INF/proguard/*',
            'META-INF/gradle/incremental.annotation.processors'
        ) }
    }
'''

if 'packagingOptions' not in s:
    s = s.replace('android {', 'android {\n' + block, 1)
    p.write_text(s)
    print('packagingOptions injected ✓')
else:
    print('packagingOptions already present')
