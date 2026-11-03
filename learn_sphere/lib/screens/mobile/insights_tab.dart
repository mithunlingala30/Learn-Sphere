import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/common.dart';

class InsightsTab extends StatelessWidget {
  const InsightsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final week = app.weekDays;
    final weekApps = app.weekApps;
    final hasData = app.daysTracked > 0;
    final top = weekApps.isEmpty ? null : weekApps.first;
    final maxApp = weekApps.isEmpty ? 1 : math.max(1, weekApps.first.seconds);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Insights', style: display(32)),
        const SizedBox(height: 4),
        Text('The last 7 days at a glance.', style: body(14.5, color: LS.slate)),
        const SizedBox(height: 18),
        if (!hasData)
          Container(
            decoration: BoxDecoration(
              color: LS.paper,
              borderRadius: BorderRadius.circular(28),
            ),
            child: EmptyState(
              icon: Icons.insights_rounded,
              title: 'Nothing to chart yet',
              message: 'Once a day of usage is recorded, your week shows up here.',
              actionLabel: 'Load sample data',
              onAction: () => seedDemoFlow(context),
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: LS.paper,
              borderRadius: BorderRadius.circular(28),
            ),
            child: WeekBars(days: week),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Daily average',
                  value: fmtDuration(app.weekAverageSeconds),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(
                  label: 'Most used',
                  value: top?.appName ?? 'None',
                  small: true,
                  caption: top == null ? null : fmtDuration(top.seconds),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Stat(
            label: 'Days within every limit',
            value: app.limits.isEmpty
                ? 'No limits set'
                : '${app.daysWithinLimits} of ${app.daysTracked}',
            tint: LS.lagoon,
            wide: true,
          ),
          const SizedBox(height: 26),
          const SectionHeader('This week by app'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
            decoration: BoxDecoration(
              color: LS.paper,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              children: [
                for (var i = 0; i < math.min(6, weekApps.length); i++) ...[
                  if (i > 0) const Divider(height: 1, color: LS.line),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            AppAvatar(
                                name: weekApps[i].appName,
                                packageName: weekApps[i].packageName,
                                size: 36),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(weekApps[i].appName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: body(15.5, weight: FontWeight.w600)),
                            ),
                            Text(fmtDuration(weekApps[i].seconds),
                                style: display(17)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        UsageBar(
                          fraction: weekApps[i].seconds / maxApp,
                          color: appColor(weekApps[i].packageName),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    this.caption,
    this.small = false,
    this.tint,
    this.wide = false,
  });

  final String label;
  final String value;
  final String? caption;
  final bool small;
  final Color? tint;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? double.infinity : null,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tint == null ? LS.paper : tint!.tint(0.16),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: body(13, color: LS.slate)),
          const SizedBox(height: 6),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: display(small ? 20 : 28)),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(caption!, style: body(13, color: LS.slate)),
          ],
        ],
      ),
    );
  }
}
