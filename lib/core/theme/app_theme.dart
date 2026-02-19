import 'package:flutter/material.dart';

import '../motion.dart';
import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    final borderColor = Colors.white.withValues(alpha: 0.1);
    final hintColor = Colors.white.withValues(alpha: 0.42);

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
}

