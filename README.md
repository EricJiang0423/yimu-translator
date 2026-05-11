# 译幕

[![CI](https://github.com/EricJiang0423/yimu-translator/actions/workflows/ci.yml/badge.svg)](https://github.com/EricJiang0423/yimu-translator/actions/workflows/ci.yml)

**框住台词，即刻入戏。**

译幕 是一款 macOS 游戏悬浮翻译工具。框选屏幕上的一块区域，OCR 全程使用 Apple Vision 在本地完成，识别到的文字经腾讯云 TMT 翻译后，以悬浮层显示在原文上方。

## 产品方向

- **名称：** 译幕
- **Slogan：** 框住台词，即刻入戏。
- **设计风格：** Midnight Glass（暗夜玻璃）。安静的深色界面、双栏毛玻璃、腾讯蓝作主操作色、警告用樱花珊瑚色，悬浮层保持低干扰半透明，适合长时间游戏。
- **图标：** 纯几何黑白——取景括角框住两行字幕条，无渐变、无文字。
- **翻译服务：** 仅腾讯云 TMT。

## 运行

```bash
scripts/build-direct.sh
.build/direct/game-translator
```

首次启动需要 macOS「屏幕录制」权限：若从终端启动，把权限授予终端；若从 .app 启动，把权限授予「译幕」，然后重启。

构建 .app 安装包与 DMG：

```bash
scripts/build-app.sh
open ".build/app/译幕.app"
```

## 快捷键

- `⌘⇧S`：框选屏幕区域
- `⌘⇧T`：开始 / 暂停自动翻译
- `⌘⇧R`：对当前区域翻译一次
- `⌘⇧H`：隐藏 / 显示悬浮层

## 配置腾讯云

在「译幕」设置面板（左栏）中：

- `SecretId`：腾讯云 API SecretId
- `SecretKey`：腾讯云 API SecretKey
- `Region`：保持 `ap-guangzhou`，除非你的腾讯云资源要求其它区域
- `源语言`：选择游戏文本区域显示的语言
- `目标`：通常是 `简体中文`

填好凭证后点「测试 API」。应用会先保存表单，再用所选源语言发一段简短的游戏对白样本走腾讯 TMT，然后在记录区显示译文预览或服务端报错。

## 使用流程

1. 填入腾讯云凭证。
2. 点「测试 API」。
3. 点「自检」验证悬浮层。
4. 点「开始」，拖框选中游戏文字区域。
5. 临时单次抓取用「立即翻译」；想持续翻译就让「开始」一直运行。

## 悬浮层操作

- 拖顶部细条移动悬浮层。
- 拖右下角把手缩放。
- 点准星按钮把它吸附回所选文字区域上方。
- 点 `x` 关闭。自动轮询不会立刻重新打开被手动关闭的悬浮层；用「浮层」按钮、`⌘⇧H`、「立即翻译」、「自检」，或重新框选区域即可再次显示。

## 验证 / CI

```bash
scripts/test-direct.sh    # 用 swiftc 编译核心模块并跑冒烟测试
scripts/build-direct.sh   # 编译直接可执行文件
scripts/build-app.sh      # 打 .app 与 DMG
swift test                # 见下方说明
```

`scripts/test-direct.sh` 用 `swiftc` 直接编译核心模块和冒烟测试，绕开本地 SwiftPM manifest 的问题。`swift test` 可能在编译源码前就失败——当本地 Command Line Tools 的 `PackageDescription` 与当前 Swift 工具链不匹配时会这样。

GitHub Actions（`.github/workflows/ci.yml`）在 `macos-15` 上跑上面三个脚本，并把 `.app` 与 DMG 作为产物上传。
