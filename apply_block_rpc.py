# One-time patch: makes blockUser call the block_user RPC.
import pathlib, re, sys

p = pathlib.Path('app/lib/core/data/supabase_social_repository.dart')
if not p.exists():
    sys.exit('Run this from the repo root (the folder that contains app/).')

text = p.read_text(encoding='utf-8')
if "'block_user'" in text:
    print('blockUser already uses the RPC. Nothing to do.')
    sys.exit(0)

pattern = re.compile(
    r"Future<void> blockUser\(String userId\) => _guard\(\(\) async \{.*?\n\s*\}\);",
    re.S,
)
found = pattern.findall(text)
if len(found) != 1:
    sys.exit(f'Expected one blockUser method, found {len(found)}. Send me the file.')

new = (
    "Future<void> blockUser(String userId) => _guard(() async {\n"
    "        await _db.rpc('block_user', params: {'p_target': userId});\n"
    "      });"
)
p.write_text(pattern.sub(lambda m: new, text, count=1), encoding='utf-8')
print('blockUser now uses the block_user RPC.')
