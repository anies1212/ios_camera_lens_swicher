# iris_camera

iOS-first camera toolkit for Flutter. `iris_camera` exposes live preview widgets, structured lens descriptors, lens switching, and still-photo capture powered by AVFoundation – all through a single Dart API.

  The plugin focuses on real hardware parity: it shares one `AVCaptureSession` between preview and capture so you always see exactly what the sensor sees when you trigger a shot, and it surfaces precise metadata (position, category, field of view, focus capability) for every selectable lens.

> **Platform coverage:** only iOS is supported right now. Android and web implementations are planned for **v2.0.0**, but at the moment the plugin will no-op on other platforms.

---

## Features

- 🔍 **Lens discovery** – enumerate every physical lens that AVFoundation exposes (wide, ultra-wide, telephoto, dual/triple arrays, Continuity cameras, etc.).
- 🔁 **Hardware switching** – swap the active sensor with a single `switchLens` call; the plugin reconfigures the capture session for you and returns the selected descriptor.
- 🖼️ **Shared preview widget** – `IrisCameraPreview` renders the native `AVCaptureVideoPreviewLayer` via a `UiKitView`, so the Flutter UI always shows what the active sensor sees – flip on `enableTapToFocus` and `showFocusIndicator` for built-in gestures and overlays (customizable via `FocusIndicatorStyle`).
- 📸 **Still capture** – `capturePhoto()` grabs a high-resolution JPEG from the same session, with flash mode plus manual exposure/ISO controls via `PhotoCaptureOptions`.
- 🎯 **Manual focus & zoom** – call `setFocus()` to drive tap-to-focus points or custom lens positions, and `setZoom()` to animate digital zoom factors.
- 🌤️ **Exposure controls** – lock/unlock exposure, set exposure points, and adjust EV compensation within device limits.
- 🎚️ **Focus mode control** – toggle auto vs locked focus modes programmatically.
- ⚪ **White balance overrides** – `setWhiteBalance()` accepts temperature/tint overrides or reverts to auto when omitted.
- 🖥️ **Resolution presets** – set `ResolutionPreset` to influence the active capture format (low/medium/high/veryHigh/ultraHigh/max).
- 📡 **Live image stream** – start/stop a BGRA frame stream for ML/processing.
- 🔦 **Torch toggle** – control continuous torch independent of still-photo flash.
- 🔄 **Orientation events** – listen to device/video orientation changes from the platform.
- ⏱️ **Frame rate tuning** – set min/max FPS for the active format when supported.
- 🧭 **Lifecycle state stream** – explicit initialize/pause/resume/dispose with state events.
- 🔁 **AF/AE state events** – listen to focus/exposure lock/search/fail states.
- ⚠️ **Structured errors** – `IrisCameraException` wraps native error codes/messages so your app can react consistently to permission or hardware failures.

---

## Installation

```bash
flutter pub add iris_camera
```

```dart
import 'package:iris_camera/iris_camera.dart';

final camera = IrisCamera();
final lenses = await camera.listAvailableLenses();

await camera.switchLens(CameraLensCategory.ultraWide);
final photo = await camera.capturePhoto(
  options: const PhotoCaptureOptions(flashMode: PhotoFlashMode.auto),
);
```

Use the provided `IrisCameraPreview` widget to show the live feed:

```dart
IrisCameraPreview(
  aspectRatio: 3 / 2,
  borderRadius: const BorderRadius.all(Radius.circular(16)),
  enableTapToFocus: true,
  onTapFocus: (point) => camera.setFocus(point: point),
  showFocusIndicator: true,
  focusIndicatorStyle: const FocusIndicatorStyle(color: Colors.amber),
)
```

The full demo app is in [`example/lib/main.dart`](example/lib/main.dart).

---

## iOS Setup

Add the camera usage string to your Info.plist:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs the camera to capture photos.</string>
```

Nothing else is required; the plugin automatically requests permission the first time you call `switchLens` or `capturePhoto`.

> Front-facing lenses are included by default. If you want to exclude them, call `listAvailableLenses(includeFrontCameras: false)`.

---

## Dart API Surface

| API | Description | Key parameters |
| --- | ----------- | -------------- |
| `Future<List<CameraLensDescriptor>> listAvailableLenses()` | Enumerate available lenses (back-facing only for now). | – |
| `Future<CameraLensDescriptor> switchLens(CameraLensCategory category)` | Reconfigure the session to the requested category (wide/ultraWide/telephoto/dual/triple/continuity/trueDepth). | `category` |
| `Future<Uint8List> capturePhoto({PhotoCaptureOptions options})` | Capture a still JPEG from the active sensor. | `PhotoCaptureOptions` (see below) |
| `Future<void> setFocus({Offset? point, double? lensPosition})` | Drive tap-to-focus or manual lens position. | `point` in 0–1 normalized preview coords, or `lensPosition` 0–1 |
| `Future<void> setZoom(double zoomFactor)` | Apply digital zoom within the active format’s supported range. | `zoomFactor` |
| `Future<void> setWhiteBalance({double? temperature, double? tint})` | Override white balance or revert to auto when omitted. | `temperature`, `tint` |
| `Future<void> setExposureMode(ExposureMode mode)` / `Future<ExposureMode> getExposureMode()` | Toggle auto or locked exposure. | `mode` |
| `Future<void> setExposurePoint(Offset point)` | Apply an exposure metering point in normalized preview coords. | `point` |
| `Future<double> getMinExposureOffset()` / `Future<double> getMaxExposureOffset()` | Bounds for EV compensation on the active device. | – |
| `Future<double> setExposureOffset(double offset)` / `Future<double> getExposureOffset()` | Apply/read exposure target bias (EV) clamped to device limits. | `offset` |
| `Future<double> getExposureOffsetStepSize()` | Step size used when adjusting exposure offset. | – |
| `Future<void> setResolutionPreset(ResolutionPreset preset)` | Set the preferred capture format (low/medium/high/veryHigh/ultraHigh/max). | `preset` |
| `Stream<IrisImageFrame> imageStream` + `startImageStream()` / `stopImageStream()` | BGRA frame stream for realtime processing. | – |
| `Future<void> setTorch(bool enabled)` | Toggle continuous torch. | `enabled` |
| `Future<void> setFocusMode(FocusMode mode)` / `Future<FocusMode> getFocusMode()` | Switch between auto and locked focus modes. | `mode` |
| `Stream<OrientationEvent> orientationStream` | Receive device/video orientation updates. | – |
| `Future<void> setFrameRateRange({double? minFps, double? maxFps})` | Set min/max FPS for the active format (when supported). | `minFps`, `maxFps` |
| `Future<void> initialize()` / `pauseSession()` / `resumeSession()` / `disposeSession()` | Explicit lifecycle controls for the shared session. | – |
| `Stream<CameraStateEvent> stateStream` | Listen for lifecycle/state/error updates. | – |
| `Stream<FocusExposureStateEvent> focusExposureStateStream` | Receive AF/AE state changes (searching, locked, failed). | – |

- `CameraLensDescriptor` exposes `id`, `name`, `position`, `category`, optional `focalLength`, `fieldOfView`, and `supportsFocus` to indicate whether tap/manual focus is available for that lens.
- `PhotoCaptureOptions` supports:
  - `flashMode` (`auto`, `on`, `off`)
  - `exposureDuration` (`Duration` in microseconds; longer values enable long exposures, clamped to the device range)
  - `iso` (double; clamped to the device range)
- Errors throw `CameraLensSwitcherException` (`code`, `message`, `details`).

> ⚠️ Platform support: only iOS is implemented right now; Android/Web will no-op until v2 adds those backends.

##

## Widgets

| Widget               | Description                                                                 |
| -------------------- | --------------------------------------------------------------------------- |
| `IrisCameraPreview`  | Embeds the `AVCaptureVideoPreviewLayer` via `UiKitView` with built-in tap-to-focus + optional overlays (tweak via `FocusIndicatorStyle` or `FocusIndicatorController`). |

---

## Example Interaction Flow

```dart
final lenses = await camera.listAvailableLenses();
final ultraWide = lenses.firstWhere(
  (lens) => lens.category == CameraLensCategory.ultraWide,
  orElse: () => lenses.first,
);

try {
  await camera.switchLens(ultraWide.category);
  final photoBytes = await camera.capturePhoto();
  // Save photoBytes to disk or upload.

  // Tap-to-focus at the center of the preview.
  await camera.setFocus(point: const Offset(0.5, 0.5));
} on CameraLensSwitcherException catch (error) {
  debugPrint('Camera error: ${error.code} -> ${error.message}');
}
```

Tap-to-focus gestures and the indicator overlay are baked into the preview:

```dart
final focusController = FocusIndicatorController();

IrisCameraPreview(
  enableTapToFocus: true,
  onTapFocus: (point) => camera.setFocus(point: point),
  showFocusIndicator: true,
  focusIndicatorController: focusController, // Optional override.
  focusIndicatorStyle: const FocusIndicatorStyle(
    color: Colors.greenAccent,
    size: 72,
  ),
);
```

---

## Roadmap

1. Finalize front-camera support (mirrored preview + capture pipeline).
2. Android implementation (likely CameraX) with the same Dart API.
3. Video capture hooks built on the shared session.
4. Publish v1.0 once cross-platform parity is reached, then revisit v2 for Android.

---

## License

MIT — see [LICENSE](LICENSE).
