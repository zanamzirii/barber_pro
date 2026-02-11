import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'customer_data_mapper.dart';

class SelectBranchScreen extends StatefulWidget {
  const SelectBranchScreen({super.key, required this.userId});

  final String userId;

  @override
  State<SelectBranchScreen> createState() => _SelectBranchScreenState();
}

class _SelectBranchScreenState extends State<SelectBranchScreen> {
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
    Navigator.of(context).pop(shopId);
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
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
                            fontSize: 18,
                            letterSpacing: 1.5,
                            color: AppColors.text,
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
                      fontSize: 10,
                      letterSpacing: 3.0,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'SEARCH LOCATIONS...',
                      hintStyle: TextStyle(
                        color: const Color(0xFF5A5F68),
                        fontSize: 12,
                        letterSpacing: 1.9,
                        fontWeight: FontWeight.w500,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.gold,
                        size: 18,
                      ),
                      filled: true,
                      fillColor: const Color(0xFF121620).withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('shops')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? const [];
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
                            padding: const EdgeInsets.only(bottom: 16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _selectBranch(doc.id),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF121620,
                                  ).withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: AppColors.gold.withValues(
                                      alpha: 0.34,
                                    ),
                                    width: 0.7,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.08,
                                      ),
                                      blurRadius: 12,
                                    ),
                                  ],
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
                                                    alpha: 0.8,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        12,
                                        14,
                                        12,
                                      ),
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
                                                    fontSize: 20,
                                                    height: 1.08,
                                                    letterSpacing: 0.3,
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
                                                        ? const Color(
                                                            0xFF10B981,
                                                          )
                                                        : const Color(
                                                            0xFFEF4444,
                                                          ),
                                                  ),
                                                ),
                                                child: Text(
                                                  isOpen ? 'OPEN' : 'CLOSED',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    letterSpacing: 1.2,
                                                    fontWeight: FontWeight.w600,
                                                    color: isOpen
                                                        ? const Color(
                                                            0xFF10B981,
                                                          )
                                                        : const Color(
                                                            0xFFEF4444,
                                                          ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            address,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.muted.withValues(
                                                alpha: 0.85,
                                              ),
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                          const SizedBox(height: 10),
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
                                                              size: 14,
                                                              color: AppColors
                                                                  .muted,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              '$count BARBERS',
                                                              style: TextStyle(
                                                                color: AppColors
                                                                    .muted
                                                                    .withValues(
                                                                      alpha:
                                                                          0.9,
                                                                    ),
                                                                fontSize: 10,
                                                                letterSpacing:
                                                                    1.45,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
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
                                                              size: 14,
                                                              color: AppColors
                                                                  .muted,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              '$count SERVICES',
                                                              style: TextStyle(
                                                                color: AppColors
                                                                    .muted
                                                                    .withValues(
                                                                      alpha:
                                                                          0.9,
                                                                    ),
                                                                fontSize: 10,
                                                                letterSpacing:
                                                                    1.45,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
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
