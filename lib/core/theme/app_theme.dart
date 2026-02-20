import 'package:flutter/material.dart';

import '../motion.dart';
import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final borderColor = AppColors.onDark10;
    final hintColor = AppColors.onDark42;

    return ThemeData(
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.midnight,
      pageTransitionsTheme: Motion.pageTransitionsTheme,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.gold,
        secondary: AppColors.gold,
        surface: AppColors.midnight,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: AppColors.gold.withValues(alpha: 0.9)),
        hintStyle: TextStyle(color: hintColor),
        filled: true,
        fillColor: const Color(0xFF141A2A),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: const ButtonStyle(
          animationDuration: Motion.microAnimationDuration,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: const ButtonStyle(
          animationDuration: Motion.microAnimationDuration,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: const ButtonStyle(
          animationDuration: Motion.microAnimationDuration,
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.gold,
        selectionColor: AppColors.gold.withValues(alpha: 0.22),
        selectionHandleColor: AppColors.gold,
      ),
    );
  }

  static ThemeData get light {
    const lightBg = Color(0xFFF8FAFC);
    const lightCard = Color(0xFFFFFFFF);
    const lightText = Color(0xFF0F172A);
    const lightMuted = Color(0xFF64748B);
    const lightBorder = Color(0xFFE2E8F0);

    return ThemeData(
      brightness: Brightness.light,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: lightBg,
      pageTransitionsTheme: Motion.pageTransitionsTheme,
      colorScheme: const ColorScheme.light(
        primary: AppColors.gold,
        secondary: AppColors.gold,
        surface: lightCard,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: lightText,
        elevation: 0,
      ),
      cardTheme: const CardThemeData(
        color: lightCard,
        shadowColor: Color(0x1A0F172A),
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: const TextStyle(color: lightMuted),
        hintStyle: const TextStyle(color: lightMuted),
        filled: true,
        fillColor: lightCard,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: lightBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: const ButtonStyle(
          animationDuration: Motion.microAnimationDuration,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: const ButtonStyle(
          animationDuration: Motion.microAnimationDuration,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: const ButtonStyle(
          animationDuration: Motion.microAnimationDuration,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.gold,
        selectionColor: Color(0x36D4AF37),
        selectionHandleColor: AppColors.gold,
      ),
    );
  }
}
