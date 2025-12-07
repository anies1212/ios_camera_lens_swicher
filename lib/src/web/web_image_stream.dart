import 'dart:async';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../image_stream_frame.dart';

/// Handles live image streaming from video element.
class WebImageStream {
  Timer? _imageStreamTimer;
  web.OffscreenCanvas? _offscreenCanvas;
  final StreamController<IrisImageFrame> _controller =
      StreamController<IrisImageFrame>.broadcast();

  Stream<IrisImageFrame> get stream => _controller.stream;
  bool get isStreaming => _imageStreamTimer != null;

  /// Starts the image stream.
  void start(web.HTMLVideoElement videoElement) {
    if (_imageStreamTimer != null) return;

    final width = videoElement.videoWidth > 0 ? videoElement.videoWidth : 640;
    final height =
        videoElement.videoHeight > 0 ? videoElement.videoHeight : 480;

    _offscreenCanvas = web.OffscreenCanvas(width, height);

    _imageStreamTimer = Timer.periodic(
      const Duration(milliseconds: 33), // ~30 fps
      (_) => _captureFrame(videoElement),
    );
  }

  /// Stops the image stream.
  void stop() {
    _imageStreamTimer?.cancel();
    _imageStreamTimer = null;
    _offscreenCanvas = null;
  }

  /// Closes the stream controller.
  void dispose() {
    stop();
    _controller.close();
  }

  void _captureFrame(web.HTMLVideoElement videoElement) {
    if (_offscreenCanvas == null) return;

    try {
      final ctx = _offscreenCanvas!.getContext('2d')
          as web.OffscreenCanvasRenderingContext2D;
      ctx.drawImage(videoElement, 0, 0);

      final imageData = ctx.getImageData(
        0,
        0,
        _offscreenCanvas!.width,
        _offscreenCanvas!.height,
      );

      final data = imageData.data.toDart;
      final bytes = Uint8List(data.length);
      for (var i = 0; i < data.length; i++) {
        bytes[i] = data[i].toInt();
      }

      _controller.add(IrisImageFrame(
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
}
