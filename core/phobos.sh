#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail
HERE="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=phobos-common.sh
source "${HERE}/phobos-common.sh"

usage() {
  cat <<USAGE
Usage:
  phobos.sh [<exercise-conf> ...] <build_command> [args...]

Notes:
- Base cfg: any file matching "${HERE}/Base*.cfg" (applied first, sorted).
- Tail cfg: "${HERE}/TailPhobos.cfg" (applied last) if present.
- Exercise configs: if provided as leading file arguments OR, if none are provided,
  all files under "./exercise-config" (sorted) are applied after base and before tail.
- If no base cfg is found, Phobos runs the command directly (no sandbox).
USAGE
  exit 2
}

[[ $# -lt 1 ]] && usage

cfgs=()
cmd=()
found_cmd=0
for a in "$@"; do
  if [[ $found_cmd -eq 0 && -f "$a" ]]; then
    cfgs+=("$a")
  else
    found_cmd=1
    cmd+=("$a")
  fi
done
[[ ${#cmd[@]} -eq 0 ]] && usage

mapfile -t base_cfgs < <(ls -1 "${HERE}"/Base*.cfg 2>/dev/null | sort || true)

if [[ ${#base_cfgs[@]} -eq 0 ]]; then
  _log "No Base*.cfg found; running command without sandbox."
  exec "${cmd[@]}"
fi

if [[ ${#cfgs[@]} -eq 0 && -d "./exercise-config" ]]; then
  while IFS= read -r f; do cfgs+=("$f"); done < <(find ./exercise-config -maxdepth 1 -type f -name "*.cfg" | sort)
fi

INI_TMP_DIRS=""

# Set BASE_CFG to the last base (sorted); earlier bases could be global then language-specific
for c in "${base_cfgs[@]}"; do BASE_CFG="$c"; done
export BASE_CFG

for c in "${cfgs[@]}"; do
  if grep -q '^\[' "$c"; then
    parse_ini_policy "$c"
  else
    validate_config_file_keys "$c"
    # shellcheck source=/dev/null
    source "$c"
  fi
done

if [[ -f "${TAIL_FLAGS_FILE}" ]]; then export TAIL_FLAGS_FILE; else TAIL_FLAGS_FILE=""; fi

check_no_widening_against_base || true

SPEC_DIR="$(mktemp -d -t phobos-spec.XXXXXX)"
trap 'rm -rf "$SPEC_DIR" $INI_TMP_DIRS' EXIT
normalize_spec "$SPEC_DIR"

exec "${HERE}/phobos-timeout.sh" "$SPEC_DIR" -- "${cmd[@]}"
