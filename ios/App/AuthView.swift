import SwiftUI

struct AuthView: View {
    @EnvironmentObject var auth: AuthState

    @State private var mode: Int = 0          // 0 登录 / 1 注册
    @State private var user: String = ""
    @State private var pass: String = ""
    @State private var pass2: String = ""
    @State private var error: String? = nil
    @State private var busy = false
    @FocusState private var focus: Int?

    private var canSubmit: Bool {
        !user.trimmingCharacters(in: .whitespaces).isEmpty && pass.count >= 1 && !busy
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 40)

                Image(systemName: "waveform")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundColor(Theme.accent)

                Text(mode == 0 ? "欢迎回来" : "创建账号")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundColor(Theme.text)
                    .padding(.top, 16)

                Text(mode == 0 ? "账号保存在本机，不需要联网。" : "账号只存在这台设备上，卸载会一并删除。")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.sub)
                    .padding(.top, 8)

                VStack(spacing: 12) {
                    field(icon: "person", placeholder: "账号", text: $user, secure: false, idx: 0)
                    field(icon: "lock", placeholder: "密码（至少 6 位）", text: $pass, secure: true, idx: 1)
                    if mode == 1 {
                        field(icon: "lock.rotation", placeholder: "再输一次密码", text: $pass2, secure: true, idx: 2)
                    }
                }
                .padding(.top, 28)

                if let e = error {
                    Label(e, systemImage: "exclamationmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.danger)
                        .padding(.top, 12)
                }

                Button {
                    submit()
                } label: {
                    if busy {
                        ProgressView().tint(.white)
                    } else {
                        Text(mode == 0 ? "登录" : "创建并登录")
                    }
                }
                .buttonStyle(PrimaryButtonStyle(enabled: canSubmit))
                .disabled(!canSubmit)
                .padding(.top, 24)

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        mode = mode == 0 ? 1 : 0
                        error = nil
                    }
                } label: {
                    Text(mode == 0 ? "还没有账号？创建一个" : "已有账号？去登录")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.accent)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 18)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 28)
        }
        .background(Theme.bg.ignoresSafeArea())
        .onTapGesture { focus = nil }
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, secure: Bool, idx: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(Theme.sub)
                .frame(width: 20)

            if secure {
                SecureField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .focused($focus, equals: idx)
                    .font(.system(size: 16))
            } else {
                TextField(placeholder, text: text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .focused($focus, equals: idx)
                    .font(.system(size: 16))
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Theme.card)
        )
    }

    private func submit() {
        error = nil
        if mode == 1 && pass != pass2 {
            error = "两次输入的密码不一致"
            return
        }
        busy = true
        focus = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let err = mode == 0 ? auth.signIn(user, pass) : auth.signUp(user, pass)
            busy = false
            error = err
        }
    }
}
