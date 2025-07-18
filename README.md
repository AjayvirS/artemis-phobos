# Write a simplified, table-free, horizontal-rule-free README that should render cleanly
# in most Markdown editors (including some that mis-handle tables or '---' sequences).
#
# We'll save to /mnt/data/README_simple_phobos.md

readme_text = """# Artemis Phobos

Phobos is a containerized toolchain that **discovers** the minimum filesystem and
environment access needed to build and test student programming exercises and then
**replays** those constraints in a Bubblewrap sandbox when grading.

The goal: run untrusted student code with only the paths, network access, and resources
it truly needs, improving reproducibility and safety in automated assessment systems
such as Artemis.

## What Problem Does Phobos Solve?

- Student build scripts often assume full system access.
- Course infrastructure typically wants *least privilege* to limit damage and noise.
- Hand-curating safe bind lists per language or assignment does not scale.
- Phobos measures (\"prunes\") the required filesystem for each exercise automatically,
  merges those results, and produces configuration files a runtime wrapper can use to
  sandbox grading runs.

## High-Level Pipeline

1. **Prune (per exercise, per language).** Re-run an exercise build/test script under
   Bubblewrap while progressively hiding each directory (none → read-only → write) until
   the build succeeds. Record what was needed.
2. **Orchestrate (merge).** Combine all per-exercise results into language-wide and
   global configuration files (BasePhobos and BaseLanguage-<lang>). Produce debug
   intersection reports.
3. **Runtime Sandbox.** Use the generated configs to run student builds/tests with
   Bubblewrap: minimal filesystem, optional network allowlist, resource limits, and
   optional command blocking.

## Repository Layout (abridged)

- `docker/` – Dockerfiles and compose files for prune, orchestrate, and run phases.
  - `prune_phase/` – language-specific prune images and `run_minimal_fs_all.sh` driver.
  - `orchestrate/` – image containing `orchestrate.py` (merges artifacts).
  - `run_phase/` – images used at grading time (phobos-runner).
- `pruning/` – `detect_minimal_fs.sh`, the pruning algorithm (hide→ro→rw).
- `helpers/` – utilities; `emit_artifacts.py` parses prune logs into structured outputs.
- `wrapper/` – `phobos_wrapper.sh`, the runtime Bubblewrap launcher used when grading.
- `security_config/` – seccomp and AppArmor profiles used by run-phase containers.

## Key Generated Artifacts

Each bullet shows filename pattern and what it contains.

- `<lang>_<exercise>.paths` – lines of the form `r /abs/path` or `w /abs/path` that an
  exercise needs. Temp workdir prefixes (created during pruning under `/tmp/...`) are
  rewritten to the stable runtime root `/var/tmp/testing-dir` so configs are reusable.
- `<lang>_<exercise>.json` – structured data for research/audit (dynamic vs. static paths,
  provenance hash, etc.).
- `TailPhobos.cfg` – global Bubblewrap tail flags. Exercise-specific `--chdir` values are
  removed; orchestrate later appends a single runtime `--chdir /var/tmp/testing-dir`.
- `<lang>_union.paths` – union of all exercises for a language (produced by `make_lang_sets.py`).
- `BaseLanguage-<lang>.cfg` – runtime config for that language (derived from the union).
- `BasePhobos.cfg` – union across all languages; used when the runtime cannot decide the
  language.
- `BasePhobosIntersect.cfg` and `Base<Lang>Intersect.cfg` – debug/audit intersection data;
  written under `core/local/debug/` and not used at runtime.

## Expected Input Tree for Pruning

Inside a prune container, exercises are mounted beneath `/var/tmp/testing-dir` like this:

/var/tmp/testing-dir/
python/
ExerciseA/
build_script # or build_script.sh (must be executable)
assignment/ # student code + tests
ExerciseB/...
java/
Exercise1/...


## Pruning Workflow (one language)

- `run_minimal_fs_all.sh <lang>` discovers exercises.
- Each exercise is copied to a private temp dir under `/tmp/`.
- `detect_minimal_fs.sh` probes required directories by running the build script many times.
- A log `final_bindings.txt` is produced in the temp dir.
- `helpers/emit_artifacts.py` parses the log, rewrites temp paths to the runtime root, and
  emits per-exercise `.paths` and `.json` files; it also merges allowed tail flags into
  `TailPhobos.cfg` (dropping per-exercise chdir values).
- Artifacts accumulate in a shared volume mounted at `/var/tmp/path_sets`.
- Temp directories are deleted.

## Orchestration Workflow

Run in the orchestrate container (see `docker/orchestrate`). Typical steps:

- Optionally re-run pruning (omit with `--skip-prune` if not needed).
- For each language in `--langs`, run `make_lang_sets.py` to build `<lang>_union.paths`.
- Generate runtime configuration files:
  - `BaseLanguage-<lang>.cfg` from `<lang>_union.paths`.
  - `BasePhobos.cfg` from the union of all languages.
- Generate intersection files (debug) and place them under `core/local/debug/`.
- Sanitize and finalize `TailPhobos.cfg`: strip stale tokens; append one `--chdir /var/tmp/testing-dir`.
- Write all runtime cfgs to `/var/tmp/opt/core/local` (shared to run-phase).

## Runtime Sandbox (Grading)

`wrapper/phobos_wrapper.sh` assembles a Bubblewrap command and executes a build script.

Selection logic:

- If `--lang <lang>` is supplied and `BaseLanguage-<lang>.cfg` exists, use that.
- Otherwise fall back to `BasePhobos.cfg`.
- Additional cfg files can be layered with repeated `--extra <cfg>` flags.
- The wrapper also reads `TailPhobos.cfg` for global flags (network sharing, runtime chdir).

### Configuration Sections

Each cfg file is an INI-like text file. Example:

[readonly]
/bin
/usr
/lib
/lib64

[write]
/home/sandboxuser/.gradle

[tmpfs]
/var/cache

[network]
allow repo.maven.apache.org:443
allow *.gradle.org:443

[limits]
timeout=600
mem_mb=2048

[restricted-commands]
ls
curl


Section meanings:

- `[readonly]` -> `--ro-bind path path`
- `[write]` -> `--bind path path`
- `[tmpfs]` -> `--tmpfs path`
- `[network]` -> allowed host[:port] entries (converted to a preload netblocker allowlist)
- `[limits]` -> timeout seconds, memory MB
- `[restricted-commands]` -> for each name: resolve in PATH (or use literal absolute path);
  append `--ro-bind /dev/null /abs/path` so the binary cannot run

If either the selected base cfg or `TailPhobos.cfg` is missing, the wrapper warns and runs
the build script directly (no sandbox) to avoid blocking grading.

## Quick Start (Development)

### Clone the repository:

```bash
git clone https://github.com/AjayvirS/artemis-phobos.git
cd artemis-phobos
# Run prune phase
docker compose -f docker/prune_phase/docker-compose.yml up --build
```

### Run a sandboxed build (example: Java run-phase compose):

docker compose -f docker/run_phase/java/docker-compose.yml run --rm phobos-runner \
  ./wrapper/phobos_wrapper.sh --lang java -- ./build_script.sh

If you see an error about a missing seccomp profile, adjust the path in the compose file.
Paths are resolved relative to that compose file; on Windows you may prefer
${PWD}/security_config/seccomp_allow_bwrap.json

