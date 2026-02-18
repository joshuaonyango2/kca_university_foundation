// lib/screens/admin/tabs/transactions_tab.dart
// 💰 TRANSACTIONS TAB - MOBILE RESPONSIVE

import 'package:flutter/material.dart';

class AdminTransactionsTab extends StatefulWidget {
  const AdminTransactionsTab({super.key});

  @override
  State<AdminTransactionsTab> createState() => _AdminTransactionsTabState();
}

class _AdminTransactionsTabState extends State<AdminTransactionsTab> {
  String _filterStatus = 'all'; // all, success, pending, failed
  String _filterPeriod = '7days'; // today, 7days, 30days, all

  // Simulated transaction data
  final List<Transaction> _transactions = [
    Transaction(
      id: 'TXN001',
      donorName: 'John Kamau',
      amount: 50000,
      campaign: 'Scholarship Fund',
      method: 'M-Pesa',
      status: 'success',
      date: DateTime.now().subtract(const Duration(hours: 2)),
      reference: 'ABC123XYZ',
    ),
    Transaction(
      id: 'TXN002',
      donorName: 'Sarah Wanjiku',
      amount: 25000,
      campaign: 'Infrastructure',
      method: 'Card',
      status: 'success',
      date: DateTime.now().subtract(const Duration(hours: 5)),
      reference: 'DEF456UVW',
    ),
    Transaction(
      id: 'TXN003',
      donorName: 'David Omondi',
      amount: 10000,
      campaign: 'Research Fund',
      method: 'M-Pesa',
      status: 'pending',
      date: DateTime.now().subtract(const Duration(minutes: 30)),
      reference: 'GHI789RST',
    ),
    Transaction(
      id: 'TXN004',
      donorName: 'Mary Akinyi',
      amount: 15000,
      campaign: 'Endowment',
      method: 'Bank Transfer',
      status: 'failed',
      date: DateTime.now().subtract(const Duration(days: 1)),
      reference: 'JKL012OPQ',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          _buildHeader(isMobile),
          _buildFilters(isMobile),
          _buildStatsRow(isMobile),
          Expanded(child: _buildTransactionsList(isMobile)),
        ],
      ),
    );
  }

  // 📊 HEADER
  Widget _buildHeader(bool isMobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Transactions',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Recent donation transactions',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          if (!isMobile)
            OutlinedButton.icon(
              onPressed: _exportTransactions,
              icon: const Icon(Icons.download),
              label: const Text('Export'),
            ),
        ],
      ),
    );
  }

  // 🔍 FILTERS
  Widget _buildFilters(bool isMobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 32,
        0,
        isMobile ? 16 : 32,
        16,
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All', 'all', _filterStatus, (value) {
                    setState(() => _filterStatus = value);
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('Success', 'success', _filterStatus, (value) {
                    setState(() => _filterStatus = value);
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('Pending', 'pending', _filterStatus, (value) {
                    setState(() => _filterStatus = value);
                  }),
                  const SizedBox(width: 8),
                  _buildFilterChip('Failed', 'failed', _filterStatus, (value) {
                    setState(() => _filterStatus = value);
                  }),
                ],
              ),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 16),
            DropdownButton<String>(
              value: _filterPeriod,
              items: const [
                DropdownMenuItem(value: 'today', child: Text('Today')),
                DropdownMenuItem(value: '7days', child: Text('Last 7 days')),
                DropdownMenuItem(value: '30days', child: Text('Last 30 days')),
                DropdownMenuItem(value: 'all', child: Text('All time')),
              ],
              onChanged: (value) {
                setState(() => _filterPeriod = value!);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(
      String label,
      String value,
      String currentValue,
      Function(String) onSelected,
      ) {
    final isSelected = currentValue == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onSelected(value),
      selectedColor: const Color(0xFF2563EB).withAlpha(51),
      checkmarkColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF2563EB) : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: 13,
      ),
    );
  }

  // 📊 STATS ROW
  Widget _buildStatsRow(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total',
              'KES 2.45M',
              Colors.blue,
              isMobile,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: _buildStatCard(
              'Success',
              '342',
              Colors.green,
              isMobile,
            ),
          ),
          SizedBox(width: isMobile ? 12 : 16),
          Expanded(
            child: _buildStatCard(
              'Pending',
              '5',
              Colors.orange,
              isMobile,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 18 : 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // 📋 TRANSACTIONS LIST
  Widget _buildTransactionsList(bool isMobile) {
    final filteredTxns = _transactions.where((txn) {
      if (_filterStatus != 'all' && txn.status != _filterStatus) return false;
      // Add period filtering here
      return true;
    }).toList();

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      itemCount: filteredTxns.length,
      itemBuilder: (context, index) {
        final txn = filteredTxns[index];
        return _buildTransactionCard(txn, isMobile);
      },
    );
  }

  // 💳 TRANSACTION CARD
  Widget _buildTransactionCard(Transaction txn, bool isMobile) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getStatusColor(txn.status).withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getPaymentIcon(txn.method),
                    color: _getStatusColor(txn.status),
                    size: isMobile ? 20 : 24,
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        txn.donorName,
                        style: TextStyle(
                          fontSize: isMobile ? 15 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        txn.campaign,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                // Amount & Status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'KES ${_formatCurrency(txn.amount)}',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(txn.status),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildStatusBadge(txn.status, isMobile),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Details Row
            Wrap(
              spacing: isMobile ? 16 : 24,
              runSpacing: 8,
              children: [
                _buildDetailItem(
                  Icons.payment,
                  txn.method,
                  isMobile,
                ),
                _buildDetailItem(
                  Icons.tag,
                  txn.reference,
                  isMobile,
                ),
                _buildDetailItem(
                  Icons.access_time,
                  _formatDateTime(txn.date),
                  isMobile,
                ),
              ],
            ),

            // Actions
            if (!isMobile) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _viewReceipt(txn),
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('View Receipt'),
                  ),
                  if (txn.status == 'pending')
                    TextButton.icon(
                      onPressed: () => _verifyTransaction(txn),
                      icon: const Icon(Icons.check_circle, size: 18),
                      label: const Text('Verify'),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status, bool isMobile) {
    Color color = _getStatusColor(status);
    String text = status.toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isMobile ? 10 : 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text, bool isMobile) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: isMobile ? 14 : 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: isMobile ? 12 : 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // 🔧 ACTIONS
  void _exportTransactions() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exporting transactions...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _viewReceipt(Transaction txn) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View receipt: ${txn.id}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _verifyTransaction(Transaction txn) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Verify transaction: ${txn.id}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 🔧 HELPERS
  Color _getStatusColor(String status) {
    switch (status) {
      case 'success':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getPaymentIcon(String method) {
    switch (method.toLowerCase()) {
      case 'm-pesa':
        return Icons.phone_android;
      case 'card':
        return Icons.credit_card;
      case 'bank transfer':
        return Icons.account_balance;
      default:
        return Icons.payment;
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}

// 💳 TRANSACTION MODEL
class Transaction {
  final String id;
  final String donorName;
  final double amount;
  final String campaign;
  final String method;
  final String status;
  final DateTime date;
  final String reference;

  Transaction({
    required this.id,
    required this.donorName,
    required this.amount,
    required this.campaign,
    required this.method,
    required this.status,
    required this.date,
    required this.reference,
  });
}