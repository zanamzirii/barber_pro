import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/role_nav_item.dart';
import 'barber_clients_screen.dart';
import 'barber_dashboard_screen.dart';
import 'barber_profile_screen.dart';
import 'barber_schedule_screen.dart';

class BarberShellScreen extends StatefulWidget {
  const BarberShellScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<BarberShellScreen> createState() => _BarberShellScreenState();
}

class _BarberShellScreenState extends State<BarberShellScreen> {
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
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_index != 0) {
          setState(() => _index = 0);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF05070A),
        body: Stack(
          children: [
            IndexedStack(
              index: _index,
              children: [
                BarberDashboardScreen(
                  onOpenScheduleTab: () => setState(() => _index = 1),
                ),
                const BarberScheduleScreen(),
                const BarberClientsScreen(),
                const _BarberChatPlaceholderScreen(),
                const BarberProfileScreen(),
              ],
            ),
            _BarberBottomBar(index: _index, onTap: _onTap),
          ],
        ),
      ),
    );
  }
}

class _BarberBottomBar extends StatelessWidget {
  const _BarberBottomBar({required this.index, required this.onTap});

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
              RoleNavItem(
                icon: Icons.grid_view_rounded,
                label: 'DASHBOARD',
                active: index == 0,
                activeColor: AppColors.gold,
                inactiveColor: Colors.white.withValues(alpha: 0.45),
                onTap: () => onTap(0),
                iconSize: 26,
                labelSize: 9,
                letterSpacing: 1.1,
              ),
              RoleNavItem(
                icon: Icons.calendar_month_rounded,
                label: 'SCHEDULE',
                active: index == 1,
                activeColor: AppColors.gold,
                inactiveColor: Colors.white.withValues(alpha: 0.45),
                onTap: () => onTap(1),
                iconSize: 26,
                labelSize: 9,
                letterSpacing: 1.1,
              ),
              RoleNavItem(
                icon: Icons.group_rounded,
                label: 'CLIENTS',
                active: index == 2,
                activeColor: AppColors.gold,
                inactiveColor: Colors.white.withValues(alpha: 0.45),
                onTap: () => onTap(2),
                iconSize: 26,
                labelSize: 9,
                letterSpacing: 1.1,
              ),
              RoleNavItem(
                icon: Icons.chat_bubble_rounded,
                label: 'CHAT',
                active: index == 3,
                activeColor: AppColors.gold,
                inactiveColor: Colors.white.withValues(alpha: 0.45),
                onTap: () => onTap(3),
                iconSize: 26,
                labelSize: 9,
                letterSpacing: 1.1,
              ),
              RoleNavItem(
                icon: Icons.account_circle_rounded,
                label: 'PROFILE',
                active: index == 4,
                activeColor: AppColors.gold,
                inactiveColor: Colors.white.withValues(alpha: 0.45),
                onTap: () => onTap(4),
                iconSize: 26,
                labelSize: 9,
                letterSpacing: 1.1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BarberChatPlaceholderScreen extends StatelessWidget {
  const _BarberChatPlaceholderScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF05070A),
      body: Center(
        child: Text(
          'Barber chat screen coming soon',
          style: TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ),
    );
  }
}
