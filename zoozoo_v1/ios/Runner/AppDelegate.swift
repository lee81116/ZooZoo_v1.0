import Flutter
import UIKit
import AVFoundation // 1. 必須引入這個庫來處理音訊

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 2. 在註冊插件之前，先設定音訊會話類別
    let audioSession = AVAudioSession.sharedInstance()
    do {
      // .playAndRecord 允許播放與錄音
      // .defaultToSpeaker 確保聲音從擴音器出來（否則可能只會從聽筒出來）
      try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
      try audioSession.setActive(true)
    } catch {
      print("Failed to set audio session category: \(error)")
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
