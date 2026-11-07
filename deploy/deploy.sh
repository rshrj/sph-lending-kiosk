#!/usr/bin/env bash
# Mac → Pi deploy helper. The Pi builds natively against its own Qt (6.8 on
# Debian 13), which avoids maintaining a cross-compile sysroot.
#
#   deploy/deploy.sh setup        one-time: install toolchain + Qt packages on the Pi
#   deploy/deploy.sh              sync sources, build on the Pi, (re)start the app
#   deploy/deploy.sh sync|build|run|stop|logs|status
#   deploy/deploy.sh spi          one-time: enable SPI for the RC522 reader (needs a reboot)
#   deploy/deploy.sh autostart    launch the app automatically when the desktop session starts
#   deploy/deploy.sh no-autostart
#   deploy/deploy.sh qml <file.qml> [args]  run a standalone QML file (e.g. a theme preview) full screen
#   deploy/deploy.sh shots [dir]  run the screenshot tour on the Pi, copy PNGs back
#
# Environment: PI_HOST (default rishi@returnstation.local), PI_DIR (default kiosk-lab),
#              APP_ARGS (default --kiosk)
set -euo pipefail

PI_HOST=${PI_HOST:-rishi@returnstation.local}
PI_DIR=${PI_DIR:-kiosk-lab}
APP_ARGS=${APP_ARGS:---kiosk}
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SSH_OPTS=(-o ControlMaster=no -o ControlPath=none -o ConnectTimeout=8)

pi() { ssh "${SSH_OPTS[@]}" "$PI_HOST" "$@"; }

# Shell snippet that finds the logged-in user's Wayland socket (labwc) on the Pi.
read -r -d '' WAYLAND_ENV <<'EOF' || true
export XDG_RUNTIME_DIR=/run/user/$(id -u)
sock=$(ls "$XDG_RUNTIME_DIR" 2>/dev/null | grep -E '^wayland-[0-9]+$' | head -1)
if [ -z "$sock" ]; then
    echo "No Wayland session for $(whoami). Log in on the Pi's screen (or via VNC) first." >&2
    exit 1
fi
EOF

cmd_setup() {
    scp "${SSH_OPTS[@]}" "$ROOT/deploy/pi-setup.sh" "$PI_HOST:/tmp/kiosk-lab-setup.sh"
    pi 'sudo bash /tmp/kiosk-lab-setup.sh && rm /tmp/kiosk-lab-setup.sh'
}

cmd_sync() {
    rsync -az --delete -e "ssh ${SSH_OPTS[*]}" \
        --exclude build/ --exclude .git/ --exclude .DS_Store --exclude .cache/ \
        "$ROOT/" "$PI_HOST:$PI_DIR/"
}

cmd_build() {
    pi "cd $PI_DIR && cmake --preset pi-release >/dev/null && cmake --build --preset pi-release && cmake --install build/pi-release >/dev/null && echo 'installed ~/.local/bin/kiosk-lab'"
}

cmd_stop() {
    pi 'systemctl --user stop kiosk-lab.service 2>/dev/null; systemctl --user reset-failed kiosk-lab.service 2>/dev/null; true'
}

cmd_run() {
    cmd_stop
    # A transient user unit: survives the SSH session, logs to the journal.
    pi "$WAYLAND_ENV
systemd-run --user --quiet --unit=kiosk-lab --collect \
    -E XDG_RUNTIME_DIR -E WAYLAND_DISPLAY=\$sock -E QT_QPA_PLATFORM=wayland \
    \$HOME/.local/bin/kiosk-lab $APP_ARGS
sleep 2
systemctl --user is-active --quiet kiosk-lab && echo 'kiosk-lab running on '\$sock || { sudo journalctl -n 40 --no-pager _SYSTEMD_USER_UNIT=kiosk-lab.service; exit 1; }"
}

# Run a QML file from the synced repo with Qt's `qml` viewer, in place of the app.
cmd_qml() {
    local file=${1:?usage: deploy.sh qml <file.qml relative to the repo> [args]}; shift
    cmd_sync
    cmd_stop
    pi "$WAYLAND_ENV
command -v qml6 >/dev/null || sudo apt-get install -y -qq qml-qt6 >/dev/null
systemd-run --user --quiet --unit=kiosk-lab --collect \
    -E XDG_RUNTIME_DIR -E WAYLAND_DISPLAY=\$sock -E QT_QPA_PLATFORM=wayland \
    qml6 \$HOME/$PI_DIR/deploy/fullscreen.qml -- --file \$HOME/$PI_DIR/$file $*
sleep 2
systemctl --user is-active --quiet kiosk-lab && echo 'running $file (deploy.sh run brings the app back)' || { sudo journalctl -n 30 --no-pager _SYSTEMD_USER_UNIT=kiosk-lab.service; exit 1; }"
}

cmd_spi() {
    pi 'if [ -e /dev/spidev0.0 ]; then echo "SPI already enabled"; else
            sudo raspi-config nonint do_spi 0 && echo "SPI enabled in /boot/firmware/config.txt — reboot the Pi to apply (sudo reboot)"; fi'
}

# The Pi's journal is volatile with no per-user files, so read the system journal.
cmd_logs() { pi 'sudo journalctl -f -n 50 _SYSTEMD_USER_UNIT=kiosk-lab.service'; }
cmd_status() { pi 'systemctl --user status kiosk-lab --no-pager || true'; }

cmd_autostart() {
    pi "mkdir -p ~/.config/autostart && cat > ~/.config/autostart/kiosk-lab.desktop <<EOF
[Desktop Entry]
Type=Application
Name=Kiosk Lab
Exec=env QT_QPA_PLATFORM=wayland \$HOME/.local/bin/kiosk-lab $APP_ARGS
X-GNOME-Autostart-enabled=true
EOF
echo 'autostart enabled (~/.config/autostart/kiosk-lab.desktop)'"
}
cmd_no_autostart() { pi 'rm -f ~/.config/autostart/kiosk-lab.desktop && echo "autostart disabled"'; }

cmd_shots() {
    local out=${1:-$ROOT/build/pi-shots}
    mkdir -p "$out"
    cmd_stop
    pi "$WAYLAND_ENV
rm -rf /tmp/kiosk-lab-shots && mkdir -p /tmp/kiosk-lab-shots
WAYLAND_DISPLAY=\$sock QT_QPA_PLATFORM=wayland timeout 90 \$HOME/.local/bin/kiosk-lab --kiosk --idle 0 --screenshot /tmp/kiosk-lab-shots 2>&1 | grep -v '^qml: saved' || true"
    scp "${SSH_OPTS[@]}" -q "$PI_HOST:/tmp/kiosk-lab-shots/*.png" "$out/"
    echo "screenshots in $out"
}

case "${1:-deploy}" in
    setup)        cmd_setup ;;
    sync)         cmd_sync ;;
    build)        cmd_sync; cmd_build ;;
    run)          cmd_run ;;
    stop)         cmd_stop ;;
    logs)         cmd_logs ;;
    status)       cmd_status ;;
    spi)          cmd_spi ;;
    autostart)    cmd_autostart ;;
    no-autostart) cmd_no_autostart ;;
    shots)        shift; cmd_shots "$@" ;;
    qml)          shift; cmd_qml "$@" ;;
    deploy)       cmd_sync; cmd_build; cmd_run ;;
    *) sed -n '2,18p' "$0"; exit 1 ;;
esac
