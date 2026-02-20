import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';
import 'package:barber_pro/core/theme/app_colors.dart';

class RoleNavItem extends StatelessWidget {
  const RoleNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
    this.iconSize = 22,
    this.labelSize = 8,
    this.letterSpacing = 1.0,
    this.labelWeight = FontWeight.w700,
    this.avatarCircle = false,
    this.avatarRadius = 11,
    this.avatarIconSize = 14,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback? onTap;
  final double iconSize;
  final double labelSize;
  final double letterSpacing;
  final FontWeight labelWeight;
  final bool avatarCircle;
  final double avatarRadius;
  final double avatarIconSize;

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : inactiveColor;
    return Expanded(
      child: _MotionNavTap(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            avatarCircle
                ? CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: AppColors.onDark20,
                    child: Icon(
                      icon,
                      size: avatarIconSize,
                      color: Colors.white,
                    ),
                  )
                : Icon(icon, color: color, size: iconSize),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: labelSize,
                fontWeight: labelWeight,
                letterSpacing: letterSpacing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MotionNavTap extends StatefulWidget {
  const _MotionNavTap({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_MotionNavTap> createState() => _MotionNavTapState();
}

class _MotionNavTapState extends State<_MotionNavTap> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: Motion.microAnimationDuration,
      curve: Motion.microAnimationCurve,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.9 : 1,
        duration: Motion.microAnimationDuration,
        curve: Motion.microAnimationCurve,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: (value) => setState(() => _pressed = value),
          child: widget.child,
        ),
      ),
    );
  }
}
