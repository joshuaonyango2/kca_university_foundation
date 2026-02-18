// lib/screens/admin/tabs/campaigns_tab.dart
// 📢 CAMPAIGNS TAB - SAFE VERSION (Works with any Campaign model)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/campaign_provider.dart';

class AdminCampaignsTab extends StatefulWidget {
  const AdminCampaignsTab({super.key});

  @override
  State<AdminCampaignsTab> createState() => _AdminCampaignsTabState();
}

class _AdminCampaignsTabState extends State<AdminCampaignsTab> {
  String _filterStatus = 'all'; // all, active, completed, draft

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CampaignProvider>(context, listen: false).fetchCampaigns();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: Colors.grey[100],
      child: Stack(
        children: [
          Column(
            children: [
              // Filter Tabs
              _buildFilterTabs(isMobile),

              // Campaign List
              Expanded(
                child: _buildCampaignList(isMobile),
              ),
            ],
          ),

          // Floating Action Button (Mobile)
          if (isMobile)
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: () => _showCreateCampaignDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('New Campaign'),
                backgroundColor: const Color(0xFF2563EB),
              ),
            ),
        ],
      ),
    );
  }

  // 📊 FILTER TABS
  Widget _buildFilterTabs(bool isMobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 32,
        vertical: 16,
      ),
      child: Column(
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Campaigns',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isMobile)
                ElevatedButton.icon(
                  onPressed: () => _showCreateCampaignDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('New Campaign'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('Active', 'active'),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', 'completed'),
                const SizedBox(width: 8),
                _buildFilterChip('Draft', 'draft'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filterStatus == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filterStatus = value);
      },
      selectedColor: const Color(0xFF2563EB).withAlpha(51),
      checkmarkColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF2563EB) : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  // 📋 CAMPAIGN LIST
  Widget _buildCampaignList(bool isMobile) {
    return Consumer<CampaignProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.campaigns.isEmpty) {
          return _buildEmptyState();
        }

        // Simple filter - just show all for now
        // You can enhance this later when your model is updated
        final filteredCampaigns = provider.campaigns;

        return ListView.builder(
          padding: EdgeInsets.all(isMobile ? 16 : 32),
          itemCount: filteredCampaigns.length,
          itemBuilder: (context, index) {
            final campaign = filteredCampaigns[index];
            return _buildCampaignCard(campaign, isMobile);
          },
        );
      },
    );
  }

  // 📦 CAMPAIGN CARD
  Widget _buildCampaignCard(dynamic campaign, bool isMobile) {
    // Safe property access with fallbacks
    final title = _getProperty(campaign, 'title', 'Untitled Campaign');
    final description = _getProperty(campaign, 'description', 'No description');
    final imageUrl = _getProperty(campaign, 'imageUrl', '');  // Empty string default
    final targetAmount = _getNumericProperty(campaign, 'targetAmount', 1000000);
    final raisedAmount = _getNumericProperty(campaign, 'raisedAmount', 0);
    final endDate = _getDateProperty(campaign, 'endDate', DateTime.now().add(const Duration(days: 30)));
    final donorCount = _getNumericProperty(campaign, 'donorCount', 0).toInt();

    final progress = targetAmount > 0 ? raisedAmount / targetAmount : 0.0;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          if (imageUrl.isNotEmpty)  // Check if not empty instead of null
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                imageUrl,
                height: isMobile ? 150 : 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: isMobile ? 150 : 200,
                  color: Colors.grey[300],
                  child: const Icon(Icons.image, size: 64, color: Colors.grey),
                ),
              ),
            ),

          // Content
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & Status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildStatusBadge(progress, isMobile),
                  ],
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // Progress Bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'KES ${_formatCurrency(raisedAmount)}',
                          style: TextStyle(
                            fontSize: isMobile ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                        Text(
                          '${(progress * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress > 1 ? 1 : progress,
                        minHeight: 8,
                        backgroundColor: Colors.grey[200],
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Goal: KES ${_formatCurrency(targetAmount)}',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stats Row
                Row(
                  children: [
                    _buildStat(
                      Icons.people,
                      '$donorCount',
                      'Donors',
                      isMobile,
                    ),
                    SizedBox(width: isMobile ? 16 : 24),
                    _buildStat(
                      Icons.calendar_today,
                      _formatDate(endDate),
                      'Ends',
                      isMobile,
                    ),
                  ],
                ),

                // Actions
                if (isMobile)
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _editCampaign(campaign),
                              icon: const Icon(Icons.edit, size: 18),
                              label: const Text('Edit'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _viewDetails(campaign),
                              icon: const Icon(Icons.visibility, size: 18),
                              label: const Text('View'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _deleteCampaign(campaign),
                            icon: const Icon(Icons.delete, color: Colors.red),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _viewDetails(campaign),
                        icon: const Icon(Icons.visibility),
                        label: const Text('View Details'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _editCampaign(campaign),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit'),
                      ),
                      IconButton(
                        onPressed: () => _deleteCampaign(campaign),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(double progress, bool isMobile) {
    Color color;
    String text;

    if (progress >= 1.0) {
      color = Colors.green;
      text = 'Completed';
    } else if (progress > 0) {
      color = const Color(0xFF2563EB);
      text = 'Active';
    } else {
      color = Colors.grey;
      text = 'Draft';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: isMobile ? 11 : 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStat(IconData icon, String value, String label, bool isMobile) {
    return Row(
      children: [
        Icon(icon, size: isMobile ? 16 : 18, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: isMobile ? 11 : 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 🏜️ EMPTY STATE
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 80,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No Campaigns Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first campaign to get started',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showCreateCampaignDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Campaign'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔧 SAFE PROPERTY GETTERS
  String _getProperty(dynamic obj, String property, String fallback) {
    try {
      final value = (obj as dynamic);
      switch (property) {
        case 'title':
          return value.title?.toString() ?? fallback;
        case 'description':
          return value.description?.toString() ?? fallback;
        case 'imageUrl':
          final url = value.imageUrl?.toString();
          return url ?? '';  // Return empty string instead of null
        default:
          return fallback;
      }
    } catch (e) {
      return fallback;
    }
  }

  double _getNumericProperty(dynamic obj, String property, double fallback) {
    try {
      final value = (obj as dynamic);
      switch (property) {
        case 'targetAmount':
          return (value.targetAmount ?? fallback).toDouble();
        case 'raisedAmount':
          return (value.raisedAmount ?? fallback).toDouble();
        case 'donorCount':
          return (value.donorCount ?? fallback).toDouble();
        default:
          return fallback;
      }
    } catch (e) {
      return fallback;
    }
  }

  DateTime _getDateProperty(dynamic obj, String property, DateTime fallback) {
    try {
      final value = (obj as dynamic);
      if (property == 'endDate') {
        return value.endDate ?? fallback;
      }
      return fallback;
    } catch (e) {
      return fallback;
    }
  }

  // 🔧 ACTIONS
  void _showCreateCampaignDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Create campaign feature - Connect to your backend'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _editCampaign(dynamic campaign) {
    final title = _getProperty(campaign, 'title', 'this campaign');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit campaign: $title'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _viewDetails(dynamic campaign) {
    final title = _getProperty(campaign, 'title', 'this campaign');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View details: $title'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _deleteCampaign(dynamic campaign) {
    final title = _getProperty(campaign, 'title', 'this campaign');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Campaign'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Campaign deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // 🔧 HELPERS
  String _formatCurrency(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toStringAsFixed(0);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now).inDays;

    if (difference < 0) return 'Ended';
    if (difference == 0) return 'Today';
    if (difference == 1) return 'Tomorrow';
    return '${difference}d';
  }
}