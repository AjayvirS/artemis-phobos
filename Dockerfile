FROM maven:3.9.6-eclipse-temurin-17

MAINTAINER Stephan Krusche <krusche@tum.de>


RUN apt-get update && apt-get install -y \
    build-essential \
    gcc \
    libssl-dev \
    libnl-3-dev \
    bubblewrap \
    tree \
    python3 \
    strace \
  && rm -rf /var/lib/apt/lists/*

# Create a directory for netblocker
RUN mkdir -p /opt/netblocker && chown sandboxuser:sandboxuser /opt/netblocker

# Copy student repos and helpers
ADD test-repos /opt/test-repository
ADD student-exercises /opt/student-exercises
COPY detect_minimal_fs.sh run_minimal_fs_all.sh helpers /opt/

# Copy and build the netblocker library
COPY netblocker.c allowedList.cfg /opt/netblocker/
RUN gcc -shared -fPIC -ldl -o /opt/netblocker/libnetblocker.so /opt/netblocker/netblocker.c

# Set permissions
RUN chown -R sandboxuser:sandboxuser /opt && \
    chmod +x /opt/*.sh /opt/netblocker/libnetblocker.so

# Switch to unprivileged user
USER sandboxuser

# Environment for LD_PRELOAD inside bwrap
ENV LD_PRELOAD=/opt/netblocker/libnetblocker.so
ENV NETBLOCKER_CONF=/opt/netblocker/allowedList.cfg

ENTRYPOINT []
# Set the default command to run the bwrap script
# CMD ["bash", "-c", "/opt/detect_minimal_fs.sh"]
CMD ["/bin/bash"]
# CMD ["/bin/bash","-c","/opt/detect_minimal_fs.sh --script /opt/build_script.sh --target /"]