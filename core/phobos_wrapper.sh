#!/usr/bin/env bash
set -euo pipefail

err()   { echo -e "\e[31m[error]\e[0m $*" >&2; exit 1; }
usage() { cat <<EOF
usage: $0 [--lang <lang>] [--base cfg] [--extra cfg] [--tail cfg] -- buildScript [args]
EOF
exit 1; }

# ---------------------------------------------------------------------
#  Defaults + CLI
# ---------------------------------------------------------------------
PWD_ORIG=$PWD
code_lang=""
core=/var/tmp/opt/core

base_cfg="$core/BasePhobos.cfg"      # new default
extra_cfgs=()                        # none by default
tail_cfg="$core/TailPhobos.cfg"

while [[ $# -gt 0 ]]; do
  case $1 in
    -b|--base)   base_cfg="$PWD_ORIG/$2"; shift 2;;
    -e|--extra)  extra_cfgs+=("$PWD_ORIG/$2"); shift 2;;
    -t|--tail)   tail_cfg="$PWD_ORIG/$2"; shift 2;;
    -l|--lang)   code_lang="$2"; shift 2;;
    --)          shift; break;;
    *) usage;;
  esac
done

# ---------------------------------------------------------------------
#  Auto-select BaseLanguage-<lang>.cfg if available
# ---------------------------------------------------------------------
if [[ -n $code_lang ]]; then
    lang_cfg="$core/BaseLanguage-$code_lang.cfg"
    [[ -f $lang_cfg ]] && base_cfg=$lang_cfg
fi

# ---------------------------------------------------------------------
#  Build-script path
# ---------------------------------------------------------------------
if [[ $# -gt 0 ]]; then
    build_script="$1"; shift
    [[ -f $build_script ]] || err "build script not found: $build_script"
else
    build_script="/var/tmp/script.sh"
    [[ -f $build_script ]] || err "default build script missing: $build_script"
fi

# ---------------------------------------------------------------------
#  Config parsing
# ---------------------------------------------------------------------
readonly_paths=(); write_paths=(); tmpfs_paths=()
network_rules=(); timeout_s=0; mem_mb=0; restricted_cmds=()

load_cfg() {
  local file=$1 section=
  [[ -f $file ]] || err "cfg not found: $file"
  while IFS= read -r ln || [[ -n $ln ]]; do
      ln=${ln%%#*}; [[ -z $ln ]] && continue
      if [[ $ln =~ ^\[(.*)\]$ ]]; then section=${BASH_REMATCH[1]}; continue; fi
      case $section in
        readonly)             readonly_paths+=("$ln") ;;
        write)                write_paths+=("$ln") ;;
        tmpfs)                tmpfs_paths+=("$ln") ;;
        network)              network_rules+=("$ln") ;;
        limits)
          [[ $ln =~ timeout=([0-9]+) ]] && timeout_s=${BASH_REMATCH[1]}
          [[ $ln =~ mem_mb=([0-9]+)  ]] && mem_mb=${BASH_REMATCH[1]} ;;
        restricted-commands)  restricted_cmds+=("$ln") ;;
      esac
  done < "$file"
}

load_cfg "$base_cfg"
for c in "${extra_cfgs[@]}"; do load_cfg "$c"; done

# ---------------------------------------------------------------------
#  Resolve restricted command paths (once)
# ---------------------------------------------------------------------
for cmd in "${restricted_cmds[@]}"; do
    [[ -z $cmd ]] && continue
    cmd_path=$(command -v "$cmd" 2>/dev/null || true)
    if [[ -n $cmd_path ]]; then
        cmd_path=$(readlink -f "$cmd_path")
        readonly_paths+=( "/dev/null" )  # ensure source exists
        write_paths+=( )                 # no-op, just to keep arrays declared
        # mask binds appended later
        restricted_paths+=( "$cmd_path" )
    else
        echo "[warn] restricted command ‘$cmd’ not found in PATH" >&2
    fi
done

# ---------------------------------------------------------------------
#  Bubblewrap argument assembly
# ---------------------------------------------------------------------
bwrap_args=( --proc /proc --dev /dev )

for p in "${readonly_paths[@]}"; do bwrap_args+=( --ro-bind "$p" "$p" ); done
for p in "${write_paths[@]}";    do bwrap_args+=( --bind    "$p" "$p" ); done
for p in "${tmpfs_paths[@]}";    do bwrap_args+=( --tmpfs   "$p"     ); done

# append restricted-command masks (shadow earlier binds)
for p in "${restricted_paths[@]-}"; do
    bwrap_args+=( --ro-bind /dev/null "$p" )
done

# tail flags (share-net, runtime chdir etc.)
if [[ -f $tail_cfg ]]; then
    while read -r line || [[ -n $line ]]; do
        read -ra parts <<<"$line"
        bwrap_args+=("${parts[@]}")
    done < "$tail_cfg"
fi

# ---------------------------------------------------------------------
#  Network + limits
# ---------------------------------------------------------------------
allowed_file="$core/allowedList.cfg"; : > "$allowed_file"

parse_hostport() {                       # $1 = host[:port] (IPv6 ok)
    local host port hostport=$1
    if [[ $hostport == \[*\]:* ]]; then  # [v6]:port
        host=${hostport%%]*}; host=${host#[}
        port=${hostport##*:}
    else
        host=${hostport%%:*}
        port=${hostport##*:}
    fi
    [[ $host == "$port" ]] && port=0
    echo "$host $port"
}

for rule in "${network_rules[@]}"; do
    [[ $rule =~ ^allow[[:space:]]+(.+)$ ]] || continue
    parse_hostport "${BASH_REMATCH[1]}" >> "$allowed_file"
done

export NETBLOCKER_CONF="$allowed_file"
export LD_PRELOAD="$core/libnetblocker.so"

rlimit_arg=(); [[ $mem_mb -gt 0 ]] && rlimit_arg=( --rlimit-as=$((mem_mb*1024*1024)) )
timeout_cmd=( timeout --kill-after=5s "${timeout_s}s" )

cmd=( "${timeout_cmd[@]}" bwrap "${bwrap_args[@]}" -- "$build_script" "$@" )
printf '\e[34m[bwrap]\e[0m '; printf '%q ' "${cmd[@]}"; echo
ulimit -v $((mem_mb*1024*5))
exec "${cmd[@]}"
