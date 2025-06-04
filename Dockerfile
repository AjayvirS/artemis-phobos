FROM ls1tum/artemis-maven-template:java17-22 AS base


RUN apt-get install -y \
    bubblewrap \
    tree \
  && rm -rf /var/lib/apt/lists/*


RUN useradd -m sandboxuser


RUN mkdir -p /opt/core
COPY core/phobos_wrapper.sh                 /opt/core/
COPY ld_preloader/libnetblocker.so                  /opt/core/
COPY core/*.cfg                     /opt/core/

RUN chown -R sandboxuser:sandboxuser /opt
RUN chmod +x /opt/core/phobos_wrapper.sh \
             /opt/core/*.cfg

ENV PATH=/opt/core:$PATH

USER sandboxuser

#ENTRYPOINT ["/opt/core/phobos_wrapper.sh", "-b", "/opt/core/BaseStatic.cfg", "-e", "/opt/core/BasePhobos.cfg", "-t", "/opt/core/TailStatic.cfg", "--", "/var/tmp/script.sh"]
CMD ["/bin/bash"]
