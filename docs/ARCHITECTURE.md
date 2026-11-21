# 架构清点与复刻映射

## 已核实（证据：包内 Info.plist / Frameworks / PlugIns 实读）

- 键盘扩展 `RequestsOpenAccess=true` → 具备网络与麦克风能力，这是"键盘里直接说话"的前提
- 键盘扩展有自己的 RN bundle → 说明键盘 UI 也是 RN 渲染，原生层只做 `textDocumentProxy` 插入
- 主 App 有 `UIBackgroundModes: audio` → 录音可在后台持续
- URL scheme `typeless://` → 键盘通过它唤起宿主 App 完成录音（键盘进程拿不到麦克风）

## 复刻映射表

| 原版组件 | 我们的实现 | 备注 |
|---|---|---|
| RN 主 App | RN + Hermes | 页面按规格重写 |
| keyboard.appex (RN) | 原生 Swift + 轻量 UI | 降低复杂度，视觉对齐 |
| 录音 | AVAudioEngine + AudioConverter | 16k mono PCM |
| 流式 ASR | WebSocket 客户端 → 我们的后端或云 API | 接口可切换 |
| 文本插入 | `textDocumentProxy.insertText` | 与系统键盘同权限 |
| 登录 | 本地账号密码（Keychain 存 hash） | **唯一差异点** |
| 订阅/额度 | 本地计数（可选） | 无服务端 |
| 灵动岛 | ActivityKit | 二期 |

## 与原版的差异清单（必须显式承认）

1. 识别引擎不同 → 准确率/延迟曲线不同
2. 无云端账号体系 → 换设备不迁移
3. 无原版的多语言运行时下发 → 文案内置

## 待补规格（需要你配合）

- 逐屏截图（首页/历史/设置/引导/键盘）——中文文案是运行时下发的，包里没有
