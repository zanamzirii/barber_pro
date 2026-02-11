import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RoleSwitcher {
  static const List<String> _allowedRoles = <String>[
    'customer',
    'barber',
    'owner',
    'superadmin',
  ];

  static String _label(String role) {
    switch (role) {
      case 'customer':
        return 'Customer';
      case 'barber':
        return 'Barber';
      case 'owner':
        return 'Owner';
      case 'superadmin':
        return 'Super Admin';
      default:
        return role;
    }
  }

  static Set<String> _extractRoles(Map<String, dynamic> data) {
    final Set<String> roles = <String>{};
    final legacyRole = (data['role'] as String?)?.trim().toLowerCase();
    if (legacyRole != null && legacyRole.isNotEmpty) {
      roles.add(legacyRole);
    }

    final rawRoles = data['roles'];
    if (rawRoles is List) {
      for (final value in rawRoles) {
        if (value is String && value.trim().isNotEmpty) {
          roles.add(value.trim().toLowerCase());
        }
      }
    }

    if (roles.isEmpty) {
      roles.add('customer');
    }
    return roles;
  }

  static Set<String> _applyRolePolicy(Set<String> roles) {
    // Owner can always act as barber/customer.
    if (roles.contains('owner')) {
      roles.add('barber');
      roles.add('customer');
    }
    // Barber can always act as customer.
    if (roles.contains('barber')) {
      roles.add('customer');
    }
    roles.removeWhere((role) => !_allowedRoles.contains(role));
    return roles;
  }

  static Future<T?> _safeQuery<T>(Future<T> Function() run) async {
    try {
      return await run();
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> availableRolesForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const <String>[];

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final ownShopByDocId = await _safeQuery(
      () => FirebaseFirestore.instance.collection('shops').doc(user.uid).get(),
    );
    final ownShopByOwnerId = await _safeQuery(
      () => FirebaseFirestore.instance
          .collection('shops')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get(),
    );
    final barberByUserId = await _safeQuery(
      () => FirebaseFirestore.instance
          .collectionGroup('barbers')
          .where('barberUserId', isEqualTo: user.uid)
          .limit(1)
          .get(),
    );
    final barberByBarberId = await _safeQuery(
      () => FirebaseFirestore.instance
          .collectionGroup('barbers')
          .where('barberId', isEqualTo: user.uid)
          .limit(1)
          .get(),
    );

    final data = doc.data() ?? <String, dynamic>{};
    final Set<String> roles = _extractRoles(data);

    if ((ownShopByDocId?.exists ?? false) ||
        (ownShopByOwnerId?.docs.isNotEmpty ?? false)) {
      roles.add('owner');
    }
    if ((barberByUserId?.docs.isNotEmpty ?? false) ||
        (barberByBarberId?.docs.isNotEmpty ?? false)) {
      roles.add('barber');
    }

    _applyRolePolicy(roles);
    final roleList = roles.toList()..sort();
    return roleList;
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
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text(
                  'Switch Role',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              for (final role in roleList)
                ListTile(
                  leading: Icon(
                    role == activeRole
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                  ),
                  title: Text(_label(role)),
                  onTap: () async {
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .set({
                          'roles': FieldValue.arrayUnion(<String>[role]),
                          'activeRole': role,
                          'role': role,
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                    }
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}
