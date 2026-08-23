#!/usr/bin/env bash
set -euo pipefail

FEDORA_MAJOR_VERSION="${FEDORA_MAJOR_VERSION:-44}"

# ---------------------------------------------------------------------------
# RPM Fusion (free + nonfree): codecs proprietários p/ mpv + rar/unrar
# ---------------------------------------------------------------------------
dnf5 -y install \
  "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_MAJOR_VERSION}.noarch.rpm" \
  "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_MAJOR_VERSION}.noarch.rpm"

# ---------------------------------------------------------------------------
# Pacotes (tudo oficial do Fedora 44, exceto rar/unrar que vêm do RPM Fusion)
# ---------------------------------------------------------------------------
dnf5 -y install \
  niri \
  noctalia \
  ly \
  xorg-x11-server-Xwayland \
  NetworkManager \
  flatpak \
  xdg-desktop-portal \
  xdg-desktop-portal-gnome \
  xdg-desktop-portal-gtk \
  pipewire \
  pipewire-pulseaudio \
  wireplumber \
  foot \
  imv \
  zathura \
  mpv \
  vim \
  git \
  ncdu \
  btop \
  rclone \
  rsync \
  aria2 \
  opus-tools \
  wget \
  efibootmgr \
  adw-gtk3-theme \
  gnome-themes-extra \
  qt6ct \
  libnotify \
  gnome-keyring \
  polkit \
  wl-clipboard \
  cliphist \
  ddcutil \
  xwayland-satellite \
  zip \
  unzip \
  rar \
  unrar

# ---------------------------------------------------------------------------
# Detecta o binário do Noctalia (v5 = `noctalia`, v4 = `noctalia-shell`)
# ---------------------------------------------------------------------------
NOCTALIA_BIN="$(command -v noctalia 2>/dev/null || true)"
if [ -z "$NOCTALIA_BIN" ]; then
  NOCTALIA_BIN="$(rpm -ql noctalia 2>/dev/null | grep -m1 '/bin/noctalia' || true)"
fi
NOCTALIA_BIN="${NOCTALIA_BIN:-/usr/bin/noctalia}"

# ---------------------------------------------------------------------------
# ly: habilita e mascara o getty do tty que o ly ocupa
# ---------------------------------------------------------------------------
LY_UNIT="$(rpm -ql ly 2>/dev/null | grep -m1 'systemd/system/ly.service$' || true)"
LY_UNIT="${LY_UNIT:-/usr/lib/systemd/system/ly.service}"
LY_TTY="$(grep -m1 '^TTYPath=' "$LY_UNIT" 2>/dev/null | sed 's#.*/tty##' || true)"
LY_TTY="${LY_TTY:-2}"

mkdir -p /usr/lib/systemd/system/multi-user.target.wants
ln -sf ../ly.service /usr/lib/systemd/system/multi-user.target.wants/ly.service
ln -sf /dev/null "/usr/lib/systemd/system/getty@tty${LY_TTY}.service"

# Desabilita o display manager padrao da silverblue (gdm) para evitar conflito com o ly
if [ -e /usr/lib/systemd/system/gdm.service ]; then
  ln -sf /dev/null /usr/lib/systemd/system/gdm.service
fi

# ---------------------------------------------------------------------------
# User-units: noctalia + xwayland-satellite, acoplados ao niri.service
# (assim o shell sobe dentro da sessão niri sem mexer no ~/.config do usuário)
# ---------------------------------------------------------------------------
mkdir -p /usr/lib/systemd/user/niri.service.wants

cat > /usr/lib/systemd/user/noctalia.service <<UNIT
[Unit]
Description=Noctalia shell
After=niri.service
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=${NOCTALIA_BIN}
Restart=on-failure

[Install]
WantedBy=niri.service
UNIT
ln -sf ../noctalia.service /usr/lib/systemd/user/niri.service.wants/noctalia.service

cat > /usr/lib/systemd/user/xwayland-satellite.service <<UNIT
[Unit]
Description=xwayland-satellite (rootless Xwayland para o niri)
After=niri.service
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=/usr/bin/xwayland-satellite
Restart=on-failure

[Install]
WantedBy=niri.service
UNIT
ln -sf ../xwayland-satellite.service /usr/lib/systemd/user/niri.service.wants/xwayland-satellite.service

dnf5 -y clean all
rm -rf /var/cache/dnf /var/lib/dnf /tmp/*
