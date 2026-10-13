#!/bin/bash
# Builds poketcg.gbc from WSL using the Linux RGBDS 1.0 binaries.
# Usage (from Windows): wsl -d Ubuntu --cd <repo> -- ./build.sh [make targets]
# Default target is "tcg" (the ROM); use "compare" to check against rom.sha1.
set -e
cd "$(dirname "$0")"

make -j"$(nproc)" "${@:-tcg}" RGBDS="${RGBDS_DIR:-/mnt/c/Users/kimbo/rgbds-1.0}/"
