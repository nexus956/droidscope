#!/usr/bin/env bash
# 03-session.sh — boot Android. Requires an active Wayland session (GNOME/KDE
# default to one). Safe to re-run: does nothing if the session already runs.
set -euo pipefail

if waydroid status 2>/dev/null | grep -q "Session:.*RUNNING"; then
    echo "[+] session already RUNNING"
    exit 0
fi

echo "[*] starting waydroid session..."
waydroid session start &
sleep 3

# wait for Android to finish booting (first boot takes a minute or two)
echo "[*] waiting for Android to come up..."
for i in $(seq 1 60); do
    if waydroid status 2>/dev/null | grep -q "Session:.*RUNNING"; then
        echo "[+] session RUNNING — Android window should be on your desktop."
        waydroid status
        exit 0
    fi
    sleep 5
done

echo "[!] session did not reach RUNNING within 5 minutes."
echo "    check: waydroid log | tail -20"
exit 1
