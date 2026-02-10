import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'owner_data.dart';

class OwnerAddBarberScreen extends StatefulWidget {
  const OwnerAddBarberScreen({super.key});

  @override
  State<OwnerAddBarberScreen> createState() => _OwnerAddBarberScreenState();
}

class _OwnerAddBarberScreenState extends State<OwnerAddBarberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _saving = false;
  late final Future<String> _shopIdFuture;

  @override
  void initState() {
    super.initState();
    _shopIdFuture = _resolveOwnerShopId();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<String> _resolveOwnerShopId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return resolveAndEnsureShopId(user.uid);
  }

  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    return List.generate(8, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String _buildInviteMessage({required String code, required String email}) {
    return 'You are invited as a barber in BarberPro.\n'
        'Email: $email\n'
        'Invite Code: $code\n\n'
        'If you are new: open app -> Join as Barber -> Create account\n'
        'If you already have barber account: open app -> Join as Barber -> I already have account.';
  }

  Future<void> _copyInviteMessage(
    BuildContext context,
    String code,
    String email,
  ) async {
    final inviteMessage = _buildInviteMessage(code: code, email: email);
    await Clipboard.setData(ClipboardData(text: inviteMessage));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite message copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendInvite() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _saving = true;
    });

    try {
      final shopId = await resolveAndEnsureShopId(user.uid);
      final email = _emailController.text.trim().toLowerCase();
      final inviteCode = _generateInviteCode();

      await FirebaseFirestore.instance.collection('barber_invites').add({
        'code': inviteCode,
        'email': email,
        'ownerId': user.uid,
        'shopId': shopId,
        'status': 'invited',
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 14)),
        ),
      });

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Invite Sent'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Email: $email'),
                const SizedBox(height: 6),
                Text('Invite code: $inviteCode'),
                const SizedBox(height: 12),
                const Text(
                  'Send this to barber:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _buildInviteMessage(code: inviteCode, email: email),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => _copyInviteMessage(context, inviteCode, email),
                child: const Text('Copy Invite'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );

      _emailController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send invite: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _cancelInvite(BuildContext context, String inviteId) async {
    try {
      await FirebaseFirestore.instance
          .collection('barber_invites')
          .doc(inviteId)
          .update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invite cancelled'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not cancel invite: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleBarberActive(
    BuildContext context,
    String shopId,
    String docId,
    bool nextValue,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('barbers')
          .doc(docId)
          .update({
            'isActive': nextValue,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(nextValue ? 'Barber activated' : 'Barber deactivated'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not update barber status: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteBarber(
    BuildContext context,
    String shopId,
    String docId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('barbers')
          .doc(docId)
          .delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Barber removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not remove barber: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Barbers')),
      body: FutureBuilder<String>(
        future: _shopIdFuture,
        builder: (context, shopSnapshot) {
          if (shopSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final shopId = shopSnapshot.data ?? '';
          if (shopId.isEmpty) {
            return const Center(child: Text('No shop assigned'));
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Barber Email',
                          helperText: 'Send invite by email code flow.',
                        ),
                        validator: (v) {
                          final email = (v ?? '').trim();
                          if (email.isEmpty) return 'Email is required';
                          final emailPattern = RegExp(
                            r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                          );
                          if (!emailPattern.hasMatch(email)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _sendInvite,
                          child: Text(_saving ? 'Sending...' : 'Send Invite'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Pending Invites',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 170,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('barber_invites')
                        .where('shopId', isEqualTo: shopId)
                        .where('status', isEqualTo: 'invited')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No pending invites'));
                      }

                      final docs = snapshot.data!.docs.toList();
                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final email = (data['email'] as String?) ?? '';
                          final code = (data['code'] as String?) ?? '';
                          return ListTile(
                            title: Text(email),
                            subtitle: Text('Code: $code'),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () =>
                                      _copyInviteMessage(context, code, email),
                                  child: const Text('Copy Invite'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _cancelInvite(context, doc.id),
                                  child: const Text('Cancel'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Active Barbers',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('shops')
                        .doc(shopId)
                        .collection('barbers')
                        .limit(200)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No barbers yet'));
                      }

                      final docs = snapshot.data!.docs.toList();
                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final docId = docs[index].id;
                          final data = docs[index].data();
                          final name = (data['name'] as String?) ?? 'Unnamed';
                          final email = (data['email'] as String?) ?? '-';
                          final specialty =
                              (data['specialty'] as String?) ?? '-';
                          final isActive = (data['isActive'] as bool?) ?? true;

                          return ListTile(
                            title: Text(name),
                            subtitle: Text('$email\n$specialty'),
                            isThreeLine: true,
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () => _toggleBarberActive(
                                    context,
                                    shopId,
                                    docId,
                                    !isActive,
                                  ),
                                  child: Text(
                                    isActive ? 'Deactivate' : 'Activate',
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _deleteBarber(context, shopId, docId),
                                  child: const Text('Remove'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
