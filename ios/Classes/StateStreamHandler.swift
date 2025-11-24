import Flutter

/// Native representation of lifecycle states emitted to Flutter.
enum CameraLifecycleStateNative: String {
  case initialized
  case running
  case paused
  case disposed
  case error
}

/// Emits lifecycle/state updates over a Flutter event channel.
final class StateStreamHandler: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    emit(state: .disposed)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  func emit(state: CameraLifecycleStateNative, error: FlutterError? = nil) {
    guard let sink else { return }
    var payload: [String: Any] = [
      "state": state.rawValue,
    ]
    if let error {
      payload["errorCode"] = error.code
      payload["errorMessage"] = error.message ?? error.code
    }
    sink(payload)
  }
}
