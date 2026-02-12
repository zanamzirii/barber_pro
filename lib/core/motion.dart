import 'package:flutter/material.dart';

class Motion {
  const Motion._();

  static const Duration pageTransitionDuration = Duration(milliseconds: 250);
  static const Curve pageTransitionCurve = Curves.easeInOut;

  static const Duration microAnimationDuration = Duration(milliseconds: 150);
  static const Curve microAnimationCurve = Curves.easeInOut;

  static Route<T> pageRoute<T>({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) {
    return PageRouteBuilder<T>(
      settings: settings,
      transitionDuration: pageTransitionDuration,
      reverseTransitionDuration: pageTransitionDuration,
      pageBuilder: (context, animation, secondaryAnimation) => builder(context),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: pageTransitionCurve,
        );
        return FadeTransition(opacity: curved, child: child);
      },
    );
  }

  static final PageTransitionsTheme pageTransitionsTheme = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: const _FadePageTransitionsBuilder(),
      TargetPlatform.iOS: const _FadePageTransitionsBuilder(),
      TargetPlatform.macOS: const _FadePageTransitionsBuilder(),
      TargetPlatform.windows: const _FadePageTransitionsBuilder(),
      TargetPlatform.linux: const _FadePageTransitionsBuilder(),
      TargetPlatform.fuchsia: const _FadePageTransitionsBuilder(),
    },
  );
}

class _FadePageTransitionsBuilder extends PageTransitionsBuilder {
  const _FadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.pageTransitionCurve,
    );
    return FadeTransition(opacity: curved, child: child);
  }
}
