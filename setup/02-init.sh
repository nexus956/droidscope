#!/usr/bin/env bash
# 02-init.sh — download the waydroid system/vendor images.
# GAPPS by default (real target apps usually want Play services):
#     ./02-init.sh          -> GAPPS image (Android 13 + Google services)
#     ./02-init.sh vanilla  -> plain LineageOS image
set -euo pipefail

VARIANT="${1:-GAPPS}"

if [ "$VARIANT" = "vanilla" ]; then
    exec pkexec waydroid init 2>/dev/null || exec sudo waydroid init
fi

exec pkexec waydroid init -s GAPPS 2>/dev/null || exec sudo waydroid init -s GAPPS
