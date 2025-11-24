import 'package:flutter/foundation.dart';
import 'method_channel_keys.dart';

enum PhotoFlashMode { auto, on, off }

/// Photo capture configuration.
@immutable
class PhotoCaptureOptions {
  /// Creates photo capture options.
  const PhotoCaptureOptions({
    this.flashMode = PhotoFlashMode.auto,
    this.exposureDuration,
    this.iso,
  });

  /// Target flash mode. Defaults to [PhotoFlashMode.auto].
  final PhotoFlashMode flashMode;

  /// Optional manual exposure duration applied before capture.
  ///
  /// Longer values enable long-exposure effects. When null the device keeps its
  /// current (auto) exposure duration.
  final Duration? exposureDuration;

  /// Optional ISO override applied before capture.
  ///
  /// Values outside the camera's supported range will be clamped.
  final double? iso;

  /// Serializes options for the platform channel.
  Map<String, Object?> toMap() {
    final flash = switch (flashMode) {
      PhotoFlashMode.auto => 'auto',
      PhotoFlashMode.on => 'on',
      PhotoFlashMode.off => 'off',
    };
    final map = <String, Object?>{
      IrisArgKey.flashMode.key: flash,
    };
    if (exposureDuration != null) {
      map[IrisArgKey.exposureDurationMicros.key] =
          exposureDuration!.inMicroseconds;
    }
    if (iso != null) {
      map[IrisArgKey.iso.key] = iso;
    }
    return map;
  }
}
