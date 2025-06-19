FROM ls1tum/artemis-maven-template:java17-22 AS base


RUN apt-get update && apt-get install -y \
          build-essential \
            gcc \
            libssl-dev \
            libnl-3-dev \
    bubblewrap \
    tree \
  && rm -rf /var/lib/apt/lists/*


RUN useradd -m sandboxuser

RUN mkdir -p /var/tmp/opt/core
COPY core/phobos_wrapper.sh                 /var/tmp/opt/core/
COPY core/libnetblocker.so                  /var/tmp/opt/core/
COPY core/remote/*.cfg                     /var/tmp/opt/core/
COPY core/allowedList.cfg                     /var/tmp/opt/core/
COPY test-repos/java                     /var/tmp/testing-dir/
#COPY ld_preloader/netblocker.c /var/tmp/opt/ld_preloader/
# RUN gcc -shared -fPIC -ldl -o /var/tmp/opt/core/libnetblocker.so /var/tmp/opt/ld_preloader/netblocker.c
#RUN rm -rf /var/tmp/opt/ld_preloader


RUN mkdir -p /var/tmp/testing-dir &&  touch /var/tmp/testing-dir/gradlew
RUN chown  sandboxuser:sandboxuser /var/tmp/testing-dir/gradlew
RUN chown -R sandboxuser:sandboxuser /var/tmp/testing-dir
RUN chown -R sandboxuser:sandboxuser /var/tmp/opt
RUN chmod +x /var/tmp/opt/core/phobos_wrapper.sh \
             /var/tmp/opt/core/*.cfg
RUN chmod +w /var/tmp/opt/core/allowedList.cfg


ENV PATH=/var/tmp/opt/core:$PATH

USER sandboxuser

