// lib/screens/admin/tabs/reports_tab.dart

import 'package:flutter/material.dart';

class AdminReportsTab extends StatelessWidget {
  const AdminReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Reports Tab',
              style: TextStyle(fontSize: 24, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            const Text('Copy your existing Reports implementation here'),
          ],
        ),
      ),
    );
  }
}