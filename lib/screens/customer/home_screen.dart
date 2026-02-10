import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../theme/app_colors.dart';
import '../../app_shell.dart';
import 'book_appointment_screen.dart';
import 'my_appointments_screen.dart';

void _showHomePlaceholder(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$label feature coming soon'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.showBottomNav = true});

  final bool showBottomNav;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF05070A),
        body: Center(child: Text('Please log in again')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, userSnapshot) {
          final selectedShopId =
              (userSnapshot.data?.data()?['selectedShopId'] as String?)?.trim();

          return Stack(
            children: [
              const _SilkyBackground(),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _HomeHeader(),
                      const SizedBox(height: 12),
                      _BranchSelectorCard(
                        userId: user.uid,
                        selectedShopId: selectedShopId,
                      ),
                      const SizedBox(height: 12),
                      _SelectedBranchOverview(shopId: selectedShopId),
                      const SizedBox(height: 18),
                      _LiveBookingPanel(selectedShopId: selectedShopId),
                      const SizedBox(height: 22),
                      const _NextSessionCard(),
                      const SizedBox(height: 22),
                      const _QuickActions(),
                      const SizedBox(height: 28),
                      const _AvailableToday(),
                      const SizedBox(height: 28),
                      const _PremiumPackages(),
                      const SizedBox(height: 28),
                      const _TopBarbers(),
                      const SizedBox(height: 28),
                      const _EliteStatusCard(),
                      const SizedBox(height: 28),
                      const _EditorialSection(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
              if (showBottomNav) const _BottomNav(),
            ],
          );
        },
      ),
    );
  }
}

class _LiveBookingPanel extends StatefulWidget {
  const _LiveBookingPanel({required this.selectedShopId});

  final String? selectedShopId;

  @override
  State<_LiveBookingPanel> createState() => _LiveBookingPanelState();
}

class _LiveBookingPanelState extends State<_LiveBookingPanel> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF121620).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LIVE BOOKING',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 2.2,
                fontWeight: FontWeight.w700,
                color: AppColors.gold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.selectedShopId == null || widget.selectedShopId!.isEmpty
                  ? 'Select a branch first, then book.'
                  : 'Booking for selected branch: ${widget.selectedShopId}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF05070A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (widget.selectedShopId == null ||
                      widget.selectedShopId!.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please select a branch first'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BookAppointmentScreen(
                        initialShopId: widget.selectedShopId,
                      ),
                    ),
                  );
                },
                child: const Text('Book Appointment'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  side: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.4),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const MyAppointmentsScreen(),
                    ),
                  );
                },
                child: const Text('My Appointments'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BranchSelectorCard extends StatelessWidget {
  const _BranchSelectorCard({
    required this.userId,
    required this.selectedShopId,
  });

  final String userId;
  final String? selectedShopId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF121620).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
        ),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('shops').snapshots(),
          builder: (context, snapshot) {
            final shops = snapshot.data?.docs ?? [];
            final hasSelected =
                selectedShopId != null && selectedShopId!.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SELECT BRANCH',
                  style: TextStyle(
                    color: AppColors.gold,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 8),
                if (!hasSelected)
                  const Text(
                    'No branch selected yet.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                DropdownButtonFormField<String>(
                  initialValue: hasSelected ? selectedShopId : null,
                  decoration: const InputDecoration(hintText: 'Choose branch'),
                  items: shops.map((doc) {
                    final data = doc.data();
                    final title = (data['name'] as String?)?.trim();
                    final label = (title == null || title.isEmpty)
                        ? doc.id
                        : title;
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    if (value == null) return;
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .set({
                          'selectedShopId': value,
                          'updatedAt': FieldValue.serverTimestamp(),
                        }, SetOptions(merge: true));
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SelectedBranchOverview extends StatelessWidget {
  const _SelectedBranchOverview({required this.shopId});

  final String? shopId;

  @override
  Widget build(BuildContext context) {
    if (shopId == null || shopId!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF121620).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('shops')
                  .doc(shopId)
                  .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final name = (data?['name'] as String?)?.trim();
                return Text(
                  name == null || name.isEmpty
                      ? 'Branch: $shopId'
                      : 'Branch: $name',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('shops')
                        .doc(shopId)
                        .collection('barbers')
                        .where('isActive', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return Text(
                        'Active Barbers: $count',
                        style: const TextStyle(color: AppColors.muted),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('shops')
                        .doc(shopId)
                        .collection('services')
                        .where('isActive', isEqualTo: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return Text(
                        'Active Services: $count',
                        style: const TextStyle(color: AppColors.muted),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SilkyBackground extends StatelessWidget {
  const _SilkyBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF05070A), Color(0xFF0B0F1A), Color(0xFF05070A)],
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'PINNACLE',
                style: TextStyle(
                  fontFamily: 'PlayfairDisplay',
                  fontSize: 20,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'ELITE CONCIERGE',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 4,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    onPressed: () =>
                        _showHomePlaceholder(context, 'Notifications'),
                    icon: const Icon(
                      Icons.notifications_none,
                      color: AppColors.gold,
                    ),
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const AppShell()),
                    (route) => false,
                  );
                },
                tooltip: 'Logout',
                icon: const Icon(Icons.logout, color: AppColors.gold),
              ),
              const SizedBox(width: 6),
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 1),
                ),
                child: ClipOval(
                  child: Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuBqFRSHASofU0oYl4E_yVUTqYyRmyJqrY-EKr_sm_r8TLGkBw9Xq1evk4RV-ZZu6xJRKiZJksg3nYCvFYJaKV4_w07QFNb-lLKFkZb3p6DgQeLOb4QJGf3LokFD8soHo0FPaBigtDweRB11_5mVeIAGWXpisUSUpzn3DM8kzXfazpHsdB2LtbyY44iKZSTIoaKkCXtewQVtGj7KaJf8Uuf9QOr3cHF-992INlluLPf8pLE34vc2p31vCksGyRWku6Yup6e5S3JrgAOI',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF121620).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'YOUR NEXT SESSION',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'The Sovereign',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 20,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    Text(
                      '14:30',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w300,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'OCT 24',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.gold.withValues(alpha: 0.25),
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuA9F_G7RgbBYE5S4J6pbDEkNjflPOqF6G9OgzZ9qb_StbESO7iJsyqNMqs82z0d83b9_h8BnY-skw_dALAm0QilzAEAEgzDQuY-gsFGL6xO9UUs0FtIc4bbMDbmI4hTJZEKFZQnd7HEl7OHkN1oHDlyDQ2mxn9kPasF3hAcrBIkrovGBHxp3Hpn9Uf4LEQq9z4QYKWTHXT2qXHJRc3MA-cD6M_xHoVBmptQlrOMMnONd2Ka3Zk1MDZFsIHTHVlb-4H0ORepDZJPL40T',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'MASTER BARBER',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2,
                        color: AppColors.muted,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Julian Vance',
                      style: TextStyle(color: AppColors.text, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SmallActionButton(
                    label: 'RESCHEDULE',
                    filled: false,
                    onTap: () => _showHomePlaceholder(context, 'Reschedule'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SmallActionButton(
                    label: 'DIRECTIONS',
                    filled: true,
                    onTap: () => _showHomePlaceholder(context, 'Directions'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.label,
    required this.filled,
    this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color: filled ? const Color(0xFF05070A) : AppColors.gold,
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _QuickAction(
            icon: Icons.menu_book,
            label: 'Services',
            onTap: () => _showHomePlaceholder(context, 'Services'),
          ),
          _QuickAction(
            icon: Icons.star,
            label: 'Loyalty',
            onTap: () => _showHomePlaceholder(context, 'Loyalty'),
          ),
          _QuickAction(
            icon: Icons.local_offer,
            label: 'Offers',
            onTap: () => _showHomePlaceholder(context, 'Offers'),
          ),
          _QuickAction(
            icon: Icons.content_cut,
            label: 'Barbers',
            onTap: () => _showHomePlaceholder(context, 'Barbers'),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF121620),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Icon(icon, color: AppColors.gold, size: 22),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 8,
            letterSpacing: 2,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _AvailableToday extends StatelessWidget {
  const _AvailableToday();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'AVAILABLE TODAY',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text,
                ),
              ),
              Row(
                children: [
                  Text(
                    'FILTER',
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 2,
                      color: AppColors.gold,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.tune, size: 12, color: AppColors.gold),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                _TimeSlot(time: '16:00', subtitle: 'Instant'),
                SizedBox(width: 10),
                _TimeSlot(time: '16:30', subtitle: 'Instant'),
                SizedBox(width: 10),
                _TimeSlot(time: '17:00', subtitle: 'Instant'),
                SizedBox(width: 10),
                _TimeSlot(time: '17:30', subtitle: 'Waitlist', disabled: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeSlot extends StatelessWidget {
  const _TimeSlot({
    required this.time,
    required this.subtitle,
    this.disabled = false,
  });

  final String time;
  final String subtitle;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Container(
        width: 88,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0xFF121620),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              time,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle.toUpperCase(),
              style: TextStyle(
                fontSize: 7,
                letterSpacing: 1.3,
                color: AppColors.gold.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumPackages extends StatelessWidget {
  const _PremiumPackages();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'THE ATELIER',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'PREMIUM PACKAGES',
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 3,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                _PackageIcon(icon: Icons.architecture, label: 'Haircut'),
                SizedBox(width: 16),
                _PackageIcon(icon: Icons.face_5, label: 'Beard'),
                SizedBox(width: 16),
                _PackageIcon(icon: Icons.flare, label: 'VIP Set'),
                SizedBox(width: 16),
                _PackageIcon(icon: Icons.content_cut, label: 'Trim'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackageIcon extends StatelessWidget {
  const _PackageIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
          ),
          child: Icon(icon, color: AppColors.gold, size: 24),
        ),
        const SizedBox(height: 10),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 8,
            letterSpacing: 2.5,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _TopBarbers extends StatelessWidget {
  const _TopBarbers();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'ARTISANS',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'TOP RATED',
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 2,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF121620).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuA9F_G7RgbBYE5S4J6pbDEkNjflPOqF6G9OgzZ9qb_StbESO7iJsyqNMqs82z0d83b9_h8BnY-skw_dALAm0QilzAEAEgzDQuY-gsFGL6xO9UUs0FtIc4bbMDbmI4hTJZEKFZQnd7HEl7OHkN1oHDlyDQ2mxn9kPasF3hAcrBIkrovGBHxp3Hpn9Uf4LEQq9z4QYKWTHXT2qXHJRc3MA-cD6M_xHoVBmptQlrOMMnONd2Ka3Zk1MDZFsIHTHVlb-4H0ORepDZJPL40T',
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Text(
                            'Julian Vance',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.stars, size: 12, color: AppColors.gold),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Next: 15:45 Today',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppColors.muted,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: InkWell(
                    onTap: () => _showHomePlaceholder(context, 'Add barber'),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.add_circle,
                        size: 16,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EliteStatusCard extends StatelessWidget {
  const _EliteStatusCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF121620).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Elite Status',
                  style: TextStyle(fontFamily: 'PlayfairDisplay', fontSize: 18),
                ),
                Icon(Icons.workspace_premium, color: AppColors.gold),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              '2 visits until reward',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 2,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 180,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.timer, size: 12, color: AppColors.gold),
                  SizedBox(width: 6),
                  Text(
                    'LIMITED: 20% OFF STYLING',
                    style: TextStyle(
                      fontSize: 8,
                      letterSpacing: 1.2,
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditorialSection extends StatelessWidget {
  const _EditorialSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'EDITORIAL',
                style: TextStyle(
                  fontSize: 18,
                  letterSpacing: 2.5,
                  fontFamily: 'PlayfairDisplay',
                ),
              ),
              Icon(Icons.unfold_more, color: AppColors.gold, size: 16),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: const [
                    _EditorialCard(
                      imageUrl:
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuBmQXle88jxfwE7hY5uv3kb4LU0XzAdUnSea-pLi2mO0uehytqlnjjLqVUYg9wXIS2aqeU9IzyXINdQI83NcJ3wEJ_TYzlCjwLh8ha9av-6n7rHiEga5dDNnJ_ceB2YnDQtb6u4WSteEiYGa4cxmOAIJ14a6CEeZ8kmmexs4XL_gAwrznbN1yIDv8Y158qBtKdgaQZ5g2KRZU9fUl7gSnlmJgA8qio18SG6_Az_pxvml5b3E5PFIdp4grX82QGGYWdwzjHlh98jY946',
                      label: 'I. PLATINUM',
                    ),
                    SizedBox(height: 12),
                    _EditorialCard(
                      imageUrl:
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuBLBSeitoD3j7b5I1yFKmz9sFE_euoX4NzhFptQeZRGQFXXW0pYa-DfwMG5M7B_xtFfSPBWPnRGSBT0b_qWorxYmqvqMMHnJmxwabHpslK2u37-VBdCvlE-b4ieX-mwH1F5Ch1BCpZUittw18L3bYH9WpNDwB5S2SuLPy9FMrC572jFMpg0BP1YTS3VCkfhpRSEG3rfY2WOr__-lKah9GAm__aNKNPjHlNWvtcb0jRIOpx0fPMm6qxVSkXSHnrrhLBtlA8Uiud1iees',
                      label: 'III. EXECUTIVE',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: const [
                    _EditorialCard(
                      imageUrl:
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuA9F_G7RgbBYE5S4J6pbDEkNjflPOqF6G9OgzZ9qb_StbESO7iJsyqNMqs82z0d83b9_h8BnY-skw_dALAm0QilzAEAEgzDQuY-gsFGL6xO9UUs0FtIc4bbMDbmI4hTJZEKFZQnd7HEl7OHkN1oHDlyDQ2mxn9kPasF3hAcrBIkrovGBHxp3Hpn9Uf4LEQq9z4QYKWTHXT2qXHJRc3MA-cD6M_xHoVBmptQlrOMMnONd2Ka3Zk1MDZFsIHTHVlb-4H0ORepDZJPL40T',
                      label: 'II. HERITAGE',
                      height: 190,
                    ),
                    SizedBox(height: 12),
                    _EditorialCard(
                      imageUrl:
                          'https://lh3.googleusercontent.com/aida-public/AB6AXuDylOxkaUQWpFakbIjBMeeTLiI51WSxTbC7oTho8CIgaCHOwTFFQOA1f0Dh_rGSJaMlO6xooGZx4ASsu79eurySOFelaXiW88CHkSavfcC82TWlIBNKJitzPmsTGiLFxGIolqRQlTbu3eejfG2iDOaNwQ-M0q_vmtiilgjqTPxex-SF9KgvYJxkwUX26Sm81ekP8_F0vx164y_vu6__yRzM7ucNZm9LN2Qx40j_YmO5P1Ry5bRGCpK8f8Gm4eJSSnUUHJ8f-MGUCFbT',
                      label: 'IV. AVANT',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorialCard extends StatelessWidget {
  const _EditorialCard({
    required this.imageUrl,
    required this.label,
    this.height = 140,
  });

  final String imageUrl;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        image: DecorationImage(
          image: NetworkImage(imageUrl),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withValues(alpha: 0.35),
            BlendMode.darken,
          ),
        ),
      ),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(12),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          letterSpacing: 2.5,
          color: AppColors.gold,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF121620).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home,
                  label: 'Home',
                  active: true,
                  onTap: () => _showHomePlaceholder(context, 'Home'),
                ),
                _NavItem(
                  icon: Icons.explore,
                  label: 'Explore',
                  onTap: () => _showHomePlaceholder(context, 'Explore'),
                ),
                _NavItem(
                  icon: Icons.calendar_today,
                  label: 'Book',
                  primary: true,
                  onTap: () => _showHomePlaceholder(context, 'Book'),
                ),
                _NavItem(
                  icon: Icons.chat_bubble,
                  label: 'Chat',
                  onTap: () => _showHomePlaceholder(context, 'Chat'),
                ),
                _NavItem(
                  icon: Icons.person,
                  label: 'Profile',
                  onTap: () => _showHomePlaceholder(context, 'Profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.primary = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (primary) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.gold,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.calendar_today, color: Color(0xFF05070A)),
            ),
            const SizedBox(height: 4),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? AppColors.gold : AppColors.text, size: 22),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 7,
              letterSpacing: 1.8,
              color: active ? AppColors.gold : AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
