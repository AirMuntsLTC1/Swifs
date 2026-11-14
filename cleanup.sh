#!/usr/bin/env bash
# Safe cleanup. Moves files, deletes nothing. Does NOT touch supabase/migrations/.
set -e
mkdir -p supabase/archive

# Unused PHP mock backend (the app never calls it)
git rm -r -q --ignore-unmatch backend

# Top-level setup SQL that duplicates migrations (already applied in the database)
for f in supabase/schema.sql supabase/comment_likes.sql supabase/stories_setup.sql \
         supabase/messages_setup.sql supabase/message_menu_setup.sql supabase/user_settings.sql; do
  [ -e "$f" ] && git mv "$f" supabase/archive/ || true
done

echo "Cleanup done. Review with: git status"
