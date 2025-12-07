import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart' show PlatformViewCreatedCallback;

/// Stub implementation for non-web platforms.
void registerWebViewFactory() {
  // No-op on non-web platforms
}

/// Stub implementation for non-web platforms.
Widget buildWebPreview({
  required PlatformViewCreatedCallback? onViewCreated,
}) {
  return const SizedBox.shrink();
}

/// Stub implementation for non-web platforms.
bool isWebCameraReady() {
  return false;
}
