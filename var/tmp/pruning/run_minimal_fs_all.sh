#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# run_minimal_fs_all.sh – prune every *exercise repository* for a single language
# -----------------------------------------------------------------------------
# Expected directory tree (June 2025)
#   /var/tmp/testing-dir/<lang>/<exercise>/
#       ├─ build_script[.sh]      (executable)
#       └─ assignment/src/        (student code; tests embedded or discovered)
#
# Option A implemented: **each exercise is copied to /tmp** so Gradle/Maven can
# freely create/clean `build/` without racing against a read-only NTFS bind.
# All temporary dirs are removed after pruning, keeping the host tree clean.
# -----------------------------------------------------------------------------
set -euo pipefail
trap 'echo "[ERR ] aborted at line $LINENO – see message above" >&2' ERR

LOG_ENABLED=0
usage() {
  cat >&2 <<EOF
Usage: $0 [--verbose] <lang>
  --verbose   enable debug logging
EOF
  exit 1
}

# ───────── parse flags ────────────────────────────────────────────────────────
if [[ "${1:-}" == "--verbose" ]]; then LOG_ENABLED=1; shift; fi
[[ $# -eq 1 ]] || usage
lang="$1"

# ───────── path constants / sanity checks ────────────────────────────────────
EX_ROOT="/var/tmp/testing-dir/$lang"          # exercises live directly here
PRUNE_SCRIPT="/var/tmp/pruning/detect_minimal_fs.sh"
OUTPUT_DIR="/var/tmp/path_sets"

log()   { (( LOG_ENABLED )) && echo "[LOG ] $*"; }
info()  { echo "[INFO] $*"; }
error() { echo "[FAIL] $*" >&2; exit 1; }

[[ -d "$EX_ROOT"      ]] || error "Language folder not found: $EX_ROOT"
[[ -x "$PRUNE_SCRIPT" ]] || error "Prune script not exec: $PRUNE_SCRIPT"
mkdir -p "$OUTPUT_DIR"

# ───────── gather exercise directories ───────────────────────────────────────
shopt -s nullglob
declare -a exercises=("$EX_ROOT"/*)
[[ ${#exercises[@]} -gt 0 ]] || error "No exercises found for $lang"

# ───────── main loop ─────────────────────────────────────────────────────────
for ex_dir in "${exercises[@]}"; do
  # resolve build script (allow with or without .sh extension)
  if [[ -x "$ex_dir/build_script" ]]; then
    build_script_rel="build_script"
  elif [[ -x "$ex_dir/build_script.sh" ]]; then
    build_script_rel="build_script.sh"
  else
    log "Skipping $(basename "$ex_dir") – build_script not found or not exec"; continue
  fi

  [[ -d "$ex_dir/assignment/src" ]] || { log "Skipping $(basename "$ex_dir") – missing assignment/src"; continue; }

  ex_name=$(basename "$ex_dir")
  info "=== Processing $ex_name ($lang) ==="

  # ---------- Option A: make a writable copy in /tmp ------------------------
  workdir=$(mktemp -d "/tmp/${lang}_${ex_name}_XXXX")
  cp -a "$ex_dir"/. "$workdir"/
  chmod -R u+w "$workdir"

  build_script="$workdir/$build_script_rel"
  assign_dir="$workdir/assignment"

  pushd "$workdir" >/dev/null
  PRUNE_ARGS=(
    --script "$build_script"
    --lang   "$lang"
    --assignment-dir "$assign_dir"
    --test-dir        "$workdir"      # Gradle/Maven discover tests
  )
  (( LOG_ENABLED )) && PRUNE_ARGS=( --verbose "${PRUNE_ARGS[@]}" )

  "$PRUNE_SCRIPT" "${PRUNE_ARGS[@]}" || error "detect_minimal_fs.sh failed for $ex_name"
  popd >/dev/null

  # verify & move outputs
  bindings_src="$workdir/final_bindings.txt"
  bwrap_src="$workdir/final_bwrap.sh"
  [[ -f "$bindings_src" ]] || error "final_bindings.txt missing for $ex_name"
  [[ -f "$bwrap_src"    ]] || error "final_bwrap.sh missing for $ex_name"

  mv "$bindings_src" "$OUTPUT_DIR/final_bindings_${lang}_${ex_name}.txt"
  mv "$bwrap_src"    "$OUTPUT_DIR/final_bwrap_${lang}_${ex_name}.sh"

  python3 /var/tmp/pruning/preprocess_bindings.py \
    "$OUTPUT_DIR/final_bindings_${lang}_${ex_name}.txt" \
    "$lang" "$ex_name" "$OUTPUT_DIR" \
    || error "preprocess_bindings failed for $ex_name"

  # clean temp directory
  rm -rf "$workdir"

done

info "All $lang exercises pruned – union.paths live in $OUTPUT_DIR"