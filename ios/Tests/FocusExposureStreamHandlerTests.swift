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
}
