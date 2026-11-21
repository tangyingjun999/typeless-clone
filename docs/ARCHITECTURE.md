# 架构清点与复刻映射

## 原版事实（实读包内文件得出）

- 主 App `com.typeless.mobile` 2.13.0，iOS 16.1+，React Native + Hermes，主 jsbundle 9.8 MB
- 键盘扩展 `keyboard.appex`，`com.apple.keyboard-service`，`RequestsOpenAccess = true`，自带 4.3 MB RN bundle
- 灵动岛 `dynamicisland.appex`（WidgetKit Live Activity）
- URL scheme `typeless://`；后台模式 `audio` / `external-accessory` / `remote-notification`
- 语音链路：`GET /ws/rt_voice_flow?v=ios_x&t=<AES>&m=0` 流式 WebSocket
- `out.js` 是 **Hermes 字节码反汇编**（`switch(_fun_ip)`），逻辑不可复用；字符串表可用
- 中文文案**不在包里**（服务端运行时下发），只能靠截图获取

## 复刻映射

| 原版组件 | 本实现 | 说明 |
|---|---|---|
| RN 主 App | SwiftUI | 页面重写，视觉对齐 |
| keyboard.appex (RN) | SwiftUI 键盘扩展 | 全键位 + 长按录音 |
| 录音 + 编码 | `AVAudioEngine` + `AVAudioConverter` | 16k/16bit/mono |
| 流式 ASR | `ASRClient` → 自建网关 → 云 ASR | 协议 partial/final |
| 文本插入 | `textDocumentProxy.insertText` | 与系统键盘同权限 |
| 历史记录 | App Group `records.json` | 两进程共享 |
| 登录 | 本地账号密码（CryptoKit 加盐哈希） | **唯一差异** |
| 引导/权限流程 | `OnboardingView` 4 步 | 键盘 → 完全访问 → 麦克风 |
| 灵动岛 | 未实现 | 二期 |

## 关键技术约束

1. **键盘扩展必须有 `RequestsOpenAccess = true`**，否则拿不到麦克风与网络。
2. 键盘扩展**不能**用 `UIApplication`，Shared 层不做任何 `UIApplication` 调用。
3. 跨进程共享依赖 **App Group** `group.com.tlb.speech`；`Cfg.shared` 在拿不到 App Group 时自动退回 `UserDefaults.standard`（不崩，但不同步）。
4. iOS ATS 不允许明文 `ws://`，生产必须 `wss://`。
5. 未签名安装（TrollStore 类）需要 ad-hoc 签名并带上 entitlements，否则 App Group 失效——CI 里用 `codesign -f -s - --entitlements` 处理。

## 已知风险

| 风险 | 影响 | 处置 |
|---|---|---|
| App Group 在非越狱环境不可用 | 记录不共享、键盘读不到网关 | 键盘内保留本地副本 + 提示；后续可改 Keychain 共享 |
| 键盘扩展被系统回收 | 录音中断 | 长按期间保持 AVAudioSession active，必要时提示重按 |
| 云 ASR 延迟 | 松手后等待 | 网关侧做 partial 预推 + 5 秒兜底收尾 |
