#!/usr/bin/env bash
# Builds and runs the C++ core checks. CI runs this on every push.
set -euo pipefail
cd "$(dirname "$0")/../.."
${CXX:-g++} -std=c++17 -Wall -Wextra -Iapp/native/include tests/native/test_core.cpp app/native/src/swifs_core.cpp -o /tmp/swifs_core_test
/tmp/swifs_core_test


