#!/bin/bash
# minimal_fs_prune.sh
#
# A language-agnostic script that prunes filesystem access by iteratively
# testing a user-provided bash script (“build/test command”) inside bubblewrap.
# The parent directory (TARGET) is mounted read-only; subdirectories are tested in
# the order hide (n) → read-only (r) → writable (w). Any environment variables
# for the build tool can be passed in as arguments or set externally.

# **Stable output contract:** On success (or best-effort completion), this
# script writes a *human-readable audit log* named `final_bindings.txt` in the
# current working directory. Each line has the form:
#     /abs/path -> n|r|w
# followed by summary lines:
#     Total Command Attempts: N
#     Base options: <bubblewrap flags...>
#     Tail options: <bubblewrap flags...>
# Downstream tooling (run_minimal_fs_all.sh) consumes this log to produce
# machine-readable artifacts (.paths, JSON, TailPhobos.cfg). Do not change the
# log format without updating those tools.

###############################################################################
# 1) ARGUMENT AND ENV VAR HANDLING
###############################################################################

TARGET="/"
BUILD_SCRIPT="/bin/true"
BUILD_ENV_VARS=""
TEST_DIR=""
ASSIGN_DIR=""
LOG_ENABLED=0
LANG=

# incase build framework shows "build failure" due to failing tests and not binding error, script should continue pruning
# Default patterns treated as *harmless test failures* rather than infra errors


IGNORABLE_FAILURE_PATTERNS=${IGNORABLE_FAILURE_PATTERNS:-"There were failing tests|> Task :(compileJava|compileTestJava) NO-SOURCE"}
UNIGNORABLE_SUCCESS_PATTERNS=${UNIGNORABLE_SUCCESS_PATTERNS:-"> Task :(compileJava|compileTestJava) NO-SOURCE"}

##############################################################################
# Canonical path classes
##############################################################################
# Kernel pseudo—always mounted by --proc / --dev
readonly PSEUDO_FS=( /proc /dev /sys /run /tmp )

# Volatile caches we rarely need for reproducible builds
readonly LARGE_VOLATILE=( /var/tmp /var/cache )

# Always-needed read-only system directories
readonly CRITICAL_TOP=( /bin /sbin /usr /lib /lib64 /lib32 /libx32 /etc )

# Helper: test if $1 is (or is below) any element in subsequent array
is_in_list() {
    local p=$1; shift
    for x; do [[ $p == $x* ]] && return 0; done
    return 1
}



# Parse command-line arguments
# Example usage:
while [[ $# -gt 0 ]]; do
  case "$1" in
    --script)
      BUILD_SCRIPT="$2"
      shift 2
      ;;
    --target)
      TARGET="$2"
      shift 2
      ;;
    --env)
      # Takes environment variables
      BUILD_ENV_VARS="$BUILD_ENV_VARS env $2"
      shift 2
      ;;
    --assignment-dir)
      ASSIGN_DIR=$2
      shift 2
      ;;
    --test-dir)
      TEST_DIR=$2
      shift 2
      ;;
    --verbose)
      LOG_ENABLED=1
      shift
      ;;
    --lang)
      LANG="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# If needed, we can read environment variables from outside (for caching).
# e.g. PERSISTENT_GRADLE_HOME, PERSISTENT_M2_REPO, etc.
# If not set externally, define defaults:
PERSISTENT_BUILD_HOME="${PERSISTENT_BUILD_HOME:-}"
BUILD_OPTS="${BUILD_OPTS:-}"

###############################################################################
# 2) GLOBAL SETUP
###############################################################################
IFS=',' read -r -a EXTRA_RO <<<"${BWRAP_EXTRA_RO:-}"
IFS=',' read -r -a EXTRA_RW <<<"${BWRAP_EXTRA_RW:-}"

# If BWRAP_EXTRA_RO or BWRAP_EXTRA_RW are set, mark them as read-only because cache is supposed to be read at least.
declare -A PROTECTED_R
for p in "${EXTRA_RO[@]}" "${EXTRA_RW[@]}"; do
  a=$p
  while [[ $a != "/" ]]; do
    PROTECTED_R["$a"]=1
    a=$(dirname "$a")
  done
done



BWRAP_COMMAND_COUNT=0

BASE_OPTIONS=(
    --proc /proc
    --dev  /dev
    --tmpfs /tmp
    --bind /tmp /tmp
)

# add read-only bind for every critical dir that exists
for dir in "${CRITICAL_TOP[@]}" "${LARGE_VOLATILE[@]}"; do
    [[ -d $dir ]] && BASE_OPTIONS+=( --ro-bind "$dir" "$dir" )
done


# user supplied extra binds, e.g. for caching build frameworks across prune runs
for p in "${EXTRA_RO[@]}"; do
    [[ -e $p ]] || error "BWRAP_EXTRA_RO path does not exist: $p"
done

for p in "${EXTRA_RW[@]}"; do
    [[ -e $p ]] || error "BWRAP_EXTRA_RW path does not exist: $p"
done


work_dir=$(dirname "$BUILD_SCRIPT")
TAIL_OPTIONS=(
    --share-net
    --chdir "$work_dir"
)

log() {
    if [[ "$LOG_ENABLED" -eq 1 ]]; then
        echo "[LOG] $*"
    fi
}


# The associative array CONFIG will store our subdirectory => state (n/r/w).
declare -A CONFIG

# We assume that if PERSISTENT_BUILD_HOME is non-empty, the user wants
# to pass that environment variable into bubblewrap, e.g. for Gradle or Maven caches.
# Similarly for BUILD_OPTS.
###############################################################################
# 3) INITIAL CONFIG: everything "r" by default, skipping critical system dirs
###############################################################################
init_config() {
  shopt -s dotglob
  for item in "$TARGET"*; do
    [[ -d $item ]] || continue
    is_in_list "$item" "${PSEUDO_FS[@]}" "${LARGE_VOLATILE[@]}" "${CRITICAL_TOP[@]}" && continue
    CONFIG["$item"]="r"
  done
  shopt -u dotglob
}


###############################################################################
# 4) BUILD THE BWRAP COMMAND
###############################################################################
build_bwrap_command() {
  local options=("${BASE_OPTIONS[@]}")

  # If TARGET isn't the root, bind it read-only first
  if [ "$TARGET" != "/" ]; then
    options+=(--ro-bind "$TARGET" "$TARGET")
  fi

  # Collect depth:weight:path entries
  local list=() path depth weight mode
  for path in "${!CONFIG[@]}"; do
    mode=${CONFIG[$path]}
    depth=$(grep -o "/" <<<"$path" | wc -l)
    case "$mode" in
      n) weight=0 ;;
      r) weight=1 ;;
      w) weight=2 ;;
    esac
    list+=("$depth:$weight:$path")
  done

  # Sort by depth then weight and extract paths
  local sorted_paths
  readarray -t sorted_paths < <(
    printf '%s\n' "${list[@]}" |
      sort -t: -k1,1n -k2,2n |
      cut -d: -f3-
  )

  # Apply bindings in sorted order
  for path in "${sorted_paths[@]}"; do
    case "${CONFIG[$path]}" in
      n) options+=(--tmpfs "$path") ;;  # hide
      w) options+=(--bind "$path" "$path") ;;  # write
      r) options+=(--ro-bind "$path" "$path") ;;  # read-only
    esac
  done

  # Add any extra read-write binds provided by the user (e.g. for caching)
  for p in "${EXTRA_RO[@]}"; do
      [[ -e $p ]] || error "BWRAP_EXTRA_RO path does not exist: $p"
      BASE_OPTIONS+=( --ro-bind "$p" "$p" )
  done

  for p in "${EXTRA_RW[@]}"; do
      [[ -e $p ]] || error "BWRAP_EXTRA_RW path does not exist: $p"
      BASE_OPTIONS+=( --bind    "$p" "$p" )
  done

  # Append tail options
  options+=("${TAIL_OPTIONS[@]}")

  # Build environment variables
  local env_part=""
  [ -n "$PERSISTENT_BUILD_HOME" ] && env_part+=" env BUILD_HOME=$PERSISTENT_BUILD_HOME"
  [ -n "$BUILD_OPTS" ]           && env_part+=" BUILD_OPTS='$BUILD_OPTS'"
  [ -n "$BUILD_ENV_VARS" ]       && env_part+=" $BUILD_ENV_VARS"

  # Construct and print the final command
  local cmd="bwrap $(printf '%s ' "${options[@]}")${env_part} /bin/bash -c '$BUILD_SCRIPT'"
  echo "$cmd"
}



#############################
# test_build_script
#############################
# Runs the current bwrap command, counts attempts, and decides whether
# the result should be treated as an infrastructure failure (return non-0)
# or merely a user-test failure (return 0 so pruning continues).
#
# Configure ignorable patterns via:
#   export IGNORABLE_FAILURE_PATTERNS='There were failing tests|==.*short test summary'
# Add more ‘harmless’ patterns per language as needed.
#############################
test_build_script() {
    local cmd
    cmd=$(build_bwrap_command)
    ((BWRAP_COMMAND_COUNT++))
    log "Testing command number: $BWRAP_COMMAND_COUNT"


    # run command, capture combined output for inspection
    tmpfile="/tmp/build-${BWRAP_COMMAND_COUNT}.log"

    echo "=== Run #${BWRAP_COMMAND_COUNT} Command ===" >"$tmpfile"

    echo "$cmd" >>"$tmpfile"
    echo ""  >>"$tmpfile"

    set +e
    eval "$cmd" >"$tmpfile" 2>&1
    exit_code=$?
    set -e

    # 1) If it failed but matches an IGNORABLE_FAILURE_PATTERNS, treat as success
    if (( exit_code != 0 )) \
       && [[ -n $IGNORABLE_FAILURE_PATTERNS ]] \
       && grep -Eq "$IGNORABLE_FAILURE_PATTERNS" "$tmpfile"; then
      exit_code=0
    fi

    # 2) If it succeeded but matches an UNIGNORABLE_SUCCESS_PATTERNS, treat as failure
    if (( exit_code == 0 )) \
       && [[ -n $UNIGNORABLE_SUCCESS_PATTERNS ]] \
       && grep -Eq "$UNIGNORABLE_SUCCESS_PATTERNS" "$tmpfile"; then
      exit_code=1
    fi


    if [[ $exit_code -eq 0 ]]; then
        status="success"
    else
        status="fail"
    fi
    logfile="/tmp/build-${BWRAP_COMMAND_COUNT}-${status}.log"
    mv "$tmpfile" "$logfile"
    log "Logs for run #${BWRAP_COMMAND_COUNT}: $logfile"

    return $exit_code
}

###############################################################################
# 6) PRUNE TREE LOGIC (hide -> read-only -> writable)
###############################################################################
prune_tree() {
  local parent="$1"
  log "Pruning subdirectories of $parent"
  for child in "${parent%/}"/*; do
    [ -d "$child" ] || continue
    # skip system directories
    is_in_list "$child" "${PSEUDO_FS[@]}" && continue

    # skip cached read directory
    [[ -n "${PROTECTED_R[$child]:-}" ]] && continue

    log "Testing candidate: $child"

    # Try n => hidden
    CONFIG["$child"]="n"
    if test_build_script; then
      log "$child => not required (n)"
    else
      # Try r => read-only
      CONFIG["$child"]="r"
      if test_build_script; then
        log "$child => read-only (r)"
      else
        # Try w => writable
        CONFIG["$child"]="w"
        if test_build_script; then
          log "$child => must be writable (w)"
        else
          log "$child => fails even with w, keep as w"
          CONFIG["$child"]="w"
        fi
      fi
    fi

    # Recurse if not hidden
    if [ "${CONFIG[$child]}" != "n" ]; then
      prune_tree "$child"
    fi
  done
}

# reduce amount of bindings for argument optimisation
# after pruning, before serializing CONFIG:
collapse_readonly_parents() {
  # look at every directory that’s all r, drop its children
  for parent in "${!CONFIG[@]}"; do
    [[ "${CONFIG[$parent]}" = r ]] || continue
    # see if _every_ existing child is also r
    all_r=true
    for child in "$parent"/*; do
      [[ -d "$child" ]] && [[ "${CONFIG[$child]:-r}" = r ]] || { all_r=false; break; }
    done
    if $all_r; then
      # we can remove all child entries
      for child in "$parent"/*; do
        unset CONFIG["$child"]
      done
    fi
  done
}





###############################################################################
# 7) SAVE CONFIG
###############################################################################
save_configuration() {
  local outfile="final_bindings.txt"
  echo "Saving final binding configuration to $outfile" > "$outfile"
  log "Saving final binding configuration to $outfile"
  for key in "${!CONFIG[@]}"; do
    echo "$key -> ${CONFIG[$key]}" >> "$outfile"
  done
  echo "Total Command Attempts: $BWRAP_COMMAND_COUNT" >> "$outfile"
  echo "Base options: ${BASE_OPTIONS[*]}" >> "$outfile"
  echo "Tail options: ${TAIL_OPTIONS[*]}" >> "$outfile"

  log "Total Command Attempts: $BWRAP_COMMAND_COUNT"
  log "Base options: ${BASE_OPTIONS[*]}"
  log "Tail options: ${TAIL_OPTIONS[*]}"
}


demote_writable_parents() {
  for child in "${!CONFIG[@]}"; do
    [[ ${CONFIG[$child]} == "w" ]] && continue
    parent=$(dirname "$child")
    while [[ $parent != "/" ]]; do
      if [[ ${CONFIG[$parent]:-} == "w" ]]; then
          CONFIG["$parent"]="r"
      fi
      parent=$(dirname "$parent")
    done
  done
}



###############################################################################
# 9) MAIN EXECUTION
###############################################################################

log "Initializing configuration for target: $TARGET"
init_config
for key in "${!CONFIG[@]}"; do
  CONFIG["$key"]="w"
done


log "Testing with full writable configuration..."
if ! test_build_script; then
  log "Build script failed even with full writable configuration. Aborting."
  exit 1
fi




log "Running pruning for exercises of $LANG..."
prune_tree "$TARGET"
demote_writable_parents

log "Final mount configuration:"
for key in "${!CONFIG[@]}"; do
  log "$key -> ${CONFIG[$key]}"
done

collapse_readonly_parents
if [[ -n "$ASSIGN_DIR" ]]; then
  log "Forcing read-only bind on assignment dir: $ASSIGN_DIR"
  CONFIG["$ASSIGN_DIR"]=r
fi

if [[ -n "$TEST_DIR" ]]; then
  log "Forcing read-only bind on test dir: $TEST_DIR"
  CONFIG["$TEST_DIR"]=r
fi

for p in "${EXTRA_RO[@]}"; do CONFIG["$p"]="r"; done
for p in "${EXTRA_RW[@]}"; do CONFIG["$p"]="w"; done
save_configuration
