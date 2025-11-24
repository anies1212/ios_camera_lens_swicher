import XCTest
@testable import IrisCameraPlugin

final class StateStreamHandlerTests: XCTestCase {
  func testEmitStatePayload() {
    let handler = StateStreamHandler()
    var received: [String: Any]?
    _ = handler.onListen(withArguments: nil) { payload in
      received = payload as? [String: Any]
    }

    handler.emit(state: .running)

    XCTAssertEqual(received?["state"] as? String, "running")
  }

  func testEmitStateWithErrorPayload() {
    let handler = StateStreamHandler()
    var received: [String: Any]?
    _ = handler.onListen(withArguments: nil) { payload in
      received = payload as? [String: Any]
    }

    let error = FlutterError(code: "sample", message: "msg", details: nil)
    handler.emit(state: .error, error: error)

    XCTAssertEqual(received?["state"] as? String, "error")
    XCTAssertEqual(received?["errorCode"] as? String, "sample")
    XCTAssertEqual(received?["errorMessage"] as? String, "msg")
  }
}
