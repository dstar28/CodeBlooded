import 'package:flutter/foundation.dart';
import '../models/emergency_contact.dart';
import '../services/supabase/emergency_contact_repository.dart';
import '../services/supabase/sync_state.dart';

/// In-memory emergency contact store (Prompt #8).
///
/// Mirrors [TripStore] and [SosStore]'s lightweight singleton
/// `ChangeNotifier` approach rather than introducing a new
/// state-management package. This store remains the source of truth for
/// the current app session; as of Prompt #12 every mutation is also
/// persisted to Supabase in the background via
/// [EmergencyContactRepository]. Nothing here sends a real SMS, call, or
/// notification.
class EmergencyContactsStore extends ChangeNotifier {
  EmergencyContactsStore._internal();

  static final EmergencyContactsStore instance =
      EmergencyContactsStore._internal();

  final List<EmergencyContact> _contacts = [];

  List<EmergencyContact> get contacts => List.unmodifiable(_contacts);

  SyncState _syncState = SyncState.idle;

  /// Status of the most recent Supabase sync attempt, for a small
  /// "Synced" / "Offline Mode" / "Unable to sync" indicator in the UI.
  SyncState get syncState => _syncState;

  /// The single contact currently marked primary, or null if none/no
  /// contacts exist yet.
  EmergencyContact? get primaryContact {
    for (final contact in _contacts) {
      if (contact.isPrimary) return contact;
    }
    return null;
  }

  void addContact(EmergencyContact contact) {
    if (contact.isPrimary) {
      _clearPrimary();
    }
    _contacts.add(contact);
    notifyListeners();
    _syncContact(contact);
  }

  void updateContact(EmergencyContact updated) {
    final index = _contacts.indexWhere((c) => c.id == updated.id);
    if (index == -1) return;

    if (updated.isPrimary) {
      _clearPrimary();
    }
    _contacts[index] = updated;
    notifyListeners();
    _syncContact(_contacts[index]);
  }

  void deleteContact(String id) {
    _contacts.removeWhere((c) => c.id == id);
    notifyListeners();
    _syncDelete(id);
  }

  /// Marks [id] as the primary contact. Any previously primary contact
  /// automatically loses primary status — only one contact is primary at
  /// a time.
  void setPrimary(String id) {
    _clearPrimary();
    final index = _contacts.indexWhere((c) => c.id == id);
    if (index == -1) return;
    _contacts[index] = _contacts[index].copyWith(isPrimary: true);
    notifyListeners();
    _syncContact(_contacts[index]);
  }

  void _clearPrimary() {
    for (var i = 0; i < _contacts.length; i++) {
      if (_contacts[i].isPrimary) {
        _contacts[i] = _contacts[i].copyWith(isPrimary: false);
      }
    }
  }

  Future<void> _syncContact(EmergencyContact contact) async {
    _syncState = SyncState.syncing;
    notifyListeners();

    final result =
        await EmergencyContactRepository.instance.saveContact(contact);
    _applySyncResult(success: result.isSuccess, offline: result.isOffline);
  }

  Future<void> _syncDelete(String id) async {
    _syncState = SyncState.syncing;
    notifyListeners();

    final result =
        await EmergencyContactRepository.instance.deleteContact(id);
    _applySyncResult(success: result.isSuccess, offline: result.isOffline);
  }

  void _applySyncResult({required bool success, required bool offline}) {
    if (success) {
      _syncState = SyncState.synced;
    } else if (offline) {
      _syncState = SyncState.offline;
    } else {
      _syncState = SyncState.error;
    }
    notifyListeners();
  }
}