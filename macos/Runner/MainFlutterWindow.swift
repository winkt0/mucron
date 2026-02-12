import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    let channel = FlutterEventChannel(name: "com.example.mic_stream/audio", binaryMessenger: flutterViewController.engine.binaryMessenger)
    let handler = MicStreamPlugin()
    channel.setStreamHandler(handler)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
