import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/common.dart';
import '../../widgets/limit_editor.dart';
import '../../widgets/orbit.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key, required this.onOpenProfile});
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final width = MediaQuery.sizeOf(context).width;
    final orbitSize = math.min(300.0, width - 40 - 44);
    final entries = app.orbitEntries(5);
    final total = app.today.totalSeconds;
    final delta = app.deltaVsYesterday;
    final apps = app.todayApps;
    final maxSec = apps.isEmpty ? 1 : math.max(1, apps.first.seconds);

    return RefreshIndicator(
      color: LS.periwinkle,
      onRefresh: () async {
        await app.refreshNative();
        await app.retryApi();
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${greeting()}, ${app.firstName}',
                        style: body(14.5, color: LS.slate)),
                    const SizedBox(height: 2),
                    Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                        style: display(28)),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Open your profile',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onOpenProfile,
                  child: Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                        color: LS.ink, shape: BoxShape.circle),
                    child: Text(
                      app.firstName.isEmpty ? '?' : app.firstName[0].toUpperCase(),
                      style: display(20, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          if (app.nativeSupported && !app.nativeStatus.ready) ...[
            Banner2(
              color: LS.marigold,
              icon: Icons.shield_moon_outlined,
              text: 'Allow usage access and "display over other apps" so Learn Sphere can track apps and show limit popups.',
              actionLabel: 'Set up',
              onAction: onOpenProfile,
            ),
            const SizedBox(height: 12),
          ],
          if (app.dataError != null) ...[
            Banner2(
              color: LS.rose,
              icon: Icons.cloud_off_rounded,
              text: app.dataError!,
            ),
            const SizedBox(height: 12),
          ] else if (!app.apiOnline && !app.loading) ...[
            Banner2(
              color: LS.slate,
              icon: Icons.wifi_off_rounded,
              text: "Can't reach the Learn Sphere server. Limits still work from your saved data.",
              actionLabel: 'Retry',
              onAction: app.retryApi,
            ),
            const SizedBox(height: 12),
          ],

          // Orbit hero
          Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            decoration: BoxDecoration(
              color: LS.space,
              borderRadius: BorderRadius.circular(34),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Screen time today',
                          style: body(14.5, color: LS.onSpaceMuted)),
                    ),
                    if (total > 0 && app.yesterdaySeconds > 0)
                      _DeltaChip(delta: delta),
                  ],
                ),
                const SizedBox(height: 18),
                OrbitView(
                  size: orbitSize,
                  entries: entries,
                  centerValue: fmtDuration(total),
                ),
                const SizedBox(height: 18),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      app.loading ? 'Loading your day…' : 'Nothing recorded yet today.',
                      style: body(14, color: LS.onSpaceMuted),
                    ),
                  )
                else
                  OrbitLegend(entries: entries.take(3).toList()),
              ],
            ),
          ),

          // Alerts
          if (app.alerts.isNotEmpty) ...[
            const SizedBox(height: 26),
            const SectionHeader('Needs attention'),
            const SizedBox(height: 12),
            for (final a in app.alerts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AlertTile(status: a),
              ),
          ],

          // Apps
          const SizedBox(height: 26),
          SectionHeader(
            'Apps today',
            trailing: TextButton.icon(
              onPressed: () => openLimitEditor(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add limit'),
            ),
          ),
          const SizedBox(height: 8),
          if (apps.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: LS.paper,
                borderRadius: BorderRadius.circular(28),
              ),
              child: app.loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _emptyApps(context, app),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: LS.paper,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < apps.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: LS.line),
                    _AppRow(
                      usage: apps[i],
                      status: app.statusFor(apps[i].packageName),
                      maxSeconds: maxSec,
                      onTap: () => openLimitEditor(
                        context,
                        existing: app.limitFor(apps[i].packageName),
                        preset: AppRef(apps[i].packageName, apps[i].appName),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _emptyApps(BuildContext context, AppState app) {
    if (app.nativeSupported && !app.nativeStatus.usageAccess) {
      return EmptyState(
        icon: Icons.lock_open_rounded,
        title: 'Allow usage access',
        message: 'Learn Sphere needs permission to see how long you use each app. Nothing leaves your account.',
        actionLabel: 'Open setup',
        onAction: onOpenProfile,
      );
    }
    return EmptyState(
      icon: Icons.hourglass_empty_rounded,
      title: 'No usage yet',
      message: app.nativeSupported
          ? 'Use your phone for a minute and pull down to refresh. Or load sample data to look around.'
          : 'Usage appears here after your Android phone syncs. Or load sample data to look around.',
      actionLabel: 'Load sample data',
      onAction: () => seedDemoFlow(context),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  const _DeltaChip({required this.delta});
  final int delta;

  @override
  Widget build(BuildContext context) {
    final less = delta <= 0;
    final c = less ? LS.lagoon : LS.marigold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.tint(0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(less ? Icons.south_east_rounded : Icons.north_east_rounded,
              size: 14, color: c),
          const SizedBox(width: 4),
          Text(
            '${fmtDuration(delta.abs())} ${less ? 'less' : 'more'} than yesterday',
            style: body(12, weight: FontWeight.w600, color: c),
          ),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.status});
  final LimitStatus status;

  @override
  Widget build(BuildContext context) {
    final over = status.state == LimitState.exceeded;
    final c = statusColor(status.state);
    final text = over
        ? '${status.appName} is ${fmtDuration(status.usedSeconds - (status.limitSeconds ?? 0))} over its limit'
        : '${status.appName}: ${fmtDuration(status.remainingSeconds ?? 0)} left today';
    final app = context.read<AppState>();
    return Material(
      color: c.tint(0.14),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => openLimitEditor(
          context,
          existing: app.limitFor(status.packageName),
          preset: AppRef(status.packageName, status.appName),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AppAvatar(name: status.appName, packageName: status.packageName, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: body(14.5, weight: FontWeight.w600, height: 1.3)),
              ),
              Icon(
                over ? Icons.error_rounded : Icons.schedule_rounded,
                color: Color.lerp(c, LS.ink, 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({
    required this.usage,
    required this.status,
    required this.maxSeconds,
    required this.onTap,
  });

  final AppUsage usage;
  final LimitStatus? status;
  final int maxSeconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final limitS = status?.limitSeconds;
    final frac = limitS != null && limitS > 0
        ? usage.seconds / limitS
        : usage.seconds / maxSeconds * 0.9;
    final barColor = status == null
        ? appColor(usage.packageName)
        : statusColor(status!.state, fallback: appColor(usage.packageName));
    final captionColor = status == null
        ? LS.slate
        : (status!.state == LimitState.exceeded
            ? LS.rose
            : (status!.state == LimitState.warning
                ? Color.lerp(LS.marigold, LS.ink, 0.3)!
                : LS.slate));

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Row(
              children: [
                AppAvatar(name: usage.appName, packageName: usage.packageName),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(usage.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(16, weight: FontWeight.w600)),
                      const SizedBox(height: 1),
                      Text(limitCaption(status),
                          style: body(13, weight: FontWeight.w500, color: captionColor)),
                    ],
                  ),
                ),
                Text(fmtDuration(usage.seconds), style: display(19)),
              ],
            ),
            const SizedBox(height: 11),
            UsageBar(fraction: frac, color: barColor),
          ],
        ),
      ),
    );
  }
}
