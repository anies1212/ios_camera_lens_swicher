import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../camera_lens_descriptor.dart';
import '../resolution_preset.dart';

/// Manages MediaStream acquisition and camera device handling.
class WebMediaStream {
  web.MediaStream? _mediaStream;
  web.HTMLVideoElement? _videoElement;
  String? _currentDeviceId;
  List<web.MediaDeviceInfo>? _availableDevices;
  ResolutionPreset _resolutionPreset = ResolutionPreset.high;
  double _currentZoom = 1.0;
  bool _torchEnabled = false;

  web.MediaStream? get mediaStream => _mediaStream;
  web.HTMLVideoElement? get videoElement => _videoElement;
  String? get currentDeviceId => _currentDeviceId;
  bool get hasActiveStream => _mediaStream != null;

  set currentDeviceId(String? value) => _currentDeviceId = value;
  set resolutionPreset(ResolutionPreset value) => _resolutionPreset = value;

  /// Requests camera permission by temporarily acquiring a stream.
  Future<void> requestCameraPermission() async {
    try {
      final constraints = web.MediaStreamConstraints(video: true.toJS);
      final stream = await web.window.navigator.mediaDevices
          .getUserMedia(constraints)
          .toDart;
      for (final track in stream.getTracks().toDart) {
        track.stop();
      }
    } catch (e) {
      // Permission denied or not available
    }
  }

  /// Lists available camera devices.
  Future<List<CameraLensDescriptor>> listAvailableLenses({
    bool includeFrontCameras = true,
  }) async {
    await requestCameraPermission();

    final devices =
        await web.window.navigator.mediaDevices.enumerateDevices().toDart;
    _availableDevices =
        devices.toDart.whereType<web.MediaDeviceInfo>().toList();

    final videoDevices =
        _availableDevices!.where((d) => d.kind == 'videoinput').toList();

    final lenses = <CameraLensDescriptor>[];
    for (var i = 0; i < videoDevices.length; i++) {
      final device = videoDevices[i];
      final label =
          device.label.isNotEmpty ? device.label : 'Camera ${i + 1}';
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

  /// Starts the media stream with current settings.
  Future<void> startStream() async {
    final constraints = _buildConstraints();
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
  }

  web.MediaStreamConstraints _buildConstraints() {
    final videoConstraints = <String, Object>{};

    if (_currentDeviceId != null) {
      videoConstraints['deviceId'] = {'exact': _currentDeviceId!};
    }

    final resolution = _getResolution();
    videoConstraints['width'] = {'ideal': resolution.$1};
    videoConstraints['height'] = {'ideal': resolution.$2};

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

  /// Stops the current media stream.
  Future<void> stopStream() async {
    if (_mediaStream != null) {
      for (final track in _mediaStream!.getTracks().toDart) {
        track.stop();
      }
      _mediaStream = null;
    }
    _videoElement = null;
  }

  /// Sets the zoom level.
  void setZoom(double zoomFactor) {
    _currentZoom = zoomFactor.clamp(1.0, 10.0);
    _applyTrackConstraints();
  }

  /// Sets torch (flashlight) state.
  void setTorch(bool enabled) {
    _torchEnabled = enabled;
    _applyTrackConstraints();
  }

  /// Applies frame rate constraints.
  Future<void> setFrameRateRange({double? minFps, double? maxFps}) async {
    if (_mediaStream == null) return;

    final videoTracks = _mediaStream!.getVideoTracks().toDart;
    if (videoTracks.isEmpty) return;

    final track = videoTracks.first;
    final constraints = <String, Object>{};

    if (maxFps != null) {
      constraints['frameRate'] = {'ideal': maxFps, 'max': maxFps};
    }

    if (constraints.isNotEmpty) {
      await track
          .applyConstraints(constraints.jsify() as web.MediaTrackConstraints)
          .toDart;
    }
  }

  /// Enables/disables video tracks.
  void setTracksEnabled(bool enabled) {
    if (_mediaStream != null) {
      for (final track in _mediaStream!.getVideoTracks().toDart) {
        track.enabled = enabled;
      }
    }
  }

  void _applyTrackConstraints() {
    if (_mediaStream == null) return;

    final videoTracks = _mediaStream!.getVideoTracks().toDart;
    if (videoTracks.isEmpty) return;

    final track = videoTracks.first;
    final constraints = <String, Object>{};

    if (_currentZoom != 1.0) {
      constraints['zoom'] = _currentZoom;
    }

    if (_torchEnabled) {
      constraints['torch'] = true;
    }

    if (constraints.isNotEmpty) {
      track.applyConstraints(constraints.jsify() as web.MediaTrackConstraints);
    }
  }
}
