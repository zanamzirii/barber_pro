import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class MyAppointmentsScreen extends StatelessWidget {
  const MyAppointmentsScreen({super.key});

  Future<void> _cancelPendingAppointment(
    BuildContext context,
    String appointmentId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointmentId)
          .update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
          });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment cancelled'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not cancel appointment'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in again')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Appointments')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('customerId', isEqualTo: user.uid)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No appointments yet'),
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
            itemCount: docs.length,
            separatorBuilder: (_, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final appointmentId = docs[index].id;
              final data = docs[index].data();
              final serviceName = (data['serviceName'] as String?) ?? 'Service';
              final barberName = (data['barberName'] as String?) ?? 'Barber';
              final status = (data['status'] as String?) ?? 'pending';
              final startAt = data['startAt'] as Timestamp?;
              final dt = startAt?.toDate();
              final when = dt == null
                  ? 'No time set'
                  : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

              return ListTile(
                leading: const Icon(Icons.event_available),
                title: Text('$serviceName • $barberName'),
                subtitle: Text(when),
                trailing: status.toLowerCase() == 'pending'
                    ? TextButton(
                        onPressed: () =>
                            _cancelPendingAppointment(context, appointmentId),
                        child: const Text('Cancel'),
                      )
                    : _StatusChip(status: status),
              );
            },
          );
        },
      ),
    );
  }
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
