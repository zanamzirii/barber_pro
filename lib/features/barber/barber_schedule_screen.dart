import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/data/firestore_data_mapper.dart';

class BarberScheduleScreen extends StatefulWidget {
  const BarberScheduleScreen({super.key});

  @override
  State<BarberScheduleScreen> createState() => _BarberScheduleScreenState();
}

class _BarberScheduleScreenState extends State<BarberScheduleScreen> {
  bool _showWeek = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.shellBackground,
        body: Center(child: Text('Please log in again')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.shellBackground,
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

          final all = _mapAppointments(snapshot.data?.docs ?? []);
          final now = DateTime.now();
          final dayAppointments =
              all
                  .where((a) => _isSameDay(a.startAt, now) && !a.isCancelled)
                  .toList()
                ..sort((a, b) => a.startAt.compareTo(b.startAt));

          final inProgress = _pickInProgress(dayAppointments, now);
          final nextUp = _pickNextUp(dayAppointments, now, inProgress?.id);
          final others = dayAppointments
              .where(
                (a) =>
                    a.id != inProgress?.id &&
                    a.id != nextUp?.id &&
                    !a.isDone &&
                    !a.isCancelled,
              )
              .toList();

          final weekDays = _weekDays(now);

          return SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
                Row(
                  children: [
                    const Text(
                      'Schedule',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'TODAY',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.ownerDashboardCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: AppColors.gold,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.ownerDashboardCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.onDark06),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _showWeek = false),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: _showWeek
                                  ? AppColors.transparent
                                  : AppColors.gold,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'DAY',
                              style: TextStyle(
                                color: _showWeek
                                    ? AppColors.slate450
                                    : AppColors.shellBackground,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _showWeek = true),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            height: 36,
                            decoration: BoxDecoration(
                              color: _showWeek
                                  ? AppColors.gold
                                  : AppColors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'WEEK',
                              style: TextStyle(
                                color: _showWeek
                                    ? AppColors.shellBackground
                                    : AppColors.slate450,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (!_showWeek) ...[
                  SizedBox(
                    height: 70,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        final d = weekDays[index];
                        final selected = _isSameDay(d, now);
                        return Container(
                          width: 56,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.gold
                                : AppColors.ownerDashboardCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? AppColors.gold
                                  : Colors.white.withValues(alpha: 0.07),
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _weekdayShort(d),
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.shellBackground
                                      : AppColors.slate300,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${d.day}',
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.shellBackground
                                      : Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                              if (selected) ...[
                                const SizedBox(height: 2),
                                const CircleAvatar(
                                  radius: 2,
                                  backgroundColor: AppColors.shellBackground,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemCount: weekDays.length,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _timelineBody(
                    context: context,
                    inProgress: inProgress,
                    nextUp: nextUp,
                    others: others,
                  ),
                ] else ...[
                  const SizedBox(height: 2),
                  _weekView(all, now, weekDays),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _timelineBody({
    required BuildContext context,
    required _BarberAppointment? inProgress,
    required _BarberAppointment? nextUp,
    required List<_BarberAppointment> others,
  }) {
    final items = <Widget>[];

    void addItem(_BarberAppointment a, {required _TimelineType type}) {
      items.add(_timelineItem(a, type: type));
      items.add(const SizedBox(height: 14));
    }

    if (inProgress != null) addItem(inProgress, type: _TimelineType.inProgress);
    if (nextUp != null) addItem(nextUp, type: _TimelineType.nextUp);
    for (final a in others.take(3)) {
      addItem(a, type: _TimelineType.scheduled);
      if (a == others.first) {
        items.add(_breakRow());
        items.add(const SizedBox(height: 14));
      }
    }

    if (items.isNotEmpty) items.removeLast();

    return Stack(
      children: [
        Positioned(
          left: 17,
          top: 8,
          bottom: 8,
          child: Container(width: 1, color: AppColors.onDark08),
        ),
        Column(children: items),
      ],
    );
  }

  Widget _weekView(
    List<_BarberAppointment> all,
    DateTime now,
    List<DateTime> weekDays,
  ) {
    final cards = weekDays.map((d) {
      final dayItems = all
          .where((a) => _isSameDay(a.startAt, d) && !a.isCancelled)
          .toList();
      final bookedMinutes = dayItems.fold<int>(
        0,
        (t, a) => t + a.durationMinutes,
      );
      const totalMinutes = 8 * 60;
      final ratio = (bookedMinutes / totalMinutes).clamp(0.0, 1.0);
      final selected = _isSameDay(d, now);
      final isNone = dayItems.isEmpty;

      Color progressColor;
      if (selected && ratio > 0.75) {
        progressColor = AppColors.danger;
      } else if (ratio >= 0.5) {
        progressColor = AppColors.warning;
      } else {
        progressColor = AppColors.success;
      }

      final bg = selected
          ? AppColors.gold.withValues(alpha: 0.08)
          : AppColors.ownerDashboardCard;
      final border = selected
          ? AppColors.gold.withValues(alpha: 0.35)
          : AppColors.onDark06;

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.15),
                    blurRadius: 18,
                    spreadRadius: -6,
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _weekdayShort(d),
                        style: TextStyle(
                          color: selected ? AppColors.gold : AppColors.onDark50,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${d.day}',
                        style: TextStyle(
                          color: selected ? AppColors.gold : Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      isNone
                          ? 'NO BOOKINGS'
                          : '${dayItems.length} APPOINTMENTS',
                      style: TextStyle(
                        color: isNone
                            ? AppColors.onDark45
                            : (selected ? AppColors.gold : AppColors.onDark50),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isNone
                          ? 'Fully Available'
                          : '${(bookedMinutes / 60).toStringAsFixed((bookedMinutes % 60 == 0) ? 0 : 1)}h / 8h Booked',
                      style: TextStyle(
                        color: isNone
                            ? AppColors.success
                            : (selected
                                  ? Colors.white.withValues(alpha: 0.88)
                                  : Colors.white.withValues(alpha: 0.78)),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isNone ? AppColors.slate700 : progressColor,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();

    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          cards[i],
          if (i != cards.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _timelineItem(_BarberAppointment a, {required _TimelineType type}) {
    final markerColor = switch (type) {
      _TimelineType.inProgress => AppColors.success,
      _TimelineType.nextUp => AppColors.gold,
      _ => AppColors.slate500,
    };

    final leftBorder = switch (type) {
      _TimelineType.inProgress => AppColors.success,
      _TimelineType.nextUp => AppColors.gold,
      _ => AppColors.slate600,
    };

    final badge = switch (type) {
      _TimelineType.inProgress => _badge('IN PROGRESS', AppColors.success),
      _TimelineType.nextUp => _badge('NEXT UP', AppColors.gold, darkText: true),
      _ => _badge('SCHEDULED', AppColors.slate300),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: markerColor,
                  shape: BoxShape.circle,
                  boxShadow: type == _TimelineType.scheduled
                      ? null
                      : [
                          BoxShadow(
                            color: markerColor.withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _hourMinute(a.startAt),
                style: TextStyle(
                  color: type == _TimelineType.nextUp
                      ? AppColors.gold
                      : AppColors.onDark70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.ownerDashboardCard,
              borderRadius: BorderRadius.circular(16),
              border: Border(
                left: BorderSide(color: leftBorder, width: 3),
                top: BorderSide(color: AppColors.onDark05),
                right: BorderSide(color: AppColors.onDark05),
                bottom: BorderSide(color: AppColors.onDark05),
              ),
              boxShadow: type == _TimelineType.nextUp
                  ? [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        blurRadius: 20,
                        spreadRadius: -5,
                      ),
                    ]
                  : null,
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
                          fontSize: 36,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    badge,
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  a.serviceName,
                  style: TextStyle(
                    color: type == _TimelineType.nextUp
                        ? AppColors.gold
                        : AppColors.onDark55,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                if (type == _TimelineType.nextUp)
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.shellBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'VIEW DETAILS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  )
                else
                  Row(
                    children: [
                      Text(
                        _timeRange(a),
                        style: TextStyle(
                          color: AppColors.onDark45,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: type == _TimelineType.inProgress
                                ? AppColors.gold.withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.15),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          'VIEW',
                          style: TextStyle(
                            color: type == _TimelineType.inProgress
                                ? AppColors.gold
                                : AppColors.onDark50,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _breakRow() {
    return Row(
      children: [
        const SizedBox(width: 34),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.07)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'BREAK 13:00 - 14:00',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.33),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Colors.white.withValues(alpha: 0.07)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _badge(String text, Color color, {bool darkText = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: darkText ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: darkText ? AppColors.shellBackground : color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}

enum _TimelineType { inProgress, nextUp, scheduled }

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

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _hourMinute(DateTime d) {
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _timeRange(_BarberAppointment a) {
  final from = _hourMinute(a.startAt);
  final to = _hourMinute(a.endAt);
  return '$from - $to';
}

List<DateTime> _weekDays(DateTime reference) {
  final monday = reference.subtract(Duration(days: reference.weekday - 1));
  return List<DateTime>.generate(5, (i) => monday.add(Duration(days: i)));
}

String _weekdayShort(DateTime d) {
  const names = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return names[d.weekday - 1];
}
