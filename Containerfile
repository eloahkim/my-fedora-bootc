# Fedora Atomic (bootc) image — niri + Noctalia v5
FROM quay.io/fedora-ostree-desktops/base-main:44

ARG FEDORA_MAJOR_VERSION=44
ENV FEDORA_MAJOR_VERSION=${FEDORA_MAJOR_VERSION}

COPY scripts/install.sh /root/install.sh

RUN --mount=type=tmpfs,target=/tmp \
    --mount=type=cache,target=/var/cache/dnf \
    --mount=type=cache,target=/var/lib/dnf \
    /root/install.sh

RUN bootc container lint
