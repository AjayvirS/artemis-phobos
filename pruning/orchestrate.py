#!/usr/bin/env python3
"""
orchestrate.py  – one command to prune, merge & build all languages.

Example
    ./orchestrate.py --langs java,python              \
                     --ex-root   /opt/student-exercises \
                     --repo-root /opt/test-repository   \
                     --path-dir  /opt/path_sets         \
                     --jobs 4
"""

from __future__ import annotations
import argparse, os, shlex, subprocess, sys, textwrap, time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Iterable, List

# ───────────────────────────────────────────────────── CLI
ap = argparse.ArgumentParser(
    formatter_class=argparse.RawTextHelpFormatter,
    description=textwrap.dedent(__doc__))

ap.add_argument('--langs',      required=True,
                help='comma-separated: java,python,c')
ap.add_argument('--ex-root',    default='/opt/student-exercises')
ap.add_argument('--repo-root',  default='/opt/test-repository')
ap.add_argument('--path-dir',   default='/opt/path_sets')
ap.add_argument('--jobs',       type=int, default=os.cpu_count() or 4)
ap.add_argument('--skip-prune', action='store_true')
ap.add_argument('--no-smoke',   action='store_true')
ap.add_argument('--verbose',    action='store_true')
args = ap.parse_args()

langs      : List[str] = [l.strip() for l in args.langs.split(',') if l.strip()]
EX_ROOT     = Path(args.ex_root)
REPO_ROOT   = Path(args.repo_root)
PATH_DIR    = Path(args.path_dir);  PATH_DIR.mkdir(parents=True, exist_ok=True)
CORE_DIR    = Path('/opt/core');    CORE_DIR.mkdir(parents=True, exist_ok=True)

# ────────────────────────────────────────── helpers
def run(cmd: str | list[str], tag: str = '') -> None:
    """Stream subprocess output, raise on non-zero exit."""
    pretty = cmd if isinstance(cmd, str) else ' '.join(shlex.quote(c) for c in cmd)
    print(f'\033[34m[{tag or "cmd"}]\033[0m', pretty)
    t0 = time.time()
    rc = subprocess.call(cmd, shell=isinstance(cmd, str))
    dt = time.time() - t0
    if rc:
        raise RuntimeError(f'{tag} failed (rc={rc}, {dt:.1f}s)')
    print(f'\033[32m✓ {tag} ({dt:.1f}s)\033[0m')


# ────────────────────────────────────────── step 1 – prune ⟶ *.paths
def prune_language(lang: str) -> Path:
    """Return directory that now contains <lang>_*.paths; may be empty."""
    if args.skip_prune:
        print(f'[skip] prune:{lang}')
        return PATH_DIR

    cmd = ['/opt/pruning/run_minimal_fs_all.sh']
    if args.verbose: cmd.append('--verbose')
    cmd.append(lang)
    run(cmd, f'prune:{lang}')
    return PATH_DIR


# ────────────────────────────────────────── step 2 – merge per language
def make_lang_cfgs(lang: str) -> tuple[Path, Path]:
    """
    Create   <lang>_union.paths / <lang>_intersection.paths  →  BaseLanguage-*.cfg
    Return (union_path, cfg_path).  If lang has no paths, returns (None, None).
    """
    union_file = PATH_DIR / f'{lang}_union.paths'
    if not union_file.exists():
        print(f'\033[33m[warn]\033[0m no *.paths for {lang}')
        return None, None

    # ---------- deduplicate & write BaseLanguage-<lang>.cfg
    readonly: set[str] = set()
    write   : set[str] = set()

    for line in union_file.read_text().splitlines():
        mode, path = line.split(maxsplit=1)
        (write if mode == 'w' else readonly).add(path)

    cfg_lines: list[str] = []
    if readonly:
        cfg_lines += ['[readonly]', *sorted(readonly), '']
    if write:
        cfg_lines += ['[write]',    *sorted(write),    '']

    cfg_path = CORE_DIR / f'BaseLanguage-{lang}.cfg'
    cfg_path.write_text('\n'.join(cfg_lines))
    print('  • wrote', cfg_path.name)
    return union_file, cfg_path


# ────────────────────────────────────────── step 3 – merge all languages
def make_base_phobos(all_union_files: Iterable[Path]) -> Path:
    """Union of every lang’s union.paths  → BasePhobos.cfg (deduped)."""
    readonly, write = set(), set()

    for uf in all_union_files:
        for line in uf.read_text().splitlines():
            mode, path = line.split(maxsplit=1)
            if mode == 'w':
                write.add(path);  readonly.discard(path)     # write beats read
            elif mode == 'r' and path not in write:
                readonly.add(path)

    lines = []
    if readonly:
        lines += ['[readonly]', *sorted(readonly), '']
    if write:
        lines += ['[write]',    *sorted(write),    '']

    out = CORE_DIR / 'BasePhobos.cfg'
    out.write_text('\n'.join(lines))
    print('  • wrote', out.name)
    return out


# ────────────────────────────────────────── main pipeline
print('\n\033[1mOrchestrating for:\033[0m', ', '.join(langs), '\n')

lang_union_files: list[Path] = []
fails: list[str] = []

with ThreadPoolExecutor(max_workers=args.jobs) as pool:
    fut2lang = {pool.submit(prune_language, l): l for l in langs}
    for fut in as_completed(fut2lang):
        lang = fut2lang[fut]
        try:
            fut.result()
        except Exception as exc:
            print(f'\033[31m{lang} prune failed:\033[0m', exc)
            fails.append(lang)

# create CFG per language (union → cfg)
for lang in langs:
    if lang in fails: continue
    union, _cfg = make_lang_cfgs(lang)
    if union: lang_union_files.append(union)

# combine everything → BasePhobos.cfg
if lang_union_files:
    make_base_phobos(lang_union_files)
else:
    print('\033[33m[warn]\033[0m nothing to merge into BasePhobos.cfg')

tail_src = PATH_DIR / 'TailStatic.cfg'
tail_dst = CORE_DIR / 'TailStatic.cfg'
if tail_src.exists():
    tail_dst.write_text(tail_src.read_text())
    print('  • copied TailStatic.cfg')
else:
    print('\033[33m[warn]\033[0m TailStatic.cfg missing in', PATH_DIR)

print('\n\033[1mDone.\033[0m')
