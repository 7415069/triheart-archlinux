ARG DEBIAN_BASE=debian:trixie-slim
FROM ${DEBIAN_BASE}

RUN apt-get -o Acquire::Retries=3 update \
    && case "$(dpkg --print-architecture)" in \
        arm64) cross="gcc-x86-64-linux-gnu libc6-dev-amd64-cross" ;; \
        amd64) cross="gcc-aarch64-linux-gnu libc6-dev-arm64-cross" ;; \
        *) exit 1 ;; \
    esac \
    && apt-get install -y --no-install-recommends ca-certificates cpio curl gcc gpg gpgv libc6-dev pigz xorriso xz-utils zstd $cross \
    && apt-get clean

WORKDIR /project
ENV TRIHEART_IN_BUILDER=1
ENTRYPOINT ["/bin/bash", "/project/scripts/build-iso"]
