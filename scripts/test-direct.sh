#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${1:-.build/direct-tests}"
mkdir -p "$BUILD_DIR"

swiftc -swift-version 6 \
  -enable-testing \
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
  -parse-as-library \
  -I "$BUILD_DIR" \
  -L "$BUILD_DIR" \
  -lGameTranslatorCore \
  Tests/DirectCoreSmokeTests.swift \
  -o "$BUILD_DIR/game-translator-core-tests" \
  -Xlinker -rpath \
  -Xlinker "@executable_path"

"$BUILD_DIR/game-translator-core-tests"
