import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:barber_pro/core/auth/auth_debug_feedback.dart';
import '../../core/auth/pending_onboarding_service.dart';
import '../../core/theme/app_colors.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';
import 'welcome_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _isCreating = false;
  bool _submitted = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Full name is required';
    if (name.length < 2) return 'Enter your full name';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Email is required';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Use at least 8 characters';
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
  }

  String? _validateConfirmPassword(String? value) {
    final confirm = value ?? '';
    if (confirm.isEmpty) return 'Confirm your password';
    if (confirm != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Widget _passwordRuleItem(String text, bool passed) {
    return Row(
      children: [
        Icon(
          passed ? Icons.check_rounded : Icons.cancel_rounded,
          size: 16,
          color: passed
              ? AppColors.gold
              : AppColors.muted.withValues(alpha: 0.7),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            color: passed
                ? AppColors.gold
                : AppColors.muted.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Future<void> _submitRegister() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    User? createdUser;
    bool verificationSent = false;
    String? nonBlockingWarning;

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      createdUser = credential.user;

      try {
        await createdUser?.updateDisplayName(_nameController.text.trim());
      } catch (_) {}

      try {
        await createdUser?.sendEmailVerification();
        verificationSent = true;
      } catch (_) {
        nonBlockingWarning =
            'Account created, but verification email was not sent. Open Verify screen and tap Resend Email.';
      }

      final user = createdUser;
      if (user != null) {
        try {
          await PendingOnboardingService.savePendingRegistration(user: user);
        } catch (_) {
          // Non-blocking: verify flow can still finalize identity after email verification.
        }
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mapAuthError(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
      showDevAuthError(context, e, scope: 'register');
      return;
    } catch (_) {
      // If auth account was created but a later non-auth step failed unexpectedly,
      // keep the user journey alive by moving to verification instead of hard-failing.
      if (createdUser == null) {
        if (!mounted) return;
        setState(() {
          _isCreating = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Something went wrong. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    setState(() {
      _isCreating = false;
    });

    final warningMessage = nonBlockingWarning;
    if (warningMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(warningMessage),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (!verificationSent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created. If no email arrives, tap Resend Email.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    Navigator.of(context).push(
      Motion.pageRoute(
        builder: (_) => VerifyEmailScreen(email: _emailController.text.trim()),
      ),
    );
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already used';
      case 'invalid-email':
        return 'Email address is not valid';
      case 'weak-password':
        return 'Password is too weak';
      case 'operation-not-allowed':
        return 'Email/password sign up is not enabled in Firebase';
      case 'network-request-failed':
        return 'Network error. Check internet, VPN, and phone date/time';
      default:
        return '[${e.code}] ${e.message ?? 'Sign up failed. Please try again'}';
    }
  }

  void _goBackOrWelcome() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
    navigator.pushAndRemoveUntil(
      Motion.pageRoute(
        builder: (_) => const WelcomeScreen(
          backgroundImageAsset: 'assets/images/welcome_screen.png',
        ),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final password = _passwordController.text;
    final hasMinLength = password.length >= 8;
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(password);

    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: PopScope(
        canPop: Navigator.of(context).canPop(),
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _goBackOrWelcome();
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Form(
              key: _formKey,
              autovalidateMode: _submitted
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: _goBackOrWelcome,
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            size: 18,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const Spacer(),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 32,
                          height: 1.15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'PlayfairDisplay',
                        ),
                        children: [
                          TextSpan(
                            text: 'Create an ',
                            style: TextStyle(color: AppColors.text),
                          ),
                          TextSpan(
                            text: 'Account',
                            style: TextStyle(color: AppColors.gold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Enter your details to create your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.muted,
                        fontSize: 13,
                        height: 1.5,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const _FieldLabel(text: 'Full Name'),
                  const SizedBox(height: 8),
                  _LuxTextField(
                    hintText: 'Ex. Michael Jordan',
                    icon: Icons.person_outline,
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    validator: _validateName,
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel(text: 'Email Address'),
                  const SizedBox(height: 8),
                  _LuxTextField(
                    hintText: 'michael@example.com',
                    icon: Icons.mail_outline,
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    textCapitalization: TextCapitalization.none,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel(text: 'Password'),
                  const SizedBox(height: 8),
                  _LuxTextField(
                    hintText: 'password',
                    icon: Icons.lock_outline,
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    validator: _validatePassword,
                    onChanged: (_) {
                      setState(() {});
                      if (_confirmController.text.isNotEmpty) {
                        _formKey.currentState?.validate();
                      }
                    },
                    suffixIcon: IconButton(
                      onPressed: () => setState(() {
                        _obscurePassword = !_obscurePassword;
                      }),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel(text: 'Confirm Password'),
                  const SizedBox(height: 8),
                  _LuxTextField(
                    hintText: 'confirm password',
                    icon: Icons.lock_reset,
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    validator: _validateConfirmPassword,
                    onFieldSubmitted: (_) => _submitRegister(),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() {
                        _obscureConfirm = !_obscureConfirm;
                      }),
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Column(
                      children: [
                        _passwordRuleItem(
                          'At least 8 characters',
                          hasMinLength,
                        ),
                        const SizedBox(height: 8),
                        _passwordRuleItem(
                          'Contains at least one letter',
                          hasLetter,
                        ),
                        const SizedBox(height: 8),
                        _passwordRuleItem(
                          'Contains at least one number',
                          hasNumber,
                        ),
                        const SizedBox(height: 8),
                        _passwordRuleItem(
                          'Contains at least one symbol',
                          hasSymbol,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 35),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.gold,
                            Color(0xFFF3D268),
                            AppColors.gold,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppColors.midnight,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        onPressed: _isCreating ? null : _submitRegister,
                        child: _isCreating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.midnight,
                                  ),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Text('CREATE ACCOUNT'),
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).push(
                        Motion.pageRoute(
                          builder: (_) => const LoginScreen(
                            headerImageAsset: 'assets/images/login_screen.png',
                          ),
                        ),
                      ),
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                          ),
                          children: const [
                            TextSpan(text: 'Already have an account? '),
                            TextSpan(
                              text: 'Log In',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.gold.withValues(alpha: 0.9),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        fontSize: 12,
      ),
    );
  }
}

class _LuxTextField extends StatelessWidget {
  const _LuxTextField({
    required this.hintText,
    required this.icon,
    required this.controller,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.onFieldSubmitted,
    this.onChanged,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.textCapitalization = TextCapitalization.none,
  });

  final String hintText;
  final IconData icon;
  final TextEditingController controller;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      onChanged: onChanged,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      textCapitalization: textCapitalization,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      style: const TextStyle(
        color: AppColors.text,
        decoration: TextDecoration.none,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: AppColors.muted.withValues(alpha: 0.4)),
        errorStyle: const TextStyle(color: Color(0xFFFF8A80)),
        filled: true,
        fillColor: const Color(0xFF121620),
        prefixIcon: Icon(icon, color: AppColors.muted.withValues(alpha: 0.6)),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.gold),
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
    );
  }
}
