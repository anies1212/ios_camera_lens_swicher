import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'iris_camera_method_channel.dart';
import 'camera_lens_descriptor.dart';
import 'exposure_mode.dart';
import 'focus_mode.dart';
import 'photo_capture_options.dart';
import 'resolution_preset.dart';
import 'image_stream_frame.dart';
import 'orientation_event.dart';
import 'camera_state_event.dart';
import 'focus_exposure_state_event.dart';

abstract class IrisCameraPlatform extends PlatformInterface {
  IrisCameraPlatform() : super(token: _token);

  static final Object _token = Object();

  static IrisCameraPlatform _instance = MethodChannelIrisCamera();

  static IrisCameraPlatform get instance => _instance;

  static set instance(IrisCameraPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<List<CameraLensDescriptor>> listAvailableLenses({
    bool includeFrontCameras = true,
  }) {
    throw UnimplementedError('listAvailableLenses() has not been implemented.');
  }

  Future<CameraLensDescriptor> switchLens(CameraLensCategory category) {
    throw UnimplementedError('switchLens() has not been implemented.');
  }

  Future<Uint8List> capturePhoto(PhotoCaptureOptions options) {
    throw UnimplementedError('capturePhoto() has not been implemented.');
  }

  Future<void> setFocus({
    Offset? point,
    double? lensPosition,
  }) {
    throw UnimplementedError('setFocus() has not been implemented.');
  }

  Future<void> setZoom(double zoomFactor) {
    throw UnimplementedError('setZoom() has not been implemented.');
  }

  Future<void> setWhiteBalance({
    double? temperature,
    double? tint,
  }) {
    throw UnimplementedError('setWhiteBalance() has not been implemented.');
  }

  Future<void> setExposureMode(ExposureMode mode) {
    throw UnimplementedError('setExposureMode() has not been implemented.');
  }

  Future<ExposureMode> getExposureMode() {
    throw UnimplementedError('getExposureMode() has not been implemented.');
  }

  Future<void> setExposurePoint(Offset point) {
    throw UnimplementedError('setExposurePoint() has not been implemented.');
  }

  Future<double> getMinExposureOffset() {
    throw UnimplementedError(
        'getMinExposureOffset() has not been implemented.');
  }

  Future<double> getMaxExposureOffset() {
    throw UnimplementedError(
        'getMaxExposureOffset() has not been implemented.');
  }

  Future<double> setExposureOffset(double offset) {
    throw UnimplementedError('setExposureOffset() has not been implemented.');
  }

  Future<double> getExposureOffset() {
    throw UnimplementedError('getExposureOffset() has not been implemented.');
  }

  Future<double> getExposureOffsetStepSize() {
    throw UnimplementedError(
        'getExposureOffsetStepSize() has not been implemented.');
  }

  Future<void> setResolutionPreset(ResolutionPreset preset) {
    throw UnimplementedError('setResolutionPreset() has not been implemented.');
  }

  Future<void> setTorch(bool enabled) {
    throw UnimplementedError('setTorch() has not been implemented.');
  }

  Future<void> setFocusMode(FocusMode mode) {
    throw UnimplementedError('setFocusMode() has not been implemented.');
  }

  Future<FocusMode> getFocusMode() {
    throw UnimplementedError('getFocusMode() has not been implemented.');
  }

  Future<void> setFrameRateRange({double? minFps, double? maxFps}) {
    throw UnimplementedError('setFrameRateRange() has not been implemented.');
  }

  Future<void> initialize() {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  Future<void> pauseSession() {
    throw UnimplementedError('pauseSession() has not been implemented.');
  }

  Future<void> resumeSession() {
    throw UnimplementedError('resumeSession() has not been implemented.');
  }

  Future<void> disposeSession() {
    throw UnimplementedError('disposeSession() has not been implemented.');
  }

  /// Stream of lifecycle/state updates.
  Stream<CameraStateEvent> get stateStream {
    throw UnimplementedError('stateStream has not been implemented.');
  }

  /// Stream of AF/AE state updates.
  Stream<FocusExposureStateEvent> get focusExposureStateStream {
    throw UnimplementedError(
        'focusExposureStateStream has not been implemented.');
  }

  /// Stream of live image frames from the active camera (BGRA).
  Stream<IrisImageFrame> get imageStream {
    throw UnimplementedError('imageStream has not been implemented.');
  }

  /// Starts delivering frames over [imageStream].
  Future<void> startImageStream() {
    throw UnimplementedError('startImageStream() has not been implemented.');
  }

  /// Stops delivering frames over [imageStream].
  Future<void> stopImageStream() {
    throw UnimplementedError('stopImageStream() has not been implemented.');
  }

  /// Stream of device/video orientation changes.
  Stream<OrientationEvent> get orientationStream {
    throw UnimplementedError('orientationStream has not been implemented.');
  }
}
