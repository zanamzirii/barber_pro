import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class BarberAvailabilityScreen extends StatefulWidget {
  const BarberAvailabilityScreen({super.key});

  @override
  State<BarberAvailabilityScreen> createState() =>
      _BarberAvailabilityScreenState();
}

class _BarberAvailabilityScreenState extends State<BarberAvailabilityScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _lastSavedFingerprint = '';
  String? _selectedShopId;

  late List<_DayRow> _days;
  List<_BreakRow> _breaks = <_BreakRow>[];
  int _bufferMinutes = 10;
  List<_ExceptionRow> _exceptions = <_ExceptionRow>[];
  bool _vacationMode = false;
  DateTime? _vacationStartDate;
  DateTime? _vacationEndDate;
  final TextEditingController _vacationNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _days = <_DayRow>[
      // Iraq week order: Sunday -> Saturday
      _DayRow(
        id: 'sun',
        label: 'Sunday',
        enabled: true,
        start: '09:00',
        end: '18:00',
      ),
      _DayRow(
        id: 'mon',
        label: 'Monday',
        enabled: true,
        start: '09:00',
        end: '18:00',
      ),
      _DayRow(
        id: 'tue',
        label: 'Tuesday',
        enabled: true,
        start: '09:00',
        end: '18:00',
      ),
      _DayRow(
        id: 'wed',
        label: 'Wednesday',
        enabled: true,
        start: '09:00',
        end: '18:00',
      ),
      _DayRow(
        id: 'thu',
        label: 'Thursday',
        enabled: true,
        start: '09:00',
        end: '17:00',
      ),
      _DayRow(
        id: 'fri',
        label: 'Friday',
        enabled: true,
        start: '09:00',
        end: '18:00',
      ),
      _DayRow(
        id: 'sat',
        label: 'Saturday',
        enabled: true,
        start: '10:00',
        end: '14:00',
      ),
    ];
    _load();
  }

  @override
  void dispose() {
    _vacationNoteController.dispose();
    super.dispose();
  }

  String _stateFingerprint() {
    final map = <String, dynamic>{
      'weekly': _days
          .map(
            (d) => <String, dynamic>{
              'id': d.id,
              'enabled': d.enabled,
              'start': d.start,
              'end': d.end,
            },
          )
          .toList(),
      'breaks': _breaks
          .map(
            (b) => <String, dynamic>{
              'enabled': b.enabled,
              'start': b.start,
              'end': b.end,
            },
          )
          .toList(),
      'bufferMinutes': _bufferMinutes,
      'exceptions': _exceptions
          .map(
            (e) => <String, dynamic>{
              'date': _dateKey(e.date),
              'isDayOff': e.isDayOff,
              'start': e.start,
              'end': e.end,
            },
          )
          .toList(),
      'vacation': <String, dynamic>{
        'enabled': _vacationMode,
        'start': _vacationStartDate == null
            ? null
            : _dateKey(_vacationStartDate!),
        'end': _vacationEndDate == null ? null : _dateKey(_vacationEndDate!),
        'note': _vacationNoteController.text.trim(),
      },
    };
    return jsonEncode(map);
  }

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime? _parseDate(dynamic raw) {
    if (raw is Timestamp) return _dateOnly(raw.toDate());
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return _dateOnly(parsed);
    }
    return null;
  }

  Timestamp? _toStartTimestamp(DateTime? d) {
    if (d == null) return null;
    return Timestamp.fromDate(DateTime(d.year, d.month, d.day));
  }

  Timestamp? _toEndTimestamp(DateTime? d) {
    if (d == null) return null;
    return Timestamp.fromDate(DateTime(d.year, d.month, d.day, 23, 59, 59));
  }

  bool get _hasUnsavedChanges {
    if (_isLoading) return false;
    return _stateFingerprint() != _lastSavedFingerprint;
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      _selectedShopId = (doc.data()?['selectedShopId'] as String?)?.trim();
      final map = doc.data()?['barberAvailability'];
      if (map is Map<String, dynamic>) {
        final weekly = map['weekly'];
        if (weekly is Map<String, dynamic>) {
          _days = _days.map((d) {
            final raw = weekly[d.id];
            if (raw is! Map<String, dynamic>) return d;
            return d.copyWith(
              enabled: raw['enabled'] is bool
                  ? raw['enabled'] as bool
                  : d.enabled,
              start: raw['start'] is String ? raw['start'] as String : d.start,
              end: raw['end'] is String ? raw['end'] as String : d.end,
            );
          }).toList();
        }
        final rawBreaks = map['breaks'];
        if (rawBreaks is List) {
          _breaks = rawBreaks
              .whereType<Map>()
              .map((raw) {
                final start = (raw['start'] ?? '').toString();
                final end = (raw['end'] ?? '').toString();
                if (!_isHHmm(start) || !_isHHmm(end)) return null;
                return _BreakRow(
                  enabled: raw['enabled'] is bool
                      ? raw['enabled'] as bool
                      : true,
                  start: start,
                  end: end,
                );
              })
              .whereType<_BreakRow>()
              .toList();
        } else if (rawBreaks is Map<String, dynamic>) {
          // Backward compatibility for previous single lunch schema.
          final lunch = rawBreaks['lunch'];
          if (lunch is Map<String, dynamic>) {
            final start = (lunch['start'] ?? '').toString();
            final end = (lunch['end'] ?? '').toString();
            if (_isHHmm(start) && _isHHmm(end)) {
              _breaks = <_BreakRow>[
                _BreakRow(
                  enabled: lunch['enabled'] is bool
                      ? lunch['enabled'] as bool
                      : true,
                  start: start,
                  end: end,
                ),
              ];
            }
          }
        }
        if (map['bufferMinutes'] is num) {
          final value = (map['bufferMinutes'] as num).toInt();
          if (const <int>[0, 5, 10, 15].contains(value)) _bufferMinutes = value;
        }
        final rawVacation = map['vacation'];
        if (rawVacation is Map<String, dynamic>) {
          _vacationMode = rawVacation['enabled'] == true;
          _vacationStartDate = _parseDate(rawVacation['start']);
          _vacationEndDate = _parseDate(rawVacation['end']);
          _vacationNoteController.text =
              (rawVacation['note'] as String?)?.trim() ?? '';
          if (_vacationMode &&
              _vacationEndDate != null &&
              _dateOnly(
                _vacationEndDate!,
              ).isBefore(_dateOnly(DateTime.now()))) {
            _vacationMode = false;
          }
        }
        final rawEx = map['exceptions'];
        if (rawEx is List) {
          _exceptions = rawEx.whereType<Map>().map((e) {
            final date =
                DateTime.tryParse((e['date'] ?? '').toString()) ??
                DateTime.now();
            final isDayOff = (e['type'] ?? '').toString() == 'day_off';
            return _ExceptionRow(
              date: DateTime(date.year, date.month, date.day),
              isDayOff: isDayOff,
              start: (e['start'] ?? '').toString(),
              end: (e['end'] ?? '').toString(),
            );
          }).toList()..sort((a, b) => a.date.compareTo(b.date));
        }
      }
    } catch (_) {
      if (mounted) _snack('Could not load availability');
    } finally {
      _lastSavedFingerprint = _stateFingerprint();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _save() async {
    if (_isSaving) return false;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    if (!_hasUnsavedChanges) return true;
    final breaksError = _validateBreaks();
    if (breaksError != null) {
      _snack(breaksError);
      return false;
    }
    if (_vacationMode &&
        (_vacationStartDate == null || _vacationEndDate == null)) {
      _snack('Set vacation start and end date');
      return false;
    }
    if (_vacationMode &&
        _vacationStartDate != null &&
        _vacationEndDate != null &&
        _dateOnly(_vacationEndDate!).isBefore(_dateOnly(_vacationStartDate!))) {
      _snack('Vacation end date must be after start date');
      return false;
    }
    setState(() => _isSaving = true);
    try {
      final weekly = <String, dynamic>{
        for (final d in _days)
          d.id: <String, dynamic>{
            'enabled': d.enabled,
            'start': d.start,
            'end': d.end,
          },
      };
      final payload = <String, dynamic>{
        'weekStartsOn': 'sunday',
        'timezone': 'Asia/Baghdad',
        'weekly': weekly,
        'breaks': _breaks
            .map(
              (b) => <String, dynamic>{
                'enabled': b.enabled,
                'start': b.start,
                'end': b.end,
              },
            )
            .toList(),
        'bufferMinutes': _bufferMinutes,
        'exceptions': _exceptions
            .map(
              (e) => <String, dynamic>{
                'date': e.date.toIso8601String(),
                'type': e.isDayOff ? 'day_off' : 'custom_hours',
                'start': e.start,
                'end': e.end,
              },
            )
            .toList(),
        'vacation': <String, dynamic>{
          'enabled': _vacationMode,
          'start': _vacationStartDate == null
              ? null
              : _dateKey(_vacationStartDate!),
          'end': _vacationEndDate == null ? null : _dateKey(_vacationEndDate!),
          'note': _vacationNoteController.text.trim(),
        },
      };
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'barberAvailability': payload,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _syncVacationToBranch(user.uid);
      _lastSavedFingerprint = _stateFingerprint();
      if (mounted) _snack('Availability saved');
      return true;
    } catch (_) {
      if (mounted) _snack('Could not save availability');
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _confirmLeaveIfNeeded() async {
    if (_isSaving) return false;
    if (!_hasUnsavedChanges) return true;
    final action = await showDialog<_UnsavedAction>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.ownerDashboardCard,
          title: const Text(
            'Save changes?',
            style: TextStyle(
              color: AppColors.text,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'You have unsaved availability changes.',
            style: TextStyle(color: AppColors.onDark65),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_UnsavedAction.cancel),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.onDark70),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_UnsavedAction.discard),
              child: const Text(
                'Discard',
                style: TextStyle(color: AppColors.danger),
              ),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_UnsavedAction.save),
              child: const Text(
                'Save',
                style: TextStyle(color: AppColors.gold),
              ),
            ),
          ],
        );
      },
    );

    if (action == _UnsavedAction.discard) return true;
    if (action == _UnsavedAction.save) return _save();
    return false;
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  int _toMinutes(String hhmm) {
    final p = hhmm.split(':');
    if (p.length != 2) return -1;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return -1;
    return (h * 60) + m;
  }

  bool _isHHmm(String value) => _toMinutes(value) >= 0;

  String? _validateBreaks() {
    final active = _breaks.where((b) => b.enabled).toList();

    for (final b in active) {
      final start = _toMinutes(b.start);
      final end = _toMinutes(b.end);
      if (start < 0 || end < 0) return 'Break time format is invalid';
      if (end <= start) return 'Break end must be after start';
    }

    active.sort((a, b) => _toMinutes(a.start).compareTo(_toMinutes(b.start)));
    for (var i = 1; i < active.length; i++) {
      final prevEnd = _toMinutes(active[i - 1].end);
      final curStart = _toMinutes(active[i].start);
      if (curStart < prevEnd) return 'Breaks cannot overlap';
    }

    for (final day in _days.where((d) => d.enabled)) {
      final dayStart = _toMinutes(day.start);
      final dayEnd = _toMinutes(day.end);
      for (final b in active) {
        final breakStart = _toMinutes(b.start);
        final breakEnd = _toMinutes(b.end);
        if (breakStart < dayStart || breakEnd > dayEnd) {
          return 'Breaks must be inside working hours (${day.label})';
        }
      }
    }
    return null;
  }

  TimeOfDay _parseT(String raw, TimeOfDay fallback) {
    final p = raw.split(':');
    if (p.length != 2) return fallback;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return fallback;
    }
    return TimeOfDay(hour: h, minute: m);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _fmt(TimeOfDay t) => MaterialLocalizations.of(
    context,
  ).formatTimeOfDay(t, alwaysUse24HourFormat: false);

  String _fmtDate(DateTime d) {
    const m = <String>[
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
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }

  Future<void> _pickDayTime(int i, bool start) async {
    final init = _parseT(
      start ? _days[i].start : _days[i].end,
      const TimeOfDay(hour: 9, minute: 0),
    );
    final picked = await showTimePicker(context: context, initialTime: init);
    if (picked == null) return;
    setState(() {
      _days[i] = start
          ? _days[i].copyWith(start: _hhmm(picked))
          : _days[i].copyWith(end: _hhmm(picked));
    });
  }

  Future<void> _showAddBreakSheet() async {
    TimeOfDay start = const TimeOfDay(hour: 13, minute: 0);
    TimeOfDay end = const TimeOfDay(hour: 14, minute: 0);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ownerDashboardCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickTime(bool isStart) async {
              final picked = await showTimePicker(
                context: context,
                initialTime: isStart ? start : end,
              );
              if (picked == null) return;
              setModalState(() {
                if (isStart) {
                  start = picked;
                } else {
                  end = picked;
                }
              });
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add Break',
                    style: TextStyle(
                      color: AppColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _timeChip('', _fmt(start), () => pickTime(true)),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '-',
                          style: TextStyle(color: AppColors.onDark30),
                        ),
                      ),
                      Expanded(
                        child: _timeChip('', _fmt(end), () => pickTime(false)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () {
                        final s = (start.hour * 60) + start.minute;
                        final e = (end.hour * 60) + end.minute;
                        if (e <= s) {
                          _snack('Break end must be after start');
                          return;
                        }
                        setState(() {
                          _breaks.add(
                            _BreakRow(
                              enabled: true,
                              start: _hhmm(start),
                              end: _hhmm(end),
                            ),
                          );
                        });
                        Navigator.of(sheetContext).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.shellBackground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'ADD BREAK',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickVacationDate(bool isStart) async {
    final now = DateTime.now();
    final initial = isStart
        ? (_vacationStartDate ?? now)
        : (_vacationEndDate ?? _vacationStartDate ?? now);
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (selected == null) return;
    setState(() {
      if (isStart) {
        _vacationStartDate = _dateOnly(selected);
      } else {
        _vacationEndDate = _dateOnly(selected);
      }
    });
  }

  Future<void> _syncVacationToBranch(String userId) async {
    final shopId = _selectedShopId;
    if (shopId == null || shopId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('barbers')
          .doc(userId)
          .set({
            'vacationMode': _vacationMode,
            'vacationStartAt': _toStartTimestamp(_vacationStartDate),
            'vacationEndAt': _toEndTimestamp(_vacationEndDate),
            'vacationNote': _vacationNoteController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (_) {
      // Keep availability save successful even if this mirror update fails.
    }
  }

  Future<void> _addDayOff() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null) return;
    setState(() {
      _exceptions.add(
        _ExceptionRow(
          date: DateTime(date.year, date.month, date.day),
          isDayOff: true,
          start: '',
          end: '',
        ),
      );
      _exceptions.sort((a, b) => a.date.compareTo(b.date));
    });
  }

  Future<void> _addCustomHours() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null) return;
    if (!mounted) return;
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
    );
    if (start == null) return;
    if (!mounted) return;
    final end = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 16, minute: 0),
    );
    if (end == null) return;

    final startMinutes = (start.hour * 60) + start.minute;
    final endMinutes = (end.hour * 60) + end.minute;
    if (startMinutes >= endMinutes) {
      _snack('Custom hours end time must be after start time');
      return;
    }

    final normalized = DateTime(date.year, date.month, date.day);
    setState(() {
      _exceptions.add(
        _ExceptionRow(
          date: normalized,
          isDayOff: false,
          start: _hhmm(start),
          end: _hhmm(end),
        ),
      );
      _exceptions.sort((a, b) => a.date.compareTo(b.date));
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final canPop = await _confirmLeaveIfNeeded();
        if (!canPop || !mounted) return;
        navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.shellBackground,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.onDark05)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final canPop = await _confirmLeaveIfNeeded();
                        if (!canPop || !mounted) return;
                        navigator.pop();
                      },
                      icon: const Icon(Icons.arrow_back, color: AppColors.gold),
                    ),
                    const Expanded(
                      child: Text(
                        'AVAILABILITY',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    OutlinedButton(
                      onPressed:
                          (_isLoading || _isSaving || !_hasUnsavedChanges)
                          ? null
                          : () async {
                              await _save();
                            },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: AppColors.gold.withValues(alpha: 0.4),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Text(
                        _isSaving
                            ? 'SAVING...'
                            : (_hasUnsavedChanges ? 'SAVE CHANGES' : 'SAVED'),
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.gold),
                  ),
                )
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      const Row(
                        children: [
                          Expanded(
                            child: Text(
                              'WEEKLY WORKING HOURS',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.8,
                              ),
                            ),
                          ),
                          Text(
                            'Standard Schedule',
                            style: TextStyle(
                              color: AppColors.onDark50,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._days.asMap().entries.map((entry) {
                        final i = entry.key;
                        final d = entry.value;
                        final s = _parseT(
                          d.start,
                          const TimeOfDay(hour: 9, minute: 0),
                        );
                        final e = _parseT(
                          d.end,
                          const TimeOfDay(hour: 18, minute: 0),
                        );
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.ownerDashboardCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: d.enabled
                                    ? AppColors.gold.withValues(alpha: 0.28)
                                    : AppColors.onDark05,
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            d.label,
                                            style: TextStyle(
                                              color: d.enabled
                                                  ? AppColors.text
                                                  : AppColors.onDark45,
                                              fontSize: 17,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          Text(
                                            d.enabled ? 'Working' : 'Off',
                                            style: TextStyle(
                                              color: d.enabled
                                                  ? AppColors.gold
                                                  : AppColors.onDark45,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: d.enabled,
                                      activeThumbColor: AppColors.gold,
                                      activeTrackColor: AppColors.gold
                                          .withValues(alpha: 0.4),
                                      onChanged: (v) => setState(
                                        () => _days[i] = d.copyWith(enabled: v),
                                      ),
                                    ),
                                  ],
                                ),
                                if (d.enabled)
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _timeChip(
                                          'START',
                                          _fmt(s),
                                          () => _pickDayTime(i, true),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          '-',
                                          style: TextStyle(
                                            color: AppColors.onDark30,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: _timeChip(
                                          'END',
                                          _fmt(e),
                                          () => _pickDayTime(i, false),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      const Text(
                        'VACATION MODE',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.ownerDashboardCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _vacationMode
                                ? AppColors.gold.withValues(alpha: 0.28)
                                : AppColors.onDark08,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.beach_access,
                                  color: AppColors.gold,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Vacation Mode',
                                    style: TextStyle(
                                      color: AppColors.text,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Switch.adaptive(
                                  value: _vacationMode,
                                  activeThumbColor: AppColors.gold,
                                  activeTrackColor: AppColors.gold.withValues(
                                    alpha: 0.4,
                                  ),
                                  onChanged: (v) => setState(() {
                                    _vacationMode = v;
                                    if (!v) {
                                      _vacationStartDate = null;
                                      _vacationEndDate = null;
                                      _vacationNoteController.clear();
                                    }
                                  }),
                                ),
                              ],
                            ),
                            if (_vacationMode) ...[
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _dateChip(
                                      label: 'START',
                                      value: _vacationStartDate == null
                                          ? 'Select date'
                                          : _fmtDate(_vacationStartDate!),
                                      onTap: () => _pickVacationDate(true),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _dateChip(
                                      label: 'END',
                                      value: _vacationEndDate == null
                                          ? 'Select date'
                                          : _fmtDate(_vacationEndDate!),
                                      onTap: () => _pickVacationDate(false),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _vacationNoteController,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(color: AppColors.text),
                                decoration: InputDecoration(
                                  hintText: 'Optional note',
                                  hintStyle: const TextStyle(
                                    color: AppColors.onDark45,
                                  ),
                                  filled: true,
                                  fillColor: AppColors.shellBackground
                                      .withValues(alpha: 0.4),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.onDark10,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: AppColors.onDark10,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'BREAKS',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.8,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _showAddBreakSheet,
                            icon: const Icon(
                              Icons.add,
                              color: AppColors.gold,
                              size: 18,
                            ),
                            label: const Text(
                              'ADD BREAK',
                              style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_breaks.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.ownerDashboardCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.onDark08),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'No breaks added yet.',
                                style: TextStyle(
                                  color: AppColors.onDark58,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 40,
                                child: OutlinedButton.icon(
                                  onPressed: _showAddBreakSheet,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.gold,
                                    side: const BorderSide(
                                      color: AppColors.gold,
                                    ),
                                  ),
                                  icon: const Icon(Icons.add, size: 16),
                                  label: const Text(
                                    'Add break',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Column(
                          children: _breaks.asMap().entries.map((entry) {
                            final i = entry.key;
                            final b = entry.value;
                            final start = _parseT(
                              b.start,
                              const TimeOfDay(hour: 13, minute: 0),
                            );
                            final end = _parseT(
                              b.end,
                              const TimeOfDay(hour: 14, minute: 0),
                            );
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Opacity(
                                opacity: b.enabled ? 1 : 0.62,
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.ownerDashboardCard,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.gold.withValues(
                                        alpha: 0.16,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.free_breakfast_rounded,
                                        size: 18,
                                        color: AppColors.gold,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Break',
                                        style: TextStyle(
                                          color: AppColors.text,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          '${_fmt(start)} - ${_fmt(end)}',
                                          style: TextStyle(
                                            color: b.enabled
                                                ? AppColors.text
                                                : AppColors.onDark45,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Switch.adaptive(
                                        value: b.enabled,
                                        activeThumbColor: AppColors.gold,
                                        activeTrackColor: AppColors.gold
                                            .withValues(alpha: 0.4),
                                        onChanged: (v) => setState(() {
                                          _breaks[i] = b.copyWith(enabled: v);
                                        }),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            setState(() => _breaks.removeAt(i)),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 20,
                                          color: AppColors.onDark35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 16),
                      const Text(
                        'EXCEPTIONS',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _addDayOff,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.shellBackground,
                                minimumSize: const Size.fromHeight(46),
                              ),
                              icon: const Icon(Icons.event_busy, size: 18),
                              label: const Text(
                                'ADD DAY OFF',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _addCustomHours,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.gold,
                                side: const BorderSide(color: AppColors.gold),
                                minimumSize: const Size.fromHeight(46),
                              ),
                              icon: const Icon(Icons.edit_calendar, size: 18),
                              label: const Text(
                                'CUSTOM HOURS',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.ownerDashboardCard,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.2),
                          ),
                        ),
                        child: _exceptions.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: Text(
                                  'No upcoming exceptions yet.',
                                  style: TextStyle(color: AppColors.onDark45),
                                ),
                              )
                            : Column(
                                children: _exceptions.asMap().entries.map((
                                  entry,
                                ) {
                                  final i = entry.key;
                                  final e = entry.value;
                                  return ListTile(
                                    dense: true,
                                    leading: CircleAvatar(
                                      backgroundColor: e.isDayOff
                                          ? AppColors.danger.withValues(
                                              alpha: 0.15,
                                            )
                                          : AppColors.gold.withValues(
                                              alpha: 0.15,
                                            ),
                                      child: Icon(
                                        e.isDayOff
                                            ? Icons.block
                                            : Icons.pending_actions,
                                        color: e.isDayOff
                                            ? AppColors.danger
                                            : AppColors.gold,
                                        size: 18,
                                      ),
                                    ),
                                    title: Text(
                                      _fmtDate(e.date),
                                      style: const TextStyle(
                                        color: AppColors.text,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    subtitle: Text(
                                      e.isDayOff
                                          ? 'Full Day Off'
                                          : '${e.start} - ${e.end}',
                                      style: TextStyle(
                                        color: e.isDayOff
                                            ? AppColors.onDark58
                                            : AppColors.gold,
                                      ),
                                    ),
                                    trailing: IconButton(
                                      onPressed: () => setState(
                                        () => _exceptions.removeAt(i),
                                      ),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: AppColors.onDark35,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'APPOINTMENT SETTINGS',
                        style: TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.ownerDashboardCard,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.onDark08),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Buffer between appointments',
                              style: TextStyle(
                                color: AppColors.text,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: const <int>[0, 5, 10, 15].map((min) {
                                return Expanded(child: SizedBox());
                              }).toList(),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.onDark05,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.onDark10),
                              ),
                              child: Row(
                                children: <int>[0, 5, 10, 15].map((min) {
                                  final selected = _bufferMinutes == min;
                                  return Expanded(
                                    child: InkWell(
                                      onTap: () =>
                                          setState(() => _bufferMinutes = min),
                                      borderRadius: BorderRadius.circular(8),
                                      child: Container(
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppColors.gold
                                              : AppColors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          '$min MIN',
                                          style: TextStyle(
                                            color: selected
                                                ? AppColors.shellBackground
                                                : AppColors.onDark45,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'A buffer allows you time to clean your station and prepare for the next client.',
                              style: TextStyle(
                                color: AppColors.onDark45,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateChip({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.ownerDashboardCard.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.onDark10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.onDark45,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeChip(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.ownerDashboardCard.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.onDark10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label.isNotEmpty)
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.onDark45,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  if (label.isNotEmpty) const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.schedule, size: 16, color: AppColors.gold),
          ],
        ),
      ),
    );
  }
}

class _DayRow {
  const _DayRow({
    required this.id,
    required this.label,
    required this.enabled,
    required this.start,
    required this.end,
  });

  final String id;
  final String label;
  final bool enabled;
  final String start;
  final String end;

  _DayRow copyWith({bool? enabled, String? start, String? end}) {
    return _DayRow(
      id: id,
      label: label,
      enabled: enabled ?? this.enabled,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}

class _BreakRow {
  const _BreakRow({
    required this.enabled,
    required this.start,
    required this.end,
  });

  final bool enabled;
  final String start;
  final String end;

  _BreakRow copyWith({bool? enabled, String? start, String? end}) {
    return _BreakRow(
      enabled: enabled ?? this.enabled,
      start: start ?? this.start,
      end: end ?? this.end,
    );
  }
}

enum _UnsavedAction { cancel, discard, save }

class _ExceptionRow {
  const _ExceptionRow({
    required this.date,
    required this.isDayOff,
    required this.start,
    required this.end,
  });

  final DateTime date;
  final bool isDayOff;
  final String start;
  final String end;
}
