import 'package:flutter/material.dart';

class MarbleColors {
  static const charcoal = Color(0xFF111111);
  static const ink = Color(0xFF1A1A1A);
  static const vein = Color(0xFF6E6E6E);
  static const mist = Color(0xFFB9B9B9);
  static const paper = Color(0xFFF4F1EC);
  static const stone = Color(0xFFE6E2DC);
  static const graphite = Color(0xFF2A2A2A);
}

class MarbleTheme {
  static ThemeData dark({required bool highContrast, required double textScale}) {
    final scheme = const ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      secondary: Color(0xFFBDBDBD),
      onSecondary: Colors.black,
      surface: Color(0xFF161616),
      onSurface: Color(0xFFF5F5F5),
      error: Color(0xFFE0E0E0),
      onError: Colors.black,
      outline: Color(0xFF8A8A8A),
    );
    return _base(scheme, Brightness.dark, highContrast, textScale);
  }

  static ThemeData light({required bool highContrast, required double textScale}) {
    final scheme = const ColorScheme.light(
      primary: Color(0xFF111111),
      onPrimary: Colors.white,
      secondary: Color(0xFF5C5C5C),
      onSecondary: Colors.white,
      surface: Color(0xFFF7F4EF),
      onSurface: Color(0xFF161616),
      error: Color(0xFF3D3D3D),
      onError: Colors.white,
      outline: Color(0xFF6F6F6F),
    );
    return _base(scheme, Brightness.light, highContrast, textScale);
  }

  static ThemeData _base(
    ColorScheme scheme,
    Brightness brightness,
    bool highContrast,
    double textScale,
  ) {
    final border = highContrast ? 1.6 : 0.8;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 22 * textScale,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: scheme.onSurface,
        ),
      ),
      cardTheme: CardTheme(
        color: scheme.surface.withValues(alpha: brightness == Brightness.dark ? 0.72 : 0.86),
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.35), width: border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface.withValues(alpha: 0.65),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface.withValues(alpha: 0.92),
        indicatorColor: scheme.onSurface.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 12 * textScale, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
