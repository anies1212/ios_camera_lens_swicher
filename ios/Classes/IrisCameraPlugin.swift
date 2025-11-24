import AVFoundation
import Flutter
import UIKit

public class IrisCameraPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, AVCaptureVideoDataOutputSampleBufferDelegate {
  private static let channelName = "iris_camera"
  private static let imageStreamChannelName = "iris_camera/imageStream"
  private static let orientationChannelName = "iris_camera/orientation"
  private static let stateChannelName = "iris_camera/state"
  private static let focusExposureChannelName = "iris_camera/focusExposureState"

  private let sessionQueue = DispatchQueue(label: "iris_camera.session")
  private let captureSession = AVCaptureSession()
  private let photoOutput = AVCapturePhotoOutput()
  private let videoOutputQueue = DispatchQueue(label: "iris_camera.videoOutput")
  private let videoDataOutput = AVCaptureVideoDataOutput()
  private var currentInput: AVCaptureDeviceInput?
  private var selectedLensID: String?
  private var pendingPhotoCapture: PhotoCaptureDelegate?
  private var currentSessionPreset: AVCaptureSession.Preset = .high
  private var imageStreamSink: FlutterEventSink?
  private var isStreaming = false
  private let orientationStreamHandler = OrientationStreamHandler()
  private let stateStreamHandler = StateStreamHandler()
  private let focusExposureStreamHandler = FocusExposureStreamHandler()
  private var isInitialized = false
  private var isPaused = false

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    let instance = IrisCameraPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    let previewFactory = CameraPreviewFactory(sessionProvider: { instance.captureSession })
    registrar.register(previewFactory, withId: "\(channelName)/preview")

    let streamChannel = FlutterEventChannel(
      name: imageStreamChannelName,
      binaryMessenger: registrar.messenger()
    )
    streamChannel.setStreamHandler(instance)

    let orientationChannel = FlutterEventChannel(
      name: orientationChannelName,
      binaryMessenger: registrar.messenger()
    )
    orientationChannel.setStreamHandler(instance.orientationStreamHandler)

    let stateChannel = FlutterEventChannel(
      name: stateChannelName,
      binaryMessenger: registrar.messenger()
    )
    stateChannel.setStreamHandler(instance.stateStreamHandler)

    let focusExposureChannel = FlutterEventChannel(
      name: focusExposureChannelName,
      binaryMessenger: registrar.messenger()
    )
    focusExposureChannel.setStreamHandler(instance.focusExposureStreamHandler)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getPlatformVersion":
      result("iOS " + UIDevice.current.systemVersion)
    case "listAvailableLenses":
      result(listAvailableLenses(arguments: call.arguments))
    case "switchLens":
      switchLens(arguments: call.arguments, result: result)
    case "takePhoto":
      takePhoto(arguments: call.arguments, result: result)
    case "setFocus":
      setFocus(arguments: call.arguments, result: result)
    case "setZoom":
      setZoom(arguments: call.arguments, result: result)
    case "setWhiteBalance":
      setWhiteBalance(arguments: call.arguments, result: result)
    case "setExposureMode":
      setExposureMode(arguments: call.arguments, result: result)
    case "getExposureMode":
      getExposureMode(result: result)
    case "setExposurePoint":
      setExposurePoint(arguments: call.arguments, result: result)
    case "getMinExposureOffset":
      getExposureOffset(isMin: true, result: result)
    case "getMaxExposureOffset":
      getExposureOffset(isMin: false, result: result)
    case "setExposureOffset":
      setExposureOffset(arguments: call.arguments, result: result)
    case "getExposureOffset":
      getCurrentExposureOffset(result: result)
    case "getExposureOffsetStepSize":
      getExposureOffsetStepSize(result: result)
    case "startImageStream":
      startImageStream(result: result)
    case "stopImageStream":
      stopImageStream(result: result)
    case "setTorch":
      setTorch(arguments: call.arguments, result: result)
    case "setFocusMode":
      setFocusMode(arguments: call.arguments, result: result)
    case "getFocusMode":
      getFocusMode(result: result)
    case "setFrameRateRange":
      setFrameRateRange(arguments: call.arguments, result: result)
    case "setResolutionPreset":
      setResolutionPreset(arguments: call.arguments, result: result)
    case "initialize":
      initializeSession(result: result)
    case "pauseSession":
      pauseSession(result: result)
    case "resumeSession":
      resumeSession(result: result)
    case "disposeSession":
      disposeSession(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Lens management

  private func switchLens(arguments: Any?, result: @escaping FlutterResult) {
    guard let args = arguments as? [String: Any], let categoryName = args["category"] as? String else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "Expected { category: <String> } for switchLens.",
        details: nil
      ))
      return
    }

    ensureAuthorization { [weak self] authorizationResult in
      guard let self = self else { return }
      switch authorizationResult {
      case .failure(let error):
        let flutterError = error.flutterError
        DispatchQueue.main.async {
          self.emitState(.error, error: flutterError)
          result(flutterError)
        }
      case .success:
        self.sessionQueue.async {
          let outcome: Result<[String: Any], CameraSwitchError>
          do {
            let descriptor = try self.configureSessionAndSwitch(categoryName: categoryName)
            self.startSessionIfNeeded()
            outcome = .success(descriptor)
          } catch let error as CameraSwitchError {
            outcome = .failure(error)
          } catch {
            outcome = .failure(.configurationFailed(message: error.localizedDescription))
          }

          DispatchQueue.main.async {
            switch outcome {
            case .success(let descriptor):
              result(descriptor)
            case .failure(let error):
              result(error.flutterError)
            }
          }
        }
      }
    }
  }

  private func configureSessionAndSwitch(categoryName: String) throws -> [String: Any] {
    guard let device = device(matchingCategory: categoryName) else {
      throw CameraSwitchError.lensNotFound(category: categoryName)
    }

    let newInput: AVCaptureDeviceInput
    do {
      newInput = try AVCaptureDeviceInput(device: device)
    } catch let error as NSError {
      if error.domain == AVFoundationErrorDomain,
         error.code == AVError.applicationIsNotAuthorizedToUseDevice.rawValue {
        throw CameraSwitchError.notAuthorized
      }
      throw CameraSwitchError.configurationFailed(message: error.localizedDescription)
    }

    if let currentDevice = currentInput?.device,
       categoryString(from: currentDevice.deviceType, fallbackPosition: currentDevice.position) == categoryName {
      return descriptorDictionary(for: currentDevice)
    }

    captureSession.beginConfiguration()
    defer {
      captureSession.commitConfiguration()
    }

    if let currentInput {
      captureSession.removeInput(currentInput)
    }

    guard captureSession.canAddInput(newInput) else {
      if let currentInput {
        captureSession.addInput(currentInput)
      }
      throw CameraSwitchError.configurationFailed(message: "Cannot attach \(device.localizedName) to capture session.")
    }

    captureSession.addInput(newInput)
    currentInput = newInput
    selectedLensID = device.uniqueID
    ensurePhotoOutputAttached()
    applySessionPresetIfNeeded()

    return descriptorDictionary(for: device)
  }

  fileprivate func listAvailableLenses(arguments: Any?) -> [[String: Any]] {
    let payload = arguments as? [String: Any]
    let includeFront = payload?["includeFront"] as? Bool ?? true
    return devices().compactMap { device in
      if device.position == .front && !includeFront {
        return nil
      }
      return descriptorDictionary(for: device)
    }
  }

  private func devices() -> [AVCaptureDevice] {
    let types = supportedDeviceTypes()
    let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .unspecified)
    return discovery.devices
  }

  private func supportedDeviceTypes() -> [AVCaptureDevice.DeviceType] {
    var types: [AVCaptureDevice.DeviceType] = [
      .builtInWideAngleCamera,
      .builtInUltraWideCamera,
      .builtInTelephotoCamera,
      .builtInDualCamera,
      .builtInTrueDepthCamera,
    ]
    if #available(iOS 13.0, *) {
      types.append(.builtInDualWideCamera)
      types.append(.builtInTripleCamera)
    }
    if #available(iOS 17.0, *) {
      types.append(.continuityCamera)
    }
    return types
  }

  private func device(matchingCategory category: String) -> AVCaptureDevice? {
    return devices().first { device in
      categoryString(from: device.deviceType, fallbackPosition: device.position) == category
    }
  }

  private func descriptorDictionary(for device: AVCaptureDevice) -> [String: Any] {
    var descriptor: [String: Any] = [
      "id": device.uniqueID,
      "name": device.localizedName,
      "position": positionString(from: device.position),
      "category": categoryString(from: device.deviceType, fallbackPosition: device.position),
      "supportsFocus": supportsManualFocus(device),
    ]

    let fovValue = Double(device.activeFormat.videoFieldOfView)
    if fovValue.isFinite {
      descriptor["fieldOfView"] = fovValue
    }

    return descriptor
  }

  private func supportsManualFocus(_ device: AVCaptureDevice) -> Bool {
    if device.isLockingFocusWithCustomLensPositionSupported {
      return true
    }
    let supportsRequestedModes = device.isFocusModeSupported(.autoFocus) ||
      device.isFocusModeSupported(.continuousAutoFocus)
    if device.isFocusPointOfInterestSupported && supportsRequestedModes {
      return true
    }
    return false
  }

  private func positionString(from position: AVCaptureDevice.Position) -> String {
    switch position {
    case .back:
      return "back"
    case .front:
      return "front"
    case .unspecified:
      return "external"
    @unknown default:
      return "unspecified"
    }
  }

  private func categoryString(from deviceType: AVCaptureDevice.DeviceType, fallbackPosition: AVCaptureDevice.Position) -> String {
    switch deviceType {
    case .builtInWideAngleCamera:
      return "wide"
    case .builtInUltraWideCamera:
      return "ultraWide"
    case .builtInTelephotoCamera:
      return "telephoto"
    case .builtInTrueDepthCamera:
      return "trueDepth"
    case .builtInDualCamera:
      return "dual"
    default:
      if #available(iOS 13.0, *) {
        if deviceType == .builtInDualWideCamera {
          return "dual"
        }
        if deviceType == .builtInTripleCamera {
          return "triple"
        }
      }
      if #available(iOS 17.0, *), deviceType == .continuityCamera {
        return "continuity"
      }
      return fallbackPosition == .unspecified ? "external" : "unknown"
    }
  }

  // MARK: Permissions / session helpers

  private func ensureAuthorization(completion: @escaping (Result<Void, CameraSwitchError>) -> Void) {
    let status = AVCaptureDevice.authorizationStatus(for: .video)
    switch status {
    case .authorized:
      completion(.success(()))
    case .notDetermined:
      AVCaptureDevice.requestAccess(for: .video) { granted in
        completion(granted ? .success(()) : .failure(.notAuthorized))
      }
    default:
      completion(.failure(.notAuthorized))
    }
  }

  private func startSessionIfNeeded() {
    guard !captureSession.isRunning else { return }
    captureSession.startRunning()
    isPaused = false
    if isInitialized {
      emitState(.running)
    }
  }

  private func ensurePhotoOutputAttached() {
    if captureSession.outputs.contains(where: { $0 === photoOutput }) {
      return
    }
    guard captureSession.canAddOutput(photoOutput) else {
      return
    }
    captureSession.addOutput(photoOutput)
    photoOutput.isHighResolutionCaptureEnabled = true
  }

  private func ensureVideoDataOutputAttached() {
    if captureSession.outputs.contains(where: { $0 === videoDataOutput }) {
      return
    }
    videoDataOutput.videoSettings = [
      kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
    ]
    videoDataOutput.alwaysDiscardsLateVideoFrames = true
    videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
    if captureSession.canAddOutput(videoDataOutput) {
      captureSession.addOutput(videoDataOutput)
    }
  }

  // MARK: Capture

  private func takePhoto(arguments: Any?, result: @escaping FlutterResult) {
    ensureAuthorization { [weak self] authResult in
      guard let self else { return }
      switch authResult {
      case .failure(let error):
        DispatchQueue.main.async {
          result(error.flutterError)
        }
      case .success:
        self.sessionQueue.async {
          self.startSessionIfNeeded()
          self.capturePhoto(arguments: arguments, result: result)
        }
      }
    }
  }

  private func capturePhoto(arguments: Any?, result: @escaping FlutterResult) {
    guard currentInput != nil else {
      DispatchQueue.main.async {
        result(FlutterError(
          code: "session_not_configured",
          message: "No active camera session is available for capture.",
          details: nil
        ))
      }
      return
    }

    let payload = arguments as? [String: Any]
    let flashMode = flashMode(from: payload?["flashMode"] as? String)
    let settings = AVCapturePhotoSettings()
    let supportedFlashModes: [AVCaptureDevice.FlashMode] =
      (photoOutput.supportedFlashModes as [Any]).compactMap { value in
        if let mode = value as? AVCaptureDevice.FlashMode {
          return mode
        }
        if let number = value as? NSNumber {
          return AVCaptureDevice.FlashMode(rawValue: number.intValue)
        }
        return nil
      }
    if supportedFlashModes.contains(flashMode) {
      settings.flashMode = flashMode
    }

    let exposureMicros = payload?["exposureDurationMicros"] as? Double ??
    (payload?["exposureDurationMicros"] as? NSNumber)?.doubleValue
    let isoOverride = payload?["iso"] as? Double ??
    (payload?["iso"] as? NSNumber)?.doubleValue
    let appliedManualExposure = applyManualExposure(
      exposureMicros: exposureMicros,
      iso: isoOverride
    )

    let cleanup: (() -> Void)? = appliedManualExposure ? { [weak self] in
      guard let self else { return }
      self.sessionQueue.async {
        self.restoreAutomaticExposure()
      }
    } : nil

    let delegate = PhotoCaptureDelegate(cleanup: cleanup) { [weak self] captureResult in
      guard let self else { return }
      self.pendingPhotoCapture = nil
      DispatchQueue.main.async {
        switch captureResult {
        case .success(let data):
          result(FlutterStandardTypedData(bytes: data))
        case .failure(let error):
          result(error.flutterError)
        }
      }
    }

    pendingPhotoCapture = delegate
    photoOutput.capturePhoto(with: settings, delegate: delegate)
  }

  private func flashMode(from rawValue: String?) -> AVCaptureDevice.FlashMode {
    switch rawValue {
    case "on":
      return .on
    case "off":
      return .off
    default:
      return .auto
    }
  }

  private func applyManualExposure(exposureMicros: Double?, iso: Double?) -> Bool {
    guard let device = currentInput?.device else { return false }
    if exposureMicros == nil && iso == nil {
      return false
    }
    do {
      try device.lockForConfiguration()
      defer { device.unlockForConfiguration() }
      if device.isExposureModeSupported(.custom) {
        let duration = clampedExposureDuration(micros: exposureMicros, device: device) ?? device.exposureDuration
        let isoValue = clampedISO(iso: iso, device: device) ?? device.iso
        device.setExposureModeCustom(duration: duration, iso: isoValue, completionHandler: nil)
        return true
      }
    } catch {
      return false
    }
    return false
  }

  private func clampedExposureDuration(micros: Double?, device: AVCaptureDevice) -> CMTime? {
    guard let micros else { return nil }
    let seconds = micros / 1_000_000.0
    var duration = CMTimeMakeWithSeconds(seconds, preferredTimescale: 1_000_000_000)
    let minDuration = device.activeFormat.minExposureDuration
    let maxDuration = device.activeFormat.maxExposureDuration
    if CMTimeCompare(duration, minDuration) < 0 {
      duration = minDuration
    } else if CMTimeCompare(duration, maxDuration) > 0 {
      duration = maxDuration
    }
    return duration
  }

  private func clampedISO(iso: Double?, device: AVCaptureDevice) -> Float? {
    guard let iso else { return nil }
    let minISO = device.activeFormat.minISO
    let maxISO = device.activeFormat.maxISO
    let clamped = max(Double(minISO), min(iso, Double(maxISO)))
    return Float(clamped)
  }

  private func restoreAutomaticExposure() {
    guard let device = currentInput?.device else { return }
    do {
      try device.lockForConfiguration()
      if device.isExposureModeSupported(.continuousAutoExposure) {
        device.exposureMode = .continuousAutoExposure
      }
      device.unlockForConfiguration()
    } catch { }
  }

  // MARK: Focus / zoom / white balance / exposure controls

  private func setFocus(arguments: Any?, result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result(FlutterError(
        code: "focus_failed",
        message: "No active camera session is available for focus updates.",
        details: nil
      ))
      return
    }
    let payload = arguments as? [String: Any]
    let x = payload?["x"] as? Double
    let y = payload?["y"] as? Double
    let lensPosition = payload?["lensPosition"] as? Double ??
    (payload?["lensPosition"] as? NSNumber)?.doubleValue

    sessionQueue.async {
      do {
        try device.lockForConfiguration()
        var applied = false
        if let lensPosition,
           device.isLockingFocusWithCustomLensPositionSupported {
          let clamped = Float(max(0.0, min(lensPosition, 1.0)))
          device.setFocusModeLocked(lensPosition: clamped, completionHandler: nil)
          applied = true
        }
        if let x, let y,
           device.isFocusPointOfInterestSupported,
           device.isFocusModeSupported(.autoFocus) || device.isFocusModeSupported(.continuousAutoFocus) {
          let point = CGPoint(
            x: max(0.0, min(x, 1.0)),
            y: max(0.0, min(y, 1.0))
          )
          device.focusPointOfInterest = point
          if device.isFocusModeSupported(.autoFocus) {
            device.focusMode = .autoFocus
          } else if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
          }
          applied = true
          self.focusExposureStreamHandler.emit(state: .focusing)
        }
        device.unlockForConfiguration()
        DispatchQueue.main.async {
          if applied {
            self.focusExposureStreamHandler.emit(state: .focusLocked)
            result(nil)
          } else {
            result(FlutterError(
              code: "focus_not_supported",
              message: "Manual focus is not supported on this device.",
              details: nil
            ))
          }
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "focus_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private func setZoom(arguments: Any?, result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result(FlutterError(
        code: "zoom_failed",
        message: "No active camera session is available for zoom updates.",
        details: nil
      ))
      return
    }
    let payload = arguments as? [String: Any]
    let zoom = payload?["zoomFactor"] as? Double ??
    (payload?["zoomFactor"] as? NSNumber)?.doubleValue ?? 1.0
    let clamped = max(1.0, min(zoom, Double(device.activeFormat.videoMaxZoomFactor)))
    sessionQueue.async {
      do {
        try device.lockForConfiguration()
        device.videoZoomFactor = CGFloat(clamped)
        device.unlockForConfiguration()
        DispatchQueue.main.async { result(nil) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "zoom_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private func setWhiteBalance(arguments: Any?, result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result(FlutterError(
        code: "white_balance_failed",
        message: "No active camera session is available for white balance updates.",
        details: nil
      ))
      return
    }
    let payload = arguments as? [String: Any]
    let temperature = payload?["temperature"] as? Double ??
    (payload?["temperature"] as? NSNumber)?.doubleValue
    let tint = payload?["tint"] as? Double ??
    (payload?["tint"] as? NSNumber)?.doubleValue

    sessionQueue.async {
      do {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if temperature == nil && tint == nil {
          if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
            device.whiteBalanceMode = .continuousAutoWhiteBalance
          }
          DispatchQueue.main.async { result(nil) }
          return
        }
        let tempValue = Float(temperature ?? 5000)
        let tintValue = Float(tint ?? 0)
        let ttValues = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
          temperature: tempValue,
          tint: tintValue
        )
        var gains = device.deviceWhiteBalanceGains(for: ttValues)
        gains = self.normalizedGains(gains, device: device)
        device.setWhiteBalanceModeLocked(with: gains, completionHandler: nil)
        DispatchQueue.main.async { result(nil) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "white_balance_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private func normalizedGains(_ gains: AVCaptureDevice.WhiteBalanceGains, device: AVCaptureDevice) -> AVCaptureDevice.WhiteBalanceGains {
    var clamped = gains
    let maxGain = device.maxWhiteBalanceGain
    let minGain: Float = 1.0
    clamped.redGain = max(minGain, min(gains.redGain, maxGain))
    clamped.greenGain = max(minGain, min(gains.greenGain, maxGain))
    clamped.blueGain = max(minGain, min(gains.blueGain, maxGain))
    return clamped
  }

  private func setExposureMode(arguments: Any?, result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result(FlutterError(
        code: "exposure_mode_failed",
        message: "No active camera session is available for exposure updates.",
        details: nil
      ))
      return
    }
    let payload = arguments as? [String: Any]
    let mode = (payload?["mode"] as? String) ?? "auto"

    sessionQueue.async {
      do {
        try device.lockForConfiguration()
        switch mode {
        case "locked":
          if device.isExposureModeSupported(.locked) {
            device.exposureMode = .locked
          } else if device.isExposureModeSupported(.autoExpose) {
            device.exposureMode = .autoExpose
          }
        default:
          if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
          } else if device.isExposureModeSupported(.autoExpose) {
            device.exposureMode = .autoExpose
          }
        }
        device.unlockForConfiguration()
        DispatchQueue.main.async { result(nil) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "exposure_mode_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private func getExposureMode(result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result("auto")
      return
    }
    let mode: String
    switch device.exposureMode {
    case .locked:
      mode = "locked"
    default:
      mode = "auto"
    }
    result(mode)
  }

  private func setExposurePoint(arguments: Any?, result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result(FlutterError(
        code: "set_exposure_point_failed",
        message: "No active camera session is available for exposure updates.",
        details: nil
      ))
      return
    }
    let payload = arguments as? [String: Any]
    let x = payload?["x"] as? Double
    let y = payload?["y"] as? Double
    guard let x, let y else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "Expected { x: <Double>, y: <Double> } for setExposurePoint.",
        details: nil
      ))
      return
    }

    sessionQueue.async {
      do {
        try device.lockForConfiguration()
        if device.isExposurePointOfInterestSupported {
          let point = CGPoint(
            x: max(0.0, min(x, 1.0)),
            y: max(0.0, min(y, 1.0))
          )
          device.exposurePointOfInterest = point
          if device.isExposureModeSupported(.continuousAutoExposure) {
            device.exposureMode = .continuousAutoExposure
          } else if device.isExposureModeSupported(.autoExpose) {
            device.exposureMode = .autoExpose
          }
          device.unlockForConfiguration()
          DispatchQueue.main.async { result(nil) }
        } else {
          device.unlockForConfiguration()
          DispatchQueue.main.async {
            result(FlutterError(
              code: "set_exposure_point_failed",
              message: "Exposure point is not supported on this device.",
              details: nil
            ))
          }
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "set_exposure_point_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private func getExposureOffset(isMin: Bool, result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result(0.0)
      return
    }
    let value = isMin ? device.minExposureTargetBias : device.maxExposureTargetBias
    result(Double(value))
  }

  private func setExposureOffset(arguments: Any?, result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result(FlutterError(
        code: "set_exposure_offset_failed",
        message: "No active camera session is available for exposure updates.",
        details: nil
      ))
      return
    }
    let payload = arguments as? [String: Any]
    let rawOffset = payload?["offset"] as? Double ?? (payload?["offset"] as? NSNumber)?.doubleValue ?? 0.0
    sessionQueue.async {
      let minOffset = Double(device.minExposureTargetBias)
      let maxOffset = Double(device.maxExposureTargetBias)
      let clamped = max(minOffset, min(rawOffset, maxOffset))
      device.setExposureTargetBias(Float(clamped)) { _ in
        DispatchQueue.main.async { result(clamped) }
      }
    }
  }

  private func getCurrentExposureOffset(result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result(0.0)
      return
    }
    result(Double(device.exposureTargetBias))
  }

  private func getExposureOffsetStepSize(result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result(0.1)
      return
    }
    let step = 0.1
    let range = Double(device.maxExposureTargetBias - device.minExposureTargetBias)
    result(min(step, max(0.01, range)))
  }

  private func setFocusMode(arguments: Any?, result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result(FlutterError(
        code: "focus_mode_failed",
        message: "No active camera session is available for focus updates.",
        details: nil
      ))
      return
    }
    let payload = arguments as? [String: Any]
    let mode = (payload?["mode"] as? String) ?? "auto"
    sessionQueue.async {
      do {
        try device.lockForConfiguration()
        switch mode {
        case "locked":
          if device.isFocusModeSupported(.locked) {
            device.focusMode = .locked
          } else if device.isLockingFocusWithCustomLensPositionSupported {
            device.setFocusModeLocked(lensPosition: device.lensPosition, completionHandler: nil)
          }
        default:
          if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
          } else if device.isFocusModeSupported(.autoFocus) {
            device.focusMode = .autoFocus
          }
        }
        device.unlockForConfiguration()
        self.focusExposureStreamHandler.emit(state: .focusLocked)
        DispatchQueue.main.async { result(nil) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "focus_mode_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  private func getFocusMode(result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result("auto")
      return
    }
    let mode: String
    switch device.focusMode {
    case .locked:
      mode = "locked"
    default:
      mode = "auto"
    }
    result(mode)
  }

  private func setTorch(arguments: Any?, result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result(FlutterError(
        code: "torch_failed",
        message: "No active camera session is available for torch updates.",
        details: nil
      ))
      return
    }
    guard device.hasTorch else {
      result(FlutterError(
        code: "torch_not_supported",
        message: "Torch is not available on this device.",
        details: nil
      ))
      return
    }

    let payload = arguments as? [String: Any]
    let enabled = payload?["enabled"] as? Bool ?? false

    sessionQueue.async {
      do {
        try device.lockForConfiguration()
        device.torchMode = enabled ? .on : .off
        device.unlockForConfiguration()
        DispatchQueue.main.async { result(nil) }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(
            code: "torch_failed",
            message: error.localizedDescription,
            details: nil
          ))
        }
      }
    }
  }

  // MARK: Streaming / frame rate / presets

  private func ensureVideoOutputForStreaming() {
    ensureVideoDataOutputAttached()
    startSessionIfNeeded()
  }

  private func startImageStream(result: @escaping FlutterResult) {
    guard currentInput != nil else {
      result(FlutterError(
        code: "stream_not_configured",
        message: "Start a lens before starting image stream.",
        details: nil
      ))
      return
    }
    sessionQueue.async {
      self.ensureVideoOutputForStreaming()
      self.isStreaming = true
      DispatchQueue.main.async { result(nil) }
    }
  }

  private func stopImageStream(result: @escaping FlutterResult) {
    sessionQueue.async {
      self.isStreaming = false
      if self.captureSession.outputs.contains(where: { $0 === self.videoDataOutput }) {
        self.captureSession.removeOutput(self.videoDataOutput)
      }
      self.videoDataOutput.setSampleBufferDelegate(nil, queue: nil)
      DispatchQueue.main.async { result(nil) }
    }
  }

  private func setFrameRateRange(arguments: Any?, result: @escaping FlutterResult) {
    guard let device = currentInput?.device else {
      result(FlutterError(
        code: "fps_failed",
        message: "No active camera session is available for frame rate updates.",
        details: nil
      ))
      return
    }
    let payload = arguments as? [String: Any]
    let minFps = payload?["minFps"] as? Double ?? (payload?["minFps"] as? NSNumber)?.doubleValue
    let maxFps = payload?["maxFps"] as? Double ?? (payload?["maxFps"] as? NSNumber)?.doubleValue
    sessionQueue.async {
      do {
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if let minFps, minFps > 0 {
          device.activeVideoMinFrameDuration = CMTimeMake(value: 1, timescale: Int32(minFps.rounded()))
        }
        if let maxFps, maxFps > 0 {
          device.activeVideoMaxFrameDuration = CMTimeMake(value: 1, timescale: Int32(maxFps.rounded()))
        }
        DispatchQueue.main.async { result(nil) }
      } catch {
        DispatchQueue.main.async {
          let flutterError = FlutterError(
            code: "fps_failed",
            message: error.localizedDescription,
            details: nil
          )
          self.emitState(.error, error: flutterError)
          result(flutterError)
        }
      }
    }
  }

  private func setResolutionPreset(arguments: Any?, result: @escaping FlutterResult) {
    let payload = arguments as? [String: Any]
    guard let presetName = payload?["preset"] as? String else {
      result(FlutterError(
        code: "invalid_arguments",
        message: "Expected { preset: <String> } for setResolutionPreset.",
        details: nil
      ))
      return
    }
    guard let preset = preset(from: presetName) else {
      result(FlutterError(
        code: "preset_not_supported",
        message: "Unknown preset \(presetName).",
        details: nil
      ))
      return
    }

    sessionQueue.async {
      self.captureSession.beginConfiguration()
      defer { self.captureSession.commitConfiguration() }
      self.currentSessionPreset = preset
      let canApplyNow = self.captureSession.inputs.isEmpty ? true : self.captureSession.canSetSessionPreset(preset)
      if canApplyNow {
        if self.captureSession.canSetSessionPreset(preset) {
          self.captureSession.sessionPreset = preset
        }
        DispatchQueue.main.async { result(nil) }
        return
      }
      DispatchQueue.main.async {
        result(FlutterError(
          code: "preset_not_supported",
          message: "Preset \(presetName) is not supported for the current session.",
          details: nil
        ))
      }
    }
  }

  private func preset(from name: String) -> AVCaptureSession.Preset? {
    switch name {
    case "low":
      return .low
    case "medium":
      return .medium
    case "high":
      return .high
    case "veryHigh":
      return .hd1920x1080
    case "ultraHigh":
      return .hd4K3840x2160
    case "max":
      return .photo
    default:
      return nil
    }
  }

  private func applySessionPresetIfNeeded() {
    if captureSession.sessionPreset == currentSessionPreset {
      return
    }
    if captureSession.canSetSessionPreset(currentSessionPreset) {
      captureSession.sessionPreset = currentSessionPreset
    }
  }

  // MARK: Lifecycle controls

  private func initializeSession(result: @escaping FlutterResult) {
    ensureAuthorization { [weak self] authResult in
      guard let self else { return }
      switch authResult {
      case .failure(let error):
        DispatchQueue.main.async { result(error.flutterError) }
      case .success:
        sessionQueue.async {
          self.ensurePhotoOutputAttached()
          self.applySessionPresetIfNeeded()
          self.isInitialized = true
          self.emitState(.initialized)
          self.startSessionIfNeeded()
          DispatchQueue.main.async { result(nil) }
        }
      }
    }
  }

  private func pauseSession(result: @escaping FlutterResult) {
    sessionQueue.async {
      if self.captureSession.isRunning {
        self.captureSession.stopRunning()
        self.isPaused = true
        self.emitState(.paused)
      }
      DispatchQueue.main.async { result(nil) }
    }
  }

  private func resumeSession(result: @escaping FlutterResult) {
    sessionQueue.async {
      self.startSessionIfNeeded()
      if self.isInitialized {
        self.emitState(.running)
      }
      DispatchQueue.main.async { result(nil) }
    }
  }

  private func disposeSession(result: @escaping FlutterResult) {
    sessionQueue.async {
      self.captureSession.stopRunning()
      if let input = self.currentInput {
        self.captureSession.removeInput(input)
      }
      if self.captureSession.outputs.contains(where: { $0 === self.photoOutput }) {
        self.captureSession.removeOutput(self.photoOutput)
      }
      if self.captureSession.outputs.contains(where: { $0 === self.videoDataOutput }) {
        self.captureSession.removeOutput(self.videoDataOutput)
      }
      self.currentInput = nil
      self.selectedLensID = nil
      self.isInitialized = false
      self.isPaused = false
      self.emitState(.disposed)
      DispatchQueue.main.async { result(nil) }
    }
  }

  private func emitState(_ state: CameraLifecycleStateNative, error: FlutterError? = nil) {
    stateStreamHandler.emit(state: state, error: error)
  }

  // MARK: Event channel (image stream)

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    imageStreamSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    imageStreamSink = nil
    return nil
  }

  public func captureOutput(
    _ output: AVCaptureOutput,
    didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {
    guard isStreaming, let sink = imageStreamSink else { return }
    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return }
    let data = Data(bytes: baseAddress, count: bytesPerRow * height)
    sink([
      "bytes": FlutterStandardTypedData(bytes: data),
      "width": width,
      "height": height,
      "bytesPerRow": bytesPerRow,
      "format": "bgra8888",
    ])
  }
}

private enum CameraSwitchError: Error {
  case lensNotFound(category: String)
  case notAuthorized
  case configurationFailed(message: String)

  var flutterError: FlutterError {
    switch self {
    case .lensNotFound(let category):
      return FlutterError(
        code: "lens_not_found",
        message: "No camera lens found for category \(category).",
        details: nil
      )
    case .notAuthorized:
      return FlutterError(
        code: "camera_permission_denied",
        message: "Camera access has not been granted. Request permission before switching lenses.",
        details: nil
      )
    case .configurationFailed(let message):
      return FlutterError(
        code: "switch_failed",
        message: message,
        details: nil
      )
    }
  }
}

private enum PhotoCaptureError: Error {
  case captureFailed(message: String)

  var flutterError: FlutterError {
    switch self {
    case .captureFailed(let message):
      return FlutterError(
        code: "photo_capture_failed",
        message: message,
        details: nil
      )
    }
  }
}

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
  private let completion: (Result<Data, PhotoCaptureError>) -> Void
  private let cleanup: (() -> Void)?

  init(
    cleanup: (() -> Void)?,
    completion: @escaping (Result<Data, PhotoCaptureError>) -> Void
  ) {
    self.cleanup = cleanup
    self.completion = completion
    super.init()
  }

  func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    if let error {
      completion(.failure(.captureFailed(message: error.localizedDescription)))
      cleanup?()
      return
    }
    guard let data = photo.fileDataRepresentation() else {
      completion(.failure(.captureFailed(message: "No image data was produced.")))
      cleanup?()
      return
    }
    completion(.success(data))
    cleanup?()
  }
}

private final class CameraPreviewFactory: NSObject, FlutterPlatformViewFactory {
  private let sessionProvider: () -> AVCaptureSession

  init(sessionProvider: @escaping () -> AVCaptureSession) {
    self.sessionProvider = sessionProvider
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    CameraPreviewPlatformView(frame: frame, sessionProvider: sessionProvider)
  }
}

private final class CameraPreviewPlatformView: NSObject, FlutterPlatformView {
  private let containerView: CameraPreviewContainerView

  init(frame: CGRect, sessionProvider: @escaping () -> AVCaptureSession) {
    containerView = CameraPreviewContainerView(frame: frame, sessionProvider: sessionProvider)
    super.init()
  }

  func view() -> UIView {
    containerView
  }
}

private final class CameraPreviewContainerView: UIView {
  private let sessionProvider: () -> AVCaptureSession
  private var previewLayer: AVCaptureVideoPreviewLayer?

  init(frame: CGRect, sessionProvider: @escaping () -> AVCaptureSession) {
    self.sessionProvider = sessionProvider
    super.init(frame: frame)
    backgroundColor = .black
    configurePreviewLayer()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func configurePreviewLayer() {
    let layer = AVCaptureVideoPreviewLayer(session: sessionProvider())
    layer.videoGravity = .resizeAspectFill
    layer.frame = bounds
    self.layer.addSublayer(layer)
    previewLayer = layer
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    previewLayer?.frame = bounds
  }
}
