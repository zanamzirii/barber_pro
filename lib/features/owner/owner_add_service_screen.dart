import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/motion.dart';
import '../../core/theme/app_colors.dart';
import 'owner_data.dart';

class OwnerAddServiceScreen extends StatefulWidget {
  const OwnerAddServiceScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<OwnerAddServiceScreen> createState() => _OwnerAddServiceScreenState();
}

class _OwnerAddServiceScreenState extends State<OwnerAddServiceScreen> {
  final TextEditingController _serviceNameController = TextEditingController();
  bool _submitting = false;
  late final Future<String> _shopIdFuture;

  @override
  void initState() {
    super.initState();
    _shopIdFuture = _resolveOwnerShopId();
  }

  @override
  void dispose() {
    _serviceNameController.dispose();
    super.dispose();
  }

  Future<String> _resolveOwnerShopId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return resolveAndEnsureShopId(user.uid);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _addService(String shopId) async {
    if (_submitting) return;

    final name = _serviceNameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Enter a service name');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnack('Please log in again');
      return;
    }

    setState(() => _submitting = true);

    try {
      final resolvedShopId = shopId.isNotEmpty
          ? shopId
          : await resolveAndEnsureShopId(user.uid);
      final ref = FirebaseFirestore.instance
          .collection('shops')
          .doc(resolvedShopId)
          .collection('services')
          .doc();

      await ref.set({
        'serviceId': ref.id,
        'shopId': resolvedShopId,
        'ownerId': user.uid,
        'name': name,
        'durationMinutes': 30,
        'price': 0.0,
        'currency': 'USD',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      _serviceNameController.clear();
      _showSnack('Service added');
    } catch (_) {
      _showSnack('Could not add service. Try again.');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _toggleServiceActive(
    String shopId,
    String docId,
    bool nextValue,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('services')
          .doc(docId)
          .update({
            'isActive': nextValue,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {
      _showSnack('Could not update service');
    }
  }

  Future<void> _deleteService(String shopId, String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('services')
          .doc(docId)
          .delete();
      _showSnack('Service removed');
    } catch (_) {
      _showSnack('Could not remove service');
    }
  }

  String _serviceCategoryLabel(String serviceName) {
    final name = serviceName.toLowerCase();
    if (name.contains('beard')) return 'ELITE GROOMING';
    if (name.contains('facial') || name.contains('spa')) return 'SPA TREATMENT';
    if (name.contains('royal') || name.contains('premium')) {
      return 'PREMIUM SERVICE';
    }
    return 'SIGNATURE SERVICE';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F1A),
      body: FutureBuilder<String>(
        future: _shopIdFuture,
        builder: (context, shopSnapshot) {
          if (shopSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            );
          }

          final shopId = shopSnapshot.data ?? '';
          if (shopId.isEmpty) {
            return const Center(
              child: Text(
                'No shop assigned',
                style: TextStyle(color: AppColors.onDark70),
              ),
            );
          }

          return Stack(
            children: [
              const _ServicesBackground(),
              SafeArea(
                child: Column(
                  children: [
                    _ServicesHeader(
                      onBack: () {
                        if (widget.onBack != null) {
                          widget.onBack!();
                          return;
                        }
                        final navigator = Navigator.of(context);
                        if (navigator.canPop()) {
                          navigator.maybePop();
                        }
                      },
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('shops')
                            .doc(shopId)
                            .collection('services')
                            .limit(200)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Could not load services',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.72),
                                ),
                              ),
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.gold,
                              ),
                            );
                          }

                          final docs = snapshot.data?.docs.toList() ?? [];
                          docs.sort((a, b) {
                            final aTs = a.data()['createdAt'] as Timestamp?;
                            final bTs = b.data()['createdAt'] as Timestamp?;
                            final aMs = aTs?.millisecondsSinceEpoch ?? 0;
                            final bMs = bTs?.millisecondsSinceEpoch ?? 0;
                            return bMs.compareTo(aMs);
                          });

                          final activeCount = docs.where((doc) {
                            return (doc.data()['isActive'] as bool?) ?? true;
                          }).length;

                          return ListView(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 124),
                            children: [
                              Text(
                                'NEW SERVICE',
                                style: TextStyle(
                                  color: AppColors.gold.withValues(alpha: 0.72),
                                  fontSize: 12,
                                  letterSpacing: 3.8,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 60,
                                      child: TextField(
                                        controller: _serviceNameController,
                                        style: const TextStyle(
                                          color: Color(0xFFEDEFF3),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textInputAction: TextInputAction.done,
                                        onSubmitted: (_) => _addService(shopId),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Service Name (e.g. Royal Cut)',
                                          hintStyle: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.34,
                                            ),
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          filled: true,
                                          fillColor: const Color(0xFF070A12),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 22,
                                              ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            borderSide: BorderSide(
                                              color: AppColors.gold.withValues(
                                                alpha: 0.26,
                                              ),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            borderSide: const BorderSide(
                                              color: AppColors.gold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  SizedBox(
                                    width: 96,
                                    height: 56,
                                    child: ElevatedButton(
                                      onPressed: _submitting
                                          ? null
                                          : () => _addService(shopId),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.gold,
                                        foregroundColor: const Color(
                                          0xFF05070A,
                                        ),
                                        disabledBackgroundColor: AppColors.gold
                                            .withValues(alpha: 0.62),
                                        elevation: 10,
                                        shadowColor: AppColors.gold.withValues(
                                          alpha: 0.32,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      child: _submitting
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.2,
                                                color: Color(0xFF05070A),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.add,
                                              size: 32,
                                              weight: 600,
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 28),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Managed Portfolio',
                                      style: TextStyle(
                                        color: AppColors.gold,
                                        fontFamily: 'PlayfairDisplay',
                                        fontSize: 38,
                                        height: 1,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    '$activeCount ACTIVE SERVICES',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.52,
                                      ),
                                      fontSize: 10,
                                      letterSpacing: 1.6,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Divider(
                                color: AppColors.gold.withValues(alpha: 0.22),
                                height: 1,
                              ),
                              const SizedBox(height: 18),
                              if (docs.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF070A12),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.14,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'No services yet. Add your first service.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.72,
                                      ),
                                      fontSize: 15,
                                    ),
                                  ),
                                )
                              else
                                ...docs.map((doc) {
                                  final data = doc.data();
                                  final serviceName =
                                      ((data['name'] as String?) ?? '')
                                          .trim()
                                          .isNotEmpty
                                      ? (data['name'] as String).trim()
                                      : 'Unnamed Service';
                                  final isActive =
                                      (data['isActive'] as bool?) ?? true;

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: _ServiceCard(
                                      name: serviceName,
                                      category: _serviceCategoryLabel(
                                        serviceName,
                                      ),
                                      active: isActive,
                                      onDelete: () =>
                                          _deleteService(shopId, doc.id),
                                      onToggle: (nextValue) =>
                                          _toggleServiceActive(
                                            shopId,
                                            doc.id,
                                            nextValue,
                                          ),
                                    ),
                                  );
                                }),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ServicesBackground extends StatelessWidget {
  const _ServicesBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B0F1A), Color(0xFF070A12), Color(0xFF0B0F1A)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.gold.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -120,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicesHeader extends StatelessWidget {
  const _ServicesHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.gold.withValues(alpha: 0.12)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: AppColors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onBack,
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.gold,
                  size: 30,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Services',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.gold,
                fontFamily: 'PlayfairDisplay',
                fontSize: 24,
                height: 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.name,
    required this.category,
    required this.active,
    required this.onDelete,
    required this.onToggle,
  });

  final String name;
  final String category;
  final bool active;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF070A12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.30),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.gold,
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 20,
                        height: 1.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category,
                      style: TextStyle(
                        color: AppColors.onDark46,
                        fontSize: 12,
                        letterSpacing: 2.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  onPressed: onDelete,
                  splashRadius: 18,
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.white.withValues(alpha: 0.54),
                    size: 28,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.onDark08, height: 1),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      active ? 'Master Switch' : 'Master Switch (Inactive)',
                      style: TextStyle(
                        color: active
                            ? Colors.white.withValues(alpha: 0.92)
                            : AppColors.onDark52,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      active
                          ? 'Controls visibility for all barbers in the shop.'
                          : 'Service is currently hidden from all booking menus.',
                      style: TextStyle(
                        color: active
                            ? Colors.white.withValues(alpha: 0.48)
                            : AppColors.onDark35,
                        fontSize: 10,
                        height: 1.25,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _GoldSwitch(value: active, onChanged: onToggle),
            ],
          ),
        ],
      ),
    );
  }
}

class _GoldSwitch extends StatelessWidget {
  const _GoldSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: Motion.microAnimationDuration,
        curve: Motion.microAnimationCurve,
        width: 80,
        height: 42,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: value ? AppColors.gold : const Color(0xFF222A3E),
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: Motion.microAnimationDuration,
          curve: Motion.microAnimationCurve,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFE6E7EC),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
