import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around Firebase Auth with human-readable errors.
class AuthService {
  AuthService([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;
  final FirebaseAuth _auth;

  Stream<User?> get userChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<UserCredential> register(
      String name, String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(), password: password);
    await cred.user?.updateDisplayName(name.trim());
    try {
      await cred.user?.sendEmailVerification();
    } catch (_) {
      // Not fatal: the user can resend from the profile screen.
    }
    await cred.user?.reload();
    return cred;
  }

  /// Google sign-in through Firebase's own provider flow: popup on the web,
  /// system browser sheet on Android / iOS (no extra plugin needed).
  Future<UserCredential> signInWithGoogle() {
    final provider = GoogleAuthProvider()..addScope('email');
    if (kIsWeb) return _auth.signInWithPopup(provider);
    return _auth.signInWithProvider(provider);
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> resendVerification() async =>
      _auth.currentUser?.sendEmailVerification();

  Future<void> reloadUser() async => _auth.currentUser?.reload();

  Future<void> updateDisplayName(String name) async {
    await _auth.currentUser?.updateDisplayName(name.trim());
    await _auth.currentUser?.reload();
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> deleteAccount() async => _auth.currentUser?.delete();

  /// Turns Firebase error codes into sentences a person can act on.
  static String friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address does not look right.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
        case 'invalid-login-credentials':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account with this email already exists. Sign in instead.';
        case 'weak-password':
          return 'Use at least 6 characters for your password.';
        case 'too-many-requests':
          return 'Too many attempts. Wait a few minutes and try again.';
        case 'network-request-failed':
          return 'No connection. Check your internet and try again.';
        case 'popup-closed-by-user':
        case 'cancelled-popup-request':
        case 'web-context-canceled':
        case 'canceled':
          return 'Google sign-in was cancelled.';
        case 'account-exists-with-different-credential':
          return 'This email is registered with a different sign-in method.';
        case 'operation-not-allowed':
          return 'This sign-in method is turned off in the Firebase console.';
        case 'requires-recent-login':
          return 'For security, sign in again and then repeat this action.';
        default:
          return error.message ?? 'Something went wrong. Try again.';
      }
    }
    return 'Something went wrong. Try again.';
  }
}
