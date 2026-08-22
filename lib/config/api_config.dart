/// Single configuration point for the SafeGuard FastAPI backend
/// (Group Safety Circle) base URL.
///
/// IMPORTANT: this is a plain HTTP backend, NOT Supabase. It is
/// separate from [SupabaseConfig] and must not be merged with it.
///
/// Change ONLY the value below (or override at build/run time) instead
/// of hardcoding a host/IP anywhere else in the app:
///
/// - Android emulator talking to a backend running on your computer:
///   `http://10.0.2.2:8000`
/// - iOS simulator / desktop / Chrome running on the same computer as
///   the backend:
///   `http://localhost:8000`
/// - A physical phone on the same Wi-Fi network as your computer:
///   `http://<your-computer-LAN-IP>:8000` (e.g. `http://192.168.1.42:8000`)
///
/// You can also override this without editing code by running:
///   flutter run --dart-define=SAFEGUARD_API_BASE_URL=http://192.168.1.42:8000
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'SAFEGUARD_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
