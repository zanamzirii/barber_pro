import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:barber_pro/core/motion.dart';

import '../../core/theme/app_colors.dart';
import 'customer_data_mapper.dart';
import 'my_appointments_screen.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key, this.initialShopId});

  final String? initialShopId;

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  int _step = 1; // 1=service, 2=barber, 3=date&time, 4=confirm
  String? _selectedServiceId;
  String? _selectedBarberId; // '__any__' means any available barber
  bool _isSubmitting = false;

  static const String _anyBarberId = '__any__';

  int _selectedDateIndex = 0;
  String? _selectedTime;

  static const List<_DateOption> _dateOptions = [
    _DateOption(label: 'MON', day: '20', fullName: 'Monday'),
    _DateOption(label: 'TUE', day: '21', fullName: 'Tuesday'),
    _DateOption(label: 'WED', day: '22', fullName: 'Wednesday'),
    _DateOption(label: 'THU', day: '23', fullName: 'Thursday'),
    _DateOption(label: 'FRI', day: '24', fullName: 'Friday'),
  ];

  static const List<String> _morningSlots = [
    '09:00 AM',
    '09:45 AM',
    '10:30 AM',
    '11:15 AM',
  ];
  static const List<String> _afternoonSlots = [
    '01:00 PM',
    '01:45 PM',
    '02:30 PM',
    '03:15 PM',
    '04:00 PM',
  ];
  static const List<String> _eveningSlots = [
    '05:30 PM',
    '06:15 PM',
    '07:00 PM',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTime = _morningSlots.last;
  }

  @override
  Widget build(BuildContext context) {
    final shopId = widget.initialShopId;

    return Scaffold(
      backgroundColor: const Color(0xFF05070A),
      body: Stack(
        children: [
          const _SilkyBackground(),
          SafeArea(
            child: Column(
              children: [
                _BookingHeader(
                  title: _titleForStep(_step),
                  onBack: () {
                    if (_step > 1) {
                      setState(() => _step -= 1);
                      return;
                    }
                    Navigator.of(context).pop();
                  },
                ),
                if (shopId == null || shopId.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Text(
                          'No branch selected. Please choose a branch first.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.muted.withValues(alpha: 0.9),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (_step == 1)
                  Expanded(child: _buildSelectService(shopId))
                else if (_step == 2)
                  Expanded(child: _buildSelectBarber(shopId))
                else if (_step == 3)
                  Expanded(child: _buildSelectDateTime())
                else
                  Expanded(child: _buildConfirmBooking(shopId)),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF05070A).withValues(alpha: 0.0),
                      const Color(0xFF05070A).withValues(alpha: 0.95),
                      const Color(0xFF05070A),
                    ],
                  ),
                ),
                child: SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: const Color(0xFF05070A),
                      disabledBackgroundColor: AppColors.gold.withValues(
                        alpha: 0.35,
                      ),
                      disabledForegroundColor: const Color(
                        0xFF05070A,
                      ).withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 4.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onPressed: _canContinue
                        ? () async {
                            if (_step == 1) {
                              setState(() => _step = 2);
                              return;
                            }
                            if (_step == 2) {
                              setState(() => _step = 3);
                              return;
                            }
                            if (_step == 3) {
                              setState(() => _step = 4);
                              return;
                            }
                            if (shopId != null && shopId.isNotEmpty) {
                              await _submitBooking(shopId);
                            }
                          }
                        : null,
                    child: Text(_buttonTextForStep(_step)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _titleForStep(int step) {
    if (step == 1) return 'Select Service';
    if (step == 2) return 'Select Barber';
    if (step == 3) return 'Select Date & Time';
    return 'Confirm Booking';
  }

  String _buttonTextForStep(int step) {
    if (step == 3) return 'CONFIRM TIME';
    if (step == 4) return _isSubmitting ? 'CONFIRMING...' : 'CONFIRM BOOKING';
    return 'CONTINUE';
  }

  bool get _canContinue {
    if (_isSubmitting) return false;
    if (_step == 1) return _selectedServiceId != null;
    if (_step == 2) return _selectedBarberId != null;
    if (_step == 3) return _selectedTime != null;
    return true;
  }

  Widget _buildSelectService(String shopId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('services')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? const [];

        if (_selectedServiceId != null &&
            !docs.any((d) => d.id == _selectedServiceId)) {
          _selectedServiceId = null;
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 2.2,
            ),
          );
        }

        if (docs.isEmpty) {
          return Center(
            child: Text(
              'No active services in this branch yet.',
              style: TextStyle(color: AppColors.muted.withValues(alpha: 0.85)),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 130),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data();
            final isSelected = _selectedServiceId == doc.id;

            final name = ((data['name'] as String?)?.trim().isNotEmpty ?? false)
                ? (data['name'] as String).trim()
                : 'Service';
            final description =
                ((data['description'] as String?)?.trim().isNotEmpty ?? false)
                ? (data['description'] as String).trim()
                : 'Premium grooming experience.';
            final durationMinutes =
                (data['durationMinutes'] as num?)?.toInt() ?? 30;
            final price = (data['price'] as num?)?.toDouble() ?? 0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => setState(() => _selectedServiceId = doc.id),
                child: _ServiceCard(
                  selected: isSelected,
                  name: name,
                  description: description,
                  durationMinutes: durationMinutes,
                  priceLabel: _formatPrice(price),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSelectBarber(String shopId) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('barbers')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        final docs = (snapshot.data?.docs ?? const []).where((d) {
          if (currentUid == null) return true;
          final data = d.data();
          final barberId = (data['barberId'] as String?)?.trim();
          final barberUserId = (data['barberUserId'] as String?)?.trim();
          return d.id != currentUid &&
              barberId != currentUid &&
              barberUserId != currentUid;
        }).toList();

        if (_selectedBarberId != _anyBarberId &&
            _selectedBarberId != null &&
            !docs.any((d) => d.id == _selectedBarberId)) {
          _selectedBarberId = null;
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 2.2,
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 130),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => setState(() => _selectedBarberId = _anyBarberId),
              child: _AnyBarberCard(
                selected: _selectedBarberId == _anyBarberId,
              ),
            ),
            const SizedBox(height: 12),
            ...docs.asMap().entries.map((entry) {
              final index = entry.key;
              final doc = entry.value;
              final data = doc.data();
              final isSelected = _selectedBarberId == doc.id;

              final name = CustomerDataMapper.barberFullName(data);
              final title =
                  ((data['title'] as String?)?.trim().isNotEmpty ?? false)
                  ? (data['title'] as String).trim()
                  : (((data['specialty'] as String?)?.trim().isNotEmpty ??
                            false)
                        ? (data['specialty'] as String).trim()
                        : 'Master Barber');

              final rating = (data['rating'] as num?)?.toDouble() ?? 5.0;
              final reviewCount =
                  (data['reviewCount'] as num?)?.toInt() ?? (80 + (index * 17));
              final imageUrl = CustomerDataMapper.barberImage(
                data,
                fallbackIndex: index,
              );

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => setState(() => _selectedBarberId = doc.id),
                  child: _BarberCard(
                    selected: isSelected,
                    name: name,
                    title: title,
                    rating: rating,
                    reviewCount: reviewCount,
                    imageUrl: imageUrl,
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildSelectDateTime() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 130),
      children: [
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Text(
                'SELECT DATE',
                style: TextStyle(
                  fontSize: 13,
                  letterSpacing: 3,
                  color: Color(0x80FFFFFF),
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'May 2024',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: List.generate(_dateOptions.length, (index) {
              final d = _dateOptions[index];
              final selected = _selectedDateIndex == index;
              return Padding(
                padding: EdgeInsets.only(
                  right: index == _dateOptions.length - 1 ? 0 : 10,
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _selectedDateIndex = index),
                  child: Container(
                    width: 64,
                    height: 80,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.gold.withValues(alpha: 0.15)
                          : const Color(0xFF121620).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? AppColors.gold.withValues(alpha: 0.8)
                            : AppColors.gold.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          d.label,
                          style: TextStyle(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            color: selected
                                ? AppColors.gold.withValues(alpha: 0.8)
                                : Colors.white.withValues(alpha: 0.35),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d.day,
                          style: TextStyle(
                            fontSize: 30,
                            color: selected
                                ? AppColors.gold
                                : Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'AVAILABLE SLOTS',
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 3,
              color: Color(0x80FFFFFF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _SlotSection(
          title: 'MORNING',
          slots: _morningSlots,
          selectedTime: _selectedTime,
          onSelect: (slot) => setState(() => _selectedTime = slot),
        ),
        _SlotSection(
          title: 'AFTERNOON',
          slots: _afternoonSlots,
          selectedTime: _selectedTime,
          onSelect: (slot) => setState(() => _selectedTime = slot),
        ),
        _SlotSection(
          title: 'EVENING',
          slots: _eveningSlots,
          selectedTime: _selectedTime,
          onSelect: (slot) => setState(() => _selectedTime = slot),
        ),
      ],
    );
  }

  Widget _buildConfirmBooking(String shopId) {
    return FutureBuilder<_ConfirmViewData>(
      future: _loadConfirmViewData(shopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              color: AppColors.gold,
              strokeWidth: 2.2,
            ),
          );
        }

        if (!snapshot.hasData) {
          return Center(
            child: Text(
              'Could not load booking details.',
              style: TextStyle(color: AppColors.muted.withValues(alpha: 0.85)),
            ),
          );
        }

        final data = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 130),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF121620).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  _ConfirmRow(
                    icon: Icons.location_on_outlined,
                    label: 'BRANCH & ADDRESS',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.branchName,
                          style: const TextStyle(
                            fontFamily: 'PlayfairDisplay',
                            fontSize: 18,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          data.branchAddress,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.white.withValues(alpha: 0.62),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ConfirmRow(
                          icon: Icons.content_cut_outlined,
                          label: 'SERVICE',
                          child: Text(
                            data.serviceName,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.text,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ConfirmRow(
                          icon: Icons.person_outline,
                          label: 'BARBER',
                          child: Text(
                            data.barberName,
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.text,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ConfirmRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'APPOINTMENT DETAILS',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.dateText,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${data.timeText} (${data.durationMinutes} min duration)',
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.62),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        data.totalText,
                        style: const TextStyle(
                          fontSize: 36,
                          fontFamily: 'PlayfairDisplay',
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'BOOKING POLICY',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                  letterSpacing: 3.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _PolicyItem(
              icon: Icons.info_outline,
              text:
                  'Please arrive 10 minutes prior to your appointment time. Cancellations must be made at least 24 hours in advance.',
            ),
            const SizedBox(height: 10),
            _PolicyItem(
              icon: Icons.verified_user_outlined,
              text:
                  'Secure payment will be handled at the branch after your service.',
            ),
          ],
        );
      },
    );
  }

  Future<_ConfirmViewData> _loadConfirmViewData(String shopId) async {
    final shopDoc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .get();

    final serviceId = _selectedServiceId;
    if (serviceId == null) {
      throw StateError('Service not selected');
    }

    final serviceDoc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('services')
        .doc(serviceId)
        .get();

    DocumentSnapshot<Map<String, dynamic>>? barberDoc;
    if (_selectedBarberId != null && _selectedBarberId != _anyBarberId) {
      barberDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('barbers')
          .doc(_selectedBarberId)
          .get();
    }

    final shop = shopDoc.data() ?? <String, dynamic>{};
    final service = serviceDoc.data() ?? <String, dynamic>{};
    final barber = barberDoc?.data() ?? <String, dynamic>{};

    final branchName = CustomerDataMapper.branchName(shop);
    final branchAddress = CustomerDataMapper.branchAddress(
      shop,
      fallback: 'Address not available',
    );

    final serviceName =
        ((service['name'] as String?)?.trim().isNotEmpty ?? false)
        ? (service['name'] as String).trim()
        : 'Service';

    final barberName = _selectedBarberId == _anyBarberId
        ? 'Any Available Barber'
        : CustomerDataMapper.barberFullName(barber);

    final durationMinutes = (service['durationMinutes'] as num?)?.toInt() ?? 30;
    final price = (service['price'] as num?)?.toDouble() ?? 0.0;
    final currency =
        ((service['currency'] as String?)?.trim().isNotEmpty ?? false)
        ? (service['currency'] as String).trim().toUpperCase()
        : 'USD';

    final selectedDate = _dateOptions[_selectedDateIndex];
    final dateText = '${selectedDate.fullName}, ${selectedDate.day} May 2024';
    final timeText = _selectedTime ?? _morningSlots.last;

    return _ConfirmViewData(
      branchName: branchName,
      branchAddress: branchAddress,
      serviceName: serviceName,
      barberName: barberName,
      dateText: dateText,
      timeText: timeText,
      durationMinutes: durationMinutes,
      totalText: _formatTotal(price, currency),
      price: price,
      currency: currency,
    );
  }

  String _formatTotal(double price, String currency) {
    final amount = price % 1 == 0
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
    if (currency == 'GBP') return 'Ã‚Â£$amount';
    if (currency == 'USD') return '\$$amount';
    return '$currency $amount';
  }

  Future<void> _submitBooking(String shopId) async {
    if (_isSubmitting) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_selectedBarberId != null &&
        _selectedBarberId != _anyBarberId &&
        _selectedBarberId == user.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot book yourself as barber'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final data = await _loadConfirmViewData(shopId);
      final startAt = _buildStartAt();
      final customerName = (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : ((user.email?.split('@').first.trim().isNotEmpty ?? false)
                ? user.email!.split('@').first.trim()
                : 'Customer');

      await FirebaseFirestore.instance.collection('appointments').add({
        'customerId': user.uid,
        'customerName': customerName,
        'shopId': shopId,
        'shopName': data.branchName,
        'shopAddress': data.branchAddress,
        'serviceId': _selectedServiceId,
        'serviceName': data.serviceName,
        'barberId': _selectedBarberId == _anyBarberId ? '' : _selectedBarberId,
        'barberName': data.barberName,
        'durationMinutes': data.durationMinutes,
        'price': data.price,
        'currency': data.currency,
        'startAt': Timestamp.fromDate(startAt),
        'dateLabel': data.dateText,
        'timeLabel': data.timeText,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        Motion.pageRoute(builder: (_) => const MyAppointmentsScreen()),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not confirm booking'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  DateTime _buildStartAt() {
    final now = DateTime.now();
    final slot = _selectedTime ?? _morningSlots.last;
    final targetWeekday = _weekdayFromLabel(
      _dateOptions[_selectedDateIndex].label,
    );
    final parsed = _parseTime(slot);

    var date = now;
    while (date.weekday != targetWeekday) {
      date = date.add(const Duration(days: 1));
    }
    var startAt = DateTime(
      date.year,
      date.month,
      date.day,
      parsed.$1,
      parsed.$2,
    );
    if (!startAt.isAfter(now)) {
      startAt = startAt.add(const Duration(days: 7));
    }
    return startAt;
  }

  int _weekdayFromLabel(String label) {
    switch (label) {
      case 'MON':
        return DateTime.monday;
      case 'TUE':
        return DateTime.tuesday;
      case 'WED':
        return DateTime.wednesday;
      case 'THU':
        return DateTime.thursday;
      default:
        return DateTime.friday;
    }
  }

  (int, int) _parseTime(String slot) {
    final parts = slot.split(' ');
    final hm = parts.first.split(':');
    var hour = int.parse(hm[0]);
    final minute = int.parse(hm[1]);
    final period = parts.last.toUpperCase();

    if (period == 'PM' && hour != 12) hour += 12;
    if (period == 'AM' && hour == 12) hour = 0;
    return (hour, minute);
  }

  String _formatPrice(double value) {
    if (value % 1 == 0) return '\$${value.toInt()}';
    return '\$${value.toStringAsFixed(2)}';
  }
}

class _DateOption {
  const _DateOption({
    required this.label,
    required this.day,
    required this.fullName,
  });

  final String label;
  final String day;
  final String fullName;
}

class _ConfirmViewData {
  const _ConfirmViewData({
    required this.branchName,
    required this.branchAddress,
    required this.serviceName,
    required this.barberName,
    required this.dateText,
    required this.timeText,
    required this.durationMinutes,
    required this.totalText,
    required this.price,
    required this.currency,
  });

  final String branchName;
  final String branchAddress;
  final String serviceName;
  final String barberName;
  final String dateText;
  final String timeText;
  final int durationMinutes;
  final String totalText;
  final double price;
  final String currency;
}

class _BookingHeader extends StatelessWidget {
  const _BookingHeader({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: AppColors.text, size: 24),
          ),
          const SizedBox(width: 4),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'PlayfairDisplay',
              fontSize: 30,
              letterSpacing: 0.4,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotSection extends StatelessWidget {
  const _SlotSection({
    required this.title,
    required this.slots,
    required this.selectedTime,
    required this.onSelect,
  });

  final String title;
  final List<String> slots;
  final String? selectedTime;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2.2,
              color: Colors.white.withValues(alpha: 0.3),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: slots.map((slot) {
              final selected = slot == selectedTime;
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelect(slot),
                child: Container(
                  width: 86,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.gold.withValues(alpha: 0.15)
                        : const Color(0xFF121620).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.gold.withValues(alpha: 0.8)
                          : AppColors.gold.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Text(
                    slot,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      color: selected
                          ? AppColors.gold
                          : Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.selected,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.priceLabel,
  });

  final bool selected;
  final String name;
  final String description;
  final int durationMinutes;
  final String priceLabel;

  @override
  Widget build(BuildContext context) {
    final cardColor = selected
        ? AppColors.gold.withValues(alpha: 0.05)
        : const Color(0xFF121620).withValues(alpha: 0.4);

    final borderColor = selected
        ? AppColors.gold.withValues(alpha: 0.8)
        : AppColors.gold.withValues(alpha: 0.2);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: selected ? 1.0 : 0.5),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.12),
                  blurRadius: 15,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 16,
                    color: AppColors.text,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                priceLabel,
                style: TextStyle(
                  color: selected ? AppColors.gold : Colors.white70,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 250,
            child: Text(
              description,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 12,
                color: selected
                    ? AppColors.gold.withValues(alpha: 0.9)
                    : Colors.white.withValues(alpha: 0.35),
              ),
              const SizedBox(width: 6),
              Text(
                '$durationMinutes MIN',
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.gold.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnyBarberCard extends StatelessWidget {
  const _AnyBarberCard({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.05)
            : const Color(0xFF121620).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.8)
              : AppColors.gold.withValues(alpha: 0.2),
          width: selected ? 1.0 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.gold.withValues(alpha: 0.10),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.groups, color: AppColors.gold, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Any\nAvailable\nBarber',
                        style: TextStyle(
                          fontFamily: 'PlayfairDisplay',
                          fontSize: 15,
                          height: 1.1,
                          color: AppColors.text,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'RECOMMENDED',
                        style: TextStyle(
                          fontSize: 8,
                          letterSpacing: 1.1,
                          color: AppColors.gold,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Best for immediate service\navailability',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                    height: 1.35,
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

class _BarberCard extends StatelessWidget {
  const _BarberCard({
    required this.selected,
    required this.name,
    required this.title,
    required this.rating,
    required this.reviewCount,
    required this.imageUrl,
  });

  final bool selected;
  final String name;
  final String title;
  final double rating;
  final int reviewCount;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.gold.withValues(alpha: 0.05)
            : const Color(0xFF121620).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? AppColors.gold.withValues(alpha: 0.8)
              : AppColors.gold.withValues(alpha: 0.2),
          width: selected ? 1.0 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: ClipOval(
              child: ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0.2126,
                  0.7152,
                  0.0722,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  // Keep layout stable when remote avatar fails.
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF1B2130),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.person,
                        color: Colors.white70,
                        size: 20,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'PlayfairDisplay',
                    fontSize: 16,
                    color: AppColors.text,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 12,
                      color: AppColors.gold.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${rating.toStringAsFixed(1)} | $reviewCount REVIEWS',
                      style: TextStyle(
                        color: AppColors.gold.withValues(alpha: 0.85),
                        fontSize: 9,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
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

class _ConfirmRow extends StatelessWidget {
  const _ConfirmRow({
    required this.icon,
    required this.label,
    required this.child,
  });

  final IconData icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: AppColors.gold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.6,
                  color: Colors.white.withValues(alpha: 0.38),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

class _PolicyItem extends StatelessWidget {
  const _PolicyItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.gold.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Colors.white.withValues(alpha: 0.45),
            ),
          ),
        ),
      ],
    );
  }
}
