/// Outcome of a single Supabase-backed operation.
///
/// Repositories return this instead of throwing or returning bare data,
/// so stores/screens can always distinguish "saved", "failed", and
/// "no backend available" — and never show a false "Data saved
/// successfully" message when a save actually failed (Prompt #12,
/// Offline Safety).
enum BackendStatus { success, failure, offline }

class BackendResult<T> {
  const BackendResult._(this.status, {this.data, this.message});

  final BackendStatus status;
  final T? data;
  final String? message;

  factory BackendResult.success([T? data]) =>
      BackendResult._(BackendStatus.success, data: data);

  factory BackendResult.failure(String message) =>
      BackendResult._(BackendStatus.failure, message: message);

  factory BackendResult.offline() => const BackendResult._(
        BackendStatus.offline,
        message: 'Offline Mode — Supabase is not configured or unreachable.',
      );

  bool get isSuccess => status == BackendStatus.success;
  bool get isOffline => status == BackendStatus.offline;
  bool get isFailure => status == BackendStatus.failure;
}