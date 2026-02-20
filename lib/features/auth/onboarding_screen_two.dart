import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';
import '../../core/theme/app_colors.dart';
import 'onboarding_screen_three.dart';

class OnboardingScreenTwo extends StatelessWidget {
  const OnboardingScreenTwo({super.key, this.illustrationAsset});

  final String? illustrationAsset;

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
                : AppColors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith<Color?>(
            (states) => states.contains(WidgetState.pressed)
                ? AppColors.midnight
                : AppColors.gold,
          ),
        );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.midnight,
      body: MediaQuery.removeViewInsets(
        removeBottom: true,
        context: context,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
            child: Column(
              children: [
                _IllustrationCard(assetPath: illustrationAsset),
                const SizedBox(height: 24),
                const Text(
                  'Effortless Management\n& Booking',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                    fontFamily: 'PlayfairDisplay',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Experience seamless scheduling at your fingertips. Whether '
                  'you are booking a fresh cut or managing your daily lineup, '
                  'efficiency is just a tap away.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.6,
                    color: Color(0xB3F5F5F5),
                    fontFamily: 'Inter',
                  ),
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    _Indicator(active: false, isWide: false),
                    SizedBox(width: 10),
                    _Indicator(active: true, isWide: true),
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
                        builder: (_) => const OnboardingScreenThree(
                          backgroundImageAsset:
                              'assets/images/onboarding_3.png',
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
      ),
    );
  }
}

class _IllustrationCard extends StatelessWidget {
  const _IllustrationCard({this.assetPath});

  final String? assetPath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: double.infinity,
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.16),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
            image: assetPath == null
                ? null
                : DecorationImage(
                    image: AssetImage(assetPath!),
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.2),
                  ),
            color: const Color(0xFF161821),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.transparent,
                  AppColors.transparent,
                  Color(0xCC0B0F1A),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          right: 18,
          bottom: 18,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1E29),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.event_available, color: AppColors.gold),
          ),
        ),
      ],
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
