## 1.0.3

- Fixed iOS example lender flex error.
- Resolved issues with Swift tests and removed unnecessary test files.
- Implemented Swift Flutter stubs and tests.
- Updated README for clarity and corrected exceptions.
- Added default camera features implementation.

## 1.0.2

- Improved code formatting
- Updated to meet pub.dev criteria
- Added code comments for clarity
- Resolved makefile issues
- Fixed ignored files
- Addressed pubspec dependency conflicts

## 1.0.1

- Improved overall formatting and output
- Enhanced GitHub workflows for better performance
- Fixed issues with AI model prompt and secret management
- Corrected context collection processes
- Removed unnecessary workflow steps

## 1.0.0

- Added per-lens focus capability flags to avoid unsupported focus calls on some devices.
- Improved example app UI by modularizing widgets and guarding focus/zoom controls per lens.
- Added CI workflows for release tagging and pub publishing to streamline releases.

## 0.0.1

- Initial release of `iris_camera` (previously `ios_camera_lens_switcher`):
  - Shared `IrisCameraPreview` widget wired to the same `AVCaptureSession` used for still capture.
    - Built-in `enableTapToFocus` + `onTapFocus` gestures, automatic focus indicators, and customizable overlays via `FocusIndicatorStyle`.
  - Lens discovery + switching via strongly typed `CameraLensDescriptor`.
  - Still-photo capture with flash, optional manual exposure duration, ISO, manual focus (tap-to-focus + lens position), zoom, and custom white balance controls.
  - Optional focus indicators via `FocusIndicatorController` and `IrisCameraPreview(showFocusIndicator: true)`.
  - Graceful error handling through `CameraLensSwitcherException`.
  - iOS-only implementation; front-facing lenses are temporarily filtered until mirrored preview support is added.
