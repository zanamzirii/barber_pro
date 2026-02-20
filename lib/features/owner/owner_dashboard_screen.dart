import 'package:barber_pro/core/motion.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/data/firestore_data_mapper.dart';
import '../../shared/screens/account_screen.dart';
import 'owner_staff_screen.dart';
import 'owner_add_service_screen.dart';
import 'owner_appointments_screen.dart';
import 'owner_data.dart';

const Color _ownerGold = AppColors.gold;
const Color _ownerBg = AppColors.midnight;
const Color _ownerCard = AppColors.ownerDashboardCard;
const double _screenHInset = 24;
const double _gridGap = 12;
const double _sectionGap = 18;
const double _cardRadius = 18;
const double _snapshotCardHeight = 110;
const double _actionCardHeight = 110;

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

  void _showComingSoon(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final noScaleMedia = MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(1.0));
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return MediaQuery(
        data: noScaleMedia,
        child: const Scaffold(
          backgroundColor: _ownerBg,
          body: Center(
            child: Text(
              'Please log in again',
              style: TextStyle(color: AppColors.onDark70),
            ),
          ),
        ),
      );
    }

    return MediaQuery(
      data: noScaleMedia,
      child: FutureBuilder<String>(
        future: _resolveShop(),
        builder: (context, shopSnap) {
          if (shopSnap.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              backgroundColor: _ownerBg,
              body: Center(child: CircularProgressIndicator(color: _ownerGold)),
            );
          }

          final shopId = shopSnap.data ?? '';
          if (shopId.isEmpty) {
            return const Scaffold(
              backgroundColor: _ownerBg,
              body: Center(
                child: Text(
                  'Shop not found',
                  style: TextStyle(color: AppColors.onDark70),
                ),
              ),
            );
          }

          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('shops')
                .doc(shopId)
                .snapshots(),
            builder: (context, shopStream) {
              final shopData =
                  shopStream.data?.data() ?? const <String, dynamic>{};
              final branchName = FirestoreDataMapper.branchName(
                shopData,
                fallback: 'AL MANSOUR BRANCH',
              );

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('appointments')
                    .where('shopId', isEqualTo: shopId)
                    .limit(300)
                    .snapshots(),
                builder: (context, appointmentStream) {
                  if (appointmentStream.connectionState ==
                      ConnectionState.waiting) {
                    return const Scaffold(
                      backgroundColor: _ownerBg,
                      body: Center(
                        child: CircularProgressIndicator(color: _ownerGold),
                      ),
                    );
                  }

                  if (appointmentStream.hasError) {
                    return const Scaffold(
                      backgroundColor: _ownerBg,
                      body: Center(
                        child: Text(
                          'Could not load dashboard now',
                          style: TextStyle(color: AppColors.onDark70),
                        ),
                      ),
                    );
                  }

                  final appointmentDocs =
                      appointmentStream.data?.docs ?? const [];
                  final stats = _OwnerOverviewStats.fromDocs(appointmentDocs);

                  return Scaffold(
                    backgroundColor: _ownerBg,
                    body: Stack(
                      children: [
                        const _OverviewBackground(),
                        SafeArea(
                          child: Column(
                            children: [
                              _OverviewHeader(
                                branchName: branchName,
                                userId: user.uid,
                                fallbackAvatar: user.photoURL ?? '',
                              ),
                              Expanded(
                                child: ListView(
                                  padding: const EdgeInsets.fromLTRB(
                                    _screenHInset,
                                    14,
                                    _screenHInset,
                                    108,
                                  ),
                                  children: [
                                    _SectionHeader(label: 'TODAY SNAPSHOT'),
                                    const SizedBox(height: _gridGap),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _SnapshotCard(
                                            icon: Icons.calendar_today_outlined,
                                            value: '${stats.todayBookings}',
                                            label: "TODAY'S BOOKINGS",
                                          ),
                                        ),
                                        const SizedBox(width: _gridGap),
                                        Expanded(
                                          child:
                                              StreamBuilder<
                                                QuerySnapshot<
                                                  Map<String, dynamic>
                                                >
                                              >(
                                                stream: FirebaseFirestore
                                                    .instance
                                                    .collection('shops')
                                                    .doc(shopId)
                                                    .collection('barbers')
                                                    .where(
                                                      'isActive',
                                                      isEqualTo: true,
                                                    )
                                                    .snapshots(),
                                                builder:
                                                    (context, barbersSnap) {
                                                      final count =
                                                          barbersSnap
                                                              .data
                                                              ?.docs
                                                              .length ??
                                                          0;
                                                      return _SnapshotCard(
                                                        icon: Icons.content_cut,
                                                        value: '$count',
                                                        label: 'ON DUTY',
                                                      );
                                                    },
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: _gridGap),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _SnapshotCard(
                                            icon: Icons.payments_outlined,
                                            value: stats.revenueLabel,
                                            label: 'REVENUE TODAY',
                                          ),
                                        ),
                                        const SizedBox(width: _gridGap),
                                        Expanded(
                                          child: _SnapshotCard(
                                            icon: Icons.schedule,
                                            value: stats.nextTime,
                                            label:
                                                'NEXT: ${stats.nextCustomer}',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: _sectionGap),
                                    const _SectionHeader(
                                      label: 'QUICK ACTIONS',
                                    ),
                                    const SizedBox(height: _gridGap),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _QuickActionCard(
                                            icon: Icons.add,
                                            label: 'Add Booking',
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
                                        const SizedBox(width: _gridGap),
                                        Expanded(
                                          child: _QuickActionCard(
                                            icon:
                                                Icons.person_add_alt_1_rounded,
                                            label: 'Invite Staff',
                                            onTap: () {
                                              Navigator.of(context).push(
                                                Motion.pageRoute(
                                                  builder: (_) =>
                                                      const OwnerStaffScreen(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: _gridGap),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _QuickActionCard(
                                            icon: Icons.list_alt_rounded,
                                            label: 'Edit Services',
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
                                        const SizedBox(width: _gridGap),
                                        Expanded(
                                          child: _QuickActionCard(
                                            icon: Icons.more_time_outlined,
                                            label: 'Business Hours',
                                            onTap: () {
                                              _showComingSoon(
                                                'Business hours screen coming soon',
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: _sectionGap),
                                    const _SectionHeader(
                                      label: 'UPCOMING FEED',
                                    ),
                                    const SizedBox(height: _gridGap),
                                    _UpcomingFeedCard(items: stats.upcoming),
                                    const SizedBox(height: 16),
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
                                        'VIEW ALL BOOKINGS',
                                        style: TextStyle(
                                          color: _ownerGold,
                                          fontSize: 12,
                                          letterSpacing: 1.2,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _OverviewBackground extends StatelessWidget {
  const _OverviewBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.midnight,
            AppColors.ownerDashboardGradientMid,
            AppColors.midnight,
          ],
        ),
      ),
    );
  }
}

class _OverviewHeader extends StatelessWidget {
  const _OverviewHeader({
    required this.branchName,
    required this.userId,
    required this.fallbackAvatar,
  });

  final String branchName;
  final String userId;
  final String fallbackAvatar;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(_screenHInset, 4, _screenHInset, 6),
      decoration: BoxDecoration(
        color: _ownerBg.withValues(alpha: 0.92),
        border: Border(
          bottom: BorderSide(color: _ownerGold.withValues(alpha: 0.20)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontFamily: 'PlayfairDisplay',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 0),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        branchName.toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ownerGold,
                          fontSize: 10,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.expand_more, color: _ownerGold, size: 20),
                  ],
                ),
              ],
            ),
          ),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(userId)
                .snapshots(),
            builder: (context, userSnap) {
              final userData =
                  userSnap.data?.data() ?? const <String, dynamic>{};
              final avatar = FirestoreDataMapper.userAvatar(
                userData,
                fallback: fallbackAvatar,
              );

              return InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  Navigator.of(context).push(
                    Motion.pageRoute(builder: (_) => const AccountScreen()),
                  );
                },
                child: Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _ownerGold, width: 2),
                  ),
                  child: ClipOval(
                    child: avatar.isNotEmpty
                        ? Image.network(avatar, fit: BoxFit.cover)
                        : Container(
                            color: AppColors.panel,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.person,
                              color: AppColors.onDark70,
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.onDark46,
            fontSize: 10,
            letterSpacing: 4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
      ],
    );
  }
}

class _SnapshotCard extends StatelessWidget {
  const _SnapshotCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _snapshotCardHeight,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _ownerCard,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: AppColors.onDark10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _ownerGold, size: 25),
          const Spacer(),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.onDark58,
              fontSize: 11,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: _actionCardHeight,
        decoration: BoxDecoration(
          color: _ownerCard,
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: _ownerGold.withValues(alpha: 0.42)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _ownerGold, size: 25),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingFeedCard extends StatelessWidget {
  const _UpcomingFeedCard({required this.items});

  final List<_UpcomingItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _ownerCard,
          borderRadius: BorderRadius.circular(_cardRadius),
          border: Border.all(color: AppColors.onDark10),
        ),
        child: Text(
          'No upcoming bookings',
          style: TextStyle(color: AppColors.onDark62),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _ownerCard,
        borderRadius: BorderRadius.circular(_cardRadius),
        border: Border.all(color: AppColors.onDark10),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColors.onDark08),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        Text(
                          items[i].time24,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          items[i].period,
                          style: TextStyle(
                            color: AppColors.onDark52,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].serviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items[i].customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.onDark58,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusTag(active: i == 0 && items[i].active),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _ownerGold : AppColors.transparent,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: active ? _ownerGold : AppColors.onDark18),
      ),
      child: Text(
        active ? 'ACTIVE' : 'UPCOMING',
        style: TextStyle(
          color: active ? AppColors.midnight : AppColors.onDark62,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _OwnerOverviewStats {
  _OwnerOverviewStats({
    required this.todayBookings,
    required this.revenueToday,
    required this.nextTime,
    required this.nextCustomer,
    required this.upcoming,
  });

  final int todayBookings;
  final double revenueToday;
  final String nextTime;
  final String nextCustomer;
  final List<_UpcomingItem> upcoming;

  String get revenueLabel {
    if (revenueToday % 1 == 0) {
      return '\$${revenueToday.toInt()}';
    }
    return '\$${revenueToday.toStringAsFixed(2)}';
  }

  static _OwnerOverviewStats fromDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final now = DateTime.now();
    final upcoming = <_UpcomingItem>[];
    int todayBookings = 0;
    double revenueToday = 0;

    for (final doc in docs) {
      final data = doc.data();
      final status = ((data['status'] as String?) ?? '').toLowerCase().trim();
      final startAt = (data['startAt'] as Timestamp?)?.toDate();
      if (startAt == null) continue;

      final isToday = _isSameDay(now, startAt);
      if (isToday) {
        todayBookings += 1;
        if (status == 'confirmed' ||
            status == 'done' ||
            status == 'completed') {
          final price = (data['price'] as num?)?.toDouble() ?? 0;
          revenueToday += price;
        }
      }

      final isUpcomingStatus = status == 'pending' || status == 'confirmed';
      if (isUpcomingStatus &&
          !startAt.isBefore(now.subtract(const Duration(minutes: 1)))) {
        upcoming.add(
          _UpcomingItem(
            startsAt: startAt,
            serviceName: FirestoreDataMapper.serviceName(
              data,
              fallback: 'Booking',
            ),
            customerName: FirestoreDataMapper.customerFullName(
              data,
              fallback: 'Customer',
            ),
            active: status == 'confirmed' || status == 'pending',
          ),
        );
      }
    }

    upcoming.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final next = upcoming.isNotEmpty ? upcoming.first : null;

    return _OwnerOverviewStats(
      todayBookings: todayBookings,
      revenueToday: revenueToday,
      nextTime: next?.time24 ?? '--:--',
      nextCustomer: (next?.customerName ?? '-').toUpperCase(),
      upcoming: upcoming.take(3).toList(),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _UpcomingItem {
  _UpcomingItem({
    required this.startsAt,
    required this.serviceName,
    required this.customerName,
    required this.active,
  });

  final DateTime startsAt;
  final String serviceName;
  final String customerName;
  final bool active;

  String get time24 =>
      '${startsAt.hour.toString().padLeft(2, '0')}:${startsAt.minute.toString().padLeft(2, '0')}';

  String get period => startsAt.hour >= 12 ? 'PM' : 'AM';
}
