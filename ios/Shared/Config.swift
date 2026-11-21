import Foundation

/// 全局配置：App 与键盘扩展共用（走 App Group）
enum Cfg {
    static let appGroup = "group.com.tlb.speech"

    static let kAsrURL = "asr.url"
    static let kAsrToken = "asr.token"
    static let kLang = "asr.lang"
    static let kFullAccess = "kb.fullAccess"
    static let kInsertCount = "kb.insertCount"
    static let kOnboarded = "app.onboarded"

    /// App Group 里的 defaults；没有 App Group 权限时退回标准 defaults（不崩，只是不同步）
    static var shared: UserDefaults {
        if let d = UserDefaults(suiteName: appGroup) { return d }
        return UserDefaults.standard
    }

    static var hasAppGroup: Bool {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) != nil
    }

    static var asrURL: String {
        get { return Cfg.shared.string(forKey: kAsrURL) ?? "" }
        set { Cfg.shared.set(newValue, forKey: kAsrURL) }
    }

    static var asrToken: String {
        get { return Cfg.shared.string(forKey: kAsrToken) ?? "" }
        set { Cfg.shared.set(newValue, forKey: kAsrToken) }
    }

    /// 语言：auto / zh-CN / en-US
    static var lang: String {
        get { return Cfg.shared.string(forKey: kLang) ?? "auto" }
        set { Cfg.shared.set(newValue, forKey: kLang) }
    }

    static var containerURL: URL {
        if let u = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) {
            return u
        }
        let u = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tlb-shared", isDirectory: true)
        try? FileManager.default.createDirectory(at: u, withIntermediateDirectories: true)
        return u
    }

    static func file(_ name: String) -> URL {
        return containerURL.appendingPathComponent(name)
    }
}

/// 小工具
enum Fmt {
    static func relative(_ ts: Double) -> String {
        let d = Date(timeIntervalSince1970: ts)
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        let cal = Calendar.current
        if cal.isDateInToday(d) {
            f.dateFormat = "HH:mm"
            return "今天 " + f.string(from: d)
        }
        if cal.isDateInYesterday(d) {
            f.dateFormat = "HH:mm"
            return "昨天 " + f.string(from: d)
        }
        f.dateFormat = "M月d日 HH:mm"
        return f.string(from: d)
    }

    static func duration(_ s: Double) -> String {
        let sec = Int(s.rounded())
        if sec < 60 { return "\(sec)\"" }
        return "\(sec / 60)'\(sec % 60)\""
    }
}
