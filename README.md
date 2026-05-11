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

## 安装

> ⚠️ 译幕没有 Apple 开发者账号，发布的包是 **ad-hoc 签名、未公证**。macOS Gatekeeper 首次启动会拦截——这是常态，不是出问题了。Homebrew 安装的也不例外，因为 app 本身没有 Apple 公证。
>
> **两种安装方式装完后，首次打开都必须手动放行一次**，两种流程完全相同。

### 安装方式

**方式一：Homebrew**

```bash
brew install --cask ericjiang0423/tap/yimu-translator
```

卸载：

```bash
brew uninstall --cask yimu-translator
rm -rf ~/Library/Preferences/com.yimu.app.plist
```

**方式二：从 [Releases](https://github.com/EricJiang0423/yimu-translator/releases) 下载 DMG**

下载 `yimu-translator-<版本>.dmg`，把「译幕.app」拖进「应用程序」。

### 首次启动（Gatekeeper 放行）

macOS 会拦截未公证的 app。不管用 brew 还是 DMG，首次启动流程如下：

1. 打开「译幕.app」（正常双击或 Launchpad），macOS 弹出警告 **「无法验证开发者」**→ 点「**好**」。
2. 打开 **「系统设置 → 隐私与安全性」**，下拉到 **安全性** 区域。
3. 你会看到一行提示 *「译幕 已被阻止打开」*，旁边有 **「仍要打开」** 按钮 — 点它，再点弹窗中的 **「打开」**。

### 屏幕录制权限

译幕需要用屏幕录制来截取游戏台词区域。这个权限只在 App **启动时**读取一次。

| 操作 | 结果 |
|------|------|
| 启动 → 系统弹出权限对话框 → 点 **「允许」** | ✅ **当前进程立即生效**，可以继续 |
| 点「不允许」或去系统设置手动勾上 | ❌ 必须 **⌘Q 完全退出**再重新打开才生效 |

> 权限是按 App 的代码签名身份记录的。同一版本重装或替换 .app 后，签名指纹（cdhash）会变，需要重新授权。下载新版本同理。

各 Release 附带的 `SHA256SUMS.txt` 可用于校验下载文件。

## 从源码构建运行

需要安装 Xcode Command Line Tools：`xcode-select --install`。

```bash
scripts/build-direct.sh
.build/direct/game-translator
```

首次启动需要 macOS「屏幕录制」权限：
- **从终端启动**：把权限授予「终端」（Terminal.app），然后重启终端再次执行命令。
- **从 .app 启动**：同上安装章节的权限说明，屏幕录制权限只在启动时读取，**⌘Q 完全退出再重开**才生效。

构建 .app 安装包与 DMG：

```bash
scripts/build-app.sh
open ".build/app/译幕.app"
```

## 快速上手

1. 打开译幕，在左栏设置面板填入[腾讯云凭证](#配置腾讯云)。
2. 点「测试 API」验证凭证是否正确。
3. 点「自检」验证悬浮层显示正常。
4. 点「开始」，屏幕上拖框选取游戏台词区域。松开后自动开始轮询翻译。
5. 单次手动抓取用「立即翻译」，暂停用「开始/暂停」按钮。

## 快捷键

- `⌘⇧S`：框选屏幕区域
- `⌘⇧T`：开始 / 暂停自动翻译
- `⌘⇧R`：对当前区域翻译一次
- `⌘⇧H`：隐藏 / 显示悬浮层

## 配置腾讯云

译幕本身只负责本地 OCR + 调腾讯云的「机器翻译 TMT」接口，不会代收任何费用，密钥只保存在你本机的 UserDefaults 里。

### 1. 注册并开通腾讯云 TMT

1. **注册账号**：[cloud.tencent.com/register](https://cloud.tencent.com/register)（可用微信/QQ/邮箱）。
2. **实名认证**：[console.cloud.tencent.com/developer/auth](https://console.cloud.tencent.com/developer/auth)。腾讯云接入接口前必须实名（个人或企业），用身份证 + 人脸刷一下就行。
3. **开通「机器翻译 TMT」服务**：进 [console.cloud.tencent.com/tmt](https://console.cloud.tencent.com/tmt)，点「立即开通」勾选服务协议。TMT 目前有**每月 500 万字符的免费额度**（以腾讯云控制台显示为准），超出按字符计费，价格在控制台的「计费概述」里查。日常游戏字幕量很小，基本用不完免费额度。
4. *（可选，推荐）* 在控制台「财务 → 费用中心 → [费用预警](https://console.cloud.tencent.com/account/usercenter)」给账号设个小额预警，万一调用量异常能及时收到通知。

### 2. 拿到 API 密钥（SecretId / SecretKey）

强烈建议**用子账号**而不是主账号根密钥，权限收到最小：

1. 进 [访问管理 CAM → 用户 → 用户列表](https://console.cloud.tencent.com/cam) → 「新建用户」→「自定义创建」→ 选「可访问资源并接收消息」。
2. 给这个子账号关联策略 `QcloudTMTFullAccess`（只能用机器翻译这一项 API）。
3. 用户创建完成后会显示 **SecretId / SecretKey**，**只显示一次**，立刻复制保存好；忘了只能重新生成。

如果只是自己用、不想折腾子账号，也可以直接在 [API 密钥管理](https://console.cloud.tencent.com/cam/capi) 给主账号生成一对根密钥——权限最大、风险最大，泄漏等于账号被接管，**不要写进任何代码仓库或截图**。

### 3. 在译幕里填入凭证

打开译幕设置面板（左栏）：

- `SecretId`：上一步拿到的 SecretId
- `SecretKey`：上一步拿到的 SecretKey
- `Region`：保持 `ap-guangzhou`，除非你的腾讯云资源要求其它区域
- `源语言`：选择游戏文本区域显示的语言
- `目标`：通常是 `简体中文`

填好后点「测试 API」。译幕会先保存表单，用所选源语言发一段简短的游戏对白样本走 TMT，把译文或服务端报错显示在右侧记录区。常见报错：`AuthFailure.SignatureFailure` 通常是 SecretKey 抄漏字符，`UnauthorizedOperation` 通常是没开通 TMT 服务或子账号没给策略。

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

GitHub Actions：

- `.github/workflows/ci.yml`：push 到 `main` / PR 时在 `macos-15` 上跑构建与测试，并上传产物。
- `.github/workflows/release.yml`：推送 `v*` tag 时自动构建、打包、发布 GitHub Release。发新版本：
  ```bash
  git tag v1.0.1 && git push origin v1.0.1
  ```
  Release 发出后，把 `SHA256SUMS.txt` 里 DMG 的哈希更新到 Homebrew tap 的 cask 中。
