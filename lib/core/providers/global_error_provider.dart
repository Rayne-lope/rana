import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'global_error_provider.g.dart';

/// Class containing error information caught from unhandled boundaries.
class UnhandledError {
  UnhandledError(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

@riverpod
class GlobalErrorController extends _$GlobalErrorController {
  @override
  UnhandledError? build() => null;

  /// Flags a fatal exception and triggers error UI.
  void setError(Object error, StackTrace stackTrace) {
    state = UnhandledError(error, stackTrace);
  }

  /// Clears the exception state to allow app recovery.
  void clearError() {
    state = null;
  }
}
