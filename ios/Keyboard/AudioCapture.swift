//
//  16kHz / 16-bit / 单声道 PCM 采集，供流式 ASR 使用
//
import AVFoundation

final class AudioCapture {
    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let target = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                       sampleRate: 16_000, channels: 1, interleaved: true)!
    var onPCM: ((Data) -> Void)?

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true)

        let input = engine.inputNode
        let inFormat = input.inputFormat(forBus: 0)
        converter = AVAudioConverter(from: inFormat, to: target)

        input.installTap(onBus: 0, bufferSize: 1024, format: inFormat) { [weak self] buf, _ in
            guard let self, let conv = self.converter else { return }
            let ratio = self.target.sampleRate / inFormat.sampleRate
            let cap = AVAudioFrameCount(Double(buf.frameLength) * ratio) + 16
            guard let out = AVAudioPCMBuffer(pcmFormat: self.target, frameCapacity: cap) else { return }
            var err: NSError?
            var done = false
            conv.convert(to: out, error: &err) { _, status in
                if done { status.pointee = .noDataNow; return nil }
                done = true; status.pointee = .haveData; return buf
            }
            if err == nil, let ch = out.int16ChannelData {
                let n = Int(out.frameLength) * 2
                self.onPCM?(Data(bytes: ch[0], count: n))
            }
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
