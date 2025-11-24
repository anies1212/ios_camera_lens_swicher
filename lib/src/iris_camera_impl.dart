// You have generated a new plugin project without specifying the `--platforms`
// flag. A plugin project with no platform support was generated. To add a
// platform, run `flutter create -t plugin --platforms <platforms> .` under the
// same directory. You can also find a detailed instruction on how to add
// platforms in the `pubspec.yaml` at
// https://flutter.dev/to/pubspec-plugin-platforms.

import 'package:flutter/services.dart';

import 'iris_camera_platform_interface.dart';
import 'photo_capture_options.dart';
import 'camera_lens_descriptor.dart';
import 'camera_lens_switcher_exception.dart';
import 'exposure_mode.dart';
import 'focus_mode.dart';
import 'resolution_preset.dart';
import 'image_stream_frame.dart';
import 'orientation_event.dart';
import 'camera_state_event.dart';
import 'focus_exposure_state_event.dart';

/// Main entry point for interacting with the native camera implementation.
class IrisCamera {
  /// Returns the platform version string (primarily for testing).
  Future<String?> getPlatformVersion() {
    return IrisCameraPlatform.instance.getPlatformVersion();
  }

  /// Lists all available camera lenses on the device.
  Future<List<CameraLensDescriptor>> listAvailableLenses({
    bool includeFrontCameras = true,
  }) {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.listAvailableLenses(
        includeFrontCameras: includeFrontCameras,
      ),
    );
  }

  /// Switches to a lens by category (e.g. wide, ultraWide, telephoto).
  Future<CameraLensDescriptor> switchLens(CameraLensCategory category) {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.switchLens(category),
    );
  }

  /// Captures a still photo using the active lens.
  ///
  /// Provide [options] to override flash, exposure, or ISO.
  Future<Uint8List> capturePhoto({
    PhotoCaptureOptions options = const PhotoCaptureOptions(),
  }) {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.capturePhoto(options),
    );
  }

  /// Sets focus either to a normalized preview [point] or to a [lensPosition].
  Future<void> setFocus({
    Offset? point,
    double? lensPosition,
  }) {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.setFocus(
        point: point,
        lensPosition: lensPosition,
      ),
    );
  }

  /// Applies digital zoom to the active lens.
  Future<void> setZoom(double zoomFactor) {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.setZoom(zoomFactor),
    );
  }

  /// Overrides white balance with temperature/tint or resets to auto when omitted.
  Future<void> setWhiteBalance({
    double? temperature,
    double? tint,
  }) {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.setWhiteBalance(
        temperature: temperature,
        tint: tint,
      ),
    );
  }

  /// Sets the exposure mode (auto or locked).
  Future<void> setExposureMode(ExposureMode mode) {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.setExposureMode(mode),
    );
  }

  /// Reads the current exposure mode.
  Future<ExposureMode> getExposureMode() {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.getExposureMode(),
    );
  }

  /// Sets a normalized exposure point of interest (0–1 coordinates).
  Future<void> setExposurePoint(Offset point) {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.setExposurePoint(point),
    );
  }

  /// Minimum allowed exposure offset (EV) for the active device.
  Future<double> getMinExposureOffset() {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.getMinExposureOffset(),
    );
  }

  /// Maximum allowed exposure offset (EV) for the active device.
  Future<double> getMaxExposureOffset() {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.getMaxExposureOffset(),
    );
  }

  /// Sets the exposure offset (EV compensation) and returns the applied value.
  Future<double> setExposureOffset(double offset) {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.setExposureOffset(offset),
    );
  }

  /// Returns the current exposure offset (EV compensation).
  Future<double> getExposureOffset() {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.getExposureOffset(),
    );
  }

  /// Returns the step size used when changing exposure offset.
  Future<double> getExposureOffsetStepSize() {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.getExposureOffsetStepSize(),
    );
  }

  /// Sets the preferred resolution preset for the capture session.
  ///
  /// Call before switching lenses or capturing to influence the active format
  /// chosen by the platform (e.g. `ResolutionPreset.high`).
  Future<void> setResolutionPreset(ResolutionPreset preset) {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.setResolutionPreset(preset),
    );
  }

  /// Stream of live frames for image processing.
  Stream<IrisImageFrame> get imageStream =>
      IrisCameraPlatform.instance.imageStream;

  /// Begins streaming frames over [imageStream].
  Future<void> startImageStream() {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.startImageStream(),
    );
  }

  /// Stops streaming frames.
  Future<void> stopImageStream() {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.stopImageStream(),
    );
  }

  /// Stream of orientation updates.
  Stream<OrientationEvent> get orientationStream =>
      IrisCameraPlatform.instance.orientationStream;

  /// Turns the continuous torch on or off (separate from flash).
  Future<void> setTorch(bool enabled) {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.setTorch(enabled),
    );
  }

  /// Sets the focus mode (auto or locked).
  Future<void> setFocusMode(FocusMode mode) {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.setFocusMode(mode),
    );
  }

  /// Reads the current focus mode.
  Future<FocusMode> getFocusMode() {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.getFocusMode(),
    );
  }

  /// Sets a frame rate range; pass one or both bounds.
  Future<void> setFrameRateRange({double? minFps, double? maxFps}) {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.setFrameRateRange(
        minFps: minFps,
        maxFps: maxFps,
      ),
    );
  }

  /// Explicitly initializes the camera session.
  Future<void> initialize() {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.initialize(),
    );
  }

  /// Pauses the running session (preview/capture).
  Future<void> pauseSession() {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.pauseSession(),
    );
  }

  /// Resumes a paused session.
  Future<void> resumeSession() {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.resumeSession(),
    );
  }

  /// Disposes the session and releases hardware resources.
  Future<void> disposeSession() {
    return _wrapPlatformExceptions(
      () => IrisCameraPlatform.instance.disposeSession(),
    );
  }

  /// Stream of lifecycle/state updates.
  Stream<CameraStateEvent> get stateStream =>
      IrisCameraPlatform.instance.stateStream;

  /// Stream of AF/AE state updates.
  Stream<FocusExposureStateEvent> get focusExposureStateStream =>
      IrisCameraPlatform.instance.focusExposureStateStream;

  Future<T> _wrapPlatformExceptions<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (error) {
      throw CameraLensSwitcherException.fromPlatformException(error);
    } on FormatException catch (error) {
      throw CameraLensSwitcherException('invalid_payload', error.message);
    }
  }
}
