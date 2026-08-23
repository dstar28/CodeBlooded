import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/api_config.dart';

/// Outcome classification for a single [SafeguardApiClient] call.
///
/// Mirrors the shape of [BackendResult] used by the Supabase repositories
/// elsewhere in the app, but is intentionally self-contained here (no
/// import of the Supabase result type) since this client has nothing to
/// do with Supabase.
enum ApiStatus { success, badRequest, notFound, serverError, network, unknown }

class ApiResult<T> {
  const ApiResult._(this.status, {this.data, this.message});

  final ApiStatus status;
  final T? data;
  final String? message;

  factory ApiResult.success(T data) => ApiResult._(ApiStatus.success, data: data);

  factory ApiResult.failure(ApiStatus status, String message) =>
      ApiResult._(status, message: message);

  bool get isSuccess => status == ApiStatus.success;

  /// True for anything that looks like "can't reach the backend right
  /// now" (timeout, connection refused, DNS failure, etc.) as opposed to
  /// a real 4xx/5xx response from the server.
  bool get isNetworkFailure => status == ApiStatus.network;
}

/// The ONE HTTP client for the FastAPI Group Safety Circle backend
/// (`group.zip` — `/groups`, `/locations`, `/safety`).
///
/// This is a small, dependency-light wrapper around `package:http` — not
/// a second Supabase client, and not a general-purpose networking layer.
/// If another feature later needs to talk to this same FastAPI backend,
/// extend this class rather than creating another HTTP client.
class SafeguardApiClient {
  SafeguardApiClient._();

  static final SafeguardApiClient instance = SafeguardApiClient._();

  static const Duration _timeout = Duration(seconds: 10);

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = Uri.parse(ApiConfig.baseUrl);
    return base.replace(
      path: '${base.path}$path',
      queryParameters: query,
    );
  }

  Future<ApiResult<Map<String, dynamic>>> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request().timeout(_timeout);
      return _parse(response);
    } on TimeoutException {
      return ApiResult.failure(
        ApiStatus.network,
        'The request timed out. Check your connection and try again.',
      );
    } on http.ClientException {
      return ApiResult.failure(
        ApiStatus.network,
        'Could not reach the SafeGuard server. Check that the backend '
        'is running and reachable.',
      );
    } on FormatException {
      return ApiResult.failure(
        ApiStatus.unknown,
        'Received an unexpected response from the server.',
      );
    } catch (_) {
      return ApiResult.failure(
        ApiStatus.network,
        'Could not reach the SafeGuard server. Check your connection.',
      );
    }
  }

  ApiResult<Map<String, dynamic>> _parse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return ApiResult.success(const {});
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return ApiResult.success(decoded);
      }
      return ApiResult.success(<String, dynamic>{'data': decoded});
    }

    final detail = _extractDetail(response.body);

    switch (response.statusCode) {
      case 400:
        return ApiResult.failure(
          ApiStatus.badRequest,
          detail ?? 'That request was invalid.',
        );
      case 404:
        return ApiResult.failure(
          ApiStatus.notFound,
          detail ?? 'Not found.',
        );
      default:
        return ApiResult.failure(
          ApiStatus.serverError,
          'The SafeGuard server had a problem. Please try again shortly.',
        );
    }
  }

  String? _extractDetail(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        return decoded['detail'] as String;
      }
    } catch (_) {
      // Not JSON — fall through to null (avoid surfacing raw bodies).
    }
    return null;
  }

  /// POST /groups/
  Future<ApiResult<Map<String, dynamic>>> createGroup({
    required String name,
    required String userId,
    required String userName,
  }) {
    return _send(
      () => http.post(
        _uri('/groups/', {
          'name': name,
          'user_id': userId,
          'user_name': userName,
        }),
      ),
    );
  }

  /// POST /groups/join
  Future<ApiResult<Map<String, dynamic>>> joinGroup({
    required String inviteCode,
    required String userId,
    required String userName,
  }) {
    return _send(
      () => http.post(
        _uri('/groups/join', {
          'invite_code': inviteCode,
          'user_id': userId,
          'user_name': userName,
        }),
      ),
    );
  }

  /// GET /groups/{group_id}
  Future<ApiResult<Map<String, dynamic>>> getGroup(String groupId) {
    return _send(() => http.get(_uri('/groups/$groupId')));
  }

  /// GET /safety/groups/{group_id}/status
  Future<ApiResult<Map<String, dynamic>>> getSafetyStatus(String groupId) {
    return _send(() => http.get(_uri('/safety/groups/$groupId/status')));
  }

  /// POST /locations/update
  Future<ApiResult<Map<String, dynamic>>> updateLocation({
    required String userId,
    required String groupId,
    required double latitude,
    required double longitude,
    double? accuracy,
  }) {
    return _send(
      () => http.post(
        _uri('/locations/update'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': userId,
          'group_id': groupId,
          'latitude': latitude,
          'longitude': longitude,
          if (accuracy != null) 'accuracy': accuracy,
        }),
      ),
    );
  }

  /// GET /zones/active
  ///
  /// Returns a GeoJSON FeatureCollection of currently ACTIVE danger /
  /// warning / safe zones, for display on the Leaflet safety map.
  Future<ApiResult<Map<String, dynamic>>> getActiveZones() {
    return _send(() => http.get(_uri('/zones/active')));
  }

  /// GET /zones/check?lat=&lng=
  ///
  /// Point-in-geofence check for the traveler's current position.
  /// Returns {"status": "safe" | "warning" | "danger", "zone": {...} | null}.
  Future<ApiResult<Map<String, dynamic>>> checkZone({
    required double latitude,
    required double longitude,
  }) {
    return _send(
      () => http.get(
        _uri('/zones/check', {
          'lat': latitude.toString(),
          'lng': longitude.toString(),
        }),
      ),
    );
  }
}
