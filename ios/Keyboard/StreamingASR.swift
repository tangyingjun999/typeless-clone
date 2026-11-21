//
//  流式 ASR 客户端：把 PCM 分片推上去，拿 partial / final
//  协议（与自建网关约定，可按云厂商适配）：
//    C→S: binary 帧 = PCM16LE 16k mono
//    S→C: {"type":"partial","text":"..."} / {"type":"final","text":"..."}
//
import Foundation

final class StreamingASR: NSObject, URLSessionWebSocketDelegate {
    private let url: URL
    private let token: String
    private var task: URLSessionWebSocketTask?
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    private var finished = false

    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?

    init(baseURL: String, token: String) {
        self.url = URL(string: baseURL) ?? URL(string: "wss://example.com")!
        self.token = token
        super.init()
    }

    func start() {
        var req = URLRequest(url: url)
        req.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let t = session.webSocketTask(with: req)
        task = t
        t.resume()
        listen()
    }

    func send(pcm: Data) {
        task?.send(.data(pcm)) { _ in }
    }

    func finish() {
        guard !finished else { return }
        finished = true
        task?.send(.string("{\"type\":\"finish\"}")) { _ in }
        // 3 秒兜底：无论服务端是否回 final，都不要卡住键盘
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.closeIfNeeded()
        }
    }

    private func listen() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                self.closeIfNeeded()
            case .success(let msg):
                if case .string(let s) = msg,
                   let data = s.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    let text = obj["text"] as? String ?? ""
                    switch obj["type"] as? String {
                    case "partial": self.onPartial?(text)
                    case "final":
                        self.onFinal?(text)
                        self.closeIfNeeded()
                        return
                    default: break
                    }
                }
                self.listen()
            }
        }
    }

    private func closeIfNeeded() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }
}
