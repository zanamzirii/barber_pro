import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_shell.dart';
import '../../role_switcher.dart';
import '../shared/firestore_data_mapper.dart';
import '../shared/account_screen.dart';

class BarberDashboardScreen extends StatelessWidget {
  const BarberDashboardScreen({super.key});

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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in again')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barber Dashboard'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const AccountScreen()));
            },
            icon: const Icon(Icons.person_outline),
            tooltip: 'Account',
          ),
          IconButton(
            onPressed: () => RoleSwitcher.show(context),
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch Role',
          ),
          IconButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: user.uid));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('UID copied. Send it to owner.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy),
            tooltip: 'Copy My UID',
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
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('barberId', isEqualTo: user.uid)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No appointments assigned yet'));
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
              final customerName = FirestoreDataMapper.customerFullName(data);
              final serviceName = FirestoreDataMapper.serviceName(data);
              final status = (data['status'] as String?) ?? 'pending';
              final startAt = data['startAt'] as Timestamp?;
              final when = startAt == null
                  ? 'No time set'
                  : _formatDateTime(startAt.toDate());

              final isConfirmed = status.toLowerCase() == 'confirmed';

              return ListTile(
                leading: const Icon(Icons.content_cut),
                title: Text('$customerName - $serviceName'),
                subtitle: Text(when),
                trailing: isConfirmed
                    ? TextButton(
                        onPressed: () => _updateAppointmentStatus(
                          context,
                          appointmentId,
                          'done',
                        ),
                        child: const Text('Mark Done'),
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
