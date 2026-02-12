import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/screens/account_screen.dart';
import '../../shared/data/firestore_data_mapper.dart';
import 'owner_add_barber_screen.dart';
import 'owner_add_service_screen.dart';
import 'owner_appointments_screen.dart';
import 'owner_data.dart';
import 'owner_ui.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  Future<String> _resolveShop() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return resolveShopId(user.uid);
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF05070A),
        body: Center(child: Text('Please log in again')),
      );
    }

    return FutureBuilder<String>(
      future: _resolveShop(),
      builder: (context, shopSnap) {
        if (shopSnap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF05070A),
            body: Center(
              child: CircularProgressIndicator(
                color: AppColors.gold,
                strokeWidth: 2.2,
              ),
            ),
          );
        }

        final shopId = shopSnap.data ?? '';
        if (shopId.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFF05070A),
            body: Center(child: Text('Shop not found')),
          );
        }

        return Scaffold(
          backgroundColor: OwnerUi.screenBg,
          body: Stack(
            children: [
              OwnerUi.background(),
              SafeArea(
                child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('shops')
                      .doc(shopId)
                      .snapshots(),
                  builder: (context, shopStream) {
                    if (shopStream.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Could not load dashboard now. Please try again.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      );
                    }
                    final shopData =
                        shopStream.data?.data() ?? const <String, dynamic>{};
                    final branchName = FirestoreDataMapper.branchName(
                      shopData,
                      fallback: 'AL MANSOUR BRANCH',
                    );

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 108),
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Dashboard',
                                    style: TextStyle(
                                      fontFamily: 'PlayfairDisplay',
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        branchName.toUpperCase(),
                                        style: const TextStyle(
                                          color: AppColors.gold,
                                          fontSize: 14,
                                          letterSpacing: 0.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      const Icon(
                                        Icons.expand_more,
                                        color: AppColors.gold,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            StreamBuilder<
                              DocumentSnapshot<Map<String, dynamic>>
                            >(
                              stream: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .snapshots(),
                              builder: (context, userSnap) {
                                final userData =
                                    userSnap.data?.data() ??
                                    const <String, dynamic>{};
                                final avatar = FirestoreDataMapper.userAvatar(
                                  userData,
                                  fallback: user.photoURL ?? '',
                                );
                                return InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      Motion.pageRoute(
                                        builder: (_) => const AccountScreen(),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 54,
                                    height: 54,
                                    padding: const EdgeInsets.all(1),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(
                                          alpha: 0.10,
                                        ),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.gold.withValues(
                                            alpha: 0.2,
                                          ),
                                          blurRadius: 16,
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: avatar.isNotEmpty
                                          ? Image.network(
                                              avatar,
                                              fit: BoxFit.cover,
                                            )
                                          : Container(
                                              color: const Color(0xFF1B2130),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.person,
                                                color: Colors.white70,
                                              ),
                                            ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricCard(
                                title: "TODAY'S LIST",
                                metricStream: FirebaseFirestore.instance
                                    .collection('appointments')
                                    .where('shopId', isEqualTo: shopId)
                                    .where(
                                      'status',
                                      whereIn: ['pending', 'confirmed'],
                                    )
                                    .snapshots(),
                                suffix: 'Bookings',
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _MetricCard(
                                title: 'IN SHOP',
                                metricStream: FirebaseFirestore.instance
                                    .collection('shops')
                                    .doc(shopId)
                                    .collection('barbers')
                                    .where('isActive', isEqualTo: true)
                                    .snapshots(),
                                suffix: 'Barbers',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _RevenueCard(shopId: shopId),
                        const SizedBox(height: 24),
                        Text(
                          'QUICK MANAGEMENT',
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 3,
                            color: Colors.white.withValues(alpha: 0.38),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickActionTile(
                                icon: Icons.calendar_today,
                                label: 'BOOKINGS',
                                onTap: () {
                                  Navigator.of(context).push(
                                    Motion.pageRoute(
                                      builder: (_) =>
                                          const OwnerAppointmentsScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickActionTile(
                                icon: Icons.content_cut,
                                label: 'BARBERS',
                                onTap: () {
                                  Navigator.of(context).push(
                                    Motion.pageRoute(
                                      builder: (_) =>
                                          const OwnerAddBarberScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _QuickActionTile(
                                icon: Icons.design_services_outlined,
                                label: 'SERVICES',
                                onTap: () {
                                  Navigator.of(context).push(
                                    Motion.pageRoute(
                                      builder: (_) =>
                                          const OwnerAddServiceScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Text(
                              'RECENT BOOKINGS',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 3,
                                color: Colors.white.withValues(alpha: 0.38),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  Motion.pageRoute(
                                    builder: (_) =>
                                        const OwnerAppointmentsScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                'VIEW ALL',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 11,
                                  letterSpacing: 1.8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        _RecentBookingsList(shopId: shopId),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.metricStream,
    required this.suffix,
  });

  final String title;
  final Stream<QuerySnapshot<Map<String, dynamic>>> metricStream;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: OwnerUi.panelDecoration(radius: 18, alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 10,
              letterSpacing: 1.7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: metricStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      '--',
                      style: TextStyle(
                        color: AppColors.text,
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 34,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        suffix,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                );
              }
              final value = snapshot.data?.docs.length ?? 0;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$value',
                    style: const TextStyle(
                      color: AppColors.text,
                      fontFamily: 'PlayfairDisplay',
                      fontSize: 34,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      suffix,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.62),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0E12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.06),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REVENUE TODAY',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 10,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('appointments')
                      .where('shopId', isEqualTo: shopId)
                      .where('status', whereIn: ['confirmed', 'done'])
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        '--',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 46,
                          height: 1.0,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    }
                    final docs = snapshot.data?.docs ?? const [];
                    final total = docs.fold<double>(0, (acc, doc) {
                      final p = (doc.data()['price'] as num?)?.toDouble() ?? 0;
                      return acc + p;
                    });
                    final amount = total % 1 == 0
                        ? total.toInt().toString()
                        : total.toStringAsFixed(2);
                    return Text(
                      '\$$amount',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 46,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(
              Icons.auto_graph,
              color: AppColors.gold,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 82,
            decoration: OwnerUi.panelDecoration(radius: 16, alpha: 0.10),
            child: Icon(icon, color: AppColors.gold, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 9,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RecentBookingsList extends StatelessWidget {
  const _RecentBookingsList({required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('appointments')
          .where('shopId', isEqualTo: shopId)
          .limit(3)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: OwnerUi.panelDecoration(radius: 16, alpha: 0.06),
            child: Text(
              'Could not load recent bookings',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          );
        }
        final docs =
            snapshot.data?.docs.toList() ??
            <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        docs.sort((a, b) {
          final aTs = a.data()['startAt'] as Timestamp?;
          final bTs = b.data()['startAt'] as Timestamp?;
          return (bTs?.millisecondsSinceEpoch ?? 0).compareTo(
            aTs?.millisecondsSinceEpoch ?? 0,
          );
        });

        if (docs.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: OwnerUi.panelDecoration(radius: 16, alpha: 0.06),
            child: Text(
              'No recent bookings',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data();
            final startAt = (data['startAt'] as Timestamp?)?.toDate();
            final hour = startAt == null
                ? '--:--'
                : '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}';
            final serviceName = FirestoreDataMapper.serviceName(
              data,
              fallback: 'Booking',
            );
            final barberName = FirestoreDataMapper.barberFullName(data);
            final status = ((data['status'] as String?) ?? 'upcoming')
                .toUpperCase();

            final active = status == 'CONFIRMED' || status == 'PENDING';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: OwnerUi.panelDecoration(radius: 16, alpha: 0.06),
                child: Row(
                  children: [
                    SizedBox(
                      width: 52,
                      child: Column(
                        children: [
                          Text(
                            hour,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'PM',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                              fontSize: 9,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            serviceName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Barber: $barberName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.gold.withValues(alpha: 0.12)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: active
                              ? AppColors.gold.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      child: Text(
                        active ? 'ACTIVE' : 'UPCOMING',
                        style: TextStyle(
                          color: active
                              ? AppColors.gold
                              : Colors.white.withValues(alpha: 0.55),
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
