import Foundation
import AVFoundation
import FlutterMacOS  // NOTE: macOS uses FlutterMacOS (not Flutter)

/**
 MicStreamPlugin (macOS)
 - Streams mono Float32 PCM frames from the default input device
   via a FlutterEventChannel.
 - Buffer size: 1024 frames @ 44.1 kHz (tweak as you like).
*/
class MicStreamPlugin: NSObject, FlutterStreamHandler {

    private var engine: AVAudioEngine?
    private var sink: FlutterEventSink?
    private let sampleRate: Double = 44100
    private let frameSize: AVAudioFrameCount = 1024

    // FlutterStreamHandler
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

        // macOS doesn’t have AVAudioSession like iOS — no category to set.
        engine = AVAudioEngine()
        guard let engine = engine else { return }

        let input = engine.inputNode
        // macOS can negotiate sample rate; request 44.1k Float32 mono
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                   sampleRate: sampleRate,
                                   channels: 1,
                                   interleaved: false)!

        input.installTap(onBus: 0, bufferSize: frameSize, format: format) { [weak self] (buffer, _) in
            guard let self = self, let sink = self.sink else { return }
            buffer.frameLength = min(buffer.frameLength, self.frameSize)

            // Extract Float32 mono channel and send as bytes
            guard let ch0 = buffer.floatChannelData?.pointee else { return }
            let count = Int(buffer.frameLength)
            let data = Data(bytes: ch0, count: count * MemoryLayout<Float>.size)
            sink(FlutterStandardTypedData(bytes: data))
        }

        do {
            try engine.start()
        } catch {
            sink?(FlutterError(code: "ENGINE_START_FAILED", message: error.localizedDescription, details: nil))
        }
    }

    private func stop() {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
    }
}
