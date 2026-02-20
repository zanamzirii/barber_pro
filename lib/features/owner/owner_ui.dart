import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class OwnerUi {
  static const Color screenBg = Color(0xFF05070A);
  static const Color panelBg = Color(0xFF0C0E12);

  static BoxDecoration gradientBackground() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF05070A), Color(0xFF0B0F1A), Color(0xFF05070A)],
      ),
    );
  }

  static Widget background() {
    return Container(decoration: gradientBackground());
  }

  static TextStyle pageTitleStyle({
    double size = 32,
    FontWeight weight = FontWeight.w700,
  }) {
    return TextStyle(
      color: AppColors.text,
      fontFamily: 'PlayfairDisplay',
      fontSize: size,
      fontWeight: weight,
    );
  }

  static TextStyle sectionLabelStyle() {
    return TextStyle(
      color: AppColors.onDark42,
      fontSize: 10,
      letterSpacing: 2,
      fontWeight: FontWeight.w700,
    );
  }

  static BoxDecoration panelDecoration({
    double radius = 16,
    double alpha = 0.07,
  }) {
    return BoxDecoration(
      color: panelBg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: alpha)),
    );
  }

  static InputDecoration inputDecoration(String label, {String? helperText}) {
    return InputDecoration(
      labelText: label,
      helperText: helperText,
      labelStyle: TextStyle(color: AppColors.onDark75),
      helperStyle: TextStyle(color: AppColors.onDark45, fontSize: 11),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.onDark10),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.gold),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
