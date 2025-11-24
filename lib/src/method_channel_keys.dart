/// Channel names used for platform communication.
enum IrisChannel {
  /// Method channel for invoking platform APIs.
  method('iris_camera'),

  /// Event channel that streams image frames.
  imageStream('iris_camera/imageStream'),

  /// Event channel that reports device/video orientation.
  orientation('iris_camera/orientation'),

  /// Event channel that reports lifecycle/state.
  state('iris_camera/state'),

  /// Event channel that reports focus/exposure state changes.
  focusExposureState('iris_camera/focusExposureState');

  const IrisChannel(this.name);
  final String name;
}

/// Method names invoked over the method channel.
enum IrisMethod {
  /// Returns platform version (for tests).
  getPlatformVersion('getPlatformVersion'),

  /// Enumerates available camera lenses.
  listAvailableLenses('listAvailableLenses'),

  /// Switches the active lens by category.
  switchLens('switchLens'),

  /// Captures a still photo.
  takePhoto('takePhoto'),

  /// Sets a focus point or lens position.
  setFocus('setFocus'),

  /// Sets digital zoom.
  setZoom('setZoom'),

  /// Overrides white balance.
  setWhiteBalance('setWhiteBalance'),

  /// Sets exposure mode (auto/locked).
  setExposureMode('setExposureMode'),

  /// Reads current exposure mode.
  getExposureMode('getExposureMode'),

  /// Sets exposure point of interest.
  setExposurePoint('setExposurePoint'),

  /// Reads minimum EV compensation.
  getMinExposureOffset('getMinExposureOffset'),

  /// Reads maximum EV compensation.
  getMaxExposureOffset('getMaxExposureOffset'),

  /// Sets EV compensation.
  setExposureOffset('setExposureOffset'),

  /// Reads EV compensation.
  getExposureOffset('getExposureOffset'),

  /// Reads EV step size.
  getExposureOffsetStepSize('getExposureOffsetStepSize'),

  /// Sets resolution preset.
  setResolutionPreset('setResolutionPreset'),

  /// Starts image stream.
  startImageStream('startImageStream'),

  /// Stops image stream.
  stopImageStream('stopImageStream'),

  /// Toggles torch.
  setTorch('setTorch'),

  /// Sets focus mode (auto/locked).
  setFocusMode('setFocusMode'),

  /// Reads focus mode.
  getFocusMode('getFocusMode'),

  /// Sets frame rate range.
  setFrameRateRange('setFrameRateRange'),

  /// Initializes the camera session.
  initialize('initialize'),

  /// Pauses the running session.
  pauseSession('pauseSession'),

  /// Resumes the session after pause.
  resumeSession('resumeSession'),

  /// Disposes the session and releases resources.
  disposeSession('disposeSession');

  const IrisMethod(this.method);
  final String method;
}

/// Argument keys sent over the method channel.
enum IrisArgKey {
  /// Lens category.
  category('category'),

  /// Whether to include front cameras.
  includeFront('includeFront'),

  /// Flash mode for photo capture.
  flashMode('flashMode'),

  /// Exposure duration in microseconds.
  exposureDurationMicros('exposureDurationMicros'),

  /// ISO override.
  iso('iso'),

  /// Normalized X coordinate.
  x('x'),

  /// Normalized Y coordinate.
  y('y'),

  /// Lens position override (0-1).
  lensPosition('lensPosition'),

  /// Digital zoom factor.
  zoomFactor('zoomFactor'),

  /// White balance temperature.
  temperature('temperature'),

  /// White balance tint.
  tint('tint'),

  /// Generic mode parameter.
  mode('mode'),

  /// Resolution preset string.
  preset('preset'),

  /// Boolean enabled flag.
  enabled('enabled'),

  /// Exposure offset (EV).
  offset('offset'),

  /// Device orientation label.
  deviceOrientation('deviceOrientation'),

  /// Video orientation label.
  videoOrientation('videoOrientation'),

  /// Raw pixel bytes.
  bytes('bytes'),

  /// Frame width in pixels.
  width('width'),

  /// Frame height in pixels.
  height('height'),

  /// Bytes per row.
  bytesPerRow('bytesPerRow'),

  /// Pixel format identifier.
  format('format'),

  /// Minimum frames per second.
  minFps('minFps'),

  /// Maximum frames per second.
  maxFps('maxFps'),

  /// State label emitted from platform.
  state('state'),

  /// Error code emitted from platform.
  errorCode('errorCode'),

  /// Error message emitted from platform.
  errorMessage('errorMessage');

  const IrisArgKey(this.key);
  final String key;
}
