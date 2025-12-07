import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'iris_camera_platform_interface.dart';
import 'camera_lens_descriptor.dart';
import 'exposure_mode.dart';
import 'focus_mode.dart';
import 'photo_capture_options.dart';
import 'resolution_preset.dart';
import 'image_stream_frame.dart';
import 'orientation_event.dart';
import 'camera_state_event.dart';
import 'focus_exposure_state_event.dart';
import 'burst_progress_event.dart';

import 'web/web_media_stream.dart';
import 'web/web_video_recorder.dart';
import 'web/web_image_capture.dart';
import 'web/web_image_stream.dart';
import 'web/web_orientation.dart';

/// Web implementation of the iris_camera plugin using browser APIs.
class IrisCameraWeb extends IrisCameraPlatform {
  IrisCameraWeb();

  /// Registers this class as the default instance of [IrisCameraPlatform].
  static void registerWith(Registrar registrar) {
    IrisCameraPlatform.instance = IrisCameraWeb();
  }

  // Delegates
  final WebMediaStream _mediaStream = WebMediaStream();
  final WebVideoRecorder _videoRecorder = WebVideoRecorder();
  final WebImageCapture _imageCapture = WebImageCapture();
  final WebImageStream _imageStream = WebImageStream();
  final WebOrientation _orientation = WebOrientation();

  // State
  bool _isInitialized = false;
  bool _isPaused = false;
  ExposureMode _exposureMode = ExposureMode.auto;
  FocusMode _focusMode = FocusMode.auto;

  // Stream controllers
  final StreamController<CameraStateEvent> _stateController =
      StreamController<CameraStateEvent>.broadcast();
  final StreamController<FocusExposureStateEvent> _focusExposureController =
      StreamController<FocusExposureStateEvent>.broadcast();
  final StreamController<BurstProgressEvent> _burstProgressController =
      StreamController<BurstProgressEvent>.broadcast();

  @override
  Future<String?> getPlatformVersion() async {
    return 'Web ${web.window.navigator.userAgent}';
  }

  @override
  Future<List<CameraLensDescriptor>> listAvailableLenses({
    bool includeFrontCameras = true,
  }) async {
    try {
      return await _mediaStream.listAvailableLenses(
        includeFrontCameras: includeFrontCameras,
      );
    } catch (e) {
      _emitError('list_lenses_failed', 'Failed to list cameras: $e');
      return [];
    }
  }

  @override
  Future<CameraLensDescriptor> switchLens(CameraLensCategory category) async {
    final lenses = await listAvailableLenses();
    final target = lenses.firstWhere(
      (l) => l.category == category,
      orElse: () => lenses.isNotEmpty
          ? lenses.first
          : throw Exception('No cameras available'),
    );

    await _mediaStream.stopStream();
    _mediaStream.currentDeviceId = target.id;
    await _startStream();

    return target;
  }

  Future<void> _startStream() async {
    try {
      await _mediaStream.startStream();
      _isInitialized = true;
      _isPaused = false;
      _emitState(CameraLifecycleState.running);
    } catch (e) {
      _emitError('camera_access_failed', 'Failed to access camera: $e');
      rethrow;
    }
  }

  @override
  Future<Uint8List> capturePhoto(PhotoCaptureOptions options) async {
    _ensureInitialized();

    final videoElement = _mediaStream.videoElement;
    if (videoElement == null) {
      throw Exception('Video element not available');
    }

    if (options.flashMode == PhotoFlashMode.on) {
      await setTorch(true);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      return await _imageCapture.capturePhoto(
        videoElement: videoElement,
        options: options,
      );
    } finally {
      if (options.flashMode == PhotoFlashMode.on) {
        await setTorch(false);
      }
    }
  }

  @override
  Future<List<Uint8List>> captureBurst({
    int count = 3,
    PhotoCaptureOptions options = const PhotoCaptureOptions(),
    String? directory,
    String? filenamePrefix,
  }) async {
    _ensureInitialized();

    final results = <Uint8List>[];

    _burstProgressController.add(BurstProgressEvent(
      total: count,
      completed: 0,
      status: BurstProgressStatus.inProgress,
    ));

    for (var i = 0; i < count; i++) {
      try {
        final photo = await capturePhoto(options);
        results.add(photo);

        _burstProgressController.add(BurstProgressEvent(
          total: count,
          completed: i + 1,
          status: i == count - 1
              ? BurstProgressStatus.done
              : BurstProgressStatus.inProgress,
        ));

        if (i < count - 1) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
      } catch (e) {
        _burstProgressController.add(BurstProgressEvent(
          total: count,
          completed: i,
          status: BurstProgressStatus.error,
          error: e.toString(),
        ));
        break;
      }
    }

    return results;
  }

  @override
  Future<String> startVideoRecording({
    String? filePath,
    bool enableAudio = true,
  }) async {
    _ensureInitialized();

    final stream = _mediaStream.mediaStream;
    if (stream == null) {
      throw Exception('No active media stream');
    }

    return _videoRecorder.startRecording(
      videoStream: stream,
      filePath: filePath,
      enableAudio: enableAudio,
    );
  }

  @override
  Future<String> stopVideoRecording() async {
    return _videoRecorder.stopRecording();
  }

  @override
  Future<void> setFocus({Offset? point, double? lensPosition}) async {
    _focusExposureController.add(
      FocusExposureStateEvent(state: FocusExposureState.focusLocked),
    );
  }

  @override
  Future<void> setZoom(double zoomFactor) async {
    _mediaStream.setZoom(zoomFactor);
  }

  @override
  Future<void> setWhiteBalance({double? temperature, double? tint}) async {
    // Web has very limited white balance control
  }

  @override
  Future<void> setExposureMode(ExposureMode mode) async {
    _exposureMode = mode;
    _focusExposureController.add(
      FocusExposureStateEvent(
        state: mode == ExposureMode.locked
            ? FocusExposureState.exposureLocked
            : FocusExposureState.exposureSearching,
      ),
    );
  }

  @override
  Future<ExposureMode> getExposureMode() async => _exposureMode;

  @override
  Future<void> setExposurePoint(Offset point) async {}

  @override
  Future<double> getMinExposureOffset() async => -2.0;

  @override
  Future<double> getMaxExposureOffset() async => 2.0;

  @override
  Future<double> setExposureOffset(double offset) async =>
      offset.clamp(-2.0, 2.0);

  @override
  Future<double> getExposureOffset() async => 0.0;

  @override
  Future<double> getExposureOffsetStepSize() async => 0.1;

  @override
  Future<Duration> getMaxExposureDuration() async =>
      const Duration(seconds: 1);

  @override
  Future<void> setResolutionPreset(ResolutionPreset preset) async {
    _mediaStream.resolutionPreset = preset;
    if (_isInitialized) {
      await _mediaStream.stopStream();
      await _startStream();
    }
  }

  @override
  Future<void> setTorch(bool enabled) async {
    _mediaStream.setTorch(enabled);
  }

  @override
  Future<void> setFocusMode(FocusMode mode) async {
    _focusMode = mode;
    _focusExposureController.add(
      FocusExposureStateEvent(
        state: mode == FocusMode.locked
            ? FocusExposureState.focusLocked
            : FocusExposureState.focusing,
      ),
    );
  }

  @override
  Future<FocusMode> getFocusMode() async => _focusMode;

  @override
  Future<void> setFrameRateRange({double? minFps, double? maxFps}) async {
    await _mediaStream.setFrameRateRange(minFps: minFps, maxFps: maxFps);
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized && !_isPaused) return;

    if (_mediaStream.currentDeviceId == null) {
      final lenses = await listAvailableLenses();
      if (lenses.isNotEmpty) {
        _mediaStream.currentDeviceId = lenses.first.id;
      }
    }

    await _startStream();
    _emitState(CameraLifecycleState.initialized);
  }

  @override
  Future<void> pauseSession() async {
    _ensureInitialized();
    _mediaStream.setTracksEnabled(false);
    _isPaused = true;
    _emitState(CameraLifecycleState.paused);
  }

  @override
  Future<void> resumeSession() async {
    _mediaStream.setTracksEnabled(true);
    _isPaused = false;
    _emitState(CameraLifecycleState.running);
  }

  @override
  Future<void> disposeSession() async {
    await stopImageStream();
    await _mediaStream.stopStream();

    _isInitialized = false;
    _emitState(CameraLifecycleState.disposed);

    await Future.delayed(const Duration(milliseconds: 50));
    _stateController.close();
    _focusExposureController.close();
    _burstProgressController.close();
    _imageStream.dispose();
    _orientation.dispose();
  }

  @override
  Stream<CameraStateEvent> get stateStream => _stateController.stream;

  @override
  Stream<FocusExposureStateEvent> get focusExposureStateStream =>
      _focusExposureController.stream;

  @override
  Stream<IrisImageFrame> get imageStream => _imageStream.stream;

  @override
  Stream<BurstProgressEvent> get burstProgressStream =>
      _burstProgressController.stream;

  @override
  Future<void> startImageStream() async {
    _ensureInitialized();
    final videoElement = _mediaStream.videoElement;
    if (videoElement != null) {
      _imageStream.start(videoElement);
    }
  }

  @override
  Future<void> stopImageStream() async {
    _imageStream.stop();
  }

  @override
  Stream<OrientationEvent> get orientationStream => _orientation.stream;

  void _emitState(CameraLifecycleState state) {
    if (!_stateController.isClosed) {
      _stateController.add(CameraStateEvent(state: state));
    }
  }

  void _emitError(String code, String message) {
    if (!_stateController.isClosed) {
      _stateController.add(CameraStateEvent(
        state: CameraLifecycleState.error,
        errorCode: code,
        errorMessage: message,
      ));
    }
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception(
        'Camera not initialized. Call initialize() or switchLens() first.',
      );
    }
  }

  /// Returns the video element for use in the preview widget.
  web.HTMLVideoElement? get videoElement => _mediaStream.videoElement;

  /// Returns whether the camera is initialized.
  bool get isInitialized => _isInitialized;
}
