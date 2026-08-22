import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';

/// Thin initialization/status layer around Supabase for SafeGuard.
///
/// SafeGuard must keep working even when Supabase is unavailable or not
/// yet configured. Every repository in this app checks [isAvailable] (or
/// reads [client]) before touching the network, so the app can show a
/// controlled Offline Mode instead of crashing or silently pretending a
/// save succeeded.
class SupabaseService {
  SupabaseService._();

  static bool _initialized = false;
  static bool _available = false;

  /// True once `Supabase.initialize()` has completed successfully.
  static bool get isAvailable => _available;

  /// Call once, before `runApp()`. Safe to call even when
  /// [SupabaseConfig.isConfigured] is false, or when initialization
  /// itself throws — SafeGuard simply stays in Offline/Demo Mode in
  /// either case rather than crashing on launch.
  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    if (!SupabaseConfig.isConfigured) {
      debugPrint(
        'SafeGuard: Supabase credentials not configured — '
        'running in Offline/Demo Mode.',
      );
      _available = false;
      return;
    }

    try {
      await Supabase.initialize(
        url: SupabaseConfig.url,
        anonKey: SupabaseConfig.anonKey,
      );
      _available = true;
      debugPrint('SafeGuard: Supabase connected.');
    } catch (error) {
      debugPrint('SafeGuard: Supabase initialization failed: $error');
      _available = false;
    }
  }

  /// The active Supabase client, or null when Supabase is unavailable.
  /// Repositories must check this before querying and return an offline
  /// result rather than throwing.
  static SupabaseClient? get client {
    if (!_available) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}