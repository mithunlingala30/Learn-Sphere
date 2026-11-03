import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/models.dart';

/// All persistent data lives in Firestore under /users/{uid}:
///   limits/{packageName}  -> AppLimit
///   usage/{yyyy-MM-dd}    -> DayUsage
class FirestoreService {
  FirestoreService([FirebaseFirestore? db])
      : _db = db ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      _db.collection('users').doc(uid);

  Future<void> ensureProfile(User u) => _user(u.uid).set({
        'email': u.email,
        'displayName': u.displayName,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Stream<List<AppLimit>> limits(String uid) =>
      _user(uid).collection('limits').snapshots().map((snap) {
        final list = snap.docs.map((d) => AppLimit.fromMap(d.data())).toList();
        list.sort((a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()));
        return list;
      });

  Stream<DayUsage?> usageDay(String uid, String key) =>
      _user(uid).collection('usage').doc(key).snapshots().map(
          (d) => d.exists && d.data() != null ? DayUsage.fromMap(d.data()!) : null);

  /// Most recent days first.
  Stream<List<DayUsage>> usageRecent(String uid, int days) => _user(uid)
      .collection('usage')
      .orderBy('date', descending: true)
      .limit(days)
      .snapshots()
      .map((snap) => snap.docs.map((d) => DayUsage.fromMap(d.data())).toList());

  Future<void> saveLimit(String uid, AppLimit l) =>
      _user(uid).collection('limits').doc(l.packageName).set(l.toMap());

  Future<void> deleteLimit(String uid, String packageName) =>
      _user(uid).collection('limits').doc(packageName).delete();

  Future<void> saveUsage(String uid, DayUsage d) =>
      _user(uid).collection('usage').doc(d.date).set({
        ...d.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> saveUsageBatch(
      String uid, List<DayUsage> days, List<AppLimit> limits) async {
    final batch = _db.batch();
    for (final d in days) {
      batch.set(_user(uid).collection('usage').doc(d.date), {
        ...d.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    for (final l in limits) {
      batch.set(_user(uid).collection('limits').doc(l.packageName), l.toMap());
    }
    await batch.commit();
  }

  /// Removes limits and usage history (not the account itself).
  Future<void> deleteAllData(String uid) async {
    for (final name in ['limits', 'usage']) {
      final snap = await _user(uid).collection(name).get();
      // Firestore batches are limited to 500 writes.
      for (var i = 0; i < snap.docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in snap.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }
    await _user(uid).delete();
  }
}
