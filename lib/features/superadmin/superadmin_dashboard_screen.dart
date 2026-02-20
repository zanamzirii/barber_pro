import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';
import '../../app_shell.dart';
import '../../role_switcher.dart';
import '../../shared/screens/account_screen.dart';
import 'dart:math';
import 'package:flutter/services.dart';

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
      body: const _SuperAdminInviteOwnerPanel(),
    );
  }
}

class _SuperAdminInviteOwnerPanel extends StatefulWidget {
  const _SuperAdminInviteOwnerPanel();

  @override
  State<_SuperAdminInviteOwnerPanel> createState() =>
      _SuperAdminInviteOwnerPanelState();
}

class _SuperAdminInviteOwnerPanelState
    extends State<_SuperAdminInviteOwnerPanel> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _shopController = TextEditingController();
  final _locationController = TextEditingController();
  bool _sending = false;
  String _inviteCollection = 'invites';

  String get _pendingStatus =>
      _inviteCollection == 'invites' ? 'pending' : 'invited';

  @override
  void dispose() {
    _emailController.dispose();
    _shopController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String _code() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(8, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<String> _uniqueCode() async {
    for (var i = 0; i < 12; i++) {
      final candidate = _code();
      final exists = await FirebaseFirestore.instance
          .collection(_inviteCollection)
          .where('code', isEqualTo: candidate)
          .limit(1)
          .get();
      if (exists.docs.isEmpty) return candidate;
    }
    throw Exception('Could not generate unique invite code');
  }

  Future<bool?> _checkAccountExistsForInvite(String email) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') return null;
      rethrow;
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) throw Exception('Super-admin login required');
      final email = _emailController.text.trim().toLowerCase();
      final existing = await FirebaseFirestore.instance
          .collection(_inviteCollection)
          .where('email', isEqualTo: email)
          .where('role', isEqualTo: 'owner')
          .where('status', isEqualTo: _pendingStatus)
          .where('used', isEqualTo: false)
          .limit(20)
          .get();
      final now = DateTime.now();
      for (final doc in existing.docs) {
        final ts = doc.data()['expiresAt'] as Timestamp?;
        if (ts == null || ts.toDate().isAfter(now)) {
          final code = (doc.data()['code'] as String?) ?? '';
          await _showResult(email, code, existing: true);
          return;
        }
      }

      final code = await _uniqueCode();
      final accountExists = await _checkAccountExistsForInvite(email);
      final payload = <String, dynamic>{
        'code': code,
        'email': email,
        'role': 'owner',
        'status': _pendingStatus,
        'used': false,
        'createdBy': current.uid,
        'shopName': _shopController.text.trim(),
        'shopLocation': _locationController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 72))),
        if (accountExists != null) 'accountExists': accountExists,
      };
      await FirebaseFirestore.instance
          .collection(_inviteCollection)
          .add(payload);
      await _showResult(email, code, existing: false);
      _emailController.clear();
      _shopController.clear();
      _locationController.clear();
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied' && _inviteCollection == 'invites') {
        if (mounted) {
          setState(() {
            _inviteCollection = 'owner_invites';
          });
        }
        await _send();
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not send owner invite: [${e.code}] ${e.message}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send owner invite: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showResult(
    String email,
    String code, {
    required bool existing,
  }) async {
    if (!mounted) return;
    final link = 'barberpro://invite?code=$code';
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing ? 'Invite Already Exists' : 'Owner Invite Sent'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: $email'),
            const SizedBox(height: 8),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              link,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invite link copied'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Copy Link'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(
                  text:
                      'Owner invite\nEmail: $email\nInvite Link: $link\nUse "Have invite code?" in app and paste the link.',
                ),
              );
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invite message copied'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Copy Message'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Invite code copied'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Copy Code'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            const Text(
              'Invite Owner',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Owner Email'),
              validator: (value) {
                final email = (value ?? '').trim();
                if (email.isEmpty) return 'Email is required';
                if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _shopController,
              decoration: const InputDecoration(labelText: 'Shop Name'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Shop Location'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                child: Text(_sending ? 'SENDING...' : 'SEND OWNER INVITE'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
