import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';

import '../../app_shell.dart';
import '../../role_switcher.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/screens/app_settings_screen.dart';
import '../../shared/data/firestore_data_mapper.dart';

class OwnerProfileScreen extends StatelessWidget {
  const OwnerProfileScreen({super.key});

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
      backgroundColor: const Color(0xFF0B0F1A),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userStream,
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? const <String, dynamic>{};
            final displayName = FirestoreDataMapper.userFullName(
              data,
              fallback: (user?.displayName?.trim().isNotEmpty ?? false)
                  ? user!.displayName!.trim()
                  : 'Owner',
            );
            final avatar = FirestoreDataMapper.userAvatar(
              data,
              fallback: user?.photoURL ?? '',
            );

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 118),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0E12),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.onDark12),
                    ),
                    child: IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          Motion.pageRoute(
                            builder: (_) => const AppSettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(child: _profileAvatar(avatar)),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'PlayfairDisplay',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'BOUTIQUE OWNER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 28),
                _sectionTitle('BUSINESS PROFILE'),
                const SizedBox(height: 10),
                _sectionPanel(
                  children: [
                    _ProfileActionTile(
                      icon: Icons.location_on_outlined,
                      label: 'Branch Locations',
                      onTap: () {},
                    ),
                    _ProfileActionTile(
                      icon: Icons.notifications_none_rounded,
                      label: 'Notifications',
                      onTap: () {},
                    ),
                    _ProfileActionTile(
                      icon: Icons.schedule_rounded,
                      label: 'Business Hours',
                      onTap: () {},
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _sectionTitle('MANAGEMENT'),
                const SizedBox(height: 10),
                _sectionPanel(
                  children: [
                    _ProfileActionTile(
                      icon: Icons.group_outlined,
                      label: 'Staff Directory',
                      onTap: () {},
                    ),
                    _ProfileActionTile(
                      icon: Icons.content_cut_rounded,
                      label: 'Service Menu Editor',
                      onTap: () {},
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _sectionTitle('ACCOUNT'),
                const SizedBox(height: 10),
                _sectionPanel(
                  children: [
                    _ProfileActionTile(
                      icon: Icons.person_outline,
                      label: 'Edit Profile',
                      onTap: () {},
                    ),
                    _ProfileActionTile(
                      icon: Icons.shield_outlined,
                      label: 'Account Security',
                      onTap: () {},
                    ),
                    _ProfileActionTile(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Switch Role',
                      onTap: () => RoleSwitcher.show(context),
                    ),
                    _ProfileActionTile(
                      icon: Icons.settings_applications_outlined,
                      label: 'App Settings',
                      onTap: () {
                        Navigator.of(context).push(
                          Motion.pageRoute(
                            builder: (_) => const AppSettingsScreen(),
                          ),
                        );
                      },
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        Motion.pageRoute(builder: (_) => const AppShell()),
                        (_) => false,
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0x29EF4444),
                      side: const BorderSide(color: Color(0x55EF4444)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'LOG OUT',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 3.0,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

Widget _sectionTitle(String text) {
  return Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Text(
      text,
      style: TextStyle(
        color: AppColors.onDark42,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.2,
      ),
    ),
  );
}

Widget _sectionPanel({required List<Widget> children}) {
  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFF161B26),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.onDark06),
      boxShadow: const [
        BoxShadow(
          color: Color(0x26D4AF37),
          blurRadius: 20,
          spreadRadius: -10,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(children: children),
  );
}

Widget _profileAvatar(String avatar) {
  return Container(
    width: 132,
    height: 132,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        colors: [Color(0xFFECB913), Color(0xFF785A07), Color(0xFFECB913)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: Color(0xFF05070A),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: avatar.isNotEmpty
            ? Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _avatarFallback(),
              )
            : _avatarFallback(),
      ),
    ),
  );
}

Widget _avatarFallback() {
  return Container(
    color: const Color(0xFF1B2130),
    alignment: Alignment.center,
    child: const Icon(Icons.person, color: AppColors.onDark70, size: 44),
  );
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(bottom: BorderSide(color: AppColors.onDark05))
              : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.gold, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppColors.onDark38, size: 20),
          ],
        ),
      ),
    );
  }
}
