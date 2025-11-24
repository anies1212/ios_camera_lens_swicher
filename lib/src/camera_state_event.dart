/// High-level lifecycle/state for the camera session.
enum CameraLifecycleState {
  /// Session and channel initialized.
  initialized,

  /// Session running (preview/capture active).
  running,

  /// Session paused/stopped temporarily.
  paused,

  /// Session disposed and resources released.
  disposed,

  /// Error state reported by the platform.
  error,
}

/// State update emitted by the platform.
class CameraStateEvent {
  /// Creates a camera state event.
  CameraStateEvent({
    required this.state,
    this.errorCode,
    this.errorMessage,
  });

  /// Reported lifecycle state.
  final CameraLifecycleState state;

  /// Optional error code when [state] is [CameraLifecycleState.error].
  final String? errorCode;

  /// Optional error message when [state] is [CameraLifecycleState.error].
  final String? errorMessage;

  /// Parses a platform map into a [CameraStateEvent].
  factory CameraStateEvent.fromMap(Map<String, Object?> map) {
    final stateRaw = map['state'] as String?;
    final state = switch (stateRaw) {
      'initialized' => CameraLifecycleState.initialized,
      'running' => CameraLifecycleState.running,
      'paused' => CameraLifecycleState.paused,
      'disposed' => CameraLifecycleState.disposed,
      _ => CameraLifecycleState.error,
    };
    return CameraStateEvent(
      state: state,
      errorCode: map['errorCode'] as String?,
      errorMessage: map['errorMessage'] as String?,
    );
  }
}
