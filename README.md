# Typeless 同款（自研版）

目标：做出与 Typeless 2.13.0 **交互/流程/外观一致**的自有产品，唯一差异 = 登录改为本地账号密码。

## 原版事实（来自包清点）

| 项 | 原版 |
|---|---|
| 主 App | com.typeless.mobile 2.13.0，iOS 16.1+，React Native + Hermes |
| 主 JS | main.jsbundle 9.8 MB（Hermes 字节码） |
| 键盘扩展 | keyboard.appex，`com.apple.keyboard-service`，`RequestsOpenAccess = true`，**自身也是 RN（4.3MB bundle）** |
| 灵动岛 | dynamicisland.appex（WidgetKit Live Activity） |
| URL scheme | `typeless://` |
| 后台模式 | audio / external-accessory / remote-notification |
| 语音链路 | `GET /ws/rt_voice_flow?v=ios_x&t=<AES>&m=0` WebSocket 流式 |

## 三个确定的技术选型

1. **ASR**：云 ASR API（可插拔 provider：OpenAI Whisper / Deepgram / 火山）
2. **构建**：GitHub Actions macOS runner（Windows 无法编 iOS）
3. **UI**：按规格重写 RN 页面（原 bundle 是字节码，无法直接移植 JS 逻辑）

## 目录

```
app/                 React Native 主工程（本地登录、历史、设置）
ios/App/             App 外壳 + 原生桥（录音、ASR WebSocket）
ios/Keyboard/        键盘扩展（mic 按钮 → 宿主 App 录音 → 回填文本）
docs/                架构清点、原版文案表、逐屏规格
.github/workflows/   macOS 云构建 → ipa
```

## 还需要你提供

- GitHub 仓库（含 Actions 权限）或一个 PAT，用来跑 macOS 编译
- 云 ASR 的 API key（先给一家即可，接口做成可切换）
