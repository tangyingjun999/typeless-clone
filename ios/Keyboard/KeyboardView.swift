import SwiftUI
import UIKit
import AVFoundation

// MARK: - 状态

final class KeyboardModel: ObservableObject {
    @Published var partial: String = ""
    @Published var state: Int = 0          // 0 空闲 / 1 录音中 / 2 识别中
    @Published var shift: Bool = false
    @Published var numbers: Bool = false
    @Published var level: CGFloat = 0
    @Published var hint: String = ""
    @Published var needsFullAccess: Bool = false

    var insert: ((String) -> Void)?
    var del: (() -> Void)?
    var nextKb: (() -> Void)?
    var dismiss: (() -> Void)?

    private(set) var lastSeconds: Double = 0

    private var cap: AudioCapture?
    private var asr: ASRClient?
    private var cfgURL = ""
    private var cfgToken = ""
    private var beganAt: Date?
    private var micDenied = false

    init() {
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] ok in
            DispatchQueue.main.async { self?.micDenied = !ok }
        }
    }

    func refreshConfig() {
        cfgURL = Cfg.asrURL
        cfgToken = Cfg.asrToken
    }

    // 普通按键
    func key(_ s: String) {
        insert?(s)
        if shift { shift = false }
    }

    // MARK: - 录音

    func startRecording() {
        if needsFullAccess { hint = "请先开启完全访问"; return }
        if micDenied { hint = "麦克风未授权"; return }
        if state != 0 { return }
        refreshConfig()
        if !ASRClient.isUsable(cfgURL) {
            hint = "请先在 App 里填识别网关"
            return
        }

        let asr = ASRClient(urlString: cfgURL, token: cfgToken)
        asr.onPartial = { [weak self] t in
            DispatchQueue.main.async { self?.partial = t }
        }
        asr.onFinal = { [weak self] t in
            DispatchQueue.main.async { self?.finish(t) }
        }
        asr.onError = { [weak self] _ in
            DispatchQueue.main.async { self?.fail("连接失败，检查网关") }
        }
        asr.start()

        let cap = AudioCapture()
        cap.onPCM = { [weak asr] d in asr?.send(pcm: d) }
        cap.onLevel = { [weak self] l in
            DispatchQueue.main.async { self?.level = CGFloat(l) }
        }
        do {
            try cap.start()
        } catch {
            asr.cancel()
            hint = "录音启动失败"
            return
        }

        self.cap = cap
        self.asr = asr
        beganAt = Date()
        partial = ""
        hint = ""
        state = 1
    }

    /// 松手：短按当空格，长按结束录音
    func endHold() {
        guard state == 1 else { return }
        let elapsed = beganAt.map { Date().timeIntervalSince($0) } ?? 0

        if elapsed < 0.28 {
            cap?.stop()
            cap = nil
            asr?.cancel()
            asr = nil
            state = 0
            beganAt = nil
            insert?(" ")
            return
        }

        lastSeconds = elapsed
        cap?.stop()
        cap = nil
        state = 2
        asr?.finish()
    }

    private func finish(_ text: String) {
        asr?.cancel()
        asr = nil
        beganAt = nil
        state = 0
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty {
            partial = ""
            hint = lastSeconds < 0.5 ? "按住说话" : "没听清，再说一次"
            return
        }
        insert?(t)
        partial = ""
        hint = ""
    }

    private func fail(_ msg: String) {
        cap?.stop()
        cap = nil
        asr?.cancel()
        asr = nil
        beganAt = nil
        state = 0
        partial = ""
        hint = msg
    }
}

// MARK: - 键盘 UI

struct KeyboardView: View {
    @ObservedObject var model: KeyboardModel
    @State private var holding = false

    init(model: KeyboardModel) {
        _model = ObservedObject(wrappedValue: model)
    }

    private let row1 = ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]
    private let row2 = ["a", "s", "d", "f", "g", "h", "j", "k", "l"]
    private let row3 = ["z", "x", "c", "v", "b", "n", "m"]
    private let num1 = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]
    private let num2 = ["-", "/", ":", ";", "(", ")", "¥", "&", "@", "\""]
    private let num3 = [".", ",", "?", "!", "'", "#", "%", "*", "+", "="]

    private var boardColor: Color { Color(UIColor.systemGray5) }
    private var keyColor: Color { Color(UIColor.systemBackground) }
    private var labelColor: Color { Color(UIColor.label) }

    var body: some View {
        VStack(spacing: 7) {
            statusRow

            if model.numbers {
                simpleRow(num1)
                simpleRow(num2)
                HStack(spacing: 5) {
                    iconKey("textformat.abc", w: 46) {
                        model.numbers = false
                    }
                    ForEach(num3, id: \.self) { k in
                        KeyCap(text: k, bg: keyColor, fg: labelColor) { model.key(k) }
                    }
                    iconKey("delete.left", w: 46) { model.del?() }
                }
            } else {
                simpleRow(row1)
                HStack(spacing: 5) {
                    Color.clear.frame(width: 6)
                    ForEach(row2, id: \.self) { k in
                        KeyCap(text: model.shift ? k.uppercased() : k, bg: keyColor, fg: labelColor) {
                            model.key(model.shift ? k.uppercased() : k)
                        }
                    }
                    Color.clear.frame(width: 6)
                }
                .padding(.horizontal, 12)

                HStack(spacing: 5) {
                    iconKey(model.shift ? "shift.fill" : "shift",
                            w: 44,
                            bg: model.shift ? keyColor : Color(UIColor.systemGray4)) {
                        model.shift.toggle()
                    }
                    ForEach(row3, id: \.self) { k in
                        KeyCap(text: model.shift ? k.uppercased() : k, bg: keyColor, fg: labelColor) {
                            model.key(model.shift ? k.uppercased() : k)
                        }
                    }
                    iconKey("delete.left", w: 44) { model.del?() }
                }
            }

            bottomRow
        }
        .padding(.horizontal, 3)
        .padding(.top, 5)
        .padding(.bottom, 3)
        .background(boardColor.ignoresSafeArea())
    }

    // MARK: 状态条

    private var statusRow: some View {
        HStack(spacing: 8) {
            if model.state == 1 {
                levelBars
            }

            Text(statusText)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(model.state == 1 ? Color(UIColor.label) : Color(UIColor.secondaryLabel))
                .lineLimit(1)
                .truncationMode(.head)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    private var statusText: String {
        if model.needsFullAccess { return "请开启「允许完全访问」后使用" }
        if !model.partial.isEmpty { return model.partial }
        if !model.hint.isEmpty { return model.hint }
        if model.state == 1 { return "松手结束" }
        if model.state == 2 { return "识别中…" }
        return "按住空格键说话"
    }

    private var levelBars: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: 3, height: barHeight(i))
            }
        }
    }

    private func barHeight(_ i: Int) -> CGFloat {
        let base = 4.0 + model.level * 16.0
        let wobble = CGFloat([1.0, 0.6, 0.85, 0.5, 0.9][i])
        return max(4, base * wobble)
    }

    // MARK: 行

    private func simpleRow(_ keys: [String]) -> some View {
        HStack(spacing: 5) {
            ForEach(keys, id: \.self) { k in
                KeyCap(text: k, bg: keyColor, fg: labelColor) { model.key(k) }
            }
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 5) {
            iconKey("123", w: 44, fontSize: 14) {
                model.numbers.toggle()
            }

            iconKey("globe", w: 44) {
                model.nextKb?()
            }

            micKey

            Button {
                model.insert?("\n")
            } label: {
                Image(systemName: "return")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color(UIColor.label))
                    .frame(width: 62, height: 42)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color(UIColor.systemGray4)))
            }
            .buttonStyle(.plain)
        }
    }

    private var micKey: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(model.state == 1 ? Theme.accent : keyColor)

            HStack(spacing: 6) {
                Image(systemName: model.state == 1 ? "waveform" : "mic.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(model.state == 2 ? "识别中" : (model.state == 1 ? "松手结束" : "按住说话"))
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(model.state == 1 ? .white : Color(UIColor.label))
        }
        .frame(height: 42)
        .frame(maxWidth: .infinity)
        .shadow(color: Color.black.opacity(0.16), radius: 0, x: 0, y: 1)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !holding {
                        holding = true
                        model.startRecording()
                    }
                }
                .onEnded { _ in
                    if holding {
                        holding = false
                        model.endHold()
                    }
                }
        )
    }

    private func iconKey(_ symbol: String,
                         w: CGFloat,
                         bg: Color? = nil,
                         fontSize: CGFloat = 16,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if symbol == "123" {
                    Text("123").font(.system(size: fontSize, weight: .medium))
                } else {
                    Image(systemName: symbol).font(.system(size: fontSize, weight: .medium))
                }
            }
            .foregroundColor(Color(UIColor.label))
            .frame(width: w, height: 42)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(bg ?? Color(UIColor.systemGray4)))
        }
        .buttonStyle(.plain)
    }
}

/// 单个字母键
struct KeyCap: View {
    var text: String
    var bg: Color
    var fg: Color
    var action: () -> Void
    @State private var pressed = false

    init(text: String, bg: Color, fg: Color, action: @escaping () -> Void) {
        self.text = text
        self.bg = bg
        self.fg = fg
        self.action = action
    }

    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .regular))
            .foregroundColor(fg)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(bg))
            .shadow(color: Color.black.opacity(0.16), radius: 0, x: 0, y: 1)
            .opacity(pressed ? 0.55 : 1.0)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in pressed = true }
                    .onEnded { _ in
                        pressed = false
                        action()
                    }
            )
    }
}
