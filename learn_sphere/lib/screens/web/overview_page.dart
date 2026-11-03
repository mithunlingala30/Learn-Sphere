import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/common.dart';
import '../../widgets/limit_editor.dart';
import '../../widgets/orbit.dart';
import 'web_widgets.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key, required this.onNavigate});
  final ValueChanged<int> onNavigate;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final entries = app.orbitEntries(5);

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 920;

        final orbit = OrbitView(
          size: wide ? 380 : 320,
          entries: entries,
          centerValue: fmtDuration(app.today.totalSeconds),
        );

        final summary = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_headline(app),
                style: display(38, color: Colors.white, height: 1.08, letterSpacing: -1)),
            const SizedBox(height: 12),
            Text(_subline(app), style: body(16, color: LS.onSpaceMuted, height: 1.45)),
            if (app.today.totalSeconds > 0 && app.yesterdaySeconds > 0) ...[
              const SizedBox(height: 18),
              DeltaChip(delta: app.deltaVsYesterday),
            ],
            const SizedBox(height: 26),
            if (entries.isEmpty)
              _noData(context, app)
            else ...[
              Divider(height: 1, color: LS.onSpace.tint(0.12)),
              const SizedBox(height: 10),
              OrbitLegend(entries: entries),
            ],
          ],
        );

        final hero = Panel(
          dark: true,
          padding: EdgeInsets.all(wide ? 44 : 28),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    orbit,
                    const SizedBox(width: 56),
                    Expanded(child: summary),
                  ],
                )
              : Column(children: [orbit, const SizedBox(height: 32), summary]),
        );

        final week = Panel(
          title: 'This week',
          subtitle: 'Hover a bar to read that day.',
          child: WeekBars(days: app.weekDays, height: 220),
        );

        final attention = Panel(
          title: 'Needs attention',
          subtitle: app.limits.isEmpty ? 'Limits you set show up here.' : null,
          child: app.alerts.isEmpty
              ? _allClear(app)
              : Column(
                  children: [for (final a in app.alerts) _AlertRow(status: a)],
                ),
        );

        final appsPanel = Panel(
          title: 'Apps today',
          trailing: TextButton(
            onPressed: () => onNavigate(1),
            child: const Text('See all apps'),
          ),
          child: AppsTable(
            apps: app.todayApps.take(6).toList(),
            emptyMessage: 'Apps show up here once they have been used today.',
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            const SizedBox(height: 24),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: week),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: attention),
                ],
              )
            else ...[
              week,
              const SizedBox(height: 24),
              attention,
            ],
            const SizedBox(height: 24),
            appsPanel,
          ],
        );
      },
    );
  }

  Widget _noData(BuildContext context, AppState app) {
    if (app.loading) {
      return Text('Loading…', style: body(14.5, color: LS.onSpaceMuted));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          app.nativeSupported
              ? 'Use your phone for a minute, then pull down on Today to sync.'
              : 'Usage appears here after your Android phone syncs. Or look around with sample data.',
          style: body(14.5, color: LS.onSpaceMuted, height: 1.5),
        ),
        const SizedBox(height: 14),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: LS.marigold,
            foregroundColor: LS.space,
            minimumSize: const Size(0, 46),
          ),
          onPressed: () => seedDemoFlow(context),
          child: const Text('Load sample data'),
        ),
      ],
    );
  }

  Widget _allClear(AppState app) => Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: LS.lagoon.tint(0.18), shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: LS.lagoon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              app.limits.isEmpty
                  ? 'No limits set yet. Add one to get warnings and the time-is-up popup.'
                  : 'All clear. No app is close to its limit.',
              style: body(14.5, color: LS.slate, height: 1.45),
            ),
          ),
        ],
      );

  String _headline(AppState app) {
    if (app.loading) return 'Loading your day…';
    if (app.today.totalSeconds == 0) return 'Nothing recorded yet today.';
    final over = app.alerts.where((a) => a.state == LimitState.exceeded).toList();
    if (over.isNotEmpty) {
      final a = over.first;
      if (over.length == 1) {
        return '${a.appName} is ${fmtDuration(a.usedSeconds - (a.limitSeconds ?? 0))} past its limit.';
      }
      return '${a.appName} and ${over.length - 1} more are past their limits.';
    }
    if (app.alerts.isNotEmpty) {
      final a = app.alerts.first;
      return '${a.appName} has ${fmtDuration(a.remainingSeconds ?? 0)} left today.';
    }
    return app.limits.isEmpty ? 'Set a limit to stay in control.' : 'Every limit is on track.';
  }

  String _subline(AppState app) {
    final n = app.today.apps.length;
    if (n == 0) return 'Your rings fill as you use apps through the day.';
    return "You've spent ${fmtDuration(app.today.totalSeconds)} across $n ${n == 1 ? 'app' : 'apps'} today.";
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.status});
  final LimitStatus status;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final over = status.state == LimitState.exceeded;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => openLimitEditor(
        context,
        existing: app.limitFor(status.packageName),
        preset: AppRef(status.packageName, status.appName),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Row(
          children: [
            AppAvatar(name: status.appName, packageName: status.packageName, size: 42),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(status.appName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: body(15.5, weight: FontWeight.w600)),
                  Text(
                    over
                        ? '${fmtDuration(status.usedSeconds)} used, limit ${fmtDuration(status.limitSeconds ?? 0)}'
                        : '${fmtDuration(status.remainingSeconds ?? 0)} left of ${fmtDuration(status.limitSeconds ?? 0)}',
                    style: body(13, color: LS.slate),
                  ),
                ],
              ),
            ),
            StatusPill(status.state),
          ],
        ),
      ),
    );
  }
}
