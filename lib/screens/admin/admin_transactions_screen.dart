// lib/screens/admin/admin_transactions_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/routes.dart';
import 'widgets/admin_layout.dart';

class _KCA {
  static const navy  = Color(0xFF1B2263);
  static const gold  = Color(0xFFF5A800);
  static const white = Colors.white;
  static const bg    = Color(0xFFF0F2F8);
}

class AdminTransactionsScreen extends StatefulWidget {
  const AdminTransactionsScreen({super.key});

  @override
  State<AdminTransactionsScreen> createState() =>
      _AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState
    extends State<AdminTransactionsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery  = '';
  String _filterStatus = 'all'; // all | completed | pending | failed

  double _totalFiltered = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Transactions',
      activeRoute: AppRoutes.adminTransactions,
      actions: [
        OutlinedButton.icon(
          onPressed: _exportCSV,
          icon: const Icon(Icons.download_outlined,
              size: 18, color: _KCA.navy),
          label: const Text('Export CSV',
              style: TextStyle(color: _KCA.navy)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey[300]!),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
      child: Column(
        children: [
          // ── Search + filter bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search by donor or campaign...',
                      prefixIcon:
                      const Icon(Icons.search, color: _KCA.navy),
                      filled: true,
                      fillColor: _KCA.white,
                      contentPadding:
                      const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _filterChip('All', 'all'),
                const SizedBox(width: 6),
                _filterChip('Completed', 'completed'),
                const SizedBox(width: 6),
                _filterChip('Pending', 'pending'),
                const SizedBox(width: 6),
                _filterChip('Failed', 'failed'),
              ],
            ),
          ),

          // ── Summary bar ──────────────────────────────────────────────────
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('donations')
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];
              final filtered = _applyFilters(docs);
              double total = 0;
              for (final d in filtered) {
                total += ((d.data()
                as Map<String, dynamic>)['amount']
                as num? ??
                    0)
                    .toDouble();
              }

              return Container(
                margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: _KCA.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _summaryItem(
                        '${filtered.length}', 'Transactions'),
                    Container(
                        width: 1,
                        height: 28,
                        color: Colors.white24),
                    _summaryItem(
                        'KES ${_fmt(total)}', 'Total Amount'),
                    Container(
                        width: 1,
                        height: 28,
                        color: Colors.white24),
                    _summaryItem(
                        filtered
                            .where((d) =>
                        (d.data() as Map<String,
                            dynamic>)['status'] ==
                            'completed')
                            .length
                            .toString(),
                        'Completed'),
                  ],
                ),
              );
            },
          ),

          // ── Transactions list ────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('donations')
                  .orderBy('created_at', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          valueColor:
                          AlwaysStoppedAnimation(_KCA.navy)));
                }

                final docs = snapshot.data?.docs ?? [];
                final filtered = _applyFilters(docs);

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No transactions found',
                            style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 15)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                  const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final data = filtered[i].data()
                    as Map<String, dynamic>;
                    data['id'] = filtered[i].id;
                    return _TransactionCard(data: data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<QueryDocumentSnapshot> _applyFilters(
      List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data   = doc.data() as Map<String, dynamic>;
      final donor  = (data['donor_name'] as String? ?? '').toLowerCase();
      final camp   = (data['campaign_title'] as String? ?? '').toLowerCase();
      final status = data['status'] as String? ?? 'completed';

      final matchSearch = _searchQuery.isEmpty ||
          donor.contains(_searchQuery) ||
          camp.contains(_searchQuery);
      final matchStatus =
          _filterStatus == 'all' || status == _filterStatus;

      return matchSearch && matchStatus;
    }).toList();
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = value),
      child: Container(
        padding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _KCA.navy : _KCA.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: isSelected ? _KCA.navy : Colors.grey[300]!),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? _KCA.white : Colors.grey[700],
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _summaryItem(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: _KCA.white,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        Text(label,
            style: TextStyle(
                color: Colors.white.withAlpha(180), fontSize: 11)),
      ],
    );
  }

  void _exportCSV() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV export coming soon — M-Pesa integration required'),
        backgroundColor: _KCA.navy,
      ),
    );
  }

  String _fmt(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);
}

// ── Transaction card ──────────────────────────────────────────────────────────
class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TransactionCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final donor    = data['donor_name'] as String? ?? 'Unknown';
    final campaign = data['campaign_title'] as String? ?? '—';
    final amount   = (data['amount'] as num? ?? 0).toDouble();
    final status   = data['status'] as String? ?? 'completed';
    final method   = data['payment_method'] as String? ?? 'M-Pesa';
    final date     = data['created_at'] as String? ?? '';
    final ref      = data['transaction_ref'] as String? ?? data['id'] as String? ?? '—';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _KCA.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _statusColor(status).withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(_statusIcon(status),
                color: _statusColor(status), size: 20),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(donor,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: _KCA.navy)),
                const SizedBox(height: 2),
                Text(campaign,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.tag, size: 11, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text(ref,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400])),
                    const SizedBox(width: 10),
                    Icon(Icons.phone_android,
                        size: 11, color: Colors.grey[400]),
                    const SizedBox(width: 3),
                    Text(method,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400])),
                  ],
                ),
              ],
            ),
          ),

          // Right side
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('KES ${_fmt(amount)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: _KCA.navy)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor(status).withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: _statusColor(status))),
              ),
              const SizedBox(height: 4),
              Text(
                  date.length >= 10 ? date.substring(0, 10) : date,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400])),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'completed': return const Color(0xFF10B981);
      case 'pending':   return const Color(0xFFF59E0B);
      case 'failed':    return Colors.red;
      default:          return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'completed': return Icons.check_circle_outline;
      case 'pending':   return Icons.hourglass_empty;
      case 'failed':    return Icons.cancel_outlined;
      default:          return Icons.payments_outlined;
    }
  }

  String _fmt(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);
}