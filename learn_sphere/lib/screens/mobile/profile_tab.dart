import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/common.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final ns = app.nativeStatus;
    final native = context.read<AppState>().native;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Row(
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: LS.ink, shape: BoxShape.circle),
              child: Text(
                app.firstName.isEmpty ? '?' : app.firstName[0].toUpperCase(),
                style: display(28, color: Colors.white),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.displayName,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: display(26)),
                  Text(app.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(14, color: LS.slate)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        if (!app.emailVerified) ...[
          Banner2(
            color: LS.marigold,
            icon: Icons.mark_email_unread_outlined,
            text: 'Verify your email to keep your account secure.',
            actionLabel: 'Resend',
            onAction: () => resendVerificationFlow(context),
          ),
          const SizedBox(height: 14),
        ],

        // Phone tracking
        _Group(
          title: 'Phone tracking',
          children: app.nativeSupported
              ? [
                  _Row(
                    icon: Icons.query_stats_rounded,
                    title: 'Usage access',
                    subtitle: 'Lets Learn Sphere read how long you use each app.',
                    trailing: _Granted(ns.usageAccess, onGrant: native.openUsageSettings),
                  ),
                  _Row(
                    icon: Icons.layers_outlined,
                    title: 'Display over other apps',
                    subtitle: 'Shows the popup in the middle of the screen when time is up.',
                    trailing: _Granted(ns.overlay, onGrant: native.openOverlaySettings),
                  ),
                  _Row(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'Warns you before you reach a limit.',
                    trailing: _Granted(ns.notifications, onGrant: native.requestNotifications),
                  ),
                  _Row(
                    icon: Icons.radar_rounded,
                    title: 'Limit monitor',
                    subtitle: app.limits.isEmpty
                        ? 'Starts once you add a limit.'
                        : (ns.monitoring ? 'Watching your limits in the background.' : 'Not running yet. Finish the steps above.'),
                    trailing: _Dot(ns.monitoring),
                  ),
                ]
              : [
                  const _Row(
                    icon: Icons.phone_android_rounded,
                    title: 'Tracking runs on Android',
                    subtitle: 'Install Learn Sphere on your Android phone and sign in. Usage syncs here.',
                  ),
                ],
        ),
        const SizedBox(height: 14),

        _Group(
          title: 'Connection',
          children: [
            _Row(
              icon: app.apiOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              title: 'Learn Sphere server',
              subtitle: app.apiOnline ? 'Connected to ${app.apiBase}' : "Can't reach ${app.apiBase}",
              trailing: app.apiOnline
                  ? const _Dot(true)
                  : TextButton(onPressed: app.retryApi, child: const Text('Retry')),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _Group(
          title: 'Your data',
          children: [
            _Row(
              icon: Icons.auto_awesome_outlined,
              title: 'Load sample data',
              subtitle: 'Adds a week of example usage and three limits.',
              onTap: () => seedDemoFlow(context),
            ),
            _Row(
              icon: Icons.delete_sweep_outlined,
              title: 'Delete my data',
              subtitle: 'Removes usage history and limits.',
              danger: true,
              onTap: () => deleteDataFlow(context),
            ),
          ],
        ),
        const SizedBox(height: 14),

        _Group(
          title: 'Account',
          children: [
            _Row(
              icon: Icons.badge_outlined,
              title: 'Change name',
              subtitle: app.displayName,
              onTap: () => editNameFlow(context),
            ),
            _Row(
              icon: Icons.password_rounded,
              title: 'Reset password',
              subtitle: 'We email a reset link to ${app.email}.',
              onTap: () => resetPasswordFlow(context),
            ),
            _Row(
              icon: Icons.logout_rounded,
              title: 'Sign out',
              onTap: () => signOutFlow(context),
            ),
            _Row(
              icon: Icons.person_remove_outlined,
              title: 'Delete account',
              subtitle: 'Removes your account and everything in it.',
              danger: true,
              onTap: () => deleteAccountFlow(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 0, 8),
          child: Text(title, style: display(18)),
        ),
        Container(
          decoration: BoxDecoration(
            color: LS.paper,
            borderRadius: BorderRadius.circular(26),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 62, color: LS.line),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = danger ? LS.rose : LS.ink;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: danger ? LS.rose : LS.periwinkle),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: body(15.5, weight: FontWeight.w600, color: c)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: body(13, color: LS.slate, height: 1.35)),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 10), trailing!],
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.on);
  final bool on;

  @override
  Widget build(BuildContext context) => Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: on ? LS.lagoon : LS.line,
          shape: BoxShape.circle,
        ),
      );
}

class _Granted extends StatelessWidget {
  const _Granted(this.granted, {required this.onGrant});
  final bool granted;
  final Future<void> Function() onGrant;

  @override
  Widget build(BuildContext context) {
    if (granted) {
      return const Icon(Icons.check_circle_rounded, color: LS.lagoon);
    }
    return FilledButton(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        backgroundColor: LS.periwinkle,
      ),
      onPressed: () => onGrant(),
      child: const Text('Allow'),
    );
  }
}
