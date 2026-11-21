import Foundation
import Combine

struct Dictation: Codable, Identifiable, Equatable {
    var id: String
    var text: String
    var createdAt: Double
    var seconds: Double
    var source: String     // "keyboard" / "app"
}

/// 听写记录（App Group 文件，App 与键盘共享）
final class RecordStore: ObservableObject {
    static let shared = RecordStore()

    @Published var items: [Dictation] = []

    private let fileName = "records.json"
    private var url: URL { Cfg.file(fileName) }

    init() {
        reload()
    }

    func reload() {
        guard let d = try? Data(contentsOf: url) else {
            items = []
            return
        }
        items = (try? JSONDecoder().decode([Dictation].self, from: d)) ?? []
    }

    private func persist() {
        if let d = try? JSONEncoder().encode(items) {
            try? d.write(to: url, options: .atomic)
        }
    }

    func add(text: String, seconds: Double, source: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return }
        let rec = Dictation(
            id: UUID().uuidString,
            text: t,
            createdAt: Date().timeIntervalSince1970,
            seconds: seconds,
            source: source
        )
        items.insert(rec, at: 0)
        if items.count > 500 { items = Array(items.prefix(500)) }
        persist()
    }

    func update(_ rec: Dictation) {
        if let i = items.firstIndex(where: { $0.id == rec.id }) {
            items[i] = rec
            persist()
        }
    }

    func delete(_ id: String) {
        items.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        items = []
        persist()
    }
}
