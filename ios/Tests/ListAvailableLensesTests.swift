import XCTest
@testable import IrisCameraPlugin

private final class StubDevice: NSObject {
  let uniqueID: String
  let localizedName: String
  let position: AVCaptureDevice.Position
  let deviceType: AVCaptureDevice.DeviceType

  init(id: String, name: String, position: AVCaptureDevice.Position, type: AVCaptureDevice.DeviceType) {
    self.uniqueID = id
    self.localizedName = name
    self.position = position
    self.deviceType = type
  }
}

extension IrisCameraPlugin {
  fileprivate func _listAvailableLenses(
    includeFront: Bool,
    devices: [StubDevice]
  ) -> [[String: Any]] {
    return devices.compactMap { device in
      if device.position == .front && !includeFront {
        return nil
      }
      return [
        "id": device.uniqueID,
        "name": device.localizedName,
        "position": positionString(from: device.position),
        "category": categoryString(from: device.deviceType, fallbackPosition: device.position),
        "supportsFocus": true,
      ]
    }
  }
}

final class ListAvailableLensesTests: XCTestCase {
  func testExcludesFrontWhenRequested() {
    let plugin = IrisCameraPlugin()
    let devices = [
      StubDevice(id: "back", name: "Back Cam", position: .back, type: .builtInWideAngleCamera),
      StubDevice(id: "front", name: "Front Cam", position: .front, type: .builtInWideAngleCamera),
    ]

    let lenses = plugin._listAvailableLenses(includeFront: false, devices: devices)
    XCTAssertEqual(lenses.count, 1)
    XCTAssertEqual(lenses.first?["id"] as? String, "back")
  }

  func testIncludesFrontByDefault() {
    let plugin = IrisCameraPlugin()
    let devices = [
      StubDevice(id: "back", name: "Back Cam", position: .back, type: .builtInWideAngleCamera),
      StubDevice(id: "front", name: "Front Cam", position: .front, type: .builtInWideAngleCamera),
    ]

    let lenses = plugin._listAvailableLenses(includeFront: true, devices: devices)
    XCTAssertEqual(lenses.count, 2)
  }
}
