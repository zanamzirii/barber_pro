import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../shared/firestore_data_mapper.dart';
import 'owner_data.dart';
import 'owner_ui.dart';

class OwnerAppointmentsScreen extends StatelessWidget {
  const OwnerAppointmentsScreen({super.key});

  Future<String> _getShopId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return resolveShopId(user.uid);
  }

  Future<void> _updateAppointmentStatus(
    BuildContext context,
    String appointmentId,
    String status,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Appointment marked as $status'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update appointment'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OwnerUi.screenBg,
      body: FutureBuilder<String>(
        future: _getShopId(),
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
                style: TextStyle(color: Colors.white70),
              ),
            );
          }

          return Stack(
            children: [
              OwnerUi.background(),
              SafeArea(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                      child: Row(
                        children: [
                          Text(
                            'Bookings',
                            style: OwnerUi.pageTitleStyle(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('appointments')
                            .where('shopId', isEqualTo: shopId)
                            .limit(100)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: AppColors.gold,
                              ),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Center(
                              child: Text(
                                'No appointments yet',
                                style: TextStyle(color: Colors.white70),
                              ),
                            );
                          }

                          final docs = snapshot.data!.docs.toList()
                            ..sort((a, b) {
                              final aTs = a.data()['startAt'] as Timestamp?;
                              final bTs = b.data()['startAt'] as Timestamp?;
                              final aMs = aTs?.millisecondsSinceEpoch ?? 0;
                              final bMs = bTs?.millisecondsSinceEpoch ?? 0;
                              return bMs.compareTo(aMs);
                            });

                          return ListView.separated(
                            padding: const EdgeInsets.fromLTRB(24, 10, 24, 32),
                            itemCount: docs.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final appointmentId = docs[index].id;
                              final data = docs[index].data();
                              final customerName =
                                  FirestoreDataMapper.customerFullName(data);
                              final serviceName =
                                  FirestoreDataMapper.serviceName(data);
                              final barberName =
                                  FirestoreDataMapper.barberFullName(data);
                              final status =
                                  (data['status'] as String?) ?? 'pending';
                              final startAt = data['startAt'] as Timestamp?;
                              final startAtText = startAt == null
                                  ? 'No time set'
                                  : _formatDateTime(startAt.toDate());

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: OwnerUi.panelDecoration(),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '$customerName - $serviceName',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: AppColors.text,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        _StatusChip(status: status),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Barber: $barberName',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      startAtText,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                    if (status.toLowerCase() == 'pending') ...[
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed: () =>
                                                  _updateAppointmentStatus(
                                                context,
                                                appointmentId,
                                                'cancelled',
                                              ),
                                              style: OutlinedButton.styleFrom(
                                                side: BorderSide(
                                                  color: Colors.white.withValues(
                                                    alpha: 0.2,
                                                  ),
                                                ),
                                              ),
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: Colors.white70,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  _updateAppointmentStatus(
                                                context,
                                                appointmentId,
                                                'confirmed',
                                              ),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppColors.gold,
                                                foregroundColor:
                                                    const Color(0xFF05070A),
                                              ),
                                              child: const Text('Confirm'),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
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
          );
        },
      ),
    );
  }
}

String _formatDateTime(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'confirmed':
        color = Colors.blue;
        break;
      case 'done':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      case 'pending':
        color = AppColors.gold;
        break;
      default:
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
