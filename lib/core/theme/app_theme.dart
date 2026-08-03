import 'package:flutter/material.dart';

class AppTheme {
  static const Color forestGreen = Color(0xFF1B4D3E);
  static const Color gold = Color(0xFFD4A017);
  static const Color brick = Color(0xFFA0452F);
  static const Color sky = Color(0xFF7EB6D9);
  static const Color cream = Color(0xFFF7F3E9);

  /// Labels/headings on forest-green bars (readable white).
  static const Color labelText = Colors.white;

  /// Body text on cream/white cards — near-black (replaces hard-to-read green;
  /// pure white on cream would be invisible).
  static const Color bodyText = Color(0xFF111111);

  /// Prefer [standard_buttons.dart] widgets for labeled actions.
  /// Theme defaults match Action (indigo) with a white contrast ring.
  static final Color actionBlue = Colors.indigo.shade700;

  static ButtonStyle get _filledStyle => FilledButton.styleFrom(
        backgroundColor: actionBlue,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
        side: const BorderSide(color: Colors.white, width: 2.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  static ButtonStyle get _elevatedStyle => ElevatedButton.styleFrom(
        backgroundColor: actionBlue,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
        side: const BorderSide(color: Colors.white, width: 2.5),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  static ButtonStyle get _outlinedStyle => OutlinedButton.styleFrom(
        backgroundColor: Colors.grey.shade700,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
        side: const BorderSide(color: Colors.white, width: 2.5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  static ButtonStyle get _textStyle => TextButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white54,
        side: const BorderSide(color: Colors.white, width: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      );

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: forestGreen,
        primary: forestGreen,
        secondary: gold,
        surface: cream,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: cream,
      appBarTheme: const AppBarTheme(
        backgroundColor: forestGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: forestGreen),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: actionBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _filledStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _elevatedStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedStyle),
      textButtonTheme: TextButtonThemeData(style: _textStyle),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: forestGreen, width: 2),
        ),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: forestGreen,
        primary: forestGreen,
        secondary: gold,
        brightness: Brightness.dark,
      ),
    );

    final whiteTextTheme = base.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    );

    return base.copyWith(
      scaffoldBackgroundColor: const Color(0xFF102018),
      textTheme: whiteTextTheme,
      primaryTextTheme: whiteTextTheme,
      iconTheme: const IconThemeData(color: Colors.white),
      primaryIconTheme: const IconThemeData(color: Colors.white),
      cardTheme: const CardThemeData(
        color: Color(0xFF182B22),
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF182B22),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: TextStyle(color: Colors.white),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: Colors.white,
        iconColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B1A14),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: Color(0xFF0B1A14)),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: actionBlue,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(style: _filledStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: _elevatedStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(style: _outlinedStyle),
      textButtonTheme: TextButtonThemeData(style: _textStyle),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A2E24),
        labelStyle: const TextStyle(color: Colors.white70),
        floatingLabelStyle: const TextStyle(color: Colors.white),
        hintStyle: const TextStyle(color: Colors.white60),
        helperStyle: const TextStyle(color: Colors.white70),
        prefixIconColor: Colors.white70,
        suffixIconColor: Colors.white70,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: gold, width: 2),
        ),
      ),
    );
  }
}
