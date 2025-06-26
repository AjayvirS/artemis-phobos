#!/usr/bin/env python3
"""
make_all_lang_sets.py

Create
  • union_all.paths
  • intersection_all.paths
  • base_phobos.cfg  (INI format: [readonly] / [write] / [network] / [limits])

Assumes the directory contains one or more  *_union.paths  and  *_intersection.paths
files produced by the language-specific detectors.

Usage:
    make_all_lang_sets.py --input-dir /opt/path_sets --output-dir /opt/core
"""

from __future__ import annotations
import argparse
import pathlib
from collections import defaultdict
from typing import Dict, Iterable

MODE_RANK: dict[str, int] = {"n": 0, "r": 1, "w": 2}


def parse_paths_file(p: pathlib.Path) -> Dict[str, str]:
    """Return {path: mode} from a .paths file."""
    mapping: Dict[str, str] = {}
    for raw in p.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        try:
            mode, path = line.split(maxsplit=1)
        except ValueError:
            continue
        mapping[path] = mode
    return mapping


def strongest_modes(files: Iterable[pathlib.Path]) -> Dict[str, str]:
    """For each path keep the strongest mode (w > r > n)."""
    combined: Dict[str, str] = {}
    for f in files:
        for path, mode in parse_paths_file(f).items():
            if path not in combined or MODE_RANK[mode] > MODE_RANK[combined[path]]:
                combined[path] = mode
    return combined


def intersection_modes(files: Iterable[pathlib.Path]) -> Dict[str, str]:
    """Paths present in every file.  Mark them 'r'."""
    counts: defaultdict[str, int] = defaultdict(int)
    for f in files:
        for path in parse_paths_file(f):
            counts[path] += 1
    total = len(files)
    return {p: "r" for p, c in counts.items() if c == total}


def write_paths_file(mapping: Dict[str, str], outfile: pathlib.Path) -> None:
    with outfile.open("w") as out:
        for path, mode in sorted(mapping.items()):
            out.write(f"{mode} {path}\n")
    print("Wrote", outfile)


# ───────────────────────── main ─────────────────────────────
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input-dir", required=True, type=pathlib.Path,
                    help="Directory with *_union.paths / *_intersection.paths")
    ap.add_argument("--output-dir", default=pathlib.Path("/var/tmp/opt/core/local"),
                    type=pathlib.Path,
                    help="Destination directory for BasePhobos.cfg "
                         "(defaults to /var/tmp/opt/core/local)")
args = ap.parse_args()
base_dir: pathlib.Path = args.input_dir
core_dir: pathlib.Path = args.output_dir

union_files = list(base_dir.glob("*_union.paths"))
inter_files = list(base_dir.glob("*_intersection.paths"))
if not union_files:
    raise SystemExit(f"No *_union.paths files in {base_dir}")
if not inter_files:
    raise SystemExit(f"No *_intersection.paths files in {base_dir}")

union_map = strongest_modes(union_files)
write_paths_file(union_map, base_dir / "union_all.paths")

inter_map = intersection_modes(inter_files)
write_paths_file(inter_map, base_dir / "intersection_all.paths")

readonly = [p for p, m in union_map.items() if m == "r"]
writable = [p for p, m in union_map.items() if m == "w"]

cfg_path = core_dir / "BasePhobos.cfg"
with cfg_path.open("w") as cfg:
    if readonly:
        cfg.write("[readonly]\n")
        cfg.write("\n".join(sorted(readonly)) + "\n\n")
    if writable:
        cfg.write("[write]\n")
        cfg.write("\n".join(sorted(writable)) + "\n\n")

    # default-open network section
    cfg.write("[network]\nallow *\n\n")

    # default limits
    cfg.write("[limits]\ntimeout=0\n")

print("Wrote", cfg_path)

if __name__ == "__main__":
    main()
