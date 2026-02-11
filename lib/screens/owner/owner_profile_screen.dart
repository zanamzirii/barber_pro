import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_shell.dart';
import '../../role_switcher.dart';
import '../../theme/app_colors.dart';
import '../shared/firestore_data_mapper.dart';
import 'owner_ui.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userStream = user == null
        ? null
        : FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots();

    return Scaffold(
      backgroundColor: OwnerUi.screenBg,
      body: Stack(
        children: [
          OwnerUi.background(),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: userStream,
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? const <String, dynamic>{};
                final displayName = FirestoreDataMapper.userFullName(
                  data,
                  fallback:
                      (user?.displayName?.trim().isNotEmpty ?? false)
                      ? user!.displayName!.trim()
                      : 'Owner',
                );
                final email = user?.email ?? '-';
                final avatar = FirestoreDataMapper.userAvatar(
                  data,
                  fallback: user?.photoURL ?? '',
                );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 110),
                  children: [
                Row(
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Icon(
                        Icons.notifications,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: OwnerUi.panelDecoration(radius: 22, alpha: 0.06),
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.gold),
                            ),
                            child: ClipOval(
                              child: avatar.isNotEmpty
                                  ? Image.network(avatar, fit: BoxFit.cover)
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
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Icon(
                              Icons.edit,
                              size: 18,
                              color: Colors.white.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'PlayfairDisplay',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Text(
                          'OWNER MODE',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontSize: 10,
                            letterSpacing: 1.7,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  decoration: OwnerUi.panelDecoration(radius: 22, alpha: 0.06),
                  child: Column(
                    children: [
                      _ProfileActionTile(
                        icon: Icons.person_outline,
                        label: 'Edit Profile',
                        onTap: () {},
                      ),
                      _ProfileActionTile(
                        icon: Icons.swap_horiz,
                        label: 'Switch Role',
                        onTap: () => RoleSwitcher.show(context),
                      ),
                      _ProfileActionTile(
                        icon: Icons.shield_outlined,
                        label: 'Account Security',
                        onTap: () {},
                      ),
                      _ProfileActionTile(
                        icon: Icons.settings,
                        label: 'App Settings',
                        onTap: () {},
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const AppShell()),
                        (_) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.40),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'LOG OUT',
                      style: TextStyle(
                        color: AppColors.gold,
                        letterSpacing: 3,
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

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                )
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.45),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
