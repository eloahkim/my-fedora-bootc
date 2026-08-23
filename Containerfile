# Fedora Atomic (bootc) image — niri + Noctalia v5
# silverblue traz toda a plumbing Atomic (NetworkManager, polkit, flatpak, etc.).
# GNOME fica instalado mas não é usado; o DM é o ly.
FROM quay.io/fedora-ostree-desktops/silverblue:44

ARG FEDORA_MAJOR_VERSION=44
ENV FEDORA_MAJOR_VERSION=${FEDORA_MAJOR_VERSION}

COPY scripts/install.sh /root/install.sh

RUN --mount=type=tmpfs,target=/tmp \
    --mount=type=cache,target=/var/cache/dnf \
    --mount=type=cache,target=/var/lib/dnf \
    /root/install.sh

RUN bootc container lint
