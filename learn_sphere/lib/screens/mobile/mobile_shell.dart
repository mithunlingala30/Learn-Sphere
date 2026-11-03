import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import 'home_tab.dart';
import 'insights_tab.dart';
import 'limits_tab.dart';
import 'profile_tab.dart';

/// Phone layout: four tabs and a floating bottom bar.
class MobileShell extends StatefulWidget {
  const MobileShell({super.key});

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final app = context.read<AppState>();
      app.refreshNative(); // picks up permissions granted in system settings
      app.reloadUser(); // picks up a verified email
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _index,
          children: [
            HomeTab(onOpenProfile: () => setState(() => _index = 3)),
            const LimitsTab(),
            const InsightsTab(),
            const ProfileTab(),
          ],
        ),
      ),
      bottomNavigationBar: _NavBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({required this.index, required this.onChanged});
  final int index;
  final ValueChanged<int> onChanged;

  static const _items = <(String, IconData)>[
    ('Today', Icons.blur_circular_rounded),
    ('Limits', Icons.timer_outlined),
    ('Insights', Icons.bar_chart_rounded),
    ('You', Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: LS.space,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == index,
                    label: _items[i].$1,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => onChanged(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: i == index ? LS.onSpace.tint(0.1) : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _items[i].$2,
                              size: 24,
                              color: i == index ? LS.marigold : LS.onSpaceMuted,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _items[i].$1,
                              style: body(11.5,
                                  weight: FontWeight.w600,
                                  color: i == index ? Colors.white : LS.onSpaceMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
