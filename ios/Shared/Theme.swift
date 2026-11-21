import SwiftUI

/// 视觉基调：跟随系统明暗，主色偏蓝（与原版接近）
enum Theme {
    static let bg = Color(UIColor.systemBackground)
    static let card = Color(UIColor.secondarySystemBackground)
    static let text = Color(UIColor.label)
    static let sub = Color(UIColor.secondaryLabel)
    static let line = Color(UIColor.separator)
    static let accent = Color(red: 0.16, green: 0.42, blue: 1.0)
    static let danger = Color(UIColor.systemRed)
    static let radius: CGFloat = 18.0
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1.0
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(enabled ? Theme.accent : Theme.accent.opacity(0.35))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}
