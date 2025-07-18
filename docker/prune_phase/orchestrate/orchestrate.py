#!/usr/bin/env python3
"""
orchestrate.py – prune, merge & build binding config files used by Bubblewrap
sandboxes.

Refactored to consume *pre‑generated* per‑exercise artifacts (.paths/.json) and a
cumulative `TailPhobos.cfg` emitted upstream by `run_minimal_fs_all.sh` +
`emit_artifacts.py`.

### Outputs (all in /var/tmp/opt/core/config)
* **BasePhobos.cfg**            – **UNION** of bindings from *all* languages →
  used when the runtime cannot tell which language is running.
* **BaseLanguage-<lang>.cfg**   – full binding set for that language (duplicates ok).
* **BasePhobosIntersect.cfg**   – **INTERSECTION** (common bindings across all
  languages).
* **Base<lang>Intersect.cfg**   – intersection of that language with BasePhobos
  (redundant but useful for auditing).
* **TailPhobos.cfg**            – merged tail flags suitable for *runtime* use.
  (Any per‑exercise `--chdir` tokens found during pruning are stripped; a
  runtime chdir is injected via `--runtime-chdir` CLI argument.)

Overlaps are fine; intersection files are for human inspection.
"""

from __future__ import annotations
import argparse, os, shlex, subprocess, sys, textwrap, time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path
from typing import Dict, Iterable, List, Sequence, Set, Tuple

# ────────────────────────────────────────── CLI
ap = argparse.ArgumentParser(
    formatter_class=argparse.RawTextHelpFormatter,
    description=textwrap.dedent(__doc__))

ap.add_argument('--langs', required=True,
                help='comma‑separated: java,python,c')
ap.add_argument('--tests-dir', default='/var/tmp/testing-dir',
                help='Root that contains <lang>/ sub‑dirs with exercises (passed to prune script).')
ap.add_argument('--path-dir', default='/var/tmp/path_sets',
                help='Where <lang>_*.paths, *.json & TailPhobos.cfg live (input).')
ap.add_argument('--helpers-dir', default='/var/tmp/helpers',
                help='Where helper scripts (make_lang_sets.py) reside.')
ap.add_argument('--jobs', type=int, default=os.cpu_count() or 4)
ap.add_argument('--skip-prune', action='store_true',
                help='Skip running prune scripts; use existing artifacts in --path-dir.')
ap.add_argument('--verbose', action='store_true')
ap.add_argument('--runtime-chdir', default='/var/tmp/testing-dir',
                help='Directory the *runtime* sandbox should chdir into (overrides any per‑exercise chdir seen during pruning).')
args = ap.parse_args()

langs: List[str] = [l.strip() for l in args.langs.split(',') if l.strip()]
PATH_DIR = Path(args.path_dir);            PATH_DIR.mkdir(parents=True, exist_ok=True)
CORE_DIR = Path('/var/tmp/opt/core/config'); CORE_DIR.mkdir(parents=True, exist_ok=True)
INTERSECT_DIR = CORE_DIR / 'debug'
INTERSECT_DIR.mkdir(parents=True, exist_ok=True)

HELPERS_DIR = Path(args.helpers_dir)
PRUNE_SCRIPT = Path('/var/tmp/pruning/run_minimal_fs_all.sh')
MAKE_LANG_SETS = HELPERS_DIR / 'make_lang_sets.py'

# ────────────────────────────────────────── helpers

def run(cmd: Sequence[str] | str, tag: str = '') -> None:
    """Run *cmd* streaming output; raise if exit‑status != 0."""
    pretty = cmd if isinstance(cmd, str) else ' '.join(shlex.quote(str(c)) for c in cmd)
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
    # NOTE: PRUNE_SCRIPT infers EX_ROOT from /var/tmp/testing-dir/<lang>.  It
    # writes per‑exercise artifacts into PATH_DIR via emit_artifacts.py.  See
    # run_minimal_fs_all.sh.
    cmd.append(lang)
    run(cmd, f'prune:{lang}')


# ────────────────────────────────────────── language union generation

def gen_lang_sets(lang: str) -> None:
    """Invoke make_lang_sets.py to produce <lang>_union.paths & _intersection.paths."""
    if not MAKE_LANG_SETS.exists():
        raise FileNotFoundError(f'make_lang_sets.py not found: {MAKE_LANG_SETS}')
    # Skip languages that have no per‑exercise .paths (all exercises skipped).
    if not any(PATH_DIR.glob(f"{lang}_*.paths")):
        print(f'\033[33m[warn]\033[0m no {lang}_*.paths in {PATH_DIR}; skipping langsets.')
        return
    cmd = ['python3', str(MAKE_LANG_SETS), lang, str(PATH_DIR)]
    run(cmd, f'langsets:{lang}')


# ────────────────────────────────────────── utilities

def _read_union(path: Path) -> Tuple[Set[str], Set[str]]:
    """Return (readonly_set, write_set) from a *_union.paths file.

    Lines are expected in the form `r /abs/path` or `w /abs/path` as written by
    make_lang_sets.py.  Blank/comment lines are ignored.
    """
    readonly, write = set(), set()
    for raw in path.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        try:
            mode, p = line.split(maxsplit=1)
        except ValueError:
            continue
        if mode == 'w':
            write.add(p); readonly.discard(p)
        elif p not in write:
            readonly.add(p)
    return readonly, write


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


# ────────────────────────────────────────── tail handling

def _sanitize_tail_tokens(tokens: List[str], runtime_chdir: str) -> List[str]:
    """Drop any per‑exercise --chdir tokens and inject the runtime one.

    During pruning each exercise ran with `--chdir <exercise-workdir>` in the
    TAIL_OPTIONS array in detect_minimal_fs.sh.  Those paths are ephemeral and
    meaningless at runtime.  We therefore discard them and append a stable
    `--chdir runtime_chdir` token.  We preserve other flags (e.g., --share-net).
    """
    out: List[str] = []
    it = iter(tokens)
    for tok in it:
        if tok == '--chdir':
            try: next(it)
            except StopIteration: pass
            continue
        out.append(tok)
    # ensure our runtime chdir appears last
    out += ['--chdir', runtime_chdir]
    return out

_ALLOWED_TAIL_FLAGS = {"--share-net"}

# ────────────────────────────────────────── tail handling


def build_runtime_tail(runtime_chdir: str) -> None:
    """
    Sanitise PATH_DIR/TailPhobos.cfg into CORE_DIR/TailPhobos.cfg.

    1. Tokenise with shlex.split().
    2. Drop every (--chdir <...>) pair.
    3. Drop any orphan absolute‑path tokens (left‑over temp dirs).
    4. Keep only flags in _ALLOWED_TAIL_FLAGS.
    5. Deduplicate flags, preserve first occurrence.
    6. Append '--chdir', runtime_chdir.
    """
    src_tail = PATH_DIR / 'TailPhobos.cfg'
    dst_tail = CORE_DIR / 'TailPhobos.cfg'

    if not src_tail.exists():
        print('\033[33m[warn]\033[0m TailPhobos.cfg missing in', PATH_DIR)
        return

    tokens: list[str] = shlex.split(src_tail.read_text())

    cleaned: list[str] = []
    it = iter(tokens)
    for tok in it:
        if tok == '--chdir':
            next(it, None)
            continue
        if tok.startswith('/'):        # orphan absolute path -> junk, drop
            continue
        if tok in _ALLOWED_TAIL_FLAGS:
            cleaned.append(tok)

    deduped: list[str] = []
    seen = set()
    for t in cleaned:
        if t not in seen:
            seen.add(t)
            deduped.append(t)

    deduped += ['--chdir', runtime_chdir]

    dst_tail.write_text(' '.join(deduped) + '\n')
    print('  • wrote TailPhobos.cfg (runtime chdir set to', runtime_chdir + ')')



# ────────────────────────────────────────── main pipeline
print('\n\033[1mOrchestrating for:\033[0m', ', '.join(langs), '\n')

# 1) prune in parallel (creates per‑exercise artifacts in PATH_DIR)
with ThreadPoolExecutor(max_workers=args.jobs) as pool:
    fut2lang = {pool.submit(prune_language, l): l for l in langs}
    for fut in as_completed(fut2lang):
        lang = fut2lang[fut]
        try:
            fut.result()
        except Exception as exc:
            print(f'\033[31m{lang} prune failed:\033[0m', exc)

# 2) generate per‑language union/intersection files
for L in langs:
    gen_lang_sets(L)

# 3) gather *_union.paths
lang_data = collect_language_data(langs)
if not lang_data:
    print('\033[31m[error]\033[0m no union.paths present – abort')
    sys.exit(1)

# 4) BasePhobos (UNION across langs)
read_union, write_union = set(), set()
for info in lang_data.values():
    write_union |= info['w']
for info in lang_data.values():
    read_union |= (info['r'] - write_union)
write_cfg_path = CORE_DIR / 'BasePhobos.cfg'

def _write_cfg(read_set: Set[str], write_set: Set[str], dest: Path) -> None:
    lines: List[str] = []
    if read_set:
        lines += ['[readonly]', *sorted(read_set), '']
    if write_set:
        lines += ['[write]', *sorted(write_set), '']
    dest.write_text('\n'.join(lines))

_write_cfg(read_union, write_union, write_cfg_path)

# 5) BasePhobosIntersect (intersection across languages)
all_sets = [(info['r'] | info['w']) for info in lang_data.values()]
inter_all = set.intersection(*all_sets)
read_inter_all, write_inter_all = set(), set()
for p in inter_all:
    if any(p in info['w'] for info in lang_data.values()):
        write_inter_all.add(p)
    else:
        read_inter_all.add(p)
_write_cfg(read_inter_all, write_inter_all, INTERSECT_DIR / 'BasePhobosIntersect.cfg')

# 6) per‑language files (full & intersection)
for L, info in lang_data.items():
    _write_cfg(info['r'], info['w'], CORE_DIR / f'BaseLanguage-{L}.cfg')
    Lcap = L.capitalize()
    lang_inter_read  = info['r'] & (read_union | write_union)
    lang_inter_write = info['w'] & (read_union | write_union)
    _write_cfg(lang_inter_read, lang_inter_write, INTERSECT_DIR / f'Base{Lcap}Intersect.cfg')
# 7) TailPhobos (sanitize & inject runtime chdir)
build_runtime_tail(args.runtime_chdir)

print('\n\033[1mDone.\033[0m')
