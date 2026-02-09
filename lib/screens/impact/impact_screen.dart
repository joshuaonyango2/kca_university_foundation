import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // If using CampaignProvider
import '../../../../providers/campaign_provider.dart'; // Assume exists

class ImpactScreen extends StatelessWidget {
  final String? campaignId; // Optional filter

  const ImpactScreen({super.key, this.campaignId});

  @override
  Widget build(BuildContext context) {
    // Fetch updates from provider if campaignId provided
    return Scaffold(
      appBar: AppBar(title: const Text('Impact Stories')),
      body: const Center(child: Text('Impact updates, photos, videos here')), // TODO: ListView of stories
    );
  }
}