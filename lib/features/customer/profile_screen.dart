import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';

import '../../app_shell.dart';
import '../../role_switcher.dart';
import '../../core/theme/app_colors.dart';
import 'customer_data_mapper.dart';
import 'my_appointments_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userStream = user == null
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots();

    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      body: Stack(
        children: [
          const _SilkyBackground(),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: userStream,
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? const <String, dynamic>{};
                final name = CustomerDataMapper.userFullName(
                  data,
                  fallback: user?.displayName?.trim().isNotEmpty == true
                      ? user!.displayName!.trim()
                      : 'Customer',
                );
                final email = user?.email ?? 'email@example.com';
                final avatarUrl = CustomerDataMapper.userAvatar(
                  data,
                  fallback: user?.photoURL ?? '',
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 120),
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Profile',
                          style: TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 24,
                            color: AppColors.text,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            InkWell(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Notifications coming soon'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(
                                  Icons.notifications_none,
                                  color: AppColors.gold,
                                  size: 22,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 6,
                              top: 6,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121620).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.35),
                          width: 0.6,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.08),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.gold,
                                width: 1.2,
                              ),
                            ),
                            child: ClipOval(
                              child: avatarUrl.isNotEmpty
                                  ? Image.network(avatarUrl, fit: BoxFit.cover)
                                  : Container(
                                      color: const Color(0xFF1B2130),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.person,
                                        color: Colors.white70,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.text,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Icon(
                                      Icons.edit,
                                      size: 15,
                                      color: Color(0x66FFFFFF),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'PREMIUM CUSTOMER',
                                    style: TextStyle(
                                      color: AppColors.gold,
                                      fontSize: 10,
                                      letterSpacing: 1.6,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    _ProfileRow(
                      label: 'Edit Profile',
                      icon: Icons.person_outline,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Edit profile screen coming soon'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    _ProfileRow(
                      label: 'My Appointments',
                      icon: Icons.calendar_month_outlined,
                      onTap: () {
                        Navigator.of(context).push(
                          Motion.pageRoute(
                            builder: (_) => const MyAppointmentsScreen(),
                          ),
                        );
                      },
                    ),
                    _ProfileRow(
                      label: 'App Settings',
                      icon: Icons.settings_outlined,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Settings screen coming soon'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    if (user != null)
                      FutureBuilder<List<String>>(
                        future: RoleSwitcher.availableRolesForCurrentUser(),
                        builder: (context, snapshot) {
                          final roles = snapshot.data ?? const <String>[];
                          if (roles.length <= 1) return const SizedBox.shrink();
                          return _ProfileRow(
                            label: 'Switch Role',
                            icon: Icons.swap_horiz,
                            onTap: () => RoleSwitcher.show(context),
                          );
                        },
                      ),
                    const SizedBox(height: 26),
                    SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () async {
                          await FirebaseAuth.instance.signOut();
                          if (!context.mounted) return;
                          Navigator.of(context).pushAndRemoveUntil(
                            Motion.pageRoute(builder: (_) => const AppShell()),
                            (route) => false,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: AppColors.gold.withValues(alpha: 0.35),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                        ),
                        child: const Text(
                          'LOG OUT',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 13,
                            letterSpacing: 3.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.gold, size: 21),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              margin: const EdgeInsets.only(left: 38),
              height: 0.6,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ],
        ),
      ),
    );
  }
}

class _SilkyBackground extends StatelessWidget {
  const _SilkyBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF05070A), Color(0xFF0B0F1A), Color(0xFF05070A)],
        ),
      ),
    );
  }
}
