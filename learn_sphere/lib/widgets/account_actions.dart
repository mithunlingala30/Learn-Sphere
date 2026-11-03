import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'common.dart';

void _toast(ScaffoldMessengerState m, String text) =>
    m.showSnackBar(SnackBar(content: Text(text)));

Future<void> editNameFlow(BuildContext context) async {
  final app = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final ctrl = TextEditingController(text: app.displayName);
  final name = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: LS.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Your name', style: display(22)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        style: body(16),
        decoration: fieldDecoration('Name'),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text('Cancel', style: body(14, color: LS.slate, weight: FontWeight.w600)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
          child: const Text('Save name'),
        ),
      ],
    ),
  );
  if (name == null || name.isEmpty) return;
  try {
    await app.updateDisplayName(name);
    _toast(messenger, 'Name updated');
  } catch (e) {
    _toast(messenger, AuthService.friendlyError(e));
  }
}

Future<void> resetPasswordFlow(BuildContext context) async {
  final app = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await app.sendPasswordReset();
    _toast(messenger, 'Reset link sent to ${app.email}');
  } catch (e) {
    _toast(messenger, AuthService.friendlyError(e));
  }
}

Future<void> resendVerificationFlow(BuildContext context) async {
  final app = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await app.resendVerification();
    _toast(messenger, 'Verification email sent to ${app.email}');
  } catch (e) {
    _toast(messenger, AuthService.friendlyError(e));
  }
}

Future<void> signOutFlow(BuildContext context) async {
  final app = context.read<AppState>();
  final ok = await confirmDialog(
    context,
    title: 'Sign out?',
    message: 'Limits keep working on your phone. Sign in again any time to see your data.',
    confirmLabel: 'Sign out',
  );
  if (ok) await app.signOut();
}

Future<void> seedDemoFlow(BuildContext context) async {
  final app = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  try {
    await app.seedDemo();
    _toast(messenger, 'Sample data loaded');
  } catch (_) {
    _toast(messenger, 'Could not load sample data. Check your Firestore rules.');
  }
}

Future<void> deleteDataFlow(BuildContext context) async {
  final app = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final ok = await confirmDialog(
    context,
    title: 'Delete all your data?',
    message: 'This removes your usage history and every limit. Your account stays.',
    confirmLabel: 'Delete data',
    danger: true,
  );
  if (!ok) return;
  try {
    await app.deleteMyData();
    _toast(messenger, 'Your data was deleted');
  } catch (_) {
    _toast(messenger, 'Could not delete your data. Try again.');
  }
}

Future<void> deleteAccountFlow(BuildContext context) async {
  final app = context.read<AppState>();
  final messenger = ScaffoldMessenger.of(context);
  final ok = await confirmDialog(
    context,
    title: 'Delete your account?',
    message: 'Your account, usage history and limits are removed for good. This cannot be undone.',
    confirmLabel: 'Delete account',
    danger: true,
  );
  if (!ok) return;
  try {
    await app.deleteAccount();
  } catch (e) {
    _toast(messenger, AuthService.friendlyError(e));
  }
}
