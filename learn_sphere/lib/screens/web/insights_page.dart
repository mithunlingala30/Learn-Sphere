import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/common.dart';
import 'web_widgets.dart';

class InsightsPage extends StatelessWidget {
  const InsightsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (app.daysTracked == 0) {
      return Panel(
        child: EmptyState(
          icon: Icons.insights_rounded,
          title: 'Nothing to chart yet',
          message: 'Once a day of usage is recorded, your week shows up here.',
          actionLabel: 'Load sample data',
          onAction: () => seedDemoFlow(context),
        ),
      );
    }

    final weekApps = app.weekApps;
    final top = weekApps.isEmpty ? null : weekApps.first;
    final total = weekApps.fold<int>(0, (s, a) => s + a.seconds);
    final maxApp = weekApps.isEmpty ? 1 : math.max(1, weekApps.first.seconds);
    final overToday = app.alerts.where((a) => a.state == LimitState.exceeded).length;

    final tiles = <Widget>[
      StatTile(
        label: 'Daily average',
        value: fmtDuration(app.weekAverageSeconds),
        caption: 'across ${app.daysTracked} tracked ${app.daysTracked == 1 ? 'day' : 'days'}',
      ),
      StatTile(
        label: 'Most used this week',
        value: top?.appName ?? 'None',
        caption: top == null ? null : fmtDuration(top.seconds),
      ),
      StatTile(
        label: 'Days within every limit',
        value: app.limits.isEmpty ? 'No limits' : '${app.daysWithinLimits} of ${app.daysTracked}',
        caption: app.limits.isEmpty ? 'Add a limit to track this' : null,
        tint: LS.lagoon,
      ),
      StatTile(
        label: 'Over limit right now',
        value: '$overToday',
        caption: overToday == 1 ? 'app today' : 'apps today',
        tint: overToday > 0 ? LS.rose : null,
      ),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        final cols = box.maxWidth >= 1000 ? 4 : 2;
        const gap = 20.0;
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Panel(
              title: 'Screen time, last 7 days',
              subtitle: 'Hover a bar to read that day.',
              child: WeekBars(days: app.weekDays, height: 260),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final t in tiles) SizedBox(width: w, child: t)],
            ),
            const SizedBox(height: 24),
            Panel(
              title: 'This week by app',
              subtitle: 'Share of your ${fmtDuration(total)} total.',
              child: Column(
                children: [
                  for (final a in weekApps.take(8))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 9),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                AppAvatar(name: a.appName, packageName: a.packageName, size: 36),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(a.appName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: body(15, weight: FontWeight.w600)),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 5,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: UsageBar(
                                fraction: a.seconds / maxApp,
                                color: appColor(a.packageName),
                                height: 8,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 120,
                            child: Text(
                              '${fmtDuration(a.seconds)}  ${total == 0 ? 0 : (a.seconds / total * 100).round()}%',
                              textAlign: TextAlign.right,
                              style: body(14.5, weight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
