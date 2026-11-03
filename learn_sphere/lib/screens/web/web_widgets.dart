import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/common.dart';
import '../../widgets/limit_editor.dart';

/// Flat, hairline-bordered surface used across the dashboard.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(28),
    this.dark = false,
  });

  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets padding;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? LS.space : LS.paper,
        borderRadius: BorderRadius.circular(30),
        border: dark ? null : Border.all(color: LS.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!, style: display(22, color: dark ? Colors.white : LS.ink)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle!,
                            style: body(14, color: dark ? LS.onSpaceMuted : LS.slate)),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 22),
          ],
          child,
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.caption,
    this.tint,
  });

  final String label;
  final String value;
  final String? caption;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: tint == null ? LS.paper : tint!.tint(0.15),
        borderRadius: BorderRadius.circular(26),
        border: tint == null ? Border.all(color: LS.line) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: body(13.5, color: LS.slate)),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: display(30)),
          if (caption != null) ...[
            const SizedBox(height: 3),
            Text(caption!, style: body(13.5, color: LS.slate)),
          ],
        ],
      ),
    );
  }
}

/// Table of apps with usage, limit and status; click a row to edit its limit.
class AppsTable extends StatelessWidget {
  const AppsTable({super.key, required this.apps, this.emptyMessage = 'No apps to show.'});

  final List<AppUsage> apps;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (apps.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Center(child: Text(emptyMessage, style: body(14.5, color: LS.slate))),
      );
    }
    final maxSec = math.max(1, apps.map((a) => a.seconds).reduce(math.max));

    Widget head(String t) => Text(t, style: body(12.5, weight: FontWeight.w600, color: LS.slate));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: Row(
            children: [
              Expanded(flex: 5, child: head('App')),
              Expanded(flex: 4, child: head('Used today')),
              Expanded(flex: 3, child: head('Daily limit')),
              Expanded(flex: 3, child: head('Status')),
              const SizedBox(width: 44),
            ],
          ),
        ),
        const Divider(height: 1, color: LS.line),
        const SizedBox(height: 6),
        for (final a in apps)
          _TableRow(
            usage: a,
            limit: app.limitFor(a.packageName),
            status: app.statusFor(a.packageName),
            maxSeconds: maxSec,
          ),
      ],
    );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.usage,
    required this.limit,
    required this.status,
    required this.maxSeconds,
  });

  final AppUsage usage;
  final AppLimit? limit;
  final LimitStatus? status;
  final int maxSeconds;

  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final u = widget.usage;
    final s = widget.status;
    final limitS = s?.limitSeconds;
    final frac = limitS != null && limitS > 0
        ? u.seconds / limitS
        : u.seconds / widget.maxSeconds * 0.9;
    final color = s == null
        ? appColor(u.packageName)
        : statusColor(s.state, fallback: appColor(u.packageName));

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => openLimitEditor(
          context,
          existing: widget.limit,
          preset: AppRef(u.packageName, u.appName),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _hover ? LS.mist.tint(0.8) : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Row(
                  children: [
                    AppAvatar(name: u.appName, packageName: u.packageName, size: 40),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(u.appName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(15.5, weight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Padding(
                  padding: const EdgeInsets.only(right: 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fmtDuration(u.seconds), style: display(18)),
                      const SizedBox(height: 7),
                      UsageBar(fraction: frac, color: color, height: 5),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.limit == null ? 'No limit' : fmtDuration(widget.limit!.limitSeconds),
                      style: body(14.5, weight: FontWeight.w600),
                    ),
                    if (s != null && s.limitSeconds != null)
                      Text(limitCaption(s), style: body(12.5, color: LS.slate)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: s == null
                      ? Text('Not set', style: body(13.5, color: LS.slate))
                      : StatusPill(s.state),
                ),
              ),
              SizedBox(
                width: 44,
                child: Icon(
                  widget.limit == null ? Icons.add_rounded : Icons.tune_rounded,
                  size: 20,
                  color: _hover ? LS.periwinkle : LS.slate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "18m less than yesterday" chip (dark surfaces).
class DeltaChip extends StatelessWidget {
  const DeltaChip({super.key, required this.delta});
  final int delta;

  @override
  Widget build(BuildContext context) {
    final less = delta <= 0;
    final c = less ? LS.lagoon : LS.marigold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: c.tint(0.18),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(less ? Icons.south_east_rounded : Icons.north_east_rounded,
              size: 16, color: c),
          const SizedBox(width: 6),
          Text(
            '${fmtDuration(delta.abs())} ${less ? 'less' : 'more'} than yesterday',
            style: body(13.5, weight: FontWeight.w600, color: c),
          ),
        ],
      ),
    );
  }
}
