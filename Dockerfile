FROM ls1tum/artemis-maven-template:java17-22 AS base


RUN apt-get update && apt-get install -y \
        build-essential \
        gcc \
        libssl-dev \
        libnl-3-dev \
    strace \
    bubblewrap \
    tree \
  && rm -rf /var/lib/apt/lists/*


RUN useradd -m sandboxuser

RUN mkdir -p /opt/core
COPY core/phobos_wrapper.sh                 /opt/core/
COPY ld_preloader/libnetblocker.so                  /opt/core/
COPY core/*.cfg                     /opt/core/
COPY test-repos                     /opt/test-repository/
COPY ld_preloader/netblocker.c /opt/ld_preloader/

RUN chown -R sandboxuser:sandboxuser /opt
RUN chmod +x /opt/core/phobos_wrapper.sh \
             /opt/core/*.cfg

RUN gcc -shared -fPIC -ldl -o /opt/core/libnetblocker.so /opt/ld_preloader/netblocker.c
RUN rm -rf /opt/ld_preloader

ENV PATH=/opt/core:$PATH

USER sandboxuser

#ENTRYPOINT ["/opt/core/phobos_wrapper.sh", "-b", "/opt/core/BaseStatic.cfg", "-e", "/opt/core/BasePhobos.cfg", "-t", "/opt/core/TailStatic.cfg", "--", "build_script.sh"]
#CMD ["/bin/bash"]

