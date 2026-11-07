#!/usr/bin/env bash
# Mac → Pi deploy for the inventory backend (separate from the kiosk UI's deploy/deploy.sh).
#
#   backend/deploy.sh          sync, install deps, (re)start the service
#   backend/deploy.sh logs|stop|status|reset|labels
#   backend/deploy.sh pin [NEW]   show the staff PIN, or set a new one (4-8 digits)
#
# Runs as a systemd --user service on 127.0.0.1:8000. Data: ~/kiosk-backend/data/inventory.db
# Environment: PI_HOST (default rishi@returnstation.local), PI_DIR (default kiosk-backend)
set -euo pipefail

PI_HOST=${PI_HOST:-rishi@returnstation.local}
PI_DIR=${PI_DIR:-kiosk-backend}
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SSH_OPTS=(-o ControlMaster=no -o ControlPath=none -o ConnectTimeout=8)
pi() { ssh "${SSH_OPTS[@]}" "$PI_HOST" "$@"; }

UNIT='[Unit]
Description=SPH inventory kiosk backend
After=network.target

[Service]
WorkingDirectory=%h/'"$PI_DIR"'
ExecStart=%h/'"$PI_DIR"'/.venv/bin/uvicorn kiosk_backend.app:app --host 127.0.0.1 --port 8000 --no-access-log
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target'

cmd_deploy() {
    rsync -az --delete -e "ssh ${SSH_OPTS[*]}" \
        --exclude .venv/ --exclude data/ --exclude __pycache__/ --exclude .pytest_cache/ --exclude labels.png \
        "$HERE/" "$PI_HOST:$PI_DIR/"
    pi "set -e; cd $PI_DIR
        [ -x .venv/bin/python ] || python3 -m venv .venv
        mkdir -p data && chmod 700 data      # inventory DB + staff PIN: owner only
        .venv/bin/pip install -q --disable-pip-version-check -r requirements.txt
        mkdir -p ~/.config/systemd/user
        cat > ~/.config/systemd/user/kiosk-backend.service <<'EOF'
$UNIT
EOF
        systemctl --user daemon-reload
        systemctl --user enable --quiet kiosk-backend.service
        systemctl --user restart kiosk-backend.service
        for i in \$(seq 20); do curl -sf localhost:8000/health && echo && exit 0; sleep 0.5; done
        echo 'backend did not come up:' >&2; journalctl --user -u kiosk-backend -n 30 --no-pager >&2; exit 1"
}

case "${1:-deploy}" in
    deploy) cmd_deploy ;;
    logs)   pi 'sudo journalctl -f -n 100 _SYSTEMD_USER_UNIT=kiosk-backend.service' ;;  # no per-user journal on the Pi
    stop)   pi 'systemctl --user stop kiosk-backend' ;;
    status) pi 'systemctl --user status kiosk-backend --no-pager; curl -s localhost:8000/health; echo' ;;
    reset)  pi "curl -s -X POST -H \"X-Staff-Pin: \$(cat $PI_DIR/data/staff_pin)\" localhost:8000/admin/reset; echo" ;;
    pin)    if [ -n "${2:-}" ]; then
                [[ $2 =~ ^[0-9]{4,8}$ ]] || { echo "PIN must be 4-8 digits" >&2; exit 2; }
                pi "umask 077; mkdir -p $PI_DIR/data && echo $2 > $PI_DIR/data/staff_pin" && echo "staff PIN set"
            else
                pi "cat $PI_DIR/data/staff_pin 2>/dev/null || echo 'no PIN yet: open the staff panel once (or: deploy.sh pin NEW)'"
            fi ;;
    labels) pi "cd $PI_DIR && .venv/bin/python -m kiosk_backend.labels /tmp/labels.png" \
              && scp -q "${SSH_OPTS[@]}" "$PI_HOST:/tmp/labels.png" "$HERE/labels.png" && echo "→ $HERE/labels.png" ;;
    *) echo "usage: $0 [deploy|logs|stop|status|reset|labels|pin [NEW]]" >&2; exit 2 ;;
esac
