import XCTest
@testable import IrisCameraPlugin

final class FocusExposureStreamHandlerTests: XCTestCase {
  func testEmitSendsStatePayload() {
    let handler = FocusExposureStreamHandler()
    var received: [String: Any]?
    _ = handler.onListen(withArguments: nil) { payload in
      received = payload as? [String: Any]
    }

    handler.emit(state: .focusLocked)

    XCTAssertEqual(received?["state"] as? String, "focusLocked")
  }

  func testEmitAllStates() {
    let handler = FocusExposureStreamHandler()
    var received: [String: Any]?
    _ = handler.onListen(withArguments: nil) { payload in
      received = payload as? [String: Any]
    }

    let cases: [(FocusExposureStateNative, String)] = [
      (.focusing, "focusing"),
      (.focusLocked, "focusLocked"),
      (.focusFailed, "focusFailed"),
      (.exposureSearching, "exposureSearching"),
      (.exposureLocked, "exposureLocked"),
      (.exposureFailed, "exposureFailed"),
      (.combinedLocked, "combinedLocked"),
      (.unknown, "unknown"),
    ]

    for (state, raw) in cases {
      handler.emit(state: state)
      XCTAssertEqual(received?["state"] as? String, raw)
    }
  }
}
