import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';
import '../../core/theme/app_colors.dart';
import 'onboarding_screen_two.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.backgroundImageAsset});

  // Set this to an asset path (e.g. assets/images/onboarding_1.jpg) once added.
  final String? backgroundImageAsset;

  @override
  Widget build(BuildContext context) {
    final buttonStyle =
        OutlinedButton.styleFrom(
          foregroundColor: AppColors.gold,
          side: const BorderSide(color: AppColors.gold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.pressed)
                ? AppColors.gold.withValues(alpha: 0.2)
                : null,
          ),
          backgroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.pressed)
                ? AppColors.gold
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.pressed)
                ? AppColors.midnight
                : AppColors.gold,
          ),
        );

    return Scaffold(
      backgroundColor: AppColors.midnight,
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.midnight,
                image: backgroundImageAsset == null
                    ? null
                    : DecorationImage(
                        image: AssetImage(backgroundImageAsset!),
                        fit: BoxFit.cover,
                        alignment: const Alignment(-0.55, -1.0),
                      ),
              ),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x66000000),
                    AppColors.midnight,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Spacer(flex: 2),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 36,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'PlayfairDisplay',
                      ),
                      children: [
                        TextSpan(
                          text: 'Empower\n',
                          style: TextStyle(color: AppColors.text),
                        ),
                        TextSpan(
                          text: 'Your Business',
                          style: TextStyle(color: AppColors.gold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Streamline your appointments, manage client profiles, and '
                    'optimize your schedule with tools designed for the modern '
                    'barber.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Color(0xCCF5F5F5),
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(height: 50),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      _Indicator(active: true, isWide: true),
                      SizedBox(width: 10),
                      _Indicator(active: false, isWide: false),
                      SizedBox(width: 10),
                      _Indicator(active: false, isWide: false),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      style: buttonStyle,
                      onPressed: () => Navigator.of(context).push(
                        Motion.pageRoute(
                          builder: (_) => const OnboardingScreenTwo(
                            illustrationAsset: 'assets/images/onboarding_2.png',
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Inter',
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  const _Indicator({required this.active, required this.isWide});

  final bool active;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final width = isWide ? 24.0 : 6.0;
    final color = active
        ? AppColors.gold
        : const Color(0x80231E10); // surface-dark/50

    return Container(
      width: width,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: active ? null : Border.all(color: const Color(0x33F5F5F5)),
        boxShadow: active
            ? [const BoxShadow(color: Color(0x80D4AF37), blurRadius: 10)]
            : null,
      ),
    );
  }
}
