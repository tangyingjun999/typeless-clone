//
//  KeyboardViewController.swift
//  与原版一致的键盘：一个麦克风键，按住说话，松开插入文本
//  前提：Info.plist 里 RequestsOpenAccess = true（否则拿不到麦克风与网络）
//
import UIKit
import AVFoundation

final class KeyboardViewController: UIInputViewController {

    private let micButton = UIButton(type: .system)
    private let hintLabel = UILabel()
    private var recorder: AudioCapture?
    private var asr: StreamingASR?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 未授权完全访问时，与原版一致：给出引导，而不是静默失败
        if !hasFullAccess { showFullAccessGuide() }
    }

    private func setupUI() {
        let bar = UIStackView()
        bar.axis = .horizontal
        bar.alignment = .center
        bar.spacing = 10
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)

        micButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        micButton.tintColor = .white
        micButton.backgroundColor = UIColor(red: 0.10, green: 0.45, blue: 0.90, alpha: 1)
        micButton.layer.cornerRadius = 22
        micButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.widthAnchor.constraint(equalToConstant: 44).isActive = true
        micButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
        micButton.addTarget(self, action: #selector(micDown), for: .touchDown)
        micButton.addTarget(self, action: #selector(micUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])

        hintLabel.text = "按住说话"
        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textColor = .secondaryLabel

        bar.addArrangedSubview(micButton)
        bar.addArrangedSubview(hintLabel)
        bar.addArrangedSubview(UIView())

        NSLayoutConstraint.activate([
            bar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            bar.topAnchor.constraint(equalTo: view.topAnchor, constant: 6),
            bar.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func showFullAccessGuide() {
        hintLabel.text = "设置 → 通用 → 键盘 → 开启「允许完全访问」"
        hintLabel.textColor = .systemOrange
    }

    // MARK: - 录音

    @objc private func micDown() {
        guard hasFullAccess else { showFullAccessGuide(); return }
        hintLabel.text = "听写中…"
        hintLabel.textColor = .systemBlue

        let asr = StreamingASR(baseURL: AppConfig.asrBaseURL, token: AppConfig.asrToken)
        asr.onPartial = { [weak self] text in
            DispatchQueue.main.async { self?.hintLabel.text = text.isEmpty ? "听写中…" : text }
        }
        asr.onFinal = { [weak self] text in
            DispatchQueue.main.async {
                guard let self else { return }
                if !text.isEmpty { self.textDocumentProxy.insertText(text) }
                self.hintLabel.text = "按住说话"
                self.hintLabel.textColor = .secondaryLabel
            }
        }
        asr.start()

        let cap = AudioCapture()
        cap.onPCM = { data in asr.send(pcm: data) }
        try? cap.start()
        recorder = cap
        self.asr = asr
    }

    @objc private func micUp() {
        recorder?.stop(); recorder = nil
        asr?.finish()   // 等服务端给最终结果后再插入
    }

    // MARK: - 键盘尺寸

    override var needsInputModeSwitchKey: Bool { true }

    override func textWillChange(_ textInput: UITextInput?) {}
    override func textDidChange(_ textInput: UITextInput?) {}
}

enum AppConfig {
    /// 换成你自己的 ASR 网关；留空则用 OpenAI Whisper 直连
    static let asrBaseURL = "wss://your-asr-gateway.example.com/ws/stream"
    static let asrToken = ProcessInfo.processInfo.environment["ASR_TOKEN"] ?? ""
}
