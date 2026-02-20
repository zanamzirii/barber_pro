import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'core/auth/pending_onboarding_service.dart';
import 'core/auth/user_role_service.dart';
import 'features/auth/splash_screen.dart';
import 'features/auth/verify_email_screen.dart';
import 'features/auth/welcome_screen.dart';
import 'features/barber/barber_shell_screen.dart';
import 'features/customer/customer_shell_screen.dart';
import 'features/owner/owner_shell_screen.dart';
import 'features/superadmin/superadmin_dashboard_screen.dart';
import 'core/theme/app_colors.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final Future<void> _splashDelayFuture;
  static const Duration _minimumSplashDuration = Duration(milliseconds: 750);
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
          return const SplashScreen(
            autoNavigate: false,
            progress: 0.28,
            statusText: 'Starting app...',
          );
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, authSnapshot) {
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen(
                autoNavigate: false,
                progress: 0.52,
                statusText: 'Checking session...',
              );
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
              _ensureIdentityFuture = _prepareVerifiedIdentity(user);
            }

            return FutureBuilder<void>(
              future: _ensureIdentityFuture,
              builder: (context, ensureSnapshot) {
                if (ensureSnapshot.connectionState != ConnectionState.done) {
                  return const SplashScreen(
                    autoNavigate: false,
                    progress: 0.78,
                    statusText: 'Preparing account...',
                  );
                }
                if (ensureSnapshot.hasError) {
                  return _AuthBootstrapErrorScreen(
                    message: ensureSnapshot.error.toString(),
                    onRetry: () {
                      setState(() {
                        _ensureIdentityFuture = _prepareVerifiedIdentity(user);
                      });
                    },
                  );
                }
                return _RoleGate(uid: user.uid);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _prepareVerifiedIdentity(User user) async {
    // Always finalize pending invite/registration work first (if any),
    // then ensure the identity doc exists.
    await _finalizeWithRetry();
    await UserRoleService.ensureIdentityDoc(user);
  }

  Future<void> _finalizeWithRetry() async {
    var delayMs = 350;
    Object? lastError;
    for (var i = 0; i < 3; i++) {
      try {
        await PendingOnboardingService.finalizeForCurrentUser();
        return;
      } on FirebaseException catch (e) {
        lastError = e;
        final transient =
            e.code == 'unavailable' ||
            e.code == 'aborted' ||
            e.code == 'deadline-exceeded';
        if (!transient || i == 2) rethrow;
      } catch (e) {
        lastError = e;
        if (i == 2) rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: delayMs));
      delayMs *= 2;
    }
    if (lastError != null) throw lastError;
  }
}

class _AuthBootstrapErrorScreen extends StatelessWidget {
  const _AuthBootstrapErrorScreen({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: const Color(0xFF070A12),
      body: MediaQuery.removeViewInsets(
        removeBottom: true,
        context: context,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  const Text(
                    'Account setup failed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.onDark70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleGate extends StatefulWidget {
  const _RoleGate({required this.uid});

  final String uid;

  @override
  State<_RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<_RoleGate> {
  Future<Set<String>>? _rolesFuture;
  String? _rolesFutureSignature;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen(
            autoNavigate: false,
            progress: 0.92,
            statusText: 'Loading dashboard...',
          );
        }

        final data = snapshot.data?.data() ?? <String, dynamic>{};
        final fallbackRoles = UserRoleService.extractRoles(data);
        final fallbackRole = _pickRole(data, fallbackRoles);
        final signature = _rolesSignature(data);
        if (_rolesFuture == null || _rolesFutureSignature != signature) {
          _rolesFutureSignature = signature;
          _rolesFuture = UserRoleService.inferRolesForUser(
            widget.uid,
            data,
          ).timeout(const Duration(seconds: 6), onTimeout: () => fallbackRoles);
        }
        return FutureBuilder<Set<String>>(
          future: _rolesFuture,
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

  String _rolesSignature(Map<String, dynamic> data) {
    return <Object?>[
      widget.uid,
      data['role'],
      data['activeRole'],
      data['roles'],
      data['branchId'],
      data['shopId'],
      data['selectedShopId'],
      data['updatedAt'],
    ].join('|');
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
