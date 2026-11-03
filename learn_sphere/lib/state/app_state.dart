import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/native_bridge.dart';

/// Single source of truth for the UI.
///
/// Data flow
///   phone (Android)  --usage-->  Firestore  <--stream--  every signed-in device
///   limits edited anywhere  -->  Firestore  --stream-->  phone monitor + backend
///   FastAPI /sync  <-- usage + limits -->  alerts (notification + popup text)
class AppState extends ChangeNotifier {
  AppState({
    required this.auth,
    required this.firestore,
    required this.api,
    required this.native,
  }) {
    _authSub = auth.userChanges.listen(_onUser);
  }

  final AuthService auth;
  final FirestoreService firestore;
  final ApiService api;
  final NativeBridge native;

  // ------------------------------------------------------------ auth
  bool authReady = false;
  User? user;

  String get displayName {
    final n = user?.displayName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final e = user?.email ?? '';
    return e.contains('@') ? e.split('@').first : 'there';
  }

  String get firstName => displayName.split(' ').first;
  String get email => user?.email ?? '';
  bool get emailVerified => user?.emailVerified ?? true;

  // ------------------------------------------------------------ data
  List<AppLimit> limits = const [];
  DayUsage today = DayUsage.empty(dayKey(DateTime.now()));
  List<DayUsage> recent = const []; // newest first, as stored in Firestore
  List<AppRef> installed = const [];
  List<LimitStatus> alerts = const [];
  String? dataError;
  bool _gotLimits = false;
  bool _gotToday = false;
  bool get loading => user != null && !(_gotLimits && _gotToday) && dataError == null;

  Map<String, LimitStatus> _statuses = {};
  String _todayKey = dayKey(DateTime.now());
  String get todayKey => _todayKey;

  // ------------------------------------------------------------ backend + phone
  bool apiOnline = false;
  String get apiBase => api.baseUrl;
  NativeStatus nativeStatus = const NativeStatus();
  bool get nativeSupported => native.supported;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<List<AppLimit>>? _limitsSub;
  StreamSubscription<DayUsage?>? _todaySub;
  StreamSubscription<List<DayUsage>>? _recentSub;
  Timer? _tickTimer;
  Timer? _syncTimer;
  String _lastUsageSig = '';
  bool _backfilled = false;
  final Set<String> _popupShown = {};
  final List<LimitStatus> _popupQueue = [];

  // ------------------------------------------------------------ derived
  LimitStatus? statusFor(String packageName) => _statuses[packageName];
  List<LimitStatus> get statuses => limits
      .map((l) => _statuses[l.packageName])
      .whereType<LimitStatus>()
      .toList();

  AppLimit? limitFor(String packageName) {
    for (final l in limits) {
      if (l.packageName == packageName) return l;
    }
    return null;
  }

  List<AppUsage> get todayApps {
    final list = [...today.apps];
    list.sort((a, b) => b.seconds.compareTo(a.seconds));
    return list;
  }

  /// Last 7 days, oldest first, today last. Missing days are empty.
  List<DayUsage> get weekDays {
    final now = DateTime.now();
    final byDate = {for (final d in recent) d.date: d};
    byDate[_todayKey] = today;
    return [
      for (var i = 6; i >= 0; i--)
        () {
          final key = dayKey(DateTime(now.year, now.month, now.day - i));
          return byDate[key] ?? DayUsage.empty(key);
        }()
    ];
  }

  int get yesterdaySeconds {
    final w = weekDays;
    return w.length >= 2 ? w[w.length - 2].totalSeconds : 0;
  }

  /// Positive = more screen time than yesterday.
  int get deltaVsYesterday => today.totalSeconds - yesterdaySeconds;

  List<OrbitEntry> orbitEntries([int max = 5]) {
    final top = todayApps.take(max).toList();
    if (top.isEmpty) return const [];
    final maxSec = max == 0 || top.first.seconds == 0 ? 1 : top.first.seconds;
    return top.map((a) {
      final st = _statuses[a.packageName];
      final limitS = st?.limitSeconds;
      final frac = limitS != null && limitS > 0
          ? (a.seconds / limitS).clamp(0.0, 1.0).toDouble()
          : (a.seconds / maxSec) * 0.85;
      return OrbitEntry(
        packageName: a.packageName,
        appName: a.appName,
        seconds: a.seconds,
        fraction: frac,
        state: st?.state ?? LimitState.none,
      );
    }).toList();
  }

  /// Per-app totals across the last 7 days, most used first.
  List<AppUsage> get weekApps {
    final sums = <String, int>{};
    final names = <String, String>{};
    for (final d in weekDays) {
      for (final a in d.apps) {
        sums[a.packageName] = (sums[a.packageName] ?? 0) + a.seconds;
        names[a.packageName] = a.appName;
      }
    }
    final list = sums.entries
        .map((e) => AppUsage(
            packageName: e.key, appName: names[e.key] ?? e.key, seconds: e.value))
        .toList();
    list.sort((a, b) => b.seconds.compareTo(a.seconds));
    return list;
  }

  int get daysTracked => weekDays.where((d) => d.totalSeconds > 0).length;

  int get weekAverageSeconds {
    final n = daysTracked;
    if (n == 0) return 0;
    return weekDays.fold<int>(0, (sum, d) => sum + d.totalSeconds) ~/ n;
  }

  int get daysTrackedWithLimits => limits.isEmpty ? 0 : daysTracked;

  /// Every app we know about, for the limit picker.
  List<AppRef> get knownApps {
    final map = <String, String>{};
    for (final a in installed) {
      map[a.packageName] = a.appName;
    }
    for (final d in [...recent, today]) {
      for (final a in d.apps) {
        map.putIfAbsent(a.packageName, () => a.appName);
      }
    }
    for (final l in limits) {
      map.putIfAbsent(l.packageName, () => l.appName);
    }
    final list = map.entries.map((e) => AppRef(e.key, e.value)).toList();
    list.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
    return list;
  }

  /// Number of days this week where no app went over its limit.
  int get daysWithinLimits {
    if (limits.isEmpty) return 0;
    var n = 0;
    for (final d in weekDays) {
      if (d.apps.isEmpty) continue;
      final over = limits.any((l) => d.secondsFor(l.packageName) >= l.limitSeconds);
      if (!over) n++;
    }
    return n;
  }

  // ------------------------------------------------------------ lifecycle
  void _onUser(User? u) {
    final changed = u?.uid != user?.uid;
    user = u;
    authReady = true;
    if (changed) {
      final hadUser = _tickTimer != null;
      _teardown();
      _resetData();
      if (u != null) {
        _startFor(u);
      } else if (hadUser && native.supported) {
        native.setLimits(const []);
        native.stopMonitoring();
      }
    }
    notifyListeners();
  }

  void _startFor(User u) {
    _todayKey = dayKey(DateTime.now());
    today = DayUsage.empty(_todayKey);
    firestore.ensureProfile(u).catchError((_) {});
    _subscribe(u.uid);
    _tickTimer = Timer.periodic(const Duration(seconds: 60), (_) => _tick());
    if (native.supported) {
      refreshNative();
      native.installedApps().then((apps) {
        installed = apps;
        notifyListeners();
      });
    }
    api.ping().then((ok) {
      apiOnline = ok;
      notifyListeners();
    });
  }

  void _subscribe(String uid) {
    void onError(Object e) {
      dataError = 'Could not load your data. Check your connection and Firestore rules.';
      debugPrint('Firestore error: $e');
      notifyListeners();
    }

    _limitsSub = firestore.limits(uid).listen((l) {
      limits = l;
      _gotLimits = true;
      _afterData(limitsChanged: true);
    }, onError: onError);
    _subscribeToday(uid, onError);
    _recentSub = firestore.usageRecent(uid, 14).listen((w) {
      recent = w;
      notifyListeners();
    }, onError: onError);
  }

  void _subscribeToday(String uid, void Function(Object) onError) {
    _todaySub?.cancel();
    _todaySub = firestore.usageDay(uid, _todayKey).listen((d) {
      today = d ?? DayUsage.empty(_todayKey);
      _gotToday = true;
      _afterData();
    }, onError: onError);
  }

  void _afterData({bool limitsChanged = false}) {
    dataError = null;
    _recompute();
    _queuePopups();
    notifyListeners();
    _scheduleApiSync();
    if (limitsChanged) _pushLimitsToNative();
  }

  void _recompute() {
    _statuses = {
      for (final l in limits)
        l.packageName: LimitStatus.compute(l, today.secondsFor(l.packageName))
    };
    alerts = _sortAlerts(_statuses.values.where((s) => s.isAlert));
  }

  List<LimitStatus> _sortAlerts(Iterable<LimitStatus> list) {
    final out = list.toList();
    out.sort((a, b) {
      final rank = (b.state == LimitState.exceeded ? 1 : 0) -
          (a.state == LimitState.exceeded ? 1 : 0);
      return rank != 0 ? rank : b.usedSeconds.compareTo(a.usedSeconds);
    });
    return out;
  }

  Future<void> _tick() async {
    final k = dayKey(DateTime.now());
    if (k != _todayKey && user != null) {
      _todayKey = k;
      _gotToday = false;
      today = DayUsage.empty(k);
      _subscribeToday(user!.uid, (e) => debugPrint('Firestore error: $e'));
      _recompute();
      notifyListeners();
    }
    await refreshNative();
  }

  void _teardown() {
    _limitsSub?.cancel();
    _todaySub?.cancel();
    _recentSub?.cancel();
    _tickTimer?.cancel();
    _syncTimer?.cancel();
    _limitsSub = null;
    _todaySub = null;
    _recentSub = null;
    _tickTimer = null;
    _syncTimer = null;
  }

  void _resetData() {
    limits = const [];
    recent = const [];
    installed = const [];
    alerts = const [];
    _statuses = {};
    _gotLimits = false;
    _gotToday = false;
    dataError = null;
    apiOnline = false;
    _lastUsageSig = '';
    _backfilled = false;
    _popupShown.clear();
    _popupQueue.clear();
    _todayKey = dayKey(DateTime.now());
    today = DayUsage.empty(_todayKey);
  }

  // ------------------------------------------------------------ backend sync
  void _scheduleApiSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 700), _runApiSync);
  }

  Future<void> _runApiSync() async {
    if (user == null) return;
    try {
      final res = await api.sync(date: _todayKey, usage: today.apps, limits: limits);
      apiOnline = true;
      alerts = _sortAlerts(res);
    } catch (e) {
      apiOnline = false;
      debugPrint('API sync failed ($apiBase): $e');
    }
    _queuePopups();
    notifyListeners();
  }

  Future<void> retryApi() async {
    apiOnline = await api.ping();
    notifyListeners();
    if (apiOnline) await _runApiSync();
  }

  // ------------------------------------------------------------ popups
  void _queuePopups() {
    for (final a in alerts) {
      if (a.state != LimitState.exceeded) continue;
      final key = '$_todayKey|${a.packageName}';
      if (_popupShown.add(key)) _popupQueue.add(a);
    }
  }

  bool get hasPopup => _popupQueue.isNotEmpty;

  LimitStatus? takePopup() =>
      _popupQueue.isEmpty ? null : _popupQueue.removeAt(0);

  // ------------------------------------------------------------ phone (Android)
  Future<void> refreshNative() async {
    if (!native.supported || user == null) return;
    final uid = user!.uid;
    nativeStatus = await native.status();
    notifyListeners();
    if (!nativeStatus.usageAccess) return;

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final apps = await native.getUsage(start, now);
    if (apps.isNotEmpty) {
      final day = DayUsage(date: dayKey(now), apps: _sorted(apps));
      final sig = '${day.date}:${day.totalSeconds}:${day.apps.length}';
      if (sig != _lastUsageSig) {
        _lastUsageSig = sig;
        await firestore.saveUsage(uid, day);
      }
    }

    if (!_backfilled) {
      _backfilled = true;
      for (var i = 1; i <= 6; i++) {
        final s = DateTime(now.year, now.month, now.day - i);
        final e = DateTime(now.year, now.month, now.day - i + 1);
        final a = await native.getUsage(s, e);
        if (a.isNotEmpty) {
          await firestore.saveUsage(uid, DayUsage(date: dayKey(s), apps: _sorted(a)));
        }
      }
    }
    await _pushLimitsToNative();
  }

  List<AppUsage> _sorted(List<AppUsage> apps) {
    final list = [...apps]..sort((a, b) => b.seconds.compareTo(a.seconds));
    return list;
  }

  Future<void> _pushLimitsToNative() async {
    if (!native.supported) return;
    await native.setLimits(limits);
    if (limits.isEmpty) {
      await native.stopMonitoring();
    } else if (nativeStatus.usageAccess && nativeStatus.overlay) {
      await native.startMonitoring();
    }
  }

  // ------------------------------------------------------------ actions
  Future<void> saveLimit(AppLimit l) async {
    final uid = user?.uid;
    if (uid == null) return;
    await firestore.saveLimit(uid, l);
  }

  Future<void> deleteLimit(String packageName) async {
    final uid = user?.uid;
    if (uid == null) return;
    await firestore.deleteLimit(uid, packageName);
  }

  Future<void> signOut() => auth.signOut();

  Future<void> updateDisplayName(String name) async {
    await auth.updateDisplayName(name);
    notifyListeners();
  }

  Future<void> resendVerification() => auth.resendVerification();

  Future<void> reloadUser() async {
    await auth.reloadUser();
    notifyListeners();
  }

  Future<void> sendPasswordReset() => auth.sendPasswordReset(email);

  Future<void> deleteMyData() async {
    final uid = user?.uid;
    if (uid == null) return;
    await firestore.deleteAllData(uid);
    _lastUsageSig = '';
  }

  Future<void> deleteAccount() async {
    final uid = user?.uid;
    if (uid == null) return;
    await firestore.deleteAllData(uid);
    await auth.deleteAccount();
  }

  /// Writes a week of believable usage plus three limits, so every screen
  /// has something to show before the phone has reported real data.
  Future<void> seedDemo() async {
    final uid = user?.uid;
    if (uid == null) return;
    final rnd = Random(7);
    const apps = <_Demo>[
      _Demo('com.google.android.youtube', 'YouTube', 75),
      _Demo('com.whatsapp', 'WhatsApp', 58),
      _Demo('com.instagram.android', 'Instagram', 52),
      _Demo('com.android.chrome', 'Chrome', 47),
      _Demo('com.khanacademy.android', 'Khan Academy', 41),
      _Demo('com.spotify.music', 'Spotify', 38),
      _Demo('com.duolingo', 'Duolingo', 34),
      _Demo('notion.id', 'Notion', 22),
    ];
    final now = DateTime.now();
    final days = <DayUsage>[];
    for (var i = 0; i < 7; i++) {
      final date = dayKey(DateTime(now.year, now.month, now.day - i));
      final list = apps.map((a) {
        final factor = i == 0 ? 1.0 : 0.55 + rnd.nextDouble() * 0.9;
        return AppUsage(
          packageName: a.pkg,
          appName: a.name,
          seconds: (a.minutes * factor * 60).round(),
        );
      }).toList()
        ..sort((a, b) => b.seconds.compareTo(a.seconds));
      days.add(DayUsage(date: date, apps: list));
    }
    final demoLimits = <AppLimit>[
      const AppLimit(
          packageName: 'com.instagram.android',
          appName: 'Instagram',
          dailyLimitMinutes: 45),
      const AppLimit(
          packageName: 'com.google.android.youtube',
          appName: 'YouTube',
          dailyLimitMinutes: 90),
      const AppLimit(
          packageName: 'com.whatsapp',
          appName: 'WhatsApp',
          dailyLimitMinutes: 120,
          warnAtPercent: 85),
    ];
    await firestore.saveUsageBatch(uid, days, demoLimits);
  }

  String get apiHost => apiBaseUrl;

  @override
  void dispose() {
    _authSub?.cancel();
    _teardown();
    super.dispose();
  }
}

class _Demo {
  final String pkg;
  final String name;
  final int minutes;
  const _Demo(this.pkg, this.name, this.minutes);
}
