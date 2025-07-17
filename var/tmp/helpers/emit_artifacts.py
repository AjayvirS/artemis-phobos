#!/usr/bin/env python3
"""
emit_artifacts.py
-----------------

Parse a `final_bindings.txt` log produced by `detect_minimal_fs.sh` and emit:

  • <out_dir>/<lang>_<exercise>.paths
      - 'r /path' / 'w /path' lines
      - 'n' (hidden) entries are not written.

  • <out_dir>/<lang>_<exercise>.json
      Structured record with:
         paths_dynamic : list[ {mode,path} ]       # may include 'n'
         paths_base    : list[ {mode,path} ]       # static Base binds
         paths_all     : list[ {mode,path} ]       # merged r/w (w overrides r)
         tail_flags    : list[str]                 # from 'Tail options:' line
         provenance    : log SHA256, timestamp, schema_version

  • <out_dir>/TailPhobos.cfg
      Merges/uniquifies all tail flags across every exercise processed.

This helper replaces the old preprocess_bindings.py stage, eliminating the need
to scrape logs later in the pipeline.
"""

from __future__ import annotations
import argparse, hashlib, json, pathlib, re, subprocess, sys, time
from typing import Dict, List, Tuple

# -----------------------------------------------------------------------------
# Regex and helpers
# -----------------------------------------------------------------------------
RX_DETAIL = re.compile(r"^(\/[^ ]+)\s+->\s+([rwn])$")  # /path -> r|w|n


def canon(p: str) -> str:
    """Canonicalize path (resolve symlinks, keep non-existent)"""
    try:
        out = subprocess.check_output(
            ["realpath", "--canonicalize-missing", "--no-symlinks", p],
            text=True,
        ).strip()
        return out or p
    except Exception:
        return str(pathlib.Path(p).resolve(strict=False))


# -----------------------------------------------------------------------------
# Parse detect_minimal_fs log
# -----------------------------------------------------------------------------
def parse_log(path: pathlib.Path) -> Tuple[List[Tuple[str, str]],
Dict[str, str],
List[str]]:
    """
    Returns:
        dyn_pairs  – [('r'|'w'|'n', /path), ...] from per-path lines
        base_modes – {path: 'r'|'w'} from 'Base options:' line
        tail_flags – ['--flag', 'value', ...] from 'Tail options:' line
    """
    dyn_pairs: List[Tuple[str, str]] = []
    base_modes: Dict[str, str] = {}
    tail_flags: List[str] = []

    with path.open(encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("[LOG] "):          # strip detect’s log prefix
                line = line[6:]

            # per-path detail block
            m = RX_DETAIL.match(line)
            if m:
                p, mode = m.groups()
                dyn_pairs.append((mode, canon(p)))
                continue

            # Base static binds
            if line.startswith("Base options:"):
                tokens = line.split()[2:]
                it = iter(tokens)
                for flag in it:
                    try:
                        if flag == "--ro-bind":
                            p = canon(next(it)); next(it)
                            base_modes[p] = "r"
                        elif flag == "--bind":
                            p = canon(next(it)); next(it)
                            base_modes[p] = "w"
                        elif flag in ("--proc", "--dev", "--tmpfs"):
                            _ = next(it)
                    except StopIteration:
                        break
                continue

            # Tail flags
            if line.startswith("Tail options:"):
                tail_flags.extend(line.split()[2:])
                continue

    return dyn_pairs, base_modes, tail_flags


# -----------------------------------------------------------------------------
# Merge dynamic + base (w overrides r)
# -----------------------------------------------------------------------------
def merge_pairs(dyn: List[Tuple[str, str]],
                base: Dict[str, str]) -> List[Tuple[str, str]]:
    merged: Dict[str, str] = dict(base)          # start with static
    for mode, path in dyn:
        if mode == "n":
            continue
        prev = merged.get(path)
        if prev is None or (prev == "r" and mode == "w"):
            merged[path] = mode
    # sort paths for determinism
    return sorted(((m, p) for p, m in merged.items()), key=lambda t: t[1])


# -----------------------------------------------------------------------------
# Writers
# -----------------------------------------------------------------------------
def write_paths(lang: str, ex: str,
                pairs: List[Tuple[str, str]],
                out_dir: pathlib.Path) -> pathlib.Path:
    out_dir.mkdir(parents=True, exist_ok=True)
    dest = out_dir / f"{lang}_{ex}.paths"
    dest.write_text("\n".join(f"{m} {p}" for m, p in pairs) + "\n")
    return dest


def write_json(lang: str, ex: str,
               dyn_pairs: List[Tuple[str, str]],
               base_modes: Dict[str, str],
               merged_pairs: List[Tuple[str, str]],
               tail: List[str],
               log_path: pathlib.Path,
               out_dir: pathlib.Path) -> pathlib.Path:
    data = {
        "schema_version": 1,
        "timestamp_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "lang": lang,
        "exercise": ex,
        "paths_dynamic": [{"mode": m, "path": p} for m, p in dyn_pairs],
        "paths_base": [{"mode": m, "path": p} for p, m in sorted(base_modes.items())],
        "paths_all": [{"mode": m, "path": p} for m, p in merged_pairs],
        "tail_flags": tail,
        "log_sha256": hashlib.sha256(log_path.read_bytes()).hexdigest(),
        "log_filename": str(log_path),
    }
    out_dir.mkdir(parents=True, exist_ok=True)
    dest = out_dir / f"{lang}_{ex}.json"
    dest.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n")
    return dest


def merge_tail(flags: List[str], out_dir: pathlib.Path) -> pathlib.Path | None:
    if not flags:
        return None
    dest = out_dir / "TailPhobos.cfg"
    existing = dest.read_text().split() if dest.exists() else []
    merged = []
    seen = set()
    for tok in existing + flags:
        if tok not in seen:
            seen.add(tok); merged.append(tok)
    dest.write_text(" ".join(merged) + "\n")
    return dest


# -----------------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", required=True)
    ap.add_argument("--exercise", required=True)
    ap.add_argument("--config-file", required=True,
                    help="final_bindings.txt from detect_minimal_fs.sh")
    ap.add_argument("--out-dir", required=True)
    args = ap.parse_args()

    log_path = pathlib.Path(args.config_file)
    out_dir  = pathlib.Path(args.out_dir)

    if not log_path.is_file():
        print(f"emit_artifacts: no log file {log_path}", file=sys.stderr)
        return 2

    dyn_pairs, base_modes, tail_flags = parse_log(log_path)
    merged_pairs = merge_pairs(dyn_pairs, base_modes)

    p_file = write_paths(args.lang, args.exercise, merged_pairs, out_dir)
    j_file = write_json(args.lang, args.exercise,
                        dyn_pairs, base_modes, merged_pairs,
                        tail_flags, log_path, out_dir)
    t_file = merge_tail(tail_flags, out_dir)

    msg = f"emit_artifacts: wrote {p_file.name}, {j_file.name}"
    if t_file:
        msg += f", updated {t_file.name}"
    print(msg)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
