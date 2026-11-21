import SwiftUI
import AVFoundation

/// 首次引导：欢迎 → 添加键盘 → 完全访问 → 麦克风权限
struct OnboardingView: View {
    var onFinish: () -> Void

    @State private var step = 0
    @State private var micGranted = AVAudioSession.sharedInstance().recordPermission == .granted
    @State private var fullAccess = Cfg.shared.bool(forKey: Cfg.kFullAccess)

    private let total = 4

    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $step) {
                welcomePage.tag(0)
                keyboardPage.tag(1)
                accessPage.tag(2)
                micPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.28), value: step)

            dots
            bottomArea
        }
        .background(Theme.bg.ignoresSafeArea())
        .onAppear { refresh() }
    }

    private func refresh() {
        fullAccess = Cfg.shared.bool(forKey: Cfg.kFullAccess)
        micGranted = AVAudioSession.sharedInstance().recordPermission == .granted
    }

    // MARK: - 页

    private var welcomePage: some View {
        page(
            icon: "waveform.circle.fill",
            title: "按住说，松开成文",
            desc: "在任何输入框里按住空格键说话，\n松手就变成文字，说错也不用手改。",
            extra: AnyView(
                VStack(spacing: 12) {
                    bullet("keyboard", "自带键盘，全局可用")
                    bullet("bolt.fill", "边说边出字，几乎无等待")
                    bullet("lock.fill", "语音只在你的设备与网关间流转")
                }
                .padding(.top, 8)
            )
        )
    }

    private var keyboardPage: some View {
        page(
            icon: "keyboard",
            title: "添加你的键盘",
            desc: "设置 → 通用 → 键盘 → 键盘 → 添加新键盘\n→ 选择「语音听写」",
            extra: AnyView(
                VStack(spacing: 10) {
                    Button {
                        openSettings()
                    } label: {
                        Text("打开设置")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.top, 8)
            )
        )
    }

    private var accessPage: some View {
        page(
            icon: "hand.raised.fill",
            title: "开启完全访问",
            desc: "在键盘设置里点开「语音听写」，\n打开「允许完全访问」。\n\n没有这一步，键盘无法使用麦克风与网络。",
            extra: AnyView(
                VStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: fullAccess ? "checkmark.circle.fill" : "circle.dashed")
                            .foregroundColor(fullAccess ? .green : Theme.sub)
                        Text(fullAccess ? "已开启完全访问" : "尚未检测到完全访问")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.sub)
                        Spacer()
                        Button("重新检测") { refresh() }
                            .font(.system(size: 13, weight: .medium))
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))

                    Text("提示：开启后回到这里，或切一次键盘即可被检测到。")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.sub)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 8)
            )
        )
    }

    private var micPage: some View {
        page(
            icon: "mic.fill",
            title: "允许使用麦克风",
            desc: "听写需要麦克风权限。\n授权后，键盘里按住说话即可。",
            extra: AnyView(
                VStack(spacing: 10) {
                    if micGranted {
                        Label("麦克风已授权", systemImage: "checkmark.seal.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 15, weight: .medium))
                    } else {
                        Button {
                            requestMic()
                        } label: {
                            Text("允许麦克风")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                    }
                }
                .padding(.top, 8)
            )
        )
    }

    // MARK: - 组件

    private func page(icon: String, title: String, desc: String, extra: AnyView) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 20)
            Image(systemName: icon)
                .font(.system(size: 56, weight: .regular))
                .foregroundColor(Theme.accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 24)

            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)

            Text(desc)
                .font(.system(size: 15))
                .foregroundColor(Theme.sub)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 12)

            extra

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.accent)
                .frame(width: 22)
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(Theme.text)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == step ? Theme.accent : Theme.line)
                    .frame(width: i == step ? 22 : 7, height: 7)
                    .animation(.easeInOut(duration: 0.2), value: step)
            }
        }
        .padding(.vertical, 16)
    }

    private var bottomArea: some View {
        VStack(spacing: 10) {
            Button {
                if step < total - 1 {
                    withAnimation { step += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(step == total - 1 ? "开始使用" : "继续")
            }
            .buttonStyle(PrimaryButtonStyle())

            if step < total - 1 {
                Button("跳过") { onFinish() }
                    .font(.system(size: 14))
                    .foregroundColor(Theme.sub)
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 12)
    }

    private func openSettings() {
        if let u = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(u, options: [:], completionHandler: nil)
        }
    }

    private func requestMic() {
        AVAudioSession.sharedInstance().requestRecordPermission { ok in
            DispatchQueue.main.async {
                micGranted = ok
            }
        }
    }
}
