import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.shellBackground,
      appBar: AppBar(
        title: const Text('Chat'),
        backgroundColor: AppColors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ChatTile(
            name: 'Gilded Downtown',
            preview: 'Your appointment is confirmed.',
            time: '2m',
          ),
          SizedBox(height: 10),
          _ChatTile(
            name: 'Julian Vance',
            preview: 'See you at 5:00 PM tomorrow.',
            time: '1h',
          ),
          SizedBox(height: 10),
          _ChatTile(
            name: 'Support',
            preview: 'How can we help you today?',
            time: 'Yesterday',
          ),
        ],
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({
    required this.name,
    required this.preview,
    required this.time,
  });

  final String name;
  final String preview;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.onDark08),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.2),
            ),
            child: const Icon(Icons.chat_bubble, color: AppColors.gold),
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  preview,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
