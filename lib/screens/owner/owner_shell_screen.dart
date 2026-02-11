import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'owner_add_barber_screen.dart';
import 'owner_appointments_screen.dart';
import 'owner_dashboard_screen.dart';
import 'owner_profile_screen.dart';

class OwnerShellScreen extends StatefulWidget {
  const OwnerShellScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<OwnerShellScreen> createState() => _OwnerShellScreenState();
}

class _OwnerShellScreenState extends State<OwnerShellScreen> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, 4);
  }

  void _onTap(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: const [
              OwnerDashboardScreen(),
              OwnerAppointmentsScreen(),
              OwnerAddBarberScreen(),
              _OwnerChatPlaceholderScreen(),
              OwnerProfileScreen(),
            ],
          ),
          _OwnerBottomBar(index: _index, onTap: _onTap),
        ],
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
          height: 84,
          decoration: BoxDecoration(
            color: const Color(0xFF05070A).withValues(alpha: 0.95),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
            ),
          ),
          child: Row(
            children: [
              _OwnerNavItem(
                icon: Icons.grid_view_rounded,
                label: 'OVERVIEW',
                active: index == 0,
                onTap: () => onTap(0),
              ),
              _OwnerNavItem(
                icon: Icons.calendar_month,
                label: 'BOOKINGS',
                active: index == 1,
                onTap: () => onTap(1),
              ),
              _OwnerNavItem(
                icon: Icons.badge,
                label: 'STAFF',
                active: index == 2,
                onTap: () => onTap(2),
              ),
              _OwnerNavItem(
                icon: Icons.chat_bubble,
                label: 'CHAT',
                active: index == 3,
                onTap: () => onTap(3),
              ),
              _OwnerNavItem(
                icon: Icons.account_circle,
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
    required this.icon,
    required this.label,
    required this.onTap,
    required this.active,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 26,
              color: active
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? AppColors.gold
                    : Colors.white.withValues(alpha: 0.45),
                fontSize: 9,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OwnerChatPlaceholderScreen extends StatelessWidget {
  const _OwnerChatPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF05070A),
      body: Center(
        child: Text(
          'Owner chat screen coming soon',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}
