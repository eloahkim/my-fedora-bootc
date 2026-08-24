# Fedora Atomic (bootc) image — Mango (wl-only) + Noctalia v5
# base-main: base mínima da Universal Blue (sem GNOME/KDE, built sobre o
# fedora-bootc). Instalamos NetworkManager, flatpak e o stack de desktop
# no install.sh.
FROM ghcr.io/ublue-os/base-main:44

ARG FEDORA_MAJOR_VERSION=44
ENV FEDORA_MAJOR_VERSION=${FEDORA_MAJOR_VERSION}

COPY scripts/install.sh /root/install.sh

RUN --mount=type=tmpfs,target=/tmp \
    --mount=type=cache,target=/var/cache/dnf \
    --mount=type=cache,target=/var/lib/dnf \
    /root/install.sh

RUN bootc container lint
