// lib/screens/admin/tabs/donors_tab.dart
// 👥 DONORS TAB - MOBILE RESPONSIVE

import 'package:flutter/material.dart';

class AdminDonorsTab extends StatefulWidget {
  const AdminDonorsTab({super.key});

  @override
  State<AdminDonorsTab> createState() => _AdminDonorsTabState();
}

class _AdminDonorsTabState extends State<AdminDonorsTab> {
  String _searchQuery = '';
  String _sortBy = 'recent'; // recent, amount, name

  // Simulated donor data
  final List<Donor> _donors = [
    Donor(
      id: '1',
      name: 'John Kamau',
      email: 'john.kamau@email.com',
      totalDonations: 250000,
      donationCount: 12,
      lastDonation: DateTime.now().subtract(const Duration(days: 2)),
      phone: '+254 712 345 678',
      isVerified: true,
    ),
    Donor(
      id: '2',
      name: 'Sarah Wanjiku',
      email: 'sarah.w@email.com',
      totalDonations: 180000,
      donationCount: 8,
      lastDonation: DateTime.now().subtract(const Duration(days: 5)),
      phone: '+254 723 456 789',
      isVerified: true,
    ),
    Donor(
      id: '3',
      name: 'David Omondi',
      email: 'david.o@email.com',
      totalDonations: 95000,
      donationCount: 15,
      lastDonation: DateTime.now().subtract(const Duration(days: 1)),
      phone: '+254 734 567 890',
      isVerified: false,
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
          _buildStatsCards(isMobile),
          Expanded(child: _buildDonorsList(isMobile)),
        ],
      ),
    );
  }

  // 📊 HEADER
  Widget _buildHeader(bool isMobile) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Donors',
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Search & Filter
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search donors...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),
              if (!isMobile) ...[
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(value: 'recent', child: Text('Recent')),
                    DropdownMenuItem(value: 'amount', child: Text('Amount')),
                    DropdownMenuItem(value: 'name', child: Text('Name')),
                  ],
                  onChanged: (value) {
                    setState(() => _sortBy = value!);
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // 📊 STATS CARDS
  Widget _buildStatsCards(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: isMobile ? 12 : 16,
        mainAxisSpacing: isMobile ? 12 : 16,
        childAspectRatio: isMobile ? 1.5 : 1.8,
        children: [
          _buildStatCard(
            'Total Donors',
            '342',
            Icons.people,
            Colors.blue,
            isMobile,
          ),
          _buildStatCard(
            'Active (30d)',
            '128',
            Icons.trending_up,
            Colors.green,
            isMobile,
          ),
          _buildStatCard(
            'Avg Donation',
            'KES 45K',
            Icons.attach_money,
            Colors.orange,
            isMobile,
          ),
          _buildStatCard(
            'Verified',
            '98%',
            Icons.verified_user,
            Colors.purple,
            isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      bool isMobile,
      ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: isMobile ? 20 : 24),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 11 : 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: isMobile ? 18 : 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 📋 DONORS LIST
  Widget _buildDonorsList(bool isMobile) {
    final filteredDonors = _donors.where((donor) {
      if (_searchQuery.isEmpty) return true;
      return donor.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          donor.email.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Sort
    if (_sortBy == 'amount') {
      filteredDonors.sort((a, b) => b.totalDonations.compareTo(a.totalDonations));
    } else if (_sortBy == 'name') {
      filteredDonors.sort((a, b) => a.name.compareTo(b.name));
    } else {
      filteredDonors.sort((a, b) => b.lastDonation.compareTo(a.lastDonation));
    }

    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 16 : 32),
      itemCount: filteredDonors.length,
      itemBuilder: (context, index) {
        final donor = filteredDonors[index];
        return _buildDonorCard(donor, isMobile);
      },
    );
  }

  // 👤 DONOR CARD
  Widget _buildDonorCard(Donor donor, bool isMobile) {
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
          children: [
            Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: isMobile ? 24 : 30,
                  backgroundColor: const Color(0xFF2563EB).withAlpha(25),
                  child: Text(
                    donor.name[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2563EB),
                    ),
                  ),
                ),
                SizedBox(width: isMobile ? 12 : 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              donor.name,
                              style: TextStyle(
                                fontSize: isMobile ? 15 : 17,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (donor.isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified,
                              size: 16,
                              color: Color(0xFF2563EB),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        donor.email,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.grey[600],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!isMobile) ...[
                        const SizedBox(height: 4),
                        Text(
                          donor.phone,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Amount (Desktop)
                if (!isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'KES ${_formatCurrency(donor.totalDonations)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      Text(
                        '${donor.donationCount} donations',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Mobile Stats
            if (isMobile) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Donated',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'KES ${_formatCurrency(donor.totalDonations)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Donations',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${donor.donationCount}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Actions
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: isMobile ? 14 : 16,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Text(
                  'Last: ${_formatDate(donor.lastDonation)}',
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _viewDonorDetails(donor),
                  child: const Text('View Details'),
                ),
                IconButton(
                  onPressed: () => _contactDonor(donor),
                  icon: const Icon(Icons.email_outlined, size: 20),
                  tooltip: 'Contact',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 🔧 ACTIONS
  void _viewDonorDetails(Donor donor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('View details: ${donor.name}'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _contactDonor(Donor donor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Contact: ${donor.email}'),
        behavior: SnackBarBehavior.floating,
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
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '${difference}d ago';
    if (difference < 30) return '${(difference / 7).floor()}w ago';
    return '${(difference / 30).floor()}mo ago';
  }
}

// 👤 DONOR MODEL
class Donor {
  final String id;
  final String name;
  final String email;
  final String phone;
  final double totalDonations;
  final int donationCount;
  final DateTime lastDonation;
  final bool isVerified;

  Donor({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.totalDonations,
    required this.donationCount,
    required this.lastDonation,
    required this.isVerified,
  });
}