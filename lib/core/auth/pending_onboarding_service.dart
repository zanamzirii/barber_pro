import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'user_role_service.dart';

class PendingOnboardingService {
  static CollectionReference<Map<String, dynamic>> get _pendingCollection =>
      FirebaseFirestore.instance.collection('pending_onboarding');

  static Future<void> savePendingRegistration({required User user}) async {
    final payload = <String, dynamic>{
      'uid': user.uid,
      'type': 'register',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    try {
      await _pendingCollection
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      await _savePendingFallbackOnUserDoc(user, payload);
    }
  }

  static Future<void> savePendingInvite({
    required User user,
    required String inviteCollection,
    required String inviteId,
    required String code,
    required String role,
    String? branchId,
    String? shopId,
    String? ownerId,
    String? shopName,
    String? shopLocation,
  }) async {
    final payload = <String, dynamic>{
      'uid': user.uid,
      'type': 'invite',
      'inviteCollection': inviteCollection,
      'inviteId': inviteId,
      'code': code,
      'role': role.trim().toLowerCase(),
      'branchId': (branchId ?? '').trim(),
      'shopId': (shopId ?? '').trim(),
      'ownerId': (ownerId ?? '').trim(),
      'shopName': (shopName ?? '').trim(),
      'shopLocation': (shopLocation ?? '').trim(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
    try {
      await _pendingCollection
          .doc(user.uid)
          .set(payload, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      await _savePendingFallbackOnUserDoc(user, payload);
    }
  }

  static Future<void> finalizeForCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !user.emailVerified) return;

    final uid = user.uid;
    final pendingRef = _pendingCollection.doc(uid);
    final pendingSnap = await pendingRef.get();
    Map<String, dynamic>? pending = pendingSnap.data();
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    DocumentSnapshot<Map<String, dynamic>>? userSnap;

    if (pending == null) {
      userSnap = await userRef.get();
      final userData = userSnap.data() ?? const <String, dynamic>{};
      final fallbackPending = userData['pendingOnboarding'];
      if (fallbackPending is Map<String, dynamic>) {
        pending = fallbackPending;
      }
    }

    if (pending == null) {
      await _ensureVerifiedIdentity(user);
      return;
    }

    final type = ((pending['type'] as String?) ?? '').trim().toLowerCase();
    if (type == 'register') {
      await _finalizeRegistration(user, pending);
    } else if (type == 'invite') {
      await _finalizeInvite(user, pending);
    } else {
      await _ensureVerifiedIdentity(user);
    }

    try {
      await pendingRef.delete();
    } catch (_) {}
    try {
      await userRef.set({
        'pendingOnboarding': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> _savePendingFallbackOnUserDoc(
    User user,
    Map<String, dynamic> payload,
  ) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': (user.email ?? '').trim().toLowerCase(),
      'fullName': (user.displayName ?? '').trim(),
      'pendingOnboarding': payload,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _ensureVerifiedIdentity(User user) async {
    await UserRoleService.ensureIdentityDoc(
      user,
      defaultRoles: const {'customer'},
    );
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fullName': (user.displayName ?? '').trim(),
      'email': (user.email ?? '').trim().toLowerCase(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _finalizeRegistration(
    User user,
    Map<String, dynamic> pending,
  ) async {
    final fullName = (user.displayName ?? '').trim();
    if (fullName.isNotEmpty && user.displayName?.trim() != fullName) {
      try {
        await user.updateDisplayName(fullName);
      } catch (_) {}
    }

    await UserRoleService.ensureIdentityDoc(
      user,
      defaultRoles: const {'customer'},
    );
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': (user.email ?? '').trim().toLowerCase(),
      'fullName': fullName.isNotEmpty
          ? fullName
          : (user.displayName ?? '').trim(),
      'roles': FieldValue.arrayUnion(<String>['customer']),
      'activeRole': 'customer',
      'role': 'customer',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> _finalizeInvite(
    User user,
    Map<String, dynamic> pending,
  ) async {
    final role = ((pending['role'] as String?) ?? '').trim().toLowerCase();
    if (role != 'barber' && role != 'owner') {
      await _ensureVerifiedIdentity(user);
      return;
    }

    final email = (user.email ?? '').trim().toLowerCase();
    final fullName = (user.displayName ?? '').trim();

    if (fullName.isNotEmpty && user.displayName?.trim() != fullName) {
      try {
        await user.updateDisplayName(fullName);
      } catch (_) {}
    }

    final defaultRoles = role == 'owner'
        ? const <String>{'customer', 'barber', 'owner'}
        : const <String>{'customer', 'barber'};
    await UserRoleService.ensureIdentityDoc(user, defaultRoles: defaultRoles);

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? const <String, dynamic>{};
    final existingRoles = UserRoleService.extractRoles(userData);

    final branchId = ((pending['branchId'] as String?) ?? '').trim();
    final ownerId = ((pending['ownerId'] as String?) ?? '').trim();
    final shopName = ((pending['shopName'] as String?) ?? '').trim();
    final shopLocation = ((pending['shopLocation'] as String?) ?? '').trim();

    final patch = <String, dynamic>{
      'uid': user.uid,
      'email': email,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (fullName.isNotEmpty) {
      patch['fullName'] = fullName;
    }
    if (!userDoc.exists) {
      patch['createdAt'] = FieldValue.serverTimestamp();
    }

    if (role == 'barber') {
      if (branchId.isEmpty) {
        throw Exception('Invite missing branch information');
      }
      if (existingRoles.contains('owner')) {
        final ownerShopId =
            ((userData['shopId'] as String?) ?? '').trim().isNotEmpty
            ? ((userData['shopId'] as String?) ?? '').trim()
            : ((userData['branchId'] as String?) ?? '').trim();
        if (ownerShopId.isNotEmpty && ownerShopId != branchId) {
          throw Exception(
            'Owner/barber account cannot join another branch as barber.',
          );
        }
      }
      patch['branchId'] = branchId;
      patch['shopId'] = branchId;
      patch['ownerId'] = ownerId;
      patch['isActive'] = true;
    } else {
      // Owner invite finalization always provisions the owner's own shop id.
      // Using foreign/pre-created IDs can violate Firestore rules.
      final shopId = user.uid;
      await _cleanPreviousBarberEmploymentForOwnerTransition(user.uid, shopId);
      patch['shopId'] = shopId;
      patch['branchId'] = shopId;
      patch['shopName'] = shopName.isNotEmpty ? shopName : 'My Branch';
      patch['shopLocation'] = shopLocation;

      await FirebaseFirestore.instance.collection('shops').doc(shopId).set({
        'ownerId': user.uid,
        'name': shopName.isNotEmpty ? shopName : 'My Branch',
        'location': shopLocation,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _safeWriteBarberMembership(
        uid: user.uid,
        email: email,
        name: (user.displayName ?? fullName).trim(),
        branchId: shopId,
        ownerId: user.uid,
      );
    }

    await userRef.set(patch, SetOptions(merge: true));
    await UserRoleService.setActiveRole(user.uid, role);

    if (role == 'barber' && branchId.isNotEmpty) {
      await _safeWriteBarberMembership(
        uid: user.uid,
        email: email,
        name: (user.displayName ?? fullName).trim(),
        branchId: branchId,
        ownerId: ownerId,
      );
    }

    final inviteCollection = ((pending['inviteCollection'] as String?) ?? '')
        .trim();
    final inviteId = ((pending['inviteId'] as String?) ?? '').trim();
    if (inviteCollection.isNotEmpty && inviteId.isNotEmpty) {
      try {
        await FirebaseFirestore.instance
            .collection(inviteCollection)
            .doc(inviteId)
            .update({
              'status': inviteCollection == 'invites' ? 'accepted' : 'used',
              'used': true,
              'claimedBy': user.uid,
              'claimedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
      } catch (_) {}
    }
  }

  static Future<void> _safeWriteBarberMembership({
    required String uid,
    required String email,
    required String name,
    required String branchId,
    required String ownerId,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(branchId)
          .collection('barbers')
          .doc(uid)
          .set({
            'barberId': uid,
            'barberUserId': uid,
            'shopId': branchId,
            'ownerId': ownerId,
            'name': name,
            'email': email,
            'status': 'active',
            'isActive': true,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<void> _cleanPreviousBarberEmploymentForOwnerTransition(
    String uid,
    String targetShopId,
  ) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data() ?? const <String, dynamic>{};
      final previousShopId =
          ((userData['shopId'] as String?) ?? '').trim().isNotEmpty
          ? ((userData['shopId'] as String?) ?? '').trim()
          : ((userData['branchId'] as String?) ?? '').trim();

      if (previousShopId.isNotEmpty && previousShopId != targetShopId) {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(previousShopId)
            .collection('barbers')
            .doc(uid)
            .delete();

        await _deleteByBarberAndShop('commissions', uid, previousShopId);
        await _deleteByBarberAndShop('barber_services', uid, previousShopId);
        await _deleteByBarberAndShop('barber_schedules', uid, previousShopId);
      }
    } catch (_) {}
  }

  static Future<void> _deleteByBarberAndShop(
    String collection,
    String barberId,
    String shopId,
  ) async {
    try {
      while (true) {
        final snap = await FirebaseFirestore.instance
            .collection(collection)
            .where('barberId', isEqualTo: barberId)
            .where('shopId', isEqualTo: shopId)
            .limit(200)
            .get();
        if (snap.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in snap.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      }
    } catch (_) {}
  }
}
