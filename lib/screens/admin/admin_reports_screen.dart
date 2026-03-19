// lib/screens/admin/admin_reports_screen.dart
// spell-checker: disable
// ignore_for_file: avoid_web_libraries_in_flutter

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/routes.dart';
import '../../utils/export_helper.dart';
import 'widgets/admin_layout.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const _navy  = Color(0xFF1B2263);
const _gold  = Color(0xFFF5A800);
const _bg    = Color(0xFFF0F2F8);
const _green = Color(0xFF10B981);
const _amber = Color(0xFFF59E0B);
const _blue  = Color(0xFF2563EB);

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _db = FirebaseFirestore.instance;

  // Raw data
  List<Map<String, dynamic>> _donors     = [];
  List<Map<String, dynamic>> _campaigns  = [];
  List<Map<String, dynamic>> _donations  = [];
  bool   _loading        = true;
  String _period         = 'All Time';
  final  _periods        = ['This Month', 'Last 3 Months', 'This Year', 'All Time'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  // ── Fetch ─────────────────────────────────────────────────────────────────
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _db.collection('donors').get(),
        _db.collection('campaigns').get(),
        _db.collection('donations').orderBy('created_at', descending: true).get(),
      ]);
      _donors    = results[0].docs.map((d) { final m = d.data(); m['id'] = d.id; return m; }).toList();
      _campaigns = results[1].docs.map((d) { final m = d.data(); m['id'] = d.id; return m; }).toList();
      _donations = results[2].docs.map((d) { final m = d.data(); m['id'] = d.id; return m; }).toList();
    } catch (e) { debugPrint('Reports load error: $e'); }
    if (mounted) setState(() => _loading = false);
  }

  // ── Period filter ─────────────────────────────────────────────────────────
  List<Map<String, dynamic>> get _filtered {
    if (_period == 'All Time') return _donations;
    final now = DateTime.now();
    final cut = {
      'This Month':    DateTime(now.year, now.month),
      'Last 3 Months': DateTime(now.year, now.month - 2),
      'This Year':     DateTime(now.year),
    }[_period]!;
    return _donations.where((d) {
      final dt = DateTime.tryParse(d['created_at'] as String? ?? '');
      return dt != null && dt.isAfter(cut);
    }).toList();
  }

  // ── Derived stats ─────────────────────────────────────────────────────────
  double get _totalRaised   => _filtered.fold(0, (s, d) => s + (d['amount'] as num? ?? 0));
  int    get _completed     => _filtered.where((d) => (d['status'] ?? 'completed') == 'completed').length;
  int    get _pending       => _filtered.where((d) => d['status'] == 'pending').length;
  int    get _failed        => _filtered.where((d) => d['status'] == 'failed').length;
  int    get _individualD   => _donors.where((d) => d['donor_type'] == 'individual').length;
  int    get _corporateD    => _donors.where((d) => d['donor_type'] == 'corporate').length;
  int    get _partnerD      => _donors.where((d) => d['donor_type'] == 'partner').length;
  int    get _activeCamp    => _campaigns.where((c) => c['is_active'] == true).length;
  double get _avgDonation   => _filtered.isEmpty ? 0 : _totalRaised / _filtered.length;

  // Monthly raised this calendar month
  double get _monthlyRaised {
    final now = DateTime.now();
    return _donations.where((d) {
      final dt = DateTime.tryParse(d['created_at'] as String? ?? '');
      return dt != null && dt.month == now.month && dt.year == now.year;
    }).fold(0, (s, d) => s + (d['amount'] as num? ?? 0));
  }

  // Top 10 donors by total amount
  List<Map<String, dynamic>> get _topDonors {
    final totals = <String, Map<String, dynamic>>{};
    for (final d in _donations) {
      final id     = d['donor_id'] as String? ?? d['id'] as String? ?? '';
      final name   = d['donor_name'] as String? ?? 'Unknown';
      final amount = (d['amount'] as num? ?? 0).toDouble();
      totals.putIfAbsent(id, () => {'name': name, 'total': 0.0, 'count': 0});
      totals[id]!['total'] = (totals[id]!['total'] as double) + amount;
      totals[id]!['count'] = (totals[id]!['count'] as int) + 1;
    }
    return (totals.values.toList()
      ..sort((a, b) => (b['total'] as double).compareTo(a['total'] as double)))
        .take(10).toList();
  }

  // Monthly trend — last 6 months
  List<Map<String, dynamic>> get _monthlyTrend {
    final now = DateTime.now();
    return List.generate(6, (i) {
      final m     = DateTime(now.year, now.month - (5 - i));
      double amt  = 0; int cnt = 0;
      for (final d in _donations) {
        final dt = DateTime.tryParse(d['created_at'] as String? ?? '');
        if (dt != null && dt.month == m.month && dt.year == m.year) {
          amt += (d['amount'] as num? ?? 0).toDouble(); cnt++;
        }
      }
      return {'month': _mon(m.month), 'total': amt, 'count': cnt};
    });
  }

  String _mon(int m) => ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m.clamp(1,12)];

  /// New donors who joined each month, last 12 months.
  List<Map<String, dynamic>> get _donorGrowth {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final m = DateTime(now.year, now.month - (11 - i));
      int count = 0;
      for (final d in _donors) {
        final raw = d['created_at'];
        DateTime? dt;
        if (raw is String) dt = DateTime.tryParse(raw);
        if (raw is Map)    dt = DateTime.tryParse(raw['_seconds']?.toString() ?? '');
        if (dt != null && dt.month == m.month && dt.year == m.year) count++;
      }
      // cumulative
      return {'month': _mon(m.month), 'new': count};
    });
  }

  // Campaign performance
  List<Map<String, dynamic>> get _campPerf {
    return (_campaigns.map((c) {
      final raised = (c['raised'] as num? ?? 0).toDouble();
      final goal   = (c['goal'] as num? ?? 1).toDouble();
      return {
        'title':     c['title'] ?? 'Unknown',
        'raised':    raised,
        'goal':      goal,
        'progress':  (raised / goal).clamp(0.0, 1.0),
        'is_active': c['is_active'] ?? false,
      };
    }).toList()..sort((a, b) => (b['raised'] as double).compareTo(a['raised'] as double)));
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Reports & Analytics',
      activeRoute: AppRoutes.adminReports,
      actions: [
        // Period picker
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _period,
              style: const TextStyle(fontSize: 13, color: _navy, fontWeight: FontWeight.w600),
              items: _periods.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
              onChanged: (v) { if (v != null) setState(() => _period = v); },
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Export button
        _ExportButton(
          onCSV:  _exportCSV,
          onXLS:  _exportXLS,
          onPDF:  _exportPDF,
        ),
        const SizedBox(width: 8),
        IconButton(icon: const Icon(Icons.refresh, color: _navy), onPressed: _load, tooltip: 'Refresh'),
      ],
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: _navy))
          : Column(children: [
        // Tabs
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            labelColor: _navy,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _gold,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.people_outline, size: 18),    text: 'Donors'),
              Tab(icon: Icon(Icons.payments_outlined, size: 18), text: 'Financial'),
              Tab(icon: Icon(Icons.campaign_outlined, size: 18), text: 'Campaigns'),
              Tab(icon: Icon(Icons.show_chart, size: 18),        text: 'Trends'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [_donorTab(), _financialTab(), _campaignTab(), _trendsTab()],
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 1 — DONORS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _donorTab() {
    final total = _donors.length == 0 ? 1 : _donors.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _grid([
          _Stat('Total Donors',   '${_donors.length}',  Icons.people,      _navy),
          _Stat('Individual',     '$_individualD',       Icons.person,      _blue),
          _Stat('Corporate',      '$_corporateD',        Icons.business,    _amber),
          _Stat('Partners',       '$_partnerD',          Icons.handshake,   _green),
        ]),
        const SizedBox(height: 24),

        // Donor type distribution
        _section('Donor Type Breakdown'),
        const SizedBox(height: 12),
        _card(child: Column(children: [
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(children: [
              if (_individualD > 0) _barSeg('Individual', _individualD / total, _blue),
              if (_corporateD > 0)  _barSeg('Corporate',  _corporateD  / total, _amber),
              if (_partnerD > 0)    _barSeg('Partner',    _partnerD    / total, _green),
            ]),
          ),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _leg('Individual', _blue,  _individualD),
            const SizedBox(width: 20),
            _leg('Corporate',  _amber, _corporateD),
            const SizedBox(width: 20),
            _leg('Partner',    _green, _partnerD),
          ]),
        ])),
        const SizedBox(height: 24),

        // Top donors
        _section('Top Donors by Lifetime Giving'),
        const SizedBox(height: 12),
        _topDonors.isEmpty
            ? _empty(Icons.people_outline, 'No donation data yet')
            : _card(child: Column(children: [
          _thead(['#', 'Donor Name', 'Donations', 'Total Given', 'Share of Total']),
          ..._topDonors.asMap().entries.map((e) {
            final idx  = e.key; final d = e.value;
            final amt  = d['total'] as double;
            final maxA = (_topDonors.first['total'] as double).clamp(1, double.infinity);
            return _trow(idx, [
              Text('${idx + 1}', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              Row(children: [
                CircleAvatar(radius: 15, backgroundColor: _navy,
                    child: Text((d['name'] as String)[0].toUpperCase(),
                        style: const TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.bold))),
                const SizedBox(width: 8),
                Expanded(child: Text(d['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), overflow: TextOverflow.ellipsis)),
              ]),
              Text('${d['count']}', textAlign: TextAlign.center),
              Text('KES ${_f(amt)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Row(children: [
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: amt / maxA, minHeight: 8, color: _navy, backgroundColor: Colors.grey[200]))),
                const SizedBox(width: 6),
                Text('${(amt / maxA * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11)),
              ]),
            ]);
          }),
        ])),
        const SizedBox(height: 24),

        // ── Donor growth chart (last 12 months) ───────────────────────
        _section('New Donors — Last 12 Months'),
        const SizedBox(height: 12),
        _card(child: _DonorGrowthChart(data: _donorGrowth)),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 2 — FINANCIAL
  // ══════════════════════════════════════════════════════════════════════════
  Widget _financialTab() {
    final rate = _filtered.isEmpty ? 0.0 : _completed / _filtered.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _grid([
          _Stat('Total Raised',   'KES ${_f(_totalRaised)}',        Icons.payments,       _green),
          _Stat('This Month',     'KES ${_f(_monthlyRaised)}',       Icons.calendar_today, _blue),
          _Stat('Transactions',   '${_filtered.length}',             Icons.receipt_long,   _navy),
          _Stat('Success Rate',   '${(rate*100).toStringAsFixed(0)}%', Icons.verified,     _amber),
        ]),
        const SizedBox(height: 24),

        LayoutBuilder(builder: (ctx, c) {
          final wide = c.maxWidth > 700;
          final statusCard = _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Transaction Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
            const SizedBox(height: 16),
            _statusBar('Completed', _completed, _filtered.length, _green),
            const SizedBox(height: 10),
            _statusBar('Pending',   _pending,   _filtered.length, _amber),
            const SizedBox(height: 10),
            _statusBar('Failed',    _failed,    _filtered.length, Colors.red),
          ]));
          final analysisCard = _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Giving Analysis', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: _navy)),
            const SizedBox(height: 16),
            _aRow('Average donation',       'KES ${_f(_avgDonation)}'),
            _aRow('Avg/donor this month',   'KES ${_f(_donors.isEmpty ? 0 : _monthlyRaised / _donors.length)}'),
            _aRow('Donations per donor',    _donors.isEmpty ? '—' : (_donations.length / _donors.length).toStringAsFixed(1)),
            _aRow('Active campaigns',       '$_activeCamp'),
            _aRow('Total campaigns',        '${_campaigns.length}'),
          ]));
          return wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: statusCard), const SizedBox(width: 16), Expanded(child: analysisCard)])
              : Column(children: [statusCard, const SizedBox(height: 16), analysisCard]);
        }),
        const SizedBox(height: 24),

        _section('Transaction List — $_period'),
        const SizedBox(height: 12),
        _filtered.isEmpty
            ? _empty(Icons.receipt_long_outlined, 'No transactions in this period')
            : _card(child: Column(children: [
          _thead(['Donor', 'Campaign', 'Amount', 'Method', 'Status', 'Date']),
          ..._filtered.take(25).toList().asMap().entries.map((e) {
            final i = e.key; final d = e.value;
            final status = d['status'] as String? ?? 'completed';
            return _trow(i, [
              Text(d['donor_name'] as String? ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), overflow: TextOverflow.ellipsis),
              Text(d['campaign_title'] as String? ?? '—', style: TextStyle(fontSize: 12, color: Colors.grey[600]), overflow: TextOverflow.ellipsis),
              Text('KES ${_f((d['amount'] as num? ?? 0).toDouble())}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text(d['payment_method'] as String? ?? 'M-Pesa', style: const TextStyle(fontSize: 11)),
              _badge(status),
              Text(_shortDate(d['created_at'] as String? ?? ''), style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            ]);
          }),
          if (_filtered.length > 25)
            Container(
              padding: const EdgeInsets.all(12),
              child: Text('Showing 25 of ${_filtered.length} — use Export for full data',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]), textAlign: TextAlign.center),
            ),
        ])),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 3 — CAMPAIGNS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _campaignTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _grid([
          _Stat('Total Campaigns', '${_campaigns.length}',           Icons.campaign,              _navy),
          _Stat('Active',          '$_activeCamp',                   Icons.play_circle_outline,   _green),
          _Stat('Inactive',        '${_campaigns.length - _activeCamp}', Icons.pause_circle_outline, _amber),
        ], cols: 3),
        const SizedBox(height: 24),

        _section('Campaign Performance'),
        const SizedBox(height: 12),
        _campPerf.isEmpty
            ? _empty(Icons.campaign_outlined, 'No campaigns yet')
            : Column(children: _campPerf.map((c) {
          final raised   = c['raised'] as double;
          final goal     = c['goal'] as double;
          final progress = c['progress'] as double;
          final isActive = c['is_active'] as bool;
          final pctColor = progress >= 1.0 ? _green : progress >= 0.5 ? _blue : _amber;
          return _card(child: Column(children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: _navy.withAlpha(15), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.campaign, color: _navy, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _navy)),
                Text('Goal: KES ${_f(goal)}', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ])),
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: isActive ? _green.withAlpha(25) : Colors.grey.withAlpha(20),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(isActive ? 'Active' : 'Inactive',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isActive ? _green : Colors.grey))),
              const SizedBox(width: 12),
              Text('${(progress * 100).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: pctColor)),
            ]),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Raised: KES ${_f(raised)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              Text('Remaining: KES ${_f((goal - raised).clamp(0, double.infinity))}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ]),
            const SizedBox(height: 8),
            ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(value: progress, minHeight: 12, color: pctColor, backgroundColor: Colors.grey[200])),
          ]));
        }).toList()),
      ]),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TAB 4 — TRENDS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _trendsTab() {
    final trend  = _monthlyTrend;
    final maxAmt = trend.map((m) => m['total'] as double).fold(0.0, (a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _section('Monthly Donation Trend — Last 6 Months'),
        const SizedBox(height: 12),

        // Bar chart
        _card(child: SizedBox(
          height: 220,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: trend.map((m) {
              final amt = m['total'] as double;
              final frac = maxAmt == 0 ? 0.0 : amt / maxAmt;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text('KES ${_f(amt)}',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: _navy), textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Flexible(child: FractionallySizedBox(
                      heightFactor: frac.clamp(0.04, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [_navy.withAlpha(180), _navy],
                                begin: Alignment.bottomCenter, end: Alignment.topCenter),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6))),
                      ),
                    )),
                    const SizedBox(height: 8),
                    Text(m['month'] as String,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                    Text('${m['count']} txn',
                        style: TextStyle(fontSize: 9, color: Colors.grey[400])),
                  ]),
                ),
              );
            }).toList(),
          ),
        )),
        const SizedBox(height: 24),

        _section('Month-by-Month Summary'),
        const SizedBox(height: 12),
        _card(child: Column(children: [
          _thead(['Month', 'Transactions', 'Total Raised', 'vs Previous Month']),
          ...trend.asMap().entries.map((e) {
            final i    = e.key; final m = e.value;
            final curr = m['total'] as double;
            final prev = i > 0 ? (trend[i - 1]['total'] as double) : 0.0;
            final diff = curr - prev;
            return _trow(i, [
              Text(m['month'] as String, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text('${m['count']}', textAlign: TextAlign.center),
              Text('KES ${_f(curr)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              i == 0
                  ? Text('—', style: TextStyle(color: Colors.grey[400]))
                  : Row(children: [
                Icon(diff >= 0 ? Icons.trending_up : Icons.trending_down,
                    size: 16, color: diff >= 0 ? _green : Colors.red),
                const SizedBox(width: 4),
                Text('KES ${_f(diff.abs())}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: diff >= 0 ? _green : Colors.red)),
              ]),
            ]);
          }),
        ])),
        const SizedBox(height: 24),

        // Donor growth tracker
        _section('Donor Engagement Overview'),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (ctx, c) {
          final wide = c.maxWidth > 700;
          final cards = [
            _insightCard(Icons.volunteer_activism, 'Most Active Month',
                trend.reduce((a, b) => (a['total'] as double) > (b['total'] as double) ? a : b)['month'] as String, _blue),
            _insightCard(Icons.people, 'Avg Donations/Month',
                _f(trend.fold(0.0, (s, m) => s + (m['total'] as double)) / 6), _green),
            _insightCard(Icons.stars, 'Top Donor Type',
                _individualD >= _corporateD && _individualD >= _partnerD ? 'Individual'
                    : _corporateD >= _partnerD ? 'Corporate' : 'Partner', _amber),
          ];
          return wide
              ? Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c))).toList())
              : Column(children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 12), child: c)).toList());
        }),
      ]),
    );
  }

  // ── Export handlers ───────────────────────────────────────────────────────
  void _exportCSV() {
    final headers = ['Donor', 'Campaign', 'Amount (KES)', 'Method', 'Status', 'Date'];
    ExportHelper.exportCSV(filename: 'kca_report_$_period', headers: headers, rows: _exportRows());
  }

  void _exportXLS() {
    ExportHelper.exportXLS(filename: 'kca_report_$_period', title: 'KCA Donations — $_period',
        headers: ['Donor', 'Campaign', 'Amount (KES)', 'Method', 'Status', 'Date'], rows: _exportRows());
  }

  void _exportPDF() {
    ExportHelper.exportPDF(
      filename: 'kca_report_$_period',
      title: 'Donations Report — $_period',
      subtitle: 'KCA University Foundation · Total: KES ${_f(_totalRaised)} · ${_filtered.length} transactions',
      headers: ['Donor', 'Campaign', 'Amount (KES)', 'Method', 'Status', 'Date'],
      rows: _exportRows(),
      colWidths: [20, 22, 14, 12, 12, 12],
    );
  }

  List<List<dynamic>> _exportRows() => _filtered.map((d) => [
    d['donor_name'] ?? '—',
    d['campaign_title'] ?? '—',
    (d['amount'] ?? 0).toString(),
    d['payment_method'] ?? 'M-Pesa',
    d['status'] ?? 'completed',
    _shortDate(d['created_at'] as String? ?? ''),
  ]).toList();

  // ── Widget helpers ────────────────────────────────────────────────────────
  Widget _grid(List<_Stat> stats, {int cols = 4}) => GridView.count(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    crossAxisCount: MediaQuery.of(context).size.width > 700 ? cols : 2,
    crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.9,
    children: stats.map((s) => _card(child: Row(children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: s.color.withAlpha(25), borderRadius: BorderRadius.circular(10)),
          child: Icon(s.icon, color: s.color, size: 22)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(s.value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: s.color)),
        Text(s.label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ])),
    ]))).toList(),
  );

  Widget _card({required Widget child}) => Container(
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 8, offset: const Offset(0, 2))]),
    child: child,
  );

  Widget _section(String t) => Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _navy));

  Widget _thead(List<String> cols) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: const BoxDecoration(color: _navy, borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
    child: Row(children: cols.map((c) => Expanded(child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))).toList()),
  );

  Widget _trow(int i, List<Widget> cells) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(
        color: i.isEven ? _bg : Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
    child: Row(children: cells.map((c) => Expanded(child: c)).toList()),
  );

  Widget _barSeg(String label, double frac, Color color) => Expanded(
      flex: (frac * 100).round().clamp(1, 100),
      child: Tooltip(message: '$label: ${(frac * 100).toStringAsFixed(1)}%',
          child: Container(height: 40, color: color, alignment: Alignment.center,
              child: frac > 0.12 ? Text('${(frac * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)) : null)));

  Widget _leg(String label, Color color, int count) => Row(children: [
    Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
    const SizedBox(width: 6),
    Text('$label ($count)', style: const TextStyle(fontSize: 12)),
  ]);

  Widget _statusBar(String label, int count, int total, Color color) {
    final pct = total == 0 ? 0.0 : count / total;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Container(width: 10, height: 10, margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          Text(label, style: const TextStyle(fontSize: 13)),
        ]),
        Text('$count  (${(pct * 100).toStringAsFixed(0)}%)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, minHeight: 8, color: color, backgroundColor: Colors.grey[200])),
    ]);
  }

  Widget _aRow(String l, String v) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        Text(v, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: _navy)),
      ]));

  Widget _badge(String status) {
    final color = status == 'completed' ? _green : status == 'pending' ? _amber : Colors.red;
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(6)),
        child: Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)));
  }

  Widget _insightCard(IconData icon, String label, String value, Color color) => _card(
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withAlpha(25), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 26)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
          Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
        ])),
      ]));

  Widget _empty(IconData icon, String msg) => _card(
      child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Column(children: [
        Icon(icon, size: 40, color: Colors.grey[300]),
        const SizedBox(height: 8),
        Text(msg, style: TextStyle(color: Colors.grey[400])),
      ]))));

  String _f(double v) => v >= 1000000 ? '${(v/1000000).toStringAsFixed(1)}M' : v >= 1000 ? '${(v/1000).toStringAsFixed(1)}K' : v.toStringAsFixed(0);
  String _shortDate(String s) => s.length >= 10 ? s.substring(0, 10) : s;
}

// ── Stat data class ───────────────────────────────────────────────────────────
class _Stat { final String label, value; final IconData icon; final Color color;
const _Stat(this.label, this.value, this.icon, this.color); }

// ── Export button widget ──────────────────────────────────────────────────────
class _ExportButton extends StatelessWidget {
  final VoidCallback onCSV, onXLS, onPDF;
  const _ExportButton({required this.onCSV, required this.onXLS, required this.onPDF});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (v) { if (v == 'csv') onCSV(); if (v == 'xls') onXLS(); if (v == 'pdf') onPDF(); },
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(color: _navy, borderRadius: BorderRadius.circular(10)),
          child: const Row(children: [
            Icon(Icons.download_outlined, color: Colors.white, size: 17),
            SizedBox(width: 6),
            Text('Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ])),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'csv', child: Row(children: [Icon(Icons.table_chart_outlined,       size: 18, color: Color(0xFF10B981)), SizedBox(width: 10), Text('Export CSV')])),
        PopupMenuItem(value: 'xls', child: Row(children: [Icon(Icons.grid_on_outlined,           size: 18, color: Colors.green),     SizedBox(width: 10), Text('Export XLS (Excel)')])),
        PopupMenuItem(value: 'pdf', child: Row(children: [Icon(Icons.picture_as_pdf_outlined,    size: 18, color: Colors.red),       SizedBox(width: 10), Text('Export PDF')])),
      ],
    );
  }
}

// ── Donor Growth Line Chart (pure Flutter — no external chart library) ────────
class _DonorGrowthChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _DonorGrowthChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final counts = data.map((m) => (m['new'] as int).toDouble()).toList();
    final maxVal = counts.fold(0.0, (a, b) => a > b ? a : b);
    final total  = counts.fold(0.0, (a, b) => a + b);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _kpi('${total.toInt()}', 'New Donors (12m)',
            Icons.person_add_outlined, const Color(0xFF1B2263)),
        const SizedBox(width: 16),
        _kpi(
          '${counts.last.toInt()}',
          'This Month',
          Icons.trending_up,
          const Color(0xFF10B981),
        ),
        const SizedBox(width: 16),
        _kpi(
          '${counts.isEmpty ? 0 : (total / 12).toStringAsFixed(1)}',
          'Monthly Avg',
          Icons.bar_chart,
          const Color(0xFFF59E0B),
        ),
      ]),
      const SizedBox(height: 24),

      // Line chart area
      SizedBox(
          height: 180,
          child: CustomPaint(
            painter: _GrowthPainter(
                counts: counts, maxVal: maxVal.clamp(1.0, double.infinity)),
            child: const SizedBox.expand(),
          )),
      const SizedBox(height: 8),

      // X-axis labels
      Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: data.map((m) => Text(m['month'] as String,
              style: TextStyle(
                  fontSize: 9, color: Colors.grey[500]))).toList()),
      const SizedBox(height: 16),

      // Data table
      const Divider(),
      const SizedBox(height: 8),
      const Text('Monthly Breakdown',
          style: TextStyle(fontWeight: FontWeight.bold,
              fontSize: 13, color: Color(0xFF1B2263))),
      const SizedBox(height: 8),
      ...data.asMap().entries.map((e) {
        final i     = e.key;
        final m     = e.value;
        final count = m['new'] as int;
        final frac  = maxVal == 0
            ? 0.0 : count / maxVal;
        return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 36,
                  child: Text(m['month'] as String,
                      style: TextStyle(fontSize: 11,
                          color: Colors.grey[500]))),
              const SizedBox(width: 8),
              Expanded(child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                      value: frac.clamp(0.0, 1.0),
                      minHeight: 10,
                      color: const Color(0xFF1B2263),
                      backgroundColor: Colors.grey[100]))),
              const SizedBox(width: 10),
              SizedBox(width: 24, child: Text('$count',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.bold))),
            ]));
      }),
    ]);
  }

  Widget _kpi(String v, String l, IconData icon, Color color) =>
      Expanded(child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: color.withAlpha(15),
              borderRadius: BorderRadius.circular(10)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(height: 6),
                Text(v, style: TextStyle(
                    color: color, fontSize: 20,
                    fontWeight: FontWeight.bold)),
                Text(l, style: TextStyle(
                    color: Colors.grey[600], fontSize: 10)),
              ])));
}

class _GrowthPainter extends CustomPainter {
  final List<double> counts;
  final double maxVal;
  const _GrowthPainter({required this.counts, required this.maxVal});

  @override
  void paint(Canvas canvas, Size size) {
    if (counts.isEmpty) return;
    const navy = Color(0xFF1B2263);
    const gold = Color(0xFFF5A800);

    final linePaint = Paint()
      ..color  = navy
      ..strokeWidth = 2.5
      ..style  = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
          colors: [navy.withAlpha(60), navy.withAlpha(0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter)
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final n      = counts.length;
    final xStep  = size.width / (n - 1);

    List<Offset> pts = [];
    for (int i = 0; i < n; i++) {
      final x = i * xStep;
      final y = size.height - (counts[i] / maxVal) * size.height;
      pts.add(Offset(x, y));
    }

    // Fill path
    final fillPath = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(pts.last.dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Line
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      // Smooth curve
      final prev = pts[i - 1];
      final curr = pts[i];
      final cpx  = (prev.dx + curr.dx) / 2;
      linePath.cubicTo(cpx, prev.dy, cpx, curr.dy, curr.dx, curr.dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Dots
    final dotPaint = Paint()..color = gold ..style = PaintingStyle.fill;
    final dotBorder = Paint()
      ..color = navy ..style = PaintingStyle.stroke ..strokeWidth = 2;
    for (final p in pts) {
      canvas.drawCircle(p, 4, dotPaint);
      canvas.drawCircle(p, 4, dotBorder);
    }
  }

  @override
  bool shouldRepaint(_GrowthPainter old) => old.counts != counts;
}