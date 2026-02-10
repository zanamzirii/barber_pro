import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'owner_data.dart';

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
      appBar: AppBar(title: const Text('Appointments')),
      body: FutureBuilder<String>(
        future: _getShopId(),
        builder: (context, shopSnapshot) {
          if (shopSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final shopId = shopSnapshot.data ?? '';
          if (shopId.isEmpty) {
            return const Center(child: Text('No shop assigned'));
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('appointments')
                .where('shopId', isEqualTo: shopId)
                .limit(100)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No appointments yet'));
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
                itemCount: docs.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final appointmentId = docs[index].id;
                  final data = docs[index].data();
                  final customerName =
                      (data['customerName'] as String?) ?? 'Unknown';
                  final serviceName =
                      (data['serviceName'] as String?) ?? 'Service';
                  final barberName =
                      (data['barberName'] as String?) ?? 'Barber';
                  final status = (data['status'] as String?) ?? 'pending';
                  final startAt = data['startAt'] as Timestamp?;
                  final startAtText = startAt == null
                      ? 'No time set'
                      : _formatDateTime(startAt.toDate());

                  return ListTile(
                    title: Text('$customerName - $serviceName'),
                    subtitle: Text('$barberName\n$startAtText'),
                    isThreeLine: true,
                    trailing: status.toLowerCase() == 'pending'
                        ? Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => _updateAppointmentStatus(
                                  context,
                                  appointmentId,
                                  'confirmed',
                                ),
                                child: const Text('Confirm'),
                              ),
                              TextButton(
                                onPressed: () => _updateAppointmentStatus(
                                  context,
                                  appointmentId,
                                  'cancelled',
                                ),
                                child: const Text('Cancel'),
                              ),
                            ],
                          )
                        : _StatusChip(status: status),
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
        status,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
