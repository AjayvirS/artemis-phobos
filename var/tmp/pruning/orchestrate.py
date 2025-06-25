#!/usr/bin/env python3
"""
orchestrate.py – prune, merge & build binding config files used by Bubblewrap
sandboxes.

Outputs (all in /var/tmp/opt/core/local)
-----------------------------------------
* **BasePhobos.cfg**            – **UNION** of bindings from *all* languages →
  used when the runtime cannot tell which language is running.
* **BaseLanguage-<lang>.cfg**   – *full* binding set for that language
  (duplicates with BasePhobos allowed).
* **BasePhobosIntersect.cfg**   – **INTERSECTION** (common bindings across all
  languages).
* **Base<lang>Intersect.cfg**   – intersection of *that* language with
  BasePhobos (same as language’s full set but written separately for clarity).
* **TailStatic.cfg**            – copied verbatim when present.

Overlaps are now fine; extra intersection files are just for auditing.
"""

from __future__ import annotations
import argparse, os, shlex, subprocess, sys, textwrap, time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Dict, Iterable, List, Set, Tuple

# ────────────────────────────────────────── CLI
ap = argparse.ArgumentParser(
    formatter_class=argparse.RawTextHelpFormatter,
    description=textwrap.dedent(__doc__))

ap.add_argument('--langs',      required=True,
                help='comma‑separated: java,python,c')
ap.add_argument('--tests-dir',  default='/var/tmp/testing-dir',
                help='Root that contains <lang>/ sub‑dirs with exercises')
ap.add_argument('--path-dir',   default='/var/tmp/path_sets',
                help='Where <lang>_*.paths files are read/written')
ap.add_argument('--jobs',       type=int, default=os.cpu_count() or 4)
ap.add_argument('--skip-prune', action='store_true')
ap.add_argument('--verbose',    action='store_true')
args = ap.parse_args()

langs: List[str] = [l.strip() for l in args.langs.split(',') if l.strip()]
PATH_DIR = Path(args.path_dir);            PATH_DIR.mkdir(parents=True, exist_ok=True)
CORE_DIR = Path('/var/tmp/opt/core/local'); CORE_DIR.mkdir(parents=True, exist_ok=True)

PRUNE_SCRIPT = Path('/var/tmp/pruning/run_minimal_fs_all.sh')

# ────────────────────────────────────────── helpers

def run(cmd: str | List[str], tag: str = '') -> None:
    """Run *cmd* streaming output; raise if exit‑status != 0."""
    pretty = cmd if isinstance(cmd, str) else ' '.join(shlex.quote(c) for c in cmd)
    print(f'\033[34m[{tag or "cmd"}]\033[0m', pretty)
    t0 = time.time()
    rc = subprocess.call(cmd, shell=isinstance(cmd, str))
    dt = time.time() - t0
    if rc:
        raise RuntimeError(f'{tag} failed (rc={rc}, {dt:.1f}s)')
    print(f'\033[32m✓ {tag} ({dt:.1f}s)\033[0m')

# ────────────────────────────────────────── step 1 – prune

def prune_language(lang: str) -> None:
    if args.skip_prune:
        print(f'[skip] prune:{lang}')
        return
    if not PRUNE_SCRIPT.exists():
        raise FileNotFoundError(f'pruning script not found: {PRUNE_SCRIPT}')
    cmd: List[str] = [str(PRUNE_SCRIPT)]
    if args.verbose:
        cmd.append('--verbose')
    cmd.append(lang)
    run(cmd, f'prune:{lang}')

# ────────────────────────────────────────── utilities

def _read_union(path: Path) -> Tuple[Set[str], Set[str]]:
    """Return (readonly_set, write_set) from a *_union.paths file."""
    readonly, write = set(), set()
    for line in path.read_text().splitlines():
        mode, p = line.split(maxsplit=1)
        if mode == 'w':
            write.add(p); readonly.discard(p)
        else:
            if p not in write:
                readonly.add(p)
    return readonly, write

# ────────────────────────────────────────── step 2 – gather data

def collect_language_data(langs: Iterable[str]) -> Dict[str, Dict[str, Set[str]]]:
    data: Dict[str, Dict[str, Set[str]]] = {}
    for lang in langs:
        union_file = PATH_DIR / f'{lang}_union.paths'
        if not union_file.exists():
            print(f'\033[33m[warn]\033[0m missing {union_file.name}')
            continue
        r_set, w_set = _read_union(union_file)
        data[lang] = {'r': r_set, 'w': w_set}
    return data

# ────────────────────────────────────────── writers

def write_cfg(read_set: Set[str], write_set: Set[str], dest: Path) -> None:
    lines: List[str] = []
    if read_set:
        lines += ['[readonly]', *sorted(read_set), '']
    if write_set:
        lines += ['[write]',    *sorted(write_set),    '']
    dest.write_text('\n'.join(lines))

# ────────────────────────────────────────── main pipeline
print('\n\033[1mOrchestrating for:\033[0m', ', '.join(langs), '\n')

# 1) prune in parallel
with ThreadPoolExecutor(max_workers=args.jobs) as pool:
    fut2lang = {pool.submit(prune_language, l): l for l in langs}
    for fut in as_completed(fut2lang):
        lang = fut2lang[fut]
        try:
            fut.result()
        except Exception as exc:
            print(f'\033[31m{lang} prune failed:\033[0m', exc)

# 2) gather *.paths data
lang_data = collect_language_data(langs)
if not lang_data:
    print('\033[31m[error]\033[0m no union.paths present – abort')
    sys.exit(1)

# 3) BasePhobos (UNION)
read_union, write_union = set(), set()
for info in lang_data.values():
    write_union |= info['w']
for info in lang_data.values():
    read_union |= (info['r'] - write_union)
write_cfg(read_union, write_union, CORE_DIR / 'BasePhobos.cfg')

# 4) BasePhobosIntersect (intersection across languages)
all_sets = [(info['r'] | info['w']) for info in lang_data.values()]
inter_all = set.intersection(*all_sets)
read_inter_all, write_inter_all = set(), set()
for p in inter_all:
    if any(p in info['w'] for info in lang_data.values()):
        write_inter_all.add(p)
    else:
        read_inter_all.add(p)
write_cfg(read_inter_all, write_inter_all, CORE_DIR / 'BasePhobosIntersect.cfg')

# 5) per‑language files (full & intersection)
for lang, info in lang_data.items():
    # full union for that language
    write_cfg(info['r'], info['w'], CORE_DIR / f'BaseLanguage-{lang}.cfg')

    # intersection with BasePhobos (redundant but requested)
    # here, it is simply the same as language’s own set, but kept for auditing
    lang_inter_read  = info['r'] & (read_union | write_union)  # == info['r']
    lang_inter_write = info['w'] & (read_union | write_union)  # == info['w']
    write_cfg(lang_inter_read, lang_inter_write,
              CORE_DIR / f'Base{lang.capitalize()}Intersect.cfg')

# 6) TailStatic passthrough
src_tail = PATH_DIR / 'TailStatic.cfg'
dst_tail = CORE_DIR / 'TailStatic.cfg'
if src_tail.exists():
    dst_tail.write_text(src_tail.read_text())
    print('  • copied TailStatic.cfg')
else:
    print('\033[33m[warn]\033[0m TailStatic.cfg missing in', PATH_DIR)

print('\n\033[1mDone.\033[0m')
