#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <lang>"
  exit 1
fi
lang="$1"

BASE_EX_ROOT="/opt/student-exercises"
TEST_REPO="/opt/test-repository"
PRUNE_SCRIPT="/opt/detect_minimal_fs.sh"
BUILD_SCRIPT="$TEST_REPO/build_script.sh"
OUTPUT_DIR="/opt/bindings-results"

EX_ROOT="$BASE_EX_ROOT/student-exercises-$lang"

mkdir -p "$OUTPUT_DIR"

# Where the student code must land inside the test repository
TARGET_SRC="$TEST_REPO/assignment/src"

for ex_dir in "$EX_ROOT"/*; do
    [[ -d "$ex_dir/src" ]] || { echo "No src in $ex_dir – skipping"; continue; }

    ex_name=$(basename "$ex_dir")
    echo "=== Processing $ex_name ($lang) ==="

    # 1. Clean & copy student source into the test repository
    rm -rf "$TARGET_SRC"
    mkdir -p "$TARGET_SRC"
    cp -r "$ex_dir/src/"* "$TARGET_SRC/"
    cd "/opt"

    # 2. Run minimal-fs detection (Gradle build/tests)
    pushd "$TEST_REPO" >/dev/null

    "$PRUNE_SCRIPT" \
        --script "$BUILD_SCRIPT" \
        --env "GRADLE_USER_HOME=/tmp/cache/gradle_home" \
        --env "GRADLE_OPTS=-Dmaven.repo.local=/tmp/cache/m2_repo"

    popd >/dev/null

    # 3. Archive the result
    mv "$TEST_REPO/final_bindings.txt" \
       "$OUTPUT_DIR/final_bindings_${lang}_${ex_name}.txt"
    mv "$TEST_REPO/final_bwrap.sh" \
       "$OUTPUT_DIR/final_bwrap_${lang}_${ex_name}.sh"

    echo "=== $ex_name done – results in $OUTPUT_DIR ==="
done
