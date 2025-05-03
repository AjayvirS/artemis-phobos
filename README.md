# artemis_bwrap - Minimal-FS Pruning Toolkit

This repository contains tools to automatically discover the minimal set of filesystem bindings needed by different build & test frameworks (Java/Gradle/Maven, Python/pytest, C/Make, Swift, etc.) when running inside a Bubblewrap sandbox. It also ties into our “Phobos” security policy workflow, turning raw binding data + per‐exercise overrides into a final `phobos.cfg` for secure execution.

## Goals

1. **Detect Minimal Bindings**  
   For each student exercise submission, run its build/test script under Bubblewrap and prune filesystem paths in a hierarchical, iterative fashion:
   - Start with everything writable → test
   - Hide (mount empty) → test → mark “n” if safe
   - Read-only → test → mark “r” if sufficient
   - Writable → test → mark “w” if required

   Results per‐exercise go into:
   - `final_bindings_<exercise>.txt`  (path → n/r/w)
   - `final_bwrap_<exercise>.sh`      (replay Bubblewrap invocation)

2. **Compute Global Policy (`base_phobos.cfg`)**  
   – Collect all per‐exercise binding files  
   – For each path:  
     - `w` if **any** exercise needed it writable  
     - else `r` if **any** needed it read-only  
     - else dropped  
   – Merge with fixed Bubblewrap defaults (`/proc`, `/dev`, `--share-net`, timeouts, firewall, etc.)

3. **Exercise-Dependent Overrides**  
   – Instructors supply `phobos-policy.yaml` for per-exercise allowances (extra writable paths, network ports, time/memory limits, etc.)  
   – Our JavaWriter (from Ares2) loads both the `base_phobos.cfg` and the YAML override, eliminates redundant rules, and outputs the final `phobos.cfg`.

---

## Quickstart

1. **Build the Docker image**  
   ```bash
   docker build -t minimal-fs-pruner .
   ```
2. **Mount your exercise and run**
   ```bash
   docker run --rm minimal-fs-pruner
   ````
   This will produce for each exercise:
   ```bash
   /opt/bindings-results/final_bindings_<ex>.txt
   /opt/bindings-results/final_bwrap_<ex>.sh
   ```
3. **Generate** `phobos.cfg`
   Parse all *.txt files, compute union of paths with w>r>n precedence, and emit Bubblewrap + firewall + resource‐limit settings

4. *Apply per-exercise overrides*:
   The instructor’s `phobos-policy.yaml` (in this repo) is fed into our JavaWriter (Ares2 codebase).
   It merges with the auto‐discovered `base_phobos.cfg` and writes out `phobos.cfg` to be used by the test harness



## How it works

1. **detect_minimal_fs.sh**
   Iteratively prunes filesystem access under a Bubblewrap sandbox: hides (n), tests read-only (r), then writable (w) for each directory.
   Skips pseudo-FS (/proc, /dev, /sys, /run, /tmp) and large volatile caches (/var/tmp, /var/cache).
   Binds the parent directory read-only, overrides per-child as needed.
   Captures and filters build/test output, treating test failures as non-fatal during pruning (regex-driven).

2. **detect_minimal_fs.sh**
   Loops over each exercise in student-exercises/.
   Copies that exercise’s source into the shared test repository.
   Calls `detect_minimal_fs.sh` with the correct build script and environment variables.
   Collects per-exercise outputs: final_bindings_<ex>.txt (path→n/r/w) and final_bwrap_<ex>.sh (replay command).

3. **phobos-policy.yaml**
   Instructors specify exercise-specific overrides: additional writable/readonly paths, network ports, time/memory limits.

4. **JavaWriter (Ares2)**
   Loads both the auto-generated base policy (union of discovered bindings) and the instructor’s YAML overrides.
   Eliminates redundant or conflicting rules.
   Outputs the final phobos.cfg used by the secure test harness.

## Contributing
   Add a new language
   Create a build/test script under build-scripts/ that compiles and runs tests for that language.
   Extend Dockerfile to install any new dependencies and copy the script into the container.
   Update run_all_minimal_fs.sh to invoke the new script when iterating exercises.
   Optimise pruning behavior
   Update IGNORE_IGNORABLE_FAILURE_PATTERNS in detect_minimal_fs.sh to match new test-runner output for non-fatal errors.
   Modify the pseudo-FS or critical-path arrays if a language requires additional system directories by default.

### Policy evolution
   Refine phobos-policy.yaml schema to cover new constraints (e.g., database sockets, GPU access).
   Enhance JavaWriter parsing logic to support new policy sections and merge rules.

### Documentation & Examples
   Add sample exercise folders under student-exercises/<lang>-all/ with expected binding outputs.
   Update this README with any new caveats or tips learned from real-world usage.


© TUM CIT ASE — secure-by-default Bubblewrap sandbox policy discovery tool.



