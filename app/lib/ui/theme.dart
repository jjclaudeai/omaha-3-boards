import 'package:flutter/material.dart';

/// Palette du jeu : nuit bleutée pour les menus, tapis vert pour la table, or pour ce qui rapporte.
class Palette {
  static const night = Color(0xFF0D1626);
  static const nightRaised = Color(0xFF15233A);
  static const panel = Color(0xFF1B2D49);
  static const panelLine = Color(0xFF2A4166);
  static const felt = Color(0xFF1F7A4F);
  static const feltDark = Color(0xFF0E4A30);
  static const gold = Color(0xFFF6C453);
  static const goldDeep = Color(0xFFC98D23);
  static const ruby = Color(0xFFD9473F);
  static const mint = Color(0xFF3FD68E);
  static const sky = Color(0xFF55A8FF);
  static const textHi = Color(0xFFF2F5FA);
  static const textLo = Color(0xFF93A5BF);
}

const displayFont = 'Baloo2';
const bodyFont = 'Nunito';

TextStyle display(double size, {Color color = Palette.textHi, FontWeight weight = FontWeight.w800}) =>
    TextStyle(fontFamily: displayFont, fontSize: size, fontWeight: weight, color: color, height: 1.1);

TextStyle body(double size, {Color color = Palette.textHi, FontWeight weight = FontWeight.w700}) =>
    TextStyle(fontFamily: bodyFont, fontSize: size, fontWeight: weight, color: color, height: 1.25);

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: bodyFont,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.felt,
      brightness: Brightness.dark,
      primary: Palette.gold,
      surface: Palette.nightRaised,
    ),
    scaffoldBackgroundColor: Palette.night,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(fontFamily: bodyFont, bodyColor: Palette.textHi, displayColor: Palette.textHi),
  );
}

/// Formate un nombre de pièces : 12 500, 1,2 M.
String formatCoins(int n) {
  if (n >= 10000000) return '${(n / 1000000).toStringAsFixed(1).replaceAll('.', ',')} M';
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(' ');
    b.write(s[i]);
  }
  return b.toString();
}
