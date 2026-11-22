# Waydroid Pentest Kit

Rooted **Android 13** running near-native on Linux (Kali/Debian), pre-wired for **Frida** and **Burp Suite**.

No emulator. Waydroid runs Android in an LXC container on the host kernel — apps run at near-native speed, root is available out of the box, and the whole mobile-pentest loop (install → spawn → unpin → intercept) runs in seconds.

```
┌──────────────┐    adb (192.168.240.112:5554/5555)   ┌──────────────────────┐
│  Kali host   │ ───────────────────────────────────▶ │ Android 13 container │
│              │                                     │ LineageOS 20 + GAPPS │
│  frida 17.x  │ ◀──────────── frida-ps -U ────────── │ frida-server (root)  │
│  Burp :8080  │ ─────────── reverse tunnel ────────▶ │ 127.0.0.1:8080      │
└──────────────┘      container → host loopback       └──────────────────────┘
```

## What you get

| Piece | Detail |
|---|---|
| Android | LineageOS 20 (Android 13), GAPPS or vanilla image, SELinux disabled in the image |
| Root | `waydroid shell` attaches as root via LXC — `adb root` is blocked by the image, irrelevant |
| Frida | frida-server running as root, version-matched to host `frida` tools |
| Burp | container traffic tunnels to Burp's **default** listener via `adb reverse` — zero Burp config; Burp CA installs as a **system** cert |
| Scripts | httptoolkit's unpinning suite: OkHttp, TrustManagerImpl, Conscrypt, Flutter, root-detection, proxy override |

## Quickstart (fresh Kali)

```bash
git clone https://github.com/nexus956/waydroid-pentest-kit && cd waydroid-pentest-kit

./setup/01-install-waydroid.sh     # repo + packages + binder boot config
#   → if it says REBOOT REQUIRED: reboot, continue after login
./setup/02-init.sh                 # pull the Android image (~1.4 GB, GAPPS)
./setup/03-session.sh              # boot Android (window appears on desktop)
./bin/frida-server-get.sh          # fetch frida-server matching host frida
./bin/frida-server-run.sh          # push + start as root, verify frida-ps -U
./bin/rearm.sh                     # adb tunnel + Burp reverse tunnel + frida check
```

Burp: run it, accept the temp project, export the CA once —
`Proxy → Proxy settings → Import / export CA certificate → Certificate in DER format` — then:

```bash
./bin/burp-cert-install.sh ~/Downloads/burp-ca.der
./bin/rearm.sh burp-on            # route all container traffic through Burp
```

## Daily workflow

```bash
# install the target
adb -s 192.168.240.112:5555 install target.apk

# spawn with root-detection bypass + full unpinning; traffic lands in Burp
frida -U -f com.target.app \
  -l frida-scripts/android-disable-root-detection.js \
  -l frida-scripts/android-certificate-unpinning.js

# attach to something already running
frida -U com.target.app -l frida-scripts/android-certificate-unpinning.js

# Flutter apps: regular unpinning misses Flutter's bundled BoringSSL
frida -U -f com.target.app -l frida-scripts/android-disable-flutter-certificate-pinning.js
```

After any reboot or container restart, one command re-arms everything:
`./bin/rearm.sh` (add `burp-on` to re-route traffic).

## Kali gotchas (found the hard way)

- **binder loads with one device.** Kali's kernel ships `CONFIG_ANDROID_BINDER_DEVICES="binder"` and no binderfs. Waydroid needs `binder,hwbinder,vndbinder` — fixed at module load via `/etc/modprobe.d/waydroid-binder.conf` (written by `01-install-waydroid.sh`).
- **The module is `[permanent]`.** Kali kernels pin `binder_linux` — `rmmod` fails even with zero holders, so a running system can't be fixed in place. The config takes effect on the next boot. That's why the installer says REBOOT REQUIRED instead of reloading.
- **`waydroid shell` chokes on flags.** Its argparse rejects anything that looks like an option (`sh -c ...`, `mount -o ...`). Workaround used throughout: drop the command into a script under `/data/local/tmp/` via adb, execute by path through `waydroid shell`.
- **`waydroid init` needs root** even though most actions don't prompt — every script here self-elevates via `pkexec` (GNOME dialog) with a `sudo` fallback.
- **adb unauthorized on first connect** — accept the RSA dialog on the Android screen (tick "always allow"), or push `~/.android/adbkey.pub` into `/data/misc/adb/adb_keys/`.
- **System cert store:** Android 13 still uses `/system/etc/security/cacerts` (the APEX move lands in 14). `/` remounts rw as container root — the install scripts rely on that.
- **frida-server arch:** the container is the host's arch. x86_64 host → `android-x86_64` build, not arm64. This is the #1 failure in the field.
- **frida versions must match exactly.** Host `frida`/`frida-tools` == `frida-server` version, or every command dies at handshake. `frida-server-get.sh` pins them together automatically.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `Binder node "vndbinder" for waydroid not found` | binder module loaded with wrong device set — reboot (config from `01` applies) |
| `modprobe: could not remove 'binder_linux'` | expected on Kali — module is `[permanent]`, reboot instead |
| `adb: device unauthorized` | accept the dialog on the Android screen, or kill adb-server, click allow, reconnect |
| `adb root` → `not available in Waydroid` | by design — frida runs as root via `waydroid shell`, not via adbd |
| frida-ps -U hangs / empty | frida-server not running → `./bin/frida-server-run.sh`; version mismatch → re-run `frida-server-get.sh` |
| Target refuses to talk through Burp | `./bin/rearm.sh burp-on`; still refusing → app pins, run the unpinning script; own-transport apps → `android-proxy-override.js` |
| No traffic in Burp | `adb reverse --list` should show `tcp:8080`; re-run `./bin/rearm.sh` |
| Container has no internet | proxy set but Burp closed — `./bin/rearm.sh burp-off`, or start Burp |

## Layout

```
setup/    01-install-waydroid.sh  02-init.sh  03-session.sh
bin/      frida-server-get.sh     frida-server-run.sh
          rearm.sh                burp-cert-install.sh
          frida-server            (not in git — fetched by frida-server-get.sh)
frida-scripts/   httptoolkit unpinning suite (see credits)
```

## Credits & licenses

- [Waydroid](https://github.com/waydroid/waydroid) — Android in a container (GPL)
- [Frida](https://github.com/frida/frida) — dynamic instrumentation toolkit
- [httptoolkit/frida-interception-and-unpinning](https://github.com/httptoolkit/frida-interception-and-unpinning) — the unpinning scripts (MIT)
- [Burp Suite](https://portswigger.net/burp) — PortSwigger

Tested on: Kali Rolling 2026.3 (kernel 7.2.15, GNOME Wayland), waydroid 1.6.3, frida 17.24.3, Burp 2026.10.1.

MIT — do whatever. Test targets you're authorized to test.
