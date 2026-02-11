import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class MyAppointmentsScreen extends StatefulWidget {
  const MyAppointmentsScreen({super.key});

  @override
  State<MyAppointmentsScreen> createState() => _MyAppointmentsScreenState();
}

class _MyAppointmentsScreenState extends State<MyAppointmentsScreen> {
  bool _showUpcoming = true;

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
            'updatedAt': FieldValue.serverTimestamp(),
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

  void _showDetails(BuildContext context, _AppointmentView view) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0B0F1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Appointment Details',
              style: TextStyle(
                fontFamily: 'PlayfairDisplay',
                fontSize: 24,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              view.serviceName,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontFamily: 'PlayfairDisplay',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Date: ${view.dateAndTime}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
              ),
            ),
            Text(
              'Branch: ${view.branchName}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
              ),
            ),
            Text(
              'Status: ${view.statusLabel}',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.75),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
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

    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      body: Stack(
        children: [
          const _SilkyBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'My Appointments',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 25,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _TabsHeader(
                    showUpcoming: _showUpcoming,
                    onUpcoming: () => setState(() => _showUpcoming = true),
                    onPast: () => setState(() => _showUpcoming = false),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('appointments')
                        .where('customerId', isEqualTo: user.uid)
                        .limit(150)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.gold,
                            strokeWidth: 2.2,
                          ),
                        );
                      }

                      final docs = snapshot.data?.docs ?? const [];
                      final now = DateTime.now();
                      final appointments = docs
                          .map(_AppointmentView.fromDoc)
                          .toList();

                      final upcoming =
                          appointments.where((a) {
                            if (a.isCancelled || a.isDone) return false;
                            if (a.startAt == null) return true;
                            return !a.startAt!.isBefore(now);
                          }).toList()..sort((a, b) {
                            final aMs =
                                a.startAt?.millisecondsSinceEpoch ?? (1 << 62);
                            final bMs =
                                b.startAt?.millisecondsSinceEpoch ?? (1 << 62);
                            return aMs.compareTo(bMs);
                          });

                      final past =
                          appointments.where((a) {
                            if (a.isCancelled || a.isDone) return true;
                            if (a.startAt == null) return false;
                            return a.startAt!.isBefore(now);
                          }).toList()..sort((a, b) {
                            final aMs = a.startAt?.millisecondsSinceEpoch ?? 0;
                            final bMs = b.startAt?.millisecondsSinceEpoch ?? 0;
                            return bMs.compareTo(aMs);
                          });

                      final visible = _showUpcoming ? upcoming : past;

                      if (appointments.isEmpty) {
                        return Center(
                          child: Text(
                            'No appointments yet',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 14,
                            ),
                          ),
                        );
                      }

                      if (visible.isEmpty) {
                        return Center(
                          child: Text(
                            _showUpcoming
                                ? 'No upcoming appointments'
                                : 'No past appointments',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.65),
                              fontSize: 14,
                            ),
                          ),
                        );
                      }

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                        children: [
                          if (_showUpcoming)
                            ...visible.map(
                              (view) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _AppointmentCard(
                                  view: view,
                                  showPrimaryActions: true,
                                  onPrimary: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Reschedule flow will be added in next step',
                                        ),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  onSecondary: view.isPending
                                      ? () => _cancelPendingAppointment(
                                          context,
                                          view.id,
                                        )
                                      : null,
                                  onDetails: () => _showDetails(context, view),
                                ),
                              ),
                            )
                          else ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(2, 0, 2, 10),
                              child: Text(
                                'PAST APPOINTMENTS',
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 4,
                                  color: Colors.white.withValues(alpha: 0.35),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            ...visible.map(
                              (view) => Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: _AppointmentCard(
                                  view: view,
                                  showPrimaryActions: false,
                                  onDetails: () => _showDetails(context, view),
                                ),
                              ),
                            ),
                          ],
                        ],
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

class _TabsHeader extends StatelessWidget {
  const _TabsHeader({
    required this.showUpcoming,
    required this.onUpcoming,
    required this.onPast,
  });

  final bool showUpcoming;
  final VoidCallback onUpcoming;
  final VoidCallback onPast;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: onUpcoming,
            child: Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: showUpcoming
                        ? AppColors.gold
                        : Colors.white.withValues(alpha: 0.10),
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                'UPCOMING',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700,
                  color: showUpcoming
                      ? AppColors.text
                      : Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: InkWell(
            onTap: onPast,
            child: Container(
              padding: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: !showUpcoming
                        ? AppColors.gold
                        : Colors.white.withValues(alpha: 0.10),
                    width: 2,
                  ),
                ),
              ),
              child: Text(
                'PAST',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.w700,
                  color: !showUpcoming
                      ? AppColors.text
                      : Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.view,
    required this.showPrimaryActions,
    this.onPrimary,
    this.onSecondary,
    this.onDetails,
  });

  final _AppointmentView view;
  final bool showPrimaryActions;
  final VoidCallback? onPrimary;
  final VoidCallback? onSecondary;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final muted = Colors.white.withValues(alpha: 0.4);
    final body = Colors.white.withValues(alpha: 0.88);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(
          0xFF121620,
        ).withValues(alpha: showPrimaryActions ? 0.42 : 0.34),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                      'SERVICE',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 2.2,
                        color: muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      view.serviceName,
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        fontSize: 20,
                        height: 1.15,
                        color: showPrimaryActions
                            ? AppColors.text
                            : Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                status: view.statusLabel,
                isActive: showPrimaryActions,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _InfoItem(
                  icon: Icons.calendar_today,
                  label: 'DATE & TIME',
                  value: view.dateAndTime,
                  valueColor: body,
                ),
              ),
              Expanded(
                child: _InfoItem(
                  icon: Icons.location_on_outlined,
                  label: 'BRANCH',
                  value: view.branchName,
                  valueColor: body,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 14),
          if (showPrimaryActions)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onPrimary,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.gold.withValues(alpha: 0.35),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'RESCHEDULE',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 10,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSecondary,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 10,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onDetails,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(
                  'VIEW DETAILS',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 10,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status, required this.isActive});

  final String status;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isConfirmed = status.toLowerCase() == 'confirmed';
    final bg = isActive
        ? (isConfirmed
              ? AppColors.gold.withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.07))
        : Colors.white.withValues(alpha: 0.07);
    final fg = isActive && isConfirmed
        ? AppColors.gold
        : Colors.white.withValues(alpha: 0.40);
    final border = isActive && isConfirmed
        ? AppColors.gold.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.10);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: fg,
          fontSize: 9,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.gold.withValues(alpha: 0.9)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.8,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: valueColor,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
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

class _AppointmentView {
  _AppointmentView({
    required this.id,
    required this.serviceName,
    required this.status,
    required this.startAt,
    required this.branchName,
  });

  final String id;
  final String serviceName;
  final String status;
  final DateTime? startAt;
  final String branchName;

  bool get isPending => status.toLowerCase() == 'pending';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
  bool get isDone => status.toLowerCase() == 'done';

  String get statusLabel {
    if (isDone) return 'Completed';
    if (isCancelled) return 'Cancelled';
    if (status.toLowerCase() == 'confirmed') return 'Confirmed';
    return 'Pending';
  }

  String get dateAndTime {
    if (startAt == null) return 'Not set';
    final d = startAt!;
    final month = _monthShort(d.month);
    final hour12 = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final minute = d.minute.toString().padLeft(2, '0');
    final suffix = d.hour >= 12 ? 'PM' : 'AM';
    return '${d.day} $month, $hour12:$minute $suffix';
  }

  static _AppointmentView fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return _AppointmentView(
      id: doc.id,
      serviceName:
          ((data['serviceName'] as String?)?.trim().isNotEmpty ?? false)
          ? (data['serviceName'] as String).trim()
          : 'Service',
      status: ((data['status'] as String?)?.trim().isNotEmpty ?? false)
          ? (data['status'] as String).trim()
          : 'pending',
      startAt: (data['startAt'] as Timestamp?)?.toDate(),
      branchName: ((data['shopName'] as String?)?.trim().isNotEmpty ?? false)
          ? (data['shopName'] as String).trim()
          : (((data['branchName'] as String?)?.trim().isNotEmpty ?? false)
                ? (data['branchName'] as String).trim()
                : 'Mayfair Elite'),
    );
  }
}

String _monthShort(int month) {
  const names = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return names[(month - 1).clamp(0, 11)];
}
