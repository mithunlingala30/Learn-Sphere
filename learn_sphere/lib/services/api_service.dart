import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/models.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client for the Learn Sphere FastAPI backend.
///
/// Every call carries the Firebase ID token (verified by the backend when
/// FIREBASE_PROJECT_ID is set) and the uid (used in development mode).
class ApiService {
  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? apiBaseUrl).replaceAll(RegExp(r'/+$'), ''),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<Map<String, String>> _headers() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await user?.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (user != null) 'X-User-Id': user.uid,
    };
  }

  /// Sends the day's usage and the full list of limits; returns every app
  /// that is in warning / exceeded state.
  Future<List<LimitStatus>> sync({
    required String date,
    required List<AppUsage> usage,
    required List<AppLimit> limits,
  }) async {
    final res = await _client
        .put(
          Uri.parse('$baseUrl/sync'),
          headers: await _headers(),
          body: jsonEncode({
            'date': date,
            'apps': [
              for (final a in usage)
                {
                  'package_name': a.packageName,
                  'app_name': a.appName,
                  'seconds': a.seconds,
                }
            ],
            'limits': [
              for (final l in limits)
                {
                  'package_name': l.packageName,
                  'app_name': l.appName,
                  'daily_limit_minutes': l.dailyLimitMinutes,
                  'warn_at_percent': l.warnAtPercent,
                }
            ],
          }),
        )
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw ApiException('Server answered ${res.statusCode}');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return [
      for (final e in (data['alerts'] as List? ?? const []))
        LimitStatus.fromJson(Map<String, dynamic>.from(e as Map))
    ];
  }

  /// True when the server is reachable and accepted our sign-in.
  Future<bool> ping() async {
    try {
      final res = await _client
          .get(Uri.parse('$baseUrl/me'), headers: await _headers())
          .timeout(const Duration(seconds: 6));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
