import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_camera/iris_camera.dart';
import 'package:iris_camera/src/iris_camera_method_channel.dart';
import 'package:iris_camera/src/iris_camera_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  final IrisCameraPlatform initialPlatform = IrisCameraPlatform.instance;

  test('$MethodChannelIrisCamera is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelIrisCamera>());
  });

  test('getPlatformVersion', () async {
    final irisCamera = IrisCamera();
    final fakePlatform = _MockIrisCameraPlatform();
    IrisCameraPlatform.instance = fakePlatform;

    expect(await irisCamera.getPlatformVersion(), '42');
  });

  test('listAvailableLenses delegates to platform', () async {
    final irisCamera = IrisCamera();
    final fakePlatform = _MockIrisCameraPlatform();
    IrisCameraPlatform.instance = fakePlatform;

    final lenses = await irisCamera.listAvailableLenses();
    expect(lenses.single.id, 'front_true_depth');
  });

  test('switchLens delegates to platform', () async {
    final plugin = IrisCamera();
    final fakePlatform = _MockIrisCameraPlatform();
    IrisCameraPlatform.instance = fakePlatform;

    final descriptor = await plugin.switchLens(CameraLensCategory.telephoto);
    expect(descriptor.category, CameraLensCategory.telephoto);
  });

  test('switchLens wraps PlatformException', () async {
    final plugin = IrisCamera();
    final throwingPlatform = _ThrowingSwitchPlatform();
    IrisCameraPlatform.instance = throwingPlatform;

    expect(
      () => plugin.switchLens(CameraLensCategory.wide),
      throwsA(isA<CameraLensSwitcherException>()),
    );
  });

  tearDown(() {
    IrisCameraPlatform.instance = initialPlatform;
  });
}

class _MockIrisCameraPlatform
    with MockPlatformInterfaceMixin
    implements IrisCameraPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<List<CameraLensDescriptor>> listAvailableLenses(
      {bool includeFrontCameras = true}) async {
    return [
      CameraLensDescriptor(
        id: 'front_true_depth',
        name: 'Front TrueDepth',
        position: CameraLensPosition.front,
        category: CameraLensCategory.trueDepth,
      ),
    ];
  }

  @override
  Future<CameraLensDescriptor> switchLens(CameraLensCategory category) async {
    return CameraLensDescriptor(
      id: 'back_wide',
      name: 'Back Wide',
      position: CameraLensPosition.back,
      category: category,
    );
  }

  @override
  Future<Uint8List> capturePhoto(PhotoCaptureOptions options) async {
    return Uint8List.fromList(<int>[1, 2, 3]);
  }

  @override
  Future<void> setFocus({Offset? point, double? lensPosition}) async {}

  @override
  Future<void> setWhiteBalance({double? temperature, double? tint}) async {}

  @override
  Future<void> setZoom(double zoomFactor) async {}

  @override
  Future<void> setExposureMode(ExposureMode mode) async {}

  @override
  Future<ExposureMode> getExposureMode() async => ExposureMode.auto;

  @override
  Future<void> setExposurePoint(Offset point) async {}

  @override
  Future<double> getMinExposureOffset() async => -2.0;

  @override
  Future<double> getMaxExposureOffset() async => 2.0;

  @override
  Future<double> setExposureOffset(double offset) async => offset;

  @override
  Future<double> getExposureOffset() async => 0.0;

  @override
  Future<double> getExposureOffsetStepSize() async => 0.1;

  @override
  Future<void> setResolutionPreset(ResolutionPreset preset) async {}

  @override
  Stream<IrisImageFrame> get imageStream => const Stream.empty();

  @override
  Future<void> startImageStream() async {}

  @override
  Future<void> stopImageStream() async {}

  @override
  Future<void> setTorch(bool enabled) async {}

  @override
  Future<void> setFocusMode(FocusMode mode) async {}

  @override
  Future<FocusMode> getFocusMode() async => FocusMode.auto;

  @override
  Stream<OrientationEvent> get orientationStream => const Stream.empty();

  @override
  Future<void> setFrameRateRange({double? minFps, double? maxFps}) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> pauseSession() async {}

  @override
  Future<void> resumeSession() async {}

  @override
  Future<void> disposeSession() async {}

  @override
  Stream<CameraStateEvent> get stateStream => const Stream.empty();

  @override
  Stream<FocusExposureStateEvent> get focusExposureStateStream =>
      const Stream.empty();
}

class _ThrowingSwitchPlatform
    with MockPlatformInterfaceMixin
    implements IrisCameraPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('0');

  @override
  Future<List<CameraLensDescriptor>> listAvailableLenses(
          {bool includeFrontCameras = true}) async =>
      <CameraLensDescriptor>[];

  @override
  Future<CameraLensDescriptor> switchLens(CameraLensCategory category) {
    throw PlatformException(
      code: 'lens_not_found',
      message: 'Lens not available',
    );
  }

  @override
  Future<Uint8List> capturePhoto(PhotoCaptureOptions options) async {
    throw PlatformException(code: 'photo_capture_failed');
  }

  @override
  Future<void> setFocus({Offset? point, double? lensPosition}) async {}

  @override
  Future<void> setWhiteBalance({double? temperature, double? tint}) async {}

  @override
  Future<void> setZoom(double zoomFactor) async {}

  @override
  Future<void> setExposureMode(ExposureMode mode) async {}

  @override
  Future<ExposureMode> getExposureMode() async => ExposureMode.auto;

  @override
  Future<void> setExposurePoint(Offset point) async {}

  @override
  Future<double> getMinExposureOffset() async => -2.0;

  @override
  Future<double> getMaxExposureOffset() async => 2.0;

  @override
  Future<double> setExposureOffset(double offset) async => offset;

  @override
  Future<double> getExposureOffset() async => 0.0;

  @override
  Future<double> getExposureOffsetStepSize() async => 0.1;

  @override
  Future<void> setResolutionPreset(ResolutionPreset preset) async {}

  @override
  Stream<IrisImageFrame> get imageStream => const Stream.empty();

  @override
  Future<void> startImageStream() async {}

  @override
  Future<void> stopImageStream() async {}

  @override
  Future<void> setTorch(bool enabled) async {}

  @override
  Future<void> setFocusMode(FocusMode mode) async {}

  @override
  Future<FocusMode> getFocusMode() async => FocusMode.auto;

  @override
  Stream<OrientationEvent> get orientationStream => const Stream.empty();

  @override
  Future<void> setFrameRateRange({double? minFps, double? maxFps}) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> pauseSession() async {}

  @override
  Future<void> resumeSession() async {}

  @override
  Future<void> disposeSession() async {}

  @override
  Stream<CameraStateEvent> get stateStream => const Stream.empty();

  @override
  Stream<FocusExposureStateEvent> get focusExposureStateStream =>
      const Stream.empty();
}
