import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/data/firestore_data_mapper.dart';
import 'barber_schedule_screen.dart';

class BarberDashboardScreen extends StatefulWidget {
  const BarberDashboardScreen({super.key, this.onOpenScheduleTab});

  final VoidCallback? onOpenScheduleTab;

  @override
  State<BarberDashboardScreen> createState() => _BarberDashboardScreenState();
}

class _BarberDashboardScreenState extends State<BarberDashboardScreen> {
  bool _acceptWalkIns = true;

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
      return const Scaffold(
        backgroundColor: Color(0xFF05070A),
        body: Center(child: Text('Please log in again')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('barberId', isEqualTo: user.uid)
            .limit(200)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            );
          }

          final appointments = _mapAppointments(
            snapshot.data?.docs ?? const [],
          );
          final now = DateTime.now();
          final todayAppointments = appointments
              .where((a) => _isSameDay(a.startAt, now) && !a.isCancelled)
              .toList();
          final bookedMinutes = todayAppointments.fold<int>(
            0,
            (total, a) => total + a.durationMinutes,
          );
          final bookedHoursText = '${(bookedMinutes / 60).toStringAsFixed(1)}h';

          final inProgress = _pickInProgress(appointments, now);
          final nextUp = _pickNextUp(appointments, now, inProgress?.id);
          final scheduled = _pickScheduled(
            appointments,
            now,
            inProgress?.id,
            nextUp?.id,
          );

          return SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
                Row(
                  children: [
                    const Text(
                      'Today',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    InkWell(
                      onTap: () {
                        final callback = widget.onOpenScheduleTab;
                        if (callback != null) {
                          callback();
                          return;
                        }
                        Navigator.of(context).push(
                          Motion.pageRoute(
                            builder: (_) => const BarberScheduleScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFF070A12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Icon(
                          Icons.calendar_today_rounded,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _statCard(
                        value: '${todayAppointments.length}',
                        label: 'APPOINTMENTS',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statCard(value: bookedHoursText, label: 'BOOKED'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF070A12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.person_add_alt_1_rounded,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Accept Walk-ins',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Switch(
                        value: _acceptWalkIns,
                        activeThumbColor: const Color(0xFF05070A),
                        activeTrackColor: AppColors.gold,
                        onChanged: (v) => setState(() => _acceptWalkIns = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (inProgress != null)
                  _inProgressCard(
                    inProgress,
                    onComplete: () => _updateAppointmentStatus(
                      context,
                      inProgress.id,
                      'done',
                    ),
                  ),
                if (inProgress != null) const SizedBox(height: 12),
                if (nextUp != null) _nextUpCard(nextUp, onView: () {}),
                if (nextUp != null) const SizedBox(height: 12),
                ...scheduled.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _scheduledCard(a),
                  ),
                ),
                if (scheduled.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '- BREAK 13:00 - 14:00 -',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Divider(
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCard({required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF070A12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: AppColors.gold.withValues(alpha: 0.65),
              fontSize: 10,
              letterSpacing: 2.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarberAppointment {
  const _BarberAppointment({
    required this.id,
    required this.customerName,
    required this.serviceName,
    required this.status,
    required this.startAt,
    required this.durationMinutes,
  });

  final String id;
  final String customerName;
  final String serviceName;
  final String status;
  final DateTime startAt;
  final int durationMinutes;

  DateTime get endAt => startAt.add(Duration(minutes: durationMinutes));
  bool get isDone => status.toLowerCase() == 'done';
  bool get isCancelled => status.toLowerCase() == 'cancelled';
}

List<_BarberAppointment> _mapAppointments(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final result = <_BarberAppointment>[];
  for (final doc in docs) {
    final data = doc.data();
    final ts = data['startAt'] as Timestamp?;
    if (ts == null) continue;
    result.add(
      _BarberAppointment(
        id: doc.id,
        customerName: FirestoreDataMapper.customerFullName(data),
        serviceName: FirestoreDataMapper.serviceName(data),
        status: (data['status'] as String?) ?? 'pending',
        startAt: ts.toDate(),
        durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 30,
      ),
    );
  }
  result.sort((a, b) => a.startAt.compareTo(b.startAt));
  return result;
}

_BarberAppointment? _pickInProgress(
  List<_BarberAppointment> list,
  DateTime now,
) {
  for (final a in list) {
    final status = a.status.toLowerCase();
    if (a.isDone || a.isCancelled) continue;
    if (status == 'in_progress' || status == 'in-progress') return a;
    if ((status == 'confirmed' || status == 'pending') &&
        now.isAfter(a.startAt) &&
        now.isBefore(a.endAt)) {
      return a;
    }
  }
  return null;
}

_BarberAppointment? _pickNextUp(
  List<_BarberAppointment> list,
  DateTime now,
  String? excludeId,
) {
  for (final a in list) {
    if (a.id == excludeId || a.isDone || a.isCancelled) continue;
    if (a.startAt.isAfter(now)) return a;
  }
  return null;
}

List<_BarberAppointment> _pickScheduled(
  List<_BarberAppointment> list,
  DateTime now,
  String? inProgressId,
  String? nextUpId,
) {
  return list
      .where((a) {
        if (a.id == inProgressId || a.id == nextUpId) return false;
        if (a.isDone || a.isCancelled) return false;
        return a.startAt.isAfter(now.subtract(const Duration(hours: 1)));
      })
      .take(4)
      .toList();
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _timeRange(_BarberAppointment a) {
  String two(int v) => v.toString().padLeft(2, '0');
  final from = '${two(a.startAt.hour)}:${two(a.startAt.minute)}';
  final to = '${two(a.endAt.hour)}:${two(a.endAt.minute)}';
  return '$from - $to';
}

Widget _inProgressCard(
  _BarberAppointment a, {
  required VoidCallback onComplete,
}) {
  final now = DateTime.now();
  final startedMin = now.difference(a.startAt).inMinutes.clamp(0, 999);
  final elapsed = now.difference(a.startAt).inMinutes;
  final progress = elapsed <= 0
      ? 0.0
      : (elapsed / a.durationMinutes).clamp(0.0, 1.0);

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF070A12),
      borderRadius: BorderRadius.circular(18),
      border: Border(
        left: BorderSide(color: const Color(0xFF10B981), width: 3),
      ),
      boxShadow: const [
        BoxShadow(color: Color(0x2610B981), blurRadius: 20, spreadRadius: -3),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'IN PROGRESS',
              style: TextStyle(
                color: Color(0xFF10B981),
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            const Spacer(),
            Text(
              'Started $startedMin min ago',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          a.customerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          a.serviceName,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 5,
            backgroundColor: const Color(0xFF1F2937),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              _timeRange(a),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: onComplete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: const Color(0xFF05070A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'COMPLETE SESSION',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _nextUpCard(_BarberAppointment a, {required VoidCallback onView}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF070A12),
      borderRadius: BorderRadius.circular(18),
      border: Border(left: BorderSide(color: AppColors.gold, width: 3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                a.customerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 33,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.gold.withValues(alpha: 0.25),
                ),
              ),
              child: const Text(
                'NEXT UP',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          a.serviceName,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Text(
              _timeRange(a),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: onView,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.gold.withValues(alpha: 0.35)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'VIEW DETAILS',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _scheduledCard(_BarberAppointment a) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0x66070A12),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                a.customerName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontSize: 29,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'SCHEDULED',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          a.serviceName,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              _timeRange(a),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: null,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'VIEW',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
