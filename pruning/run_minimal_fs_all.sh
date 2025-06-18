#!/usr/bin/env bash
set -euo pipefail

LOG_ENABLED=0

usage() {
  echo "Usage: $0 [--verbose] <lang>"
  exit 1
}

if [[ "$1" == "--verbose" ]]; then
  LOG_ENABLED=1
  shift
fi

if [[ "$#" -ne 1 ]]; then
  usage
fi
lang="$1"


BASE_EX_ROOT="/var/tmp/opt/student-exercises"
TEST_REPO="/var/tmp/opt/test-repository/$lang"
PRUNE_SCRIPT="/var/tmp/opt/pruning/detect_minimal_fs.sh"
BUILD_SCRIPT="$TEST_REPO/build_script.sh"
OUTPUT_DIR="/var/tmp/opt/bindings-results"
PATH_SETS="/var/tmp/opt/path_sets"

EX_ROOT="$BASE_EX_ROOT/$lang"

mkdir -p "$OUTPUT_DIR" "$PATH_SETS"

TARGET_SRC="$TEST_REPO/assignment/src"

log() {
    if [[ "$LOG_ENABLED" -eq 1 ]]; then
        echo "[LOG] $*"
    fi
}

for ex_dir in "$EX_ROOT"/*; do
  [[ -d "$ex_dir/src" ]] || { log "No src in $ex_dir – skipping"; continue; }

  ex_name=$(basename "$ex_dir")
  log "=== Processing $ex_name ($lang) ==="

  rm -rf "$TARGET_SRC"
  mkdir -p "$TARGET_SRC"
  cp -r "$ex_dir/src/"* "$TARGET_SRC/"
  cd "/var/tmp/opt"

  pushd "$TEST_REPO" >/dev/null

  PRUNE_ARGS=(
    --script "$BUILD_SCRIPT"
    --lang "$lang"
    --env "GRADLE_USER_HOME=/tmp/cache/gradle_home"
    --env "GRADLE_OPTS=-Dmaven.repo.local=/tmp/cache/m2_repo"
    --assignment-dir "$TEST_REPO/assignment"
    --test-dir "$TEST_REPO/test"
  )

  if [[ "$LOG_ENABLED" -eq 1 ]]; then
    PRUNE_ARGS=( --verbose "${PRUNE_ARGS[@]}" )
  fi

  "$PRUNE_SCRIPT" "${PRUNE_ARGS[@]}"

  popd >/dev/null

  mv "$TEST_REPO/final_bindings.txt" \
     "$OUTPUT_DIR/final_bindings_${lang}_${ex_name}.txt"
  mv "$TEST_REPO/final_bwrap.sh" \
     "$OUTPUT_DIR/final_bwrap_${lang}_${ex_name}.sh"

  python3 /var/tmp/opt/helpers/preprocess_bindings.py \
      "$OUTPUT_DIR/final_bindings_${lang}_${ex_name}.txt" \
      "$lang" "$ex_name" "$PATH_SETS"

  log "=== $ex_name done – results in $OUTPUT_DIR and $PATH_SETS ==="
done