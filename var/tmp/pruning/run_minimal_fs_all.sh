#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# run_minimal_fs_all.sh – prune every *exercise repository* for a single language
# -----------------------------------------------------------------------------
# Directory tree
#   /var/tmp/testing-dir/<lang>/<exercise>/
#       ├─ build_script[.sh]      (executable)
#       └─ assignment/        (student code; tests embedded or discovered)
#
# Each exercise is copied to /tmp, pruned, and the temporary folder is removed.
# Post-process each prune result into machine-readable artifacts (.paths/.json).
#
#   --cache-dir <path>   Bind <path> read‑write inside Bubblewrap so *any* build
#                        system can reuse download caches across pruning runs.
#                        The script does **NOT** set language‑specific env vars
#                        such as GRADLE_USER_HOME; callers should add the
#                        appropriate `--env NAME=...` flags in PRUNE_ARGS if
#                        they want a tool to look at the bound directory.
# -----------------------------------------------------------------------------
set -euo pipefail
trap 'echo "[ERR ] aborted at line $LINENO – see message above" >&2' ERR



###############################################################################
# 0) CONFIGURABLE PATHS
###############################################################################
# Location of helper that converts detect_minimal_fs.sh log -> .paths/.json/TailPhobos.
# Override with env HELPER_DIR=/custom/path (helper filename fixed below).
HELPER_DIR="${HELPER_DIR:-/var/tmp/helpers}"
EMIT_HELPER="$HELPER_DIR/emit_artifacts.py"
# Delete raw final_bindings logs after successful parse? 1=keep, 0=delete (default).
PHOBOS_KEEP_LOG="${PHOBOS_KEEP_LOG:-0}"


###############################################################################
# 1) CLI & LOGGING
###############################################################################
LOG_ENABLED=0
CACHE_DIR=""
lang=""

usage() {
  cat >&2 <<EOF
Usage: $0 [--verbose] [--cache-dir PATH] <lang>
  --verbose        enable debug logging
  --cache-dir PATH bind PATH read-write inside Bubblewrap (tool-agnostic cache)
EOF
  exit 1
}

# ─── parse flags in any order ────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      LOG_ENABLED=1
      shift
      ;;
    --cache-dir)
      [[ $# -ge 2 ]] || { echo "Missing path after --cache-dir" >&2; usage; }
      CACHE_DIR=$2
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    --*)
      echo "Unknown flag: $1" >&2
      usage
      ;;
    *)
      if [[ -z $lang ]]; then    # first non-flag is the language
        lang=$1
      else                       # any extra positional is an error
        echo "Unexpected argument: $1" >&2
        usage
      fi
      shift
      ;;
  esac
done

[[ -n $lang ]] || usage


log()   { (( LOG_ENABLED )) && echo "[LOG ] $*"; return 0; }
info()  { echo "[INFO] $*"; }
error() { echo "[FAIL] $*" >&2; exit 1; }

###############################################################################
# 2) PATH CONSTANTS / SANITY CHECKS
###############################################################################
EX_ROOT="/var/tmp/testing-dir/$lang"
PRUNE_SCRIPT="/var/tmp/pruning/detect_minimal_fs.sh"
OUTPUT_DIR="/var/tmp/path_sets"

[[ -d "$EX_ROOT"      ]] || error "Language folder not found: $EX_ROOT"
[[ -x "$PRUNE_SCRIPT" ]] || error "Prune script not exec: $PRUNE_SCRIPT"
mkdir -p "$OUTPUT_DIR"
mkdir -p "$HELPER_DIR" 2>/dev/null || true

###############################################################################
# 3) OPTIONAL CACHE BIND
###############################################################################
if [[ -n "$CACHE_DIR" ]]; then
  mkdir -p "$CACHE_DIR"
  export BWRAP_EXTRA_RW="$CACHE_DIR"   # detect_minimal_fs.sh picks this up
  log "Cache directory bound RW: $CACHE_DIR"
fi

###############################################################################
# 4) GATHER EXERCISES
###############################################################################
shopt -s nullglob
exercises=("$EX_ROOT"/*)
[[ ${#exercises[@]} -gt 0 ]] || error "No exercises found for $lang"

###############################################################################
# 5) MAIN LOOP
###############################################################################
for ex_dir in "${exercises[@]}"; do
  if [[ -x "$ex_dir/build_script" ]]; then
    build_script_rel="build_script"
  elif [[ -x "$ex_dir/build_script.sh" ]]; then
    build_script_rel="build_script.sh"
  else
    log "Skipping $(basename "$ex_dir") – build_script not found or not exec"; continue
  fi

  [[ -d "$ex_dir/assignment" ]] || { log "Skipping $(basename "$ex_dir") – missing assignment"; continue; }

  ex_name=$(basename "$ex_dir")
  info "=== Processing $ex_name ($lang) ==="

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
    --test-dir        "$workdir"
  )
  (( LOG_ENABLED )) && PRUNE_ARGS=( --verbose "${PRUNE_ARGS[@]}" )

  "$PRUNE_SCRIPT" "${PRUNE_ARGS[@]}" || error "detect_minimal_fs.sh failed for $ex_name"
  popd >/dev/null

  bindings_src="$workdir/final_bindings.txt"
  [[ -f "$bindings_src" ]] || error "final_bindings.txt missing for $ex_name"

  # Emit structured artifacts (.paths, .json, TailPhobos.cfg) from the detect log.
  # We reuse the parsing logic formerly in preprocess_bindings.py. :contentReference[oaicite:16]{index=16}
  if [[ -x "$EMIT_HELPER" ]]; then
    log "Emitting artifacts for $ex_name -> $OUTPUT_DIR"
    if python3 "$EMIT_HELPER" \
         --lang "$lang" \
         --exercise "$ex_name" \
         --config-file "$bindings_src" \
         --out-dir "$OUTPUT_DIR"; then
      # Optionally archive or delete raw log to avoid bloat.
      if (( PHOBOS_KEEP_LOG )); then
        mv "$bindings_src" "$OUTPUT_DIR/final_bindings_${lang}_${ex_name}.txt"
      else
        rm -f "$bindings_src"
      fi
    else
      echo "[WARN] emit_artifacts.py failed; copying raw log untouched." >&2
      mv "$bindings_src" "$OUTPUT_DIR/final_bindings_${lang}_${ex_name}.txt"
    fi
  else
    # Helper missing; fall back to old behaviour (copy raw log).
    log "emit_artifacts helper not found ($EMIT_HELPER); copying raw log."
    mv "$bindings_src" "$OUTPUT_DIR/final_bindings_${lang}_${ex_name}.txt"
  fi
  rm -rf "$workdir"
done

info "All $lang exercises pruned – artifacts in $OUTPUT_DIR"
