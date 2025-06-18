FROM ls1tum/artemis-maven-template:java17-22 AS base


RUN apt-get update && apt-get install -y \
    bubblewrap \
    tree \
  && rm -rf /var/lib/apt/lists/*


# RUN useradd -m sandboxuser

RUN mkdir -p /var/tmp/opt/core
COPY core/phobos_wrapper.sh                 /var/tmp/opt/core/
COPY ld_preloader/libnetblocker.so                  /var/tmp/opt/core/
COPY core/remote/*.cfg                     /var/tmp/opt/core/

# RUN chown -R sandboxuser:sandboxuser /var/tmp
RUN chmod +x /var/tmp/opt/core/phobos_wrapper.sh \
             /var/tmp/opt/core/*.cfg

ENV PATH=/var/tmp/opt/core:$PATH

# USER sandboxuser



#ENTRYPOINT ["/opt/core/phobos_wrapper.sh", "-b", "/opt/core/BaseStatic.cfg", "-e", "/opt/core/BasePhobos.cfg", "-t", "/opt/core/TailStatic.cfg", "--", "build_script.sh"]
#CMD ["/bin/bash"]

