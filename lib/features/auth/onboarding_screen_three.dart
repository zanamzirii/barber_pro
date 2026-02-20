import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';
import '../../core/theme/app_colors.dart';
import 'welcome_screen.dart';

class OnboardingScreenThree extends StatelessWidget {
  const OnboardingScreenThree({super.key, this.backgroundImageAsset});

  final String? backgroundImageAsset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.midnight,
      body: MediaQuery.removeViewInsets(
        removeBottom: true,
        context: context,
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: backgroundImageAsset == null
                        ? const DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.midnight,
                            ),
                          )
                        : Image.asset(
                            backgroundImageAsset!,
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, -0.2),
                          ),
                  ),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x00070A12),
                            Color(0xB3070A12),
                            AppColors.surface,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 34,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'PlayfairDisplay',
                        ),
                        children: [
                          TextSpan(
                            text: 'Experience\n',
                            style: TextStyle(color: AppColors.text),
                          ),
                          TextSpan(
                            text: 'True Luxury',
                            style: TextStyle(color: AppColors.gold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Discover a world where precision cuts meet premium service. '
                      'Manage your appointments with an interface as elegant as '
                      'your style.',
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.6,
                        color: Color(0xCCF5F5F5),
                        fontFamily: 'Inter',
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        _Indicator(active: false, isWide: false),
                        SizedBox(width: 10),
                        _Indicator(active: false, isWide: false),
                        SizedBox(width: 10),
                        _Indicator(active: true, isWide: true),
                      ],
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.midnight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          Motion.pageRoute(
                            builder: (_) => const WelcomeScreen(
                              backgroundImageAsset:
                                  'assets/images/welcome_screen.png',
                            ),
                          ),
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'Inter',
                          ),
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
