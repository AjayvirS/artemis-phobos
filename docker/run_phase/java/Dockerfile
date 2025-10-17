# Use the same base where it already worked
FROM ls1tum/artemis-maven-template:java17-25

# Only the extra you need
RUN apt-get update && apt-get install -y --no-install-recommends bubblewrap \
  && rm -rf /var/lib/apt/lists/*

# (Optional) your core files; keep if you need them
ENV PHOBOS_HOME=/var/tmp/opt/core
RUN mkdir -p "${PHOBOS_HOME}"
COPY *.sh                ${PHOBOS_HOME}/
COPY libnetblocker.so                 ${PHOBOS_HOME}/
COPY config/*.cfg                     ${PHOBOS_HOME}/
COPY allowedList.cfg                  ${PHOBOS_HOME}/
RUN chmod +x ${PHOBOS_HOME}/phobos_wrapper.sh ${PHOBOS_HOME}/*.cfg \
 && chmod +w ${PHOBOS_HOME}/allowedList.cfg
ENV PATH=${PHOBOS_HOME}:$PATH
