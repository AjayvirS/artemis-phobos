#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

# ---------- Constants ----------
PHB_OK=0
PHB_EPOLICY=11
PHB_EMERGE=12
PHB_EBASE=13
PHB_ETIMEOUT=14
PHB_ERUNTIME=15

# ---------- Logging ----------
_log() { printf '%s\n' "[$(date -u +'%Y-%m-%dT%H:%M:%SZ')] $*" >&2; }
die() { _log "$1"; exit "${2:-1}"; }
report() { printf '%s\n' "$1"; }

# ---------- Defaults ----------
: "${CORE_DIR:=$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
: "${TAIL_FLAGS_FILE:=${CORE_DIR}/TailPhobos.cfg}"

# ---------- Helpers ----------
uniq_keep_order() { awk '!seen[$0]++'; }
depth_sort() { awk '{print gsub(/\//,"/")+1 " " $0}' | sort -k1,1n -k2,2 | cut -d" " -f2-; }
canon_paths() {
  if command -v realpath >/>/dev/null 2>&1; then
    while IFS= read -r p; do [[ -z "$p" ]] && continue; realpath --canonicalize-missing --no-symlinks "$p" || echo "$p"; done
  else
    cat
  fi
}

# ---------- Config key validation ----------
allowed_keys() {
  cat <<'EOF'
TIMEOUT_SECONDS
NET_ALLOWLIST_FILE
RO_PATHS_FILE
RW_PATHS_FILE
HIDE_PATHS_FILE
TAIL_FLAGS_FILE
BASE_CFG
CORE_DIR
EOF
}

validate_config_file_keys() {
  local file="$1"
  local keys
  keys=$(sed -E -n 's/^[[:space:]]*([A-Za-z_][A-Za-z0-9_]*)=.*/\1/p' "$file" | sed 's/[[:space:]]//g' | sort -u)
  local ok=$(allowed_keys | sort -u)
  local unknown=""
  while IFS= read -r k; do
    [[ -z "$k" ]] && continue
    if ! grep -qx "$k" <<< "$ok"; then unknown+="$k "; fi
  done <<< "$keys"
  if [[ -n "$unknown" ]]; then
    report "Policy invalid: unknown key(s): ${unknown}. (PHB-EPOLICY)"
    exit "${PHB_EPOLICY}"
  fi
}

# ---------- INI-style policy parsing ----------
parse_ini_policy() {
  local ini="$1"
  local tdir; tdir="$(mktemp -d -t phobos-ini.XXXXXX)"
  INI_TMP_DIRS+=" ${tdir}"
  local ro="${tdir}/ro.paths"; local rw="${tdir}/rw.paths"; local net="${tdir}/net.rules"
  : > "$ro"; : > "$rw"; : > "$net"
  local sec=""
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"; line="$(echo "$line" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    [[ -z "$line" ]] && continue
    if [[ "$line" =~ ^\[(.+)\]$ ]]; then sec="${BASH_REMATCH[1]}"; continue; fi
    case "$sec" in
      readonly) printf '%s\n' "$line" >> "$ro" ;;
      write)    printf '%s\n' "$line" >> "$rw" ;;
      network)
        if [[ "$line" =~ ^allow[[:space:]]+(.+)$ ]]; then
          target="${BASH_REMATCH[1]}"; host="$target"; port="*"
          if [[ "$target" == *:* ]]; then host="${target%:*}"; port="${target##*:}"; fi
          host="${host#[}"; host="${host%]}"; printf '%s %s\n' "$host" "$port" >> "$net"
        fi ;;
      limits)
        if [[ "$line" =~ ^timeout[[:space:]]*=[[:space:]]*([0-9]+)$ ]]; then
          local t="${BASH_REMATCH[1]}"; [[ "$t" -eq 0 ]] && TIMEOUT_SECONDS="" || TIMEOUT_SECONDS="$t"
        fi ;;
      *) ;;
    esac
  done < "$ini"
  RO_PATHS_FILE="$ro"; RW_PATHS_FILE="$rw"; NET_ALLOWLIST_FILE="$net"
}

# ---------- Spec normalization ----------
normalize_spec() {
  local spec_dir="$1"; mkdir -p "$spec_dir"
  : "${TIMEOUT_SECONDS:=}"; [[ -n "${TIMEOUT_SECONDS}" ]] && printf '%s\n' "${TIMEOUT_SECONDS}" > "${spec_dir}/timeout.sec" || : > "${spec_dir}/timeout.sec"
  if [[ -n "${NET_ALLOWLIST_FILE:-}" && -s "${NET_ALLOWLIST_FILE}" ]]; then
    sed -E 's/#.*$//' "${NET_ALLOWLIST_FILE}" | sed '/^[[:space:]]*$/d' > "${spec_dir}/net.rules"
  else
    : > "${spec_dir}/net.rules"
  fi
  for kind in ro rw hide; do
    fvar="$(echo "${kind}" | tr '[:lower:]' '[:upper:]')_PATHS_FILE"; src="${!fvar:-}"
    if [[ -n "${src}" && -s "${src}" ]]; then
      sed -E 's/#.*$//' "$src" | sed '/^[[:space:]]*$/d' | canon_paths | uniq_keep_order | depth_sort > "${spec_dir}/${kind}.paths"
    else
      : > "${spec_dir}/${kind}.paths"
    fi
  done
  tmpd="$(mktemp -d)"; cp "${spec_dir}/ro.paths" "${tmpd}/ro"; cp "${spec_dir}/rw.paths" "${tmpd}/rw"; cp "${spec_dir}/hide.paths" "${tmpd}/hide"
  if [[ -s "${tmpd}/hide" ]]; then
    grep -vxF -f "${tmpd}/hide" "${tmpd}/ro" > "${spec_dir}/ro.paths" || true
    grep -vxF -f "${tmpd}/hide" "${tmpd}/rw" > "${spec_dir}/rw.paths" || true
  fi
  if [[ -s "${spec_dir}/ro.paths" && -s "${spec_dir}/rw.paths" ]]; then
    grep -vxF -f "${spec_dir}/rw.paths" "${spec_dir}/ro.paths" > "${tmpd}/ro2" || true; mv "${tmpd}/ro2" "${spec_dir}/ro.paths"
  fi
  rm -rf "${tmpd}"
  if [[ -n "${TAIL_FLAGS_FILE:-}" && -s "${TAIL_FLAGS_FILE}" ]]; then
    sed -E 's/#.*$//' "${TAIL_FLAGS_FILE}" | sed '/^[[:space:]]*$/d' > "${spec_dir}/tail.flags"
  else
    : > "${spec_dir}/tail.flags"
  fi
}

# ---------- Guards ----------
check_no_widening_against_base() {
  local base="${BASE_CFG:-}"
  [[ -f "$base" ]] || return 0
  local bro="$(mktemp)"; local brw="$(mktemp)"
  awk '$1=="r"{sub(/^r[[:space:]]+/,""); print $0}' "$base" | sort -u > "$bro" || true
  awk '$1=="w"{sub(/^w[[:space:]]+/,""); print $0}' "$base" | sort -u > "$brw" || true
  if [[ -n "${RO_PATHS_FILE:-}" && -s "${RO_PATHS_FILE}" ]]; then
    while IFS= read -r p; do [[ -z "$p" ]] && continue
      if ! grep -qxF "$p" "$bro" && ! grep -qxF "$p" "$brw"; then
        report "Policy merge failed: path '$p' requested RO but base does not allow access. (PHB-EMERGE)"; exit "${PHB_EMERGE}"
      fi
    done < <(sed -E 's/#.*$//' "$RO_PATHS_FILE" | sed '/^[[:space:]]*$/d')
  fi
  if [[ -n "${RW_PATHS_FILE:-}" && -s "${RW_PATHS_FILE}" ]]; then
    while IFS= read -r p; do [[ -z "$p" ]] && continue
      if ! grep -qxF "$p" "$brw"; then
        report "Policy merge failed: path '$p' requested RW but base forbids write. (PHB-EMERGE)"; exit "${PHB_EMERGE}"
      fi
    done < <(sed -E 's/#.*$//' "$RW_PATHS_FILE" | sed '/^[[:space:]]*$/d')
  fi
  rm -f "$bro" "$brw"
}
