import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/common.dart';
import 'web_widgets.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    final profile = Panel(
      title: 'Profile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 68,
                height: 68,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: LS.ink, shape: BoxShape.circle),
                child: Text(
                  app.firstName.isEmpty ? '?' : app.firstName[0].toUpperCase(),
                  style: display(30, color: Colors.white),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.displayName,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: display(26)),
                    Text(app.email, style: body(14.5, color: LS.slate)),
                  ],
                ),
              ),
            ],
          ),
          if (!app.emailVerified) ...[
            const SizedBox(height: 18),
            Banner2(
              color: LS.marigold,
              icon: Icons.mark_email_unread_outlined,
              text: 'Your email is not verified yet. Verify it to keep your account secure.',
              actionLabel: 'Resend email',
              onAction: () => resendVerificationFlow(context),
            ),
          ],
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => editNameFlow(context),
                icon: const Icon(Icons.badge_outlined, size: 18),
                label: const Text('Change name'),
              ),
              OutlinedButton.icon(
                onPressed: () => resetPasswordFlow(context),
                icon: const Icon(Icons.password_rounded, size: 18),
                label: const Text('Reset password'),
              ),
              OutlinedButton.icon(
                onPressed: () => signOutFlow(context),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
    );

    final connection = Panel(
      title: 'Server connection',
      subtitle: 'The Learn Sphere API checks limits and writes the alert messages.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: app.apiOnline ? LS.lagoon : LS.rose,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(app.apiOnline ? 'Connected' : 'Not reachable',
                  style: body(15.5, weight: FontWeight.w600)),
              const Spacer(),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: app.retryApi,
                child: const Text('Test connection'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(app.apiBase, style: body(14, color: LS.slate)),
          const SizedBox(height: 10),
          Text(
            'To use a different server, build the app with --dart-define=API_BASE_URL=https://your-server.',
            style: body(13.5, color: LS.slate, height: 1.45),
          ),
        ],
      ),
    );

    final phone = Panel(
      title: 'Phone tracking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Android phone reads how long each app is used and sends it to your account. This dashboard shows it live, and limits you set here are enforced on the phone.',
            style: body(14.5, color: LS.slate, height: 1.5),
          ),
          const SizedBox(height: 14),
          for (final step in const [
            'Install Learn Sphere on your Android phone and sign in with this account.',
            'Allow usage access, display over other apps, and notifications.',
            'Add a limit. The phone watches it in the background.',
          ])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle_outline_rounded, size: 18, color: LS.periwinkle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(step, style: body(14.5, height: 1.45))),
                ],
              ),
            ),
        ],
      ),
    );

    final data = Panel(
      title: 'Your data',
      subtitle: 'Stored in your Firebase project, visible only to you.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          OutlinedButton.icon(
            onPressed: () => seedDemoFlow(context),
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('Load sample data'),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: LS.rose,
              side: BorderSide(color: LS.rose.tint(0.5)),
            ),
            onPressed: () => deleteDataFlow(context),
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
            label: const Text('Delete my data'),
          ),
        ],
      ),
    );

    final danger = Panel(
      title: 'Delete account',
      subtitle: 'Removes your account, usage history and limits for good.',
      child: Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: LS.rose),
          onPressed: () => deleteAccountFlow(context),
          icon: const Icon(Icons.person_remove_outlined, size: 18),
          label: const Text('Delete account'),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth >= 920) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [profile, const SizedBox(height: 24), phone, const SizedBox(height: 24), danger],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [connection, const SizedBox(height: 24), data],
                ),
              ),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            profile,
            const SizedBox(height: 24),
            connection,
            const SizedBox(height: 24),
            phone,
            const SizedBox(height: 24),
            data,
            const SizedBox(height: 24),
            danger,
          ],
        );
      },
    );
  }
}
