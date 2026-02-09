import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'forgot_password_confirmation_screen.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  bool _isSending = false;
  bool _submitted = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Email is required';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  Future<void> _handleSend() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _submitted = true;
    });

    if (!_formKey.currentState!.validate()) return;
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    final email = _emailController.text.trim();
    setState(() {
      _isSending = false;
    });
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ForgotPasswordConfirmationScreen(
              email: email.isEmpty ? 'your registered email' : email,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final content = Form(
      key: _formKey,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _BackButton(onTap: () => Navigator.pop(context)),
          const SizedBox(height: 38),
          const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 32,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Don't worry, it happens. Please enter the\nemail address linked to your account and\nwe’ll send you reset instructions.",
            style: TextStyle(
              fontSize: 16,
              height: 1.55,
              color: const Color(0xFF9CA3AF).withValues(alpha: 0.88),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 28),
          _LuxuryEmailField(
            controller: _emailController,
            validator: _validateEmail,
            onFieldSubmitted: (_) => _handleSend(),
          ),
          const SizedBox(height: 34),
          _SendButton(isSending: _isSending, onPressed: _handleSend),
          if (!isKeyboardOpen) const Spacer(),
          const SizedBox(height: 24),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Remember Password? ',
                  style: TextStyle(
                    color: const Color(0xFF9CA3AF).withValues(alpha: 0.88),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pushReplacement(
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const LoginScreen(
                            headerImageAsset: 'assets/images/login_screen.png',
                          ),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            final curved = CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            );
                            return FadeTransition(
                              opacity: curved,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.04),
                                  end: Offset.zero,
                                ).animate(curved),
                                child: child,
                              ),
                            );
                          },
                    ),
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: AppColors.gold,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF070A12),
      body: Stack(
        children: [
          const Positioned.fill(child: _BackdropGlow()),
          SafeArea(
            child: isKeyboardOpen
                ? SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: content,
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: content,
                  ),
          ),
        ],
      ),
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
          right: -120,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.035),
            ),
          ),
        ),
        Positioned(
          bottom: -130,
          left: -120,
          child: Container(
            width: 260,
            height: 260,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF102246).withValues(alpha: 0.12),
            ),
          ),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }
}

class _LuxuryEmailField extends StatelessWidget {
  const _LuxuryEmailField({
    required this.controller,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF13161F),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        smartDashesType: SmartDashesType.disabled,
        smartQuotesType: SmartQuotesType.disabled,
        textAlignVertical: TextAlignVertical.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w400,
          decoration: TextDecoration.none,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          errorStyle: const TextStyle(color: Color(0xFFFF8A80)),
          prefixIcon: Icon(
            Icons.mail,
            size: 18,
            color: const Color(0xFF9CA3AF).withValues(alpha: 0.6),
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 44,
            minHeight: 44,
          ),
          hintText: 'Email Address',
          hintStyle: TextStyle(
            color: const Color(0xFF9CA3AF).withValues(alpha: 0.6),
            fontSize: 16,
            fontWeight: FontWeight.w500,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.isSending, required this.onPressed});

  final bool isSending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withValues(alpha: 0.34),
              blurRadius: 15,
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
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          onPressed: isSending ? null : onPressed,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isSending) ...[
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF070A12),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Sending...',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ] else ...[
                const Text(
                  'Send Reset Email',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.send, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
