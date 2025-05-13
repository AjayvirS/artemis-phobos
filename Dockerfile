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

RUN useradd -m sandboxuser
RUN mkdir -p /opt/ld_preloader

ADD test-repos /opt/test-repository
ADD student-exercises /opt/student-exercises
COPY pruning/detect_minimal_fs.sh pruning/run_minimal_fs_all.sh helpers /opt/
COPY ld_preloader/netblocker.c ld_preloader/allowedList.cfg /opt/ld_preloader/

RUN gcc -shared -fPIC -ldl -o /opt/ld_preloader/libnetblocker.so /opt/ld_preloader/netblocker.c
RUN chown -R sandboxuser:sandboxuser /opt && \
    chmod +x /opt/*.sh /opt/ld_preloader/libnetblocker.so
USER sandboxuser

ENV LD_PRELOAD=/opt/ld_preloader/libnetblocker.so
ENV NETBLOCKER_CONF=/opt/ld_preloader/allowedList.cfg

ENTRYPOINT []
# Set the default command to run the bwrap script
# CMD ["bash", "-c", "/opt/detect_minimal_fs.sh"]
CMD ["/bin/bash"]
# CMD ["/bin/bash","-c","/opt/detect_minimal_fs.sh --script /opt/build_script.sh --target /"]