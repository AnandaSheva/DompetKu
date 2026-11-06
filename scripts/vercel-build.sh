#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.47.9"
FLUTTER_DIR="/tmp/flutter-${FLUTTER_VERSION}"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  git clone \
    --depth 1 \
    --branch "${FLUTTER_VERSION}" \
    https://github.com/flutter/flutter.git \
    "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter --version
flutter config --enable-web
flutter precache --web
flutter pub get
flutter build web --release --no-web-resources-cdn