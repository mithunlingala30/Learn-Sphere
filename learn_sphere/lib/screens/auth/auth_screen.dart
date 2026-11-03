import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand.dart';
import '../../widgets/orbit.dart';
import 'auth_form.dart';

/// Decorative rings for the sign-in art (not real data).
List<OrbitEntry> _artRings() => const [
      OrbitEntry(packageName: 'art.one', appName: '', seconds: 0, fraction: 0.92, state: LimitState.exceeded),
      OrbitEntry(packageName: 'art.two', appName: '', seconds: 0, fraction: 0.74, state: LimitState.warning),
      OrbitEntry(packageName: 'art.three', appName: '', seconds: 0, fraction: 0.55, state: LimitState.none),
      OrbitEntry(packageName: 'art.four', appName: '', seconds: 0, fraction: 0.34, state: LimitState.none),
    ];

/// Phone layout below 900px wide, split-screen layout above.
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) =>
            box.maxWidth >= 900 ? const _WebAuth() : const _MobileAuth(),
      );
}

class _MobileAuth extends StatelessWidget {
  const _MobileAuth();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LS.space,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                      child: Column(
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Wordmark(size: 20),
                          ),
                          const SizedBox(height: 22),
                          OrbitView(
                            size: 190,
                            entries: _artRings(),
                            centerValue: 'Hello',
                            centerLabel: "let's begin",
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                        decoration: const BoxDecoration(
                          color: LS.mist,
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                        child: const AuthForm(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebAuth extends StatelessWidget {
  const _WebAuth();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LS.mist,
      body: Row(
        children: [
          Expanded(
            flex: 11,
            child: Container(
              color: LS.space,
              padding: const EdgeInsets.fromLTRB(64, 48, 64, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wordmark(size: 22),
                  Expanded(
                    child: Center(
                      child: OrbitView(
                        size: 440,
                        entries: _artRings(),
                        centerValue: 'Hello',
                        centerLabel: "let's begin",
                      ),
                    ),
                  ),
                  Text('Know where your time goes.',
                      style: display(44, color: Colors.white, height: 1.05, letterSpacing: -1.2)),
                  const SizedBox(height: 14),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Text(
                      'Learn Sphere tracks your screen time, holds the limits you set, and tells you before a quick scroll turns into an hour.',
                      style: body(17, color: LS.onSpaceMuted, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 9,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: const AuthForm(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
