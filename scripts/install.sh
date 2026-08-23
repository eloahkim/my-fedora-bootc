#!/usr/bin/env bash
# Fedora Atomic (bootc) image — Mango (wl-only) + Noctalia v5
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
# Compositor = Mango (compilado do fonte na seção abaixo); wlroots vem do
# pacote Fedora (wlroots-devel 0.20.2). Xwayland nativo do Mango.
# ---------------------------------------------------------------------------
dnf5 -y install \
  noctalia \
  ly \
  xorg-x11-server-Xwayland \
  NetworkManager \
  flatpak \
  xdg-desktop-portal \
  xdg-desktop-portal-wlr \
  xdg-desktop-portal-gtk \
  pipewire \
  pipewire-pulseaudio \
  wireplumber \
  foot \
  imv \
  zathura \
  mpv \
  mesa-va-drivers-freeworld \
  intel-media-driver \
  libva-utils \
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
  qt6ct \
  libnotify \
  gnome-keyring \
  polkit \
  wl-clipboard \
  cliphist \
  ddcutil \
  google-noto-fonts-all \
  jetbrains-mono-fonts \
  liberation-fonts \
  zip \
  unzip \
  unrar

# ---------------------------------------------------------------------------
# Build deps do Mango (C / meson + ninja). wlroots 0.20 vem do pacote Fedora
# (wlroots-devel 0.20.2); scenefx não é dependência deste branch (wl-only).
# ---------------------------------------------------------------------------
dnf5 -y install \
  meson \
  ninja-build \
  pkgconf-pkg-config \
  gcc \
  git \
  wlroots-devel \
  wayland-devel \
  wayland-protocols-devel \
  libinput-devel \
  libdrm-devel \
  libxkbcommon-devel \
  pixman-devel \
  pcre2-devel \
  cjson-devel \
  pango-devel \
  libxcb-devel \
  xcb-util-wm-devel

# ---------------------------------------------------------------------------
# Compila e instala o Mango (branch wl-only, commit fixo p/ reprodutibilidade)
# Instala mango.desktop, mango-portals.conf e /usr/etc/mango/config.conf.
# ---------------------------------------------------------------------------
MANGO_COMMIT=3a2c396c425236a512fd8babb241973f364c86d6
git clone --branch wl-only https://github.com/mangowm/mango.git /tmp/mango
cd /tmp/mango
git checkout "$MANGO_COMMIT"
# sysconfdir=/etc evita o bloco de "strip" do meson.build (incompatível com
# meson 1.11). O config instalado em /etc/mango é copiado p/ /usr/etc abaixo.
meson setup build -Dprefix=/usr -Dsysconfdir=/etc
ninja -C build install
cd /

# O meson instalou o config default em /etc/mango/config.conf. bootc preserva
# /etc da imagem como config vendor (nao usar /usr/etc, que o lint bloqueia).
# Noctalia v5: autostart + IPC binds (doc oficial). Append no config default.
cat >> /etc/mango/config.conf <<'CONF'

# --- Noctalia v5 integration (added by image build) ---
exec-once=noctalia
bind=SUPER,space,spawn,noctalia msg panel-toggle launcher
bind=SUPER,s,spawn,noctalia msg panel-toggle control-center
bind=SUPER,comma,spawn,noctalia msg settings-toggle
bind=NONE,XF86AudioRaiseVolume,spawn,noctalia msg volume-up
bind=NONE,XF86AudioLowerVolume,spawn,noctalia msg volume-down
bind=NONE,XF86AudioMute,spawn,noctalia msg volume-mute
bind=NONE,XF86MonBrightnessUp,spawn,noctalia msg brightness-up
bind=NONE,XF86MonBrightnessDown,spawn,noctalia msg brightness-down
CONF

# Wrapper p/ garantir que usuarios ja existentes recebam o config default
# (o mango lê ~/.config/mango/config.conf; se ausente, copia o seed do sistema).
cat > /usr/bin/mango-session <<'WRAP'
#!/bin/sh
mkdir -p "$HOME/.config/mango"
if [ ! -f "$HOME/.config/mango/config.conf" ]; then
  cp -f /etc/mango/config.conf "$HOME/.config/mango/config.conf" 2>/dev/null || true
fi
exec mango "$@"
WRAP
chmod 755 /usr/bin/mango-session

# ly detecta o mango.desktop; aponta o Exec para o wrapper.
cat > /usr/share/wayland-sessions/mango.desktop <<'DESK'
[Desktop Entry]
Encoding=UTF-8
Name=Mango
DesktopNames=mango;wlroots
Comment=mango WM
Exec=/usr/bin/mango-session
Icon=mango
Type=Application
DESK

rm -rf /tmp/mango

# ---------------------------------------------------------------------------
# Flathub (remoto system-wide, como no Silverblue)
# ---------------------------------------------------------------------------
XDG_RUNTIME_DIR=/run flatpak remote-add --system --if-not-exists \
  flathub https://flathub.org/repo/flathub.flatpakrepo

# ---------------------------------------------------------------------------
# ly: habilita o servico template ly@tty2 (o ly nao tem unidade ly.service;
# e' um template ly@.service com TTYPath=/dev/%I). ly conflicta com getty no
# mesmo tty, mas mascaramos mesmo assim por seguranca.
# ---------------------------------------------------------------------------
LY_TTY=2

mkdir -p /usr/lib/systemd/system/multi-user.target.wants
ln -sf ../ly@.service "/usr/lib/systemd/system/multi-user.target.wants/ly@tty${LY_TTY}.service"
ln -sf /dev/null "/usr/lib/systemd/system/getty@tty${LY_TTY}.service"

# Mascara DMs que possam conflitar (gdm da silverblue; sddm pode sobrar no
# /etc entre deployments bootc e quebrar o display-manager.target).
for dm in gdm sddm; do
  ln -sf /dev/null "/usr/lib/systemd/system/${dm}.service"
done

# ---------------------------------------------------------------------------
# Noctalia v5: o autostart é feito via `exec-once=noctalia` no config do Mango
# (método recomendado pela doc; systemd autostart está deprecated). O config
# default já foi escrito em /usr/etc/mango/config.conf e o wrapper
# /usr/bin/mango-session garante o config do usuario. Nada de user-units.
# ---------------------------------------------------------------------------

dnf5 -y clean all
rm -rf /tmp/*
