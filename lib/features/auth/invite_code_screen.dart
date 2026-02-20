import 'package:barber_pro/app_shell.dart';
import 'package:barber_pro/core/auth/auth_debug_feedback.dart';
import 'package:barber_pro/core/auth/user_role_service.dart';
import 'package:barber_pro/core/auth/pending_onboarding_service.dart';
import 'package:barber_pro/core/motion.dart';
import 'package:barber_pro/core/theme/app_colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'verify_email_screen.dart';

class InviteCodeScreen extends StatefulWidget {
  const InviteCodeScreen({super.key});

  @override
  State<InviteCodeScreen> createState() => _InviteCodeScreenState();
}

class _InviteCodeScreenState extends State<InviteCodeScreen> {
  final _ownerFormKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _shopLocationController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _smartEmailController = TextEditingController();
  TextEditingController? _readOnlyEmailController;

  bool _loading = false;
  bool _codeVerified = false;
  bool _existingAccount = false;
  bool _smartGateCompleted = false;
  bool _resolvingAccountPath = false;
  bool _inviteFieldFocused = false;
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _ownerSubmitted = false;
  String? _codeErrorText;
  String? _smartEmailErrorText;

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
    _smartEmailController.dispose();
    _readOnlyEmailController?.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    FocusScope.of(context).unfocus();
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
      final hydratedInvite = await _withResolvedBranchName(invite);
      _invite = hydratedInvite;
      _codeVerified = true;
      _smartGateCompleted = false;
      _smartEmailErrorText = null;
      _readOnlyEmailController?.dispose();
      _readOnlyEmailController = TextEditingController(
        text: hydratedInvite.email,
      );
      _smartEmailController.text = hydratedInvite.email;

      final currentUser = FirebaseAuth.instance.currentUser;
      final currentEmail = currentUser?.email?.trim().toLowerCase();
      if (hydratedInvite.role != 'owner' &&
          currentUser != null &&
          currentEmail != null &&
          currentEmail == hydratedInvite.email) {
        final verified = await _isEmailVerified(currentUser);
        if (!verified) {
          await PendingOnboardingService.savePendingInvite(
            user: currentUser,
            inviteCollection: hydratedInvite.collection,
            inviteId: hydratedInvite.reference.id,
            code: hydratedInvite.code,
            role: hydratedInvite.role,
            branchId: hydratedInvite.branchId,
            shopId: hydratedInvite.shopId,
            ownerId: hydratedInvite.ownerId,
            shopName: hydratedInvite.shopName,
            shopLocation: hydratedInvite.shopLocation,
          );
          await _routeAfterAuth(currentUser);
          return;
        }
        await _applyInviteToUser(
          user: currentUser,
          invite: hydratedInvite,
          isNewAccount: false,
        );
        await _routeAfterAuth(currentUser);
        return;
      }

      if (hydratedInvite.role == 'owner') {
        if (_shopNameController.text.trim().isEmpty) {
          _shopNameController.text = hydratedInvite.shopName ?? '';
        }
        if (_shopLocationController.text.trim().isEmpty) {
          _shopLocationController.text = hydratedInvite.shopLocation ?? '';
        }
      }
      final hintedExisting = hydratedInvite.accountExists ?? false;
      if (!hintedExisting) {
        _shopNameController.text = hydratedInvite.shopName ?? '';
        _shopLocationController.text = hydratedInvite.shopLocation ?? '';
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

  Future<_InvitePayload> _withResolvedBranchName(_InvitePayload invite) async {
    if (invite.role != 'barber') return invite;
    final existingName = (invite.shopName ?? '').trim();
    if (existingName.isNotEmpty) return invite;

    final targetShopId = (invite.branchId ?? '').trim().isNotEmpty
        ? invite.branchId!.trim()
        : (invite.shopId ?? '').trim();
    if (targetShopId.isEmpty) return invite;

    try {
      final shopDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(targetShopId)
          .get();
      final data = shopDoc.data() ?? const <String, dynamic>{};
      final resolvedName =
          ((data['name'] as String?) ??
                  (data['shopName'] as String?) ??
                  (data['branchName'] as String?) ??
                  '')
              .trim();
      if (resolvedName.isEmpty) return invite;
      return invite.copyWith(shopName: resolvedName);
    } catch (_) {
      return invite;
    }
  }

  String _displayBranchName(_InvitePayload invite) {
    final fromInvite = (invite.shopName ?? '').trim();
    if (fromInvite.isNotEmpty) return fromInvite;
    final fromShopId = (invite.shopId ?? '').trim();
    if (fromShopId.isNotEmpty) return fromShopId;
    final fromBranchId = (invite.branchId ?? '').trim();
    if (fromBranchId.isNotEmpty) return fromBranchId;
    return 'Assigned Branch';
  }

  Future<bool?> _checkIfAuthAccountExists(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final currentUser = FirebaseAuth.instance.currentUser;
    final currentEmail = currentUser?.email?.trim().toLowerCase();
    if (currentEmail != null && currentEmail == normalizedEmail) {
      return true;
    }
    final hasIdentityDoc = await _hasIdentityUserDocByEmail(normalizedEmail);
    if (hasIdentityDoc != null) return hasIdentityDoc;

    // Secondary probe against Firebase Auth so legacy accounts (Auth exists but
    // users doc missing) are still auto-detected as "existing account".
    final probe = await _probeAuthAccountExistsByEmail(normalizedEmail);
    if (probe != null) return probe;

    // Strong fallback probe: use a secondary Auth instance to try creating the
    // invited email, then immediately delete if created. This avoids touching
    // the main app auth state and gives a deterministic exists/new answer.
    final createProbe = await _probeAuthEmailExistsViaCreateDelete(
      normalizedEmail,
    );
    if (createProbe != null) return createProbe;

    return null;
  }

  Future<void> _resolveAccountPathForInvite({
    required _InvitePayload invite,
    bool preferInviteHint = true,
  }) async {
    if (!mounted) return;
    setState(() => _resolvingAccountPath = true);
    try {
      final exists = await _determineExistingAccountState(
        invite,
        preferInviteHint: preferInviteHint,
      );
      if (!mounted) return;
      setState(() {
        _existingAccount = exists;
      });
    } finally {
      if (mounted) {
        setState(() => _resolvingAccountPath = false);
      }
    }
  }

  Future<bool> _determineExistingAccountState(
    _InvitePayload invite, {
    bool preferInviteHint = true,
  }) async {
    final hint = invite.accountExists;
    if (preferInviteHint && hint != null) {
      return hint;
    }

    final fromLiveChecks = await _checkIfAuthAccountExists(invite.email);
    if (fromLiveChecks != null) return fromLiveChecks;

    if (hint != null) return hint;
    // If detection is unknown, prefer existing-account path.
    // Existing users can continue immediately; new users can switch via the
    // "Don't have an account? Sign up & Join" link.
    return true;
  }

  Future<void> _runSmartGateCheck(_InvitePayload invite) async {
    final typedEmail = _smartEmailController.text.trim().toLowerCase();
    final invitedEmail = invite.email.trim().toLowerCase();
    if (typedEmail.isEmpty) {
      if (!mounted) return;
      setState(() {
        _smartEmailErrorText = 'Enter your email';
      });
      return;
    }
    if (typedEmail != invitedEmail) {
      if (!mounted) return;
      setState(() {
        _smartEmailErrorText = 'Use the invited email for this code';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _smartEmailErrorText = null);
    await _resolveAccountPathForInvite(invite: invite, preferInviteHint: false);
    if (!mounted) return;
    setState(() => _smartGateCompleted = true);
  }

  Future<bool?> _hasIdentityUserDocByEmail(String email) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      return userDoc.docs.isNotEmpty;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      return false;
    }
  }

  Future<bool?> _probeAuthAccountExistsByEmail(String email) async {
    final auth = FirebaseAuth.instance;
    final previousUser = auth.currentUser;
    final probePassword =
        '__probe__${DateTime.now().microsecondsSinceEpoch}__X9!';

    try {
      final credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: probePassword,
      );

      // Extremely unlikely, but avoid leaking probe-auth session if it ever
      // succeeds for any reason.
      final signedInUid = credential.user?.uid;
      final previousUid = previousUser?.uid;
      if (signedInUid != null && signedInUid != previousUid) {
        await auth.signOut();
      }
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'user-disabled':
        case 'too-many-requests':
        case 'operation-not-allowed':
          return true;
        case 'user-not-found':
          return false;
        case 'invalid-credential':
          // With email-enumeration protection this is often returned for
          // both existing and new accounts.
          return null;
        case 'network-request-failed':
          return null;
        default:
          return null;
      }
    } catch (_) {
      return null;
    }
  }

  Future<bool?> _probeAuthEmailExistsViaCreateDelete(String email) async {
    if (email.isEmpty) return null;

    FirebaseApp? probeApp;
    try {
      final options = Firebase.app().options;
      final appName = 'invite_probe_${DateTime.now().microsecondsSinceEpoch}';
      probeApp = await Firebase.initializeApp(name: appName, options: options);
      final probeAuth = FirebaseAuth.instanceFor(app: probeApp);
      final probePassword =
          'P@ssw0rd_${DateTime.now().microsecondsSinceEpoch}Aa!';

      try {
        final credential = await probeAuth.createUserWithEmailAndPassword(
          email: email,
          password: probePassword,
        );
        final createdUser = credential.user;
        if (createdUser != null) {
          await createdUser.delete();
        }
        return false;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') return true;
        if (e.code == 'invalid-email') return null;
        if (e.code == 'network-request-failed') return null;
        if (e.code == 'too-many-requests') return null;
        if (e.code == 'operation-not-allowed') return null;
        return null;
      } finally {
        try {
          await probeAuth.signOut();
        } catch (_) {}
      }
    } catch (_) {
      return null;
    } finally {
      if (probeApp != null) {
        try {
          await probeApp.delete();
        } catch (_) {}
      }
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
      if (e.code == 'invalid-credential') {
        final hasIdentity = await _hasIdentityUserDocByEmail(invite.email);
        if (hasIdentity == false) {
          if (mounted) {
            setState(() {
              _existingAccount = false;
            });
          }
          _showMessage(
            'No account found for this email. Create account below.',
          );
          return;
        }
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

    if (invite.role == 'owner' && !_existingAccount) {
      setState(() => _ownerSubmitted = true);
      if (!_ownerFormKey.currentState!.validate()) return;
    }

    final fullName = _fullNameController.text.trim();
    final password = _newPasswordController.text;
    final confirm = _confirmPasswordController.text;
    if (fullName.length < 2) {
      _showMessage('Enter full name');
      return;
    }
    if (password.length < 8) {
      _showMessage('Use at least 8 characters');
      return;
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
      _showMessage('Include at least one letter');
      return;
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      _showMessage('Include at least one number');
      return;
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      _showMessage('Include at least one symbol');
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
      final isLockedInviteRole =
          _invite?.role == 'barber' || _invite?.role == 'owner';
      Navigator.of(context).pushAndRemoveUntil(
        Motion.pageRoute(
          builder: (_) => VerifyEmailScreen(
            email: refreshed.email ?? '',
            allowChangeEmail: !isLockedInviteRole,
          ),
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
      // Owner transition always creates/uses own shop root by uid (fresh start).
      // This avoids permission-denied on foreign/pre-provisioned shop IDs.
      final shopId = user.uid;
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
        hintStyle: TextStyle(color: AppColors.onDark42),
        filled: true,
        fillColor: const Color(0xFF141A2A),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.onDark10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.onDark10),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.shellBackground,
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
                              minHeight:
                                  constraints.maxHeight - (compact ? 8 : 0),
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 360,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: EdgeInsets.fromLTRB(
                                    22,
                                    compact ? 22 : 30,
                                    22,
                                    compact ? 18 : 24,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xE60B0F1A),
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.45,
                                      ),
                                      width: 0.9,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.45,
                                        ),
                                        blurRadius: 28,
                                        offset: const Offset(0, 14),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.key_rounded,
                                        size: 32,
                                        color: AppColors.gold,
                                      ),
                                      const SizedBox(height: 14),
                                      const Text(
                                        'Enter Invite Code',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontFamily: 'PlayfairDisplay',
                                          fontSize: 32,
                                          height: 1.0,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.text,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        'Verify your professional status with\nthe code provided by your shop\nowner.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.52,
                                          ),
                                          fontSize: 13,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 58,
                                        child: AnimatedContainer(
                                          duration:
                                              Motion.microAnimationDuration,
                                          curve: Motion.microAnimationCurve,
                                          clipBehavior: Clip.antiAlias,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: _codeErrorText == null
                                                  ? (_inviteFieldFocused
                                                        ? AppColors.gold
                                                        : Colors.white
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ))
                                                  : const Color(0xFFDC2626),
                                              width: _inviteFieldFocused
                                                  ? 1.15
                                                  : 1,
                                            ),
                                            color: AppColors.surfaceSoft,
                                            boxShadow: [
                                              BoxShadow(
                                                color: _codeErrorText == null
                                                    ? AppColors.gold.withValues(
                                                        alpha:
                                                            _inviteFieldFocused
                                                            ? 0.18
                                                            : 0.08,
                                                      )
                                                    : const Color(0x33DC2626),
                                                blurRadius: _inviteFieldFocused
                                                    ? 18
                                                    : 14,
                                                offset: const Offset(0, 6),
                                              ),
                                            ],
                                          ),
                                          child: Focus(
                                            onFocusChange: (focused) {
                                              if (!mounted) return;
                                              setState(() {
                                                _inviteFieldFocused = focused;
                                              });
                                            },
                                            child: TextField(
                                              controller: _codeController,
                                              onChanged: _onCodeChanged,
                                              textCapitalization:
                                                  TextCapitalization.characters,
                                              readOnly: _loading,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: AppColors.text,
                                                fontSize: 22,
                                                letterSpacing: 2.6,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: 'AB12 - CD34',
                                                hintStyle: TextStyle(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.28),
                                                  fontSize: 20,
                                                  letterSpacing: 2.2,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                isDense: true,
                                                border: InputBorder.none,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 16,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_codeErrorText != null) ...[
                                        const SizedBox(height: 10),
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
                                      const SizedBox(height: 18),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 56,
                                        child: ElevatedButton(
                                          onPressed: _loading
                                              ? null
                                              : _verifyCode,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppColors.gold,
                                            foregroundColor: const Color(
                                              0xFF05070A,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                            elevation: 8,
                                            shadowColor: AppColors.gold
                                                .withValues(alpha: 0.28),
                                            textStyle: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 2.3,
                                              fontSize: 13,
                                            ),
                                          ),
                                          child: Text(
                                            _loading
                                                ? 'CHECKING...'
                                                : 'VERIFY & PROCEED',
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
                      );
                    },
                  ),
                ),
              )
            : !_smartGateCompleted
            ? _buildSmartGate(invite)
            : (invite.role == 'barber' && !_existingAccount)
            ? _buildLuxuryBarberRegistration(invite)
            : (invite.role == 'barber' && _existingAccount)
            ? _buildLuxuryBarberExistingAccount(invite)
            : (invite.role == 'owner' && !_existingAccount)
            ? _buildLuxuryOwnerRegistration(invite)
            : (invite.role == 'owner' && _existingAccount)
            ? _buildLuxuryOwnerExistingAccount(invite)
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
                            decoration: const InputDecoration(
                              labelText: 'Email',
                            ),
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
                                  () => _obscureNewPassword =
                                      !_obscureNewPassword,
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

  Widget _buildSmartGate(_InvitePayload invite) {
    final roleLabel = invite.role == 'owner'
        ? 'OWNER SETUP'
        : invite.role == 'barber'
        ? 'BARBER INVITE'
        : invite.role.toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Icon(
                        Icons.email_rounded,
                        size: 34,
                        color: AppColors.gold.withValues(alpha: 0.95),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'Step 2: Smart Gate',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 31,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        'Enter your invited email, then we will auto-select\nthe correct screen (Sign in or Sign up).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.onDark58,
                          fontSize: 13,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1422),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.onDark08),
                      ),
                      child: Row(
                        children: [
                          Text(
                            roleLabel,
                            style: TextStyle(
                              color: AppColors.gold.withValues(alpha: 0.9),
                              fontSize: 10,
                              letterSpacing: 2.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Code: ${invite.code}',
                            style: TextStyle(
                              color: AppColors.onDark52,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Email Address',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _smartEmailController,
                      enabled: !_resolvingAccountPath,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _runSmartGateCheck(invite),
                      onChanged: (_) {
                        if (_smartEmailErrorText != null) {
                          setState(() => _smartEmailErrorText = null);
                        }
                      },
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: 'your@email.com',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.28),
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceSoft,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _smartEmailErrorText == null
                                ? AppColors.onDark08
                                : const Color(0xFFEF4444),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                            color: _smartEmailErrorText == null
                                ? AppColors.gold
                                : const Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ),
                    if (_smartEmailErrorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _smartEmailErrorText!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text(
                        'Must match invited email: ${invite.email}',
                        style: TextStyle(
                          color: AppColors.onDark45,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: _resolvingAccountPath
                            ? null
                            : () => _runSmartGateCheck(invite),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.shellBackground,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.2,
                          ),
                        ),
                        child: _resolvingAccountPath
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.shellBackground,
                                  ),
                                ),
                              )
                            : const Text('NEXT'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryOwnerExistingAccount(_InvitePayload invite) {
    final shopName = (invite.shopName ?? '').trim().isEmpty
        ? 'e.g. Sovereign Heights'
        : invite.shopName!.trim();

    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Complete Owner Setup',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 31,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                    height: 1.08,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Finalize your administrative credentials to begin\nmanaging your barbershop.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.onDark58,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.55),
                    width: 1.1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(
                          'INVITE TYPE',
                          style: TextStyle(
                            color: AppColors.gold.withValues(alpha: 0.9),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2.8,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.13),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Text(
                            'OWNER',
                            style: TextStyle(
                              color: AppColors.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(
                      color: Colors.white.withValues(alpha: 0.07),
                      height: 1,
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Assigned Email',
                        style: TextStyle(
                          color: AppColors.onDark52,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.gold.withValues(alpha: 0.95),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            invite.email,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text(
                'BRANCH NAME',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _shopNameController,
                style: const TextStyle(color: AppColors.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: shopName,
                  filled: true,
                  fillColor: AppColors.surfaceSoft,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.onDark08),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'BRANCH LOCATION',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _shopLocationController,
                style: const TextStyle(color: AppColors.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'e.g. 123 Main St, Cityville',
                  filled: true,
                  fillColor: AppColors.surfaceSoft,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  suffixIcon: Icon(
                    Icons.location_on_outlined,
                    color: AppColors.gold.withValues(alpha: 0.8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.onDark08),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'ACCOUNT PASSWORD',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2.4,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: AppColors.text, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'password',
                  filled: true,
                  fillColor: AppColors.surfaceSoft,
                  hintStyle: TextStyle(
                    color: Colors.white.withValues(alpha: 0.28),
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.onDark08),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.gold),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: _loading ? null : _joinWithExistingAccount,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.shellBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.3,
                    ),
                    shadowColor: AppColors.gold.withValues(alpha: 0.3),
                    elevation: 10,
                  ),
                  child: Text(
                    _loading ? 'VERIFYING...' : 'VERIFY & BECOME OWNER',
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() => _existingAccount = false),
                  child: Text(
                    "Don't have an account? Sign up & Join",
                    style: TextStyle(
                      color: AppColors.gold.withValues(alpha: 0.95),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Center(
                child: TextButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).maybePop(),
                  child: Text(
                    'Cancel Setup',
                    style: TextStyle(
                      color: AppColors.onDark50,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryBarberRegistration(_InvitePayload invite) {
    final password = _newPasswordController.text;
    final hasMinLength = password.length >= 8;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(password);
    final isStrong = hasMinLength && hasLetter && hasNumber && hasSymbol;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Join as Barber',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 31,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Create your professional profile to begin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.onDark58,
                  height: 1.45,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.55),
                  width: 1.1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.gold.withValues(alpha: 0.95),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'INVITATION CONFIRMED',
                        style: TextStyle(
                          color: AppColors.gold.withValues(alpha: 0.95),
                          fontSize: 11,
                          letterSpacing: 2.1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Text(
                        'Invite Type',
                        style: TextStyle(
                          color: AppColors.onDark46,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Professional Barber',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Text(
                        'Branch',
                        style: TextStyle(
                          color: AppColors.onDark46,
                          fontSize: 11,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _displayBranchName(invite),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.onDark08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Locked Email',
                                style: TextStyle(
                                  color: AppColors.onDark45,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                invite.email,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
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
                ],
              ),
            ),
            const SizedBox(height: 30),
            Text(
              'Full Name',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _fullNameController,
              style: const TextStyle(color: AppColors.text, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Ex. John Doe',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                ),
                filled: true,
                fillColor: AppColors.surfaceSoft,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.onDark08),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Password',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newPasswordController,
              obscureText: _obscureNewPassword,
              style: const TextStyle(color: AppColors.text, fontSize: 15),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'password',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                ),
                filled: true,
                fillColor: AppColors.surfaceSoft,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.onDark08),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => _obscureNewPassword = !_obscureNewPassword,
                  ),
                  icon: Icon(
                    _obscureNewPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.onDark45,
                  ),
                ),
              ),
            ),
            if (password.isNotEmpty && !isStrong) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.gold,
                  ),
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
            Text(
              'Confirm Password',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirmPassword,
              style: const TextStyle(color: AppColors.text, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'confirm password',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                ),
                filled: true,
                fillColor: AppColors.surfaceSoft,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.onDark08),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
                suffixIcon: IconButton(
                  onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword,
                  ),
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppColors.onDark45,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        hasMinLength
                            ? Icons.check_rounded
                            : Icons.cancel_rounded,
                        size: 16,
                        color: hasMinLength
                            ? AppColors.gold
                            : AppColors.onDark40,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'At least 8 characters',
                        style: TextStyle(
                          color: hasMinLength
                              ? AppColors.gold
                              : AppColors.onDark40,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        hasLetter ? Icons.check_rounded : Icons.cancel_rounded,
                        size: 16,
                        color: hasLetter ? AppColors.gold : AppColors.onDark40,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Contains one letter',
                        style: TextStyle(
                          color: hasLetter
                              ? AppColors.gold
                              : AppColors.onDark40,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        hasNumber ? Icons.check_rounded : Icons.cancel_rounded,
                        size: 16,
                        color: hasNumber ? AppColors.gold : AppColors.onDark40,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Contains one number',
                        style: TextStyle(
                          color: hasNumber
                              ? AppColors.gold
                              : AppColors.onDark40,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        hasSymbol ? Icons.check_rounded : Icons.cancel_rounded,
                        size: 16,
                        color: hasSymbol ? AppColors.gold : AppColors.onDark40,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Contains one symbol',
                        style: TextStyle(
                          color: hasSymbol
                              ? AppColors.gold
                              : AppColors.onDark40,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 64,
              child: ElevatedButton(
                onPressed: _loading ? null : _createAndJoin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.shellBackground,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.3,
                  ),
                  elevation: 10,
                  shadowColor: AppColors.gold.withValues(alpha: 0.3),
                ),
                child: Text(
                  _loading ? 'PROCESSING...' : 'CREATE ACCOUNT & JOIN',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () => setState(() => _existingAccount = true),
                child: Text(
                  'Already have an account? Sign in & Join',
                  style: TextStyle(
                    color: AppColors.gold.withValues(alpha: 0.95),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: _loading
                    ? null
                    : () => Navigator.of(context).maybePop(),
                child: Text(
                  'CANCEL REGISTRATION',
                  style: TextStyle(
                    color: AppColors.onDark45,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLuxuryBarberExistingAccount(_InvitePayload invite) {
    final branchName = _displayBranchName(invite);

    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(
                    child: Text(
                      'Join as Barber',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 31,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                        height: 1.08,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      'Complete your profile connection to the sanctuary',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.onDark58,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: AppColors.gold.withValues(alpha: 0.55),
                        width: 1.1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BRANCH NAME',
                                    style: TextStyle(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.9,
                                      ),
                                      fontSize: 10,
                                      letterSpacing: 2.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    branchName,
                                    style: const TextStyle(
                                      fontFamily: 'PlayfairDisplay',
                                      fontSize: 20,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.3),
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'BARBER',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Divider(color: AppColors.onDark06, height: 1),
                        const SizedBox(height: 14),
                        Text(
                          'CONNECTED EMAIL',
                          style: TextStyle(
                            color: AppColors.gold.withValues(alpha: 0.85),
                            fontSize: 10,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.onDark55,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                invite.email,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'ACCOUNT PASSWORD',
                    style: TextStyle(
                      color: AppColors.onDark58,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppColors.text, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.26),
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceSoft,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.onDark08),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: AppColors.gold),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: AppColors.gold.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _joinWithExistingAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.shellBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        elevation: 10,
                        shadowColor: AppColors.gold.withValues(alpha: 0.3),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.3,
                        ),
                      ),
                      child: Text(
                        _loading ? 'PROCESSING...' : 'SIGN IN & JOIN',
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => setState(() => _existingAccount = false),
                      child: Text(
                        "Don't have an account? Sign up & Join",
                        style: TextStyle(
                          color: AppColors.gold.withValues(alpha: 0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).maybePop(),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.onDark50,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLuxuryOwnerRegistration(_InvitePayload invite) {
    final ownerPassword = _newPasswordController.text;
    final ownerHasMinLength = ownerPassword.length >= 8;
    final ownerHasLetter = RegExp(r'[A-Za-z]').hasMatch(ownerPassword);
    final ownerHasNumber = RegExp(r'[0-9]').hasMatch(ownerPassword);
    final ownerHasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(ownerPassword);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: AppColors.surfaceSoft,
              hintStyle: TextStyle(
                color: Colors.white.withValues(alpha: 0.28),
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
              errorStyle: const TextStyle(color: Color(0xFFFF8A80)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.onDark08, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppColors.gold.withValues(alpha: 1),
                  width: 1,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFFF8A80)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFFF8A80)),
              ),
            ),
          ),
          child: Form(
            key: _ownerFormKey,
            autovalidateMode: _ownerSubmitted
                ? AutovalidateMode.onUserInteraction
                : AutovalidateMode.disabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    'Set Up Your Branch',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 31,
                      fontWeight: FontWeight.w700,
                      height: 1.08,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Establish your domain and begin your journey\nas an elite owner.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.60),
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.55),
                      width: 1.1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.verified_rounded,
                                  color: AppColors.gold,
                                  size: 17,
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'INVITE TYPE: OWNER',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  color: AppColors.onDark50,
                                  size: 17,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    invite.email,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.66,
                                      ),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gold.withValues(alpha: 0.12),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: AppColors.gold,
                          size: 30,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppColors.gold.withValues(alpha: 0.34),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'BRANCH INFORMATION',
                        style: TextStyle(
                          color: AppColors.gold.withValues(alpha: 0.98),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.4,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: AppColors.gold.withValues(alpha: 0.34),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Branch Name',
                  style: TextStyle(color: AppColors.onDark70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _shopNameController,
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. Sovereign Heights',
                    prefixIcon: Icon(
                      Icons.storefront_rounded,
                      color: AppColors.gold.withValues(alpha: 0.75),
                    ),
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Branch name is required';
                    if (v.length < 2) return 'Enter a valid branch name';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'Branch Location',
                  style: TextStyle(color: AppColors.onDark70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _shopLocationController,
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'e.g. 123 Main St, Cityville',
                    prefixIcon: Icon(
                      Icons.location_on_rounded,
                      color: AppColors.gold.withValues(alpha: 0.75),
                    ),
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Branch location is required';
                    if (v.length < 2) return 'Enter a valid location';
                    return null;
                  },
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: AppColors.gold.withValues(alpha: 0.34),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'ACCOUNT DETAILS',
                        style: TextStyle(
                          color: AppColors.gold.withValues(alpha: 0.98),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 3.4,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: AppColors.gold.withValues(alpha: 0.34),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Full Name',
                  style: TextStyle(color: AppColors.onDark70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _fullNameController,
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Ex. Alexander Sterling',
                  ),
                  validator: (value) {
                    final v = (value ?? '').trim();
                    if (v.isEmpty) return 'Full name is required';
                    if (v.length < 2) return 'Enter your full name';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'Password',
                  style: TextStyle(color: AppColors.onDark70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscureNewPassword = !_obscureNewPassword,
                      ),
                      icon: Icon(
                        _obscureNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.onDark45,
                      ),
                    ),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    if (_confirmPasswordController.text.isNotEmpty) {
                      _ownerFormKey.currentState?.validate();
                    }
                  },
                  validator: (value) {
                    final password = value ?? '';
                    if (password.isEmpty) return 'Password is required';
                    if (password.length < 8) {
                      return 'Use at least 8 characters';
                    }
                    if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
                      return 'Include at least one letter';
                    }
                    if (!RegExp(r'[0-9]').hasMatch(password)) {
                      return 'Include at least one number';
                    }
                    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
                      return 'Include at least one symbol';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                Text(
                  'Confirm Password',
                  style: TextStyle(color: AppColors.onDark70, fontSize: 12),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  style: const TextStyle(color: AppColors.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'confirm password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      ),
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.onDark45,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final confirm = value ?? '';
                    if (confirm.isEmpty) return 'Confirm your password';
                    if (confirm != _newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _createAndJoin(),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            ownerHasMinLength
                                ? Icons.check_rounded
                                : Icons.cancel_rounded,
                            size: 16,
                            color: ownerHasMinLength
                                ? AppColors.gold
                                : AppColors.onDark40,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'At least 8 characters',
                            style: TextStyle(
                              color: ownerHasMinLength
                                  ? AppColors.gold
                                  : AppColors.onDark40,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            ownerHasLetter
                                ? Icons.check_rounded
                                : Icons.cancel_rounded,
                            size: 16,
                            color: ownerHasLetter
                                ? AppColors.gold
                                : AppColors.onDark40,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Contains one letter',
                            style: TextStyle(
                              color: ownerHasLetter
                                  ? AppColors.gold
                                  : AppColors.onDark40,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            ownerHasNumber
                                ? Icons.check_rounded
                                : Icons.cancel_rounded,
                            size: 16,
                            color: ownerHasNumber
                                ? AppColors.gold
                                : AppColors.onDark40,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Contains one number',
                            style: TextStyle(
                              color: ownerHasNumber
                                  ? AppColors.gold
                                  : AppColors.onDark40,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            ownerHasSymbol
                                ? Icons.check_rounded
                                : Icons.cancel_rounded,
                            size: 16,
                            color: ownerHasSymbol
                                ? AppColors.gold
                                : AppColors.onDark40,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Contains one symbol',
                            style: TextStyle(
                              color: ownerHasSymbol
                                  ? AppColors.gold
                                  : AppColors.onDark40,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 34),
                SizedBox(
                  width: double.infinity,
                  height: 64,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _createAndJoin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.shellBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 10,
                      shadowColor: AppColors.gold.withValues(alpha: 0.32),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.3,
                      ),
                    ),
                    child: Text(
                      _loading ? 'CREATING...' : 'CREATE OWNER ACCOUNT',
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _existingAccount = true),
                    child: Text(
                      'Already have an account? Sign in & Join',
                      style: TextStyle(
                        color: AppColors.gold.withValues(alpha: 0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).maybePop(),
                    child: Text(
                      'CANCEL SETUP',
                      style: TextStyle(
                        color: AppColors.onDark52,
                        fontSize: 11,
                        letterSpacing: 3.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Icon(
                    Icons.shield_outlined,
                    color: Colors.white.withValues(alpha: 0.14),
                    size: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    this.accountExists,
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
  final bool? accountExists;

  _InvitePayload copyWith({
    String? shopName,
    String? shopLocation,
    String? branchId,
    String? shopId,
    String? ownerId,
    bool? accountExists,
  }) {
    return _InvitePayload(
      collection: collection,
      reference: reference,
      code: code,
      email: email,
      role: role,
      status: status,
      used: used,
      expiresAt: expiresAt,
      branchId: branchId ?? this.branchId,
      shopId: shopId ?? this.shopId,
      ownerId: ownerId ?? this.ownerId,
      shopName: shopName ?? this.shopName,
      shopLocation: shopLocation ?? this.shopLocation,
      accountExists: accountExists ?? this.accountExists,
    );
  }

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
      accountExists: data['accountExists'] is bool
          ? data['accountExists'] as bool
          : null,
    );
  }
}
