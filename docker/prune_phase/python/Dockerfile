################################################################################
# docker/python/Dockerfile  – pruning-only image for Python exercises
#
#   • Installs just what the prune step needs: python3, pip, pytest, ruff,
#     bubblewrap, tree.
#   • Creates the same unprivileged  user  (sandboxuser) and runtime
#     directories used by the Java image, so your docker-compose mounts work
#     unchanged.
#   • Does *not* copy the pruning tool;   /var/tmp  is bind-mounted at runtime
#     by docker-compose and already contains the shared  pruning/  folder.
################################################################################

FROM ubuntu:20.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3 python3-pip python3-venv \
        bubblewrap tree && \
    rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir \
        pytest==8.* \
        ruff==0.8.1

RUN useradd -m sandboxuser

# host bind mounts will point at these; keep ownership consistent
RUN mkdir -p /var/tmp/path_sets /var/tmp/opt/core/local && \
    chown -R sandboxuser:sandboxuser /var/tmp

# optional: a writable pip cache that callers can bind with BWRAP_EXTRA_RW
RUN mkdir -p /home/sandboxuser/.cache/pip && \
    chown -R sandboxuser:sandboxuser /home/sandboxuser


USER sandboxuser

# docker-compose will append the language argument ("python") at run time.
ENTRYPOINT ["/var/tmp/pruning/run_minimal_fs_all.sh"]
