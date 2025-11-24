import XCTest
@testable import IrisCameraPlugin

final class StateStreamHandlerLifecycleTests: XCTestCase {
  func testEmitInitialDisposedOnListen() {
    let handler = StateStreamHandler()
    var received: [String: Any]?
    _ = handler.onListen(withArguments: nil) { payload in
      received = payload as? [String: Any]
    }
    XCTAssertEqual(received?["state"] as? String, "disposed")
  }
}
