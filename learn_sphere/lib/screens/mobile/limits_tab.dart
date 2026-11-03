import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/limit_editor.dart';

class LimitsTab extends StatelessWidget {
  const LimitsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final limits = app.limits;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openLimitEditor(context),
        backgroundColor: LS.ink,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add_rounded),
        label: Text('Add limit', style: body(15, weight: FontWeight.w600, color: Colors.white)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
        children: [
          Text('Limits', style: display(32)),
          const SizedBox(height: 4),
          Text(
            limits.isEmpty
                ? 'Set a daily time for any app.'
                : '${limits.length} ${limits.length == 1 ? 'app has' : 'apps have'} a daily limit. Swipe left to remove one.',
            style: body(14.5, color: LS.slate, height: 1.4),
          ),
          const SizedBox(height: 18),
          if (limits.isEmpty)
            Container(
              decoration: BoxDecoration(
                color: LS.paper,
                borderRadius: BorderRadius.circular(28),
              ),
              child: EmptyState(
                icon: Icons.timer_outlined,
                title: 'No limits yet',
                message: 'Pick an app and choose how long you want to use it each day. You get a warning first, then a popup when time is up.',
                actionLabel: 'Add a limit',
                onAction: () => openLimitEditor(context),
              ),
            )
          else
            for (final l in limits)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _LimitCard(limit: l, status: app.statusFor(l.packageName)),
              ),
        ],
      ),
    );
  }
}

class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.limit, required this.status});
  final AppLimit limit;
  final LimitStatus? status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final state = s?.state ?? LimitState.ok;
    final used = s?.usedSeconds ?? 0;
    final frac = limit.limitSeconds == 0 ? 0.0 : used / limit.limitSeconds;
    final color = statusColor(state);

    return Dismissible(
      key: ValueKey('limit-${limit.packageName}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => confirmDialog(
        context,
        title: 'Remove limit?',
        message: '${limit.appName} will no longer have a daily limit.',
        confirmLabel: 'Remove limit',
        danger: true,
      ),
      onDismissed: (_) => context.read<AppState>().deleteLimit(limit.packageName),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: LS.rose,
          borderRadius: BorderRadius.circular(26),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      child: Material(
        color: LS.paper,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: () => openLimitEditor(context, existing: limit),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    AppAvatar(name: limit.appName, packageName: limit.packageName, size: 46),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(limit.appName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: body(17, weight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${fmtDuration(limit.limitSeconds)} a day',
                              style: body(13.5, color: LS.slate)),
                        ],
                      ),
                    ),
                    StatusPill(state),
                  ],
                ),
                const SizedBox(height: 16),
                UsageBar(fraction: frac, color: color, height: 8),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('${fmtDuration(used)} used',
                        style: body(13.5, weight: FontWeight.w600)),
                    const Spacer(),
                    Text(limitCaption(s), style: body(13.5, color: LS.slate)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
