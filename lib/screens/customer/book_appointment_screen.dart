import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BookAppointmentScreen extends StatefulWidget {
  const BookAppointmentScreen({super.key, this.initialShopId});

  final String? initialShopId;

  @override
  State<BookAppointmentScreen> createState() => _BookAppointmentScreenState();
}

class _BookAppointmentScreenState extends State<BookAppointmentScreen> {
  String? _selectedShopId;
  String? _selectedBarberDocId;
  String? _selectedServiceDocId;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selectedShopId = widget.initialShopId;
  }

  DateTime? _buildSelectedDateTime() {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      _selectedTime = picked;
    });
  }

  Future<void> _submitBooking() async {
    if (_submitting) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final shopId = _selectedShopId;
    final barberDocId = _selectedBarberDocId;
    final serviceDocId = _selectedServiceDocId;
    final startDateTime = _buildSelectedDateTime();

    if (shopId == null ||
        barberDocId == null ||
        serviceDocId == null ||
        startDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select shop, service, barber, date, and time'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (startDateTime.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a future time'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final barberDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('barbers')
          .doc(barberDocId)
          .get();
      final serviceDoc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('services')
          .doc(serviceDocId)
          .get();

      if (!barberDoc.exists || !serviceDoc.exists) {
        throw Exception('Selected barber/service does not exist');
      }

      final barberData = barberDoc.data() ?? <String, dynamic>{};
      final serviceData = serviceDoc.data() ?? <String, dynamic>{};

      final selectedBarberId =
          (barberData['barberId'] as String?) ?? barberDoc.id;
      final selectedDurationMinutes =
          (serviceData['durationMinutes'] as num?)?.toInt() ?? 30;
      final selectedEndAt = startDateTime.add(
        Duration(minutes: selectedDurationMinutes),
      );

      final conflictSnap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('barberId', isEqualTo: selectedBarberId)
          .limit(300)
          .get();

      final hasConflict = conflictSnap.docs.any((doc) {
        final data = doc.data();
        final status = (data['status'] as String?)?.toLowerCase().trim() ?? '';
        if (status == 'cancelled' || status == 'done') {
          return false;
        }

        final existingStartTs = data['startAt'] as Timestamp?;
        if (existingStartTs == null) {
          return false;
        }
        final existingStart = existingStartTs.toDate();

        final existingDuration =
            (data['durationMinutes'] as num?)?.toInt() ?? 30;
        final existingEnd = existingStart.add(
          Duration(minutes: existingDuration),
        );

        // Overlap rule:
        // newStart < existingEnd && newEnd > existingStart
        return startDateTime.isBefore(existingEnd) &&
            selectedEndAt.isAfter(existingStart);
      });

      if (hasConflict) {
        throw Exception(
          'Selected barber already has an appointment in this time',
        );
      }

      await FirebaseFirestore.instance.collection('appointments').add({
        'shopId': shopId,
        'customerId': user.uid,
        'customerName': user.displayName ?? user.email ?? 'Customer',
        'barberId': selectedBarberId,
        'barberName': (barberData['name'] as String?) ?? 'Barber',
        'serviceId': (serviceData['serviceId'] as String?) ?? serviceDoc.id,
        'serviceName': (serviceData['name'] as String?) ?? 'Service',
        'durationMinutes': selectedDurationMinutes,
        'status': 'pending',
        'startAt': Timestamp.fromDate(startDateTime),
        'endAt': Timestamp.fromDate(selectedEndAt),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment booked successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed: ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('shops')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LinearProgressIndicator();
                }

                final docs = snapshot.data?.docs ?? [];
                if (_selectedShopId != null &&
                    !docs.any((d) => d.id == _selectedShopId)) {
                  _selectedShopId = null;
                  _selectedBarberDocId = null;
                  _selectedServiceDocId = null;
                }

                return DropdownButtonFormField<String>(
                  initialValue: _selectedShopId,
                  decoration: const InputDecoration(labelText: 'Select Shop'),
                  items: docs.map((doc) {
                    final data = doc.data();
                    final title = (data['name'] as String?)?.trim();
                    final label = (title == null || title.isEmpty)
                        ? doc.id
                        : title;
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedShopId = value;
                      _selectedBarberDocId = null;
                      _selectedServiceDocId = null;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            if (_selectedShopId != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('shops')
                    .doc(_selectedShopId!)
                    .collection('services')
                    .where('isActive', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (_selectedServiceDocId != null &&
                      !docs.any((d) => d.id == _selectedServiceDocId)) {
                    _selectedServiceDocId = null;
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: _selectedServiceDocId,
                    decoration: const InputDecoration(labelText: 'Service'),
                    items: docs.map((doc) {
                      final data = doc.data();
                      final name = (data['name'] as String?) ?? 'Service';
                      final minutes =
                          (data['durationMinutes'] as num?)?.toInt() ?? 0;
                      final price = (data['price'] as num?)?.toDouble() ?? 0;
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(
                          '$name - ${minutes}m - \$${price.toStringAsFixed(2)}',
                        ),
                      );
                    }).toList(),
                    onChanged: docs.isEmpty
                        ? null
                        : (value) {
                            setState(() {
                              _selectedServiceDocId = value;
                            });
                          },
                  );
                },
              ),
            const SizedBox(height: 12),
            if (_selectedShopId != null)
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('shops')
                    .doc(_selectedShopId!)
                    .collection('barbers')
                    .where('isActive', isEqualTo: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (_selectedBarberDocId != null &&
                      !docs.any((d) => d.id == _selectedBarberDocId)) {
                    _selectedBarberDocId = null;
                  }

                  return DropdownButtonFormField<String>(
                    initialValue: _selectedBarberDocId,
                    decoration: const InputDecoration(labelText: 'Barber'),
                    items: docs.map((doc) {
                      final data = doc.data();
                      final name = (data['name'] as String?) ?? 'Barber';
                      final specialty = (data['specialty'] as String?) ?? '';
                      return DropdownMenuItem<String>(
                        value: doc.id,
                        child: Text(
                          specialty.isEmpty ? name : '$name - $specialty',
                        ),
                      );
                    }).toList(),
                    onChanged: docs.isEmpty
                        ? null
                        : (value) {
                            setState(() {
                              _selectedBarberDocId = value;
                            });
                          },
                  );
                },
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickDate,
                    child: Text(
                      _selectedDate == null
                          ? 'Pick Date'
                          : '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickTime,
                    child: Text(
                      _selectedTime == null
                          ? 'Pick Time'
                          : _selectedTime!.format(context),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submitBooking,
                child: Text(_submitting ? 'Booking...' : 'Confirm Booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
