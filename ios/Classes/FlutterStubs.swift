// Stubs to allow SwiftPM tests to compile when Flutter.framework is unavailable.
#if !canImport(Flutter)
import Foundation
import UIKit

public class FlutterError: NSError {
  public let code: String
  public let message: String?
  public let details: Any?

  public init(code: String, message: String?, details: Any?) {
    self.code = code
    self.message = message
    self.details = details
    super.init(domain: "FlutterError", code: 0, userInfo: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) { fatalError() }
}

public typealias FlutterEventSink = (Any?) -> Void
public typealias FlutterResult = (Any?) -> Void

public protocol FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError?
  func onCancel(withArguments arguments: Any?) -> FlutterError?
}

public protocol FlutterPlugin {}

public protocol FlutterPluginRegistrar {
  func messenger() -> Any
}

public class FlutterMethodChannel {
  public init(name: String, binaryMessenger messenger: Any) {}
}

public class FlutterEventChannel {
  public init(name: String, binaryMessenger messenger: Any) {}
  public func setStreamHandler(_ handler: FlutterStreamHandler?) {}
}

public protocol FlutterMessageCodec {}

public class FlutterStandardMessageCodec: FlutterMessageCodec {
  public static func sharedInstance() -> FlutterStandardMessageCodec { FlutterStandardMessageCodec() }
}

public protocol FlutterPlatformViewFactory {
  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol
  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView
}

public protocol FlutterPlatformView {
  func view() -> UIView
}

public struct FlutterMethodCall {
  public let method: String
  public let arguments: Any?
}
#endif
