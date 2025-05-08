#!/usr/bin/env python3
"""
merge_all_paths.py

Aggregates per-language union and intersection .paths files into cross-language
union_all.paths, intersection_all.paths, and generates base_phobos.cfg.

Usage:
  merge_all_paths.py --dir /opt/path_sets
Produces:
  union_all.paths
  intersection_all.paths
  base_phobos.cfg
in the same directory.
"""
import argparse
import pathlib
from collections import defaultdict

def parse_paths_file(pathfile):
    """Return dict of path -> mode for a .paths file"""
    mapping = {}
    for line in pathfile.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        try:
            mode, path = line.split(maxsplit=1)
        except ValueError:
            continue
        mapping[path] = mode
    return mapping

MODE_RANK = {'n': 0, 'r': 1, 'w': 2}

if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--dir', required=True, help='Directory containing per-language .paths files')
    args = p.parse_args()

    base = pathlib.Path(args.dir)
    union_files = list(base.glob('*_union.paths'))
    intersection_files = list(base.glob('*_intersection.paths'))

    if not union_files:
        print('No union files found in', base)
        exit(1)
    if not intersection_files:
        print('No intersection files found in', base)
        exit(1)

    strongest = {}
    for uf in union_files:
        m = parse_paths_file(uf)
        for path, mode in m.items():
            if path not in strongest or MODE_RANK[mode] > MODE_RANK[strongest[path]]:
                strongest[path] = mode

    union_all = base / 'union_all.paths'
    with union_all.open('w') as f:
        for path, mode in sorted(strongest.items()):
            f.write(f"{mode} {path}\n")
    print('Wrote', union_all)

    inter_counts = defaultdict(int)
    for inf in intersection_files:
        m = parse_paths_file(inf)
        for path in m:
            inter_counts[path] += 1
    total_langs = len(intersection_files)
    intersection_all = {path: 'r' for path, cnt in inter_counts.items() if cnt == total_langs}

    intersection_all_file = base / 'intersection_all.paths'
    with intersection_all_file.open('w') as f:
        for path in sorted(intersection_all):
            f.write(f"r {path}\n")
    print('Wrote', intersection_all_file)

    cfg = base / 'base_phobos.cfg'
    with cfg.open('w') as f:
        for path, mode in sorted(strongest.items()):
            if mode == 'w':
                f.write(f"--bind {path} {path}\n")
            elif mode == 'r':
                f.write(f"--ro-bind {path} {path}\n")
            # skip 'n'
    print('Wrote', cfg)
# TODO: add a flag to prefix a --tmpfs / / at the beginning or not