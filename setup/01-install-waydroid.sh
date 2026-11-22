#!/usr/bin/env bash
# 01-install-waydroid.sh — Kali/Debian waydroid install + binder boot config
# Re-run safe. Root required (self-elevates via pkexec, falls back to sudo).
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    exec pkexec bash "$0" "$@" 2>/dev/null || exec sudo bash "$0" "$@"
fi

# --- distro check (Debian family only; waydroid has no Kali suite) -----------
if ! command -v apt-get >/dev/null; then
    echo "apt-get not found — this installer covers Debian/Kali only."
    exit 1
fi

# waydro.id repo: Kali's codename (kali-rolling) isn't in the repo's suite
# list. Kali Rolling is Debian-testing compatible -> use the trixie suite.
echo "[*] adding waydro.id repo (trixie suite)..."
curl -s https://repo.waydro.id | bash -s -- trixie

echo "[*] installing waydroid + adb..."
apt-get update -qq
apt-get install -y waydroid adb

# --- binder kernel module config --------------------------------------------
# Kali's kernel ships binder as a module but with a single default device
# (CONFIG_ANDROID_BINDER_DEVICES="binder") and NO binderfs. Waydroid needs
# binder + hwbinder + vndbinder. The module's "devices" parameter fixes this
# at load time. NOTE: on Kali kernels the module is flagged [permanent]
# (cannot be rmmod'd), so if it's already loaded with the wrong device set,
# the fix only takes effect after a REBOOT.
echo "[*] writing binder boot config..."
cat > /etc/modules-load.d/waydroid-binder.conf <<'EOF'
binder_linux
EOF

cat > /etc/modprobe.d/waydroid-binder.conf <<'EOF'
options binder_linux devices=binder,hwbinder,vndbinder
EOF

echo "[*] enabling waydroid-container service..."
systemctl enable --now waydroid-container

# --- node check --------------------------------------------------------------
echo "[*] checking binder nodes..."
sleep 1
if [ -e /dev/vndbinder ] && [ -e /dev/hwbinder ]; then
    echo "[+] /dev/binder /dev/hwbinder /dev/vndbinder present — no reboot needed."
else
    cat <<'EOF'

[!] REBOOT REQUIRED
    The binder module is loaded with the wrong device set and Kali kernels
    pin it [permanent] (rmmod fails: Device or resource busy). The config
    written above loads it correctly on the next boot.
    Reboot, then run 02-init.sh.

EOF
    exit 0
fi

echo "[+] install complete. Next: 02-init.sh"
