import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/tokens.dart';
import 'limit_editor.dart';
import 'orbit.dart';

/// Wrap a screen with this to get the centre-of-screen "you are overusing"
/// popup the moment an app goes over its limit (once per app per day).
class PopupHost extends StatefulWidget {
  const PopupHost({super.key, required this.child});
  final Widget child;

  @override
  State<PopupHost> createState() => _PopupHostState();
}

class _PopupHostState extends State<PopupHost> {
  bool _showing = false;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.hasPopup && !_showing) {
      _showing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final status = context.read<AppState>().takePopup();
        if (status == null) {
          _showing = false;
          return;
        }
        await showOveruseDialog(context, status);
        _showing = false;
        if (mounted) setState(() {}); // show the next one, if any
      });
    }
    return widget.child;
  }
}

Future<void> showOveruseDialog(BuildContext context, LimitStatus s) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: LS.space.tint(0.72),
    transitionDuration: const Duration(milliseconds: 380),
    pageBuilder: (ctx, a, b) => _OveruseCard(status: s, parentContext: context),
    transitionBuilder: (ctx, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween<double>(begin: 0.88, end: 1).animate(curved), child: child),
      );
    },
  );
}

class _OveruseCard extends StatelessWidget {
  const _OveruseCard({required this.status, required this.parentContext});
  final LimitStatus status;
  final BuildContext parentContext;

  @override
  Widget build(BuildContext context) {
    final s = status;
    final limit = parentContext.read<AppState>().limitFor(s.packageName);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Material(
            color: LS.space,
            borderRadius: BorderRadius.circular(32),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 32, 28, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OrbitView(
                    size: 176,
                    centerValue: fmtDuration(s.usedSeconds),
                    centerLabel: s.appName,
                    entries: [
                      OrbitEntry(
                        packageName: s.packageName,
                        appName: s.appName,
                        seconds: s.usedSeconds,
                        fraction: 1,
                        state: LimitState.exceeded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    s.popupTitle ?? "Time's up!",
                    textAlign: TextAlign.center,
                    style: display(30, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.popupMessage ??
                        'You are overusing ${s.appName} today.',
                    textAlign: TextAlign.center,
                    style: body(15, color: LS.onSpaceMuted, height: 1.45),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: LS.marigold,
                        foregroundColor: LS.space,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Got it'),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openLimitEditor(parentContext,
                          existing: limit,
                          preset: limit == null
                              ? AppRef(s.packageName, s.appName)
                              : null);
                    },
                    style: TextButton.styleFrom(foregroundColor: LS.onSpaceMuted),
                    child: const Text('Change limit'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
