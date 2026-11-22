#!/usr/bin/env bash
# rearm.sh — the daily one-shot. Run this after any reboot / container restart:
#   adb connect + Burp reverse tunnel + frida-server check.
#
#   ./rearm.sh            re-arm tunnels, make sure frida is up
#   ./rearm.sh burp-on    also route ALL container traffic through Burp
#   ./rearm.sh burp-off   restore direct (non-proxied) container traffic
set -euo pipefail
cd "$(dirname "$0")"

DEV="192.168.240.112:5555"

echo "[*] adb connect..."
adb connect "$DEV" >/dev/null 2>&1 || true
adb -s "$DEV" get-state >/dev/null 2>&1 || {
    echo "[!] device $DEV unreachable — start the session first (setup/03-session.sh)"
    exit 1
}

echo "[*] Burp reverse tunnel (container 127.0.0.1:8080 -> host 127.0.0.1:8080)..."
adb -s "$DEV" reverse tcp:8080 tcp:8080

if adb -s "$DEV" shell pidof frida-server >/dev/null 2>&1; then
    echo "[+] frida-server running"
else
    echo "[*] frida-server down — restarting..."
    ./frida-server-run.sh
fi

case "${1:-}" in
    burp-on)
        adb -s "$DEV" shell settings put global http_proxy 127.0.0.1:8080
        echo "[+] container traffic -> Burp (127.0.0.1:8080 via reverse tunnel)"
        ;;
    burp-off)
        adb -s "$DEV" shell settings put global http_proxy :0
        echo "[+] proxy off — direct traffic restored"
        ;;
esac

echo "[+] armed. Burp default listener (127.0.0.1:8080) catches container traffic."
