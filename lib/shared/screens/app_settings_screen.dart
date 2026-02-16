import 'package:barber_pro/app_shell.dart';
import 'package:barber_pro/core/auth/account_deletion_service.dart';
import 'package:barber_pro/core/motion.dart';
import 'package:barber_pro/core/theme/app_colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  final TextEditingController _passwordController = TextEditingController();
  bool _deleting = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121620),
          title: const Text(
            'Delete Account?',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Warning: deleting your account will permanently delete your full account and all linked role access. This cannot be undone.',
            style: TextStyle(color: AppColors.muted, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Continue',
                style: TextStyle(color: Color(0xFFEF4444)),
              ),
            ),
          ],
        );
      },
    );

    if (proceed != true || !mounted) return;
    _passwordController.clear();

    final passwordOk = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C0E12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            20 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Confirm Password',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'For security, enter your account password to permanently delete your account.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: const TextStyle(color: AppColors.text),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: const TextStyle(color: AppColors.muted),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    final p = _passwordController.text.trim();
                    if (p.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Enter your password')),
                      );
                      return;
                    }
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'DELETE MY ACCOUNT',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (passwordOk != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await AccountDeletionService.deleteCurrentUserCompletely(
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        Motion.pageRoute(builder: (_) => const AppShell()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      var message = '[${e.code}] ${e.message ?? 'Delete failed'}';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        message = 'Wrong password. Please try again.';
      } else if (e.code == 'requires-recent-login') {
        message =
            'For security, log out and log in again, then retry account deletion.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete account: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      appBar: AppBar(
        title: const Text('App Settings'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const _SettingsSectionLabel('GENERAL'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0C0E12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.notifications_none_rounded,
                  label: 'Notifications',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Notifications settings coming soon'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.lock_outline_rounded,
                  label: 'Privacy',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Privacy settings coming soon'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  icon: Icons.language_rounded,
                  label: 'Language',
                  showDivider: false,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Language settings coming soon'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const _SettingsSectionLabel('ACCOUNT'),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0C0E12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              children: [
                _SettingsTile(
                  icon: Icons.delete_forever_rounded,
                  iconColor: const Color(0xFFEF4444),
                  label: _deleting ? 'Deleting account...' : 'Delete Account',
                  labelColor: const Color(0xFFFFB4B4),
                  subtitle:
                      'Warning: full account will be permanently deleted for all roles.',
                  subtitleColor: const Color(0x66FFB4B4),
                  showDivider: false,
                  onTap: _deleting ? null : _confirmDeleteAccount,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSectionLabel extends StatelessWidget {
  const _SettingsSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.42),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 2.0,
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor = AppColors.gold,
    this.labelColor = AppColors.text,
    this.subtitle,
    this.subtitleColor,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color iconColor;
  final Color labelColor;
  final String? subtitle;
  final Color? subtitleColor;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
            Icon(icon, color: iconColor, size: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: subtitleColor ?? AppColors.muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
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
