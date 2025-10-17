# ────────────────────────────────────────────────────────────────────
# Base image already contains a pre-seeded /root/.gradle cache
# ────────────────────────────────────────────────────────────────────
FROM ls1tum/artemis-maven-template:java17-22 AS base


RUN apt-get update && apt-get install -y \
    bubblewrap \
    tree \
  && rm -rf /var/lib/apt/lists/*

# Unprivileged account for the sandbox
RUN useradd -m sandboxuser

# Copy Phobos core files and configuration
RUN mkdir -p /var/tmp/opt/core
COPY ../../../core/phobos_wrapper.sh                 /var/tmp/opt/core/
COPY ../../../core/libnetblocker.so                  /var/tmp/opt/core/
COPY core/config/*.cfg                      /var/tmp/opt/core/
COPY ../../../core/allowedList.cfg                   /var/tmp/opt/core/


RUN mkdir -p /var/tmp/testing-dir &&  touch /var/tmp/testing-dir/gradlew
RUN chown  sandboxuser:sandboxuser /var/tmp/testing-dir/gradlew
RUN chown -R sandboxuser:sandboxuser /var/tmp/testing-dir
RUN chown -R sandboxuser:sandboxuser /var/tmp/opt
RUN chmod +x /var/tmp/opt/core/phobos_wrapper.sh \
             /var/tmp/opt/core/*.cfg
RUN chmod +w /var/tmp/opt/core/allowedList.cfg

# Gradle-cache hand-off:
#   • /root/.gradle is warm thanks to the base image
#   • copy it to sandboxuser so the wrapper/JARs never re-download
USER root
RUN mkdir -p /home/sandboxuser/.gradle && \
    cp -a /root/.gradle/. /home/sandboxuser/.gradle/ || true && \
    chown -R sandboxuser:sandboxuser /home/sandboxuser/.gradle

# Persist the cache between container runs
VOLUME /home/sandboxuser/.gradle
ENV GRADLE_USER_HOME=/home/sandboxuser/.gradle

# ────────────────────────────────────────────────────────────────────
# Final environment tweaks and unprivileged switch
# ────────────────────────────────────────────────────────────────────
ENV PATH=/var/tmp/opt/core:$PATH
USER sandboxuser
