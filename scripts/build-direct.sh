#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${1:-.build/direct}"
mkdir -p "$BUILD_DIR"

swiftc -swift-version 6 \
  -parse-as-library \
  -emit-module \
  -emit-library \
  -module-name GameTranslatorCore \
  Sources/GameTranslatorCore/*.swift \
  -emit-module-path "$BUILD_DIR/GameTranslatorCore.swiftmodule" \
  -o "$BUILD_DIR/libGameTranslatorCore.dylib" \
  -framework CryptoKit \
  -Xlinker -install_name \
  -Xlinker "@rpath/libGameTranslatorCore.dylib"

swiftc -swift-version 6 \
  -I "$BUILD_DIR" \
  -L "$BUILD_DIR" \
  -lGameTranslatorCore \
  Sources/GameTranslatorApp/*.swift \
  -o "$BUILD_DIR/game-translator" \
  -framework AppKit \
  -framework CoreGraphics \
  -framework CryptoKit \
  -framework Vision \
  -framework ScreenCaptureKit \
  -Xlinker -rpath \
  -Xlinker "@executable_path"

echo "$BUILD_DIR/game-translator"
