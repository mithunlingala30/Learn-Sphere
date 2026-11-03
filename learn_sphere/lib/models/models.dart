import 'package:intl/intl.dart';

/// "2h 14m", "45m", "<1m".
String fmtDuration(int seconds) {
  if (seconds <= 0) return '0m';
  if (seconds < 60) return '<1m';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return m == 0 ? '${h}h' : '${h}h ${m}m';
  return '${m}m';
}

String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

DateTime parseDayKey(String key) {
  try {
    return DateFormat('yyyy-MM-dd').parseStrict(key);
  } catch (_) {
    return DateTime.now();
  }
}

class AppRef {
  final String packageName;
  final String appName;
  const AppRef(this.packageName, this.appName);
}

class AppLimit {
  final String packageName;
  final String appName;
  final int dailyLimitMinutes;
  final int warnAtPercent;

  const AppLimit({
    required this.packageName,
    required this.appName,
    required this.dailyLimitMinutes,
    this.warnAtPercent = 80,
  });

  int get limitSeconds => dailyLimitMinutes * 60;

  Map<String, dynamic> toMap() => {
        'packageName': packageName,
        'appName': appName,
        'dailyLimitMinutes': dailyLimitMinutes,
        'warnAtPercent': warnAtPercent,
      };

  factory AppLimit.fromMap(Map<String, dynamic> m) => AppLimit(
        packageName: (m['packageName'] as String?) ?? '',
        appName: (m['appName'] as String?) ?? (m['packageName'] as String?) ?? '',
        dailyLimitMinutes: (m['dailyLimitMinutes'] as num?)?.toInt() ?? 30,
        warnAtPercent: (m['warnAtPercent'] as num?)?.toInt() ?? 80,
      );
}

class AppUsage {
  final String packageName;
  final String appName;
  final int seconds;

  const AppUsage({
    required this.packageName,
    required this.appName,
    required this.seconds,
  });

  Map<String, dynamic> toMap() => {'p': packageName, 'n': appName, 's': seconds};

  factory AppUsage.fromMap(Map<String, dynamic> m) => AppUsage(
        packageName: (m['p'] as String?) ?? '',
        appName: (m['n'] as String?) ?? (m['p'] as String?) ?? '',
        seconds: (m['s'] as num?)?.toInt() ?? 0,
      );
}

class DayUsage {
  final String date; // yyyy-MM-dd
  final List<AppUsage> apps;

  const DayUsage({required this.date, required this.apps});

  factory DayUsage.empty(String date) => DayUsage(date: date, apps: const []);

  int get totalSeconds => apps.fold(0, (sum, a) => sum + a.seconds);

  int secondsFor(String packageName) {
    for (final a in apps) {
      if (a.packageName == packageName) return a.seconds;
    }
    return 0;
  }

  Map<String, dynamic> toMap() => {
        'date': date,
        'apps': apps.map((a) => a.toMap()).toList(),
        'totalSeconds': totalSeconds,
      };

  factory DayUsage.fromMap(Map<String, dynamic> m) => DayUsage(
        date: (m['date'] as String?) ?? '',
        apps: ((m['apps'] as List?) ?? const [])
            .map((e) => AppUsage.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

enum LimitState { none, ok, warning, exceeded }

LimitState _stateFrom(String? s) {
  switch (s) {
    case 'ok':
      return LimitState.ok;
    case 'warning':
      return LimitState.warning;
    case 'exceeded':
      return LimitState.exceeded;
    default:
      return LimitState.none;
  }
}

/// Where one app stands against its limit. Comes from the FastAPI backend
/// (`fromJson`) or is computed on-device (`compute`) when the API is offline.
class LimitStatus {
  final String packageName;
  final String appName;
  final int usedSeconds;
  final int? limitSeconds;
  final int? remainingSeconds;
  final double? percent;
  final LimitState state;
  final String? notification;
  final String? popupTitle;
  final String? popupMessage;

  const LimitStatus({
    required this.packageName,
    required this.appName,
    required this.usedSeconds,
    this.limitSeconds,
    this.remainingSeconds,
    this.percent,
    required this.state,
    this.notification,
    this.popupTitle,
    this.popupMessage,
  });

  bool get isAlert =>
      state == LimitState.warning || state == LimitState.exceeded;

  factory LimitStatus.fromJson(Map<String, dynamic> j) {
    final popup = (j['popup'] as Map?) ?? const {};
    final show = popup['show'] == true;
    final pkg = j['package_name'] as String;
    return LimitStatus(
      packageName: pkg,
      appName: (j['app_name'] as String?) ?? pkg,
      usedSeconds: (j['used_seconds'] as num?)?.toInt() ?? 0,
      limitSeconds: (j['limit_seconds'] as num?)?.toInt(),
      remainingSeconds: (j['remaining_seconds'] as num?)?.toInt(),
      percent: (j['percent_used'] as num?)?.toDouble(),
      state: _stateFrom(j['status'] as String?),
      notification: j['notification'] as String?,
      popupTitle: show ? popup['title'] as String? : null,
      popupMessage: show ? popup['message'] as String? : null,
    );
  }

  /// Same rules and wording as the backend.
  factory LimitStatus.compute(AppLimit limit, int used) {
    final limitS = limit.limitSeconds;
    final pct = used / limitS * 100;
    final remaining = limitS - used < 0 ? 0 : limitS - used;
    var state = LimitState.ok;
    String? notification;
    String? title;
    String? message;
    if (used >= limitS) {
      state = LimitState.exceeded;
      title = "Time's up!";
      message = 'You are overusing ${limit.appName}. '
          "You've used it for ${fmtDuration(used)} today "
          'and your limit was ${fmtDuration(limitS)}.';
      notification = "You've hit your daily limit for ${limit.appName}.";
    } else if (pct >= limit.warnAtPercent) {
      state = LimitState.warning;
      notification = '${fmtDuration(remaining)} left for ${limit.appName} today.';
    }
    return LimitStatus(
      packageName: limit.packageName,
      appName: limit.appName,
      usedSeconds: used,
      limitSeconds: limitS,
      remainingSeconds: remaining,
      percent: pct,
      state: state,
      notification: notification,
      popupTitle: title,
      popupMessage: message,
    );
  }
}

/// One ring of the orbit view.
class OrbitEntry {
  final String packageName;
  final String appName;
  final int seconds;
  final double fraction; // 0..1 of the ring that is filled
  final LimitState state;

  const OrbitEntry({
    required this.packageName,
    required this.appName,
    required this.seconds,
    required this.fraction,
    required this.state,
  });
}
