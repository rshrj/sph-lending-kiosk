# SPH Kiosk

The lending kiosk for the ETH Student Project House makerspace: **borrow** and **return**
tools on the 7" (1024×600) Raspberry Pi 5 touchscreen. Qt 6 Quick (QML) + C++23, built the
same way as the demo app in the repo root (Kiosk Lab), which it borrows its pieces from.
SPH look (design/sph/), light mode only. Talks to the inventory server in `backend/`.

## Flow

    borrow:  start → sign in (tap Legi, or type the number) → tray → confirm → done
    return:  start → tray → confirm → done                  (no sign-in)

- **Tray**: the live camera on the left, what's recognised on the right. `/identify` runs about
  once a second. The list mirrors the tray: an item drops off after it has been missing for 3 scans.
  Items that can't be borrowed or returned (already on loan, already yours, not on loan) block
  *Continue* and say why. *Add by hand* takes the number from the label (DAIM-007 → 7). With no
  camera, a simulator panel lets you tap items onto the tray.
- **Confirm**: slide to confirm → `POST /loans` / `POST /returns`. If the server refuses (409),
  you go back to the tray and the reasons are pinned on the items.
- **Done**: due dates (borrow) or where each item goes back (return), then a 10 s countdown → start.
- A **card tap** anywhere (even on the attract screen) signs in and starts borrowing.
- **Idle** 60 s → attract screen, everything reset, signed out. A signed-in session also ends
  after 5 minutes whatever happens (a flickering camera counts as activity).
- **Server down** → "Kiosk temporarily offline" (after 4 s, so blips don't flash).
- **Staff panel**: long-press the SPH logo for 1.5 s (F3 on the Mac), then the staff PIN
  (`backend/deploy.sh pin` shows/sets it). It shows server, camera, reader and vision status,
  open loans, *hold to reset the demo* and *hold to quit*. It locks again when closed or idle.
- **Privacy (public screen)**: names only as "Anna K.", never a Legi number; card UIDs are not
  logged; wrong Legi numbers are throttled server-side (5 → 1 min pause).

## Mac (develop)

    # backend, camera off, scratch DB (see backend/README.md)
    cd backend && KIOSK_CAMERA=off KIOSK_DB=/tmp/dev.db .venv/bin/uvicorn kiosk_backend.app:app

    cd kiosk
    cmake --preset mac-debug && cmake --build --preset mac-debug
    ./build/mac-debug/sph-kiosk                      # windowed 1024×600; F2 = simulated card tap, F3 = staff
    ./build/mac-debug/sph-kiosk --idle 0 --screenshot /tmp/shots   # PNG of every screen (RESETS the inventory)

    # live camera view against the Pi's backend, read-only:
    ssh -fN -L 18000:127.0.0.1:8000 rishi@returnstation.local
    ./build/mac-debug/sph-kiosk --backend http://127.0.0.1:18000 --tour camera --screenshot /tmp/cam

Options: `--kiosk` (fullscreen, no cursor), `--idle <s>` (0 = off), `--backend <url>`
(or `$KIOSK_BACKEND_URL`, default `http://127.0.0.1:8000`), `--screenshot <dir>`, `--tour full|camera`.

## Pi (deploy)

One-time setup (toolchain, Qt, SPI) is shared with the demo: `deploy/deploy.sh setup` / `spi`.

    backend/deploy.sh                 # the inventory server (systemd --user, :8000)
    kiosk/deploy/deploy.sh            # rsync → build on the Pi → (re)start (stops Kiosk Lab)
                                      # also installs the "SPH Kiosk" desktop icon + menu entry
    kiosk/deploy/deploy.sh logs|status|stop
    kiosk/deploy/deploy.sh autostart  # start with the desktop session (replaces Kiosk Lab's)
    kiosk/deploy/deploy.sh shots      # screenshot tour on the Pi (RESETS the inventory)

On the Pi itself: double-tap **SPH Kiosk** on the desktop (or Menu → Accessories). Everything —
icon, menu, autostart, `deploy.sh run` — goes through `~/.local/bin/sph-kiosk-launch`, which
(re)starts the kiosk as the `sph-kiosk` user unit: one instance, logs in the journal, restarted
after a crash. *Hold to quit* in the staff panel leaves you on the desktop.

## Layout

    src/        main.cpp, Backend (HTTP/JSON client + /health), copied from Kiosk Lab:
                RfidService + rfid/ (RC522 driver), IdleMonitor
    qml/        Main (shell + flow), Theme (SPH tokens), Session (who's signed in),
                Tray (what's on the tray + scanning), Fmt, Notify, AttractScreen
    qml/screens Start, SignIn, Tray, Confirm, Done + modals AddByTag, MyLoans, StaffPanel
    qml/components  KButton (skewed SPH button), Header (crumbs), ItemRow, CameraView, Modal, …
                    Keypad, SwipeToConfirm, SuccessMark, CountdownRing, TapPrompt, Toast, HoldButton
                    come from Kiosk Lab
    fonts/, assets/sph/   Proxima Nova, Alternate Gothic No2 (commercial, see design/sph/README.md), logo, brushes
