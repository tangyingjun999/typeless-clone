import SwiftUI

final class AuthState: ObservableObject {
    @Published var user: String? = LocalAuth.currentUser

    func signIn(_ u: String, _ p: String) -> String? {
        let err = LocalAuth.login(user: u, pass: p)
        if err == nil { user = LocalAuth.currentUser }
        return err
    }

    func signUp(_ u: String, _ p: String) -> String? {
        let err = LocalAuth.register(user: u, pass: p)
        if err == nil { user = LocalAuth.currentUser }
        return err
    }

    func signOut() {
        LocalAuth.currentUser = nil
        user = nil
    }
}

@main
struct TLApp: App {
    @StateObject private var auth = AuthState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(nil)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var auth: AuthState
    @State private var onboarded: Bool = Cfg.shared.bool(forKey: Cfg.kOnboarded)

    var body: some View {
        Group {
            if !onboarded {
                OnboardingView {
                    Cfg.shared.set(true, forKey: Cfg.kOnboarded)
                    withAnimation(.easeInOut(duration: 0.25)) { onboarded = true }
                }
            } else if auth.user == nil {
                AuthView()
            } else {
                MainView()
            }
        }
    }
}

struct MainView: View {
    @EnvironmentObject var auth: AuthState
    @State private var tab: Int = 0

    var body: some View {
        TabView(selection: $tab) {
            HistoryView()
                .tabItem {
                    Image(systemName: "waveform")
                    Text("记录")
                }
                .tag(0)

            SettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("设置")
                }
                .tag(1)
        }
        .tint(Theme.accent)
    }
}
