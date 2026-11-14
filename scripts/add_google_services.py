# Adds the Google services plugin to the generated Android project (CI only).
# Works with Kotlin (.kts) and Groovy build files.
import pathlib, re, sys

PLUGIN = 'com.google.gms.google-services'
VERSION = '4.4.2'

def pick(kts, groovy):
    if pathlib.Path(kts).exists():
        return pathlib.Path(kts), True
    if pathlib.Path(groovy).exists():
        return pathlib.Path(groovy), False
    sys.exit(f'Neither {kts} nor {groovy} exists. Run flutter create first.')

settings, is_kts = pick('app/android/settings.gradle.kts', 'app/android/settings.gradle')
text = settings.read_text(encoding='utf-8')
if PLUGIN not in text:
    line = (f'    id("{PLUGIN}") version "{VERSION}" apply false' if is_kts
            else f"    id '{PLUGIN}' version '{VERSION}' apply false")
    pat = r'(\n[ \t]*id[ \t]*\(?[ \t]*["\']com\.android\.application["\'][ \t]*\)?[ \t]*version[ \t]*["\'][^"\']+["\'][ \t]*apply[ \t]+false)'
    found = re.findall(pat, text)
    if len(found) != 1:
        sys.exit(f'settings: expected one com.android.application line, found {len(found)}.')
    text = re.sub(pat, lambda m: m.group(1) + '\n' + line, text, count=1)
    settings.write_text(text, encoding='utf-8')
    print('settings: google services plugin declared')

app, is_kts = pick('app/android/app/build.gradle.kts', 'app/android/app/build.gradle')
text = app.read_text(encoding='utf-8')
if PLUGIN not in text:
    line = f'    id("{PLUGIN}")' if is_kts else f"    id '{PLUGIN}'"
    pat = r'(\n[ \t]*id[ \t]*\(?[ \t]*["\']dev\.flutter\.flutter-gradle-plugin["\'][ \t]*\)?)'
    found = re.findall(pat, text)
    if len(found) != 1:
        sys.exit(f'app build file: expected one flutter gradle plugin line, found {len(found)}.')
    text = re.sub(pat, lambda m: m.group(1) + '\n' + line, text, count=1)
    app.write_text(text, encoding='utf-8')
    print('app: google services plugin applied')
