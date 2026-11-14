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
    'tests/native/test_core.cpp',
    'app/native/include/swifs_core.h',
    'app/lib/core/native/swifs_ffi.dart',
    'android-native/bridge/src/main/kotlin/com/swifs/native/NativeBridge.kt',
]

DATA_FILES = [
    'app/lib/core/data/models.dart',
    'app/lib/core/data/social_repository.dart',
    'app/lib/core/data/mock_social_repository.dart',
    'app/lib/core/data/supabase_social_repository.dart',
    'app/lib/core/data/social.dart',
    'app/lib/core/config/supabase_config.dart',
    'app/lib/core/network/interaction_queue.dart',
    'supabase/schema.sql',
]

CI_FILES = [
    '.github/workflows/build.yml',
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

def check_schema():
    """The schema must create every table and function the app calls."""
    if not os.path.exists('supabase/schema.sql'):
        print('[FAIL] supabase/schema.sql missing')
        return False
    text = open('supabase/schema.sql', encoding='utf-8').read()
    needed = ['get_feed', 'get_comments', 'set_like', 'set_save', 'set_follow', 'add_comment', 'set_comment_like']
    missing = [n for n in needed if ('function public.' + n) not in text]
    if missing:
        print('[FAIL] schema.sql missing functions: ' + ', '.join(missing))
        return False
    print('[OK] schema.sql has all ' + str(len(needed)) + ' functions')
    return True

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
    ok = check('Data layer and Supabase', DATA_FILES) and ok
    ok = check('CI workflows', CI_FILES) and ok
    ok = check_schema() and ok
    count_loc()
    sys.exit(0 if ok else 1)
