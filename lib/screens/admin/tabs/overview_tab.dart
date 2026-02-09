// lib/screens/admin/tabs/overview_tab.dart
// 📱 MOBILE-RESPONSIVE VERSION

import 'package:flutter/material.dart';

class AdminOverviewTab extends StatelessWidget {
  const AdminOverviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      color: Colors.grey[100],
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsCards(context, isMobile),
            const SizedBox(height: 24),

            // Charts - Stack on mobile, row on desktop
            if (isMobile)
              Column(
                children: [
                  _buildDonationsChart(context),
                  const SizedBox(height: 24),
                  _buildCampaignProgress(context),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildDonationsChart(context),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildCampaignProgress(context),
                  ),
                ],
              ),

            const SizedBox(height: 24),
            _buildRecentActivity(context, isMobile),
          ],
        ),
      ),
    );
  }

  // 📊 STATS CARDS - Responsive Grid
  Widget _buildStatsCards(BuildContext context, bool isMobile) {
    final List<_StatCard> stats = [
      _StatCard(
        title: 'Total Donations',
        value: 'KES 2.45M',
        change: '+12.5%',
        isPositive: true,
        icon: Icons.attach_money,
        color: const Color(0xFF10B981),
      ),
      _StatCard(
        title: 'Active Campaigns',
        value: '8',
        change: '+2',
        isPositive: true,
        icon: Icons.campaign,
        color: const Color(0xFF2563EB),
      ),
      _StatCard(
        title: 'Total Donors',
        value: '342',
        change: '+28',
        isPositive: true,
        icon: Icons.people,
        color: const Color(0xFFF59E0B),
      ),
      _StatCard(
        title: 'This Month',
        value: 'KES 450K',
        change: '+8.2%',
        isPositive: true,
        icon: Icons.trending_up,
        color: const Color(0xFF8B5CF6),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 4,
        crossAxisSpacing: isMobile ? 12 : 16,
        mainAxisSpacing: isMobile ? 12 : 16,
        childAspectRatio: isMobile ? 1.1 : 1.3,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final stat = stats[index];
        return _buildStatCard(stat, isMobile);
      },
    );
  }

  Widget _buildStatCard(_StatCard stat, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 8 : 12),
                decoration: BoxDecoration(
                  color: stat.color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  stat.icon,
                  color: stat.color,
                  size: isMobile ? 20 : 24,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: stat.isPositive
                      ? Colors.green.withAlpha(25)
                      : Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  stat.change,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    fontWeight: FontWeight.bold,
                    color: stat.isPositive ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.title,
                style: TextStyle(
                  fontSize: isMobile ? 11 : 14,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isMobile ? 4 : 8),
              Text(
                stat.value,
                style: TextStyle(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 📈 DONATIONS CHART
  Widget _buildDonationsChart(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
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
          Text(
            'Donations Overview',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Monthly donation trends',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: isMobile ? 20 : 32),
          SizedBox(
            height: isMobile ? 150 : 200,
            child: _buildSimpleBarChart(isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleBarChart(bool isMobile) {
    final List<String> months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
    final List<int> values = [180000, 220000, 190000, 280000, 350000, 450000];
    final int maxValue = values.reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(months.length, (index) {
        final double height =
            (values[index] / maxValue) * (isMobile ? 130 : 180);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (!isMobile || index % 2 == 0)
                  Text(
                    '${(values[index] / 1000).toInt()}k',
                    style: TextStyle(
                      fontSize: isMobile ? 9 : 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  height: height,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF2563EB), Color(0xFF1E3A8A)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  months[index],
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  // 📊 CAMPAIGN PROGRESS
  Widget _buildCampaignProgress(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
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
          Text(
            'Campaign Progress',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          _buildProgressItem('Scholarship Fund', 0.85, Colors.blue, isMobile),
          const SizedBox(height: 16),
          _buildProgressItem('Infrastructure', 0.65, Colors.orange, isMobile),
          const SizedBox(height: 16),
          _buildProgressItem('Research Fund', 0.92, Colors.green, isMobile),
          const SizedBox(height: 16),
          _buildProgressItem('Endowment', 0.45, Colors.purple, isMobile),
        ],
      ),
    );
  }

  Widget _buildProgressItem(
      String title, double progress, Color color, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: isMobile ? 6 : 8,
            backgroundColor: Colors.grey[200],
            color: color,
          ),
        ),
      ],
    );
  }

  // 📋 RECENT ACTIVITY
  Widget _buildRecentActivity(BuildContext context, bool isMobile) {
    final List<_Activity> activities = [
      _Activity(
        icon: Icons.person_add,
        title: 'New donor registered',
        subtitle: 'John Doe joined the platform',
        time: '5 min ago',
        color: Colors.green,
      ),
      _Activity(
        icon: Icons.attach_money,
        title: 'New donation received',
        subtitle: 'KES 50,000 for Scholarship Fund',
        time: '1 hour ago',
        color: Colors.blue,
      ),
      _Activity(
        icon: Icons.campaign,
        title: 'Campaign milestone reached',
        subtitle: 'Infrastructure project reached 50%',
        time: '2 hours ago',
        color: Colors.orange,
      ),
      _Activity(
        icon: Icons.email,
        title: 'Newsletter sent',
        subtitle: 'Monthly update sent to 342 donors',
        time: '5 hours ago',
        color: Colors.purple,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...activities.map((activity) => _buildActivityItem(activity, isMobile)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(_Activity activity, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 10 : 12),
            decoration: BoxDecoration(
              color: activity.color.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(
              activity.icon,
              color: activity.color,
              size: isMobile ? 18 : 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: TextStyle(
                    fontSize: isMobile ? 13 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity.subtitle,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 13,
                    color: Colors.grey[600],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            activity.time,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

// Helper Classes
class _StatCard {
  final String title;
  final String value;
  final String change;
  final bool isPositive;
  final IconData icon;
  final Color color;

  _StatCard({
    required this.title,
    required this.value,
    required this.change,
    required this.isPositive,
    required this.icon,
    required this.color,
  });
}

class _Activity {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Color color;

  _Activity({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.color,
  });
}