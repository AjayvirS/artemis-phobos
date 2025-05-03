FROM maven:3.9.6-eclipse-temurin-17

MAINTAINER Stephan Krusche <krusche@tum.de>


RUN apt-get update && apt-get install -y \
    gnupg \
    bubblewrap \
    tree \
    python3 \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m sandboxuser



ADD jack_o_lantern_test_repository /opt/test-repository
ADD student-exercises     /opt/student-exercises
COPY detect_minimal_fs.sh /opt/detect_minimal_fs.sh
COPY run_minimal_fs_all.sh  /opt/run_minimal_fs_all.sh
COPY test-repos/java/build_script.sh  /opt/test-repository/build_script.sh


RUN chown -R sandboxuser:sandboxuser /opt

RUN chmod +x /opt/*.sh

USER sandboxuser

ENTRYPOINT []
# Set the default command to run the bwrap script
# CMD ["bash", "-c", "/opt/detect_minimal_fs.sh"]
CMD ["/bin/bash"]
# CMD ["/bin/bash","-c","/opt/detect_minimal_fs.sh --script /opt/build_script.sh --target /"]