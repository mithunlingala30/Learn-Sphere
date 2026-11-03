import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/limit_editor.dart';
import 'apps_page.dart';
import 'insights_page.dart';
import 'limits_page.dart';
import 'overview_page.dart';
import 'settings_page.dart';

/// Desktop browser layout: dark rail on the left, dashboard on the right.
class WebShell extends StatefulWidget {
  const WebShell({super.key});

  @override
  State<WebShell> createState() => _WebShellState();
}

class _WebShellState extends State<WebShell> {
  int _page = 0;

  static const _titles = ['Overview', 'Apps', 'Limits', 'Insights', 'Settings'];
  static const _icons = <IconData>[
    Icons.blur_circular_rounded,
    Icons.apps_rounded,
    Icons.timer_outlined,
    Icons.bar_chart_rounded,
    Icons.settings_outlined,
  ];

  Widget _pageFor(int i) {
    switch (i) {
      case 0:
        return OverviewPage(onNavigate: (p) => setState(() => _page = p));
      case 1:
        return const AppsPage();
      case 2:
        return const LimitsPage();
      case 3:
        return const InsightsPage();
      default:
        return const SettingsPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Scaffold(
      backgroundColor: LS.mist,
      body: Row(
        children: [
          _Sidebar(
            page: _page,
            titles: _titles,
            icons: _icons,
            onSelect: (i) => setState(() => _page = i),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(title: _titles[_page], app: app),
                Expanded(
                  child: SingleChildScrollView(
                    child: LayoutBuilder(
                      builder: (context, box) => Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: math.min(1280.0, box.maxWidth),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(40, 8, 40, 56),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              layoutBuilder: (current, previous) => Stack(
                                fit: StackFit.passthrough,
                                alignment: Alignment.topCenter,
                                children: [...previous, if (current != null) current],
                              ),
                              child: KeyedSubtree(
                                key: ValueKey(_page),
                                child: _pageFor(_page),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.page,
    required this.titles,
    required this.icons,
    required this.onSelect,
  });

  final int page;
  final List<String> titles;
  final List<IconData> icons;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return Container(
      width: 268,
      color: LS.space,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Wordmark(size: 20),
          ),
          const SizedBox(height: 40),
          for (var i = 0; i < titles.length; i++)
            _NavItem(
              label: titles[i],
              icon: icons[i],
              selected: i == page,
              badge: i == 2 && app.alerts.isNotEmpty ? app.alerts.length : 0,
              onTap: () => onSelect(i),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 12, 6, 12),
            decoration: BoxDecoration(
              color: LS.spaceRaised,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: LS.marigold, shape: BoxShape.circle),
                  child: Text(
                    app.firstName.isEmpty ? '?' : app.firstName[0].toUpperCase(),
                    style: display(17, color: LS.space),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(14, weight: FontWeight.w600, color: Colors.white)),
                      Text(app.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: body(12, color: LS.onSpaceMuted)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Sign out',
                  onPressed: () => signOutFlow(context),
                  icon: const Icon(Icons.logout_rounded, size: 20, color: LS.onSpaceMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          hoverColor: LS.onSpace.tint(0.06),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: selected ? LS.spaceRaised : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 20,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: selected ? LS.marigold : Colors.transparent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Icon(icon, size: 22, color: selected ? Colors.white : LS.onSpaceMuted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: body(15,
                        weight: FontWeight.w600,
                        color: selected ? Colors.white : LS.onSpaceMuted),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: LS.rose,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text('$badge',
                        style: body(12, weight: FontWeight.w700, color: Colors.white)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.app});
  final String title;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 30, 40, 22),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: display(34)),
                const SizedBox(height: 2),
                Text(
                  '${greeting()}, ${app.firstName}. ${DateFormat('EEEE d MMMM').format(DateTime.now())}.',
                  style: body(14.5, color: LS.slate),
                ),
              ],
            ),
          ),
          _ServerChip(app: app),
          const SizedBox(width: 14),
          FilledButton.icon(
            onPressed: () => openLimitEditor(context),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('New limit'),
          ),
        ],
      ),
    );
  }
}

class _ServerChip extends StatelessWidget {
  const _ServerChip({required this.app});
  final AppState app;

  @override
  Widget build(BuildContext context) {
    final ok = app.apiOnline;
    final c = ok ? LS.lagoon : LS.rose;
    return Tooltip(
      message: ok ? app.apiBase : "Can't reach ${app.apiBase}. Click to retry.",
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: ok ? null : app.retryApi,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: c.tint(0.13),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                ok ? 'Server connected' : 'Server offline',
                style: body(13, weight: FontWeight.w600, color: Color.lerp(c, LS.ink, 0.5)!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
