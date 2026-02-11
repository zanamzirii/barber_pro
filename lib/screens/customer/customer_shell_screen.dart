import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_colors.dart';
import 'book_appointment_screen.dart';
import 'chat_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'select_branch_screen.dart';

class CustomerShellScreen extends StatefulWidget {
  const CustomerShellScreen({super.key});

  @override
  State<CustomerShellScreen> createState() => _CustomerShellScreenState();
}

class _CustomerShellScreenState extends State<CustomerShellScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens = const [
    HomeScreen(),
    ExploreScreen(),
    HomeScreen(),
    ChatScreen(),
    ProfileScreen(),
  ];

  Future<void> _openBookFlow(String userId) async {
    String? selectedShopId =
        (await FirebaseFirestore.instance.collection('users').doc(userId).get())
                .data()?['selectedShopId']
            as String?;
    selectedShopId = selectedShopId?.trim();

    if (selectedShopId == null || selectedShopId.isEmpty) {
      if (!mounted) return;
      final picked = await Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => SelectBranchScreen(userId: userId)),
      );
      selectedShopId = picked?.trim();
    }

    if (!mounted || selectedShopId == null || selectedShopId.isEmpty) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookAppointmentScreen(initialShopId: selectedShopId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userId == null
            ? null
            : FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .snapshots(),
        builder: (context, snapshot) {
          final effectiveIndex = _currentIndex;

          return Stack(
            children: [
              IndexedStack(index: effectiveIndex, children: _screens),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Container(
                      height: 72,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121620).withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 30,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _NavItem(
                            icon: Icons.home,
                            label: 'Home',
                            active: effectiveIndex == 0,
                            onTap: () => setState(() => _currentIndex = 0),
                          ),
                          _NavItem(
                            icon: Icons.explore,
                            label: 'Explore',
                            dimmed: true,
                            active: effectiveIndex == 1,
                            onTap: () => setState(() => _currentIndex = 1),
                          ),
                          _NavItem(
                            icon: Icons.calendar_month,
                            label: 'Book',
                            primary: true,
                            onTap: userId == null
                                ? null
                                : () async {
                                    setState(() => _currentIndex = 0);
                                    await _openBookFlow(userId);
                                  },
                          ),
                          _NavItem(
                            icon: Icons.chat_bubble,
                            label: 'Chat',
                            dimmed: true,
                            active: effectiveIndex == 3,
                            onTap: () => setState(() => _currentIndex = 3),
                          ),
                          _NavItem(
                            icon: Icons.person,
                            label: 'Profile',
                            dimmed: true,
                            active: effectiveIndex == 4,
                            onTap: () => setState(() => _currentIndex = 4),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.primary = false,
    this.dimmed = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool primary;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.gold,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF05070A), width: 5),
            boxShadow: [
              BoxShadow(
                color: AppColors.gold.withValues(alpha: 0.5),
                blurRadius: 26,
              ),
            ],
          ),
          child: Icon(icon, color: const Color(0xFF05070A), size: 28),
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Center(
          child: Icon(
            icon,
            color: active
                ? AppColors.gold
                : AppColors.text.withValues(alpha: dimmed ? 0.35 : 0.8),
            size: 22,
          ),
        ),
      ),
    );
  }
}
