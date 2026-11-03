import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import '../widgets/brand.dart';

/// Shown instead of crashing when firebase_options.dart is still the placeholder.
class SetupRequiredApp extends StatelessWidget {
  const SetupRequiredApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Learn Sphere',
      theme: buildTheme(),
      home: Scaffold(
        backgroundColor: LS.space,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Wordmark(),
                  const SizedBox(height: 36),
                  Text('Connect Firebase to start',
                      style: display(34, color: Colors.white, height: 1.1)),
                  const SizedBox(height: 14),
                  Text(
                    'The app needs your Firebase project for sign-in and data. Run these two commands in the project folder, then start the app again:',
                    style: body(16, color: LS.onSpaceMuted, height: 1.5),
                  ),
                  const SizedBox(height: 20),
                  _code('dart pub global activate flutterfire_cli'),
                  const SizedBox(height: 10),
                  _code('flutterfire configure'),
                  const SizedBox(height: 20),
                  Text(
                    'Also turn on Email/Password and Google in Firebase Authentication, and create a Firestore database. The README walks through each step.',
                    style: body(14.5, color: LS.onSpaceMuted, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _code(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: LS.spaceRaised,
          borderRadius: BorderRadius.circular(14),
        ),
        child: SelectableText(
          text,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14.5,
            color: LS.onSpace,
          ),
        ),
      );
}
