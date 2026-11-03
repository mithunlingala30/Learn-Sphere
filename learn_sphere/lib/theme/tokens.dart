import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/models.dart';

/// Learn Sphere design tokens.
///
/// Direction: an observatory for your attention. Deep indigo "space" surfaces,
/// a pale mist canvas, and one memorable object - the orbit - where every app
/// is a planet on its own ring. Marigold means "slow down", rose means "over".
class LS {
  static const ink = Color(0xFF1E2255);
  static const space = Color(0xFF121536);
  static const spaceRaised = Color(0xFF1C2050);
  static const mist = Color(0xFFEEF0F8);
  static const paper = Color(0xFFFFFFFF);
  static const periwinkle = Color(0xFF6C74F0);
  static const marigold = Color(0xFFF5B544);
  static const lagoon = Color(0xFF2FC4A8);
  static const rose = Color(0xFFE5546F);
  static const slate = Color(0xFF666B92);
  static const line = Color(0xFFDDE0EE);
  static const onSpace = Color(0xFFE9EBFF);
  static const onSpaceMuted = Color(0xFF9EA3D6);

  // Muted app-avatar tones (chosen per package, stable between sessions).
  static const appTones = <Color>[
    Color(0xFF6C74F0),
    Color(0xFF2FC4A8),
    Color(0xFFF08A5D),
    Color(0xFFB75CFF),
    Color(0xFF3FA7F5),
    Color(0xFFE5546F),
    Color(0xFF8BC34A),
    Color(0xFFF5B544),
  ];
}

extension ColorTint on Color {
  /// Same colour at the given opacity (0..1) without deprecated APIs.
  Color tint(double opacity) =>
      withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}

Color appColor(String packageName) {
  var h = 0;
  for (final c in packageName.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return LS.appTones[h % LS.appTones.length];
}

Color statusColor(LimitState s, {Color fallback = LS.periwinkle}) {
  switch (s) {
    case LimitState.exceeded:
      return LS.rose;
    case LimitState.warning:
      return LS.marigold;
    case LimitState.ok:
      return LS.lagoon;
    case LimitState.none:
      return fallback;
  }
}

String statusLabel(LimitState s) {
  switch (s) {
    case LimitState.exceeded:
      return 'Over limit';
    case LimitState.warning:
      return 'Close to limit';
    case LimitState.ok:
      return 'On track';
    case LimitState.none:
      return 'No limit';
  }
}

/// Display face: used for numbers and headings.
TextStyle display(
  double size, {
  FontWeight weight = FontWeight.w700,
  Color color = LS.ink,
  double? height,
  double letterSpacing = -0.4,
}) =>
    GoogleFonts.getFont(
      'Bricolage Grotesque',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

/// Text face: used for everything you read.
TextStyle body(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = LS.ink,
  double? height,
  double letterSpacing = 0,
}) =>
    GoogleFonts.getFont(
      'Instrument Sans',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );

/// Shared text-field look (set per field to stay independent of Flutter's
/// ThemeData input-decoration API changes).
InputDecoration fieldDecoration(
  String label, {
  String? hint,
  Widget? suffix,
  Widget? prefix,
  bool dark = false,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: dark ? LS.onSpaceMuted.tint(0.3) : LS.line),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixIcon: suffix,
    prefixIcon: prefix,
    filled: true,
    fillColor: dark ? LS.spaceRaised : LS.paper,
    labelStyle: body(14, color: dark ? LS.onSpaceMuted : LS.slate),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: LS.periwinkle, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: LS.rose),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: LS.rose, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}
