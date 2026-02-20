import 'dart:math';

import 'package:barber_pro/role_switcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/user_role_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/data/firestore_data_mapper.dart';
import 'owner_data.dart';

const _bg = Color(0xFF0B0F1A);
const _surface = Color(0xFF070A12);
const _muted = Color(0xFF7A8599);

enum _BarberMenuAction { view, toggleEnabled, remove }

class OwnerStaffScreen extends StatefulWidget {
  const OwnerStaffScreen({super.key});

  @override
  State<OwnerStaffScreen> createState() => _OwnerStaffScreenState();
}

class _OwnerStaffScreenState extends State<OwnerStaffScreen> {
  final _email = TextEditingController();
  late final Future<String> _branchIdFuture;
  bool _saving = false;
  bool _showInvites = false;
  String _inviteCollection = 'invites';

  String get _pendingStatus =>
      _inviteCollection == 'invites' ? 'pending' : 'invited';

  @override
  void initState() {
    super.initState();
    _branchIdFuture = _resolveBranchId();
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<String> _resolveBranchId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return resolveAndEnsureShopId(user.uid);
  }

  bool _isEmailValid(String email) {
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return regex.hasMatch(email);
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<String> _generateUniqueCode() async {
    for (var i = 0; i < 10; i++) {
      final code = _generateInviteCode();
      final existing = await FirebaseFirestore.instance
          .collection(_inviteCollection)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }
    throw Exception('Could not generate invite code');
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _findExistingInvite(
    String branchId,
    String email,
  ) async {
    final now = DateTime.now();
    final snap = await FirebaseFirestore.instance
        .collection(_inviteCollection)
        .where('branchId', isEqualTo: branchId)
        .where('email', isEqualTo: email)
        .where('status', isEqualTo: _pendingStatus)
        .where('used', isEqualTo: false)
        .limit(20)
        .get();

    for (final d in snap.docs) {
      final expiresAt = d.data()['expiresAt'] as Timestamp?;
      final expired = expiresAt != null && expiresAt.toDate().isBefore(now);
      if (!expired) return d;
    }
    return null;
  }

  Future<void> _sendInvite(String branchId) async {
    if (_saving) return;
    final email = _email.text.trim().toLowerCase();
    if (!_isEmailValid(email)) {
      _snack('Enter a valid barber email');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final existing = await _findExistingInvite(branchId, email);
      if (existing != null) {
        final code = (existing.data()['code'] as String?) ?? '';
        if (code.isNotEmpty) {
          await _showCodeDialog(email, code, existing: true);
          return;
        }
      }

      final code = await _generateUniqueCode();
      await FirebaseFirestore.instance.collection(_inviteCollection).add({
        'code': code,
        'email': email,
        'branchId': branchId,
        'shopId': branchId,
        'ownerId': user.uid,
        'role': 'barber',
        'status': _pendingStatus,
        'used': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(hours: 72)),
        ),
      });

      _email.clear();
      await _showCodeDialog(email, code, existing: false);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' && _inviteCollection == 'invites') {
        setState(() => _inviteCollection = 'barber_invites');
        await _sendInvite(branchId);
        return;
      }
      _snack('Could not send invite: ${e.toString()}');
    } catch (e) {
      _snack('Could not send invite: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showCodeDialog(
    String email,
    String code, {
    required bool existing,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surface,
        title: Text(
          existing ? 'Invite Already Exists' : 'Invite Sent',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email: $email',
              style: const TextStyle(color: AppColors.onDark70),
            ),
            const SizedBox(height: 8),
            SelectableText(
              code,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 30,
                fontWeight: FontWeight.w700,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              Navigator.of(context).pop();
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelInvite(String inviteId) async {
    try {
      await FirebaseFirestore.instance
          .collection(_inviteCollection)
          .doc(inviteId)
          .update({
            'status': 'cancelled',
            'used': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      _snack('Could not cancel invite: ${e.toString()}');
    }
  }

  bool _isBarberUser(Map<String, dynamic> data) {
    final roles = data['roles'];
    if (roles is Map<String, dynamic>) return roles['barber'] == true;
    if (roles is List) return roles.any((r) => '$r'.toLowerCase() == 'barber');
    return ((data['role'] as String?) ?? '').toLowerCase() == 'barber';
  }

  Future<void> _setBarberActive(String userId, bool active) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'isActive': active,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      final branchId = await _branchIdFuture;
      if (branchId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(branchId)
            .collection('barbers')
            .doc(userId)
            .set({
              'isActive': active,
              'status': active ? 'active' : 'inactive',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } catch (e) {
      _snack('Could not update barber status: ${e.toString()}');
    }
  }

  Future<void> _removeBarberFromBranch(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      final update = <String, dynamic>{
        'branchId': null,
        'shopId': null,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final roles = data['roles'];
      if (roles is Map<String, dynamic>) {
        update['roles.barber'] = false;
      } else if (roles is List) {
        update['roles'] = FieldValue.arrayRemove(<String>['barber']);
      }

      final activeRole = (data['activeRole'] as String?)?.trim().toLowerCase();
      if (activeRole == 'barber') {
        update['activeRole'] = 'customer';
        update['role'] = 'customer';
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(update, SetOptions(merge: true));

      final branchId = await _branchIdFuture;
      if (branchId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(branchId)
            .collection('barbers')
            .doc(userId)
            .delete();
      }
    } catch (e) {
      _snack('Could not remove barber from branch: ${e.toString()}');
    }
  }

  Future<bool> _reauthenticateOwner(String password) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final email = user.email;
    if (email == null || email.isEmpty) return false;
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } on FirebaseAuthException {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _confirmDeleteBarber({
    required String userId,
    required Map<String, dynamic> data,
    required String barberName,
  }) async {
    final passwordController = TextEditingController();
    bool submitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final pass = passwordController.text;
              if (pass.isEmpty) return;
              setDialogState(() => submitting = true);
              final ok = await _reauthenticateOwner(pass);
              if (!ok) {
                if (!dialogContext.mounted) return;
                setDialogState(() => submitting = false);
                _snack('Wrong password');
                return;
              }
              await _removeBarberFromBranch(userId, data);
              if (!dialogContext.mounted) return;
              Navigator.of(dialogContext).pop();
              _snack('$barberName removed from branch');
            }

            return AlertDialog(
              backgroundColor: _surface,
              title: const Text(
                'Remove barber?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to remove $barberName from this branch?',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    enabled: !submitting,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Owner Password',
                      labelStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF0E1524),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.onDark12),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: AppColors.gold),
                      ),
                    ),
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: submitting ? null : submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF5A6D),
                    foregroundColor: Colors.white,
                  ),
                  child: submitting
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    passwordController.dispose();
  }

  Future<void> _toggleOwnerBarberMode(bool enabled) async {
    if (!enabled) {
      _snack('Owner barber mode cannot be disabled here');
      return;
    }
    final ok = await UserRoleService.enableBarberModeForOwnerCurrentUser();
    _snack(ok ? 'Barber mode enabled' : 'Could not enable barber mode');
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Text(
            'Please log in again',
            style: TextStyle(color: AppColors.onDark70),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: FutureBuilder<String>(
        future: _branchIdFuture,
        builder: (context, branchSnap) {
          if (branchSnap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            );
          }
          final branchId = branchSnap.data ?? '';
          if (branchId.isEmpty) {
            return const Center(
              child: Text(
                'No branch assigned',
                style: TextStyle(color: AppColors.onDark70),
              ),
            );
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .doc(branchId)
                .snapshots(),
            builder: (context, shopSnap) {
              final shopData =
                  shopSnap.data?.data() ?? const <String, dynamic>{};
              final branchName = FirestoreDataMapper.branchName(
                shopData,
                fallback: 'Downtown Branch',
              );

              return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, ownerSnap) {
                  final ownerData =
                      ownerSnap.data?.data() ?? const <String, dynamic>{};
                  final ownerAvatar = FirestoreDataMapper.userAvatar(
                    ownerData,
                    fallback: user.photoURL ?? '',
                  );
                  final roles = ownerData['roles'];
                  final ownerBarberEnabled = roles is Map<String, dynamic>
                      ? roles['barber'] == true
                      : roles is List
                      ? roles.any((r) => '$r'.toLowerCase() == 'barber')
                      : false;

                  return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection(_inviteCollection)
                        .where('branchId', isEqualTo: branchId)
                        .where('status', isEqualTo: _pendingStatus)
                        .where('used', isEqualTo: false)
                        .snapshots(),
                    builder: (context, inviteSnap) {
                      final now = DateTime.now();
                      final invites = (inviteSnap.data?.docs ?? const []).where(
                        (d) {
                          final expiresAt = d.data()['expiresAt'] as Timestamp?;
                          return expiresAt == null ||
                              expiresAt.toDate().isAfter(now);
                        },
                      ).toList();

                      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('branchId', isEqualTo: branchId)
                            .limit(250)
                            .snapshots(),
                        builder: (context, staffSnap) {
                          final staff = (staffSnap.data?.docs ?? const [])
                              .where((d) => _isBarberUser(d.data()))
                              .toList();
                          final filtered = staff;

                          return SafeArea(
                            child: ListView(
                              padding: EdgeInsets.zero,
                              children: [
                                Padding(
                                  padding: EdgeInsets.zero,
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      4,
                                      24,
                                      6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _bg.withValues(alpha: 0.92),
                                      border: Border(
                                        bottom: BorderSide(
                                          color: AppColors.gold.withValues(
                                            alpha: 0.20,
                                          ),
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Staff',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 24,
                                                  fontFamily: 'PlayfairDisplay',
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      branchName.toUpperCase(),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        color: AppColors.gold,
                                                        fontSize: 10,
                                                        letterSpacing: 2,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  const Icon(
                                                    Icons.expand_more,
                                                    color: AppColors.gold,
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          width: 40,
                                          height: 40,
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.gold,
                                              width: 2,
                                            ),
                                          ),
                                          child: ClipOval(
                                            child: ownerAvatar.isNotEmpty
                                                ? Image.network(
                                                    ownerAvatar,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (_, _, _) =>
                                                        Container(
                                                          color: const Color(
                                                            0xFF1B2230,
                                                          ),
                                                          alignment:
                                                              Alignment.center,
                                                          child: const Icon(
                                                            Icons.person,
                                                            color: AppColors
                                                                .onDark70,
                                                          ),
                                                        ),
                                                  )
                                                : Container(
                                                    color: const Color(
                                                      0xFF1B2230,
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: const Icon(
                                                      Icons.person,
                                                      color: AppColors.onDark70,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    22,
                                    16,
                                    22,
                                    110,
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.fromLTRB(
                                          18,
                                          16,
                                          18,
                                          14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _surface,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                          border: Border.all(
                                            color: AppColors.gold.withValues(
                                              alpha: 0.30,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  width: 56,
                                                  height: 56,
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFF2A1612,
                                                    ),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons
                                                        .person_add_alt_1_rounded,
                                                    color: AppColors.gold,
                                                    size: 28,
                                                  ),
                                                ),
                                                const SizedBox(width: 14),
                                                const Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Invite Barber',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      SizedBox(height: 2),
                                                      Text(
                                                        'GROWTH & SCALE',
                                                        style: TextStyle(
                                                          color: _muted,
                                                          fontSize: 13,
                                                          letterSpacing: 2.4,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 14),
                                            SizedBox(
                                              height: 48,
                                              child: TextField(
                                                controller: _email,
                                                keyboardType:
                                                    TextInputType.emailAddress,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                decoration: InputDecoration(
                                                  hintText:
                                                      'barber@pinnacle.com',
                                                  hintStyle: TextStyle(
                                                    color: AppColors.onDark35,
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  filled: true,
                                                  fillColor: const Color(
                                                    0xFF0E1524,
                                                  ),
                                                  contentPadding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 18,
                                                      ),
                                                  enabledBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              24,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: AppColors
                                                              .onDark12,
                                                        ),
                                                      ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              24,
                                                            ),
                                                        borderSide:
                                                            const BorderSide(
                                                              color: AppColors
                                                                  .gold,
                                                            ),
                                                      ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            SizedBox(
                                              width: double.infinity,
                                              height: 58,
                                              child: ElevatedButton(
                                                onPressed: _saving
                                                    ? null
                                                    : () =>
                                                          _sendInvite(branchId),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      AppColors.gold,
                                                  foregroundColor: const Color(
                                                    0xFF05070A,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          22,
                                                        ),
                                                  ),
                                                ),
                                                child: _saving
                                                    ? const SizedBox(
                                                        width: 24,
                                                        height: 24,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2.4,
                                                              color: Color(
                                                                0xFF05070A,
                                                              ),
                                                            ),
                                                      )
                                                    : const Text(
                                                        'SEND INVITE',
                                                        style: TextStyle(
                                                          fontSize: 17,
                                                          letterSpacing: 2.8,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                              ),
                                            ),
                                            const SizedBox(height: 10),
                                            Text(
                                              'Invite code will be generated and emailed.',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.42,
                                                ),
                                                fontSize: 12,
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Container(
                                        padding: const EdgeInsets.fromLTRB(
                                          18,
                                          16,
                                          18,
                                          14,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _surface,
                                          borderRadius: BorderRadius.circular(
                                            22,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.11,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                const Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Work as a barber',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 18,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                      SizedBox(height: 2),
                                                      Text(
                                                        'Enable barber tools for this account',
                                                        style: TextStyle(
                                                          color: _muted,
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Switch(
                                                  value: ownerBarberEnabled,
                                                  onChanged:
                                                      _toggleOwnerBarberMode,
                                                  activeThumbColor:
                                                      Colors.white,
                                                  activeTrackColor:
                                                      AppColors.gold,
                                                  inactiveThumbColor:
                                                      AppColors.onDark70,
                                                  inactiveTrackColor:
                                                      const Color(0xFF2A334A),
                                                ),
                                              ],
                                            ),
                                            Divider(
                                              color: Colors.white.withValues(
                                                alpha: 0.08,
                                              ),
                                              height: 20,
                                            ),
                                            InkWell(
                                              onTap: () =>
                                                  RoleSwitcher.show(context),
                                              child: const Row(
                                                children: [
                                                  Text(
                                                    'MANAGE MY BARBER PROFILE',
                                                    style: TextStyle(
                                                      color: AppColors.gold,
                                                      fontSize: 17 / 2,
                                                      letterSpacing: 2.0,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  SizedBox(width: 6),
                                                  Icon(
                                                    Icons.arrow_forward,
                                                    color: AppColors.gold,
                                                    size: 20,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _bigPill(
                                              'BARBERS (${staff.length})',
                                              !_showInvites,
                                              () => setState(
                                                () => _showInvites = false,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _bigPill(
                                              'INVITES (${invites.length})',
                                              _showInvites,
                                              () => setState(
                                                () => _showInvites = true,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _showInvites
                                            ? 'PENDING INVITES'
                                            : 'BARBERS',
                                        style: const TextStyle(
                                          color: _muted,
                                          fontSize: 13,
                                          letterSpacing: 2.6,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      if (_showInvites)
                                        if (invites.isEmpty)
                                          _empty('No pending invites')
                                        else
                                          ...invites.map((invite) {
                                            final data = invite.data();
                                            final email =
                                                (data['email'] as String?) ??
                                                '';
                                            final code =
                                                (data['code'] as String?) ?? '';
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  14,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: _surface,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  border: Border.all(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.11,
                                                        ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            email,
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize:
                                                                      15.5,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            'CODE :  $code',
                                                            style:
                                                                const TextStyle(
                                                                  color: _muted,
                                                                  fontSize:
                                                                      10.5,
                                                                  letterSpacing:
                                                                      1.2,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    OutlinedButton(
                                                      onPressed: () =>
                                                          _cancelInvite(
                                                            invite.id,
                                                          ),
                                                      style:
                                                          OutlinedButton.styleFrom(
                                                            foregroundColor:
                                                                const Color(
                                                                  0xFFFF5A6D,
                                                                ),
                                                            minimumSize:
                                                                const Size(
                                                                  92,
                                                                  38,
                                                                ),
                                                            side: BorderSide(
                                                              color:
                                                                  const Color(
                                                                    0xFFFF5A6D,
                                                                  ).withValues(
                                                                    alpha: 0.5,
                                                                  ),
                                                            ),
                                                          ),
                                                      child: const Text(
                                                        'REMOVE',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          letterSpacing: 2.0,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          })
                                      else if (filtered.isEmpty)
                                        _empty('No barbers for this filter')
                                      else
                                        ...filtered.map((doc) {
                                          final data = doc.data();
                                          final name =
                                              FirestoreDataMapper.userFullName(
                                                data,
                                                fallback: 'Barber',
                                              );
                                          final avatar =
                                              FirestoreDataMapper.userAvatar(
                                                data,
                                                fallback: '',
                                              );
                                          final active =
                                              (data['isActive'] as bool?) ??
                                              true;
                                          final onDuty =
                                              (data['onDuty'] as bool?) ??
                                              (data['isOnDuty'] as bool?) ??
                                              false;
                                          final isSelf = doc.id == user.uid;
                                          return Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 10,
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(14),
                                              decoration: BoxDecoration(
                                                color: _surface,
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: AppColors.gold
                                                      .withValues(alpha: 0.18),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                    child: avatar.isNotEmpty
                                                        ? Image.network(
                                                            avatar,
                                                            width: 60,
                                                            height: 60,
                                                            fit: BoxFit.cover,
                                                            errorBuilder:
                                                                (_, _, _) =>
                                                                    _avatarFallback(),
                                                          )
                                                        : _avatarFallback(),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          name,
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            color: active
                                                                ? Colors.white
                                                                : const Color(
                                                                    0xFFA5AFBF,
                                                                  ),
                                                            fontSize: 18,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        const Text(
                                                          'Today: 6 bookings',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: TextStyle(
                                                            color: _muted,
                                                            fontSize: 13,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 10,
                                                                vertical: 4,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: active
                                                                ? const Color(
                                                                    0xFF10B981,
                                                                  ).withValues(
                                                                    alpha: 0.14,
                                                                  )
                                                                : const Color(
                                                                    0xFF334155,
                                                                  ).withValues(
                                                                    alpha: 0.35,
                                                                  ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  999,
                                                                ),
                                                          ),
                                                          child: Text(
                                                            onDuty
                                                                ? 'ON DUTY'
                                                                : 'OFF DUTY',
                                                            style: TextStyle(
                                                              color: onDuty
                                                                  ? const Color(
                                                                      0xFF24D267,
                                                                    )
                                                                  : const Color(
                                                                      0xFF9BA7BA,
                                                                    ),
                                                              fontSize: 10,
                                                              letterSpacing:
                                                                  1.2,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Column(
                                                    children: [
                                                      PopupMenuButton<
                                                        _BarberMenuAction
                                                      >(
                                                        onSelected: (action) {
                                                          switch (action) {
                                                            case _BarberMenuAction
                                                                .view:
                                                              _snack(
                                                                'Profile view coming soon',
                                                              );
                                                              break;
                                                            case _BarberMenuAction
                                                                .toggleEnabled:
                                                              _setBarberActive(
                                                                doc.id,
                                                                !active,
                                                              );
                                                              break;
                                                            case _BarberMenuAction
                                                                .remove:
                                                              if (isSelf) {
                                                                _snack(
                                                                  'You cannot remove yourself',
                                                                );
                                                                return;
                                                              }
                                                              _confirmDeleteBarber(
                                                                userId: doc.id,
                                                                data: data,
                                                                barberName:
                                                                    name,
                                                              );
                                                              break;
                                                          }
                                                        },
                                                        color: _surface,
                                                        icon: const Icon(
                                                          Icons.more_horiz,
                                                          color: AppColors
                                                              .onDark70,
                                                          size: 24,
                                                        ),
                                                        itemBuilder: (context) => [
                                                          const PopupMenuItem(
                                                            value:
                                                                _BarberMenuAction
                                                                    .view,
                                                            child: Text(
                                                              'View profile',
                                                            ),
                                                          ),
                                                          PopupMenuItem(
                                                            value: _BarberMenuAction
                                                                .toggleEnabled,
                                                            child: Text(
                                                              active
                                                                  ? 'Disable'
                                                                  : 'Enable',
                                                            ),
                                                          ),
                                                          const PopupMenuItem(
                                                            value:
                                                                _BarberMenuAction
                                                                    .remove,
                                                            child: Text(
                                                              'Remove from branch',
                                                              style: TextStyle(
                                                                color: Color(
                                                                  0xFFFF5A6D,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Text(
                                                        onDuty
                                                            ? 'ON DUTY'
                                                            : 'OFF DUTY',
                                                        style: const TextStyle(
                                                          color: _muted,
                                                          fontSize: 10,
                                                          letterSpacing: 1.0,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _bigPill(String label, bool active, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: active ? AppColors.gold : const Color(0xFF121B2C),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.gold : AppColors.onDark12,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? const Color(0xFF05070A) : AppColors.onDark70,
            fontSize: 11,
            letterSpacing: 2.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _empty(String message) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.onDark08),
      ),
      child: Text(message, style: const TextStyle(color: _muted, fontSize: 14)),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 60,
      height: 60,
      color: const Color(0xFF182131),
      alignment: Alignment.center,
      child: const Icon(Icons.person, color: AppColors.onDark70),
    );
  }
}
