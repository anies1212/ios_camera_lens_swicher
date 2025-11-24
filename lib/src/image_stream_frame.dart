import 'dart:typed_data';

/// Represents a single frame from the live image stream.
class IrisImageFrame {
  /// Creates an image frame wrapper.
  IrisImageFrame({
    required this.bytes,
    required this.width,
    required this.height,
    required this.bytesPerRow,
    required this.format,
  });

  /// Raw pixel buffer (BGRA8).
  final Uint8List bytes;

  /// Frame width in pixels.
  final int width;

  /// Frame height in pixels.
  final int height;

  /// Stride in bytes for each row.
  final int bytesPerRow;

  /// Pixel format identifier (e.g. "bgra8888").
  final String format;

  /// Parses a platform map into an [IrisImageFrame].
  factory IrisImageFrame.fromMap(Map<String, Object?> map) {
    final bytes = map['bytes'];
    if (bytes is! Uint8List) {
      throw const FormatException('Expected bytes to be Uint8List');
    }
    final width = map['width'];
    final height = map['height'];
    final bytesPerRow = map['bytesPerRow'];
    final format = map['format'];
    if (width is! int ||
        height is! int ||
        bytesPerRow is! int ||
        format is! String) {
      throw const FormatException('Invalid frame metadata');
    }
    return IrisImageFrame(
      bytes: bytes,
      width: width,
      height: height,
      bytesPerRow: bytesPerRow,
      format: format,
    );
  }
}
