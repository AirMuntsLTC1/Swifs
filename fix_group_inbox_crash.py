# One-time patch: stops group messages from crashing the inbox.
import pathlib, sys

p = pathlib.Path('app/lib/core/data/messages_repository.dart')
if not p.exists():
    sys.exit('Run this from the repo root (the folder that contains app/).')

text = p.read_text(encoding='utf-8')
if 'group messages are skipped' in text:
    print('Already applied. Nothing to do.')
    sys.exit(0)

old1 = "recipientId: r['recipient'].toString(),"
new1 = "recipientId: (r['recipient'] ?? '').toString(),"
old2 = "      final other = m.senderId == me ? m.recipientId : m.senderId;"
new2 = ("      // group messages are skipped here: they have no recipient. (group messages are skipped)\n"
        "      if (m.groupId != null) continue;\n"
        "      final other = m.senderId == me ? m.recipientId : m.senderId;")

for old, new in [(old1, new1), (old2, new2)]:
    n = text.count(old)
    if n != 1:
        sys.exit(f'Expected one match for: {old.strip()} (found {n}). Send me the file.')
    text = text.replace(old, new, 1)

p.write_text(text, encoding='utf-8')
print('Group inbox crash fixed.')
