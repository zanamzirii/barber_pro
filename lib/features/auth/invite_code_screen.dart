import 'package:barber_pro/app_shell.dart';
import 'package:barber_pro/core/auth/auth_debug_feedback.dart';
import 'package:barber_pro/core/auth/user_role_service.dart';
import 'package:barber_pro/core/auth/pending_onboarding_service.dart';
import 'package:barber_pro/core/motion.dart';
import 'package:barber_pro/core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'verify_email_screen.dart';

class InviteCodeScreen extends StatefulWidget {
  const InviteCodeScreen({super.key});

  @override
  State<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends State<InviteCodeScreen> {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _shopLocationController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  TextEditingController? _readOnlyEmailController;

  bool _loading = false;
  bool _codeVerified = false;
  bool _existingAccount = false;
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _codeErrorText;

  _InvitePayload? _invite;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _shopNameController.dispose();
    _shopLocationController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _readOnlyEmailController?.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    setState(() => _codeErrorText = null);
    final code = _extractInviteCode(_codeController.text);
    if (code.length < 6) {
      setState(
        () => _codeErrorText =
            'Invalid invitation code. Please try again or contact support.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final invite = await _findInviteByCode(code);
      _validateInvite(invite);

      final existingAccount = await _checkIfAuthAccountExists(invite.email);

      _invite = invite;
      _existingAccount = existingAccount;
      _codeVerified = true;
      _readOnlyEmailController?.dispose();
      _readOnlyEmailController = TextEditingController(text: invite.email);

      final currentUser = FirebaseAuth.instance.currentUser;
      final currentEmail = currentUser?.email?.trim().toLowerCase();
      if (invite.role != 'owner' &&
          currentUser != null &&
          currentEmail != null &&
          currentEmail == invite.email) {
        final verified = await _isEmailVerified(currentUser);
        if (!verified) {
          await PendingOnboardingService.savePendingInvite(
            user: currentUser,
            inviteCollection: invite.collection,
            inviteId: invite.reference.id,
            code: invite.code,
            role: invite.role,
            branchId: invite.branchId,
            shopId: invite.shopId,
            ownerId: invite.ownerId,
            shopName: invite.shopName,
            shopLocation: invite.shopLocation,
          );
          await _routeAfterAuth(currentUser);
          return;
        }
        await _applyInviteToUser(
          user: currentUser,
          invite: invite,
          isNewAccount: false,
        );
        await _routeAfterAuth(currentUser);
        return;
      }

      if (invite.role == 'owner') {
        if (_shopNameController.text.trim().isEmpty) {
          _shopNameController.text = invite.shopName ?? '';
        }
        if (_shopLocationController.text.trim().isEmpty) {
          _shopLocationController.text = invite.shopLocation ?? '';
        }
      }
      if (!_existingAccount) {
        _shopNameController.text = invite.shopName ?? '';
        _shopLocationController.text = invite.shopLocation ?? '';
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _codeErrorText = e.toString().replaceFirst('Exception: ', '').isEmpty
            ? 'Invalid invitation code. Please try again or contact support.'
            : e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _checkIfAuthAccountExists(String email) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentEmail = currentUser?.email?.trim().toLowerCase();
    if (currentEmail != null && currentEmail == email) {
      return true;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      return userDoc.docs.isNotEmpty;
    } on FirebaseException catch (_) {
      return false;
    }
  }

  String _extractInviteCode(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return '';

    if (!input.contains('://') && !input.contains('?')) {
      return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    }

    Uri? uri;
    try {
      uri = Uri.parse(input);
    } catch (_) {
      uri = null;
    }
    if (uri == null) return input.toUpperCase();

    final codeFromQuery =
        (uri.queryParameters['code'] ?? uri.queryParameters['inviteCode'] ?? '')
            .trim();
    if (codeFromQuery.isNotEmpty) return codeFromQuery.toUpperCase();

    final segments = uri.pathSegments;
    if (segments.isNotEmpty) {
      final maybeCode = segments.last.trim();
      if (maybeCode.isNotEmpty && maybeCode.length >= 6) {
        return maybeCode.toUpperCase();
      }
    }
    return input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  void _onCodeChanged(String raw) {
    // Keep deep links untouched; format only plain invite codes.
    if (raw.contains('://') || raw.contains('?')) return;
    if (_codeErrorText != null) {
      setState(() => _codeErrorText = null);
    }
    final cleaned = raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    var formatted = cleaned;
    if (cleaned.length > 4) {
      formatted = '${cleaned.substring(0, 4)} - ${cleaned.substring(4)}';
    }
    if (formatted.length > 11) {
      formatted = formatted.substring(0, 11);
    }
    if (formatted != raw) {
      _codeController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
  }

  Future<void> _joinWithExistingAccount() async {
    final invite = _invite;
    if (invite == null) return;
    if (invite.role == 'owner') {
      if (_shopNameController.text.trim().isEmpty) {
        _showMessage('Enter branch name');
        return;
      }
      if (_shopLocationController.text.trim().isEmpty) {
        _showMessage('Enter branch location');
        return;
      }
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      _showMessage('Enter your account password');
      return;
    }

    setState(() => _loading = true);
    try {
      _validateInvite(invite);
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: invite.email,
        password: password,
      );
      final user = credential.user;
      if (user == null) throw Exception('Could not sign in');
      final verified = await _isEmailVerified(user);
      if (!verified) {
        await PendingOnboardingService.savePendingInvite(
          user: user,
          inviteCollection: invite.collection,
          inviteId: invite.reference.id,
          code: invite.code,
          role: invite.role,
          branchId: invite.branchId,
          shopId: invite.shopId,
          ownerId: invite.ownerId,
          shopName: _shopNameController.text.trim().isNotEmpty
              ? _shopNameController.text.trim()
              : invite.shopName,
          shopLocation: _shopLocationController.text.trim().isNotEmpty
              ? _shopLocationController.text.trim()
              : invite.shopLocation,
        );
        await _routeAfterAuth(user);
        return;
      }
      await _applyInviteToUser(user: user, invite: invite, isNewAccount: false);
      await _routeAfterAuth(user);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        if (mounted) {
          setState(() {
            _existingAccount = false;
          });
        }
        _showMessage('No account found for this email. Create account below.');
        return;
      }
      _showMessage('[${e.code}] ${e.message ?? 'Sign in failed'}');
      if (mounted) {
        showDevAuthError(context, e, scope: 'invite_signin_join');
      }
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAndJoin() async {
    final invite = _invite;
    if (invite == null) return;

    final fullName = _fullNameController.text.trim();
    final password = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (fullName.length < 2) {
      _showMessage('Enter full name');
      return;
    }
    if (password.length < 8) {
      _showMessage('Password must be at least 8 characters');
      return;
    }
    if (password != confirm) {
      _showMessage('Passwords do not match');
      return;
    }
    if (invite.role == 'owner' &&
        _shopNameController.text.trim().isEmpty &&
        (invite.shopName == null || invite.shopName!.trim().isEmpty)) {
      _showMessage('Enter shop name');
      return;
    }

    setState(() => _loading = true);
    try {
      _validateInvite(invite);
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: invite.email,
            password: password,
          );
      final user = credential.user;
      if (user == null) throw Exception('Could not create account');
      await user.updateDisplayName(fullName);
      await user.sendEmailVerification();
      // Do not create app role/profile links before email verification.
      await PendingOnboardingService.savePendingInvite(
        user: user,
        inviteCollection: invite.collection,
        inviteId: invite.reference.id,
        code: invite.code,
        role: invite.role,
        branchId: invite.branchId,
        shopId: invite.shopId,
        ownerId: invite.ownerId,
        shopName: _shopNameController.text.trim().isNotEmpty
            ? _shopNameController.text.trim()
            : invite.shopName,
        shopLocation: _shopLocationController.text.trim().isNotEmpty
            ? _shopLocationController.text.trim()
            : invite.shopLocation,
      );
      _showMessage(
        'Verify your email first, then log in and enter invite code again to complete joining.',
      );
      await _routeAfterAuth(user);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        if (mounted) {
          setState(() {
            _existingAccount = true;
          });
        }
        _showMessage(
          'This email already has an account. Enter your existing password to continue.',
        );
        return;
      }
      _showMessage('[${e.code}] ${e.message ?? 'Sign up failed'}');
      if (mounted) {
        showDevAuthError(context, e, scope: 'invite_create_join');
      }
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _routeAfterAuth(User user) async {
    final verified = await _isEmailVerified(user);
    final refreshed = FirebaseAuth.instance.currentUser ?? user;
    if (!mounted) return;
    if (!verified) {
      Navigator.of(context).pushAndRemoveUntil(
        Motion.pageRoute(
          builder: (_) => VerifyEmailScreen(email: refreshed.email ?? ''),
        ),
        (_) => false,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      Motion.pageRoute(builder: (_) => const AppShell()),
      (_) => false,
    );
  }

  Future<bool> _isEmailVerified(User user) async {
    try {
      await user.reload();
    } catch (_) {}
    final refreshed = FirebaseAuth.instance.currentUser ?? user;
    return refreshed.emailVerified;
  }

  Future<void> _applyInviteToUser({
    required User user,
    required _InvitePayload invite,
    required bool isNewAccount,
  }) async {
    final defaultRoles = invite.role == 'owner'
        ? const <String>{'customer', 'barber', 'owner'}
        : invite.role == 'barber'
        ? const <String>{'customer', 'barber'}
        : const <String>{'customer'};
    await UserRoleService.ensureIdentityDoc(user, defaultRoles: defaultRoles);
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() ?? const <String, dynamic>{};
    final existingRoles = UserRoleService.extractRoles(userData);

    final patch = <String, dynamic>{
      'email': invite.email,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (isNewAccount) {
      patch['fullName'] = _fullNameController.text.trim();
      patch['createdAt'] = FieldValue.serverTimestamp();
    }

    if (invite.role == 'barber') {
      if (invite.branchId == null || invite.branchId!.isEmpty) {
        throw Exception('Invite missing branch information');
      }
      if (existingRoles.contains('owner')) {
        final ownerShopId =
            (userData['shopId'] as String?)?.trim().isNotEmpty == true
            ? (userData['shopId'] as String).trim()
            : ((userData['branchId'] as String?)?.trim().isNotEmpty == true
                  ? (userData['branchId'] as String).trim()
                  : '');
        if (ownerShopId.isNotEmpty && ownerShopId != invite.branchId) {
          throw Exception(
            'Owner/barber account cannot join another branch as barber.',
          );
        }
      }
      patch['branchId'] = invite.branchId;
      patch['shopId'] = invite.branchId;
      patch['ownerId'] = invite.ownerId ?? '';
      patch['isActive'] = true;
    } else if (invite.role == 'owner') {
      final shopId = (invite.shopId?.trim().isNotEmpty ?? false)
          ? invite.shopId!.trim()
          : user.uid;
      if (!isNewAccount) {
        await _cleanPreviousBarberEmploymentForOwnerTransition(
          user.uid,
          shopId,
        );
      }
      final shopName = _shopNameController.text.trim().isNotEmpty
          ? _shopNameController.text.trim()
          : (invite.shopName ?? 'My Branch');
      final shopLocation = _shopLocationController.text.trim().isNotEmpty
          ? _shopLocationController.text.trim()
          : (invite.shopLocation ?? '');
      patch['shopId'] = shopId;
      patch['branchId'] = shopId;
      patch['shopName'] = shopName;
      patch['shopLocation'] = shopLocation;

      await FirebaseFirestore.instance.collection('shops').doc(shopId).set({
        'ownerId': user.uid,
        'name': shopName,
        'location': shopLocation,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Owner accounts carry barber mode too in this identity model.
      await _safeWriteBarberShopLink(
        user: user,
        invite: _InvitePayload(
          collection: invite.collection,
          reference: invite.reference,
          code: invite.code,
          email: invite.email,
          role: 'barber',
          status: invite.status,
          used: invite.used,
          expiresAt: invite.expiresAt,
          branchId: shopId,
          shopId: shopId,
          ownerId: user.uid,
          shopName: shopName,
          shopLocation: shopLocation,
        ),
      );
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .set(patch, SetOptions(merge: true));

    await UserRoleService.setActiveRole(user.uid, invite.role);

    // For barber invites, membership doc must exist in shop/barbers so
    // owner/staff lists and booking selectors can find this barber.
    if (invite.role == 'barber') {
      await _ensureBarberMembership(user: user, invite: invite);
    }

    await _safeMarkInviteUsed(user: user, invite: invite);
  }

  Future<void> _cleanPreviousBarberEmploymentForOwnerTransition(
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
          ((userData['shopId'] as String?)?.trim().isNotEmpty ?? false)
          ? (userData['shopId'] as String).trim()
          : ((userData['branchId'] as String?)?.trim().isNotEmpty ?? false)
          ? (userData['branchId'] as String).trim()
          : '';

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
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
    }
  }

  Future<void> _deleteByBarberAndShop(
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
    } on FirebaseException catch (_) {
      // Optional cleanup collections may not exist in all setups.
    }
  }

  Future<void> _safeWriteBarberShopLink({
    required User user,
    required _InvitePayload invite,
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(invite.branchId!)
          .collection('barbers')
          .doc(user.uid)
          .set({
            'barberId': user.uid,
            'barberUserId': user.uid,
            'shopId': invite.branchId,
            'ownerId': invite.ownerId ?? '',
            'name': (user.displayName ?? '').trim(),
            'email': invite.email,
            'status': 'active',
            'isActive': true,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      rethrow;
    }
  }

  Future<void> _ensureBarberMembership({
    required User user,
    required _InvitePayload invite,
  }) async {
    try {
      await _safeWriteBarberShopLink(user: user, invite: invite);
      return;
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
    }

    // Retry once after a short delay in case security rules read stale role data.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _safeWriteBarberShopLink(user: user, invite: invite);
  }

  Future<void> _safeMarkInviteUsed({
    required User user,
    required _InvitePayload invite,
  }) async {
    try {
      await invite.reference.update({
        'status': invite.collection == 'invites' ? 'accepted' : 'used',
        'used': true,
        'claimedBy': user.uid,
        'claimedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      // Do not block onboarding if invite doc update is denied.
    }
  }

  Future<_InvitePayload> _findInviteByCode(String code) async {
    final fromInvites = await _tryFindInviteInCollection(
      collection: 'invites',
      code: code,
    );
    if (fromInvites != null) return fromInvites;

    final fromBarberLegacy = await _tryFindInviteInCollection(
      collection: 'barber_invites',
      code: code,
    );
    if (fromBarberLegacy != null) return fromBarberLegacy;

    final fromOwnerLegacy = await _tryFindInviteInCollection(
      collection: 'owner_invites',
      code: code,
    );
    if (fromOwnerLegacy != null) return fromOwnerLegacy;

    throw Exception('Invalid invite code');
  }

  Future<_InvitePayload?> _tryFindInviteInCollection({
    required String collection,
    required String code,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(collection)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return _InvitePayload.fromDoc(snap.docs.first, collection: collection);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  void _validateInvite(_InvitePayload invite) {
    final validRoles = <String>{'barber', 'owner'};
    if (!validRoles.contains(invite.role)) {
      throw Exception('Unsupported invite role');
    }
    final pendingStatus = invite.collection == 'invites'
        ? 'pending'
        : 'invited';
    if (invite.status != pendingStatus || invite.used) {
      throw Exception('Invite already used or invalid');
    }
    if (invite.expiresAt != null &&
        invite.expiresAt!.toDate().isBefore(DateTime.now())) {
      throw Exception('Invite code expired');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    final showInputCard = !_codeVerified || invite == null;
    final themed = Theme.of(context).copyWith(
      scaffoldBackgroundColor: AppColors.midnight,
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: AppColors.gold.withValues(alpha: 0.9)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.42)),
        filled: true,
        fillColor: const Color(0xFF141A2A),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: const Color(0xFF05070A),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
    return Theme(
      data: themed,
      child: Scaffold(
        backgroundColor: AppColors.midnight,
        body: showInputCard
            ? Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.15,
                  colors: [Color(0xCC0B0F1A), Color(0xF205070A)],
                ),
              ),
              child: SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final media = MediaQuery.of(context);
                    final keyboardInset = media.viewInsets.bottom;
                    final compact = keyboardInset > 0;
                    return AnimatedPadding(
                      duration: Motion.microAnimationDuration,
                      curve: Motion.microAnimationCurve,
                      padding: EdgeInsets.fromLTRB(
                        14,
                        18,
                        14,
                        keyboardInset > 0 ? keyboardInset + 12 : 20,
                      ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight - (compact ? 8 : 0),
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: Container(
                                width: double.infinity,
                                padding: EdgeInsets.fromLTRB(
                                  24,
                                  compact ? 24 : 34,
                                  24,
                                  compact ? 20 : 28,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0x990B0F1A),
                                  borderRadius: BorderRadius.circular(46),
                                  border: Border.all(
                                    color: AppColors.gold.withValues(alpha: 0.35),
                                    width: 0.6,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.45),
                                      blurRadius: 42,
                                      offset: const Offset(0, 20),
                                    ),
                                  ],
                                ),
                                child: MediaQuery(
                                  data: media.copyWith(
                                    textScaler: const TextScaler.linear(1.0),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.key_rounded,
                                        size: compact ? 30 : 34,
                                        color: AppColors.gold,
                                      ),
                                      SizedBox(height: compact ? 10 : 16),
                                      const Text(
                                        'Enter Invite Code',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'PlayfairDisplay',
                                          fontSize: 30,
                                          height: 1.0,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      SizedBox(height: compact ? 10 : 14),
                                      Text(
                                        'Verify your professional status with\nthe code provided by your shop\nowner.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.52,
                                          ),
                                          fontSize: compact ? 13 : 14,
                                          height: 1.5,
                                        ),
                                      ),
                                      SizedBox(height: compact ? 14 : 24),
                                      AnimatedContainer(
                                        duration: Motion.microAnimationDuration,
                                        curve: Motion.microAnimationCurve,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: _codeErrorText == null
                                                ? Colors.white.withValues(alpha: 0.18)
                                                : const Color(0xFFDC2626),
                                          ),
                                          gradient: const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Color(0xFF0D1320),
                                              Color(0xFF0A0F19),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _codeErrorText == null
                                                  ? AppColors.gold.withValues(alpha: 0.06)
                                                  : const Color(0x33DC2626),
                                              blurRadius: 16,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: TextField(
                                          controller: _codeController,
                                          onChanged: _onCodeChanged,
                                          textCapitalization:
                                              TextCapitalization.characters,
                                          enabled: !_loading,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: AppColors.text,
                                            fontSize: 24,
                                            letterSpacing: 2.6,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'XXXX - XXXX',
                                            hintStyle: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.28),
                                              letterSpacing: 2.4,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            isDense: true,
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: compact ? 14 : 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_codeErrorText != null) ...[
                                        SizedBox(height: compact ? 8 : 10),
                                        Text(
                                          _codeErrorText!,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            color: Color(0xFFEF4444),
                                            fontSize: 11,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                      SizedBox(height: compact ? 12 : 18),
                                      SizedBox(
                                        width: double.infinity,
                                        height: compact ? 48 : 54,
                                        child: ElevatedButton(
                                          onPressed: _loading
                                              ? null
                                              : _verifyCode,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.gold,
                                            foregroundColor: const Color(0xFF05070A),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            elevation: 0,
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 2.2,
                                              fontSize: 14,
                                            ),
                                          ),
                                          child: Text(
                                            _loading ? 'CHECKING...' : 'VERIFY & PROCEED',
                                          ),
                                        ),
                                      ),
                                      if (!compact) ...[
                                        const SizedBox(height: 10),
                                        TextButton(
                                          onPressed: _loading
                                              ? null
                                              : () => Navigator.of(
                                                  context,
                                                ).maybePop(),
                                          style: TextButton.styleFrom(
                                            foregroundColor: Colors.white
                                                .withValues(alpha: 0.45),
                                          ),
                                          child: const Text(
                                            'Cancel',
                                            style: TextStyle(fontSize: 15),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              )
            : (invite.role == 'barber' && !_existingAccount)
            ? _buildLuxuryBarberRegistration(invite)
            : (invite.role == 'owner' && !_existingAccount)
            ? _buildLuxuryOwnerRegistration(invite)
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...[
                        const SizedBox(height: 20),
                        Text(
                          'Invite detected: ${invite.role.toUpperCase()}',
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Email: ${invite.email}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_existingAccount) ...[
                          const Text(
                            'Account exists. Sign in to link this role.',
                            style: TextStyle(color: AppColors.text),
                          ),
                          const SizedBox(height: 10),
                          if (invite.role == 'owner') ...[
                            TextField(
                              controller: _shopNameController,
                              decoration: const InputDecoration(
                                labelText: 'Branch Name',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _shopLocationController,
                              decoration: const InputDecoration(
                                labelText: 'Branch Location',
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Account Password',
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _loading
                                  ? null
                                  : _joinWithExistingAccount,
                              child: Text(
                                _loading ? 'Processing...' : 'SIGN IN & JOIN',
                              ),
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'No account found. Create your account.',
                            style: TextStyle(color: AppColors.text),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _fullNameController,
                            decoration: const InputDecoration(
                              labelText: 'Full Name',
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _codeVerified
                                ? (_readOnlyEmailController ??=
                                      TextEditingController(text: invite.email))
                                : null,
                            readOnly: true,
                            enableInteractiveSelection: false,
                            decoration: const InputDecoration(labelText: 'Email'),
                          ),
                          if (invite.role == 'owner') ...[
                            const SizedBox(height: 10),
                            TextField(
                              controller: _shopNameController,
                              decoration: const InputDecoration(
                                labelText: 'Shop Name',
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _shopLocationController,
                              decoration: const InputDecoration(
                                labelText: 'Shop Location',
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          TextField(
                            controller: _newPasswordController,
                            obscureText: _obscureNewPassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () =>
                                      _obscureNewPassword = !_obscureNewPassword,
                                ),
                                icon: Icon(
                                  _obscureNewPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _createAndJoin,
                              child: Text(
                                _loading
                                    ? 'Processing...'
                                    : 'CREATE ACCOUNT & JOIN',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildLuxuryBarberRegistration(_InvitePayload invite) {
    final password = _newPasswordController.text;
    final hasMinLength = password.length >= 8;
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final isStrong = hasMinLength && hasUppercase && hasNumber;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                'THE SANCTUARY GUILD',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.gold.withValues(alpha: 0.9),
                  fontSize: 10,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'Join as Barber',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 50,
                  height: 0.98,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Complete your account to join this branch and begin your journey with us.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.58),
                  height: 1.45,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF070A12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.8),
                  width: 0.7,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4),
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'INVITATION CONFIRMED',
                          style: TextStyle(
                            color: AppColors.gold.withValues(alpha: 0.95),
                            fontSize: 9,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.verified_user_rounded,
                        color: AppColors.gold.withValues(alpha: 0.65),
                        size: 18,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _inviteRow(
                    icon: Icons.content_cut_rounded,
                    label: 'INVITE TYPE',
                    value: 'Professional Barber',
                  ),
                  const SizedBox(height: 10),
                  _inviteRow(
                    icon: Icons.location_on_rounded,
                    label: 'BRANCH',
                    value:
                        ((invite.shopName ?? '').trim().isEmpty
                            ? 'Branch'
                            : invite.shopName!)
                        .trim(),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EMAIL ADDRESS',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  fontSize: 9,
                                  letterSpacing: 1.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                invite.email,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 15,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.lock_rounded,
                          color: Colors.white.withValues(alpha: 0.35),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _luxuryLabel('FULL NAME'),
            const SizedBox(height: 8),
            TextField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                hintText: 'e.g. Alexander Sterling',
              ),
            ),
            const SizedBox(height: 14),
            _luxuryLabel('PASSWORD'),
            const SizedBox(height: 8),
            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNewPassword,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Enter password',
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => _obscureNewPassword = !_obscureNewPassword,
                  ),
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                ),
              ),
            ),
            if (password.isNotEmpty && !isStrong) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Text(
                    'Password is too weak',
                    style: TextStyle(
                      color: AppColors.gold.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            _luxuryLabel('CONFIRM PASSWORD'),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              decoration: InputDecoration(
                hintText: 'Re-enter password',
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x1A141A2A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  _ruleRow('Minimum 8 characters', hasMinLength),
                  const SizedBox(height: 8),
                  _ruleRow('At least 1 uppercase letter', hasUppercase),
                  const SizedBox(height: 8),
                  _ruleRow('At least 1 number', hasNumber),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _loading ? null : _createAndJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF070A12),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                child: Text(_loading ? 'PROCESSING...' : 'CREATE ACCOUNT & JOIN'),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                        _existingAccount = true;
                      }),
                child: const Text(
                  'ALREADY HAVE AN ACCOUNT? SIGN IN & JOIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _loading ? null : () => Navigator.of(context).maybePop(),
                child: Text(
                  'CANCEL REGISTRATION',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLuxuryOwnerRegistration(_InvitePayload invite) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Set Up Your Branch',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 24,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Complete your owner account setup',
              style: TextStyle(
                color: AppColors.gold.withValues(alpha: 0.92),
                fontSize: 14,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/images/login_screen.png', fit: BoxFit.cover),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.15),
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 10,
                      bottom: 8,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'NEW INVITATION',
                              style: TextStyle(
                                color: Color(0xFF070A12),
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Join the Elite Network',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'PlayfairDisplay',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _luxuryLabel('INVITATION DETAILS'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF070A12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.35),
                  width: 0.7,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        size: 16,
                        color: AppColors.gold.withValues(alpha: 0.9),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Invited by Super Admin',
                        style: TextStyle(
                          color: AppColors.gold.withValues(alpha: 0.9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    invite.email,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'PlayfairDisplay',
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Role: Owner',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_rounded,
                          size: 15,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Locked',
                          style: TextStyle(
                            color: AppColors.gold.withValues(alpha: 0.95),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _ownerSectionCard(
              icon: Icons.storefront_rounded,
              title: 'Branch Information',
              child: Column(
                children: [
                  _ownerFieldLabel('BRANCH NAME *'),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _shopNameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Sterling Heights Manor',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ownerFieldLabel('LOCATION *'),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _shopLocationController,
                    decoration: const InputDecoration(
                      hintText: 'City, Country',
                      prefixIcon: Icon(
                        Icons.location_on_rounded,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _ownerSectionCard(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Owner Account',
              child: Column(
                children: [
                  _ownerFieldLabel('FULL NAME'),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _fullNameController,
                    decoration: const InputDecoration(
                      hintText: 'Alexander Sterling',
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ownerFieldLabel('PASSWORD'),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: _obscureNewPassword,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscureNewPassword = !_obscureNewPassword,
                        ),
                        icon: Icon(
                          _obscureNewPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ownerFieldLabel('CONFIRM PASSWORD'),
                  const SizedBox(height: 7),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscureConfirmPassword = !_obscureConfirmPassword,
                        ),
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              decoration: BoxDecoration(
                color: const Color(0xFF070A12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _createAndJoin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: const Color(0xFF070A12),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'PlayfairDisplay',
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _loading
                                ? 'Creating...'
                                : 'Create Owner Account',
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : () => Navigator.of(context).maybePop(),
                    child: Text(
                      'Cancel Setup',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Have account?',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                _existingAccount = true;
                              }),
                        child: const Text(
                          'Sign in instead',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'STERLING MANAGEMENT SYSTEM © 2024 • LUXURY STANDARD',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.24),
                  fontSize: 8,
                  letterSpacing: 1.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ownerSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: const Color(0xFF070A12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.gold, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: AppColors.gold.withValues(alpha: 0.2), height: 1),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _ownerFieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.52),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _luxuryLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        color: AppColors.gold.withValues(alpha: 0.86),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.7,
      ),
    );
  }

  Widget _inviteRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF121620),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Icon(icon, size: 18, color: AppColors.gold),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _ruleRow(String text, bool done) {
    return Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 16,
          color: done
              ? AppColors.gold
              : Colors.white.withValues(alpha: 0.35),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: done
                ? Colors.white.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.45),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _InvitePayload {
  _InvitePayload({
    required this.collection,
    required this.reference,
    required this.code,
    required this.email,
    required this.role,
    required this.status,
    required this.used,
    this.expiresAt,
    this.branchId,
    this.shopId,
    this.ownerId,
    this.shopName,
    this.shopLocation,
  });

  final String collection;
  final DocumentReference<Map<String, dynamic>> reference;
  final String code;
  final String email;
  final String role;
  final String status;
  final bool used;
  final Timestamp? expiresAt;
  final String? branchId;
  final String? shopId;
  final String? ownerId;
  final String? shopName;
  final String? shopLocation;

  factory _InvitePayload.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String collection,
  }) {
    final data = doc.data();
    final roleRaw = (data['role'] as String?)?.trim().toLowerCase();
    final inferredRole =
        roleRaw ?? (collection == 'owner_invites' ? 'owner' : 'barber');
    return _InvitePayload(
      collection: collection,
      reference: doc.reference,
      code: ((data['code'] as String?) ?? '').trim().toUpperCase(),
      email: ((data['email'] as String?) ?? '').trim().toLowerCase(),
      role: inferredRole,
      status: ((data['status'] as String?) ?? '').trim().toLowerCase(),
      used: data['used'] == true,
      expiresAt: data['expiresAt'] as Timestamp?,
      branchId: (data['branchId'] as String?)?.trim().isNotEmpty == true
          ? (data['branchId'] as String).trim()
          : (data['shopId'] as String?)?.trim(),
      shopId: (data['shopId'] as String?)?.trim(),
      ownerId: (data['ownerId'] as String?)?.trim(),
      shopName: (data['shopName'] as String?)?.trim(),
      shopLocation: (data['shopLocation'] as String?)?.trim(),
    );
  }
}
