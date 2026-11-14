#!/usr/bin/env python3
"""Swifs UI validator. Run: python3 scripts/setup.py"""

import os
import sys
import json

UI_FILES = [
    'app/pubspec.yaml',
    'app/lib/main.dart',
    'app/lib/features/home/home_screen.dart',
    'app/lib/features/explore/explore_screen.dart',
    'app/lib/features/create/create_screen.dart',
    'app/lib/features/notifications/notifications_screen.dart',
    'app/lib/features/profile/profile_screen.dart',
]

NATIVE_FILES = [
    'app/native/CMakeLists.txt',
    'app/native/src/swifs_core.cpp',
    'app/native/include/swifs_core.h',
    'app/lib/core/native/swifs_ffi.dart',
    'android-native/bridge/src/main/kotlin/com/swifs/native/NativeBridge.kt',
]

BACKEND_FILES = [
    'backend/composer.json',
    'backend/public/index.php',
    'backend/src/Core/Router.php',
    'backend/routes/api.php',
    'backend/config/config.php',
]

CI_FILES = [
    '.github/workflows/build.yml',
    '.github/workflows/backend-ci.yml',
]

def check(label, files):
    missing = [f for f in files if not os.path.exists(f)]
    if missing:
        print('[FAIL] ' + label + ' missing:')
        for m in missing:
            print('  - ' + m)
        return False
    print('[OK] ' + label + ': ' + str(len(files)) + ' files')
    return True

def check_no_db():
    if os.path.exists('backend/database'):
        print('[FAIL] backend/database should not exist')
        return False
    print('[OK] No database folder')
    return True

def check_no_supabase():
    refs = 0
    for path in ('backend/config/config.php', 'backend/routes/api.php'):
        if os.path.exists(path):
            with open(path, encoding='utf-8', errors='ignore') as f:
                refs += f.read().lower().count('supabase')
    if refs > 0:
        print('[FAIL] Supabase references found: ' + str(refs))
        return False
    print('[OK] Zero Supabase references')
    return True

def check_json():
    try:
        with open('backend/composer.json', encoding='utf-8') as f:
            json.load(f)
        print('[OK] composer.json valid')
        return True
    except Exception as e:
        print('[FAIL] composer.json: ' + str(e))
        return False

def count_loc():
    total = 0
    by_ext = {}
    for root, _, files in os.walk('.'):
        if '.git' in root.split(os.sep):
            continue
        for f in files:
            ext = os.path.splitext(f)[1]
            if ext in ('.dart', '.php', '.cpp', '.h', '.kt', '.yaml', '.yml', '.py'):
                try:
                    with open(os.path.join(root, f), encoding='utf-8', errors='ignore') as fh:
                        n = sum(1 for _ in fh)
                    total += n
                    by_ext[ext] = by_ext.get(ext, 0) + n
                except Exception:
                    pass
    print('[INFO] LOC total: ' + str(total))
    for ext, n in sorted(by_ext.items()):
        print('  ' + ext + ': ' + str(n))

if __name__ == '__main__':
    ok = True
    ok = check('UI screens', UI_FILES) and ok
    ok = check('Native layer', NATIVE_FILES) and ok
    ok = check('Backend mocks', BACKEND_FILES) and ok
    ok = check('CI workflows', CI_FILES) and ok
    ok = check_no_db() and ok
    ok = check_no_supabase() and ok
    ok = check_json() and ok
    count_loc()
    sys.exit(0 if ok else 1)
