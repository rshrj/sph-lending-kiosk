# Kiosk Lab

> The real kiosk (SPH borrow & return) is in [`kiosk/`](kiosk/README.md); its server is in [`backend/`](backend/README.md).
> Kiosk Lab below is the touch/UI test bench it was built from.

Touch / UI test bench for the 7" (1024×600) touchscreen on the Raspberry Pi 5.
Qt 6 Quick (QML) + C++23, CMake. Targets **Qt 6.8** (what Raspberry Pi OS / Debian 13 ships);
the Mac uses Homebrew's newer Qt, so stay within the 6.8 API.

## Mac (develop)

    cmake --preset mac-debug && cmake --build --preset mac-debug
    ./build/mac-debug/kiosk-lab              # windowed 1024×600 (F11 = fullscreen, ⌘Q = quit)
    ./build/mac-debug/kiosk-lab --screenshot /tmp/shots --idle 0   # PNG of every screen

Options: `--kiosk` (fullscreen, frameless, no cursor), `--idle <s>` (attract-screen timeout, 0 = off).

## Pi (deploy)

The Pi builds natively against its system Qt (no cross-compile sysroot needed).

    deploy/deploy.sh setup      # once: apt install cmake, g++, Qt 6 dev + QML modules
    deploy/deploy.sh            # rsync → build on the Pi → (re)start in the labwc session
    deploy/deploy.sh logs       # follow the app's journal
    deploy/deploy.sh stop
    deploy/deploy.sh shots      # screenshot tour on the Pi → build/pi-shots/
    deploy/deploy.sh autostart  # start with the desktop session (no-autostart to undo)

`PI_HOST` overrides the target (default `rishi@returnstation.local`). The app runs as a
transient `systemd --user` unit on the logged-in user's Wayland display, so VNC (wayvnc) sees it.

**Production option:** `deploy/kiosk-lab-eglfs.service` runs Qt directly on KMS/DRM with no
desktop at all (fastest, no compositor) — but then VNC can't show it. Install steps are in the file.

## Layout

    src/            main.cpp, SystemInfo (live stats), IdleMonitor (attract-screen timer)
    qml/            Main.qml, Theme/Notify singletons, AttractScreen, VirtualKeyboard
    qml/components  reusable touch controls (buttons, switches, slider, dial, keypad, swipe/hold-to-confirm…)
    qml/pages       Home, Touch lab (multi-touch / gestures / accuracy), Controls, System, Settings, GuidedFlow
    fonts/          Inter (SIL OFL)
