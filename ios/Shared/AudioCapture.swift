import Foundation
import AVFoundation

/// 16kHz / 16bit / 单声道 PCM 采集（键盘扩展内直接录，依赖 RequestsOpenAccess）
final class AudioCapture {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let target = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                       sampleRate: 16000,
                                       channels: 1,
                                       interleaved: true)

    var onPCM: ((Data) -> Void)?
    var onLevel: ((Float) -> Void)?
    private(set) var isRunning = false
    private(set) var startedAt = Date()

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true, options: [])

        let input = engine.inputNode
        let inFormat = input.inputFormat(forBus: 0)
        guard let tgt = target, let conv = AVAudioConverter(from: inFormat, to: tgt) else {
            throw NSError(domain: "tlb.audio", code: 1)
        }
        converter = conv
        startedAt = Date()

        input.installTap(onBus: 0, bufferSize: 1024, format: inFormat) { [weak self] buf, _ in
            guard let self, let conv = self.converter, let tgt = self.target else { return }

            // 音量（0~1）用于波形
            var level: Float = 0
            if let ch = buf.floatChannelData?[0] {
                var sum: Float = 0
                let n = Int(buf.frameLength)
                var i = 0
                while i < n { sum += ch[i] * ch[i]; i += 1 }
                if n > 0 { level = min(1.0, sqrt(sum / Float(n)) * 8.0) }
            }
            self.onLevel?(level)

            let ratio = tgt.sampleRate / inFormat.sampleRate
            let cap = AVAudioFrameCount(Double(buf.frameLength) * ratio) + 32
            guard let out = AVAudioPCMBuffer(pcmFormat: tgt, frameCapacity: cap) else { return }

            var err: NSError?
            var consumed = false
            conv.convert(to: out, error: &err) { _, status in
                if consumed {
                    status.pointee = .noDataNow
                    return nil
                }
                consumed = true
                status.pointee = .haveData
                return buf
            }
            if err == nil, out.frameLength > 0, let ch = out.int16ChannelData {
                let n = Int(out.frameLength) * 2
                self.onPCM?(Data(bytes: ch[0], count: n))
            }
        }

        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        if isRunning {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    var elapsed: Double { Date().timeIntervalSince(startedAt) }
}
