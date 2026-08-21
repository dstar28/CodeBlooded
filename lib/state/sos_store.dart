import 'package:flutter/foundation.dart';

/// Local/mock SOS session states supported by Emergency Assistance
/// (Prompt #7).
///
/// There is no real emergency dispatch behind these values yet — no
/// backend, no SMS, no calls, no responder API. This purely tracks what
/// the traveler has done in the current app session.
enum SosStatus { idle, countdown, active, cancelled }

/// In-memory SOS session store.
///
/// Mirrors [TripStore]'s lightweight singleton `ChangeNotifier` approach
/// (Prompt #5) rather than introducing a new state-management package.
/// An active SOS session intentionally survives navigating away from the
/// Emergency screen for as long as the app session is alive — it is only
/// reset when the traveler explicitly cancels it, or when a countdown is
/// abandoned before it finishes.
class SosStore extends ChangeNotifier {
  SosStore._internal();

  static final SosStore instance = SosStore._internal();

  SosStatus _status = SosStatus.idle;
  DateTime? _activatedAt;

  SosStatus get status => _status;
  DateTime? get activatedAt => _activatedAt;

  /// Countdown has started but SOS is not active yet.
  void startCountdown() {
    _status = SosStatus.countdown;
    notifyListeners();
  }

  /// Countdown finished — SOS is now active.
  void activate() {
    _status = SosStatus.active;
    _activatedAt = DateTime.now();
    notifyListeners();
  }

  /// Countdown was abandoned or cancelled before completion. No emergency
  /// state is created.
  void cancelCountdown() {
    _status = SosStatus.idle;
    _activatedAt = null;
    notifyListeners();
  }

  /// Traveler confirmed cancelling an active SOS session.
  void cancelActive() {
    _status = SosStatus.cancelled;
    notifyListeners();
  }

  /// Returns to the normal Emergency screen after a cancellation has been
  /// acknowledged (shown briefly, then dismissed or on user action).
  void acknowledgeCancelled() {
    _status = SosStatus.idle;
    _activatedAt = null;
    notifyListeners();
  }
}
