#!/usr/bin/env bash
# burp-cert-install.sh — install the Burp CA as a SYSTEM cert in the container.
#
# Export from Burp first:
#   Proxy -> Proxy settings -> Import / export CA certificate
#   -> "Certificate in DER format" -> save, then:
#
#   ./burp-cert-install.sh /path/to/burp-ca.der
#
# Installs to /system/etc/security/cacerts/<subject_hash>.0 — trusted by every
# app, no user-cert dialog. Android 13 (waydroid's LineageOS 20) still uses
# the classic store; / remounts rw as container root.
set -euo pipefail
cd "$(dirname "$0")"

CERT="${1:-}"
[ -f "$CERT" ] || { echo "usage: ./burp-cert-install.sh /path/to/burp-ca.der"; exit 1; }

DEV="192.168.240.112:5555"
adb connect "$DEV" >/dev/null 2>&1 || true
adb -s "$DEV" get-state >/dev/null 2>&1 || { echo "[!] container not reachable"; exit 1; }

HASH="$(openssl x509 -inform DER -in "$CERT" -subject_hash_old -noout)"
openssl x509 -inform DER -in "$CERT" -out /tmp/burp-ca.pem

echo "[*] installing as system CA: ${HASH}.0"
B64="$(base64 -w0 /tmp/burp-ca.pem)"
INNER="#!/system/bin/sh
mount -o remount,rw /
echo ${B64} | base64 -d > /system/etc/security/cacerts/${HASH}.0
chmod 644 /system/etc/security/cacerts/${HASH}.0
mount -o remount,ro /
echo CERT_OK"
SB64="$(printf '%s' "$INNER" | base64 -w0)"

adb -s "$DEV" shell "echo ${SB64} | base64 -d > /data/local/tmp/install-cert.sh && chmod 755 /data/local/tmp/install-cert.sh"
pkexec waydroid shell /data/local/tmp/install-cert.sh 2>/dev/null \
    || sudo waydroid shell /data/local/tmp/install-cert.sh

echo "[+] installed. Restart target apps (or the container) to pick it up."
echo "    verify: adb shell ls /system/etc/security/cacerts/ | grep $HASH"
