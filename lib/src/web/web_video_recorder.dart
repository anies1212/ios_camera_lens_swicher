import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Handles video recording using MediaRecorder API.
class WebVideoRecorder {
  web.MediaRecorder? _mediaRecorder;
  List<web.Blob>? _recordedChunks;
  String? _recordingMimeType;
  bool _isRecording = false;

  bool get isRecording => _isRecording;

  /// Starts video recording.
  Future<String> startRecording({
    required web.MediaStream videoStream,
    String? filePath,
    bool enableAudio = true,
  }) async {
    if (_isRecording) {
      throw Exception('Recording already in progress');
    }

    web.MediaStream recordingStream;
    if (enableAudio) {
      try {
        final audioStream = await web.window.navigator.mediaDevices
            .getUserMedia(web.MediaStreamConstraints(audio: true.toJS))
            .toDart;

        recordingStream = web.MediaStream();
        for (final track in videoStream.getVideoTracks().toDart) {
          recordingStream.addTrack(track);
        }
        for (final track in audioStream.getAudioTracks().toDart) {
          recordingStream.addTrack(track);
        }
      } catch (e) {
        recordingStream = videoStream;
      }
    } else {
      recordingStream = videoStream;
    }

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

  /// Stops video recording and returns the blob URL.
  Future<String> stopRecording() async {
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
}
