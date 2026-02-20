import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

import 'owner_staff_screen.dart';
import 'owner_add_service_screen.dart';
import 'owner_appointments_screen.dart';
import 'owner_dashboard_screen.dart';
import 'owner_profile_screen.dart';

const Color _ownerGold = AppColors.gold;
const Color _ownerBg = AppColors.shellBackground;
const Color _ownerNavBg = AppColors.shellNavBackground;
const Color _ownerInactive = AppColors.shellInactive;

class OwnerShellScreen extends StatefulWidget {
  const OwnerShellScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<OwnerShellScreen> createState() => _OwnerShellScreenState();
}

class _OwnerShellScreenState extends State<OwnerShellScreen> {
  late int _index;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4);
    _screens = [
      const OwnerDashboardScreen(),
      const OwnerAppointmentsScreen(),
      const OwnerStaffScreen(),
      OwnerAddServiceScreen(onBack: _goToOverview),
      const OwnerProfileScreen(),
    ];
  }

  void _onTap(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  void _goToOverview() {
    if (_index == 0) return;
    setState(() => _index = 0);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        backgroundColor: _ownerBg,
        body: Stack(
          children: [
            IndexedStack(index: _index, children: _screens),
            _OwnerBottomBar(index: _index, onTap: _onTap),
          ],
        ),
      ),
    );
  }
}

class _OwnerBottomBar extends StatelessWidget {
  const _OwnerBottomBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: _ownerNavBg.withValues(alpha: 0.98),
            border: Border(top: BorderSide(color: AppColors.shellNavBorder)),
          ),
          child: Row(
            children: [
              _OwnerNavItem(
                activeIcon: Icons.grid_view_rounded,
                inactiveIcon: Icons.grid_view_outlined,
                label: 'OVERVIEW',
                active: index == 0,
                onTap: () => onTap(0),
              ),
              _OwnerNavItem(
                activeIcon: Icons.event_note_rounded,
                inactiveIcon: Icons.event_note_outlined,
                label: 'BOOKINGS',
                active: index == 1,
                onTap: () => onTap(1),
              ),
              _OwnerNavItem(
                activeIcon: Icons.badge_rounded,
                inactiveIcon: Icons.badge_outlined,
                label: 'STAFF',
                active: index == 2,
                onTap: () => onTap(2),
              ),
              _OwnerNavItem(
                activeIcon: Icons.content_cut_rounded,
                inactiveIcon: Icons.content_cut,
                label: 'SERVICES',
                active: index == 3,
                onTap: () => onTap(3),
              ),
              _OwnerNavItem(
                activeIcon: Icons.account_circle,
                inactiveIcon: Icons.account_circle_outlined,
                label: 'PROFILE',
                active: index == 4,
                onTap: () => onTap(4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OwnerNavItem extends StatelessWidget {
  const _OwnerNavItem({
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? _ownerGold : _ownerInactive;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? activeIcon : inactiveIcon, color: color, size: 23),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
