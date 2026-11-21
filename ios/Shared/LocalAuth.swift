import Foundation
import CryptoKit
import Security

struct LocalAccount: Codable {
    var username: String
    var salt: String        // base64
    var hash: String        // base64
    var createdAt: Double
}

/// 本地账号体系（与原版唯一差异：不联网、无服务端）
enum LocalAuth {
    private static let accountsFile = "accounts.json"
    private static let sessionKeyFile = "session.json"

    private static var accountsURL: URL { Cfg.file(accountsFile) }
    private static var sessionURL: URL { Cfg.file(sessionKeyFile) }

    static func loadAccounts() -> [LocalAccount] {
        guard let d = try? Data(contentsOf: accountsURL) else { return [] }
        return (try? JSONDecoder().decode([LocalAccount].self, from: d)) ?? []
    }

    private static func saveAccounts(_ list: [LocalAccount]) {
        if let d = try? JSONEncoder().encode(list) {
            try? d.write(to: accountsURL, options: .atomic)
        }
    }

    static func derive(password: String, salt: Data) -> Data {
        var cur = Data(password.utf8) + salt
        for _ in 0..<9000 {
            cur = Data(SHA256.hash(data: cur + salt))
        }
        return cur
    }

    static func randomSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    static func register(user: String, pass: String) -> String? {
        let name = user.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.count < 2 { return "账号至少 2 个字符" }
        if pass.count < 6 { return "密码至少 6 位" }
        var list = loadAccounts()
        if list.contains(where: { $0.username.lowercased() == name.lowercased() }) {
            return "该账号已存在"
        }
        let salt = randomSalt()
        let h = derive(password: pass, salt: salt)
        list.append(LocalAccount(
            username: name,
            salt: salt.base64EncodedString(),
            hash: h.base64EncodedString(),
            createdAt: Date().timeIntervalSince1970
        ))
        saveAccounts(list)
        currentUser = name
        return nil
    }

    static func login(user: String, pass: String) -> String? {
        let name = user.trimmingCharacters(in: .whitespacesAndNewlines)
        let list = loadAccounts()
        guard let acc = list.first(where: { $0.username.lowercased() == name.lowercased() }) else {
            return "账号不存在"
        }
        guard let salt = Data(base64Encoded: acc.salt) else { return "账号数据损坏" }
        let h = derive(password: pass, salt: salt).base64EncodedString()
        if h != acc.hash { return "密码错误" }
        currentUser = acc.username
        return nil
    }

    static var currentUser: String? {
        get {
            guard let d = try? Data(contentsOf: sessionURL),
                  let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
            return obj["user"] as? String
        }
        set {
            if let u = newValue {
                if let d = try? JSONSerialization.data(withJSONObject: ["user": u]) {
                    try? d.write(to: sessionURL, options: .atomic)
                }
            } else {
                try? FileManager.default.removeItem(at: sessionURL)
            }
        }
    }

    /// 改密码
    static func changePassword(user: String, old: String, new: String) -> String? {
        var list = loadAccounts()
        guard let idx = list.firstIndex(where: { $0.username.lowercased() == user.lowercased() }) else {
            return "账号不存在"
        }
        guard let salt = Data(base64Encoded: list[idx].salt) else { return "账号数据损坏" }
        if derive(password: old, salt: salt).base64EncodedString() != list[idx].hash {
            return "原密码错误"
        }
        if new.count < 6 { return "新密码至少 6 位" }
        let ns = randomSalt()
        list[idx].salt = ns.base64EncodedString()
        list[idx].hash = derive(password: new, salt: ns).base64EncodedString()
        saveAccounts(list)
        return nil
    }
}
