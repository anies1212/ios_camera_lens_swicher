import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../orientation_event.dart';

/// Handles device orientation detection.
class WebOrientation {
  bool _listenerSetup = false;
  final StreamController<OrientationEvent> _controller =
      StreamController<OrientationEvent>.broadcast();

  Stream<OrientationEvent> get stream {
    _setupListener();
    return _controller.stream;
  }

  void _setupListener() {
    if (_listenerSetup) return;
    _listenerSetup = true;

    web.window.addEventListener(
      'orientationchange',
      ((web.Event e) {
        _emitOrientation();
      }).toJS,
    );

    _emitOrientation();
  }

  void _emitOrientation() {
    final orientation = _getDeviceOrientation();
    _controller.add(OrientationEvent(
      deviceOrientation: orientation,
      videoOrientation: _deviceToVideoOrientation(orientation),
    ));
  }

  DeviceOrientation _getDeviceOrientation() {
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

  void dispose() {
    _controller.close();
  }
}
