import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'iris_camera_platform_interface.dart';
import 'camera_lens_descriptor.dart';
import 'exposure_mode.dart';
import 'focus_mode.dart';
import 'photo_capture_options.dart';
import 'resolution_preset.dart';
import 'image_stream_frame.dart';
import 'method_channel_keys.dart';
import 'orientation_event.dart';
import 'camera_state_event.dart';
import 'focus_exposure_state_event.dart';
import 'burst_progress_event.dart';

class MethodChannelIrisCamera extends IrisCameraPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = MethodChannel(IrisChannel.method.name);
  static final EventChannel _imageStreamChannel =
      EventChannel(IrisChannel.imageStream.name);
  static final EventChannel _orientationChannel =
      EventChannel(IrisChannel.orientation.name);
  static final EventChannel _stateChannel =
      EventChannel(IrisChannel.state.name);
  static final EventChannel _focusExposureStateChannel =
      EventChannel(IrisChannel.focusExposureState.name);
  static final EventChannel _burstProgressChannel =
      EventChannel(IrisChannel.burstProgress.name);
  Stream<IrisImageFrame>? _imageStream;
  Stream<OrientationEvent>? _orientationStream;
  Stream<CameraStateEvent>? _stateStream;
  Stream<FocusExposureStateEvent>? _focusExposureStateStream;
  Stream<BurstProgressEvent>? _burstProgressStream;

  @override
  Future<String?> getPlatformVersion() async {
    _ensureSupported();
    final version = await methodChannel.invokeMethod<String>(
      IrisMethod.getPlatformVersion.method,
    );
    return version;
  }

  @override
  Future<List<CameraLensDescriptor>> listAvailableLenses({
    bool includeFrontCameras = true,
  }) async {
    _ensureSupported();
    final rawList = await methodChannel.invokeListMethod<Object?>(
          IrisMethod.listAvailableLenses.method,
          <String, dynamic>{IrisArgKey.includeFront.key: includeFrontCameras},
        ) ??
        const <Object?>[];
    return rawList
        .map(_coerceMap)
        .map(CameraLensDescriptor.fromMap)
        .toList(growable: false);
  }

  @override
  Future<CameraLensDescriptor> switchLens(CameraLensCategory category) async {
    _ensureSupported();
    final response = await methodChannel.invokeMethod<Object?>(
      IrisMethod.switchLens.method,
      <String, dynamic>{IrisArgKey.category.key: category.name},
    );
    final map = _coerceMap(response);
    return CameraLensDescriptor.fromMap(map);
  }

  @override
  Future<Uint8List> capturePhoto(PhotoCaptureOptions options) async {
    _ensureSupported();
    final bytes = await methodChannel.invokeMethod<Uint8List>(
      IrisMethod.takePhoto.method,
      options.toMap(),
    );
    if (bytes == null) {
      throw PlatformException(
        code: 'photo_capture_failed',
        message: 'Platform returned no image data.',
      );
    }
    return bytes;
  }

  @override
  Future<String> startVideoRecording({
    String? filePath,
    bool enableAudio = true,
  }) async {
    _ensureSupported();
    final path = await methodChannel.invokeMethod<String>(
      IrisMethod.startVideoRecording.method,
      <String, dynamic>{
        if (filePath != null) IrisArgKey.filePath.key: filePath,
        IrisArgKey.enableAudio.key: enableAudio,
      },
    );
    if (path == null) {
      throw PlatformException(
        code: 'video_start_failed',
        message: 'Platform returned no video path.',
      );
    }
    return path;
  }

  @override
  Future<String> stopVideoRecording() async {
    _ensureSupported();
    final path = await methodChannel
        .invokeMethod<String>(IrisMethod.stopVideoRecording.method);
    if (path == null) {
      throw PlatformException(
        code: 'video_stop_failed',
        message: 'Platform did not return a video path.',
      );
    }
    return path;
  }

  @override
  Future<void> setFocus({
    Offset? point,
    double? lensPosition,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.android && lensPosition != null) {
      throw PlatformException(
        code: 'unsupported_feature',
        message: 'lensPosition focus is not supported on Android.',
      );
    }
    _ensureSupported();
    final args = <String, dynamic>{};
    if (point != null) {
      args[IrisArgKey.x.key] = point.dx;
      args[IrisArgKey.y.key] = point.dy;
    }
    if (lensPosition != null) {
      args[IrisArgKey.lensPosition.key] = lensPosition;
    }
    await methodChannel.invokeMethod(IrisMethod.setFocus.method, args);
  }

  @override
  Future<void> setZoom(double zoomFactor) async {
    _ensureSupported();
    await methodChannel.invokeMethod<void>(
      IrisMethod.setZoom.method,
      <String, dynamic>{IrisArgKey.zoomFactor.key: zoomFactor},
    );
  }

  @override
  Future<void> setWhiteBalance({
    double? temperature,
    double? tint,
  }) async {
    if (defaultTargetPlatform == TargetPlatform.android && (temperature != null || tint != null)) {
      throw PlatformException(
        code: 'unsupported_feature',
        message:
            'Explicit white balance temperature/tint is not supported on Android.',
      );
    }
    _ensureSupported();
    final args = <String, dynamic>{};
    if (temperature != null) {
      args[IrisArgKey.temperature.key] = temperature;
    }
    if (tint != null) {
      args[IrisArgKey.tint.key] = tint;
    }
    await methodChannel.invokeMethod<void>(
        IrisMethod.setWhiteBalance.method, args);
  }

  @override
  Future<void> setExposureMode(ExposureMode mode) async {
    _ensureSupported();
    await methodChannel.invokeMethod<void>(
      IrisMethod.setExposureMode.method,
      <String, dynamic>{
        IrisArgKey.mode.key: switch (mode) {
          ExposureMode.locked => 'locked',
          _ => 'auto'
        }
      },
    );
  }

  @override
  Future<ExposureMode> getExposureMode() async {
    _ensureSupported();
    final mode = await methodChannel
        .invokeMethod<String>(IrisMethod.getExposureMode.method);
    return mode == 'locked' ? ExposureMode.locked : ExposureMode.auto;
  }

  @override
  Future<void> setExposurePoint(Offset point) async {
    _ensureSupported();
    await methodChannel.invokeMethod<void>(
      IrisMethod.setExposurePoint.method,
      <String, dynamic>{
        IrisArgKey.x.key: point.dx,
        IrisArgKey.y.key: point.dy,
      },
    );
  }

  @override
  Future<double> getMinExposureOffset() async {
    _ensureSupported();
    final value = await methodChannel
        .invokeMethod<num>(IrisMethod.getMinExposureOffset.method);
    return (value ?? 0).toDouble();
  }

  @override
  Future<double> getMaxExposureOffset() async {
    _ensureSupported();
    final value = await methodChannel
        .invokeMethod<num>(IrisMethod.getMaxExposureOffset.method);
    return (value ?? 0).toDouble();
  }

  @override
  Future<double> setExposureOffset(double offset) async {
    _ensureSupported();
    final value = await methodChannel.invokeMethod<num>(
      IrisMethod.setExposureOffset.method,
      <String, dynamic>{IrisArgKey.offset.key: offset},
    );
    return (value ?? offset).toDouble();
  }

  @override
  Future<double> getExposureOffset() async {
    _ensureSupported();
    final value = await methodChannel
        .invokeMethod<num>(IrisMethod.getExposureOffset.method);
    return (value ?? 0).toDouble();
  }

  @override
  Future<double> getExposureOffsetStepSize() async {
    _ensureSupported();
    final value = await methodChannel
        .invokeMethod<num>(IrisMethod.getExposureOffsetStepSize.method);
    return (value ?? 0.1).toDouble();
  }

  @override
  Future<Duration> getMaxExposureDuration() async {
    _ensureSupported();
    final value = await methodChannel
        .invokeMethod<num>(IrisMethod.getMaxExposureDuration.method);
    return Duration(microseconds: (value ?? 0).toInt());
  }

  @override
  Future<List<Uint8List>> captureBurst({
    int count = 3,
    PhotoCaptureOptions options = const PhotoCaptureOptions(),
    String? directory,
    String? filenamePrefix,
  }) async {
    _ensureSupported();
    final rawList = await methodChannel.invokeListMethod<Uint8List>(
      IrisMethod.captureBurst.method,
      <String, dynamic>{
        IrisArgKey.count.key: count,
        if (directory != null) IrisArgKey.directory.key: directory,
        if (filenamePrefix != null)
          IrisArgKey.filenamePrefix.key: filenamePrefix,
        ...options.toMap(),
      },
    );
    final result = rawList ?? const <Uint8List>[];
    return result.toList(growable: false);
  }

  @override
  Future<void> setResolutionPreset(ResolutionPreset preset) async {
    _ensureSupported();
    await methodChannel.invokeMethod<void>(
      IrisMethod.setResolutionPreset.method,
      <String, dynamic>{IrisArgKey.preset.key: preset.name},
    );
  }

  @override
  Stream<IrisImageFrame> get imageStream => _imageStream ??=
          _imageStreamChannel.receiveBroadcastStream().map((event) {
        _ensureSupported();
        final map = _coerceMap(event);
        return IrisImageFrame.fromMap(map);
      });

  @override
  Stream<OrientationEvent> get orientationStream => _orientationStream ??=
          _orientationChannel.receiveBroadcastStream().map((event) {
        _ensureSupported();
        final map = _coerceMap(event);
        return OrientationEvent.fromMap(map);
      });

  @override
  Stream<CameraStateEvent> get stateStream =>
      _stateStream ??= _stateChannel.receiveBroadcastStream().map((event) {
        _ensureSupported();
        final map = _coerceMap(event);
        return CameraStateEvent.fromMap(map);
      });

  @override
  Stream<FocusExposureStateEvent> get focusExposureStateStream =>
      _focusExposureStateStream ??=
          _focusExposureStateChannel.receiveBroadcastStream().map((event) {
        _ensureSupported();
        final map = _coerceMap(event);
        return FocusExposureStateEvent.fromMap(map);
      });

  @override
  Stream<BurstProgressEvent> get burstProgressStream => _burstProgressStream ??=
          _burstProgressChannel.receiveBroadcastStream().map((event) {
        _ensureSupported();
        final map = _coerceMap(event);
        return BurstProgressEvent.fromMap(map);
      });

  @override
  Future<void> startImageStream() async {
    _ensureSupported();
    await methodChannel.invokeMethod<void>(IrisMethod.startImageStream.method);
  }

  @override
  Future<void> stopImageStream() async {
    _ensureSupported();
    await methodChannel.invokeMethod<void>(IrisMethod.stopImageStream.method);
  }

  @override
  Future<void> setTorch(bool enabled) async {
    _ensureSupported();
    await methodChannel.invokeMethod<void>(
      IrisMethod.setTorch.method,
      <String, dynamic>{IrisArgKey.enabled.key: enabled},
    );
  }

  @override
  Future<void> setFocusMode(FocusMode mode) async {
    _ensureSupported();
    await methodChannel.invokeMethod<void>(
      IrisMethod.setFocusMode.method,
      <String, dynamic>{
        IrisArgKey.mode.key: switch (mode) {
          FocusMode.locked => 'locked',
          _ => 'auto'
        }
      },
    );
  }

  @override
  Future<FocusMode> getFocusMode() async {
    _ensureSupported();
    final mode = await methodChannel
        .invokeMethod<String>(IrisMethod.getFocusMode.method);
    return mode == 'locked' ? FocusMode.locked : FocusMode.auto;
  }

  @override
  Future<void> setFrameRateRange({double? minFps, double? maxFps}) async {
    _ensureSupported();
    final args = <String, dynamic>{};
    if (minFps != null) {
      args[IrisArgKey.minFps.key] = minFps;
    }
    if (maxFps != null) {
      args[IrisArgKey.maxFps.key] = maxFps;
    }

    await methodChannel.invokeMethod<void>(
      IrisMethod.setFrameRateRange.method,
      args,
    );
  }

  @override
  Future<void> initialize() async {
    _ensureSupported();
    await methodChannel.invokeMethod<void>(IrisMethod.initialize.method);
  }

  @override
  Future<void> pauseSession() async {
    _ensureSupported();
    await methodChannel.invokeMethod<void>(IrisMethod.pauseSession.method);
  }

  @override
  Future<void> resumeSession() async {
    _ensureSupported();
    await methodChannel.invokeMethod<void>(IrisMethod.resumeSession.method);
  }

  @override
  Future<void> disposeSession() async {
    _ensureSupported();
    await methodChannel.invokeMethod<void>(IrisMethod.disposeSession.method);
  }

  Map<String, Object?> _coerceMap(Object? payload) {
    if (payload case Map<Object?, Object?> rawMap) {
      return rawMap.map((key, value) {
        if (key is! String) {
          throw FormatException(
            'Expected map key to be a String but received $key',
          );
        }
        return MapEntry(key, value);
      });
    }
    throw FormatException('Expected a map payload but received $payload');
  }

  void _ensureSupported() {
    final platform = defaultTargetPlatform;
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.android) {
      throw PlatformException(
        code: 'unsupported_platform',
        message: 'MethodChannelIrisCamera is only supported on iOS and Android.',
      );
    }
  }
}
