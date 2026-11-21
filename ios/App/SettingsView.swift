import SwiftUI
import AVFoundation
import UIKit

struct SettingsView: View {
    @EnvironmentObject var auth: AuthState
    @ObservedObject private var store = RecordStore.shared

    @State private var asrURL: String = Cfg.asrURL
    @State private var asrToken: String = Cfg.asrToken
    @State private var lang: String = Cfg.lang
    @State private var showReplay = false
    @State private var savedTip: String? = nil

    private let langs = [("auto", "自动识别"), ("zh-CN", "中文"), ("en-US", "English")]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: Cfg.shared.bool(forKey: Cfg.kFullAccess) ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(Cfg.shared.bool(forKey: Cfg.kFullAccess) ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(Cfg.shared.bool(forKey: Cfg.kFullAccess) ? "键盘已就绪" : "键盘未开启完全访问")
                                .font(.system(size: 15, weight: .medium))
                            Text(Cfg.shared.bool(forKey: Cfg.kFullAccess)
                                 ? "在任意输入框切换到「语音听写」即可使用"
                                 : "设置 → 通用 → 键盘 → 语音听写 → 允许完全访问")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.sub)
                        }
                    }
                    Button {
                        if let u = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(u, options: [:], completionHandler: nil)
                        }
                    } label: {
                        Label("打开系统设置", systemImage: "arrow.up.forward.app")
                    }
                } header: {
                    Text("键盘")
                }

                Section {
                    TextField("wss://asr.example.com/ws/stream", text: $asrURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    SecureField("网关口令（可选）", text: $asrToken)

                    Picker("识别语言", selection: $lang) {
                        ForEach(langs, id: \.0) { item in
                            Text(item.1).tag(item.0)
                        }
                    }

                    Button {
                        Cfg.asrURL = asrURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        Cfg.asrToken = asrToken.trimmingCharacters(in: .whitespacesAndNewlines)
                        Cfg.lang = lang
                        Cfg.shared.synchronize()
                        withAnimation { savedTip = "已保存" }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            withAnimation { savedTip = nil }
                        }
                    } label: {
                        HStack {
                            Text("保存")
                            Spacer()
                            if let t = savedTip {
                                Text(t).foregroundColor(.green).font(.system(size: 13))
                            }
                        }
                    }
                } header: {
                    Text("语音识别")
                } footer: {
                    Text("地址必须是 ws:// 或 wss:// 开头，指向你自己的 ASR 网关。中文识别建议语言选「中文」。")
                }

                Section {
                    HStack {
                        Text("账号")
                        Spacer()
                        Text(auth.user ?? "-").foregroundColor(Theme.sub)
                    }
                    HStack {
                        Text("记录条数")
                        Spacer()
                        Text("\(store.items.count)").foregroundColor(Theme.sub)
                    }
                } header: {
                    Text("账号")
                }

                Section {
                    Button {
                        showReplay = true
                    } label: {
                        Text("重看引导")
                    }
                    Button(role: .destructive) {
                        auth.signOut()
                    } label: {
                        Text("退出登录")
                    }
                } header: {
                    Text("其他")
                } footer: {
                    Text("版本 1.0.0 · 本地账号，无云端同步")
                }
            }
            .navigationTitle("设置")
            .sheet(isPresented: $showReplay) {
                OnboardingView {
                    showReplay = false
                }
            }
            .onAppear {
                asrURL = Cfg.asrURL
                asrToken = Cfg.asrToken
                lang = Cfg.lang
                store.reload()
            }
        }
    }
}
