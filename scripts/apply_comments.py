#!/usr/bin/env python3
"""Wires the feed's comment button to the new comments sheet.

Run from your project root:  python3 scripts/apply_comments.py
"""
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parent.parent
path = ROOT / 'app' / 'lib' / 'features' / 'home' / 'home_screen.dart'
src = path.read_text(encoding='utf-8')

IMPORT_LINE = "import '../../core/native/swifs_ffi.dart';"
NEW_IMPORT = "import '../comments/comments_sheet.dart';"
if NEW_IMPORT not in src:
    assert src.count(IMPORT_LINE) == 1, 'could not find swifs_ffi import in home_screen.dart'
    src = src.replace(IMPORT_LINE, IMPORT_LINE + '\n' + NEW_IMPORT)

pattern = re.compile(
    r"(icon: LucideIcons\.messageCircle,\s*isActive: false,\s*activeColor: Colors\.black,\s*onTap: )\(\) \{\},"
)
found = len(pattern.findall(src))
assert found == 1, f'comment button found {found} times, expected 1'
src = pattern.sub(r"\1() => showCommentsSheet(context, postId: p['id']),", src)

path.write_text(src, encoding='utf-8')
print('Comment button now opens the comments sheet.')


