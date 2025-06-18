"""
orchestrate.py  –  one command to prune, merge & build all languages.

Usage
    ./orchestrate.py
        --langs       java,python,c
        --ex-root     /var/tmp/opt/student-exercises
        --repo-root   /var/tmp/opt/test-repository
        --path-dir    /opt/path_sets
        --jobs        4
        [--skip-prune]              # debug: reuse existing bindings
        [--no-smoke]                # skip final phobos_wrapper call
        [--verbose]                 # enable verbose logging for underlying scripts
"""

from __future__ import annotations
import argparse, itertools, os, shlex, subprocess, sys, textwrap, time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib        import Path
from typing         import List

# ───────────────────────── CLI ──────────────────────────
p = argparse.ArgumentParser(formatter_class=argparse.RawTextHelpFormatter,
                            description=__doc__)
p.add_argument('--langs',      required=True,
               help='comma-separated list, e.g. java,python,c')
p.add_argument('--ex-root',    default='/var/tmp/opt/student-exercises')
p.add_argument('--repo-root',  default='/var/tmp/opt/test-repository')
p.add_argument('--path-dir',   default='/var/tmp/opt/path_sets')
p.add_argument('--jobs',       type=int, default=os.cpu_count() or 4)
p.add_argument('--skip-prune', action='store_true',
               help='skip run_minimal_fs_all (re-use old *.paths)')
p.add_argument('--no-smoke',   action='store_true',
               help="don't run phobos_wrapper smoke-test")
p.add_argument('--verbose',    action='store_true',
               help='enable verbose logging for underlying scripts')
args = p.parse_args()

langs     : List[str] = [l.strip() for l in args.langs.split(',') if l.strip()]
ex_root   = Path(args.ex_root)
repo_root = Path(args.repo_root)
path_dir  = Path(args.path_dir)
path_dir.mkdir(parents=True, exist_ok=True)
core_dir = Path("/var/tmp/opt/core")

# ───────────────────── helper wrappers ──────────────────
def runcmd(cmd:str | List[str], name:str) -> None:
    """Run shell-command, stream output, raise on non-zero exit."""
    print(f'\033[34m[{name}]\033[0m', cmd if isinstance(cmd, str)
    else ' '.join(shlex.quote(x) for x in cmd))
    t0 = time.time()
    proc = subprocess.run(cmd, shell=isinstance(cmd,str))
    dt = time.time() - t0
    if proc.returncode != 0:
        print(f'\033[31m✗ {name} failed ({dt:.1f}s)\033[0m')
        raise RuntimeError(f'{name} failed (rc={proc.returncode})')
    print(f'\033[32m✓ {name} ok ({dt:.1f}s)\033[0m')

# ───────────────────── processing per-language ────────────
def process_language(lang:str) -> bool:
    """Prune all exercises & build lang-level sets. Returns True if path sets created, False if skipped."""
    if not args.skip_prune:
        prune_cmd = [
            '/var/tmp/opt/pruning/run_minimal_fs_all.sh',
        ]
        if args.verbose:
            prune_cmd.append('--verbose')
        prune_cmd.append(lang)
        runcmd(prune_cmd, f'prune:{lang}')
    lang_ex_dir = ex_root / lang
    if not lang_ex_dir.exists() or not any(lang_ex_dir.iterdir()):
        print(f'\033[33m[warning] No exercises found for {lang}, skipping language sets\033[0m')
        return False

    langsets_cmd = [
        'python3',
        '/var/tmp/opt/helpers/make_lang_sets.py',
    ]

    langsets_cmd.extend([lang, str(path_dir)])
    runcmd(langsets_cmd, f'merge:{lang}')
    return True

# ───────────────────── main orchestration ───────────────
print('\n\033[1mLanguages:\033[0m', ', '.join(langs))
print('Output path-sets: ', path_dir, '\n')

# Track per-language status: True=sets created, False=skipped
lang_status: dict[str, bool] = {}
with ThreadPoolExecutor(max_workers=args.jobs) as pool:
    fut2lang = {pool.submit(process_language, lang): lang for lang in langs}
    for fut in as_completed(fut2lang):
        lang = fut2lang[fut]
        try:
            result = fut.result()
            lang_status[lang] = result
        except Exception as e:
            print(f'\033[31m{lang} failed:\033[0m', e)
            pool.shutdown(wait=False, cancel_futures=True)
            sys.exit(1)

# ─────────── merge across languages once per-language sets are done ──
merge_cmd = ['python3', '/var/tmp/opt/helpers/make_all_lang_sets.py', '--input-dir', str(path_dir), '--output-dir', str(core_dir)]

merge_success = False
try:
    runcmd(merge_cmd, 'merge:all')
    merge_success = True

except Exception:
    # merge:all failure will exit above, so this is unlikely reached
    merge_success = False

# ───────────── check for expected config files ─────────────
base_static = core_dir / 'BaseStatic.cfg'
base_phobos = core_dir / 'BasePhobos.cfg'
tail_static = core_dir / 'TailStatic.cfg'

# ──────────────── detailed summary ────────────────────────
print('\n\033[1mSummary\033[0m')
# Per-language summary
for lang in langs:
    status = lang_status.get(lang)
    if status is True:
        print(f'  \033[32m✓\033[0m [{lang}] Path sets created successfully')
    else:
        print(f'  \033[33m!\033[0m [{lang}] No exercises found; skipped')

# Cross-language merge summary
if merge_success:
    print(f'  \033[32m✓\033[0m [merge:all] Cross-language merge succeeded')
else:
    print(f'  \033[31m✗\033[0m [merge:all] Cross-language merge failed')

# Config files existence
for cfg in [('BaseStatic.cfg', base_static), ('BasePhobos.cfg', base_phobos), ('TailStatic.cfg', tail_static)]:
    name, path = cfg
    if path.exists():
        print(f'  \033[32m✓\033[0m [{name}] Created: {path}')
    else:
        print(f'  \033[31m✗\033[0m [{name}] Missing: {path}')

print('\nAll done.')
