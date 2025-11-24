/// Device orientation values as reported by the platform.
enum DeviceOrientation {
  portraitUp,
  portraitDown,
  landscapeLeft,
  landscapeRight,
  unknown,
}

/// Video orientation for preview/capture pipelines.
enum VideoOrientation {
  portrait,
  portraitUpsideDown,
  landscapeLeft,
  landscapeRight,
  unknown,
}

/// Orientation update emitted from the platform.
class OrientationEvent {
  /// Creates an orientation event.
  OrientationEvent({
    required this.deviceOrientation,
    required this.videoOrientation,
  });

  /// Current device orientation.
  final DeviceOrientation deviceOrientation;

  /// Current video orientation for preview/capture.
  final VideoOrientation videoOrientation;

  /// Parses a platform map into an [OrientationEvent].
  factory OrientationEvent.fromMap(Map<String, Object?> map) {
    final deviceRaw = map['deviceOrientation'] as String?;
    final videoRaw = map['videoOrientation'] as String?;
    final device = switch (deviceRaw) {
      'portraitUp' => DeviceOrientation.portraitUp,
      'portraitDown' => DeviceOrientation.portraitDown,
      'landscapeLeft' => DeviceOrientation.landscapeLeft,
      'landscapeRight' => DeviceOrientation.landscapeRight,
      _ => DeviceOrientation.unknown,
    };
    final video = switch (videoRaw) {
      'portrait' => VideoOrientation.portrait,
      'portraitUpsideDown' => VideoOrientation.portraitUpsideDown,
      'landscapeLeft' => VideoOrientation.landscapeLeft,
      'landscapeRight' => VideoOrientation.landscapeRight,
      _ => VideoOrientation.unknown,
    };
    return OrientationEvent(
      deviceOrientation: device,
      videoOrientation: video,
    );
  }
}
