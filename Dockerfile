ARG DEBIAN_BASE=debian:trixie-slim
FROM ${DEBIAN_BASE}

ARG DEBIAN_APT_MIRROR=http://mirrors.bfsu.edu.cn/debian
RUN sed -i "s|http://deb.debian.org/debian|${DEBIAN_APT_MIRROR}|g" /etc/apt/sources.list.d/debian.sources \
    && apt-get -o Acquire::Retries=3 -o Acquire::http::Timeout=30 update \
    && case "$(dpkg --print-architecture)" in \
        arm64) cross="gcc-x86-64-linux-gnu libc6-dev-amd64-cross" ;; \
        amd64) cross="gcc-aarch64-linux-gnu libc6-dev-arm64-cross" ;; \
        *) exit 1 ;; \
    esac \
    && apt-get install -y --no-install-recommends ca-certificates cpio curl gcc gpg gpgv libc6-dev pigz xorriso xz-utils zstd \
        debian-cd apt-utils debootstrap isolinux syslinux-common mtools dosfstools $cross \
    && apt-get clean

RUN apt-get install -y --no-install-recommends initramfs-tools-bin fontconfig pango1.0-tools && apt-get clean

WORKDIR /project
ENV TRIHEART_IN_BUILDER=1
ENTRYPOINT ["/bin/bash", "/project/scripts/build-iso"]
