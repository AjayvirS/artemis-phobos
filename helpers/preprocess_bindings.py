#!/usr/bin/env python3
"""
preprocess_bindings.py  <final_bindings.txt> <lang> <exercise> <out_dir>

Creates
  • <out_dir>/base_static.cfg          (# static [readonly] / [write])
  • <out_dir>/tail_static.cfg          (# raw flags after “Tail options:”)
  • <out_dir>/<lang>_<exercise>.paths  (# mode path  – exercise-specific)
"""

from __future__ import annotations
import pathlib, re, subprocess, sys
from typing import Dict

SRC, LANG, EX, OUTDIR = sys.argv[1:]

rx_detail  = re.compile(r"^(\/[^ ]+)\s+->\s+([rwn])$")
MODE_RANK  = {"r": "readonly", "w": "write"}

def canon(p: str) -> str:
    """Canonicalise path: resolve symlinks, keep non-existent."""
    return subprocess.run(
        ["realpath", "--canonicalize-missing", "--no-symlinks", p],
        text=True, capture_output=True, check=True
    ).stdout.strip()

base_modes: Dict[str, str] = {}   # path -> 'r' | 'w'
dyn_lines: list[str]        = []
tail_flags: list[str]       = []

with open(SRC, encoding="utf-8") as fh:
    for raw in fh:
        line = raw.strip()
        if not line:
            continue

        m = rx_detail.match(line)
        if m:
            path, mode = m.groups()
            path = canon(path)

            if path not in base_modes:
                dyn_lines.append(f"{mode} {path}")
            continue

        if line.startswith("Base options:"):
            tokens = line.split()[2:]
            it = iter(tokens)
            for flag in it:
                match flag:
                    case "--ro-bind":
                        path = canon(next(it)); next(it)
                        base_modes[path] = "r"
                    case "--bind":
                        path = canon(next(it)); next(it)
                        base_modes[path] = "w"
                    case "--proc" | "--dev":
                        canon(next(it))
                    case _:
                        pass
            continue

        if line.startswith("Tail options:"):
            tail_flags.extend(line.split()[2:])
            continue

# ─────────────────────────  WRITE  ──────────────────────────
outdir = pathlib.Path(OUTDIR)
outdir.mkdir(parents=True, exist_ok=True)

# 3a) per-exercise .paths
paths_file = outdir / f"{LANG}_{EX}.paths"
paths_file.write_text("\n".join(sorted(set(dyn_lines))) + "\n")
print("wrote", paths_file)

# 3b) base_static.cfg
base_cfg = outdir / "base_static.cfg"
with base_cfg.open("w") as out:
    for sect in ("readonly", "write"):
        lines = sorted({p for p, m in base_modes.items() if MODE_RANK[m] == sect})
        if not lines:
            continue
        out.write(f"[{sect}]\n")
        out.write("\n".join(lines) + "\n\n")
print("wrote", base_cfg)

# 3c) tail_static.cfg (single line)
if tail_flags:
    tail_cfg = outdir / "tail_static.cfg"
    tail_cfg.write_text(" ".join(tail_flags) + "\n")
    print("wrote", tail_cfg)
