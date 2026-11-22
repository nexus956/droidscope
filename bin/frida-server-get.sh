#!/usr/bin/env bash
# frida-server-get.sh — fetch frida-server matching your HOST frida version
# and the container's arch (waydroid container = host arch, so x86_64 hosts
# need android-x86_64, NOT the arm64 build most guides use).
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v frida >/dev/null; then
    echo "[*] installing frida-tools first..."
    pip install --user frida-tools || pip install frida-tools
fi

FRIDA_VER="$(frida --version)"
ARCH="$(uname -m)"
case "$ARCH" in
    x86_64)  ANDROID_ARCH="x86_64" ;;
    aarch64) ANDROID_ARCH="arm64"  ;;
    *) echo "unsupported host arch: $ARCH"; exit 1 ;;
esac

URL="https://github.com/frida/frida/releases/download/${FRIDA_VER}/frida-server-${FRIDA_VER}-android-${ANDROID_ARCH}.xz"
echo "[*] fetching frida-server ${FRIDA_VER} android-${ANDROID_ARCH}..."
wget -q --show-progress -O "frida-server-${FRIDA_VER}.xz" "$URL"
xz -d "frida-server-${FRIDA_VER}.xz"
mv "frida-server-${FRIDA_VER}" frida-server
chmod 755 frida-server
echo "[+] bin/frida-server ready (version ${FRIDA_VER})"
echo "    next: ./frida-server-run.sh"
