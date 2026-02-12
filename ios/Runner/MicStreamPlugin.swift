import Foundation
import AVFoundation

class MicStreamPlugin: NSObject, FlutterStreamHandler {
    private var engine: AVAudioEngine?
    private var sink: FlutterEventSink?
    private let sampleRate: Double = 44100
    private let frameSize: AVAudioFrameCount = 1024

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        start()
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        stop()
        sink = nil
        return nil
    }

    private func start() {
        stop()
        engine = AVAudioEngine()
        guard let engine = engine else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
        try? session.setPreferredSampleRate(sampleRate)
        try? session.setActive(true)

        let input = engine.inputNode
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false)!

        input.installTap(onBus: 0, bufferSize: frameSize, format: format) { [weak self] (buffer, time) in
            guard let self = self, let sink = self.sink else { return }
            buffer.frameLength = min(buffer.frameLength, self.frameSize)
            let channelData = buffer.floatChannelData![0]
            let count = Int(buffer.frameLength)

            // Send little-endian Float32 bytes
            let data = Data(bytes: channelData, count: count * MemoryLayout<Float>.size)
            sink(FlutterStandardTypedData(bytes: data))
        }

        try? engine.start()
    }

    private func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }
}
