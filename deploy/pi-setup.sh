#!/usr/bin/env bash
# One-time Pi provisioning: build toolchain + Qt 6 runtime/dev packages.
# Runs ON the Pi (deploy.sh setup copies it over and runs it with sudo).
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
    echo "run as root (sudo $0)" >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
    cmake ninja-build g++ rsync \
    qt6-base-dev qt6-base-dev-tools \
    qt6-declarative-dev qt6-declarative-dev-tools \
    qt6-wayland \
    qml6-module-qtqml qml6-module-qtqml-models qml6-module-qtqml-workerscript \
    qml6-module-qtquick qml6-module-qtquick-window qml6-module-qtquick-layouts \
    qml6-module-qtquick-controls qml6-module-qtquick-templates \
    qml6-module-qtquick-shapes qml6-module-qtcore \
    qml6-module-qtquick-virtualkeyboard qt6-virtualkeyboard-plugin \
    libqt6svg6 qt6-svg-plugins

echo
echo "Qt: $(dpkg-query -W -f='${Version}' qt6-base-dev)   CMake: $(cmake --version | head -1)   $(g++ --version | head -1)"
