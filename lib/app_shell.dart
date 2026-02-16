import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'core/auth/user_role_service.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/verify_email_screen.dart';
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
  String? _ensuredUid;
  Future<void>? _ensureIdentityFuture;

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
              _ensuredUid = null;
              _ensureIdentityFuture = null;
              return const WelcomeScreen(
                backgroundImageAsset: 'assets/images/welcome_screen.png',
              );
            }

            if (!user.emailVerified) {
              _ensuredUid = null;
              _ensureIdentityFuture = null;
              return VerifyEmailScreen(email: user.email ?? '');
            }

            if (_ensuredUid != user.uid || _ensureIdentityFuture == null) {
              _ensuredUid = user.uid;
              _ensureIdentityFuture = UserRoleService.ensureIdentityDoc(user);
            }

            return FutureBuilder<void>(
              future: _ensureIdentityFuture,
              builder: (context, ensureSnapshot) {
                if (ensureSnapshot.connectionState != ConnectionState.done) {
                  return const SplashScreen(autoNavigate: false);
                }
                return _RoleGate(uid: user.uid);
              },
            );
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
        final fallbackRoles = UserRoleService.extractRoles(data);
        final fallbackRole = _pickRole(data, fallbackRoles);
        return FutureBuilder<Set<String>>(
          future: UserRoleService.inferRolesForUser(
            uid,
            data,
          ).timeout(const Duration(seconds: 6), onTimeout: () => fallbackRoles),
          builder: (context, rolesSnapshot) {
            if (rolesSnapshot.connectionState == ConnectionState.waiting ||
                rolesSnapshot.hasError) {
              return _shellForRole(fallbackRole);
            }

            final roles = rolesSnapshot.data ?? fallbackRoles;
            return _shellForRole(_pickRole(data, roles));
          },
        );
      },
    );
  }

  String _pickRole(Map<String, dynamic> data, Set<String> roles) {
    final safeRoles = roles.isEmpty ? const <String>{'customer'} : roles;
    final requestedActive = (data['activeRole'] as String?)
        ?.trim()
        .toLowerCase();
    if (requestedActive != null && safeRoles.contains(requestedActive)) {
      return requestedActive;
    }
    final legacyRole = (data['role'] as String?)?.trim().toLowerCase();
    if (legacyRole != null &&
        safeRoles.contains(legacyRole) &&
        (legacyRole != 'customer' ||
            (safeRoles.length == 1 && safeRoles.contains('customer')))) {
      return legacyRole;
    }
    if (safeRoles.contains('superadmin')) return 'superadmin';
    if (safeRoles.contains('owner')) return 'owner';
    if (safeRoles.contains('barber')) return 'barber';
    return 'customer';
  }

  Widget _shellForRole(String role) {
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
        return const CustomerShellScreen();
    }
  }
}
