// lib/screens/admin/tabs/campaigns_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/campaign_provider.dart';

class AdminCampaignsTab extends StatefulWidget {
  const AdminCampaignsTab({super.key});

  @override
  State<AdminCampaignsTab> createState() => _AdminCampaignsTabState();
}

class _AdminCampaignsTabState extends State<AdminCampaignsTab> {
  @override
  Widget build(BuildContext context) {
    return Consumer<CampaignProvider>(
      builder: (context, provider, _) {
        return Container(
          color: Colors.grey[100],
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.campaign, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Campaigns Tab',
                  style: TextStyle(fontSize: 24, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                const Text('Copy your existing Campaigns implementation here'),
              ],
            ),
          ),
        );
      },
    );
  }
}