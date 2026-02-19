import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'invite_code_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.backgroundImageAsset});

  final String? backgroundImageAsset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: AppColors.midnight,
      body: MediaQuery.removeViewInsets(
        removeBottom: true,
        context: context,
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  image: backgroundImageAsset == null
                      ? null
                      : DecorationImage(
                          image: AssetImage(backgroundImageAsset!),
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                        ),
                ),
              ),
            ),
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x660B0F1A),
                      Color(0xCC0B0F1A),
                      Color(0xFF0B0F1A),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                child: Column(
                  children: [
                    const SizedBox(height: 24),
                    const Icon(
                      Icons.content_cut,
                      size: 36,
                      color: AppColors.gold,
                    ),
                    const SizedBox(height: 18),
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 36,
                          height: 1.1,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'PlayfairDisplay',
                          color: AppColors.text,
                        ),
                        children: [
                          TextSpan(text: 'Welcome to\n'),
                          TextSpan(
                            text: 'Barber Shop\n',
                            style: TextStyle(color: AppColors.gold),
                          ),
                          TextSpan(text: 'Management'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: 48,
                      height: 1,
                      color: AppColors.gold.withValues(alpha: 0.4),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gold,
                          foregroundColor: AppColors.midnight,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          Motion.pageRoute(
                            builder: (_) => const LoginScreen(
                              headerImageAsset: 'assets/images/login_screen.png',
                            ),
                          ),
                        ),
                        child: const Text('LOGIN'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gold,
                          side: BorderSide(
                            color: AppColors.gold.withValues(alpha: 0.6),
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).push(
                          Motion.pageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                        child: const Text('CREATE ACCOUNT'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        Motion.pageRoute(
                          builder: (_) => const InviteCodeScreen(),
                        ),
                      ),
                      child: Text.rich(
                        TextSpan(
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                          children: const [
                            TextSpan(text: 'Barber/Owner? '),
                            TextSpan(
                              text: 'Enter invite code',
                              style: TextStyle(
                                color: AppColors.gold,
                                decoration: TextDecoration.underline,
                                decorationColor: AppColors.gold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Transform.translate(
                      offset: const Offset(0, 10),
                      child: TextButton(
                        onPressed: () => _showSupportOptions(context),
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.5),
                              fontFamily: 'Inter',
                            ),
                            children: const [
                              TextSpan(text: 'Need help? '),
                              TextSpan(
                                text: 'Contact support',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSupportOptions(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121620),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.email_outlined,
                    color: AppColors.gold,
                  ),
                  title: const Text(
                    'Email Support',
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Open your mail app with support email',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Future<void>.delayed(
                      const Duration(milliseconds: 220),
                    );
                    if (!context.mounted) return;
                    await _openEmailSupport(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.help_center_outlined,
                    color: AppColors.gold,
                  ),
                  title: const Text(
                    'Help Center / FAQ',
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Common invite and email issues',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Future<void>.delayed(
                      const Duration(milliseconds: 220),
                    );
                    if (!context.mounted) return;
                    await _showFaqSheet(context);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.bug_report_outlined,
                    color: AppColors.gold,
                  ),
                  title: const Text(
                    'Report a problem',
                    style: TextStyle(
                      color: AppColors.text,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Issue type, message, screenshot (optional)',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Future<void>.delayed(
                      const Duration(milliseconds: 220),
                    );
                    if (!context.mounted) return;
                    await _showReportProblemSheet(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openEmailSupport(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@barberpro.app',
      queryParameters: {'subject': 'BarberPro Support Request'},
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open email app. Use: support@barberpro.app'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showFaqSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF121620),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        Widget item(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 3),
                child: Icon(Icons.circle, size: 7, color: AppColors.gold),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        );

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Help Center / FAQ',
                  style: TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    color: AppColors.text,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                item('Didn\'t receive code'),
                item('Wrong email'),
                item('Invite code not working'),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showReportProblemSheet(BuildContext context) async {
    final messageController = TextEditingController();
    final screenshotController = TextEditingController();
    var selectedIssue = 'Invite code not working';
    var attachScreenshot = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFF121620),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final media = MediaQuery.of(context);
            return GestureDetector(
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              behavior: HitTestBehavior.translucent,
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeInOut,
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Report a problem',
                              style: TextStyle(
                                fontFamily: 'PlayfairDisplay',
                                color: AppColors.text,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.text,
                            ),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedIssue,
                        dropdownColor: const Color(0xFF121620),
                        style: const TextStyle(color: AppColors.text),
                        decoration: const InputDecoration(
                          labelText: 'Issue type',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Invite code not working',
                            child: Text('Invite code not working'),
                          ),
                          DropdownMenuItem(
                            value: 'Wrong email',
                            child: Text('Wrong email'),
                          ),
                          DropdownMenuItem(
                            value: 'Didn\'t receive code',
                            child: Text('Didn\'t receive code'),
                          ),
                          DropdownMenuItem(
                            value: 'Other',
                            child: Text('Other'),
                          ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() => selectedIssue = value);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: messageController,
                        maxLines: 4,
                        style: const TextStyle(color: AppColors.text),
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          hintText: 'Describe what happened...',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: attachScreenshot,
                        activeThumbColor: AppColors.gold,
                        title: const Text(
                          'Attach screenshot (optional)',
                          style: TextStyle(color: AppColors.text, fontSize: 13),
                        ),
                        onChanged: (value) {
                          setSheetState(() => attachScreenshot = value);
                        },
                      ),
                      if (attachScreenshot) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: screenshotController,
                          style: const TextStyle(color: AppColors.text),
                          decoration: const InputDecoration(
                            labelText: 'Screenshot note (optional)',
                            hintText: 'e.g. Error shown on owner setup screen',
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            final message = messageController.text.trim();
                            if (message.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please enter a message'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }

                            final uri = Uri(
                              scheme: 'mailto',
                              path: 'support@barberpro.app',
                              queryParameters: {
                                'subject': 'Report: $selectedIssue',
                                'body':
                                    'Issue: $selectedIssue\n\nMessage:\n$message\n\nScreenshot note: ${screenshotController.text.trim()}',
                              },
                            );
                            final launched = await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                            if (!launched && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not open email app. Use: support@barberpro.app',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                            if (context.mounted) {
                              Navigator.of(sheetContext).pop();
                            }
                          },
                          child: const Text('SEND REPORT'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.of(sheetContext).pop(),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                            ),
                          ),
                        ),
                      ),
                      // Extra breathing room above the keyboard on smaller devices.
                      SizedBox(height: media.viewInsets.bottom > 0 ? 8 : 0),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    messageController.dispose();
    screenshotController.dispose();
  }
}
