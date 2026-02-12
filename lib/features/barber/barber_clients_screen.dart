import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/data/firestore_data_mapper.dart';

class BarberClientsScreen extends StatefulWidget {
  const BarberClientsScreen({super.key});

  @override
  State<BarberClientsScreen> createState() => _BarberClientsScreenState();
}

class _BarberClientsScreenState extends State<BarberClientsScreen> {
  String _search = '';
  _ClientFilter _filter = _ClientFilter.all;

  void _comingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label screen coming next'),
        behavior: SnackBarBehavior.floating,
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
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('appointments')
            .where('barberId', isEqualTo: user.uid)
            .limit(300)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.gold),
            );
          }

          final clients = _buildClients(snapshot.data?.docs ?? const []);
          final total = clients.length;
          final returning = clients.where((c) => c.visits >= 3).length;
          final returningPercent = total == 0
              ? 0
              : ((returning / total) * 100).round();

          final normalizedSearch = _search.trim().toLowerCase();
          final filtered = clients.where((c) {
            final matchesText =
                normalizedSearch.isEmpty ||
                c.name.toLowerCase().contains(normalizedSearch) ||
                c.lastNote.toLowerCase().contains(normalizedSearch);
            final matchesFilter = switch (_filter) {
              _ClientFilter.all => true,
              _ClientFilter.vip => c.tier == _ClientTier.vip,
              _ClientFilter.loyal => c.tier == _ClientTier.loyal,
              _ClientFilter.newClient => c.tier == _ClientTier.newClient,
              _ClientFilter.blocked => c.tier == _ClientTier.blocked,
            };
            return matchesText && matchesFilter;
          }).toList();

          return SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              children: [
                Row(
                  children: [
                    const Text(
                      'Clients',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF070A12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.gold.withValues(alpha: 0.2),
                        ),
                      ),
                      child: IconButton(
                        onPressed: () => _comingSoon(context, 'Add client'),
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          color: AppColors.gold,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _statDotRow(
                      color: AppColors.gold,
                      text: 'Clients $total Total',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '•',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                    ),
                    _statDotRow(
                      color: const Color(0xFF10B981),
                      text: '$returningPercent% Returning',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF070A12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF586278),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: (v) => setState(() => _search = v),
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search clients',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _chip(_ClientFilter.all, 'All'),
                      _chip(_ClientFilter.vip, 'VIP'),
                      _chip(_ClientFilter.loyal, 'Loyal'),
                      _chip(_ClientFilter.newClient, 'New'),
                      _chip(_ClientFilter.blocked, 'Blocked'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (filtered.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070A12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.group_off_rounded,
                          size: 44,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'No clients found',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final client in filtered) ...[
                  _clientCard(client),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statDotRow({required Color color, required String text}) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _chip(_ClientFilter value, String label) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold : const Color(0xFF070A12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? AppColors.gold
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? const Color(0xFF05070A)
                  : Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _clientCard(_ClientItem c) {
    final isVip = c.tier == _ClientTier.vip;
    final badgeBg = isVip
        ? AppColors.gold.withValues(alpha: 0.15)
        : const Color(0xFF1E293B);
    final badgeBorder = isVip
        ? AppColors.gold.withValues(alpha: 0.3)
        : Colors.white.withValues(alpha: 0.08);
    final badgeTextColor = isVip
        ? AppColors.gold
        : Colors.white.withValues(alpha: 0.65);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF070A12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _avatar(c),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isVip) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.star_rounded,
                        color: AppColors.gold,
                        size: 16,
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: badgeBorder),
                      ),
                      child: Text(
                        '${c.visits} Visits • ${c.label}',
                        style: TextStyle(
                          color: badgeTextColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  'Last visit: ${_formatDate(c.lastVisit)}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 7),
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                Text(
                  c.lastNote,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _avatar(_ClientItem c) {
    if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.35),
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.network(
          c.avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _avatarFallback(c),
        ),
      );
    }
    return _avatarFallback(c);
  }

  Widget _avatarFallback(_ClientItem c) {
    final initial = c.name.trim().isEmpty
        ? '?'
        : c.name.trim()[0].toUpperCase();
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

enum _ClientFilter { all, vip, loyal, newClient, blocked }

enum _ClientTier { vip, loyal, returning, newClient, blocked }

class _ClientItem {
  const _ClientItem({
    required this.key,
    required this.name,
    required this.visits,
    required this.lastVisit,
    required this.lastNote,
    required this.tier,
    this.avatarUrl,
  });

  final String key;
  final String name;
  final int visits;
  final DateTime lastVisit;
  final String lastNote;
  final _ClientTier tier;
  final String? avatarUrl;

  String get label => switch (tier) {
    _ClientTier.vip => 'VIP',
    _ClientTier.loyal => 'Loyal',
    _ClientTier.returning => 'Returning',
    _ClientTier.newClient => 'New',
    _ClientTier.blocked => 'Blocked',
  };
}

List<_ClientItem> _buildClients(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final map = <String, _ClientAccumulator>{};
  for (final doc in docs) {
    final data = doc.data();
    final ts = data['startAt'] as Timestamp?;
    if (ts == null) continue;
    final startAt = ts.toDate();
    final id = (data['customerId'] as String?)?.trim();
    final fullName = FirestoreDataMapper.customerFullName(data).trim();
    final email =
        (data['customerEmail'] as String?)?.trim().toLowerCase() ?? '';
    final key = (id != null && id.isNotEmpty)
        ? 'id:$id'
        : (email.isNotEmpty
              ? 'email:$email'
              : 'name:${fullName.toLowerCase()}');
    if (key.endsWith(':')) continue;

    final noteRaw =
        (data['customerNote'] as String?) ?? (data['notes'] as String?);
    final note = (noteRaw == null || noteRaw.trim().isEmpty)
        ? 'No notes yet.'
        : noteRaw.trim();
    final avatar = (data['customerPhotoUrl'] as String?)?.trim();
    final isBlocked = (data['customerBlocked'] as bool?) ?? false;
    final name = fullName.isEmpty ? 'Client' : fullName;

    map.update(
      key,
      (existing) => existing.add(startAt: startAt, note: note),
      ifAbsent: () => _ClientAccumulator(
        key: key,
        name: name,
        visits: 1,
        lastVisit: startAt,
        lastNote: note,
        avatarUrl: avatar,
        blocked: isBlocked,
      ),
    );
  }

  final clients = map.values.map((v) => v.toClient()).toList()
    ..sort((a, b) => b.lastVisit.compareTo(a.lastVisit));
  return clients;
}

class _ClientAccumulator {
  _ClientAccumulator({
    required this.key,
    required this.name,
    required this.visits,
    required this.lastVisit,
    required this.lastNote,
    required this.avatarUrl,
    required this.blocked,
  });

  final String key;
  final String name;
  final int visits;
  final DateTime lastVisit;
  final String lastNote;
  final String? avatarUrl;
  final bool blocked;

  _ClientAccumulator add({required DateTime startAt, required String note}) {
    final newest = startAt.isAfter(lastVisit);
    return _ClientAccumulator(
      key: key,
      name: name,
      visits: visits + 1,
      lastVisit: newest ? startAt : lastVisit,
      lastNote: newest ? note : lastNote,
      avatarUrl: avatarUrl,
      blocked: blocked,
    );
  }

  _ClientItem toClient() {
    final tier = blocked
        ? _ClientTier.blocked
        : (visits >= 20)
        ? _ClientTier.vip
        : (visits >= 10)
        ? _ClientTier.loyal
        : (visits >= 3)
        ? _ClientTier.returning
        : _ClientTier.newClient;

    return _ClientItem(
      key: key,
      name: name,
      visits: visits,
      lastVisit: lastVisit,
      lastNote: lastNote,
      tier: tier,
      avatarUrl: avatarUrl,
    );
  }
}

String _formatDate(DateTime date) {
  const months = <String>[
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
  return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
}
