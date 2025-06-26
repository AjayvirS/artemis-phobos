#!/usr/bin/env python3
"""
preprocess_bindings.py  <final_bindings.txt> <lang> <exercise> <out_dir>

Creates
  • <out_dir>/<lang>_<exercise>.paths   (# mode path  – exercise-specific)
  • <out_dir>/TailStatic.cfg            (# raw flags after “Tail options:”)
        ^
        └──── orchestrator later copies this to
             /var/tmp/opt/core/local/TailStatic.cfg
"""

from __future__ import annotations
import pathlib, re, subprocess, sys
from typing import Dict

SRC, LANG, EX, OUTDIR = sys.argv[1:]
rx_detail = re.compile(r"^(\/[^ ]+)\s+->\s+([rwn])$")
MODE_RANK = {"r": "readonly", "w": "write"}

def canon(p: str) -> str:
    """Canonicalise path: resolve symlinks, keep non-existent."""
    return subprocess.run(
        ["realpath", "--canonicalize-missing", "--no-symlinks", p],
        text=True, capture_output=True, check=True
    ).stdout.strip()

base_modes: Dict[str, str] = {}   # path -> 'r' | 'w'
dyn_lines: list[str]       = []
tail_flags: list[str]      = []

with open(SRC, encoding="utf-8") as fh:
    for raw in fh:
        line = raw.strip()
        if not line:
            continue

        if line.startswith("[LOG] "):
            line = line[len("[LOG] "):]

        # -------- mount-detail lines --------
        m = rx_detail.match(line)
        if m:
            path, mode = m.groups()
            path = canon(path)
            if path not in base_modes:
                dyn_lines.append(f"{mode} {path}")
            continue

        # -------- “Base options:” block -----
        if line.startswith("Base options:"):
            tokens = line.split()[2:]
            it = iter(tokens)
            for flag in it:
                if flag == "--ro-bind":
                    path = canon(next(it)); next(it)
                    base_modes[path] = "r"
                elif flag == "--bind":
                    path = canon(next(it)); next(it)
                    base_modes[path] = "w"
                elif flag in ("--proc", "--dev"):
                    canon(next(it))          # consume path, ignore
                # anything else is ignored
            continue

        # -------- “Tail options:” block -----
        if line.startswith("Tail options:"):
            tail_flags.extend(line.split()[2:])

# ─────────────────────────  WRITE ARTEFACTS  ──────────────────────────
outdir = pathlib.Path(OUTDIR)
outdir.mkdir(parents=True, exist_ok=True)

# 1) per-exercise .paths  (used by orchestrator for union/intersection)
paths_file = outdir / f"{LANG}_{EX}.paths"
paths_file.write_text("\n".join(sorted(set(dyn_lines))) + "\n")
print("wrote", paths_file)

# 2) TailStatic.cfg  (only if any tail flags were captured)
if tail_flags:
    tail_cfg = outdir / "TailStatic.cfg"
    tail_cfg.write_text(" ".join(tail_flags) + "\n")
    print("wrote", tail_cfg)
