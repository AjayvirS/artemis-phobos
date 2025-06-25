FROM maven:3.9.6-eclipse-temurin-17

RUN apt-get update && apt-get install -y \
    bubblewrap \
    tree \
  && rm -rf /var/lib/apt/lists/*

RUN useradd sandboxuser

RUN mkdir -p /var/tmp/path_sets /var/tmp/opt/core/local \
 && chown -R sandboxuser:sandboxuser /var/tmp/path_sets /var/tmp/opt

RUN mkdir -p /home/sandboxuser/.gradle/wrapper/dists \
            /home/sandboxuser/.m2/repository  \
 && chown -R sandboxuser:sandboxuser /home/sandboxuser

USER sandboxuser

# ---------- 4. default entrypoint = pruning script --------------------------
# The compose file appends the language argument (java / python / c).
ENTRYPOINT ["/var/tmp/pruning/run_minimal_fs_all.sh"]
