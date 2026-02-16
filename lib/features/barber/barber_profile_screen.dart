import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';

import '../../app_shell.dart';
import '../../core/theme/app_colors.dart';
import '../../role_switcher.dart';
import '../../shared/screens/app_settings_screen.dart';
import '../../shared/data/firestore_data_mapper.dart';

class BarberProfileScreen extends StatefulWidget {
  const BarberProfileScreen({super.key});

  @override
  State<BarberProfileScreen> createState() => _BarberProfileScreenState();
}

class _BarberProfileScreenState extends State<BarberProfileScreen> {
  bool _vacationMode = false;

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
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: userStream,
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? const <String, dynamic>{};
            final displayName = FirestoreDataMapper.userFullName(
              data,
              fallback: (user?.displayName?.trim().isNotEmpty ?? false)
                  ? user!.displayName!.trim()
                  : 'Barber',
            );
            final avatarUrl = FirestoreDataMapper.userAvatar(
              data,
              fallback: user?.photoURL ?? '',
            );
            final branchNameFromUser =
                (data['branchName'] as String?)?.trim().isNotEmpty == true
                ? (data['branchName'] as String).trim()
                : '';
            final branchId =
                (data['branchId'] as String?)?.trim().isNotEmpty == true
                ? (data['branchId'] as String).trim()
                : ((data['shopId'] as String?)?.trim().isNotEmpty == true
                      ? (data['shopId'] as String).trim()
                      : null);

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
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
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
                Center(child: _profileAvatar(avatarUrl)),
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
                  'PROFESSIONAL BARBER',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 3.0,
                  ),
                ),
                const SizedBox(height: 4),
                if (branchNameFromUser.isNotEmpty)
                  Text(
                    branchNameFromUser,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: branchId == null
                        ? null
                        : FirebaseFirestore.instance
                              .collection('shops')
                              .doc(branchId)
                              .snapshots(),
                    builder: (context, shopSnapshot) {
                      final shopData = shopSnapshot.data?.data() ?? const {};
                      final branchName =
                          ((shopData['name'] as String?)?.trim().isNotEmpty ??
                              false)
                          ? (shopData['name'] as String).trim()
                          : 'Branch';
                      return Text(
                        branchName,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              color: AppColors.gold,
                              size: 18,
                            ),
                            SizedBox(width: 2),
                            Text(
                              '4.9',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontWeight: FontWeight.w800,
                                fontSize: 22,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2),
                        Text(
                          'RATING',
                          style: TextStyle(
                            color: Color(0xFF6A7489),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    const Column(
                      children: [
                        Text(
                          '1,240',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 22,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'SESSIONS',
                          style: TextStyle(
                            color: Color(0xFF6A7489),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _sectionTitle('WORK SECTION'),
                const SizedBox(height: 10),
                _sectionPanel(
                  children: [
                    _ActionTile(
                      icon: Icons.content_cut_rounded,
                      label: 'Services I Perform',
                      onTap: () {},
                    ),
                    _ActionTile(
                      icon: Icons.event_available_rounded,
                      label: 'My Availability',
                      onTap: () {},
                    ),
                    _VacationTile(
                      enabled: _vacationMode,
                      onChanged: (v) => setState(() => _vacationMode = v),
                    ),
                    _ActionTile(
                      icon: Icons.free_breakfast_rounded,
                      label: 'Break Hours',
                      onTap: () {},
                      showDivider: false,
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _sectionTitle('PERFORMANCE'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _metricCard(
                        title: 'TODAY',
                        value: '8',
                        suffix: 'sessions',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _metricCard(
                        title: 'THIS WEEK',
                        value: '42',
                        suffix: 'sessions',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _earningsCard(),
                const SizedBox(height: 22),
                _sectionTitle('ACCOUNT SECTION'),
                const SizedBox(height: 10),
                _sectionPanel(
                  children: [
                    _ActionTile(
                      icon: Icons.person_outline,
                      label: 'Edit Profile',
                      onTap: () {},
                    ),
                    _ActionTile(
                      icon: Icons.shield_outlined,
                      label: 'Account Security',
                      onTap: () {},
                    ),
                    _ActionTile(
                      icon: Icons.settings_applications_outlined,
                      label: 'App Settings',
                      onTap: () {
                        Navigator.of(context).push(
                          Motion.pageRoute(
                            builder: (_) => const AppSettingsScreen(),
                          ),
                        );
                      },
                    ),
                    _ActionTile(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Switch Role',
                      onTap: () => RoleSwitcher.show(context),
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
        color: Colors.white.withValues(alpha: 0.42),
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
      color: const Color(0xFF0C0E12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
    child: const Icon(Icons.person, color: Colors.white70, size: 44),
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
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
              ? Border(
                  bottom: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                )
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
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.38),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _VacationTile extends StatelessWidget {
  const _VacationTile({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.beach_access_rounded,
            color: AppColors.gold,
            size: 22,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Vacation Mode',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Switch(
              value: enabled,
              onChanged: onChanged,
              activeThumbColor: AppColors.gold,
              inactiveThumbColor: const Color(0xFF9AA3B2),
              inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _metricCard({
  required String title,
  required String value,
  required String suffix,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF0C0E12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x26D4AF37),
          blurRadius: 20,
          spreadRadius: -10,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              TextSpan(
                text: ' $suffix',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _earningsCard() {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF0C0E12),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x26D4AF37),
          blurRadius: 20,
          spreadRadius: -10,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ESTIMATED EARNINGS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                r'$1,450.00',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  height: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'AVG RATING',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '4.92',
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
