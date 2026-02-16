import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserRoleService {
  static const Set<String> allowedRoles = <String>{
    'customer',
    'barber',
    'owner',
    'superadmin',
  };

  static String normalizeRole(String role) => role.trim().toLowerCase();

  static Set<String> extractRoles(Map<String, dynamic> data) {
    final Set<String> roles = <String>{};

    final legacyRole = (data['role'] as String?)?.trim().toLowerCase();
    if (legacyRole != null && legacyRole.isNotEmpty) {
      roles.add(legacyRole);
    }

    final activeRole = (data['activeRole'] as String?)?.trim().toLowerCase();
    if (activeRole != null && activeRole.isNotEmpty) {
      roles.add(activeRole);
    }

    final rawRoles = data['roles'];
    if (rawRoles is List) {
      for (final value in rawRoles) {
        if (value is String && value.trim().isNotEmpty) {
          roles.add(value.trim().toLowerCase());
        }
      }
    } else if (rawRoles is Map<String, dynamic>) {
      for (final entry in rawRoles.entries) {
        if (entry.value == true) {
          final role = entry.key.trim().toLowerCase();
          if (role.isNotEmpty) roles.add(role);
        }
      }
    }

    roles.removeWhere((role) => !allowedRoles.contains(role));
    if (roles.contains('superadmin')) {
      return <String>{'superadmin'};
    }
    if (roles.isEmpty) roles.add('customer');
    return roles;
  }

  static Future<Set<String>> inferRolesForUser(
    String uid,
    Map<String, dynamic> userData,
  ) async {
    final roles = extractRoles(userData);
    if (roles.contains('superadmin')) {
      return <String>{'superadmin'};
    }

    try {
      final ownShopByDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(uid)
          .get();
      if (ownShopByDoc.exists) {
        roles.add('owner');
      } else {
        final ownShopByOwnerId = await FirebaseFirestore.instance
            .collection('shops')
            .where('ownerId', isEqualTo: uid)
            .limit(1)
            .get();
        if (ownShopByOwnerId.docs.isNotEmpty) {
          roles.add('owner');
        }
      }
    } catch (_) {}

    final barberShopId = await _resolveValidBarberShopId(uid, userData);
    if (barberShopId != null) {
      roles.add('barber');
    } else {
      roles.remove('barber');
    }

    roles.removeWhere((role) => !allowedRoles.contains(role));
    if (roles.isEmpty) roles.add('customer');
    return roles;
  }

  static Future<String?> _resolveValidBarberShopId(
    String uid,
    Map<String, dynamic> userData,
  ) async {
    final shopId = _extractBranchId(userData);
    if (shopId == null || shopId.isEmpty) return null;

    try {
      final membership = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('barbers')
          .doc(uid)
          .get();
      if (!membership.exists) return null;
      final membershipData = membership.data() ?? const <String, dynamic>{};
      if (membershipData['isActive'] == false) return null;

      final shopDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .get();
      if (!shopDoc.exists) return null;
      final shopData = shopDoc.data() ?? const <String, dynamic>{};
      final ownerId = (shopData['ownerId'] as String?)?.trim();
      if (ownerId == null || ownerId.isEmpty) return null;
      return shopId;
    } catch (_) {
      return null;
    }
  }

  static String? _extractBranchId(Map<String, dynamic> userData) {
    final branchId = (userData['branchId'] as String?)?.trim();
    if (branchId != null && branchId.isNotEmpty) return branchId;
    final shopId = (userData['shopId'] as String?)?.trim();
    if (shopId != null && shopId.isNotEmpty) return shopId;
    return null;
  }

  static Future<List<String>> availableRolesForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const <String>[];

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data() ?? <String, dynamic>{};
    final roles = await inferRolesForUser(user.uid, data);
    final list = roles.toList()..sort();
    return list;
  }

  static Future<void> ensureIdentityDoc(
    User user, {
    Set<String> defaultRoles = const <String>{'customer'},
  }) async {
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final existing = await userRef.get();
    final data = existing.data() ?? <String, dynamic>{};
    final existingRoles = extractRoles(data);
    final mergedRoles = <String>{...existingRoles, ...defaultRoles};

    final patch = <String, dynamic>{
      'uid': user.uid,
      'fullName': (data['fullName'] as String?)?.trim().isNotEmpty == true
          ? (data['fullName'] as String).trim()
          : (user.displayName?.trim().isNotEmpty == true
                ? user.displayName!.trim()
                : ''),
      'email': (user.email ?? '').trim().toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    _applyRolesPatch(patch, data['roles'], mergedRoles);
    if ((data['activeRole'] as String?)?.trim().isEmpty ?? true) {
      patch['activeRole'] = mergedRoles.first;
      patch['role'] = mergedRoles.first;
    }
    if (!existing.exists) {
      patch['createdAt'] = FieldValue.serverTimestamp();
    }

    await userRef.set(patch, SetOptions(merge: true));
  }

  static Future<void> setActiveRole(String uid, String role) async {
    final normalized = normalizeRole(role);
    if (!allowedRoles.contains(normalized)) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final existing = await userRef.get();
    final data = existing.data() ?? <String, dynamic>{};
    final roles = extractRoles(data)..add(normalized);
    if (roles.contains('superadmin')) {
      roles
        ..clear()
        ..add('superadmin');
    }

    final patch = <String, dynamic>{
      'activeRole': normalized,
      'role': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    _applyRolesPatch(patch, data['roles'], roles);
    await userRef.set(patch, SetOptions(merge: true));
  }

  static Future<bool> enableBarberModeForOwnerCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    final roles = await inferRolesForUser(user.uid, userData);
    if (!roles.contains('owner')) return false;

    String? branchId;
    final docAsShop = await FirebaseFirestore.instance
        .collection('shops')
        .doc(user.uid)
        .get();
    if (docAsShop.exists) {
      branchId = docAsShop.id;
    } else {
      final byOwner = await FirebaseFirestore.instance
          .collection('shops')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();
      if (byOwner.docs.isNotEmpty) {
        branchId = byOwner.docs.first.id;
      }
    }
    if (branchId == null || branchId.isEmpty) return false;

    final fullName =
        (userData['fullName'] as String?)?.trim().isNotEmpty == true
        ? (userData['fullName'] as String).trim()
        : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : 'Owner Barber');
    final email = (user.email ?? '').trim().toLowerCase();

    await FirebaseFirestore.instance
        .collection('shops')
        .doc(branchId)
        .collection('barbers')
        .doc(user.uid)
        .set({
          'barberId': user.uid,
          'barberUserId': user.uid,
          'shopId': branchId,
          'ownerId': user.uid,
          'name': fullName,
          'email': email,
          'status': 'active',
          'isActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    final updatedRoles = extractRoles(userData)..add('barber');
    final patch = <String, dynamic>{
      'branchId': branchId,
      'shopId': branchId,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    _applyRolesPatch(patch, userData['roles'], updatedRoles);
    await userRef.set(patch, SetOptions(merge: true));
    await setActiveRole(user.uid, 'barber');
    return true;
  }

  static void _applyRolesPatch(
    Map<String, dynamic> patch,
    dynamic existingRolesField,
    Set<String> roles,
  ) {
    if (existingRolesField is Map<String, dynamic>) {
      for (final role in allowedRoles) {
        patch['roles.$role'] = roles.contains(role);
      }
    } else {
      patch['roles'] = roles.toList()..sort();
    }
  }
}
