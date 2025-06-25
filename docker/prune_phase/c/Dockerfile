FROM busybox:uclibc AS src

FROM scratch
COPY --from=src /bin/true /bin/true
ENTRYPOINT ["/bin/true"]
