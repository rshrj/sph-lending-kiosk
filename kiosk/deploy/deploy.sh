#!/usr/bin/env bash
# Mac → Pi deploy for the SPH lending kiosk (kiosk/). Same approach as the demo app's
# deploy/deploy.sh: rsync, native build against the Pi's Qt 6.8, run as a transient
# systemd --user unit on the labwc Wayland session (so VNC sees it).
# The inventory backend is deployed separately: backend/deploy.sh.
#
#   kiosk/deploy/deploy.sh               sync, build on the Pi, (re)start the kiosk
#   kiosk/deploy/deploy.sh sync|build|run|stop|logs|status
#   kiosk/deploy/deploy.sh autostart     start the kiosk with the desktop session (no-autostart to undo)
#   (every deploy also installs ~/.local/bin/sph-kiosk-launch + a desktop icon and menu entry)
#   kiosk/deploy/deploy.sh shots [dir]   screenshot tour on the Pi → build/pi-shots/ (RESETS the inventory!)
#   kiosk/deploy/deploy.sh logging       one-time: keep the Pi's journal across reboots (capped at 200 MB)
#   kiosk/deploy/deploy.sh bundle [since] debug bundle → build/debug/ (since: -2h default, 'boot', '2026-11-07 14:00')
#
# One-time Pi setup (toolchain, Qt, SPI) is the demo's: deploy/deploy.sh setup / spi.
# Environment: PI_HOST (default rishi@returnstation.local), PI_DIR (default sph-kiosk),
#              APP_ARGS (default --kiosk)
set -euo pipefail

PI_HOST=${PI_HOST:-rishi@returnstation.local}
PI_DIR=${PI_DIR:-sph-kiosk}
APP_ARGS=${APP_ARGS:---kiosk}
UNIT=sph-kiosk
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SSH_OPTS=(-o ControlMaster=no -o ControlPath=none -o ConnectTimeout=8)

pi() { ssh "${SSH_OPTS[@]}" "$PI_HOST" "$@"; }

# Shell snippet that finds the logged-in user's Wayland socket (labwc) on the Pi.
read -r -d '' WAYLAND_ENV <<'SH' || true
export XDG_RUNTIME_DIR=/run/user/$(id -u)
sock=$(ls "$XDG_RUNTIME_DIR" 2>/dev/null | grep -E '^wayland-[0-9]+$' | head -1)
if [ -z "$sock" ]; then
    echo "No Wayland session for $(whoami). Log in on the Pi's screen (or via VNC) first." >&2
    exit 1
fi
SH

cmd_sync() {
    rsync -az --delete -e "ssh ${SSH_OPTS[*]}" \
        --exclude build/ --exclude .DS_Store --exclude .cache/ \
        "$ROOT/" "$PI_HOST:$PI_DIR/"
}

cmd_build() {
    pi "cd $PI_DIR && cmake --preset pi-release >/dev/null && cmake --build --preset pi-release && cmake --install build/pi-release >/dev/null && echo 'installed ~/.local/bin/sph-kiosk'"
    cmd_desktop
}

# Launcher script + "SPH Kiosk" icon on the desktop and in the app menu (all run the launcher).
cmd_desktop() {
    pi "set -e
install -D -m 755 $PI_DIR/deploy/sph-kiosk-launch ~/.local/bin/sph-kiosk-launch
install -D -m 644 $PI_DIR/deploy/sph-kiosk.png ~/.local/share/icons/sph-kiosk.png
mkdir -p ~/.local/share/applications ~/Desktop ~/.config/libfm
cat > ~/.local/share/applications/$UNIT.desktop <<DESKTOP
[Desktop Entry]
Type=Application
Name=SPH Kiosk
Comment=Start the lending kiosk fullscreen (restarts it if it is already running)
Exec=\$HOME/.local/bin/sph-kiosk-launch $APP_ARGS
Icon=\$HOME/.local/share/icons/sph-kiosk.png
Terminal=false
Categories=Utility;
DESKTOP
install -m 755 ~/.local/share/applications/$UNIT.desktop ~/Desktop/$UNIT.desktop
# open desktop launchers without the 'execute this file?' prompt (pcmanfm/libfm)
f=~/.config/libfm/libfm.conf
[ -f \$f ] || printf '[config]\\n' > \$f
grep -q '^quick_exec=' \$f && sed -i 's/^quick_exec=.*/quick_exec=1/' \$f || sed -i '/^\\[config\\]/a quick_exec=1' \$f
echo 'desktop icon + menu entry: SPH Kiosk'"
}

cmd_stop() {
    # Also stop the demo app: both want the whole screen.
    pi "for u in $UNIT kiosk-lab; do systemctl --user stop \$u.service 2>/dev/null; systemctl --user reset-failed \$u.service 2>/dev/null; done; true"
}

cmd_run() {
    pi "$WAYLAND_ENV
WAYLAND_DISPLAY=\$sock \$HOME/.local/bin/sph-kiosk-launch $APP_ARGS
sleep 2
systemctl --user is-active --quiet $UNIT && echo '$UNIT running on '\$sock || { sudo journalctl -n 40 --no-pager _SYSTEMD_USER_UNIT=$UNIT.service; exit 1; }"
}

# The Pi's journal is volatile with no per-user files, so read the system journal.
cmd_logs() { pi "sudo journalctl -f -n 50 _SYSTEMD_USER_UNIT=$UNIT.service"; }
cmd_status() { pi "systemctl --user status $UNIT --no-pager || true; curl -s localhost:8000/health; echo"; }

cmd_autostart() {
    pi "mkdir -p ~/.config/autostart && rm -f ~/.config/autostart/kiosk-lab.desktop && cat > ~/.config/autostart/$UNIT.desktop <<DESKTOP
[Desktop Entry]
Type=Application
Name=SPH Kiosk
Exec=\$HOME/.local/bin/sph-kiosk-launch $APP_ARGS
X-GNOME-Autostart-enabled=true
DESKTOP
echo 'autostart enabled (~/.config/autostart/$UNIT.desktop; Kiosk Lab autostart removed)'"
}
cmd_no_autostart() { pi "rm -f ~/.config/autostart/$UNIT.desktop && echo 'autostart disabled'"; }

cmd_shots() {
    local out=${1:-$ROOT/build/pi-shots}
    mkdir -p "$out"
    cmd_stop
    pi "$WAYLAND_ENV
rm -rf /tmp/sph-kiosk-shots && mkdir -p /tmp/sph-kiosk-shots
KIOSK_STAFF_PIN=\$(cat \$HOME/kiosk-backend/data/staff_pin) WAYLAND_DISPLAY=\$sock QT_QPA_PLATFORM=wayland timeout 120 \$HOME/.local/bin/sph-kiosk --kiosk --idle 0 --screenshot /tmp/sph-kiosk-shots 2>&1 | grep -v '^qml: saved' || true"
    scp "${SSH_OPTS[@]}" -q "$PI_HOST:/tmp/sph-kiosk-shots/*.png" "$out/"
    echo "screenshots in $out"
}

# The Pi OS default journal is volatile (lost on every reboot, so crashes/power cuts left no trace).
cmd_logging() {
    pi "set -e
sudo mkdir -p /etc/systemd/journald.conf.d /var/log/journal
printf '[Journal]\nStorage=persistent\nSystemMaxUse=200M\nMaxRetentionSec=30day\n' | sudo tee /etc/systemd/journald.conf.d/90-kiosk-persistent.conf >/dev/null
sudo systemd-tmpfiles --create --prefix /var/log/journal
sudo systemctl restart systemd-journald
sudo journalctl --flush
echo \"journal: \$(journalctl --header 2>/dev/null | grep -m1 'File path' || true)\"; sudo journalctl --disk-usage"
}

# Everything needed to debug a test/demo, in one tarball on the Mac. No names, Legi numbers or PINs:
# the logs only carry user ids, and the audit trail is exported without card UIDs.
cmd_bundle() {
    local since=${1:--2h} stamp since_opt; stamp=$(date +%Y%m%d-%H%M%S); since=${since// /T}
    [ "$since" = boot ] && since_opt="-b" || since_opt="--since=$since"
    local out="$ROOT/build/debug"; mkdir -p "$out"
    pi "set -e; d=/tmp/kiosk-debug-$stamp; rm -rf \$d; mkdir -p \$d; cd \$d
J='sudo journalctl --no-pager -o short-iso $since_opt'
\$J _SYSTEMD_USER_UNIT=$UNIT.service > kiosk.log 2>&1 || true
\$J _SYSTEMD_USER_UNIT=kiosk-backend.service > backend.log 2>&1 || true
\$J -k > kernel.log 2>&1 || true
grep -E 'over-current|USB disconnect|under-voltage|Undervoltage|Touch2USB as|Web Camera|uvcvideo|thermal|throttl' kernel.log > kernel-usb-power.log || true
\$J -p warning > warnings-all.log 2>&1 || true
sudo journalctl --list-boots --no-pager > boots.txt 2>&1 || true
{ date; uptime; echo; vcgencmd get_throttled; vcgencmd pmic_read_adc EXT5V_V; vcgencmd measure_temp
  printf 'psu max_current: '; od -An -tu4 --endian=big /proc/device-tree/chosen/power/max_current | tr -d ' '
  echo; free -h; df -h /; echo; lsusb; echo; ls -l /dev/video* 2>&1 | head -3
  echo; echo health: \$(curl -s -m 3 localhost:8000/health)
  echo; systemctl --user status $UNIT kiosk-backend --no-pager 2>&1 | head -30; } > system.txt 2>&1
~/kiosk-backend/.venv/bin/python - > audit-events.csv <<'PY' || true
import csv, json, sqlite3, sys
c = sqlite3.connect('file:' + __import__('os').path.expanduser('~/kiosk-backend/data/inventory.db') + '?mode=ro', uri=True)
w = csv.writer(sys.stdout); w.writerow(['at', 'kind', 'user_id', 'item_id', 'detail'])
for at, kind, uid, iid, det in c.execute('SELECT at, kind, user_id, item_id, detail FROM events ORDER BY id'):
    d = json.loads(det) if det else {}
    d.pop('uid', None)  # card UIDs stay on the Pi
    w.writerow([at, kind, uid, iid, json.dumps(d) if d else ''])
PY
XDG_RUNTIME_DIR=/run/user/\$(id -u) WAYLAND_DISPLAY=\$(ls /run/user/\$(id -u) | grep -E '^wayland-[0-9]+$' | head -1) grim screen.png 2>/dev/null || true
cd /tmp && tar czf kiosk-debug-$stamp.tgz kiosk-debug-$stamp && rm -rf \$d"
    scp "${SSH_OPTS[@]}" -q "$PI_HOST:/tmp/kiosk-debug-$stamp.tgz" "$out/" && pi "rm -f /tmp/kiosk-debug-$stamp.tgz"
    tar xzf "$out/kiosk-debug-$stamp.tgz" -C "$out" && rm "$out/kiosk-debug-$stamp.tgz"
    echo "debug bundle: $out/kiosk-debug-$stamp/"; ls "$out/kiosk-debug-$stamp"
}

case "${1:-deploy}" in
    sync)         cmd_sync ;;
    build)        cmd_sync; cmd_build ;;
    run)          cmd_run ;;
    stop)         cmd_stop ;;
    logs)         cmd_logs ;;
    status)       cmd_status ;;
    autostart)    cmd_autostart ;;
    desktop)      cmd_sync; cmd_desktop ;;
    no-autostart) cmd_no_autostart ;;
    shots)        shift; cmd_shots "$@" ;;
    logging)      cmd_logging ;;
    bundle)       shift; cmd_bundle "$@" ;;
    deploy)       cmd_sync; cmd_build; cmd_run ;;
    *) sed -n '2,17p' "$0"; exit 1 ;;
esac
