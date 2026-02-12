import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterEventChannel(name: "com.example.mic_stream/audio", binaryMessenger: controller.binaryMessenger)
    let handler = MicStreamPlugin()
    channel.setStreamHandler(handler)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
