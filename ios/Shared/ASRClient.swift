import Foundation

/// 流式 ASR 客户端
/// 协议（与 server/asr_gateway.py 一致）
///   C→S  二进制: PCM16LE / 16k / mono
///   C→S  文本:  {"type":"finish"}
///   S→C  文本:  {"type":"partial","text":"..."} / {"type":"final","text":"..."}
final class ASRClient: NSObject {

    private let url: URL
    private let token: String
    private var task: URLSessionWebSocketTask?
    private var session: URLSession!
    private var closed = false
    private var gotFinal = false

    var onPartial: ((String) -> Void)?
    var onFinal: ((String) -> Void)?
    var onError: ((String) -> Void)?

    init(urlString: String, token: String) {
        self.url = URL(string: urlString) ?? URL(string: "ws://127.0.0.1:9/none")!
        self.token = token
        super.init()
        self.session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)
    }

    static func isUsable(_ s: String) -> Bool {
        guard let u = URL(string: s) else { return false }
        return u.scheme == "ws" || u.scheme == "wss"
    }

    func start() {
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        if !token.isEmpty {
            req.addValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        }
        let t = session.webSocketTask(with: req)
        task = t
        t.resume()
        listen()
    }

    func send(pcm: Data) {
        guard !closed else { return }
        task?.send(.data(pcm)) { _ in }
    }

    func finish() {
        guard !closed else { return }
        task?.send(.string("{\"type\":\"finish\"}")) { _ in }

        // 兜底：服务端 5 秒没有 final 就自己收尾，绝不能把键盘卡住
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            guard let self else { return }
            if !self.gotFinal {
                self.gotFinal = true
                self.onFinal?("")
            }
            self.close()
        }
    }

    func cancel() {
        close()
    }

    private func listen() {
        guard let task else { return }
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let err):
                if !self.closed {
                    self.onError?(err.localizedDescription)
                }
                self.close()
            case .success(let msg):
                if case .string(let s) = msg,
                   let d = s.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                    let text = obj["text"] as? String ?? ""
                    let type = obj["type"] as? String ?? ""
                    if type == "partial" {
                        self.onPartial?(text)
                    } else if type == "final" {
                        self.gotFinal = true
                        self.onFinal?(text)
                        self.close()
                        return
                    }
                }
                self.listen()
            }
        }
    }

    private func close() {
        closed = true
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
    }
}
