#!/usr/bin/env bash
# frida-server-run.sh — push frida-server into the container and start it as
# ROOT. `adb root` is blocked by waydroid images ("not available in Waydroid"),
# but root access into the container is available via `waydroid shell` (lxc
# attach). NOTE: waydroid's CLI chokes on flag arguments after `shell`, so
# container commands with flags are dropped in as scripts and executed by path
# — that's what this does.
set -euo pipefail
cd "$(dirname "$0")"

DEV="192.168.240.112:5555"

adb connect "$DEV" >/dev/null 2>&1 || true
adb -s "$DEV" get-state >/dev/null 2>&1 || {
    echo "[!] adb device $DEV not reachable. Is the session up? (setup/03-session.sh)"
    exit 1
}

# push binary if it's not already in the container
if ! adb -s "$DEV" shell ls /data/local/tmp/frida-server >/dev/null 2>&1; then
    echo "[*] pushing frida-server..."
    adb -s "$DEV" push frida-server /data/local/tmp/frida-server
fi
adb -s "$DEV" shell chmod 755 /data/local/tmp/frida-server

# already running? leave it alone
if adb -s "$DEV" shell pidof frida-server >/dev/null 2>&1; then
    echo "[+] frida-server already running"
else
    echo "[*] starting frida-server as root (password prompt if needed)..."
    adb -s "$DEV" shell 'printf "#!/system/bin/sh\nnohup /data/local/tmp/frida-server >/dev/null 2>&1 &\n" > /data/local/tmp/start-frida.sh && chmod 755 /data/local/tmp/start-frida.sh'
    pkexec waydroid shell /data/local/tmp/start-frida.sh 2>/dev/null \
        || sudo waydroid shell /data/local/tmp/start-frida.sh
    sleep 2
fi

echo "[*] verifying with frida-ps -U ..."
sleep 1
frida-ps -U | head -8
echo "[+] frida live."
