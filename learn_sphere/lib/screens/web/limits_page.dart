import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/limit_editor.dart';
import '../../widgets/orbit.dart';
import 'web_widgets.dart';

class LimitsPage extends StatelessWidget {
  const LimitsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();

    if (app.limits.isEmpty) {
      return Panel(
        child: EmptyState(
          icon: Icons.timer_outlined,
          title: 'No limits yet',
          message: 'Choose an app and how long you want to use it each day. You get a warning first, then a popup when time is up. Limits you set here apply on your phone.',
          actionLabel: 'Add your first limit',
          onAction: () => openLimitEditor(context),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        const gap = 20.0;
        final cols = box.maxWidth >= 1100 ? 3 : (box.maxWidth >= 680 ? 2 : 1);
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final l in app.limits)
              SizedBox(
                width: w,
                child: _LimitTile(limit: l, status: app.statusFor(l.packageName)),
              ),
            SizedBox(width: w, child: const _AddTile()),
          ],
        );
      },
    );
  }
}

class _LimitTile extends StatelessWidget {
  const _LimitTile({required this.limit, required this.status});
  final AppLimit limit;
  final LimitStatus? status;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final state = s?.state ?? LimitState.ok;
    final used = s?.usedSeconds ?? 0;
    final frac = limit.limitSeconds == 0 ? 0.0 : used / limit.limitSeconds;
    final pct = math.min(999, (frac * 100).round());

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: LS.paper,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: LS.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(name: limit.appName, packageName: limit.packageName, size: 44),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(limit.appName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body(17, weight: FontWeight.w600)),
                    Text('${fmtDuration(limit.limitSeconds)} a day',
                        style: body(13.5, color: LS.slate)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              OrbitView(
                size: 118,
                dark: false,
                strokeFactor: 0.085,
                valueFactor: 0.17,
                centerValue: '$pct%',
                centerLabel: 'used',
                entries: [
                  OrbitEntry(
                    packageName: limit.packageName,
                    appName: limit.appName,
                    seconds: used,
                    fraction: frac.clamp(0.0, 1.0).toDouble(),
                    state: state,
                  ),
                ],
              ),
              const SizedBox(width: 22),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill(state),
                    const SizedBox(height: 12),
                    Text(fmtDuration(used), style: display(26)),
                    Text('used today', style: body(13, color: LS.slate)),
                    const SizedBox(height: 6),
                    Text(limitCaption(s), style: body(14, weight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                onPressed: () => openLimitEditor(context, existing: limit),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Edit'),
              ),
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: LS.rose),
                onPressed: () async {
                  final app = context.read<AppState>();
                  final ok = await confirmDialog(
                    context,
                    title: 'Remove limit?',
                    message: '${limit.appName} will no longer have a daily limit.',
                    confirmLabel: 'Remove limit',
                    danger: true,
                  );
                  if (ok) await app.deleteLimit(limit.packageName);
                },
                child: const Text('Remove'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile();

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: () => openLimitEditor(context),
      child: Container(
        height: 306,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: LS.line, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: LS.periwinkle.tint(0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add_rounded, color: LS.periwinkle, size: 28),
            ),
            const SizedBox(height: 14),
            Text('New limit', style: body(16, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
