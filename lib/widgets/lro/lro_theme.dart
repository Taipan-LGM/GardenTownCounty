import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// LRO contrast: dark → white text/borders; light → forest green (inverted).
class LroTheme {
  LroTheme._();

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color text(BuildContext context) =>
      isDark(context) ? Colors.white : AppTheme.forestGreen;

  static Color border(BuildContext context) =>
      isDark(context) ? Colors.white : AppTheme.forestGreen;

  static ThemeData of(BuildContext context) {
    final dark = isDark(context);
    final fg = dark ? Colors.white : AppTheme.forestGreen;
    final base = Theme.of(context);

    OutlineInputBorder outline([double width = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: fg, width: width),
        );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: fg, displayColor: fg),
      primaryTextTheme:
          base.primaryTextTheme.apply(bodyColor: fg, displayColor: fg),
      iconTheme: IconThemeData(color: fg),
      dividerColor: fg.withValues(alpha: 0.45),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: fg, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dark ? const Color(0xFF1B4D3E) : AppTheme.forestGreen,
          foregroundColor: Colors.white,
          side: BorderSide(color: fg, width: 1.5),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: fg),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: fg, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppTheme.gold,
        foregroundColor: AppTheme.forestGreen,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: fg, width: 1.5),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF1A2E24) : Colors.white,
        labelStyle: TextStyle(color: fg),
        hintStyle: TextStyle(color: fg.withValues(alpha: 0.65)),
        prefixIconColor: fg,
        suffixIconColor: fg,
        border: outline(),
        enabledBorder: outline(),
        focusedBorder: outline(2),
        disabledBorder: outline(),
      ),
      dataTableTheme: DataTableThemeData(
        headingTextStyle: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
        ),
        dataTextStyle: TextStyle(color: fg),
        dividerThickness: 1,
      ),
      cardTheme: CardThemeData(
        color: dark ? const Color(0xFF152820) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: fg.withValues(alpha: 0.55)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        textColor: fg,
        iconColor: fg,
      ),
      chipTheme: base.chipTheme.copyWith(
        labelStyle: TextStyle(color: fg),
        side: BorderSide(color: fg),
      ),
    );
  }
}

/// Wraps LRO screens so text/buttons stay readable in dark & light themes.
class LroThemed extends StatelessWidget {
  const LroThemed({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final fg = LroTheme.text(context);
    return Theme(
      data: LroTheme.of(context),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: fg),
        child: IconTheme.merge(
          data: IconThemeData(color: fg),
          child: child,
        ),
      ),
    );
  }
}
