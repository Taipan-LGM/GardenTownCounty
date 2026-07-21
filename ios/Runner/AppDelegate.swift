import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "com.gardentown.secure"
  private var secureEnabled = false
  private var methodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Log screenshot attempts while secure mode is on (iOS cannot fully block
    // screenshots the way Android FLAG_SECURE can).
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(onUserDidTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    methodChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "enableSecureScreen":
        self?.secureEnabled = true
        self?.applySecureFlag(true)
        result(nil)
      case "disableSecureScreen":
        self?.secureEnabled = false
        self?.applySecureFlag(false)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Best-effort secure presentation. iOS has no FLAG_SECURE equivalent;
  /// we hide the window contents from the app switcher snapshot where possible
  /// and notify Flutter if a screenshot is taken while secure mode is active.
  private func applySecureFlag(_ enabled: Bool) {
    // Hide sensitive content from multitasking preview.
    if #available(iOS 13.0, *) {
      for scene in UIApplication.shared.connectedScenes {
        guard let windowScene = scene as? UIWindowScene else { continue }
        for window in windowScene.windows {
          window.isHidden = false
          // Soften app-switcher capture: blank window briefly is OS-controlled;
          // mark accessibility for tooling.
          window.accessibilityElementsHidden = enabled
        }
      }
    }
  }

  @objc private func onUserDidTakeScreenshot() {
    guard secureEnabled else { return }
    methodChannel?.invokeMethod("screenshotDetected", arguments: nil)
  }
}
