# 语音听写（Typeless 同款 · 自研实现）

目标：做出与 Typeless 2.13.0 **交互、流程、外观一致**的自有产品；唯一差异 = 登录改为**本地账号密码**（不联网、无服务端账号）。

## 当前形态

| 项 | 实现 |
|---|---|
| 主 App | SwiftUI，iOS 16.1+，`com.tlb.speech` |
| 键盘扩展 | `TypelessKeyboard.appex`，`com.apple.keyboard-service`，`RequestsOpenAccess = true` |
| 键盘 UI | SwiftUI 全键位 QWERTY + 麦克风长按 |
| 录音 | 键盘扩展内 `AVAudioEngine` → 16k/16bit/mono PCM |
| 识别 | 流式 WebSocket → 自建网关 → 云 ASR（Deepgram / Whisper / 火山，可切换） |
| 记录 | App Group 内 `records.json`，App 与键盘共享 |
| 登录 | 本地账号密码，CryptoKit 9000 轮加盐哈希 |
| 构建 | GitHub Actions `macos-14` + XcodeGen，产出未签名 ipa |

## 为什么不用 React Native

原版是 RN + Hermes，但字节码无法复用，且这台开发机是 Windows（无 Xcode / CocoaPods）。
纯 Swift + XcodeGen 可以**零第三方依赖**在云端一次编译成功，视觉效果由我们自己画到一致。

## 目录

```
ios/
  project.yml              XcodeGen 工程定义（app + 键盘扩展两个 target）
  App/                     主 App（引导 / 登录 / 记录 / 设置）
  Keyboard/                键盘扩展（全键位 + 长按录音）
  Shared/                  两端共用（配置、音频、ASR 客户端、本地账号、记录存储）
  Resources/               Info.plist 与 entitlements（App Group）
server/asr_gateway.py      ASR 网关（mock / openai / deepgram）
docs/SPEC.md               逐屏规格采集清单
docs/strings_original.txt  从原版包里抽出的 1232 条文案
```

## 一次完整的动作链

```
用户在任意 App 的输入框
  → 切到「语音听写」键盘
  → 按住空格键（= 麦克风键）
  → 键盘扩展开麦，16k PCM 经 WSS 上行
  → 网关转 Deepgram/Whisper，partial 实时回显在键盘状态条
  → 松手发 finish，服务端给 final
  → textDocumentProxy.insertText 直接落字
  → 同时写入 App Group 的 records.json（App 里能看到历史）
```

## 构建

推到 `main` 或手动触发 `ios-build` workflow，产物是 artifact `Typeless-ipa`。

本地（有 Mac 时）：

```bash
brew install xcodegen
cd ios && xcodegen generate
xcodebuild -project Typeless.xcodeproj -scheme Typeless -sdk iphoneos -configuration Release CODE_SIGNING_ALLOWED=NO
```

## 安装（未签名 ipa）

ipa 是 ad-hoc 签名（含 App Group entitlement），用 TrollStore / 自签工具安装。
装完后需要三步才能真正用起来：设置里添加键盘 → 打开「允许完全访问」→ 允许麦克风。
这跟原版完全一致，也是 `OnboardingView` 引导的内容。

## 与原版的差异（必须承认）

1. 识别引擎不同 → 准确率与延迟曲线不同
2. 无云端账号 → 记录不跨设备同步
3. 无订阅、无额度限制
4. 灵动岛 Live Activity 尚未实现（二期）
5. 中文文案为自写（原版中文由服务端运行时下发，包里没有原文）
