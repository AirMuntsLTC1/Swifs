import pathlib
import re

p = pathlib.Path('android/app/build.gradle')
if not p.exists():
    print('build.gradle not found, skipping optimization')
    exit(0)

s = p.read_text()

# 1. Force compileSdk to 35 to support audioplayers (handles any flutter default)
s = re.sub(r'compileSdk\s*=\s*[^\n]+', 'compileSdk = 35', s)
s = re.sub(r'compileSdkVersion\s*[^\n]+', 'compileSdkVersion 35', s)

# 2. Apply size optimizations (packagingOptions)
block = '''    packagingOptions {
        jniLibs {
            useLegacyPackaging true
        }
        resources {
            excludes += [
                'META-INF/*.kotlin_module', 'META-INF/*.version',
                'META-INF/AL2.0', 'META-INF/LGPL2.1',
                'META-INF/LICENSE*', 'META-INF/NOTICE*',
                'META-INF/DEPENDENCIES', 'META-INF/proguard/*',
                'META-INF/gradle/incremental.annotation.processors'
            ]
        }
    }
'''

if 'packagingOptions' not in s:
    s = s.replace('android {', 'android {\n' + block, 1)

p.write_text(s)
print('✅ build.gradle optimized: compileSdk set to 35 and packagingOptions applied')
