import 'package:flutter/foundation.dart';
import '../models/emergency_contact.dart';

/// In-memory emergency contact store (Prompt #8).
///
/// Mirrors [TripStore] and [SosStore]'s lightweight singleton
/// `ChangeNotifier` approach rather than introducing a new state-management
/// package. Contacts only persist for the current app session — Supabase
/// persistence will replace this in a later prompt. Do NOT treat this as a
/// real backend/service: nothing here sends a real SMS, call, or
/// notification.
class EmergencyContactsStore extends ChangeNotifier {
  EmergencyContactsStore._internal();

  static final EmergencyContactsStore instance =
      EmergencyContactsStore._internal();

  final List<EmergencyContact> _contacts = [];

  List<EmergencyContact> get contacts => List.unmodifiable(_contacts);

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
  }

  void updateContact(EmergencyContact updated) {
    final index = _contacts.indexWhere((c) => c.id == updated.id);
    if (index == -1) return;

    if (updated.isPrimary) {
      _clearPrimary();
    }
    _contacts[index] = updated;
    notifyListeners();
  }

  void deleteContact(String id) {
    _contacts.removeWhere((c) => c.id == id);
    notifyListeners();
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
  }

  void _clearPrimary() {
    for (var i = 0; i < _contacts.length; i++) {
      if (_contacts[i].isPrimary) {
        _contacts[i] = _contacts[i].copyWith(isPrimary: false);
      }
    }
  }
}
