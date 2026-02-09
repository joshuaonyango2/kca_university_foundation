// lib/screens/admin/tabs/donors_tab.dart

import 'package:flutter/material.dart';

class AdminDonorsTab extends StatefulWidget {
  const AdminDonorsTab({super.key});

  @override
  State<AdminDonorsTab> createState() => _AdminDonorsTabState();
}

class _AdminDonorsTabState extends State<AdminDonorsTab> {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[100],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Donors Tab',
              style: TextStyle(fontSize: 24, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            const Text('Copy your existing Donors implementation here'),
          ],
        ),
      ),
    );
  }
}