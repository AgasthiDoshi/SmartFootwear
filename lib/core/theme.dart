import 'package:flutter/material.dart';

abstract final class StrideColors {
  static const mint = Color(0xFF8CFFCF);
  static const blue = Color(0xFF91B8FF);
  static const lavender = Color(0xFFD6A8FF);
  static const warning = Color(0xFFFFD08A);
}

ThemeData strideTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: StrideColors.mint,
    brightness: brightness,
    primary: dark ? StrideColors.mint : const Color(0xFF006B4C),
    surface: dark ? const Color(0xFF151923) : Colors.white,
    error: dark ? const Color(0xFFFF747F) : const Color(0xFFBA1A30),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF0B0D12)
        : const Color(0xFFF3F6F5),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primary.withValues(alpha: .16),
    ),
  );
}
