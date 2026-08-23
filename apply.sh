#!/usr/bin/env bash
set -euo pipefail

IMAGE="localhost/fedora-niri-noctalia:44"

if command -v bootc >/dev/null 2>&1; then
  echo "==> bootc detectado: trocando a imagem base para $IMAGE"
  sudo bootc switch --transport=containers-storage "$IMAGE"
  echo "==> Pronto. Reinicie (systemctl reboot) e escolha a sessao 'niri' no ly."
  echo "    Rollback: selecione o deployment antigo no GRUB ou 'sudo bootc rollback'."
else
  echo "==> bootc NAO encontrado neste sistema."
  echo "    Opcoes:"
  echo "    1) sudo rpm-ostree install bootc   # requer reboot; depois rode este script de novo"
  echo "    2) Faca push para um registry e use:"
  echo "       sudo rpm-ostree rebase ostree-unverified-registry:ghcr.io/<user>/fedora-niri-noctalia:44"
  exit 1
fi
