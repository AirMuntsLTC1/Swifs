#!/usr/bin/env bash
# Archives old SQL and migrations. Nothing is deleted, so you can always get it back.
set -e
mkdir -p supabase/archive

# Unused PHP mock backend (the app never calls it)
git rm -r -q --ignore-unmatch backend

# Old migrations use column names that differ from the live database.
# Moving them out keeps "supabase db push" from running them.
for f in supabase/migrations/20240101*.sql; do
  [ -e "$f" ] && git mv "$f" supabase/archive/ || true
done

# Setup files that duplicate migrations (already run in the SQL Editor)
for f in supabase/schema.sql supabase/comment_likes.sql supabase/stories_setup.sql \
         supabase/messages_setup.sql supabase/message_menu_setup.sql supabase/user_settings.sql; do
  [ -e "$f" ] && git mv "$f" supabase/archive/ || true
done

echo "Cleanup done. Review with: git status"
