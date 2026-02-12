import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/theme/app_colors.dart';
import 'login_screen.dart';

class ForgotPasswordConfirmationScreen extends StatefulWidget {
  const ForgotPasswordConfirmationScreen({
    super.key,
    this.email = 'your registered email',
  });

  final String email;

  @override
  State<ForgotPasswordConfirmationScreen> createState() =>
      _ForgotPasswordConfirmationScreenState();
}

class _ForgotPasswordConfirmationScreenState
    extends State<ForgotPasswordConfirmationScreen> {
  bool _isResending = false;

  Future<void> _handleResend() async {
    if (_isResending) return;
    setState(() {
      _isResending = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: widget.email);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mapAuthError(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isResending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isResending = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reset link sent again'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email address is not valid';
      case 'user-not-found':
        return 'No account found for this email';
      case 'too-many-requests':
        return 'Too many attempts. Try again later';
      case 'network-request-failed':
        return 'Network error. Check internet, VPN, and phone date/time';
      default:
        return '[${e.code}] ${e.message ?? 'Could not resend reset email'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070A12),
      body: Stack(
        children: [
          const Positioned.fill(child: _BackdropGlow()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  const SizedBox(height: 44),
                  const Spacer(),
                  const _MailBadge(),
                  const SizedBox(height: 30),
                  const Text(
                    'Check Your Email',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      height: 1.08,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'PlayfairDisplay',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "We've sent a password reset link to your\nregistered email address. Please check your\ninbox (and spam folder).",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.55,
                      color: const Color(0xFF9CA3AF).withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(27),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.25),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: const Color(0xFF070A12),
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(27),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pushAndRemoveUntil(
                            Motion.pageRoute(
                              builder: (_) => const LoginScreen(
                                headerImageAsset:
                                    'assets/images/login_screen.png',
                              ),
                            ),
                            (route) => false,
                          );
                        },
                        child: const Text('Go to Login'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the email? ",
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(
                            0xFF9CA3AF,
                          ).withValues(alpha: 0.75),
                        ),
                      ),
                      GestureDetector(
                        onTap: _isResending ? null : _handleResend,
                        child: Text(
                          _isResending ? 'Sending...' : 'Resend',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.gold.withValues(
                              alpha: _isResending ? 0.65 : 1,
                            ),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MailBadge extends StatelessWidget {
  const _MailBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1F2E), Color(0xFF070A12)],
        ),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.28),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: const Icon(Icons.mark_email_read, color: AppColors.gold, size: 36),
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFF070A12)),
        Positioned(
          top: -120,
          left: -120,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.05),
            ),
          ),
        ),
        Positioned(
          bottom: -120,
          right: -120,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.05),
            ),
          ),
        ),
      ],
    );
  }
}
