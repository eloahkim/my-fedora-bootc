# fedora-mango-noctalia

Imagem **Fedora Atomic (bootc)** personalizada com **Mango** (compositor Wayland,
branch `wl-only`) + **Noctalia v5** (shell), usando **ly** como display manager.
Base: `ghcr.io/ublue-os/base-main:44` (base mínima da **Universal Blue**, sem
GNOME/KDE; instalamos NetworkManager, flatpak e todo o stack de desktop
no `install.sh`). A ublue traz de bônus `just`, regras udev e timers de
atualização automática de flatpaks (system + user).

O **Mango** é compilado do fonte (branch `wl-only`, commit fixo para
reprodutibilidade) dentro do Containerfile. O **wlroots 0.20** vem do próprio
pacote Fedora (`wlroots-devel` 0.20.2), e **não** compilamos `scenefx` (ausente
como dependência neste branch). Xwayland é nativo do Mango (build com xwayland
habilitado).

## O que a imagem traz

- **Sessão/DM:** `mango` (compilado do fonte), `noctalia`, `ly`, `xorg-x11-server-Xwayland`
- **Portais/áudio:** `xdg-desktop-portal`, `xdg-desktop-portal-wlr`, `xdg-desktop-portal-gtk`, `pipewire`, `pipewire-pulseaudio`, `wireplumber`
- **Apps:** `foot`, `imv`, `zathura`, `mpv`, `vim`, `git`, `ncdu`, `btop`, `rclone`, `rsync`, `aria2`, `opus-tools`, `wget`, `efibootmgr`
- **Aceleração de vídeo (VA-API, AMD/Intel):** `mesa-va-drivers-freeworld`, `intel-media-driver`, `libva-utils` (RPM Fusion free) — decode por hardware de h264/h265/VP9/AV1
- **Flatpak:** `flatpak` instalado e remoto **Flathub** pré-configurado (system-wide)
- **Temas/integração:** `adw-gtk3-theme`, `qt6ct`, `libnotify`, `gnome-keyring`, `polkit`, `wl-clipboard`, `cliphist`, `ddcutil`
- **Fontes:** `google-noto-fonts-all` (todas as famílias Noto: emoji, CJK, etc.), `jetbrains-mono-fonts`, `liberation-fonts`
- **Compactação:** `zip`, `unzip`, `unrar` (RPM Fusion nonfree)

O **Noctalia** sobe via `exec-once=noctalia` no config default do Mango
(`/usr/etc/mango/config.conf`, que vira `/etc/mango/config.conf` no boot). Um
wrapper (`/usr/bin/mango-session`) garante que usuários já existentes recebam o
config default no primeiro login. Não usamos user-units do systemd (método
deprecated na v5).

## Pré-requisitos na máquina alvo (Kinoite)

- Fedora Kinoite (F41+). Verifique o backend:
  - `bootc status` → se existir, usamos `bootc switch`
  - senão, `rpm-ostree status` (ostree native container) — veja abaixo a alternativa
- `podman` instalado (`rpm-ostree install podman` se faltar)
- Mesma arquitetura da imagem (x86_64)

## Build (na própria máquina Kinoite)

O build **precisa rodar como root** (`sudo podman`), pois o `bootc switch` (também root)
só enxerga o storage de sistema (`/var/lib/containers/storage`). O `build.sh` já usa `sudo`.

```bash
# transference do repo (git clone / rsync / scp) para a máquina Kinoite, depois:
cd fedora-mango-noctalia
./build.sh          # sudo podman build -> localhost/fedora-mango-noctalia:44
```

Se por acaso buildar como usuário rootless, carregue a imagem no storage do root antes do apply:
```bash
podman save localhost/fedora-mango-noctalia:44 | sudo podman load
```

O build compila o Mango a partir do commit fixo `3a2c396c425236a512fd8babb241973f364c86d6`
(branch `wl-only`). O `wlroots-devel` 0.20.2 é usado direto do Fedora — não há
compilação de wlroots.

## Aplicar (switch in-place, sem formatar)

```bash
./apply.sh
# ou, manualmente:
sudo bootc switch --transport=containers-storage localhost/fedora-mango-noctalia:44
systemctl reboot
```

No primeiro boot aparece o **ly**; escolha a sessão **Mango**. O Noctalia sobe
automaticamente. `/home` e `/var` (incluindo flatpaks do Kinoite) são preservados;
o deployment antigo do Kinoite vira um entry de fallback no GRUB.

### Se o Kinoite não tiver `bootc`

```bash
sudo rpm-ostree install bootc && systemctl reboot
./apply.sh
```
Ou, sem instalar bootc, faça push para um registry e rebase:
```bash
podman tag localhost/fedora-mango-noctalia:44 ghcr.io/<user>/fedora-mango-noctalia:44
podman push ghcr.io/<user>/fedora-mango-noctalia:44
sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/<user>/fedora-mango-noctalia:44
```

## Rollback

- No GRUB, selecione o deployment anterior (Kinoite), ou:
- `sudo bootc rollback` / `sudo rpm-ostree rollback`

A versão anterior com **niri** está preservada no branch `niri` deste repo.

## Atualizações

Rebuild local + `sudo bootc switch localhost/fedora-mango-noctalia:44` (ou `bootc upgrade`
se estiver trackando um registry). Nada de `rpm-ostree upgrade` no deployment custom.

## Configuração fina do Mango para o Noctalia

O autostart e os IPC binds já vêm no config default da imagem
(`/etc/mango/config.conf`). Para ajustar, edite `~/.config/mango/config.conf`
(copiado do default no primeiro login). Referência oficial:
https://docs.noctalia.dev/v5/compositor-settings/mango/

Trecho relevante já embutido:
```ini
exec-once=noctalia
bind=SUPER,space,spawn,noctalia msg panel-toggle launcher
bind=SUPER,s,spawn,noctalia msg panel-toggle control-center
bind=SUPER,comma,spawn,noctalia msg settings-toggle
bind=NONE,XF86AudioRaiseVolume,spawn,noctalia msg volume-up
bind=NONE,XF86AudioLowerVolume,spawn,noctalia msg volume-down
bind=NONE,XF86AudioMute,spawn,noctalia msg volume-mute
bind=NONE,XF86MonBrightnessUp,spawn,noctalia msg brightness-up
bind=NONE,XF86MonBrightnessDown,spawn,noctalia msg brightness-down
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
- **wlroots-0.20.pc ausente:** se o `wlroots-devel` do Fedora não expuser o
  `wlroots-0.20.pc`, o build do Mango falha. Nesse caso, compilar o wlroots 0.20.2
  do fonte antes do Mango (ajustar `install.sh`).

## Testar em VM antes de aplicar na máquina real

Gere uma imagem de disco com o `bootc-image-builder` e rode no QEMU:

```bash
podman run --rm -it \
  --privileged \
  -v ./:/workspace:ro \
  -v ./out:/output \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 localhost/fedora-mango-noctalia:44
```

Depois abra o `out/*.qcow2` no virt-manager/QEMU.
