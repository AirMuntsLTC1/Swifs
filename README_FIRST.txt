SWIFS PATCH 8: the last analyzer error and the story camera warnings.

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-patch-8.zip
  python3 apply_ci_fix.py
  rm -f apply_ci_fix.py
  git add -A
  git commit -m "Patch 8: CI template test and analyzer warnings"
  git push
