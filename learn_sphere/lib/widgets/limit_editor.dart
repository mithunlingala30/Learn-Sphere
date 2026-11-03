import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'common.dart';

/// Opens the limit editor as a side drawer on wide screens and as a bottom
/// sheet on phones.
Future<void> openLimitEditor(
  BuildContext context, {
  AppLimit? existing,
  AppRef? preset,
}) {
  final wide = MediaQuery.sizeOf(context).width >= 900;
  Widget builder(BuildContext c) => LimitEditor(existing: existing, preset: preset);
  if (wide) return showSideSheet<void>(context, builder: builder);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: LS.mist,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: builder,
  );
}

class LimitEditor extends StatefulWidget {
  const LimitEditor({super.key, this.existing, this.preset});

  final AppLimit? existing;
  final AppRef? preset;

  @override
  State<LimitEditor> createState() => _LimitEditorState();
}

class _LimitEditorState extends State<LimitEditor> {
  static const _presets = [15, 30, 60, 90, 120, 180];

  late int _minutes;
  late int _warn;
  final _pkg = TextEditingController();
  TextEditingController? _name; // owned by the Autocomplete field
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _minutes = e?.dailyLimitMinutes ?? 30;
    _warn = e?.warnAtPercent ?? 80;
    _pkg.text = e?.packageName ?? widget.preset?.packageName ?? '';
  }

  @override
  void dispose() {
    _pkg.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final name = widget.existing?.appName ?? (_name?.text.trim() ?? '');
    final pkg = widget.existing?.packageName ?? _pkg.text.trim();
    if (name.isEmpty || pkg.isEmpty) {
      setState(() =>
          _error = 'Pick an app from the list, or enter its name and package name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await app.saveLimit(AppLimit(
        packageName: pkg,
        appName: name,
        dailyLimitMinutes: _minutes,
        warnAtPercent: _warn,
      ));
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text('Limit saved for $name')));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save the limit. Check your connection and try again.';
      });
    }
  }

  Future<void> _remove() async {
    final e = widget.existing;
    if (e == null) return;
    final app = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final ok = await confirmDialog(
      context,
      title: 'Remove limit?',
      message: '${e.appName} will no longer have a daily limit.',
      confirmLabel: 'Remove limit',
      danger: true,
    );
    if (!ok) return;
    await app.deleteLimit(e.packageName);
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text('Limit removed for ${e.appName}')));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final existing = widget.existing;
    final known = app.knownApps;
    final notifyLeft =
        fmtDuration((_minutes * 60 * (100 - _warn) / 100).round());

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(existing == null ? 'New limit' : 'Edit limit',
                    style: display(26)),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (existing != null)
            Row(
              children: [
                AppAvatar(name: existing.appName, packageName: existing.packageName),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(existing.appName, style: body(17, weight: FontWeight.w600)),
                      Text(existing.packageName, style: body(12.5, color: LS.slate)),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            LayoutBuilder(
              builder: (context, box) => Autocomplete<AppRef>(
                initialValue: TextEditingValue(text: widget.preset?.appName ?? ''),
                displayStringForOption: (o) => o.appName,
                optionsBuilder: (v) {
                  final q = v.text.trim().toLowerCase();
                  final list = q.isEmpty
                      ? known
                      : known.where((a) =>
                          a.appName.toLowerCase().contains(q) ||
                          a.packageName.toLowerCase().contains(q));
                  return list.take(8);
                },
                onSelected: (o) => _pkg.text = o.packageName,
                fieldViewBuilder: (ctx, controller, focus, onSubmit) {
                  _name = controller;
                  return TextField(
                    controller: controller,
                    focusNode: focus,
                    style: body(16),
                    decoration: fieldDecoration('App name', hint: 'Instagram'),
                  );
                },
                optionsViewBuilder: (ctx, onSelected, options) => Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Material(
                      elevation: 6,
                      color: LS.paper,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(maxHeight: 260, maxWidth: box.maxWidth),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          children: [
                            for (final o in options)
                              ListTile(
                                dense: true,
                                leading: AppAvatar(
                                    name: o.appName, packageName: o.packageName, size: 32),
                                title: Text(o.appName, style: body(15, weight: FontWeight.w600)),
                                subtitle: Text(o.packageName, style: body(12, color: LS.slate)),
                                onTap: () => onSelected(o),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pkg,
              style: body(15),
              decoration: fieldDecoration(
                'Package name',
                hint: 'com.instagram.android',
              ),
            ),
          ],
          const SizedBox(height: 28),
          Text('Daily limit', style: body(14, weight: FontWeight.w600, color: LS.slate)),
          const SizedBox(height: 4),
          Text(fmtDuration(_minutes * 60), style: display(44, letterSpacing: -1.5)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in _presets)
                ChoiceChip(
                  label: Text(fmtDuration(m * 60)),
                  selected: _minutes == m,
                  showCheckmark: false,
                  selectedColor: LS.ink,
                  backgroundColor: LS.paper,
                  side: const BorderSide(color: LS.line),
                  shape: const StadiumBorder(),
                  labelStyle: body(14,
                      weight: FontWeight.w600,
                      color: _minutes == m ? Colors.white : LS.ink),
                  onSelected: (_) => setState(() => _minutes = m),
                ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: LS.periwinkle,
              inactiveTrackColor: LS.line,
              thumbColor: LS.periwinkle,
              trackHeight: 6,
            ),
            child: Slider(
              min: 5,
              max: 360,
              divisions: 71,
              value: _minutes.clamp(5, 360).toDouble(),
              onChanged: (v) => setState(() => _minutes = (v / 5).round() * 5),
            ),
          ),
          const SizedBox(height: 14),
          Text('Warn me at $_warn%',
              style: body(14, weight: FontWeight.w600, color: LS.slate)),
          const SizedBox(height: 2),
          Text("You'll get a notification when $notifyLeft are left.",
              style: body(13.5, color: LS.slate)),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: LS.marigold,
              inactiveTrackColor: LS.line,
              thumbColor: LS.marigold,
              trackHeight: 6,
            ),
            child: Slider(
              min: 50,
              max: 95,
              divisions: 9,
              value: _warn.clamp(50, 95).toDouble(),
              onChanged: (v) => setState(() => _warn = (v / 5).round() * 5),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: body(13.5, color: LS.rose, weight: FontWeight.w600)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                    )
                  : const Text('Save limit'),
            ),
          ),
          if (existing != null) ...[
            const SizedBox(height: 6),
            Center(
              child: TextButton(
                onPressed: _remove,
                style: TextButton.styleFrom(foregroundColor: LS.rose),
                child: const Text('Remove limit'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
