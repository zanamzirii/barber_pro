import 'package:flutter/material.dart';

class AppColors {
  // Core shared palette
  static const midnight = Color(0xFF0B0F1A);
  // Global app defaults (locked to owner dashboard look)
  static const bgPrimary = midnight;
  static const ownerDashboardCard = Color(0xFF161B26);
  static const surface = ownerDashboardCard;
  static const elevatedSurface = ownerDashboardCard;
  static const surfaceSoft = ownerDashboardCard;
  static const ownerDashboardGradientMid = Color(0xFF070D19);
  static const shellBackground = midnight;
  static const shellNavBackground = midnight;
  static const shellNavBorder = Color(0x14ECB913);
  static const shellInactive = Color(0xFF97A4B8);
  static const textOnDark70 = onDark70;
  static const textOnDark45 = onDark45;

  static const textPrimary = Color(0xFFF5F5F5);
  static const text = textPrimary;
  static const muted = Color(0xCCA7ABB4);
  static const transparent = Colors.transparent;

  // On-dark text/border opacities (centralized to avoid random inline alpha usage)
  static const onDark05 = Color(0x0DFFFFFF);
  static const onDark06 = Color(0x0FFFFFFF);
  static const onDark08 = Color(0x14FFFFFF);
  static const onDark10 = Color(0x1AFFFFFF);
  static const onDark12 = Color(0x1FFFFFFF);
  static const onDark18 = Color(0x2EFFFFFF);
  static const onDark20 = Color(0x33FFFFFF);
  static const onDark25 = Color(0x40FFFFFF);
  static const onDark30 = Color(0x4DFFFFFF);
  static const onDark33 = Color(0x54FFFFFF);
  static const onDark35 = Color(0x59FFFFFF);
  static const onDark38 = Color(0x61FFFFFF);
  static const onDark40 = Color(0x66FFFFFF);
  static const onDark42 = Color(0x6BFFFFFF);
  static const onDark45 = Color(0x73FFFFFF);
  static const onDark46 = Color(0x75FFFFFF);
  static const onDark50 = Color(0x80FFFFFF);
  static const onDark52 = Color(0x85FFFFFF);
  static const onDark55 = Color(0x8CFFFFFF);
  static const onDark58 = Color(0x94FFFFFF);
  static const onDark62 = Color(0x9EFFFFFF);
  static const onDark65 = Color(0xA6FFFFFF);
  static const onDark70 = Color(0xB3FFFFFF);
  static const onDark75 = Color(0xBFFFFFFF);
  static const onDark80 = Color(0xCCFFFFFF);

  static const borderSoft = Color(0x1FFFFFFF);

  // Neutral scale for consistent UI surfaces/text across roles
  static const slate700 = Color(0xFF1F2937);
  static const slate650 = Color(0xFF1E293B);
  static const slate600 = Color(0xFF334155);
  static const slate500 = Color(0xFF475772);
  static const slate450 = Color(0xFF4E5B73);
  static const slate400 = Color(0xFF586278);
  static const slate350 = Color(0xFF6A7489);
  static const slate300 = Color(0xFF6B7893);
  static const slate200 = Color(0xFF9AA3B2);
  static const panel = ownerDashboardCard;
  static const overlaySurface = Color(0x66070A12);
  static const dangerSoft = Color(0x29EF4444);

  // Role accents (change here to update role identity globally)
  static const ownerAccent = Color(0xFFECB913);
  static const barberAccent = ownerAccent;
  static const customerAccent = Color(0xFF3B82F6);

  // Backward compatibility
  static const gold = ownerAccent;

  // Semantic status colors
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
}
