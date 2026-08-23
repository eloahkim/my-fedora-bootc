# fedora-niri-noctalia

Imagem **Fedora Atomic (bootc)** personalizada com **niri** (compositor scrollable-tiling
Wayland) + **Noctalia v5** (shell), usando **ly** como display manager. Base:
`quay.io/fedora/fedora-bootc:44` (base mínima oficial da Fedora, **sem GNOME/KDE**;
instalamos NetworkManager, flatpak e todo o stack de desktop no `install.sh`).

Tudo nos repos oficiais do Fedora 44, exceto `rar`/`unrar` (RPM Fusion).

## O que a imagem traz

- **Sessão/DM:** `niri`, `noctalia`, `ly`, `xorg-x11-server-Xwayland`
- **Portais/áudio:** `xdg-desktop-portal` `-gnome` `-gtk`, `pipewire`, `pipewire-pulseaudio`, `wireplumber`
- **Apps:** `foot`, `imv`, `zathura`, `mpv`, `vim`, `ncdu`, `btop`, `rclone`, `rsync`, `aria2`, `opus-tools`, `wget`, `efibootmgr` (git fica via toolbox)
- **Aceleração de vídeo (VA-API, AMD/Intel):** `mesa-va-drivers-freeworld`, `intel-media-driver`, `libva-utils` (RPM Fusion free) — decode por hardware de h264/h265/VP9/AV1
- **Temas/integração:** `adw-gtk3-theme`, `qt6ct`, `libnotify`, `gnome-keyring`, `polkit`, `wl-clipboard`, `cliphist`, `ddcutil`, `xwayland-satellite`
- **Fontes:** `google-noto-fonts-all` (todas as famílias Noto: emoji, CJK, etc.), `jetbrains-mono-fonts`, `liberation-fonts`
- **Compactação:** `zip`, `unzip`, `unrar` (RPM Fusion nonfree)

O **Noctalia** e o **xwayland-satellite** sobem como *user-units* acoplados ao
`niri.service` (criados no `install.sh`), então o shell inicia sozinho dentro da
sessão niri — sem precisar editar o `~/.config/niri/config.kdl` do usuário.

## Pré-requisitos na máquina alvo (Kinoite)

- Fedora Kinoite (F41+). Verifique o backend:
  - `bootc status` → se existir, usamos `bootc switch`
  - senão, `rpm-ostree status` (ostree native container) — veja abaixo a alternativa
- `podman` instalado (`rpm-ostree install podman` se faltar)
- Mesma arquitetura da imagem (x86_64)

## Build (na própria máquina Kinoite)

```bash
# transference do repo (git clone / rsync / scp) para a máquina Kinoite, depois:
cd fedora-niri-noctalia
./build.sh          # podman build -> localhost/fedora-niri-noctalia:44
```

## Aplicar (switch in-place, sem formatar)

```bash
./apply.sh
# ou, manualmente:
sudo bootc switch --transport=containers-storage localhost/fedora-niri-noctalia:44
systemctl reboot
```

No primeiro boot aparece o **ly**; escolha a sessão **niri**. O Noctalia sobe
automaticamente. `/home` e `/var` (incluindo flatpaks do Kinoite) são preservados;
o deployment antigo do Kinoite vira um entry de fallback no GRUB.

### Se o Kinoite não tiver `bootc`

```bash
sudo rpm-ostree install bootc && systemctl reboot
./apply.sh
```
Ou, sem instalar bootc, faça push para um registry e rebase:
```bash
podman tag localhost/fedora-niri-noctalia:44 ghcr.io/<user>/fedora-niri-noctalia:44
podman push ghcr.io/<user>/fedora-niri-noctalia:44
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/<user>/fedora-niri-noctalia:44
```

## Rollback

- No GRUB, selecione o deployment anterior (Kinoite), ou:
- `sudo bootc rollback` / `sudo rpm-ostree rollback`

## Atualizações

Rebuild local + `sudo bootc switch localhost/fedora-niri-noctalia:44` (ou `bootc upgrade`
se estiver trackando um registry). Nada de `rpm-ostree upgrade` no deployment custom.

## (Opcional) Configuração fina do niri para o Noctalia

A autostart já é feita via systemd — **não** adicione `spawn-at-startup "noctalia"`
no config (senão o shell sobe duas vezes). Para os ajustes visuais/teclas do Noctalia,
adicione ao seu `~/.config/niri/config.kdl` (substitui os defaults do niri, então
mantenha também seus binds preferidos):

```kdl
// Cantos arredondados + janela de settings do Noctalia flutuando
window-rule {
  geometry-corner-radius 20
  clip-to-geometry true
}
window-rule {
  match app-id="dev.noctalia.Noctalia"
  open-floating true
  default-column-width { fixed 1080; }
  default-window-height { fixed 920; }
}

debug {
  honor-xdg-activation-with-invalid-serial
}

binds {
  Mod+Space { spawn-sh "noctalia msg panel-toggle launcher"; }
  Mod+S     { spawn-sh "noctalia msg panel-toggle control-center"; }
  Mod+Comma { spawn-sh "noctalia msg settings-toggle"; }
  Alt+Tab   { spawn-sh "noctalia msg window-switcher"; }
  XF86AudioRaiseVolume { spawn-sh "noctalia msg volume-up"; }
  XF86AudioLowerVolume { spawn-sh "noctalia msg volume-down"; }
  XF86AudioMute        { spawn-sh "noctalia msg volume-mute"; }
  XF86MonBrightnessUp   { spawn-sh "noctalia msg brightness-up"; }
  XF86MonBrightnessDown { spawn-sh "noctalia msg brightness-down"; }
}

// Blur (requer niri >= 26.04; vem no Fedora 44)
window-rule {
  background-effect { blur true; xray false; }
}
layer-rule {
  match namespace="^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd)$"
  background-effect { xray false; }
}
layer-rule {
  match namespace="noctalia-window-switcher"
  background-effect { blur true; xray false; }
}
blur { passes 2; offset 3.0; noise 0.03; saturation 1.0; }

// Wallpaper backdrop (visível no overview)
layer-rule {
  match namespace="^noctalia-backdrop"
  place-within-backdrop true
}
```

## Troubleshooting

- **ly não aparece / sessão não inicia (SELinux):** o `ly` tem histórico de bloqueio
  no Fedora. Se o login falhar, gere a política:
  ```bash
  sudo ausearch -m AVC -ts recent | audit2allow -M lyfix
  sudo semodule -i lyfix.pp
  ```
- **Laptop (lid/suspend):** o Noctalia trava a tela antes de suspender por padrão.
  Ajuste em `[lockscreen]` na config do Noctalia e, se necessário, `HandleLidSwitch=ignore`
  em `/etc/systemd/logind.conf`.

## Testar em VM antes de aplicar na máquina real

Gere uma imagem de disco com o `bootc-image-builder` e rode no QEMU:

```bash
podman run --rm -it \
  --privileged \
  -v ./:/workspace:ro \
  -v ./out:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 localhost/fedora-niri-noctalia:44
```

Depois abra o `out/*.qcow2` no virt-manager/QEMU.
