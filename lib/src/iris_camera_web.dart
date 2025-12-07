import 'dart:async';
import 'dart:js_interop';
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

/// Web implementation of the iris_camera plugin using browser APIs.
class IrisCameraWeb extends IrisCameraPlatform {
  /// Factory constructor that initializes the platform instance.
  IrisCameraWeb();

  /// Registers this class as the default instance of [IrisCameraPlatform].
  static void registerWith(Registrar registrar) {
    IrisCameraPlatform.instance = IrisCameraWeb();
  }

  // Internal state
  web.MediaStream? _mediaStream;
  web.HTMLVideoElement? _videoElement;
  web.MediaRecorder? _mediaRecorder;
  List<web.Blob>? _recordedChunks;
  String? _currentDeviceId;
  List<web.MediaDeviceInfo>? _availableDevices;
  bool _isInitialized = false;
  bool _isPaused = false;
  double _currentZoom = 1.0;
  bool _torchEnabled = false;
  ExposureMode _exposureMode = ExposureMode.auto;
  FocusMode _focusMode = FocusMode.auto;
  ResolutionPreset _resolutionPreset = ResolutionPreset.high;
  bool _isRecording = false;
  String? _recordingMimeType;

  // Stream controllers
  final StreamController<CameraStateEvent> _stateController =
      StreamController<CameraStateEvent>.broadcast();
  final StreamController<IrisImageFrame> _imageStreamController =
      StreamController<IrisImageFrame>.broadcast();
  final StreamController<OrientationEvent> _orientationController =
      StreamController<OrientationEvent>.broadcast();
  final StreamController<FocusExposureStateEvent> _focusExposureController =
      StreamController<FocusExposureStateEvent>.broadcast();
  final StreamController<BurstProgressEvent> _burstProgressController =
      StreamController<BurstProgressEvent>.broadcast();

  Timer? _imageStreamTimer;
  web.OffscreenCanvas? _offscreenCanvas;

  @override
  Future<String?> getPlatformVersion() async {
    return 'Web ${web.window.navigator.userAgent}';
  }

  @override
  Future<List<CameraLensDescriptor>> listAvailableLenses({
    bool includeFrontCameras = true,
  }) async {
    try {
      // Request camera permission first to get device labels
      await _requestCameraPermission();

      final devices = await web.window.navigator.mediaDevices.enumerateDevices().toDart;
      _availableDevices = devices.toDart.whereType<web.MediaDeviceInfo>().toList();

      final videoDevices = _availableDevices!
          .where((d) => d.kind == 'videoinput')
          .toList();

      final lenses = <CameraLensDescriptor>[];
      for (var i = 0; i < videoDevices.length; i++) {
        final device = videoDevices[i];
        final label = device.label.isNotEmpty ? device.label : 'Camera ${i + 1}';
        final isFront = _isFrontCamera(label);

        if (!includeFrontCameras && isFront) continue;

        lenses.add(CameraLensDescriptor(
          id: device.deviceId,
          name: label,
          position: isFront ? CameraLensPosition.front : CameraLensPosition.back,
          category: _inferCategory(label, isFront),
          supportsFocus: true,
        ));
      }

      return lenses;
    } catch (e) {
      _emitError('list_lenses_failed', 'Failed to list cameras: $e');
      return [];
    }
  }

  bool _isFrontCamera(String label) {
    final lower = label.toLowerCase();
    return lower.contains('front') ||
        lower.contains('user') ||
        lower.contains('facetime') ||
        lower.contains('selfie');
  }

  CameraLensCategory _inferCategory(String label, bool isFront) {
    final lower = label.toLowerCase();
    if (isFront) return CameraLensCategory.wide;
    if (lower.contains('ultra') || lower.contains('wide')) {
      return CameraLensCategory.ultraWide;
    }
    if (lower.contains('tele') || lower.contains('zoom')) {
      return CameraLensCategory.telephoto;
    }
    return CameraLensCategory.wide;
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

    await _stopCurrentStream();
    _currentDeviceId = target.id;
    await _startStream();

    return target;
  }

  Future<void> _requestCameraPermission() async {
    try {
      final constraints = web.MediaStreamConstraints(video: true.toJS);
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
      // Stop tracks after permission granted
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
    } catch (e) {
      // Permission denied or not available
    }
  }

  Future<void> _startStream() async {
    final constraints = _buildConstraints();
    try {
      _mediaStream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;

      _videoElement = web.HTMLVideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true');
      _videoElement!.srcObject = _mediaStream;
      await _videoElement!.play().toDart;

      _applyTrackConstraints();
      _isInitialized = true;
      _isPaused = false;
      _emitState(CameraLifecycleState.running);
    } catch (e) {
      _emitError('camera_access_failed', 'Failed to access camera: $e');
      rethrow;
    }
  }

  web.MediaStreamConstraints _buildConstraints() {
    final videoConstraints = <String, Object>{};

    if (_currentDeviceId != null) {
      videoConstraints['deviceId'] = {'exact': _currentDeviceId!};
    }

    // Resolution based on preset
    final resolution = _getResolution();
    videoConstraints['width'] = {'ideal': resolution.$1};
    videoConstraints['height'] = {'ideal': resolution.$2};

    // Convert to JSObject
    final jsVideo = videoConstraints.jsify();
    return web.MediaStreamConstraints(video: jsVideo, audio: false.toJS);
  }

  (int, int) _getResolution() {
    return switch (_resolutionPreset) {
      ResolutionPreset.low => (320, 240),
      ResolutionPreset.medium => (720, 480),
      ResolutionPreset.high => (1280, 720),
      ResolutionPreset.veryHigh => (1920, 1080),
      ResolutionPreset.ultraHigh => (3840, 2160),
      ResolutionPreset.max => (3840, 2160),
    };
  }

  Future<void> _stopCurrentStream() async {
    _imageStreamTimer?.cancel();
    _imageStreamTimer = null;

    if (_mediaStream != null) {
      for (final track in _mediaStream!.getTracks().toDart) {
        track.stop();
      }
      _mediaStream = null;
    }
    _videoElement = null;
  }

  void _applyTrackConstraints() {
    if (_mediaStream == null) return;

    final videoTracks = _mediaStream!.getVideoTracks().toDart;
    if (videoTracks.isEmpty) return;

    final track = videoTracks.first;
    final constraints = <String, Object>{};

    // Apply zoom if supported
    if (_currentZoom != 1.0) {
      constraints['zoom'] = _currentZoom;
    }

    // Apply torch if supported
    if (_torchEnabled) {
      constraints['torch'] = true;
    }

    if (constraints.isNotEmpty) {
      track.applyConstraints(constraints.jsify() as web.MediaTrackConstraints);
    }
  }

  @override
  Future<Uint8List> capturePhoto(PhotoCaptureOptions options) async {
    _ensureInitialized();

    if (_videoElement == null) {
      throw Exception('Video element not available');
    }

    // Apply flash (torch) for capture if requested
    if (options.flashMode == PhotoFlashMode.on) {
      await setTorch(true);
      await Future.delayed(const Duration(milliseconds: 100));
    }

    try {
      final canvas = web.HTMLCanvasElement()
        ..width = _videoElement!.videoWidth
        ..height = _videoElement!.videoHeight;

      final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
      ctx.drawImage(_videoElement!, 0, 0);

      final dataUrl = canvas.toDataURL('image/jpeg', 0.92.toJS);
      final base64 = dataUrl.split(',').last;
      final bytes = _base64Decode(base64);

      return bytes;
    } finally {
      if (options.flashMode == PhotoFlashMode.on) {
        await setTorch(false);
      }
    }
  }

  Uint8List _base64Decode(String base64) {
    // Decode base64 using web APIs
    final binaryString = web.window.atob(base64);
    final bytes = Uint8List(binaryString.length);
    for (var i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.codeUnitAt(i);
    }
    return bytes;
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

        // Small delay between captures
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

    if (_isRecording) {
      throw Exception('Recording already in progress');
    }

    // Create a new stream with audio if requested
    web.MediaStream recordingStream;
    if (enableAudio) {
      try {
        final audioStream = await web.window.navigator.mediaDevices
            .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
            .toDart;

        recordingStream = web.MediaStream();
        for (final track in _mediaStream!.getVideoTracks().toDart) {
          recordingStream.addTrack(track);
        }
        for (final track in audioStream.getAudioTracks().toDart) {
          recordingStream.addTrack(track);
        }
      } catch (e) {
        // Fall back to video only
        recordingStream = _mediaStream!;
      }
    } else {
      recordingStream = _mediaStream!;
    }

    // Determine supported MIME type
    _recordingMimeType = _getSupportedMimeType();
    _recordedChunks = [];

    final options = web.MediaRecorderOptions(mimeType: _recordingMimeType!);
    _mediaRecorder = web.MediaRecorder(recordingStream, options);

    _mediaRecorder!.ondataavailable = ((web.BlobEvent event) {
      if (event.data.size > 0) {
        _recordedChunks!.add(event.data);
      }
    }).toJS;

    _mediaRecorder!.start(100);
    _isRecording = true;

    return filePath ?? 'recording_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _getSupportedMimeType() {
    final types = [
      'video/webm;codecs=vp9,opus',
      'video/webm;codecs=vp8,opus',
      'video/webm',
      'video/mp4',
    ];

    for (final type in types) {
      if (web.MediaRecorder.isTypeSupported(type)) {
        return type;
      }
    }

    return 'video/webm';
  }

  @override
  Future<String> stopVideoRecording() async {
    if (!_isRecording || _mediaRecorder == null) {
      throw Exception('No recording in progress');
    }

    final completer = Completer<String>();

    _mediaRecorder!.onstop = ((web.Event event) {
      final blob = web.Blob(
        _recordedChunks!.map((c) => c as JSAny).toList().toJS,
        web.BlobPropertyBag(type: _recordingMimeType ?? 'video/webm'),
      );

      final url = web.URL.createObjectURL(blob);
      completer.complete(url);
    }).toJS;

    _mediaRecorder!.stop();
    _isRecording = false;

    return completer.future;
  }

  @override
  Future<void> setFocus({Offset? point, double? lensPosition}) async {
    // Web has limited focus control
    // Emit focus locked event for compatibility
    _focusExposureController.add(
      FocusExposureStateEvent(state: FocusExposureState.focusLocked),
    );
  }

  @override
  Future<void> setZoom(double zoomFactor) async {
    _currentZoom = zoomFactor.clamp(1.0, 10.0);
    _applyTrackConstraints();
  }

  @override
  Future<void> setWhiteBalance({double? temperature, double? tint}) async {
    // Web has very limited white balance control
    // Most browsers don't support this
  }

  @override
  Future<void> setExposureMode(ExposureMode mode) async {
    _exposureMode = mode;
    // Web has limited exposure control
    _focusExposureController.add(
      FocusExposureStateEvent(
        state: mode == ExposureMode.locked
            ? FocusExposureState.exposureLocked
            : FocusExposureState.exposureSearching,
      ),
    );
  }

  @override
  Future<ExposureMode> getExposureMode() async {
    return _exposureMode;
  }

  @override
  Future<void> setExposurePoint(Offset point) async {
    // Not directly supported on web
  }

  @override
  Future<double> getMinExposureOffset() async {
    return -2.0; // Simulated value
  }

  @override
  Future<double> getMaxExposureOffset() async {
    return 2.0; // Simulated value
  }

  @override
  Future<double> setExposureOffset(double offset) async {
    return offset.clamp(-2.0, 2.0);
  }

  @override
  Future<double> getExposureOffset() async {
    return 0.0;
  }

  @override
  Future<double> getExposureOffsetStepSize() async {
    return 0.1;
  }

  @override
  Future<Duration> getMaxExposureDuration() async {
    return const Duration(seconds: 1);
  }

  @override
  Future<void> setResolutionPreset(ResolutionPreset preset) async {
    _resolutionPreset = preset;
    if (_isInitialized) {
      await _stopCurrentStream();
      await _startStream();
    }
  }

  @override
  Future<void> setTorch(bool enabled) async {
    _torchEnabled = enabled;
    _applyTrackConstraints();
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
  Future<FocusMode> getFocusMode() async {
    return _focusMode;
  }

  @override
  Future<void> setFrameRateRange({double? minFps, double? maxFps}) async {
    // Apply frame rate constraints if supported
    if (_mediaStream == null) return;

    final videoTracks = _mediaStream!.getVideoTracks().toDart;
    if (videoTracks.isEmpty) return;

    final track = videoTracks.first;
    final constraints = <String, Object>{};

    if (maxFps != null) {
      constraints['frameRate'] = {'ideal': maxFps, 'max': maxFps};
    }

    if (constraints.isNotEmpty) {
      await track.applyConstraints(
        constraints.jsify() as web.MediaTrackConstraints,
      ).toDart;
    }
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized && !_isPaused) return;

    if (_currentDeviceId == null) {
      final lenses = await listAvailableLenses();
      if (lenses.isNotEmpty) {
        _currentDeviceId = lenses.first.id;
      }
    }

    await _startStream();
    _emitState(CameraLifecycleState.initialized);
  }

  @override
  Future<void> pauseSession() async {
    _ensureInitialized();

    if (_mediaStream != null) {
      for (final track in _mediaStream!.getVideoTracks().toDart) {
        track.enabled = false;
      }
    }
    _isPaused = true;
    _emitState(CameraLifecycleState.paused);
  }

  @override
  Future<void> resumeSession() async {
    if (_mediaStream != null) {
      for (final track in _mediaStream!.getVideoTracks().toDart) {
        track.enabled = true;
      }
    }
    _isPaused = false;
    _emitState(CameraLifecycleState.running);
  }

  @override
  Future<void> disposeSession() async {
    await stopImageStream();
    await _stopCurrentStream();

    _isInitialized = false;
    _emitState(CameraLifecycleState.disposed);

    // Close controllers after emitting final state
    await Future.delayed(const Duration(milliseconds: 50));
    _stateController.close();
    _imageStreamController.close();
    _orientationController.close();
    _focusExposureController.close();
    _burstProgressController.close();
  }

  @override
  Stream<CameraStateEvent> get stateStream => _stateController.stream;

  @override
  Stream<FocusExposureStateEvent> get focusExposureStateStream =>
      _focusExposureController.stream;

  @override
  Stream<IrisImageFrame> get imageStream => _imageStreamController.stream;

  @override
  Stream<BurstProgressEvent> get burstProgressStream =>
      _burstProgressController.stream;

  @override
  Future<void> startImageStream() async {
    _ensureInitialized();

    if (_imageStreamTimer != null) return;

    // Create offscreen canvas for frame capture
    final width = _videoElement?.videoWidth ?? 640;
    final height = _videoElement?.videoHeight ?? 480;

    _offscreenCanvas = web.OffscreenCanvas(width, height);

    _imageStreamTimer = Timer.periodic(
      const Duration(milliseconds: 33), // ~30 fps
      (_) => _captureFrame(),
    );
  }

  void _captureFrame() {
    if (_videoElement == null || _offscreenCanvas == null) return;

    try {
      final ctx = _offscreenCanvas!.getContext('2d')
          as web.OffscreenCanvasRenderingContext2D;
      ctx.drawImage(_videoElement!, 0, 0);

      final imageData = ctx.getImageData(
        0,
        0,
        _offscreenCanvas!.width,
        _offscreenCanvas!.height,
      );

      // Convert RGBA to Uint8List
      final data = imageData.data.toDart;
      final bytes = Uint8List(data.length);
      for (var i = 0; i < data.length; i++) {
        bytes[i] = data[i].toInt();
      }

      _imageStreamController.add(IrisImageFrame(
        bytes: bytes,
        width: _offscreenCanvas!.width,
        height: _offscreenCanvas!.height,
        bytesPerRow: _offscreenCanvas!.width * 4,
        format: 'rgba8888',
      ));
    } catch (e) {
      // Ignore frame capture errors
    }
  }

  @override
  Future<void> stopImageStream() async {
    _imageStreamTimer?.cancel();
    _imageStreamTimer = null;
    _offscreenCanvas = null;
  }

  @override
  Stream<OrientationEvent> get orientationStream {
    // Set up orientation listener if not already done
    _setupOrientationListener();
    return _orientationController.stream;
  }

  bool _orientationListenerSetup = false;

  void _setupOrientationListener() {
    if (_orientationListenerSetup) return;
    _orientationListenerSetup = true;

    web.window.addEventListener(
      'orientationchange',
      ((web.Event e) {
        _emitOrientation();
      }).toJS,
    );

    // Emit initial orientation
    _emitOrientation();
  }

  void _emitOrientation() {
    final orientation = _getDeviceOrientation();
    _orientationController.add(OrientationEvent(
      deviceOrientation: orientation,
      videoOrientation: _deviceToVideoOrientation(orientation),
    ));
  }

  DeviceOrientation _getDeviceOrientation() {
    // Try screen orientation API first
    try {
      final screenOrientation = web.window.screen.orientation;
      final type = screenOrientation.type;
      return switch (type) {
        'portrait-primary' => DeviceOrientation.portraitUp,
        'portrait-secondary' => DeviceOrientation.portraitDown,
        'landscape-primary' => DeviceOrientation.landscapeRight,
        'landscape-secondary' => DeviceOrientation.landscapeLeft,
        _ => DeviceOrientation.unknown,
      };
    } catch (e) {
      return DeviceOrientation.unknown;
    }
  }

  VideoOrientation _deviceToVideoOrientation(DeviceOrientation device) {
    return switch (device) {
      DeviceOrientation.portraitUp => VideoOrientation.portrait,
      DeviceOrientation.portraitDown => VideoOrientation.portraitUpsideDown,
      DeviceOrientation.landscapeLeft => VideoOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight => VideoOrientation.landscapeRight,
      DeviceOrientation.unknown => VideoOrientation.unknown,
    };
  }

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
  web.HTMLVideoElement? get videoElement => _videoElement;

  /// Returns whether the camera is initialized.
  bool get isInitialized => _isInitialized;
}
