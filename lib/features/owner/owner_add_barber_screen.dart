import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth/user_role_service.dart';
import '../../core/theme/app_colors.dart';
import 'owner_data.dart';
import 'owner_ui.dart';

class OwnerAddBarberScreen extends StatefulWidget {
  const OwnerAddBarberScreen({super.key});

  @override
  State<OwnerAddBarberScreen> createState() => _OwnerAddBarberScreenState();
}

class _OwnerAddBarberScreenState extends State<OwnerAddBarberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _saving = false;
  bool _expiring = false;
  late final Future<String> _branchIdFuture;

  String _inviteCollection = 'invites';

  String get _pendingStatus =>
      _inviteCollection == 'invites' ? 'pending' : 'invited';

  @override
  void initState() {
    super.initState();
    _branchIdFuture = _resolveOwnerBranchId();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<String> _resolveOwnerBranchId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return resolveAndEnsureShopId(user.uid);
  }

  bool _isEmailValid(String email) {
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailPattern.hasMatch(email);
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  Future<String> _generateUniqueInviteCode() async {
    for (var i = 0; i < 10; i++) {
      final code = _generateInviteCode();
      final existing = await FirebaseFirestore.instance
          .collection(_inviteCollection)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    }
    throw Exception('Could not generate unique invite code');
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
  _findExistingPendingInvite(String branchId, String email) async {
    final now = DateTime.now();
    final snap = await FirebaseFirestore.instance
        .collection(_inviteCollection)
        .where('branchId', isEqualTo: branchId)
        .where('email', isEqualTo: email)
        .where('status', isEqualTo: _pendingStatus)
        .where('used', isEqualTo: false)
        .limit(20)
        .get();

    for (final doc in snap.docs) {
      final data = doc.data();
      final expiresAt = data['expiresAt'] as Timestamp?;
      final expired = expiresAt == null
          ? false
          : expiresAt.toDate().isBefore(now);
      if (!expired) return doc;
    }
    return null;
  }

  Future<void> _copyCode(BuildContext context, String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite code copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _copyResendMessage(
    BuildContext context, {
    required String email,
    required String code,
  }) async {
    final message =
        'BarberPro invite\nEmail: $email\nCode: $code\n\nUse this code in "Join as Barber".';
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite message copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _showInviteDialog({
    required String email,
    required String code,
    required bool existing,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(existing ? 'Invite Already Exists' : 'Invite Sent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: $email'),
              const SizedBox(height: 12),
              const Text(
                'Invite Code',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Center(
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    fontSize: 28,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => _copyCode(context, code),
              child: const Text('Copy Code'),
            ),
            if (existing)
              TextButton(
                onPressed: () =>
                    _copyResendMessage(context, email: email, code: code),
                child: const Text('Resend'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _enableBarberModeForMe() async {
    final ok = await UserRoleService.enableBarberModeForOwnerCurrentUser();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Barber mode enabled for your account'
              : 'Could not enable barber mode. Create/select your branch first.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendInvite(String branchId) async {
    if (_saving) return;
    final rawEmail = _emailController.text.trim().toLowerCase();

    if (rawEmail.isEmpty || !_isEmailValid(rawEmail)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid barber email'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      final existing = await _findExistingPendingInvite(branchId, rawEmail);
      if (existing != null) {
        final existingCode = (existing.data()['code'] as String?) ?? '';
        if (existingCode.isNotEmpty) {
          await _showInviteDialog(
            email: rawEmail,
            code: existingCode,
            existing: true,
          );
          return;
        }
      }

      final code = await _generateUniqueInviteCode();
      final now = DateTime.now();
      await FirebaseFirestore.instance.collection(_inviteCollection).add({
        'code': code,
        'email': rawEmail,
        'branchId': branchId,
        'shopId': branchId,
        'ownerId': user.uid,
        'role': 'barber',
        'status': _pendingStatus,
        'used': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 72))),
      });

      _emailController.clear();
      await _showInviteDialog(email: rawEmail, code: code, existing: false);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' && _inviteCollection == 'invites') {
        if (mounted) {
          setState(() {
            _saving = false;
            _inviteCollection = 'barber_invites';
          });
        }
        await _sendInvite(branchId);
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send invite: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send invite: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not cancel invite: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _markExpired(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    if (_expiring || docs.isEmpty) return;
    setState(() => _expiring = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in docs) {
        batch.update(doc.reference, {
          'status': 'expired',
          'used': true,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not mark expired invites: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _expiring = false);
    }
  }

  bool _isBarberUser(Map<String, dynamic> data) {
    final roles = data['roles'];
    if (roles is Map<String, dynamic>) {
      return roles['barber'] == true;
    }
    if (roles is List) {
      return roles.any((r) => r is String && r.toLowerCase() == 'barber');
    }
    final role = (data['role'] as String?)?.toLowerCase();
    return role == 'barber';
  }

  Future<void> _deactivateBarber(String userId) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'isActive': false,
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
              'isActive': false,
              'status': 'inactive',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not deactivate barber: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _activateBarber(String userId) async {
    try {
      final branchId = await _branchIdFuture;
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final userData = userSnap.data() ?? <String, dynamic>{};
      final roles = userData['roles'];
      final update = <String, dynamic>{
        'isActive': true,
        'branchId': branchId,
        'shopId': branchId,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (roles is Map<String, dynamic>) {
        update['roles.barber'] = true;
      } else {
        update['roles'] = FieldValue.arrayUnion(<String>['barber']);
      }
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        ...update,
      }, SetOptions(merge: true));
      if (branchId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('shops')
            .doc(branchId)
            .collection('barbers')
            .doc(userId)
            .set({
              'barberId': userId,
              'barberUserId': userId,
              'shopId': branchId,
              'isActive': true,
              'status': 'active',
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not activate barber: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not remove barber from branch: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatTs(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final minute = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: OwnerUi.screenBg,
      body: FutureBuilder<String>(
        future: _branchIdFuture,
        builder: (context, branchSnapshot) {
          if (branchSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            );
          }

          final branchId = branchSnapshot.data ?? '';
          if (branchId.isEmpty) {
            return const Center(
              child: Text(
                'No branch assigned',
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return Stack(
            children: [
              OwnerUi.background(),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Staff', style: OwnerUi.pageTitleStyle()),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: OwnerUi.panelDecoration(),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(color: AppColors.text),
                                decoration: OwnerUi.inputDecoration(
                                  'Barber Email',
                                ),
                                validator: (value) {
                                  final email = (value ?? '')
                                      .trim()
                                      .toLowerCase();
                                  if (email.isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!_isEmailValid(email)) {
                                    return 'Enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                height: 46,
                                child: ElevatedButton(
                                  onPressed: _saving
                                      ? null
                                      : () {
                                          if (!_formKey.currentState!
                                              .validate()) {
                                            return;
                                          }
                                          _sendInvite(branchId);
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.gold,
                                    foregroundColor: const Color(0xFF05070A),
                                  ),
                                  child: Text(
                                    _saving ? 'SENDING...' : 'SEND INVITE',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 42,
                        child: OutlinedButton(
                          onPressed: _enableBarberModeForMe,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.gold,
                            side: BorderSide(
                              color: AppColors.gold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Text(
                            'ENABLE BARBER MODE FOR ME',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.0,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'PENDING INVITES',
                        style: OwnerUi.sectionLabelStyle(),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 170,
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection(_inviteCollection)
                                  .where('branchId', isEqualTo: branchId)
                                  .where('status', isEqualTo: _pendingStatus)
                                  .where('used', isEqualTo: false)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.gold,
                                    ),
                                  );
                                }

                                final now = DateTime.now();
                                final docs = (snapshot.data?.docs ?? const []);
                                final pending = docs.where((d) {
                                  final expires =
                                      d.data()['expiresAt'] as Timestamp?;
                                  if (expires == null) return true;
                                  return expires.toDate().isAfter(now);
                                }).toList();

                                if (pending.isEmpty) {
                                  return Container(
                                    alignment: Alignment.center,
                                    decoration: OwnerUi.panelDecoration(
                                      radius: 14,
                                    ),
                                    child: Text(
                                      'No pending invites',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.6,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  itemCount: pending.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final doc = pending[index];
                                    final data = doc.data();
                                    final email =
                                        (data['email'] as String?) ?? '';
                                    final code =
                                        (data['code'] as String?) ?? '';
                                    final createdAt =
                                        data['createdAt'] as Timestamp?;
                                    return Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: OwnerUi.panelDecoration(
                                        radius: 12,
                                        alpha: 0.08,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            email,
                                            style: const TextStyle(
                                              color: AppColors.text,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Code: $code',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            'Created: ${_formatTs(createdAt)}',
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.45,
                                              ),
                                              fontSize: 11,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              TextButton(
                                                onPressed: () =>
                                                    _copyCode(context, code),
                                                child: const Text('COPY CODE'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    _copyResendMessage(
                                                      context,
                                                      email: email,
                                                      code: code,
                                                    ),
                                                child: const Text('RESEND'),
                                              ),
                                              TextButton(
                                                onPressed: () =>
                                                    _cancelInvite(doc.id),
                                                child: Text(
                                                  'CANCEL',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.75,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'EXPIRED INVITES',
                        style: OwnerUi.sectionLabelStyle(),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 78,
                        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: FirebaseFirestore.instance
                              .collection(_inviteCollection)
                              .where('branchId', isEqualTo: branchId)
                              .where('status', isEqualTo: _pendingStatus)
                              .where('used', isEqualTo: false)
                              .snapshots(),
                          builder: (context, snapshot) {
                            final now = DateTime.now();
                            final docs = (snapshot.data?.docs ?? const [])
                                .where((d) {
                                  final expires =
                                      d.data()['expiresAt'] as Timestamp?;
                                  if (expires == null) return false;
                                  return !expires.toDate().isAfter(now);
                                })
                                .toList();

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: OwnerUi.panelDecoration(
                                radius: 12,
                                alpha: 0.08,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      docs.isEmpty
                                          ? 'No expired pending invites'
                                          : '${docs.length} expired pending invite(s)',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: (docs.isEmpty || _expiring)
                                        ? null
                                        : () => _markExpired(docs),
                                    child: Text(
                                      _expiring
                                          ? 'UPDATING...'
                                          : 'MARK EXPIRED',
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('BARBERS', style: OwnerUi.sectionLabelStyle()),
                      const SizedBox(height: 8),
                      Expanded(
                        child:
                            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .where('branchId', isEqualTo: branchId)
                                  .limit(200)
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.gold,
                                    ),
                                  );
                                }

                                final docs = (snapshot.data?.docs ?? const [])
                                    .where((d) => _isBarberUser(d.data()))
                                    .toList();

                                if (docs.isEmpty) {
                                  return Center(
                                    child: Text(
                                      'No barbers in this branch',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  padding: const EdgeInsets.only(bottom: 24),
                                  itemCount: docs.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final doc = docs[index];
                                    final data = doc.data();
                                    final isSelf =
                                        currentUid != null &&
                                        currentUid.isNotEmpty &&
                                        doc.id == currentUid;
                                    final fullName =
                                        ((data['fullName'] as String?)
                                                ?.trim()
                                                .isNotEmpty ??
                                            false)
                                        ? (data['fullName'] as String).trim()
                                        : (((data['name'] as String?)
                                                      ?.trim()
                                                      .isNotEmpty ??
                                                  false)
                                              ? (data['name'] as String).trim()
                                              : 'Unnamed');
                                    final email =
                                        (data['email'] as String?) ?? '-';
                                    final isActive = data['isActive'] == true;

                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: OwnerUi.panelDecoration(
                                        radius: 12,
                                        alpha: 0.08,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fullName,
                                            style: const TextStyle(
                                              color: AppColors.text,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            email,
                                            style: TextStyle(
                                              color: Colors.white.withValues(
                                                alpha: 0.6,
                                              ),
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            isActive ? 'Active' : 'Inactive',
                                            style: TextStyle(
                                              color: isActive
                                                  ? AppColors.gold
                                                  : Colors.white.withValues(
                                                      alpha: 0.5,
                                                    ),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          if (isSelf)
                                            Text(
                                              'Owner account',
                                              style: TextStyle(
                                                color: Colors.white.withValues(
                                                  alpha: 0.6,
                                                ),
                                                fontSize: 12,
                                              ),
                                            )
                                          else
                                            Row(
                                              children: [
                                                OutlinedButton(
                                                  onPressed: () => isActive
                                                      ? _deactivateBarber(
                                                          doc.id,
                                                        )
                                                      : _activateBarber(doc.id),
                                                  style:
                                                      OutlinedButton.styleFrom(
                                                        side: BorderSide(
                                                          color: Colors.white
                                                              .withValues(
                                                                alpha: 0.20,
                                                              ),
                                                        ),
                                                      ),
                                                  child: Text(
                                                    isActive
                                                        ? 'Deactivate'
                                                        : 'Activate',
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                TextButton(
                                                  onPressed: () =>
                                                      _removeBarberFromBranch(
                                                        doc.id,
                                                        data,
                                                      ),
                                                  child: Text(
                                                    'Remove from Branch',
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.75,
                                                          ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
