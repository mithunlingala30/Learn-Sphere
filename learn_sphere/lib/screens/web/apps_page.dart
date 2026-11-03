import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/account_actions.dart';
import '../../widgets/common.dart';
import 'web_widgets.dart';

enum _Filter { all, limited, attention }

class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  final _search = TextEditingController();
  _Filter _filter = _Filter.all;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final q = _search.text.trim().toLowerCase();

    var apps = app.todayApps.where((a) {
      if (q.isNotEmpty &&
          !a.appName.toLowerCase().contains(q) &&
          !a.packageName.toLowerCase().contains(q)) {
        return false;
      }
      final s = app.statusFor(a.packageName);
      switch (_filter) {
        case _Filter.all:
          return true;
        case _Filter.limited:
          return s != null;
        case _Filter.attention:
          return s != null && s.isAlert;
      }
    }).toList();

    String label(_Filter f) {
      switch (f) {
        case _Filter.all:
          return 'All apps';
        case _Filter.limited:
          return 'With a limit';
        case _Filter.attention:
          return 'Needs attention';
      }
    }

    if (app.todayApps.isEmpty && !app.loading) {
      return Panel(
        child: EmptyState(
          icon: Icons.apps_rounded,
          title: 'No apps used today',
          message: app.nativeSupported
              ? 'Use your phone for a minute and pull down on Today to sync.'
              : 'Apps show up after your Android phone syncs. Or look around with sample data.',
          actionLabel: 'Load sample data',
          onAction: () => seedDemoFlow(context),
        ),
      );
    }

    return Panel(
      title: 'Apps used today',
      subtitle: '${app.todayApps.length} apps, ${fmtDuration(app.today.totalSeconds)} in total. Click an app to set its limit.',
      trailing: SizedBox(
        width: 280,
        child: TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          style: body(15),
          decoration: fieldDecoration(
            'Search apps',
            prefix: const Icon(Icons.search_rounded, color: LS.slate),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final f in _Filter.values)
                ChoiceChip(
                  label: Text(label(f)),
                  selected: _filter == f,
                  showCheckmark: false,
                  selectedColor: LS.ink,
                  backgroundColor: LS.paper,
                  side: const BorderSide(color: LS.line),
                  shape: const StadiumBorder(),
                  labelStyle: body(14,
                      weight: FontWeight.w600,
                      color: _filter == f ? Colors.white : LS.ink),
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
          const SizedBox(height: 18),
          AppsTable(
            apps: apps,
            emptyMessage: q.isEmpty
                ? 'Nothing matches this filter.'
                : 'No app matches "${_search.text.trim()}".',
          ),
        ],
      ),
    );
  }
}
