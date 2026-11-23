import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// ZoolGo brand tokens (Figma variables, docs/MISSING_SCREENS.md §1). Screens never hard-code colors.
abstract final class ZoolColors {
  static const primary = Color(0xFF9A1B2F); // Red 500 — main action
  static const primarySoft = Color(0xFFF5E8EA); // Red 50
  static const secondary = Color(0xFF03442C); // Green 500 — amounts, active tab, icons
  static const secondarySoft = Color(0xFFE6ECEA); // Green 50 — header, selected chips
  static const text = Color(0xFF121212);
  static const textSecondary = Color(0xFF494E63);
  static const textMuted = Color(0xFF858896);
  static const border = Color(0xFFC7C8CF);
  static const divider = Color(0xFFEDEDEF);
  static const background = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF7F7F8);
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9500);
  static const error = Color(0xFFFF3B30);
  static const info = Color(0xFF007AFF);
  static const women = Color(0xFFE91E8C); // women-only seat outline
}

abstract final class ZoolRadii {
  static const card = 16.0;
  static const field = 12.0;
  static const button = 12.0;
  static const chip = 10.0;
}

const String kZoolFont = 'IBMPlexSansArabic';
const String _fontPackage = 'zool_ui';

/// Arabic, right-to-left. All three apps run in this locale.
const Locale kZoolLocale = Locale('ar');
const List<LocalizationsDelegate<dynamic>> kZoolLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The shared Material theme (font, colors, inputs, buttons, cards, tabs).
ThemeData zoolTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: ZoolColors.primary,
    primary: ZoolColors.primary,
    onPrimary: Colors.white,
    secondary: ZoolColors.secondary,
    onSecondary: Colors.white,
    secondaryContainer: ZoolColors.secondarySoft,
    onSecondaryContainer: ZoolColors.secondary,
    primaryContainer: ZoolColors.primarySoft,
    onPrimaryContainer: ZoolColors.primary,
    error: ZoolColors.error,
    surface: ZoolColors.background,
    onSurface: ZoolColors.text,
    outline: ZoolColors.border,
    outlineVariant: ZoolColors.divider,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: kZoolFont, package: _fontPackage);
  final text = base.textTheme.apply(fontFamily: kZoolFont, package: _fontPackage, bodyColor: ZoolColors.text, displayColor: ZoolColors.text);

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(ZoolRadii.field),
    borderSide: const BorderSide(color: ZoolColors.border),
  );

  return base.copyWith(
    scaffoldBackgroundColor: ZoolColors.background,
    textTheme: text.copyWith(
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 20),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 16),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.5),
      bodySmall: text.bodySmall?.copyWith(fontSize: 12, color: ZoolColors.textSecondary, height: 1.45),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 15),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: ZoolColors.background,
      foregroundColor: ZoolColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontFamily: kZoolFont, package: _fontPackage, fontSize: 17, fontWeight: FontWeight.w700, color: ZoolColors.text),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ZoolColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: ZoolColors.divider,
        disabledForegroundColor: ZoolColors.textMuted,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZoolRadii.button)),
        textStyle: const TextStyle(fontFamily: kZoolFont, package: _fontPackage, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ZoolColors.secondary,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: ZoolColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZoolRadii.button)),
        textStyle: const TextStyle(fontFamily: kZoolFont, package: _fontPackage, fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ZoolColors.secondary,
        textStyle: const TextStyle(fontFamily: kZoolFont, package: _fontPackage, fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: ZoolColors.secondary, width: 1.5)),
      errorBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: ZoolColors.error)),
      focusedErrorBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: ZoolColors.error, width: 1.5)),
      labelStyle: const TextStyle(color: ZoolColors.textSecondary),
      hintStyle: const TextStyle(color: ZoolColors.textMuted),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ZoolRadii.card),
        side: const BorderSide(color: ZoolColors.divider),
      ),
    ),
    dividerTheme: const DividerThemeData(color: ZoolColors.divider, thickness: 1, space: 1),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: ZoolColors.secondarySoft,
      side: const BorderSide(color: ZoolColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZoolRadii.chip)),
      labelStyle: const TextStyle(fontFamily: kZoolFont, package: _fontPackage, color: ZoolColors.text, fontSize: 13),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: ZoolColors.secondarySoft,
      height: 68,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? ZoolColors.secondary : ZoolColors.textMuted),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontFamily: kZoolFont,
          package: _fontPackage,
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400,
          color: s.contains(WidgetState.selected) ? ZoolColors.secondary : ZoolColors.textMuted,
        ),
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: ZoolColors.secondary,
      unselectedLabelColor: ZoolColors.textMuted,
      indicatorColor: ZoolColors.secondary,
      dividerColor: ZoolColors.divider,
      labelStyle: TextStyle(fontFamily: kZoolFont, package: _fontPackage, fontWeight: FontWeight.w700, fontSize: 14),
      unselectedLabelStyle: TextStyle(fontFamily: kZoolFont, package: _fontPackage, fontSize: 14),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZoolRadii.card)),
    ),
  );
}
