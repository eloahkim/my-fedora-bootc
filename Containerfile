# Fedora Atomic (bootc) image — niri + Noctalia v5
# fedora-bootc: base mínima oficial da Fedora (sem GNOME/KDE). Instalamos
# NetworkManager, flatpak e todo o stack de desktop no install.sh.
FROM quay.io/fedora/fedora-bootc:44

ARG FEDORA_MAJOR_VERSION=44
ENV FEDORA_MAJOR_VERSION=${FEDORA_MAJOR_VERSION}

COPY scripts/install.sh /root/install.sh

RUN --mount=type=tmpfs,target=/tmp \
    --mount=type=cache,target=/var/cache/dnf \
    --mount=type=cache,target=/var/lib/dnf \
    /root/install.sh

RUN bootc container lint
