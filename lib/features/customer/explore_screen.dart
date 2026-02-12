import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      appBar: AppBar(
        title: const Text('Explore'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SearchBar(),
          SizedBox(height: 12),
          _ShopCard(
            title: 'Gilded Downtown',
            subtitle: '4.9 - 12 barbers - 1.2 km',
          ),
          SizedBox(height: 10),
          _ShopCard(
            title: 'Crown Fade Studio',
            subtitle: '4.8 - 8 barbers - 2.6 km',
          ),
          SizedBox(height: 10),
          _ShopCard(
            title: 'Sultan Grooming Lounge',
            subtitle: '4.7 - 6 barbers - 3.1 km',
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search shops, services, barbers',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: const Color(0xFF121620),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF121620),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.18),
            ),
            child: const Icon(Icons.storefront, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton(onPressed: () {}, child: const Text('View')),
        ],
      ),
    );
  }
}
