SWIFS: PERFORMANCE INDEX MIGRATION

Your `supabase db push --remote` reported "Remote database is up to date", because the
index script was not a migration. This zip adds it as one.

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-perf-index-migration.zip
  supabase db push --remote
  git add -A
  git commit -m "Add perf index migration"
  git push

If db push fails on this file, copy the error line and send it to me.
