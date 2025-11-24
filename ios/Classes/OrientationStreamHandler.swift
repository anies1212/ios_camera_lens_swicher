import Flutter
import UIKit
import AVFoundation

/// Emits device/video orientation changes over a Flutter event channel.
final class OrientationStreamHandler: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private var observer: NSObjectProtocol?

  override init() {
    super.init()
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    emitCurrentOrientation()
    observer = NotificationCenter.default.addObserver(
      forName: UIDevice.orientationDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.emitCurrentOrientation()
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer {
      NotificationCenter.default.removeObserver(observer)
    }
    observer = nil
    sink = nil
    return nil
  }

  private func emitCurrentOrientation() {
    guard let sink else { return }
    let deviceOrientation = UIDevice.current.orientation
    let videoOrientation = mapVideoOrientation(from: deviceOrientation)
    sink([
      "deviceOrientation": deviceOrientationString(deviceOrientation),
      "videoOrientation": videoOrientationString(videoOrientation),
    ])
  }

  private func mapVideoOrientation(from device: UIDeviceOrientation) -> AVCaptureVideoOrientation {
    switch device {
    case .landscapeLeft:
      return .landscapeRight
    case .landscapeRight:
      return .landscapeLeft
    case .portraitUpsideDown:
      return .portraitUpsideDown
    case .portrait:
      fallthrough
    default:
      return .portrait
    }
  }

  private func deviceOrientationString(_ orientation: UIDeviceOrientation) -> String {
    switch orientation {
    case .portrait:
      return "portraitUp"
    case .portraitUpsideDown:
      return "portraitDown"
    case .landscapeLeft:
      return "landscapeLeft"
    case .landscapeRight:
      return "landscapeRight"
    default:
      return "unknown"
    }
  }

  private func videoOrientationString(_ orientation: AVCaptureVideoOrientation) -> String {
    switch orientation {
    case .portrait:
      return "portrait"
    case .portraitUpsideDown:
      return "portraitUpsideDown"
    case .landscapeLeft:
      return "landscapeLeft"
    case .landscapeRight:
      return "landscapeRight"
    @unknown default:
      return "unknown"
    }
  }
}
