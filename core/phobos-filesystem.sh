#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail
HERE="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=phobos-common.sh
source "${HERE}/phobos-common.sh"

[[ $# -ge 3 && "$2" == "--" ]] || { echo "Usage: phobos-filesystem.sh <SPEC_DIR> -- <cmd...>"; exit 2; }
SPEC_DIR="$1"; shift 2
CMD=("$@")

RO="${SPEC_DIR}/ro.paths"; RW="${SPEC_DIR}/rw.paths"; HIDE="${SPEC_DIR}/hide.paths"; TAIL="${SPEC_DIR}/tail.flags"
BWRAP="${BWRAP_BIN:-bwrap}"; TIMEOUT_BIN="${TIMEOUT_BIN:-timeout}"

# If no constraints at all, run raw
if [[ ! -s "$RO" && ! -s "$RW" && ! -s "$HIDE" && ! -s "${SPEC_DIR}/net.rules" && -z "${PHB_TIMEOUT_SEC:-}" ]]; then
  exec "${CMD[@]}"
fi

args=(--dev-bind / /)
if [[ -s "${HIDE}" ]]; then while IFS= read -r p; do [[ -z "$p" ]] && continue; args+=(--tmpfs "$p"); done < "${HIDE}"; fi
if [[ -s "${RO}" ]]; then while IFS= read -r p; do [[ -z "$p" ]] && continue; args+=(--ro-bind "$p" "$p"); done < "${RO}"; fi
if [[ -s "${RW}" ]]; then while IFS= read -r p; do [[ -z "$p" ]] && continue; args+=(--bind "$p" "$p"); done < "${RW}"; fi
if [[ -s "${TAIL}" ]]; then args+=($(<"${TAIL}")); fi

OUTLOG="$(mktemp -t phobos-out.XXXXXX)"; ERRLOG="$(mktemp -t phobos-err.XXXXXX)"
trap 'rm -f "$OUTLOG" "$ERRLOG"' EXIT

set +e
(
  if [[ -n "${PHB_TIMEOUT_SEC:-}" ]]; then
    "${TIMEOUT_BIN}" "--kill-after=5s" "${PHB_TIMEOUT_SEC}" "${BWRAP}" "${args[@]}" -- "${CMD[@]}"
  else
    "${BWRAP}" "${args[@]}" -- "${CMD[@]}"
  fi
) > >(tee "$OUTLOG") 2> >(tee "$ERRLOG" >&2)
rc=$?
set -e

if [[ -n "${PHB_TIMEOUT_SEC:-}" && ( "$rc" -eq 124 || "$rc" -eq 137 ) ]]; then
  report "Timed out after ${PHB_TIMEOUT_SEC}s. (PHB-ETIMEOUT)"
  exit ${PHB_ETIMEOUT}
fi

net_denials=0; fs_denials=0
if [[ -s "$ERRLOG" ]]; then
  net_denials=$(grep -E -c 'EAI_AGAIN|EAI_FAIL|EAI_NONAME|Network is unreachable|Connection timed out' "$ERRLOG" || true)
  fs_denials=$(grep -E -c 'Permission denied|EACCES|EROFS' "$ERRLOG" || true)
fi
if (( net_denials > 0 || fs_denials > 0 )); then
  report "Sandbox denials: network=${net_denials}, filesystem=${fs_denials}. (PHB-EDENY)"
fi

exit "$rc"
