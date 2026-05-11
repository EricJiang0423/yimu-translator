# 译幕

框住台词，即刻入戏。

译幕 is a macOS floating translator for games. Select a screen region, OCR stays local with Apple Vision, and recognized text is translated through Tencent Cloud TMT into a floating overlay above the original game text.

## Product Direction

- **Name:** 译幕
- **Slogan:** 框住台词，即刻入戏。
- **Design style:** Midnight Glass. A quiet graphite UI, Tencent blue for primary actions, sakura coral for warnings, and low-distraction translucent overlays for long play sessions.
- **Provider:** Tencent Cloud TMT only.

## Run

```bash
scripts/build-direct.sh
.build/direct/game-translator
```

The first launch needs macOS Screen Recording permission. If the app is started from Terminal, grant permission to Terminal. If it is started from the app bundle, grant permission to 译幕, then restart.

To build the macOS app bundle and DMG:

```bash
scripts/build-app.sh
open ".build/app/译幕.app"
```

## Shortcuts

- `Cmd+Shift+S`: select screen region
- `Cmd+Shift+T`: start or pause automatic translation
- `Cmd+Shift+R`: translate the current region once
- `Cmd+Shift+H`: hide or show the overlay

## Configure Tencent Cloud

In 译幕 settings:

- `SecretId`: Tencent Cloud API SecretId
- `SecretKey`: Tencent Cloud API SecretKey
- `Region`: keep `ap-guangzhou` unless your Tencent Cloud resource requires another region
- `Source`: choose the language shown in the game text region
- `Target`: usually `简体中文`

Click `Test Tencent API` after entering credentials. The app saves the form first, sends a short game-dialogue sample in the selected source language through Tencent TMT, then shows either the translated preview or the provider error in the status line.

## Workflow

1. Enter Tencent Cloud credentials.
2. Click `Test Tencent API`.
3. Click `Run Self Test` to verify the floating overlay.
4. Click `Start` and drag over the game text area.
5. Use `Translate Now` for a one-off capture, or leave `Start` running for live translation.

## Overlay Controls

- Drag the thin top bar to move the overlay.
- Drag the bottom-right grip to resize it.
- Click the target/crosshair button to snap it back above the selected text region.
- Click the `x` button to close it. Automatic polling will not immediately reopen a user-closed overlay; use `Show/Hide Overlay`, `Cmd+Shift+H`, `Translate Now`, `Run Self Test`, or select a new region to show it again.

## Verify

```bash
scripts/test-direct.sh
scripts/build-direct.sh
scripts/build-app.sh
swift test
```

`scripts/test-direct.sh` compiles the core module and direct smoke tests with `swiftc`, bypassing the local SwiftPM manifest issue. `swift test` may fail before compiling source if the local Command Line Tools `PackageDescription` library is mismatched with the active Swift toolchain.
