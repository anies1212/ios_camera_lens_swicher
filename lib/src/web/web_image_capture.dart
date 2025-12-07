import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../photo_capture_options.dart';

/// Handles still image capture from video element.
class WebImageCapture {
  /// Captures a photo from the video element.
  Future<Uint8List> capturePhoto({
    required web.HTMLVideoElement videoElement,
    PhotoCaptureOptions options = const PhotoCaptureOptions(),
  }) async {
    final canvas = web.HTMLCanvasElement()
      ..width = videoElement.videoWidth
      ..height = videoElement.videoHeight;

    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(videoElement, 0, 0);

    final dataUrl = canvas.toDataURL('image/jpeg', 0.92.toJS);
    final base64 = dataUrl.split(',').last;
    return _base64Decode(base64);
  }

  Uint8List _base64Decode(String base64) {
    final binaryString = web.window.atob(base64);
    final bytes = Uint8List(binaryString.length);
    for (var i = 0; i < binaryString.length; i++) {
      bytes[i] = binaryString.codeUnitAt(i);
    }
    return bytes;
  }
}
