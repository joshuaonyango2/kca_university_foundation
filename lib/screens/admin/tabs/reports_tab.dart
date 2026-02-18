// lib/screens/admin/tabs/reports_tab.dart
// 📊 REPORTS TAB - MOBILE RESPONSIVE

import 'package:flutter/material.dart';

class AdminReportsTab extends StatefulWidget {
  const AdminReportsTab({super.key});

  @override
  State<AdminReportsTab> createState() => _AdminReportsTabState();
}

class _AdminReportsTabState extends State<AdminReportsTab> {
  String _selectedPeriod = '30days';

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
            // Header
            _buildHeader(isMobile),
            SizedBox(height: isMobile ? 20 : 32),

            // Period Selector
            _buildPeriodSelector(isMobile),
            SizedBox(height: isMobile ? 20 : 32),

            // Summary Cards
            _buildSummaryCards(isMobile),
            SizedBox(height: isMobile ? 20 : 32),

            // Charts Section
            _buildChartsSection(isMobile),
            SizedBox(height: isMobile ? 20 : 32),

            // Quick Reports
            _buildQuickReports(isMobile),
          ],
        ),
      ),
    );
  }

  // 📊 HEADER
  Widget _buildHeader(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports & Analytics',
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Overview of your organization\'s performance',
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        if (!isMobile)
          ElevatedButton.icon(
            onPressed: _generateFullReport,
            icon: const Icon(Icons.download),
            label: const Text('Download Report'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
            ),
          ),
      ],
    );
  }

  // 📅 PERIOD SELECTOR
  Widget _buildPeriodSelector(bool isMobile) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildPeriodChip('7 Days', '7days', isMobile),
          const SizedBox(width: 8),
          _buildPeriodChip('30 Days', '30days', isMobile),
          const SizedBox(width: 8),
          _buildPeriodChip('3 Months', '3months', isMobile),
          const SizedBox(width: 8),
          _buildPeriodChip('Year', 'year', isMobile),
          const SizedBox(width: 8),
          _buildPeriodChip('All Time', 'all', isMobile),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value, bool isMobile) {
    final isSelected = _selectedPeriod == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedPeriod = value);
      },
      selectedColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        fontSize: isMobile ? 13 : 14,
      ),
    );
  }

  // 📊 SUMMARY CARDS
  Widget _buildSummaryCards(bool isMobile) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 2 : 4,
      crossAxisSpacing: isMobile ? 12 : 16,
      mainAxisSpacing: isMobile ? 12 : 16,
      childAspectRatio: isMobile ? 1.3 : 1.5,
      children: [
        _buildSummaryCard(
          'Total Raised',
          'KES 2.45M',
          '+12.5%',
          true,
          Icons.trending_up,
          Colors.green,
          isMobile,
        ),
        _buildSummaryCard(
          'Donations',
          '342',
          '+8',
          true,
          Icons.attach_money,
          Colors.blue,
          isMobile,
        ),
        _buildSummaryCard(
          'Avg Donation',
          'KES 7.2K',
          '+2.1%',
          true,
          Icons.bar_chart,
          Colors.orange,
          isMobile,
        ),
        _buildSummaryCard(
          'Active Campaigns',
          '8',
          '+2',
          true,
          Icons.campaign,
          Colors.purple,
          isMobile,
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title,
      String value,
      String change,
      bool isPositive,
      IconData icon,
      Color color,
      bool isMobile,
      ) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
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
                padding: EdgeInsets.all(isMobile ? 8 : 10),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: isMobile ? 20 : 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPositive
                      ? Colors.green.withAlpha(25)
                      : Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  change,
                  style: TextStyle(
                    fontSize: isMobile ? 10 : 11,
                    fontWeight: FontWeight.bold,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 📈 CHARTS SECTION
  Widget _buildChartsSection(bool isMobile) {
    return Column(
      children: [
        // Donation Trends
        Container(
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
                'Donation Trends',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Monthly donation overview',
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
        ),

        SizedBox(height: isMobile ? 16 : 24),

        // Top Campaigns
        Container(
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
                'Top Performing Campaigns',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isMobile ? 16 : 24),
              _buildCampaignProgress('Scholarship Fund', 0.92, Colors.blue, isMobile),
              const SizedBox(height: 12),
              _buildCampaignProgress('Infrastructure', 0.78, Colors.orange, isMobile),
              const SizedBox(height: 12),
              _buildCampaignProgress('Research Fund', 0.65, Colors.green, isMobile),
              const SizedBox(height: 12),
              _buildCampaignProgress('Endowment', 0.45, Colors.purple, isMobile),
            ],
          ),
        ),
      ],
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
        final double height = (values[index] / maxValue) * (isMobile ? 130 : 180);
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

  Widget _buildCampaignProgress(
      String name,
      double progress,
      Color color,
      bool isMobile,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                fontWeight: FontWeight.w600,
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
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            color: color,
          ),
        ),
      ],
    );
  }

  // 📄 QUICK REPORTS
  Widget _buildQuickReports(bool isMobile) {
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
            'Quick Reports',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isMobile ? 16 : 24),
          _buildReportItem(
            'Donor Activity Report',
            'Complete donor engagement analysis',
            Icons.people,
            isMobile,
          ),
          const Divider(height: 32),
          _buildReportItem(
            'Campaign Performance',
            'Detailed campaign metrics and progress',
            Icons.campaign,
            isMobile,
          ),
          const Divider(height: 32),
          _buildReportItem(
            'Financial Summary',
            'Income, expenses, and balance overview',
            Icons.account_balance,
            isMobile,
          ),
          const Divider(height: 32),
          _buildReportItem(
            'Tax Receipt Report',
            'Generate tax receipts for donors',
            Icons.receipt_long,
            isMobile,
          ),
        ],
      ),
    );
  }

  Widget _buildReportItem(
      String title,
      String description,
      IconData icon,
      bool isMobile,
      ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB).withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF2563EB),
            size: isMobile ? 20 : 24,
          ),
        ),
        SizedBox(width: isMobile ? 12 : 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 13,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _downloadReport(title),
          icon: const Icon(Icons.download_outlined),
          tooltip: 'Download',
        ),
      ],
    );
  }

  // 🔧 ACTIONS
  void _generateFullReport() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Generating full report...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _downloadReport(String reportName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading $reportName...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}