#!/usr/bin/env bash
set -euo pipefail

# Build como root: a imagem precisa estar no storage do sistema (/var/lib/containers/storage)
# para que o `bootc switch` (que roda como root) a encontre. Se ja for root, sudo e no-op.
sudo podman build -t localhost/fedora-mango-noctalia:44 -f Containerfile .
