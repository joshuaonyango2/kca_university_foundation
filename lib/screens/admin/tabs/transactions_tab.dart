// lib/screens/admin/tabs/transactions_tab.dart

import 'package:flutter/material.dart';

class AdminTransactionsTab extends StatefulWidget {
  const AdminTransactionsTab({super.key});

  @override
  State<AdminTransactionsTab> createState() => _AdminTransactionsTabState();
}

class _AdminTransactionsTabState extends State<AdminTransactionsTab> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Transactions Tab',
              style: TextStyle(fontSize: 24, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            const Text('Copy your existing Transactions implementation here'),
          ],
        ),
      ),
    );
  }
}