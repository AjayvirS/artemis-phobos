#!/usr/bin/env bash
set -euo pipefail

err(){ echo -e "\e[31m[error]\e[0m $*" >&2; exit 1; }
usage(){
cat <<EOF
usage: $0 -b base.cfg --lang lang [-e extra.cfg] [--tail tail_static.cfg] -- buildScript.sh [args]
EOF
exit 1; }

base_cfg=; extra_cfgs=(); tail_cfg=
workdir="$PWD"; code_lang="java"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -b|--base) base_cfg="${workdir}/$2"; shift 2;;
    -e|--extra) extra_cfgs+=("${workdir}/$2"); shift 2;;
    -t|--tail) tail_cfg="${workdir}/$2"; shift 2;;
    -o|--output) workdir="$2"; shift 2;;
    -l|--lang) code_lang="$2"; shift 2;;
    --) shift; break;;
    *) usage;;
  esac
done
[[ -z ${base_cfg:-} ]] && usage
[[ $# -eq 0 ]] && err "missing build script"

repo_root="/opt/test-repository/${code_lang}"
cd "$repo_root" || err "cannot cd to $repo_root"
[[ $workdir == $PWD ]] && workdir="$repo_root"
build_script="$repo_root/build_script.sh"; shift


readonly_paths=() write_paths=() network_rules=(); timeout_s=0; mem_mb=0
bwrap_args=()

load_cfg(){
  set +e
  local file=$1 section=
  [[ -f $file ]] || err "cfg not found: $file"
  while IFS= read -r ln || [[ -n $ln ]]; do
    ln=${ln%%#*}; [[ -z $ln ]] && continue
    if [[ $ln =~ ^\[(.*)\]$ ]]; then section=${BASH_REMATCH[1]}; continue; fi
    case $section in
      readonly) readonly_paths+=("$ln");;
      write)    write_paths+=("$ln");;
      network)  network_rules+=("$ln");;
      limits)
        [[ $ln =~ timeout=([0-9]+) ]] && timeout_s=${BASH_REMATCH[1]}
        [[ $ln =~ mem_mb=([0-9]+)  ]] && mem_mb=${BASH_REMATCH[1]} ;;
    esac
  done < "$file"
  set -e
}

load_cfg "$base_cfg";status=$?
echo "[debug] load_cfg base returned $status"
for c in "${extra_cfgs[@]}"; do load_cfg "$c"; done
for p in "${readonly_paths[@]}"; do bwrap_args+=( --ro-bind "$p" "$p" ); done
for p in "${write_paths[@]}";    do bwrap_args+=( --bind    "$p" "$p" ); done


allowed_file=$(mktemp "${workdir}/allowedList.XXXX.cfg")
: > "$allowed_file"
bwrap_args+=( --ro-bind "$allowed_file" "$allowed_file" )
export NETBLOCKER_CONF="$allowed_file"


[[ -n ${tail_cfg:-} && -f $tail_cfg ]] && while read -r f || [[ -n $ln ]]; do bwrap_args+=("$f"); done < "$tail_cfg"


for rule in "${network_rules[@]}"; do
  [[ $rule =~ ^allow[[:space:]]+(.+)$ ]] || continue
  hostport=${BASH_REMATCH[1]}
  host=${hostport%%:*}; port=${hostport##*:}
  [[ $host == "$port" ]] && port=0
  echo "$host $port" >> "$allowed_file"
done

rlimit_arg=(); [[ $mem_mb -gt 0 ]] && rlimit_arg=( --rlimit-as=$((mem_mb*1024*1024)) )
timeout_cmd=(); timeout_cmd=( timeout --kill-after=5s "${timeout_s}s" )
[[ -x $build_script ]] || err "build script not found or not executable: $build_script"

cmd=( "${timeout_cmd[@]}" bwrap "${bwrap_args[@]}" -- "$build_script" "$@" )
printf '\e[34m[bwrap]\e[0m '
printf '%q ' "${cmd[@]}"
echo
exec "${cmd[@]}"