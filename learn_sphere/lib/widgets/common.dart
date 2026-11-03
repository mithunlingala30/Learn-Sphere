import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../theme/tokens.dart';

String greeting() {
  final h = DateTime.now().hour;
  if (h < 5) return 'Still up';
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

/// "12m over" / "28m left" / "No limit".
String limitCaption(LimitStatus? s) {
  if (s == null || s.limitSeconds == null) return 'No limit';
  if (s.state == LimitState.exceeded) {
    return '${fmtDuration(s.usedSeconds - s.limitSeconds!)} over';
  }
  return '${fmtDuration(s.remainingSeconds ?? 0)} left';
}

/// Rounded square with the app's initial; no icon fetching needed.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    required this.packageName,
    this.size = 44,
  });

  final String name;
  final String packageName;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = appColor(packageName);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.tint(0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(initial, style: display(size * 0.44, color: c)),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.state, {super.key, this.dark = false});
  final LimitState state;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final c = statusColor(state, fallback: LS.slate);
    final text = dark ? c : Color.lerp(c, LS.ink, 0.5)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.tint(dark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(statusLabel(state),
              style: body(12, weight: FontWeight.w600, color: text)),
        ],
      ),
    );
  }
}

class UsageBar extends StatelessWidget {
  const UsageBar({
    super.key,
    required this.fraction,
    required this.color,
    this.height = 6,
    this.dark = false,
  });

  final double fraction;
  final Color color;
  final double height;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final target = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0).toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: ColoredBox(
                  color: dark ? LS.onSpace.tint(0.12) : LS.ink.tint(0.08)),
            ),
            Positioned.fill(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: target),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: v,
                    heightFactor: 1,
                    child: ColoredBox(color: color),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Seven bars, newest on the right. Tap or hover a bar to read its total.
class WeekBars extends StatefulWidget {
  const WeekBars({
    super.key,
    required this.days,
    this.height = 170,
    this.dark = false,
  });

  final List<DayUsage> days;
  final double height;
  final bool dark;

  @override
  State<WeekBars> createState() => _WeekBarsState();
}

class _WeekBarsState extends State<WeekBars> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    if (days.isEmpty) return const SizedBox.shrink();
    final sel = (_selected ?? days.length - 1).clamp(0, days.length - 1);
    final maxSec = days.fold<int>(1, (m, d) => math.max(m, d.totalSeconds));
    final fg = widget.dark ? Colors.white : LS.ink;
    final muted = widget.dark ? LS.onSpaceMuted : LS.slate;
    final idle = widget.dark ? LS.onSpace.tint(0.16) : LS.ink.tint(0.12);
    final barArea = widget.height - 26;

    final selDate = parseDayKey(days[sel].date);
    final isToday = sel == days.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(fmtDuration(days[sel].totalSeconds),
                style: display(26, color: fg)),
            const SizedBox(width: 10),
            Text(
              isToday ? 'Today' : DateFormat('EEEE d MMM').format(selDate),
              style: body(14, color: muted),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: widget.height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < days.length; i++)
                Expanded(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    onEnter: (_) => setState(() => _selected = i),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _selected = i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                              begin: 0,
                              end: days[i].totalSeconds == 0
                                  ? 3
                                  : math.max(
                                      6, days[i].totalSeconds / maxSec * barArea),
                            ),
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeOutCubic,
                            builder: (context, h, _) => Container(
                              height: h,
                              margin: const EdgeInsets.symmetric(horizontal: 5),
                              decoration: BoxDecoration(
                                color: i == sel ? LS.periwinkle : idle,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('E').format(parseDayKey(days[i].date)),
                            style: body(11,
                                weight: i == days.length - 1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: i == sel ? fg : muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.dark = false});
  final String title;
  final Widget? trailing;
  final bool dark;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(title,
                style: display(20, color: dark ? Colors.white : LS.ink)),
          ),
          if (trailing != null) trailing!,
        ],
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.dark = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white : LS.ink;
    final muted = dark ? LS.onSpaceMuted : LS.slate;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: LS.periwinkle.tint(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: LS.periwinkle),
          ),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center, style: display(20, color: fg)),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Text(message,
                textAlign: TextAlign.center,
                style: body(14, color: muted, height: 1.45)),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 18),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class Banner2 extends StatelessWidget {
  const Banner2({
    super.key,
    required this.color,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  final Color color;
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
          color: color.tint(0.13),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Color.lerp(color, LS.ink, 0.35), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: body(13.5, height: 1.35)),
            ),
            if (actionLabel != null)
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool danger = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: LS.paper,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: display(22)),
      content: Text(message, style: body(14.5, height: 1.45)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text('Cancel', style: body(14, color: LS.slate, weight: FontWeight.w600)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: danger ? LS.rose : LS.ink,
            minimumSize: const Size(0, 44),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}

/// Drawer that slides in from the right (used on the web layout).
Future<T?> showSideSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double width = 460,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: LS.space.tint(0.55),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (ctx, a, b) => Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: LS.mist,
        clipBehavior: Clip.antiAlias,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(28)),
        child: SizedBox(
          width: math.min(width, MediaQuery.sizeOf(ctx).width),
          height: double.infinity,
          child: builder(ctx),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
      child: child,
    ),
  );
}
