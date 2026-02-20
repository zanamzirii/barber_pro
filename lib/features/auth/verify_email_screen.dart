import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barber_pro/app_shell.dart';
import 'package:barber_pro/core/auth/auth_debug_feedback.dart';
import 'package:barber_pro/core/auth/pending_onboarding_service.dart';
import 'package:barber_pro/core/motion.dart';
import '../../core/theme/app_colors.dart';
import 'register_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    this.email = 'user@example.com',
    this.allowChangeEmail = true,
  });

  final String email;
  final bool allowChangeEmail;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const int _cooldownSeconds = 45;
  static const Duration _autoCheckInterval = Duration(seconds: 6);
  int _remainingSeconds = 0;
  Timer? _autoCheckTimer;
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkVerificationSilently();
    });
    _autoCheckTimer = Timer.periodic(_autoCheckInterval, (_) {
      _checkVerificationSilently();
    });
  }

  late final _VerifyLifecycleObserver _lifecycleObserver =
      _VerifyLifecycleObserver(onResumed: _checkVerificationSilently);

  Future<void> _startCooldown() async {
    if (_remainingSeconds > 0) return;
    setState(() {
      _remainingSeconds = _cooldownSeconds;
    });
    await Future.doWhile(() async {
      if (!mounted) return false;
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _remainingSeconds = (_remainingSeconds - 1).clamp(0, _cooldownSeconds);
      });
      return _remainingSeconds > 0;
    });
  }

  Future<void> _handleResendVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      _startCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Could not resend verification email'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      showDevAuthError(context, e, scope: 'verify_email_resend');
    }
  }

  Future<void> _handleContinue() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please log in again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await user.reload();
    final refreshedUser = FirebaseAuth.instance.currentUser;
    if (!mounted) return;

    if (refreshedUser?.emailVerified == true) {
      await _goToAppAfterVerification();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email is not verified yet. Please check inbox.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _goToAppAfterVerification() async {
    if (_navigating) return;
    _navigating = true;
    try {
      await _finalizeWithRetry();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        Motion.pageRoute(builder: (_) => const AppShell()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not finalize account setup: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      _navigating = false;
    }
  }

  Future<void> _finalizeWithRetry() async {
    var delayMs = 350;
    Object? lastError;
    for (var i = 0; i < 3; i++) {
      try {
        await PendingOnboardingService.finalizeForCurrentUser();
        return;
      } on FirebaseException catch (e) {
        lastError = e;
        final transient =
            e.code == 'unavailable' ||
            e.code == 'aborted' ||
            e.code == 'deadline-exceeded';
        if (!transient || i == 2) rethrow;
      } catch (e) {
        lastError = e;
        if (i == 2) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      delayMs *= 2;
    }
    if (lastError != null) throw lastError;
  }

  Future<void> _checkVerificationSilently() async {
    if (!mounted || _navigating) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (!mounted) return;
      if (refreshedUser?.emailVerified == true) {
        await _goToAppAfterVerification();
      }
    } catch (_) {}
  }

  Future<void> _handleChangeEmail() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Session expired. Please register again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uid = user.uid;

    try {
      // Step 1: Delete account data (Case 9).
      try {
        await FirebaseFirestore.instance
            .collection('pending_onboarding')
            .doc(uid)
            .delete();
      } catch (_) {}

      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      } catch (_) {}

      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = e.code == 'requires-recent-login'
          ? 'For security, sign in again before changing email.'
          : (e.message ?? 'Could not delete account. Try again.');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
      showDevAuthError(context, e, scope: 'verify_change_email_delete');
      return;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not delete account. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      // Step 2: Clear local session.
      await auth.signOut();
    } catch (_) {}

    if (!mounted) return;
    // Step 3: Navigate to Register only after successful deletion.
    Navigator.of(context).pushAndRemoveUntil(
      Motion.pageRoute(builder: (_) => const RegisterScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCooldown = _remainingSeconds > 0;

    return PopScope(
      canPop: false,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.surface,
        body: MediaQuery.removeViewInsets(
          removeBottom: true,
          context: context,
          child: Stack(
            children: [
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 28),
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF13161E),
                          border: Border.all(color: const Color(0xFF2A2E3B)),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(
                              Icons.mark_email_unread,
                              color: AppColors.gold,
                              size: 40,
                            ),
                            Positioned(
                              bottom: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF13161E),
                                  border: Border.all(
                                    color: const Color(0xFF2A2E3B),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.verified,
                                  color: AppColors.gold,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Verify Your Email',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'PlayfairDisplay',
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'We sent a verification link to',
                        style: TextStyle(color: AppColors.muted, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.email,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),

                      if (widget.allowChangeEmail)
                        TextButton(
                          onPressed: _handleChangeEmail,
                          child: Text(
                            'Change email',
                            style: TextStyle(
                              color: AppColors.gold.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      const Spacer(),
                      const SizedBox(height: 18),
                      Column(
                        children: [
                          Text(
                            "Didn't receive the email?",
                            style: TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextButton(
                            onPressed: isCooldown
                                ? null
                                : () => _handleResendVerification(),
                            child: Text(
                              isCooldown
                                  ? 'Resend available in ${_remainingSeconds}s'
                                  : 'Resend Email',
                              style: TextStyle(
                                color: isCooldown
                                    ? AppColors.muted
                                    : AppColors.text,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.gold, Color(0xFFC29F2E)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.gold.withValues(alpha: 0.25),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.transparent,
                              foregroundColor: AppColors.surface,
                              shadowColor: AppColors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: _handleContinue,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('I Verified'),
                                SizedBox(width: 6),
                                Icon(Icons.arrow_forward, size: 18),
                                SizedBox(width: 6),
                                Text('Continue'),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'After verifying, come back and tap Continue',
                        style: TextStyle(
                          color: AppColors.muted.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VerifyLifecycleObserver with WidgetsBindingObserver {
  _VerifyLifecycleObserver({required this.onResumed});

  final VoidCallback onResumed;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResumed();
    }
  }
}
