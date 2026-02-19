import 'dart:async';
import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';
import '../../core/theme/app_colors.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.logoAsset = 'assets/images/splash_logo.png',
    this.autoNavigate = true,
    this.animationDuration = const Duration(milliseconds: 900),
    this.progress,
    this.statusText,
  });

  final String? logoAsset;
  final bool autoNavigate;
  final Duration animationDuration;
  final double? progress;
  final String? statusText;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    )..forward();

    if (widget.autoNavigate) {
      _navigationTimer = Timer(widget.animationDuration, () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          Motion.pageRoute(
            builder: (_) => const OnboardingScreen(
              backgroundImageAsset: 'assets/images/onboarding_1.png',
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress?.clamp(0.0, 1.0);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.midnight,
      body: MediaQuery.removeViewInsets(
        removeBottom: true,
        context: context,
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x14000000),
                      AppColors.midnight,
                      AppColors.midnight,
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const Spacer(),
                    _LogoBadge(logoAsset: widget.logoAsset),
                    const SizedBox(height: 24),
                    const Text(
                      'Midnight Barber',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                        fontFamily: 'PlayfairDisplay',
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'PREMIUM GROOMING',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 3.5,
                        color: Color(0x99F5F5F5),
                        fontFamily: 'Inter',
                      ),
                    ),
                    const Spacer(),
                    _LoadingBar(
                      animation: progress == null ? _controller : null,
                      progress: progress,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.statusText ?? 'v1.0.2',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0x66F5F5F5),
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge({required this.logoAsset});

  final String? logoAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFF2F2F2),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: logoAsset == null
          ? const Icon(Icons.content_cut, size: 48, color: AppColors.gold)
          : ClipOval(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  logoAsset!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.content_cut,
                    size: 48,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({this.animation, this.progress});

  final Animation<double>? animation;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final progressValue = progress;

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: progressValue != null
              ? TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: progressValue),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: value,
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [AppColors.gold, Color(0xFFF9E79F)],
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x80D4AF37), blurRadius: 10),
                      ],
                    ),
                  ),
                )
              : AnimatedBuilder(
                  animation: animation!,
                  builder: (context, child) {
                    return FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: animation!.value,
                      child: child,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: const LinearGradient(
                        colors: [AppColors.gold, Color(0xFFF9E79F)],
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x80D4AF37), blurRadius: 10),
                      ],
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Text(
          progressValue == null ? 'Loading assets...' : 'Loading...',
          style: const TextStyle(
            fontSize: 11,
            color: Color(0x66F5F5F5),
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
