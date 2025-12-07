import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import '../iris_camera_platform_interface.dart';
import '../iris_camera_web.dart';

const String _kWebPreviewViewType = 'iris_camera/web_preview';

bool _isViewFactoryRegistered = false;

/// Registers the web view factory for camera preview.
void registerWebViewFactory() {
  if (_isViewFactoryRegistered) return;
  _isViewFactoryRegistered = true;

  ui_web.platformViewRegistry.registerViewFactory(
    _kWebPreviewViewType,
    (int viewId) {
      final container = web.HTMLDivElement()
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = 'black'
        ..style.display = 'flex'
        ..style.alignItems = 'center'
        ..style.justifyContent = 'center'
        ..style.overflow = 'hidden';

      // Get video element from the web platform instance
      final platform = IrisCameraPlatform.instance;
      if (platform is IrisCameraWeb && platform.videoElement != null) {
        final video = platform.videoElement!;
        video.style.width = '100%';
        video.style.height = '100%';
        video.style.objectFit = 'cover';
        container.appendChild(video);
      } else {
        // Show placeholder if camera not initialized
        final placeholder = web.HTMLDivElement()
          ..style.color = 'white'
          ..style.textAlign = 'center'
          ..innerText = 'Camera initializing...';
        container.appendChild(placeholder);
      }

      return container;
    },
  );
}

/// Builds the web-specific camera preview widget.
Widget buildWebPreview({
  required PlatformViewCreatedCallback? onViewCreated,
}) {
  registerWebViewFactory();
  return HtmlElementView(
    viewType: _kWebPreviewViewType,
    onPlatformViewCreated: onViewCreated,
  );
}

/// Checks if the web camera is ready for preview.
bool isWebCameraReady() {
  final platform = IrisCameraPlatform.instance;
  return platform is IrisCameraWeb && platform.isInitialized;
}
