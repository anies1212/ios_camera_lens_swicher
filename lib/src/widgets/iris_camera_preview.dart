import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart' show PlatformViewCreatedCallback;

import 'focus_indicator_controller.dart';
import 'iris_camera_preview_stub.dart'
    if (dart.library.js_interop) 'iris_camera_preview_web.dart' as web_preview;

const String _kPreviewViewType = 'iris_camera/preview';

/// Callback invoked with a tap-to-focus point in normalized preview coords.
typedef TapToFocusCallback = FutureOr<void> Function(Offset normalizedPoint);

/// Embeds the native iOS/Android camera preview layer and optional focus indicator.
class IrisCameraPreview extends StatefulWidget {
  const IrisCameraPreview({
    super.key,
    this.aspectRatio,
    this.borderRadius,
    this.backgroundColor = Colors.black,
    this.clipBehavior = Clip.antiAlias,
    this.hitTestBehavior = PlatformViewHitTestBehavior.transparent,
    this.placeholder,
    this.onViewCreated,
    this.showFocusIndicator = false,
    this.focusIndicatorStyle = const FocusIndicatorStyle(),
    this.focusIndicatorController,
    this.enableTapToFocus = false,
    this.onTapFocus,
  }) : assert(
          !enableTapToFocus || onTapFocus != null,
          'onTapFocus must be provided when enableTapToFocus is true.',
        );

  /// Optional aspect ratio for the preview container.
  final double? aspectRatio;

  /// Optional border radius for clipping the preview.
  final BorderRadius? borderRadius;

  /// Background shown behind the native view.
  final Color backgroundColor;
  final Clip clipBehavior;
  final PlatformViewHitTestBehavior hitTestBehavior;

  /// Placeholder displayed on non-iOS platforms.
  final Widget? placeholder;
  final PlatformViewCreatedCallback? onViewCreated;

  /// Whether to render the focus indicator overlay.
  final bool showFocusIndicator;

  /// Style applied to the focus indicator overlay.
  final FocusIndicatorStyle focusIndicatorStyle;

  /// Optional external controller for the indicator.
  final FocusIndicatorController? focusIndicatorController;

  /// Enables tap-to-focus gesture detection.
  final bool enableTapToFocus;

  /// Callback invoked when the preview is tapped (normalized coordinates).
  final TapToFocusCallback? onTapFocus;

  @override
  State<IrisCameraPreview> createState() => _IrisCameraPreviewState();
}

class _IrisCameraPreviewState extends State<IrisCameraPreview> {
  Offset? _focusPoint;
  FocusIndicatorController? _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _attachController();
  }

  @override
  void didUpdateWidget(IrisCameraPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusIndicatorController != widget.focusIndicatorController ||
        oldWidget.showFocusIndicator != widget.showFocusIndicator) {
      _detachController();
      _attachController();
    }
  }

  void _attachController() {
    _controller = widget.focusIndicatorController ?? FocusIndicatorController();
    _ownsController = widget.focusIndicatorController == null;
    if (widget.showFocusIndicator) {
      _controller!.addListener(_handleIndicatorChanged);
    }
  }

  void _detachController() {
    _controller?.removeListener(_handleIndicatorChanged);
    if (_ownsController) {
      _controller?.dispose();
    }
    _controller = null;
    _focusPoint = null;
  }

  void _handleIndicatorChanged() {
    if (!mounted) return;
    setState(() {
      _focusPoint = _controller!.normalizedPoint;
    });
  }

  @override
  void dispose() {
    _detachController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget preview;

    if (kIsWeb) {
      // Web platform uses HtmlElementView
      preview = web_preview.buildWebPreview(
        onViewCreated: widget.onViewCreated,
      );
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          preview = UiKitView(
            viewType: _kPreviewViewType,
            hitTestBehavior: widget.hitTestBehavior,
            onPlatformViewCreated: widget.onViewCreated,
          );
        case TargetPlatform.android:
          preview = AndroidView(
            viewType: _kPreviewViewType,
            hitTestBehavior: widget.hitTestBehavior,
            onPlatformViewCreated: widget.onViewCreated,
          );
        default:
          preview = widget.placeholder ??
              const Center(
                child: Text(
                  'Camera preview is only available on iOS/Android/Web.',
                  textAlign: TextAlign.center,
                ),
              );
      }
    }

    preview = DecoratedBox(
      decoration: BoxDecoration(color: widget.backgroundColor),
      child: preview,
    );

    Widget content = preview;

    if (widget.showFocusIndicator) {
      final indicatorLayer = AnimatedOpacity(
        duration: widget.focusIndicatorStyle.fadeDuration,
        opacity: _focusPoint == null ? 0 : 1,
        child: CustomPaint(
          painter: _FocusIndicatorPainter(
            point: _focusPoint,
            style: widget.focusIndicatorStyle,
          ),
        ),
      );

      content = Stack(
        fit: StackFit.passthrough,
        children: [
          preview,
          Positioned.fill(child: indicatorLayer),
        ],
      );
    }

    if (widget.enableTapToFocus) {
      content = _TapToFocusDetector(
        onTap: _handleTapToFocus,
        child: content,
      );
    }

    if (widget.borderRadius != null) {
      content = ClipRRect(
        borderRadius: widget.borderRadius!,
        clipBehavior: widget.clipBehavior,
        child: content,
      );
    }

    if (widget.aspectRatio != null) {
      content = AspectRatio(
        aspectRatio: widget.aspectRatio!,
        child: content,
      );
    }

    return content;
  }

  void _handleTapToFocus(Offset normalizedPoint) {
    widget.onTapFocus?.call(normalizedPoint);
    if (widget.showFocusIndicator) {
      _controller?.showIndicator(normalizedPoint);
    }
  }
}

class _FocusIndicatorPainter extends CustomPainter {
  const _FocusIndicatorPainter({
    required this.point,
    required this.style,
  });

  final Offset? point;
  final FocusIndicatorStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    if (point == null) return;
    final center = Offset(
      point!.dx * size.width,
      point!.dy * size.height,
    );
    final rect = Rect.fromCenter(
      center: center,
      width: style.size,
      height: style.size,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = style.color
      ..strokeWidth = style.strokeWidth;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, style.borderRadius),
      paint,
    );
  }

  @override
  bool shouldRepaint(_FocusIndicatorPainter oldDelegate) =>
      oldDelegate.point != point || oldDelegate.style != style;
}

@immutable
class FocusIndicatorStyle {
  const FocusIndicatorStyle({
    this.size = 90,
    this.strokeWidth = 2,
    this.color = Colors.white,
    this.borderRadius = const Radius.circular(12),
    this.fadeDuration = const Duration(milliseconds: 150),
  });

  final double size;
  final double strokeWidth;
  final Color color;
  final Radius borderRadius;
  final Duration fadeDuration;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FocusIndicatorStyle &&
        other.size == size &&
        other.strokeWidth == strokeWidth &&
        other.color == color &&
        other.borderRadius == borderRadius &&
        other.fadeDuration == fadeDuration;
  }

  @override
  int get hashCode => Object.hash(
        size,
        strokeWidth,
        color,
        borderRadius,
        fadeDuration,
      );
}

class _TapToFocusDetector extends StatelessWidget {
  const _TapToFocusDetector({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final ValueChanged<Offset> onTap;

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (gestureContext) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (details) {
          final renderBox = gestureContext.findRenderObject() as RenderBox?;
          if (renderBox == null ||
              renderBox.size.width == 0 ||
              renderBox.size.height == 0) {
            return;
          }
          final local = renderBox.globalToLocal(details.globalPosition);
          final size = renderBox.size;
          final normalized = Offset(
            (local.dx / size.width).clamp(0.0, 1.0),
            (local.dy / size.height).clamp(0.0, 1.0),
          );
          onTap(normalized);
        },
        child: child,
      ),
    );
  }
}
