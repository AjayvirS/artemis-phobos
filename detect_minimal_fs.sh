#!/bin/bash
# minimal_fs_prune.sh
#
# A language-agnostic script that prunes filesystem access by iteratively
# testing a user-provided bash script (“build/test command”) inside bubblewrap.
# The parent directory (TARGET) is mounted read-only; subdirectories are tested in
# the order hide (n) → read-only (r) → writable (w). Any environment variables
# for the build tool can be passed in as arguments or set externally.

###############################################################################
# 1) ARGUMENT AND ENV VAR HANDLING
###############################################################################

TARGET="/"
BUILD_SCRIPT="/bin/true"
BUILD_ENV_VARS=""

# incase build framework shows "build failure" due to failing tests and not binding error, script should continue pruning
# Default patterns treated as *harmless test failures* rather than infra errors


IGNORABLE_FAILURE_PATTERNS=${IGNORABLE_FAILURE_PATTERNS:-"There were failing tests"}

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

local work_dir
work_dir=$(dirname "$BUILD_SCRIPT")
TAIL_OPTIONS=(
    --share-net
    --chdir "$work_dir"
)

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
      is_in_list "$item" "${PSEUDO_FS[@]}" "${LARGE_VOLATILE[@]}" && continue

    # skip . and .., etc.
    if [ -d "$item" ] && [[ "$(basename "$item")" != "." && "$(basename "$item")" != ".." ]]; then
      CONFIG["$item"]="r"
    fi
  done
  shopt -u dotglob
}

###############################################################################
# 4) BUILD THE BWRAP COMMAND
###############################################################################
build_bwrap_command() {
  local options=("${BASE_OPTIONS[@]}")

  # If target != "/", read-only bind it as the parent
  if [ "$TARGET" != "/" ]; then
    options+=( --ro-bind "$TARGET" "$TARGET" )
  fi


  # Then override subdirectories that are hidden (n) or writable (w)
  # sort paths by depth: parents first, children last
  sorted_paths=($(for p in "${!CONFIG[@]}"; do
                    echo "$p"
                  done | awk -F/ '{print NF " " $0}' | sort -n | cut -d" " -f2-))

  for path in "${sorted_paths[@]}"; do
    case "${CONFIG[$path]}" in
      n) options+=( --tmpfs "$path" )  ;;  # must come *after* any parent bind
      w) options+=( --bind  "$path" "$path" ) ;;
      r) ;;                                # parent’s ro-bind is already in BASE_OPTIONS
    esac
  done



  options+=( "${TAIL_OPTIONS[@]}" )

  # Build env part dynamically
  # e.g. if PERSISTENT_BUILD_HOME="/tmp/cache/gradle_home", etc.
  local env_part=""
  if [ -n "$PERSISTENT_BUILD_HOME" ]; then
    env_part+=" env BUILD_HOME=$PERSISTENT_BUILD_HOME"
  fi
  if [ -n "$BUILD_OPTS" ]; then
    env_part+=" BUILD_OPTS='$BUILD_OPTS'"
  fi
  # also add any user-specified environment variables from arguments:
  if [ -n "$BUILD_ENV_VARS" ]; then
    env_part+=" $BUILD_ENV_VARS"
  fi

  # Finally, we run /bin/bash -c "$BUILD_SCRIPT"
  local cmd="bwrap $(printf '%s ' "${options[@]}") $env_part /bin/bash -c '$BUILD_SCRIPT'"
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
    echo "Testing with command:"
    echo "$cmd"
    ((BWRAP_COMMAND_COUNT++))

    # run command, capture combined output for inspection
     set +e
     eval "$cmd" > /tmp/build.log 2>&1
     local exit_code=$?
     set -e

    # default patterns: Gradle and Maven test-failure line
    local patterns=${IGNORABLE_FAILURE_PATTERNS:-"There were failing tests"}

    # If build failed, but ONLY due to test failures, treat as success
    if [[ $exit_code -ne 0 ]]; then
        if grep -Eq "$patterns" /tmp/build.log ; then
            echo "Detected harmless test failures – ignoring exit $exit_code for pruning."
            exit_code=0
        fi
    fi
    return $exit_code
}

###############################################################################
# 6) PRUNE TREE LOGIC (hide -> read-only -> writable)
###############################################################################
prune_tree() {
  local parent="$1"
  echo "Pruning subdirectories of $parent"
  for child in "${parent%/}"/*; do
    [ -d "$child" ] || continue
    # skip system directories
    is_in_list "$child" "${PSEUDO_FS[@]}" && continue

    echo "Testing candidate: $child"

    # Try n => hidden
    CONFIG["$child"]="n"
    if test_build_script; then
      echo "$child => not required (n)"
    else
      # Try r => read-only
      CONFIG["$child"]="r"
      if test_build_script; then
        echo "$child => read-only (r)"
      else
        # Try w => writable
        CONFIG["$child"]="w"
        if test_build_script; then
          echo "$child => must be writable (w)"
        else
          echo "$child => fails even with w, keep as w"
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

###############################################################################
# 7) SAVE CONFIG
###############################################################################
save_configuration() {
  local outfile="final_bindings.txt"
  echo "Saving final binding configuration to $outfile"
  > "$outfile"
  for key in "${!CONFIG[@]}"; do
    echo "$key -> ${CONFIG[$key]}" >> "$outfile"
  done
  echo "Total Command Attempts: $BWRAP_COMMAND_COUNT" >> "$outfile"
  echo "Base options: ${BASE_OPTIONS[*]}" >> "$outfile"
  echo "Tail options: ${TAIL_OPTIONS[*]}" >> "$outfile"
}

###############################################################################
# 8) CREATE A FINAL BWRAP SCRIPT
###############################################################################
create_final_script() {
  local outfile="final_bwrap.sh"
  echo "#!/bin/bash" > "$outfile"
  echo "# Replays the final bwrap command with pruned settings." >> "$outfile"

  # We can just store the one-liner. Or to be safe, we replicate build_bwrap_command
  local final_cmd
  final_cmd=$(build_bwrap_command)

  echo "$final_cmd" >> "$outfile"
  chmod +x "$outfile"
  echo "Final bwrap script saved to $outfile"
}

###############################################################################
# 9) MAIN EXECUTION
###############################################################################

demote_writable_parents() {
  # If a parent directory is still writable but every child ended up r or n
  # then the parent can safely fall back to read-only.
  for child in "${!CONFIG[@]}"; do
    [[ ${CONFIG[$child]} == "w" ]] && continue          # child needs write
    parent=$(dirname "$child")
    while [[ "$parent" != "/" ]]; do
      if [[ ${CONFIG[$parent]:-} == "w" ]]; then        # parent still write
        CONFIG["$parent"]="r"
      fi
      parent=$(dirname "$parent")
    done
  done
}

echo "Initializing configuration for target: $TARGET"
init_config
for key in "${!CONFIG[@]}"; do
  CONFIG["$key"]="w"
done


echo "Testing with full writable configuration..."
if ! test_build_script; then
  echo "Build script failed even with full writable configuration. Aborting."
  exit 1
fi

echo "Starting tree based pruning..."
prune_tree "$TARGET"

echo "Revisiting parent directories that remained writable..."
demote_writable_parents

echo "Final mount configuration:"
for key in "${!CONFIG[@]}"; do
  echo "$key -> ${CONFIG[$key]}"
done

save_configuration
create_final_script
