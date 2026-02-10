import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'owner_data.dart';

class OwnerAddServiceScreen extends StatefulWidget {
  const OwnerAddServiceScreen({super.key});

  @override
  State<OwnerAddServiceScreen> createState() => _OwnerAddServiceScreenState();
}

class _OwnerAddServiceScreenState extends State<OwnerAddServiceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _durationController = TextEditingController();
  final _priceController = TextEditingController();
  bool _saving = false;
  late final Future<String> _shopIdFuture;

  @override
  void initState() {
    super.initState();
    _shopIdFuture = _resolveOwnerShopId();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _durationController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<String> _resolveOwnerShopId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '';
    return resolveAndEnsureShopId(user.uid);
  }

  Future<void> _saveService() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _saving = true;
    });

    try {
      final shopId = await resolveAndEnsureShopId(user.uid);
      final ref = FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('services')
          .doc();

      await ref.set({
        'serviceId': ref.id,
        'shopId': shopId,
        'ownerId': user.uid,
        'name': _nameController.text.trim(),
        'durationMinutes': int.parse(_durationController.text.trim()),
        'price': double.parse(_priceController.text.trim()),
        'currency': 'USD',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service added successfully'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _nameController.clear();
      _durationController.clear();
      _priceController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not add service. Try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _toggleServiceActive(
    BuildContext context,
    String shopId,
    String docId,
    bool nextValue,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('services')
          .doc(docId)
          .update({
            'isActive': nextValue,
            'updatedAt': FieldValue.serverTimestamp(),
          });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nextValue ? 'Service activated' : 'Service deactivated',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update service status'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _deleteService(
    BuildContext context,
    String shopId,
    String docId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('services')
          .doc(docId)
          .delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service removed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not remove service'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Services')),
      body: FutureBuilder<String>(
        future: _shopIdFuture,
        builder: (context, shopSnapshot) {
          if (shopSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final shopId = shopSnapshot.data ?? '';
          if (shopId.isEmpty) {
            return const Center(child: Text('No shop assigned'));
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Service Name',
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Service name is required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration (minutes)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          final value = int.tryParse((v ?? '').trim());
                          if (value == null || value <= 0) {
                            return 'Enter valid duration';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _priceController,
                        decoration: const InputDecoration(labelText: 'Price'),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (v) {
                          final value = double.tryParse((v ?? '').trim());
                          if (value == null || value < 0) {
                            return 'Enter valid price';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _saveService,
                          child: Text(_saving ? 'Saving...' : 'Add Service'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Your Services',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('shops')
                        .doc(shopId)
                        .collection('services')
                        .limit(200)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No services yet'));
                      }

                      final docs = snapshot.data!.docs.toList()
                        ..sort((a, b) {
                          final aTs = a.data()['createdAt'] as Timestamp?;
                          final bTs = b.data()['createdAt'] as Timestamp?;
                          final aMs = aTs?.millisecondsSinceEpoch ?? 0;
                          final bMs = bTs?.millisecondsSinceEpoch ?? 0;
                          return bMs.compareTo(aMs);
                        });

                      return ListView.separated(
                        itemCount: docs.length,
                        separatorBuilder: (_, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final docId = docs[index].id;
                          final data = docs[index].data();
                          final name = (data['name'] as String?) ?? 'Unnamed';
                          final duration =
                              (data['durationMinutes'] as num?)?.toInt() ?? 0;
                          final price =
                              (data['price'] as num?)?.toDouble() ?? 0;
                          final currency =
                              (data['currency'] as String?)
                                      ?.trim()
                                      .isNotEmpty ==
                                  true
                              ? data['currency'] as String
                              : 'USD';
                          final isActive = (data['isActive'] as bool?) ?? true;

                          return ListTile(
                            title: Text(name),
                            subtitle: Text(
                              '${duration}m - $currency ${price.toStringAsFixed(2)}',
                            ),
                            trailing: Wrap(
                              spacing: 8,
                              children: [
                                TextButton(
                                  onPressed: () => _toggleServiceActive(
                                    context,
                                    shopId,
                                    docId,
                                    !isActive,
                                  ),
                                  child: Text(
                                    isActive ? 'Deactivate' : 'Activate',
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      _deleteService(context, shopId, docId),
                                  child: const Text('Remove'),
                                ),
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
          );
        },
      ),
    );
  }
}
