import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../app_shell.dart';
import '../../theme/app_colors.dart';

class BarberInviteRegisterScreen extends StatefulWidget {
  const BarberInviteRegisterScreen({super.key});

  @override
  State<BarberInviteRegisterScreen> createState() =>
      _BarberInviteRegisterScreenState();
}

class _BarberInviteRegisterScreenState
    extends State<BarberInviteRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _specialtyController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _alreadyHaveAccount = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _validateCode(String? value) {
    final code = (value ?? '').trim();
    if (code.isEmpty) return 'Invite code is required';
    if (code.length < 6) return 'Enter a valid invite code';
    return null;
  }

  String? _validateName(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Full name is required';
    if (name.length < 2) return 'Enter your full name';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = (value ?? '').trim();
    if (email.isEmpty) return 'Email is required';
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailPattern.hasMatch(email)) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Password is required';
    if (password.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
      return 'Include at least one letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Include at least one number';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(password)) {
      return 'Include at least one symbol';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (_alreadyHaveAccount) return null;
    if ((value ?? '').isEmpty) return 'Confirm your password';
    if (value != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _getInviteByCode(
    String code,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection('barber_invites')
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception('Invalid invite code');
    }
    return snap.docs.first;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
    });

    final code = _codeController.text.trim().toUpperCase();
    final email = _emailController.text.trim().toLowerCase();

    try {
      UserCredential credential;
      if (_alreadyHaveAccount) {
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );
      } else {
        credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: _passwordController.text,
        );
      }

      final user = credential.user;
      if (user == null) throw Exception('Could not authenticate user');

      final inviteDoc = await _getInviteByCode(code);
      final inviteData = inviteDoc.data() ?? {};

      final status = (inviteData['status'] as String?)?.trim().toLowerCase();
      if (status != 'invited') {
        throw Exception('Invite already used or invalid');
      }

      final invitedEmail = (inviteData['email'] as String?)
          ?.trim()
          .toLowerCase();
      if (invitedEmail == null || invitedEmail != email) {
        throw Exception('This email does not match invite');
      }

      final expiresAt = inviteData['expiresAt'] as Timestamp?;
      if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
        throw Exception('Invite code expired');
      }

      final fullName = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final specialty = _specialtyController.text.trim();
      final shopId = (inviteData['shopId'] as String?) ?? '';
      final ownerId = (inviteData['ownerId'] as String?) ?? '';

      await user.updateDisplayName(fullName);
      if (!_alreadyHaveAccount) {
        await user.sendEmailVerification();
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'roles': FieldValue.arrayUnion(<String>['customer', 'barber']),
        'activeRole': 'barber',
        'role': 'barber',
        'shopId': shopId,
        'ownerId': ownerId,
        'inviteId': inviteDoc.id,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('barbers')
          .doc(user.uid)
          .set({
            'barberId': user.uid,
            'barberUserId': user.uid,
            'shopId': shopId,
            'ownerId': ownerId,
            'name': fullName,
            'email': email,
            'phone': phone,
            'specialty': specialty,
            'status': 'active',
            'isActive': true,
            'updatedAt': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      await inviteDoc.reference.update({
        'status': 'used',
        'claimedBy': user.uid,
        'claimedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_mapAuthError(e)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email already has an account. Turn on "I already have account".';
      case 'invalid-email':
        return 'Email address is not valid';
      case 'weak-password':
        return 'Password is too weak';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid existing account email/password';
      case 'network-request-failed':
        return 'Network error. Check internet, VPN, and phone date/time';
      default:
        return '[${e.code}] ${e.message ?? 'Registration failed'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.midnight,
      appBar: AppBar(title: const Text('Join as Barber')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Accept Invite',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'PlayfairDisplay',
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'New barber or existing barber from another branch can join here.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('I already have barber account'),
                  value: _alreadyHaveAccount,
                  onChanged: (v) {
                    setState(() {
                      _alreadyHaveAccount = v;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  validator: _validateCode,
                  decoration: const InputDecoration(labelText: 'Invite Code'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  validator: _validateName,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _specialtyController,
                  decoration: const InputDecoration(labelText: 'Specialty'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textCapitalization: TextCapitalization.none,
                  validator: _validateEmail,
                  decoration: const InputDecoration(labelText: 'Invite Email'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  validator: _validatePassword,
                  decoration: InputDecoration(
                    labelText: _alreadyHaveAccount
                        ? 'Current Password'
                        : 'Password',
                    suffixIcon: IconButton(
                      onPressed: () => setState(() {
                        _obscurePassword = !_obscurePassword;
                      }),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                    ),
                  ),
                ),
                if (!_alreadyHaveAccount) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    validator: _validateConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() {
                          _obscureConfirm = !_obscureConfirm;
                        }),
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: Text(
                      _submitting
                          ? 'Processing...'
                          : _alreadyHaveAccount
                          ? 'Join Branch'
                          : 'Create Account & Join',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
