import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// ZoolGo brand tokens, taken from the Figma file (sz5wZeoY4Bz4rOVhnFpkWq, "Test Design").
/// Screens never hard-code colors.
abstract final class ZoolColors {
  /// Red 500 — the main action button.
  static const primary = Color(0xFF9A1B2F);
  static const primarySoft = Color(0xFFF5E8EA);

  /// Dark green — amounts, times, active tab, wallet card, selected seat.
  static const brand = Color(0xFF115233);

  /// Green 500 — text on soft-green buttons.
  static const secondary = Color(0xFF03442C);

  /// Green 50 — quick-access buttons, chips.
  static const secondarySoft = Color(0xFFE6ECEA);

  /// Page background (mint).
  static const background = Color(0xFFE8F5EE);

  /// Women-only seat.
  static const women = Color(0xFF7BC4A5);

  static const text = Color(0xFF1F212A);
  static const textStrong = Color(0xFF111111);
  static const textSecondary = Color(0xFF6F727A);
  static const textMuted = Color(0xFF9A9DA5);
  static const navInactive = Color(0xFFABAEB7);
  static const label = Color(0xFF494E63);
  static const border = Color(0xFFC7C8CF);
  static const divider = Color(0xFFEDEDEF);
  static const surface = Color(0xFFFFFFFF);
  static const field = Color(0xFFF7F8FA);
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9500);
  static const error = Color(0xFFFF3B30);
  static const info = Color(0xFF007AFF);
}

abstract final class ZoolRadii {
  static const card = 16.0;
  static const bigCard = 20.0;
  static const field = 12.0;
  static const button = 16.0;
  static const bar = 24.0;
}

abstract final class ZoolShadows {
  /// Bottom bars (nav bar, action bar).
  static const bar = [BoxShadow(color: Color(0x295B6B8C), blurRadius: 2, offset: Offset(0, -1))];

  /// The dark-green wallet card.
  static const wallet = [BoxShadow(color: Color(0x33115233), blurRadius: 8, offset: Offset(0, 8))];

  /// Soft-green quick buttons.
  static const soft = [BoxShadow(color: Color(0x295B8C6F), blurRadius: 12, offset: Offset(0, 8))];
}

const String kZoolFont = 'Cairo';
const String _fontPackage = 'zool_ui';

/// Arabic, right-to-left. All three apps run in this locale.
const Locale kZoolLocale = Locale('ar');
const List<LocalizationsDelegate<dynamic>> kZoolLocalizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Arrows and symbols Cairo lacks (←) come from the platform font.
const List<String> kZoolFallbackFonts = ['Roboto', 'sans-serif'];

TextStyle _font(double size, FontWeight weight, Color color, {double? height}) => TextStyle(
      fontFamily: kZoolFont,
      package: _fontPackage,
      fontFamilyFallback: kZoolFallbackFonts,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
    );

/// Brand text style for places that replace the theme style (e.g. a button's `textStyle`).
TextStyle zoolText(double size, {FontWeight weight = FontWeight.w400, Color? color}) =>
    TextStyle(fontFamily: kZoolFont, package: _fontPackage, fontFamilyFallback: kZoolFallbackFonts, fontSize: size, fontWeight: weight, color: color);

/// The shared Material theme (Cairo, mint background, white borderless cards, 16px buttons).
ThemeData zoolTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: ZoolColors.brand,
    primary: ZoolColors.primary,
    onPrimary: Colors.white,
    secondary: ZoolColors.brand,
    onSecondary: Colors.white,
    secondaryContainer: ZoolColors.secondarySoft,
    onSecondaryContainer: ZoolColors.secondary,
    primaryContainer: ZoolColors.primarySoft,
    onPrimaryContainer: ZoolColors.primary,
    error: ZoolColors.error,
    surface: ZoolColors.surface,
    onSurface: ZoolColors.text,
    outline: ZoolColors.border,
    outlineVariant: ZoolColors.divider,
  );

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: kZoolFont, fontFamilyFallback: kZoolFallbackFonts, package: _fontPackage);
  final text = base.textTheme.apply(fontFamily: kZoolFont, package: _fontPackage, bodyColor: ZoolColors.text, displayColor: ZoolColors.text);

  final fieldBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(ZoolRadii.field),
    borderSide: const BorderSide(color: ZoolColors.border),
  );

  return base.copyWith(
    scaffoldBackgroundColor: ZoolColors.background,
    textTheme: text.copyWith(
      titleLarge: _font(20, FontWeight.w700, ZoolColors.text),
      titleMedium: _font(15, FontWeight.w700, ZoolColors.text),
      titleSmall: _font(14, FontWeight.w700, ZoolColors.textStrong),
      bodyLarge: _font(15, FontWeight.w400, ZoolColors.text),
      bodyMedium: _font(14, FontWeight.w400, ZoolColors.text, height: 1.5),
      bodySmall: _font(12, FontWeight.w400, ZoolColors.textMuted, height: 1.45),
      labelLarge: _font(16, FontWeight.w700, Colors.white),
      labelSmall: _font(11, FontWeight.w400, ZoolColors.textSecondary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: ZoolColors.textStrong,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: _font(16, FontWeight.w700, ZoolColors.textStrong),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ZoolColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: ZoolColors.divider,
        disabledForegroundColor: ZoolColors.textMuted,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZoolRadii.button)),
        textStyle: _font(16, FontWeight.w700, Colors.white),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: ZoolColors.brand,
        backgroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: ZoolColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZoolRadii.button)),
        textStyle: _font(14, FontWeight.w700, ZoolColors.brand),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: ZoolColors.brand, textStyle: _font(14, FontWeight.w700, ZoolColors.brand)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ZoolColors.field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: ZoolColors.brand, width: 1.5)),
      errorBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: ZoolColors.error)),
      focusedErrorBorder: fieldBorder.copyWith(borderSide: const BorderSide(color: ZoolColors.error, width: 1.5)),
      labelStyle: _font(14, FontWeight.w400, ZoolColors.textSecondary),
      hintStyle: _font(14, FontWeight.w400, ZoolColors.textMuted),
      errorStyle: _font(12, FontWeight.w400, ZoolColors.error),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZoolRadii.card)),
    ),
    dividerTheme: const DividerThemeData(color: ZoolColors.divider, thickness: 1, space: 1),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: Colors.white,
      selectedColor: ZoolColors.secondarySoft,
      side: const BorderSide(color: ZoolColors.divider),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelStyle: _font(13, FontWeight.w600, ZoolColors.text),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: ZoolColors.brand,
      unselectedLabelColor: ZoolColors.textSecondary,
      indicatorColor: ZoolColors.brand,
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: Colors.transparent,
      labelStyle: _font(14, FontWeight.w700, ZoolColors.brand),
      unselectedLabelStyle: _font(14, FontWeight.w400, ZoolColors.textSecondary),
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, contentTextStyle: _font(14, FontWeight.w400, Colors.white)),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(ZoolRadii.bigCard)),
    ),
    datePickerTheme: const DatePickerThemeData(backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
  );
}
