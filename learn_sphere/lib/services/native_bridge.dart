import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';

class NativeStatus {
  final bool usageAccess;
  final bool overlay;
  final bool notifications;
  final bool monitoring;
  const NativeStatus({
    this.usageAccess = false,
    this.overlay = false,
    this.notifications = false,
    this.monitoring = false,
  });

  bool get ready => usageAccess && overlay;
}

/// Talks to the Kotlin side (android_native/) that reads real app usage,
/// shows the centre-screen overlay and runs the background monitor.
/// On every other platform it is a harmless no-op.
class NativeBridge {
  static const MethodChannel _ch = MethodChannel('learnsphere/native');

  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<T?> _call<T>(String method, [Object? args]) async {
    if (!supported) return null;
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      debugPrint('NativeBridge.$method failed: ${e.message}');
    } on MissingPluginException {
      debugPrint('NativeBridge.$method: native side not installed.');
    }
    return null;
  }

  Future<NativeStatus> status() async {
    final raw = await _call<Map<dynamic, dynamic>>('status');
    if (raw == null) return const NativeStatus();
    return NativeStatus(
      usageAccess: raw['usageAccess'] == true,
      overlay: raw['overlay'] == true,
      notifications: raw['notifications'] == true,
      monitoring: raw['monitoring'] == true,
    );
  }

  /// Total foreground seconds per app between [start] and [end].
  Future<List<AppUsage>> getUsage(DateTime start, DateTime end) async {
    final raw = await _call<List<dynamic>>('getUsage', {
      'start': start.millisecondsSinceEpoch,
      'end': end.millisecondsSinceEpoch,
    });
    return (raw ?? const []).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return AppUsage(
        packageName: m['package'] as String,
        appName: (m['name'] as String?) ?? m['package'] as String,
        seconds: (m['seconds'] as num).toInt(),
      );
    }).toList();
  }

  Future<List<AppRef>> installedApps() async {
    final raw = await _call<List<dynamic>>('installedApps');
    return (raw ?? const []).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return AppRef(m['package'] as String, (m['name'] as String?) ?? m['package'] as String);
    }).toList();
  }

  Future<void> openUsageSettings() => _call<void>('openUsageSettings');
  Future<void> openOverlaySettings() => _call<void>('openOverlaySettings');
  Future<void> requestNotifications() => _call<void>('requestNotifications');

  /// Hands the limits to the background monitor (it works offline).
  Future<void> setLimits(List<AppLimit> limits) => _call<void>('setLimits', {
        'limits': [
          for (final l in limits)
            {
              'package': l.packageName,
              'name': l.appName,
              'minutes': l.dailyLimitMinutes,
              'warnPercent': l.warnAtPercent,
            }
        ],
      });

  Future<void> startMonitoring() => _call<void>('startMonitoring');
  Future<void> stopMonitoring() => _call<void>('stopMonitoring');
}
