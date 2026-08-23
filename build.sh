#!/usr/bin/env bash
set -euo pipefail

podman build -t localhost/fedora-niri-noctalia:44 -f Containerfile .
