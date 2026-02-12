import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import 'book_appointment_screen.dart';
import 'customer_data_mapper.dart';
import 'my_appointments_screen.dart';
import 'select_branch_screen.dart';

void _showHomePlaceholder(BuildContext context, String label) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$label feature coming soon'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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

          if (selectedShopId == null || selectedShopId.isEmpty) {
            return _NoBranchHomeState(userId: user.uid);
          }

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
                      _LiveBookingPanel(
                        userId: user.uid,
                        selectedShopId: selectedShopId,
                      ),
                      const SizedBox(height: 16),
                      const _NextSessionCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LiveBookingPanel extends StatefulWidget {
  const _LiveBookingPanel({required this.userId, required this.selectedShopId});

  final String userId;
  final String? selectedShopId;

  @override
  State<_LiveBookingPanel> createState() => _LiveBookingPanelState();
}

class _LiveBookingPanelState extends State<_LiveBookingPanel> {
  Future<void> _clearBranch(BuildContext context) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear Selected Branch?'),
          content: const Text(
            'Your home will return to "No branch selected" state.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear'),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .set({
          'selectedShopId': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Widget build(BuildContext context) {
    final selectedShopId = widget.selectedShopId;
    if (selectedShopId == null || selectedShopId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(selectedShopId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const <String, dynamic>{};
        final shopName = CustomerDataMapper.branchName(data);
        final address = CustomerDataMapper.branchAddress(data);
        final isOpen = CustomerDataMapper.boolValue(data, const [
          'isOpen',
        ], fallback: true);
        final branchImageUrl = CustomerDataMapper.branchImage(
          data,
          seed: selectedShopId,
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.35),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      SizedBox(
                        height: 192,
                        width: double.infinity,
                        child: Image.network(branchImageUrl, fit: BoxFit.cover),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFF05070A).withValues(alpha: 0.0),
                                const Color(0xFF05070A).withValues(alpha: 0.4),
                                const Color(0xFF05070A).withValues(alpha: 0.92),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 16,
                        right: 16,
                        child: InkWell(
                          onTap: () => _clearBranch(context),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 40,
                            height: 40,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF05070A,
                              ).withValues(alpha: 0.4),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 20,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 12,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: isOpen
                                              ? Colors.greenAccent
                                              : Colors.redAccent,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        isOpen ? 'OPEN NOW' : 'CLOSED',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
                                          fontSize: 10,
                                          letterSpacing: 2.0,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    shopName,
                                    style: const TextStyle(
                                      fontFamily: 'PlayfairDisplay',
                                      fontSize: 24,
                                      height: 1.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                      fontSize: 12,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  Motion.pageRoute(
                                    builder: (_) => SelectBranchScreen(
                                      userId: widget.userId,
                                    ),
                                  ),
                                );
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 0,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'CHANGE',
                                style: TextStyle(
                                  color: AppColors.gold,
                                  fontSize: 10,
                                  letterSpacing: 2.0,
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
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: const Color(0xFF05070A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      Motion.pageRoute(
                        builder: (_) => BookAppointmentScreen(
                          initialShopId: selectedShopId,
                        ),
                      ),
                    );
                  },
                  child: const Text('BOOK APPOINTMENT'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    backgroundColor: AppColors.gold.withValues(alpha: 0.05),
                    side: BorderSide(
                      color: AppColors.gold.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).push(
                      Motion.pageRoute(
                        builder: (_) => const MyAppointmentsScreen(),
                      ),
                    );
                  },
                  child: const Text('MY APPOINTMENTS'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NoBranchHomeState extends StatelessWidget {
  const _NoBranchHomeState({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    const reservedBottomSpace = 120.0;

    return Stack(
      children: [
        const _SilkyBackground(),
        SafeArea(
          child: Column(
            children: [
              const _HomeHeader(),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, reservedBottomSpace),
                  child: Column(
                    children: [
                      const Spacer(flex: 5),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 132,
                            height: 132,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.gold.withValues(alpha: 0.12),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(
                                0xFF121620,
                              ).withValues(alpha: 0.45),
                              border: Border.all(
                                color: AppColors.gold.withValues(alpha: 0.2),
                              ),
                            ),
                            child: const Icon(
                              Icons.location_on_outlined,
                              color: AppColors.gold,
                              size: 38,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 34),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Text(
                          'Select a branch',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 34,
                            letterSpacing: 0.6,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const SizedBox(
                        width: 280,
                        child: Text(
                          'CHOOSE A BRANCH TO VIEW SERVICES AND BOOK APPOINTMENTS.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 11,
                            letterSpacing: 2.6,
                            fontWeight: FontWeight.w600,
                            height: 1.65,
                          ),
                        ),
                      ),
                      const Spacer(flex: 4),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.gold,
                            foregroundColor: const Color(0xFF05070A),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 4,
                            ),
                          ),
                          onPressed: () {
                            Navigator.of(context).push(
                              Motion.pageRoute(
                                builder: (_) =>
                                    SelectBranchScreen(userId: userId),
                              ),
                            );
                          },
                          child: const Text('SELECT BRANCH'),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BranchSelectionScreen extends StatefulWidget {
  const _BranchSelectionScreen({required this.userId});

  final String userId;

  @override
  State<_BranchSelectionScreen> createState() => _BranchSelectionScreenState();
}

class _BranchSelectionScreenState extends State<_BranchSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectBranch(String shopId) async {
    await FirebaseFirestore.instance.collection('users').doc(widget.userId).set(
      {'selectedShopId': shopId, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      body: Stack(
        children: [
          const _SilkyBackground(),
          SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: AppColors.text,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Select a branch',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 26,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                  child: Text(
                    'CHOOSE A BRANCH TO VIEW SERVICES AND BOOK APPOINTMENTS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.muted.withValues(alpha: 0.8),
                      fontSize: 8,
                      letterSpacing: 3.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'SEARCH LOCATIONS...',
                      hintStyle: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10,
                        letterSpacing: 1.8,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.gold,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF121620).withValues(alpha: 0.6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('shops')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      final query = _searchController.text.trim().toLowerCase();
                      final filtered = docs.where((doc) {
                        final data = doc.data();
                        final name = CustomerDataMapper.branchName(
                          data,
                          fallback: doc.id,
                        ).toLowerCase();
                        final address = CustomerDataMapper.branchAddress(
                          data,
                          fallback: '',
                        ).toLowerCase();
                        if (query.isEmpty) return true;
                        return name.contains(query) || address.contains(query);
                      }).toList();

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final doc = filtered[index];
                          final data = doc.data();
                          final name = CustomerDataMapper.branchName(
                            data,
                            fallback: doc.id,
                          );
                          final address = CustomerDataMapper.branchAddress(
                            data,
                            fallback: 'Location unavailable',
                          );
                          final isOpen = CustomerDataMapper.boolValue(
                            data,
                            const ['isOpen'],
                            fallback: true,
                          );
                          final imageUrl = CustomerDataMapper.branchImage(
                            data,
                            seed: doc.id,
                          );

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _selectBranch(doc.id),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF121620,
                                  ).withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.25,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      children: [
                                        Container(
                                          height: 160,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                const BorderRadius.vertical(
                                                  top: Radius.circular(18),
                                                ),
                                            image: DecorationImage(
                                              image: NetworkImage(imageUrl),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  const BorderRadius.vertical(
                                                    top: Radius.circular(18),
                                                  ),
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.black.withValues(
                                                    alpha: 0.08,
                                                  ),
                                                  Colors.black.withValues(
                                                    alpha: 0.72,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  name,
                                                  style: const TextStyle(
                                                    fontFamily:
                                                        'PlayfairDisplay',
                                                    color: AppColors.gold,
                                                    fontSize: 30,
                                                    height: 1.05,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                  border: Border.all(
                                                    color: isOpen
                                                        ? Colors.greenAccent
                                                        : Colors.redAccent,
                                                  ),
                                                ),
                                                child: Text(
                                                  isOpen ? 'OPEN' : 'CLOSED',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    letterSpacing: 1.5,
                                                    color: isOpen
                                                        ? Colors.greenAccent
                                                        : Colors.redAccent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            address,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppColors.muted,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
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
                                                          .doc(doc.id)
                                                          .collection('barbers')
                                                          .where(
                                                            'isActive',
                                                            isEqualTo: true,
                                                          )
                                                          .snapshots(),
                                                      builder: (context, barbersSnap) {
                                                        final count =
                                                            barbersSnap
                                                                .data
                                                                ?.docs
                                                                .length ??
                                                            0;
                                                        return Row(
                                                          children: [
                                                            const Icon(
                                                              Icons.content_cut,
                                                              size: 12,
                                                              color: AppColors
                                                                  .muted,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              '$count BARBERS',
                                                              style: const TextStyle(
                                                                color: AppColors
                                                                    .muted,
                                                                fontSize: 9,
                                                                letterSpacing:
                                                                    1.4,
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                              ),
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
                                                          .doc(doc.id)
                                                          .collection(
                                                            'services',
                                                          )
                                                          .where(
                                                            'isActive',
                                                            isEqualTo: true,
                                                          )
                                                          .snapshots(),
                                                      builder: (context, servicesSnap) {
                                                        final count =
                                                            servicesSnap
                                                                .data
                                                                ?.docs
                                                                .length ??
                                                            0;
                                                        return Row(
                                                          children: [
                                                            const Icon(
                                                              Icons.flash_on,
                                                              size: 12,
                                                              color: AppColors
                                                                  .muted,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              '$count SERVICES',
                                                              style: const TextStyle(
                                                                color: AppColors
                                                                    .muted,
                                                                fontSize: 9,
                                                                letterSpacing:
                                                                    1.4,
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      },
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                  fontSize: 22,
                  letterSpacing: 2.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'ELITE CONCIERGE',
                style: TextStyle(
                  fontSize: 8,
                  letterSpacing: 3.9,
                  color: Color(0xFFD4AF37),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const Row(
            children: [
              SizedBox(width: 2),
              _HeaderNotificationButton(),
              SizedBox(width: 8),
              _HeaderAvatar(),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderNotificationButton extends StatelessWidget {
  const _HeaderNotificationButton();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: () => _showHomePlaceholder(context, 'Notifications'),
          borderRadius: BorderRadius.circular(999),
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Icon(
              Icons.notifications_none,
              color: AppColors.gold,
              size: 23,
            ),
          ),
        ),
        Positioned(
          right: 6,
          top: 6,
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
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar();

  @override
  Widget build(BuildContext context) {
    final fallbackAvatar =
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBqFRSHASofU0oYl4E_yVUTqYyRmyJqrY-EKr_sm_r8TLGkBw9Xq1evk4RV-ZZu6xJRKiZJksg3nYCvFYJaKV4_w07QFNb-lLKFkZb3p6DgQeLOb4QJGf3LokFD8soHo0FPaBigtDweRB11_5mVeIAGWXpisUSUpzn3DM8kzXfazpHsdB2LtbyY44iKZSTIoaKkCXtewQVtGj7KaJf8Uuf9QOr3cHF-992INlluLPf8pLE34vc2p31vCksGyRWku6Yup6e5S3JrgAOI';
    final avatarUrl =
        FirebaseAuth.instance.currentUser?.photoURL?.trim().isNotEmpty == true
        ? FirebaseAuth.instance.currentUser!.photoURL!.trim()
        : fallbackAvatar;

    return Container(
      width: 36,
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.gold, width: 1),
      ),
      child: ClipOval(child: Image.network(avatarUrl, fit: BoxFit.cover)),
    );
  }
}

class _NextSessionCard extends StatelessWidget {
  const _NextSessionCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UPCOMING SESSION',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 4,
              fontWeight: FontWeight.w700,
              color: AppColors.gold.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF121620).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'DEC',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                              Text(
                                '14',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontFamily: 'PlayfairDisplay',
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'The Royal Cut',
                              style: TextStyle(
                                fontFamily: 'PlayfairDisplay',
                                fontSize: 18,
                                color: AppColors.text,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  '45 Min',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Ã¢â‚¬Â¢',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '10:30 AM',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.gold.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const CircleAvatar(
                            backgroundImage: NetworkImage(
                              'https://lh3.googleusercontent.com/aida-public/AB6AXuBqFRSHASofU0oYl4E_yVUTqYyRmyJqrY-EKr_sm_r8TLGkBw9Xq1evk4RV-ZZu6xJRKiZJksg3nYCvFYJaKV4_w07QFNb-lLKFkZb3p6DgQeLOb4QJGf3LokFD8soHo0FPaBigtDweRB11_5mVeIAGWXpisUSUpzn3DM8kzXfazpHsdB2LtbyY44iKZSTIoaKkCXtewQVtGj7KaJf8Uuf9QOr3cHF-992INlluLPf8pLE34vc2p31vCksGyRWku6Yup6e5S3JrgAOI',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'BARBER',
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: 2,
                                color: Color(0x66FFFFFF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Marcus V.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xCCFFFFFF),
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        InkWell(
                          onTap: () =>
                              _showHomePlaceholder(context, 'Reschedule'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: const Text(
                              'RESCHEDULE',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w600,
                                color: Color(0xB3FFFFFF),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () =>
                              _showHomePlaceholder(context, 'Directions'),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.white.withValues(alpha: 0.05),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            child: const Icon(
                              Icons.directions,
                              size: 15,
                              color: Color(0xB3FFFFFF),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
