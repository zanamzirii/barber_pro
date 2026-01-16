import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.logoAsset = 'assets/images/splash_logo.png',
  });

  final String? logoAsset;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();

    Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              const OnboardingScreen(
                backgroundImageAsset: 'assets/images/onboarding_1.png',
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
                  begin: const Offset(0, 0.06),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Stack(
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
                  _LoadingBar(progress: _controller),
                  const SizedBox(height: 16),
                  const Text(
                    'v1.0.2',
                    style: TextStyle(
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
                  errorBuilder: (_, __, ___) => const Icon(
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
  const _LoadingBar({required this.progress});

  final Animation<double> progress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 2,
          decoration: BoxDecoration(
            color: AppColors.gold.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedBuilder(
            animation: progress,
            builder: (context, child) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.value,
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
        const Text(
          'Loading assets...',
          style: TextStyle(
            fontSize: 11,
            color: Color(0x66F5F5F5),
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
