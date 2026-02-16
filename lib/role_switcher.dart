import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'core/auth/user_role_service.dart';
import 'core/theme/app_colors.dart';

class RoleSwitcher {
  static String _label(String role) {
    switch (role) {
      case 'customer':
        return 'Customer';
      case 'barber':
        return 'Barber';
      case 'owner':
        return 'Owner';
      default:
        return role;
    }
  }

  static IconData _icon(String role) {
    switch (role) {
      case 'customer':
        return Icons.person_outline;
      case 'barber':
        return Icons.content_cut_rounded;
      case 'owner':
        return Icons.storefront_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  static String _subtitle(String role) {
    switch (role) {
      case 'customer':
        return 'Book and manage appointments';
      case 'barber':
        return 'Manage schedule and clients';
      case 'owner':
        return 'Manage shop, staff and services';
      default:
        return '';
    }
  }

  static Future<List<String>> availableRolesForCurrentUser() async {
    final roles = await UserRoleService.availableRolesForCurrentUser();
    final filtered = roles
        .where((r) => r == 'customer' || r == 'barber' || r == 'owner')
        .toSet();

    if (filtered.contains('owner')) {
      return const <String>['owner', 'barber', 'customer'];
    }
    if (filtered.contains('barber')) {
      return const <String>['barber', 'customer'];
    }
    return const <String>['customer'];
  }

  static Future<void> show(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? <String, dynamic>{};
    final roleList = await availableRolesForCurrentUser();
    if (roleList.isEmpty) return;
    final activeRole =
        ((data['activeRole'] as String?)?.trim().toLowerCase().isNotEmpty ??
            false)
        ? (data['activeRole'] as String).trim().toLowerCase()
        : roleList.first;
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0C0E12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  children: [
                    Text(
                      'Switch Role',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              for (final role in roleList)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 2,
                  ),
                  leading: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_icon(role), color: AppColors.gold, size: 18),
                  ),
                  title: Text(
                    _label(role),
                    style: const TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    _subtitle(role),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  trailing: role == activeRole
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Text(
                            'ACTIVE',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.35),
                        ),
                  onTap: () async {
                    await UserRoleService.setActiveRole(user.uid, role);
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
