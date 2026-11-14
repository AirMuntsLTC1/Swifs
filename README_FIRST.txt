SWIFS PATCH 7: fix the flutter analyze error and simple warnings.

  cd ~/Swifs
  unzip -o ~/storage/downloads/swifs-patch-7.zip
  python3 apply_analyzer_fixes.py
  rm -f apply_analyzer_fixes.py
  git add -A
  git commit -m "Patch 7: analyzer fixes"
  git push

Then run: flutter analyze
Info-level hints are fine for now. The CI build fails only on errors.
