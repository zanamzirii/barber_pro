import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/barber/barber_shell_screen.dart';
import 'features/customer/customer_shell_screen.dart';
import 'features/owner/owner_shell_screen.dart';
import 'features/superadmin/superadmin_dashboard_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final Future<void> _splashDelayFuture;
  static const Duration _minimumSplashDuration = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    _splashDelayFuture = Future<void>.delayed(_minimumSplashDuration);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _splashDelayFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SplashScreen(autoNavigate: false);
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen(autoNavigate: false);
            }

            final user = authSnapshot.data;
            if (user == null) {
              return const WelcomeScreen(
                backgroundImageAsset: 'assets/images/welcome_screen.png',
              );
            }

            return _RoleGate(uid: user.uid);
          },
        );
      },
    );
  }
}

class _RoleGate extends StatelessWidget {
  const _RoleGate({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen(autoNavigate: false);
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final Set<String> roles = <String>{};
        final legacyRole = (data['role'] as String?)?.trim().toLowerCase();
        if (legacyRole != null && legacyRole.isNotEmpty) {
          roles.add(legacyRole);
        }
        final rawRoles = data['roles'];
        if (rawRoles is List) {
          for (final value in rawRoles) {
            if (value is String && value.trim().isNotEmpty) {
              roles.add(value.trim().toLowerCase());
            }
          }
        }
        if (roles.isEmpty) {
          roles.add('customer');
        }

        final requestedActive = (data['activeRole'] as String?)
            ?.trim()
            .toLowerCase();
        final role =
            (requestedActive != null && roles.contains(requestedActive))
            ? requestedActive
            : roles.first;

        switch (role) {
          case 'superadmin':
            return const SuperAdminDashboardScreen();
          case 'owner':
            return const OwnerShellScreen();
          case 'barber':
            return const BarberShellScreen();
          case 'customer':
            return const CustomerShellScreen();

          default:
            return Scaffold(body: Center(child: Text('Unknown role: $role')));
        }
      },
    );
  }
}
