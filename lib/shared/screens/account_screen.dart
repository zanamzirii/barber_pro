import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';

import '../../app_shell.dart';
import '../../role_switcher.dart';
import '../../core/theme/app_colors.dart';
import 'app_settings_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim().isNotEmpty == true
        ? user!.displayName!
        : 'User';
    final email = user?.email ?? '-';

    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF121620),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.gold.withValues(alpha: 0.2),
                  ),
                  child: const Icon(Icons.person, color: AppColors.gold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (user != null)
            FutureBuilder<List<String>>(
              future: RoleSwitcher.availableRolesForCurrentUser(),
              builder: (context, snapshot) {
                final roles = snapshot.data ?? const <String>[];
                if (roles.length <= 1) return const SizedBox.shrink();
                return ListTile(
                  onTap: () => RoleSwitcher.show(context),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 2),
                  leading: const Icon(Icons.swap_horiz, color: AppColors.gold),
                  title: const Text(
                    'Switch Role',
                    style: TextStyle(color: AppColors.text),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                );
              },
            ),
          ListTile(
            onTap: () => Navigator.of(
              context,
            ).push(Motion.pageRoute(builder: (_) => const AppSettingsScreen())),
            contentPadding: const EdgeInsets.symmetric(horizontal: 2),
            leading: const Icon(Icons.settings_outlined, color: AppColors.gold),
            title: const Text(
              'App Settings',
              style: TextStyle(color: AppColors.text),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  Motion.pageRoute(builder: (_) => const AppShell()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),
        ],
      ),
    );
  }
}
