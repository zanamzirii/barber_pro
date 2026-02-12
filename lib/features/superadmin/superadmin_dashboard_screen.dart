import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';
import '../../app_shell.dart';
import '../../role_switcher.dart';
import '../../shared/screens/account_screen.dart';

class SuperAdminDashboardScreen extends StatelessWidget {
  const SuperAdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Super Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(Motion.pageRoute(builder: (_) => const AccountScreen()));
            },
            icon: const Icon(Icons.person_outline),
            tooltip: 'Account',
          ),
          IconButton(
            onPressed: () => RoleSwitcher.show(context),
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch Role',
          ),
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                Motion.pageRoute(builder: (_) => const AppShell()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: const Center(child: Text('Super admin platform placeholder')),
    );
  }
}
