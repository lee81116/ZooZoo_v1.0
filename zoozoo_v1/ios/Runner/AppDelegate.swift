import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(
        AVAudioSession.Category.playback,
        mode: AVAudioSession.Mode.voicePrompt,
        options:[
          AVAudioSession.CategoryOptions.allowBluetooth,
          AVAudioSession.CategoryOptions.allowBluetoothA2DP,
          AVAudioSession.CategoryOptions.mixWithOthers,
          AVAudioSession.CategoryOptions.duckOthers
        ]
      )
    } catch {
      print("Setting category to AVAudioSessionCategoryPlayback failed.")
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
