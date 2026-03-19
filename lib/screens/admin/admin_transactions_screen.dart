// lib/screens/admin/admin_transactions_screen.dart
// spell-checker: disable
//
// Full transactions list with:
//   • filter by status / payment method / search
//   • export CSV / PDF (web download)
//   • Refund dialog (marks status = 'refunded', decrements campaign raised)
//   • Manual adjustment dialog (amount override + note)
//   • Add manual donation dialog
//   • Mark pending → completed

import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
// Web-only download helper — uses dart:js_interop + package:web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html if (dart.library.io) 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../../config/routes.dart';
import 'package:provider/provider.dart';
import '../../models/role_model.dart';
import '../../providers/staff_provider.dart';
import 'widgets/admin_layout.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
class _C {
static const navy    = Color(0xFF1B2263);
static const bg      = Color(0xFFF0F2F8);
static const green   = Color(0xFF10B981);
static const warning = Color(0xFFF59E0B);
static const error   = Color(0xFFDC2626);
static const purple  = Color(0xFF7C3AED);
}

// ─────────────────────────────────────────────────────────────────────────────
class AdminTransactionsScreen extends StatefulWidget {
const AdminTransactionsScreen({super.key});
@override
State<AdminTransactionsScreen> createState() =>
_AdminTransactionsScreenState();
}

class _AdminTransactionsScreenState
extends State<AdminTransactionsScreen> {
String _statusFilter = 'all';
String _methodFilter = 'all';
String _search       = '';
bool   _canManage    = false;

@override
void initState() {
super.initState();
WidgetsBinding.instance.addPostFrameCallback((_) {
if (!mounted) return;
final sp = context.read<StaffProvider>();
setState(() {
_canManage = sp.canDo(Permission.manageDonations);
});
});
}

@override
Widget build(BuildContext context) {
// FIX 1: use 'child:' not 'body:' — AdminLayout requires child
// FIX 2: add required activeRoute parameter
return AdminLayout(
title:       'Transactions',
activeRoute: AppRoutes.adminTransactions,
actions: [
// Export menu
PopupMenuButton<String>(
icon: const Icon(Icons.download_outlined, color: Colors.white),
tooltip: 'Export',
onSelected: _handleExport,
itemBuilder: (_) => const [
PopupMenuItem(value: 'csv', child: Row(children: [
Icon(Icons.table_chart_outlined, size: 18, color: _C.green),
SizedBox(width: 10), Text('Export CSV')])),
PopupMenuItem(value: 'pdf', child: Row(children: [
Icon(Icons.picture_as_pdf_outlined, size: 18, color: _C.error),
SizedBox(width: 10), Text('Export PDF')])),
]),
if (_canManage)
IconButton(
icon: const Icon(Icons.add, color: Colors.white),
tooltip: 'Add Manual Donation',
onPressed: () => _showAddDonationDialog(context)),
],
// FIX 1: 'child' not 'body' — wrap in Column inside child
child: Column(children: [
_Filters(
statusFilter: _statusFilter,
methodFilter: _methodFilter,
search:       _search,
onStatus: (v) => setState(() => _statusFilter = v),
onMethod: (v) => setState(() => _methodFilter = v),
onSearch: (v) => setState(() => _search = v),
),
_SummaryStrip(status: _statusFilter, method: _methodFilter),
Expanded(child: _TxList(
statusFilter: _statusFilter,
methodFilter: _methodFilter,
search:       _search,
canManage:    _canManage,
onRefund:     (id, d) => _showRefundDialog(id, d),
onAdjust:     (id, d) => _showAdjustDialog(id, d),
)),
]),
);
}

// ── Export ────────────────────────────────────────────────────────────────
Future<void> _handleExport(String fmt) async {
final snap = await FirebaseFirestore.instance
    .collection('donations')
    .orderBy('created_at', descending: true)
    .limit(1000)
    .get();

final rows = snap.docs.map((d) {
final data = d.data();
final ts   = data['created_at'];
DateTime? dt;
if (ts is Timestamp) dt = ts.toDate();
return [
data['donor_name']     as String? ?? '',
data['campaign_title'] as String? ?? '',
(data['amount'] as num? ?? 0).toString(),
data['payment_method'] as String? ?? '',
data['status']         as String? ?? '',
data['purpose']        as String? ?? '',
data['frequency']      as String? ?? 'one-time',
dt != null ? DateFormat('dd/MM/yyyy HH:mm').format(dt) : '',
];
}).toList();

if (fmt == 'csv') {
_downloadCSV(rows);
} else {
await _exportPDF(rows);
}
}

void _downloadCSV(List<List<String>> rows) {
if (!kIsWeb) return; // export only supported on web
const headers = [
'Donor', 'Campaign', 'Amount (KES)',
'Method', 'Status', 'Purpose', 'Frequency', 'Date',
];
final csv = [headers, ...rows]
    .map((r) => r.map((c) => '"${c.replaceAll('"', '""')}"').join(','))
    .join('\n');
final blob = html.Blob(
[const Utf8Encoder().convert(csv)], 'text/csv');
final url  = html.Url.createObjectUrlFromBlob(blob);
html.window.open(url, '_blank');
Future.delayed(const Duration(seconds: 5),
() => html.Url.revokeObjectUrl(url));
}

Future<void> _exportPDF(List<List<String>> rows) async {
if (!kIsWeb) return; // export only supported on web
final doc  = pw.Document();
final navy = PdfColor.fromHex('#1B2263');

doc.addPage(pw.MultiPage(
pageFormat: PdfPageFormat.a4.landscape,
build:      (_) => [
pw.Text('KCA Foundation — Transactions Export',
style: pw.TextStyle(
fontWeight: pw.FontWeight.bold,
fontSize: 14, color: navy)),
pw.SizedBox(height: 12),
pw.TableHelper.fromTextArray(
headers: [
'Donor', 'Campaign', 'KES',
'Method', 'Status', 'Purpose', 'Date',
],
data: rows.map((r) => r.take(7).toList()).toList(),
headerStyle: pw.TextStyle(
color: PdfColors.white,
fontWeight: pw.FontWeight.bold, fontSize: 8),
headerDecoration: pw.BoxDecoration(color: navy),
cellStyle: const pw.TextStyle(fontSize: 7),
columnWidths: {
0: const pw.FlexColumnWidth(2),
1: const pw.FlexColumnWidth(2),
2: const pw.FlexColumnWidth(1),
3: const pw.FlexColumnWidth(1.5),
4: const pw.FlexColumnWidth(1),
5: const pw.FlexColumnWidth(1.5),
6: const pw.FlexColumnWidth(1.5),
}),
]));

final bytes = await doc.save();
final blob  = html.Blob([bytes], 'application/pdf');
final url   = html.Url.createObjectUrlFromBlob(blob);
html.window.open(url, '_blank');
Future.delayed(const Duration(seconds: 5),
() => html.Url.revokeObjectUrl(url));
}

// ── Refund dialog ─────────────────────────────────────────────────────────
void _showRefundDialog(String docId, Map<String, dynamic> data) {
final amount     = (data['amount'] as num? ?? 0).toDouble();
final campaignId = data['campaign_id']    as String? ?? '';
final campaign   = data['campaign_title'] as String? ?? '';
final donor      = data['donor_name']     as String? ?? '';
final noteCtrl   = TextEditingController();

showDialog(
context: context,
builder: (_) => StatefulBuilder(
builder: (ctx, ss) {
bool processing = false;
return AlertDialog(
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16)),
title: const Row(children: [
Icon(Icons.undo_outlined, color: _C.error),
SizedBox(width: 8),
Text('Issue Refund',
style: TextStyle(color: _C.navy, fontSize: 17)),
]),
content: SizedBox(width: 400, child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_dialogRow('Donor', donor),
_dialogRow('Campaign', campaign),
_dialogRow('Refund Amount',
'KES ${_fmt(amount)}', highlight: true),
const SizedBox(height: 16),
const Text('Refund Note (optional)',
style: TextStyle(
fontSize: 12, color: Colors.grey)),
const SizedBox(height: 6),
TextField(
controller: noteCtrl,
maxLines: 2,
decoration: InputDecoration(
hintText: 'Reason for refund...',
filled: true, fillColor: _C.bg,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(8),
borderSide: BorderSide.none))),
const SizedBox(height: 12),
Container(
padding: const EdgeInsets.all(10),
decoration: BoxDecoration(
color: _C.error.withAlpha(15),
borderRadius: BorderRadius.circular(8)),
child: const Row(children: [
Icon(Icons.warning_amber_outlined,
color: _C.error, size: 16),
SizedBox(width: 8),
Expanded(child: Text(
'This will mark the donation as refunded '
'and reverse the campaign raised amount.',
style: TextStyle(
fontSize: 11, color: _C.error))),
])),
])),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx),
child: const Text('Cancel')),
StatefulBuilder(builder: (ctx2, ss2) =>
ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: _C.error,
foregroundColor: Colors.white),
onPressed: processing ? null : () async {
ss2(() => processing = true);
await _processRefund(
docId:      docId,
campaignId: campaignId,
amount:     amount,
note:       noteCtrl.text.trim());
if (ctx.mounted) Navigator.pop(ctx);
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Refund processed'),
backgroundColor: _C.green));
}
},
child: processing
? const SizedBox(width: 18, height: 18,
child: CircularProgressIndicator(
strokeWidth: 2, color: Colors.white))
    : const Text('Confirm Refund'))),
]);
}));
}

Future<void> _processRefund({
required String docId,
required String campaignId,
required double amount,
required String note,
}) async {
final db    = FirebaseFirestore.instance;
final batch = db.batch();
batch.update(db.collection('donations').doc(docId), {
'status':      'refunded',
'refund_note': note,
'refunded_at': FieldValue.serverTimestamp(),
});
if (campaignId.isNotEmpty) {
batch.update(db.collection('campaigns').doc(campaignId), {
'raised': FieldValue.increment(-amount),
});
}
await batch.commit();
}

// ── Manual adjustment dialog ──────────────────────────────────────────────
void _showAdjustDialog(String docId, Map<String, dynamic> data) {
final currAmt    = (data['amount'] as num? ?? 0).toDouble();
final donor      = data['donor_name']     as String? ?? '';
final campaign   = data['campaign_title'] as String? ?? '';
final campaignId = data['campaign_id']    as String? ?? '';
final amtCtrl    = TextEditingController(
text: currAmt.toStringAsFixed(0));
final noteCtrl   = TextEditingController();

showDialog(
context: context,
builder: (_) => StatefulBuilder(
builder: (ctx, ss) {
bool processing = false;
return AlertDialog(
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16)),
title: const Row(children: [
Icon(Icons.edit_outlined, color: _C.navy),
SizedBox(width: 8),
Text('Manual Adjustment',
style: TextStyle(color: _C.navy, fontSize: 17)),
]),
content: SizedBox(width: 400, child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_dialogRow('Donor',   donor),
_dialogRow('Campaign', campaign),
_dialogRow('Current Amount',
'KES ${_fmt(currAmt)}'),
const SizedBox(height: 16),
const Text('New Amount (KES)',
style: TextStyle(
fontSize: 12, color: Colors.grey)),
const SizedBox(height: 6),
TextField(
controller: amtCtrl,
keyboardType: TextInputType.number,
decoration: InputDecoration(
prefixText: 'KES ',
filled: true, fillColor: _C.bg,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(8),
borderSide: BorderSide.none))),
const SizedBox(height: 12),
const Text('Adjustment Note *',
style: TextStyle(
fontSize: 12, color: Colors.grey)),
const SizedBox(height: 6),
TextField(
controller: noteCtrl,
maxLines: 2,
decoration: InputDecoration(
hintText: 'Reason for adjustment...',
filled: true, fillColor: _C.bg,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(8),
borderSide: BorderSide.none))),
])),
actions: [
TextButton(
onPressed: () => Navigator.pop(ctx),
child: const Text('Cancel')),
StatefulBuilder(builder: (ctx2, ss2) =>
ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: _C.navy,
foregroundColor: Colors.white),
onPressed: processing ? null : () async {
final newAmt = double.tryParse(
amtCtrl.text.replaceAll(',', ''))
?? currAmt;
if (noteCtrl.text.trim().isEmpty) {
ScaffoldMessenger.of(ctx).showSnackBar(
const SnackBar(
content: Text(
'Note is required')));
return;
}
ss2(() => processing = true);
await _processAdjustment(
docId:      docId,
campaignId: campaignId,
oldAmount:  currAmt,
newAmount:  newAmt,
note:       noteCtrl.text.trim(),
);
if (ctx.mounted) Navigator.pop(ctx);
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(
const SnackBar(
content: Text('Adjustment saved'),
backgroundColor: _C.green));
}
},
child: processing
? const SizedBox(width: 18, height: 18,
child: CircularProgressIndicator(
strokeWidth: 2,
color: Colors.white))
    : const Text('Save Adjustment'))),
]);
}));
}

Future<void> _processAdjustment({
required String docId,
required String campaignId,
required double oldAmount,
required double newAmount,
required String note,
}) async {
final db    = FirebaseFirestore.instance;
final batch = db.batch();
final diff  = newAmount - oldAmount;

batch.update(db.collection('donations').doc(docId), {
'amount':          newAmount,
'original_amount': oldAmount,
'adjustment_note': note,
'adjusted_at':     FieldValue.serverTimestamp(),
});
if (campaignId.isNotEmpty && diff != 0) {
batch.update(db.collection('campaigns').doc(campaignId), {
'raised': FieldValue.increment(diff),
});
}
await batch.commit();
}

// ── Add manual donation dialog ────────────────────────────────────────────
void _showAddDonationDialog(BuildContext ctx) {
final nameCtrl     = TextEditingController();
final emailCtrl    = TextEditingController();
final amtCtrl      = TextEditingController();
final campaignCtrl = TextEditingController();
final noteCtrl     = TextEditingController();
String method      = 'Bank Transfer';
String status      = 'completed';

showDialog(
context: ctx,
builder: (_) => StatefulBuilder(
builder: (dlgCtx, ss) {
bool processing = false;
return AlertDialog(
shape: RoundedRectangleBorder(
borderRadius: BorderRadius.circular(16)),
title: const Row(children: [
Icon(Icons.add_circle_outline, color: _C.navy),
SizedBox(width: 8),
Text('Add Manual Donation',
style: TextStyle(
color: _C.navy, fontSize: 17)),
]),
content: SizedBox(
width: 480,
child: SingleChildScrollView(child: Column(
mainAxisSize: MainAxisSize.min,
crossAxisAlignment: CrossAxisAlignment.start,
children: [
_dField('Donor Name', nameCtrl,
Icons.person_outline),
const SizedBox(height: 12),
_dField('Donor Email', emailCtrl,
Icons.email_outlined,
type: TextInputType.emailAddress),
const SizedBox(height: 12),
_dField('Campaign Title', campaignCtrl,
Icons.campaign_outlined),
const SizedBox(height: 12),
_dField('Amount (KES)', amtCtrl,
Icons.attach_money,
type: TextInputType.number),
const SizedBox(height: 12),
// FIX 3: add // ignore for deprecated value
DropdownButtonFormField<String>(
initialValue: method,
decoration: _dDeco('Payment Method',
Icons.payment_outlined),
items: const [
'Bank Transfer', 'M-Pesa Manual',
'Cash', 'Cheque', 'Other',
].map((m) => DropdownMenuItem(
value: m,
child: Text(m))).toList(),
onChanged: (v) {
if (v != null) ss(() => method = v);
}),
const SizedBox(height: 12),
DropdownButtonFormField<String>(
initialValue: status,
decoration: _dDeco('Status',
Icons.info_outline),
items: const ['completed', 'pending']
    .map((s) => DropdownMenuItem(
value: s,
child: Text(
s.toUpperCase()))).toList(),
onChanged: (v) {
if (v != null) ss(() => status = v);
}),
const SizedBox(height: 12),
_dField('Internal Note', noteCtrl,
Icons.note_outlined, maxLines: 2),
]))),
actions: [
TextButton(
onPressed: () => Navigator.pop(dlgCtx),
child: const Text('Cancel')),
StatefulBuilder(builder: (ctx2, ss2) =>
ElevatedButton(
style: ElevatedButton.styleFrom(
backgroundColor: _C.navy,
foregroundColor: Colors.white),
onPressed: processing ? null : () async {
if (nameCtrl.text.trim().isEmpty ||
amtCtrl.text.trim().isEmpty) {
ScaffoldMessenger.of(dlgCtx)
    .showSnackBar(const SnackBar(
content: Text(
'Name and amount are required')));
return;
}
final amt = double.tryParse(
amtCtrl.text.replaceAll(',', ''))
?? 0;
if (amt <= 0) {
ScaffoldMessenger.of(dlgCtx)
    .showSnackBar(const SnackBar(
content: Text(
'Enter a valid amount')));
return;
}
ss2(() => processing = true);
final ref = FirebaseFirestore.instance
    .collection('donations').doc();
await ref.set({
'id':             ref.id,
'donor_id':       '',
'donor_name':     nameCtrl.text.trim(),
'donor_email':    emailCtrl.text.trim(),
'campaign_title': campaignCtrl.text.trim(),
'campaign_id':    '',
'amount':         amt,
'payment_method': method,
'payment_type':   'manual',
'status':         status,
'type':           'manual_admin',
'admin_note':     noteCtrl.text.trim(),
'created_at':     FieldValue.serverTimestamp(),
});
if (dlgCtx.mounted) Navigator.pop(dlgCtx);
if (mounted) {
ScaffoldMessenger.of(context)
    .showSnackBar(const SnackBar(
content: Text('Donation recorded'),
backgroundColor: _C.green));
}
},
child: processing
? const SizedBox(width: 18, height: 18,
child: CircularProgressIndicator(
strokeWidth: 2,
color: Colors.white))
    : const Text('Save Donation'))),
]);
}));
}

// ── Small helpers ─────────────────────────────────────────────────────────
Widget _dField(String hint, TextEditingController c, IconData icon,
{TextInputType? type, int maxLines = 1}) =>
TextField(
controller: c,
keyboardType: type,
maxLines: maxLines,
decoration: _dDeco(hint, icon));

InputDecoration _dDeco(String hint, IconData icon) =>
InputDecoration(
hintText: hint,
prefixIcon: Icon(icon, color: _C.navy, size: 18),
filled: true, fillColor: _C.bg,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(10),
borderSide: BorderSide.none));

Widget _dialogRow(String l, String v, {bool highlight = false}) =>
Padding(
padding: const EdgeInsets.only(bottom: 8),
child: Row(children: [
SizedBox(width: 110, child: Text(l,
style: TextStyle(
fontSize: 12, color: Colors.grey[500]))),
Expanded(child: Text(v, style: TextStyle(
fontSize: highlight ? 15 : 13,
fontWeight: highlight
? FontWeight.bold : FontWeight.w500,
color: _C.navy))),
]));

String _fmt(double v) => v >= 1000
? '${(v / 1000).toStringAsFixed(0)}K'
    : v.toStringAsFixed(0);
}

// ── Filters ───────────────────────────────────────────────────────────────────
class _Filters extends StatelessWidget {
final String statusFilter, methodFilter, search;
final ValueChanged<String> onStatus, onMethod, onSearch;
const _Filters({
required this.statusFilter, required this.methodFilter,
required this.search,
required this.onStatus, required this.onMethod,
required this.onSearch,
});

@override
Widget build(BuildContext context) => Container(
color: Colors.white,
padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
child: Column(children: [
TextField(
onChanged: onSearch,
decoration: InputDecoration(
hintText: 'Search donor, campaign...',
prefixIcon: const Icon(Icons.search,
color: _C.navy, size: 20),
filled: true, fillColor: _C.bg,
border: OutlineInputBorder(
borderRadius: BorderRadius.circular(10),
borderSide: BorderSide.none),
contentPadding: const EdgeInsets.symmetric(
horizontal: 14, vertical: 10))),
const SizedBox(height: 10),
SingleChildScrollView(
scrollDirection: Axis.horizontal,
child: Row(children: [
const Text('Status:',
style: TextStyle(fontSize: 12,
color: Colors.grey,
fontWeight: FontWeight.w600)),
const SizedBox(width: 8),
for (final s in [
'all', 'completed', 'pending', 'failed', 'refunded'
])
_Chip(
label: s == 'all' ? 'All' : _cap(s),
active: statusFilter == s,
onTap: () => onStatus(s)),
const SizedBox(width: 16),
const Text('Method:',
style: TextStyle(fontSize: 12,
color: Colors.grey,
fontWeight: FontWeight.w600)),
const SizedBox(width: 8),
for (final m in ['all', 'M-Pesa', 'Bank', 'Card'])
_Chip(
label: m == 'all' ? 'All' : m,
active: methodFilter == m,
onTap: () => onMethod(m)),
])),
]));

static String _cap(String s) =>
s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _Chip extends StatelessWidget {
final String label;
final bool active;
final VoidCallback onTap;
const _Chip({required this.label, required this.active,
required this.onTap});

@override
Widget build(BuildContext context) => GestureDetector(
onTap: onTap,
child: Container(
margin: const EdgeInsets.only(right: 8),
padding: const EdgeInsets.symmetric(
horizontal: 12, vertical: 4),
decoration: BoxDecoration(
color: active ? _C.navy : Colors.grey.shade100,
borderRadius: BorderRadius.circular(20),
border: Border.all(
color: active ? _C.navy : Colors.grey.shade300)),
child: Text(label,
style: TextStyle(
color: active ? Colors.white : Colors.grey[700],
fontSize: 12,
fontWeight: active
? FontWeight.bold : FontWeight.normal))));
}

// ── Summary strip ─────────────────────────────────────────────────────────────
class _SummaryStrip extends StatelessWidget {
final String status, method;
const _SummaryStrip({required this.status, required this.method});

@override
Widget build(BuildContext context) =>
StreamBuilder<QuerySnapshot>(
stream: FirebaseFirestore.instance
    .collection('donations').snapshots(),
builder: (ctx, snap) {
final docs = snap.data?.docs ?? [];
double total = 0;
int completed = 0, pending = 0, refunded = 0;
for (final d in docs) {
final data = d.data() as Map<String, dynamic>;
final s    = data['status'] as String? ?? '';
final amt  = (data['amount'] as num? ?? 0).toDouble();
if (s == 'completed') { total += amt; completed++; }
if (s == 'pending')   pending++;
if (s == 'refunded')  refunded++;
}
return Container(
color: _C.navy,
padding: const EdgeInsets.symmetric(
horizontal: 24, vertical: 12),
child: Row(children: [
_stat(_f(total), 'Total Raised'),
_div(),
_stat('$completed', 'Completed'),
_div(),
_stat('$pending', 'Pending'),
_div(),
_stat('$refunded', 'Refunded'),
_div(),
_stat('${docs.length}', 'All Txn'),
]));
});

Widget _stat(String v, String l) => Expanded(child: Column(
mainAxisSize: MainAxisSize.min, children: [
Text(v, style: const TextStyle(
color: Colors.white, fontWeight: FontWeight.bold,
fontSize: 16)),
Text(l, style: TextStyle(
color: Colors.white.withAlpha(180), fontSize: 10)),
]));

Widget _div() => Container(
width: 1, height: 32,
color: Colors.white.withAlpha(40),
margin: const EdgeInsets.symmetric(horizontal: 4));

String _f(double v) => v >= 1000000
? 'KES ${(v / 1000000).toStringAsFixed(1)}M'
    : v >= 1000
? 'KES ${(v / 1000).toStringAsFixed(0)}K'
    : 'KES ${v.toStringAsFixed(0)}';
}

// ── Transaction list ──────────────────────────────────────────────────────────
class _TxList extends StatelessWidget {
final String statusFilter, methodFilter, search;
final bool   canManage;
final void Function(String, Map<String, dynamic>) onRefund;
final void Function(String, Map<String, dynamic>) onAdjust;

const _TxList({
required this.statusFilter, required this.methodFilter,
required this.search,       required this.canManage,
required this.onRefund,     required this.onAdjust,
});

@override
Widget build(BuildContext context) {
// FIX 4: base query — avoid re-declaring q inside the if block
// which caused a type mismatch (Query vs CollectionReference)
Query<Map<String, dynamic>> q;

if (statusFilter != 'all') {
q = FirebaseFirestore.instance
    .collection('donations')
    .where('status', isEqualTo: statusFilter)
    .orderBy('created_at', descending: true)
    .limit(200);
} else {
q = FirebaseFirestore.instance
    .collection('donations')
    .orderBy('created_at', descending: true)
    .limit(200);
}

return StreamBuilder<QuerySnapshot>(
stream: q.snapshots(),
builder: (ctx, snap) {
if (snap.connectionState == ConnectionState.waiting) {
return const Center(
child: CircularProgressIndicator(color: _C.navy));
}

var docs = snap.data?.docs ?? [];

// Client-side method filter
if (methodFilter != 'all') {
docs = docs.where((d) {
final m = ((d.data() as Map)['payment_method']
as String? ?? '').toLowerCase();
return m.contains(methodFilter.toLowerCase());
}).toList();
}

// Client-side search
if (search.isNotEmpty) {
final sq = search.toLowerCase();
docs = docs.where((d) {
final data = d.data() as Map<String, dynamic>;
return (data['donor_name']     as String? ?? '')
    .toLowerCase().contains(sq) ||
(data['campaign_title'] as String? ?? '')
    .toLowerCase().contains(sq) ||
(data['donor_email']    as String? ?? '')
    .toLowerCase().contains(sq);
}).toList();
}

if (docs.isEmpty) {
return Center(child: Column(
mainAxisAlignment: MainAxisAlignment.center,
children: [
Icon(Icons.receipt_long_outlined,
size: 64, color: Colors.grey[300]),
const SizedBox(height: 12),
const Text('No transactions found',
style: TextStyle(
color: _C.navy,
fontWeight: FontWeight.bold)),
]));
}

return ListView.builder(
padding: const EdgeInsets.all(16),
itemCount: docs.length,
itemBuilder: (ctx, i) {
final d  = docs[i].data() as Map<String, dynamic>;
final id = docs[i].id;
return _TxCard(
id: id, data: d,
canManage: canManage,
onRefund:  () => onRefund(id, d),
onAdjust:  () => onAdjust(id, d),
);
});
});
}
}

// ── Transaction card ──────────────────────────────────────────────────────────
class _TxCard extends StatelessWidget {
final String id;
final Map<String, dynamic> data;
final bool canManage;
final VoidCallback onRefund, onAdjust;

const _TxCard({
required this.id,         required this.data,
required this.canManage,  required this.onRefund,
required this.onAdjust,
});

@override
Widget build(BuildContext context) {
final status   = data['status']         as String? ?? 'pending';
final amount   = (data['amount'] as num? ?? 0).toDouble();
final donor    = data['donor_name']     as String? ?? '—';
final campaign = data['campaign_title'] as String? ?? '—';
final method   = data['payment_method'] as String? ?? '—';
final purpose  = data['purpose']        as String?;
final freq     = data['frequency']      as String?;
final ts       = data['created_at'];
DateTime? dt;
if (ts is Timestamp) dt = ts.toDate();

final (color, bg) = _statusStyle(status);

return Container(
margin: const EdgeInsets.only(bottom: 10),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(12),
border: Border.all(color: Colors.grey.shade200),
boxShadow: [BoxShadow(
color: Colors.black.withAlpha(5),
blurRadius: 4)]),
child: Column(children: [
Padding(
padding: const EdgeInsets.all(14),
child: Row(children: [
Expanded(child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Text(donor, style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 14, color: _C.navy)),
const SizedBox(height: 3),
Text(campaign, style: TextStyle(
fontSize: 12, color: Colors.grey[600])),
const SizedBox(height: 3),
Row(children: [
Text(method, style: TextStyle(
fontSize: 11, color: Colors.grey[400])),
if (purpose != null) ...[
Text(' · ', style: TextStyle(
color: Colors.grey[300])),
Text(purpose, style: TextStyle(
fontSize: 11, color: Colors.grey[400])),
],
if (freq != null && freq != 'one-time') ...[
Text(' · ', style: TextStyle(
color: Colors.grey[300])),
const Icon(Icons.repeat,
size: 11, color: _C.navy),
const SizedBox(width: 2),
Text(freq, style: const TextStyle(
fontSize: 10, color: _C.navy,
fontWeight: FontWeight.w600)),
],
]),
])),
Column(crossAxisAlignment: CrossAxisAlignment.end,
children: [
Text('KES ${_f(amount)}',
style: const TextStyle(
fontWeight: FontWeight.bold,
fontSize: 16, color: _C.navy)),
const SizedBox(height: 6),
Container(
padding: const EdgeInsets.symmetric(
horizontal: 8, vertical: 3),
decoration: BoxDecoration(
color: bg,
borderRadius: BorderRadius.circular(10)),
child: Text(_statusLabel(status),
style: TextStyle(
color: color, fontSize: 10,
fontWeight: FontWeight.w700))),
if (dt != null) ...[
const SizedBox(height: 4),
Text(DateFormat('dd MMM yy').format(dt),
style: TextStyle(
fontSize: 10,
color: Colors.grey[400])),
],
]),
])),

// Action bar — admin only, non-refunded
if (canManage && status != 'refunded')
Container(
decoration: BoxDecoration(
border: Border(top: BorderSide(
color: Colors.grey.shade100))),
child: Row(children: [
if (status == 'completed')
Expanded(child: TextButton.icon(
onPressed: onRefund,
style: TextButton.styleFrom(
foregroundColor: _C.error),
icon: const Icon(
Icons.undo_outlined, size: 15),
label: const Text('Refund',
style: TextStyle(fontSize: 12)))),
Expanded(child: TextButton.icon(
onPressed: onAdjust,
style: TextButton.styleFrom(
foregroundColor: _C.navy),
icon: const Icon(
Icons.edit_outlined, size: 15),
label: const Text('Adjust',
style: TextStyle(fontSize: 12)))),
if (status == 'pending')
Expanded(child: TextButton.icon(
onPressed: _markCompleted,
style: TextButton.styleFrom(
foregroundColor: _C.green),
icon: const Icon(
Icons.check_circle_outline, size: 15),
label: const Text('Mark Done',
style: TextStyle(fontSize: 12)))),
])),
]));
}

Future<void> _markCompleted() async {
await FirebaseFirestore.instance
    .collection('donations')
    .doc(id)
    .update({'status': 'completed'});
}

(Color, Color) _statusStyle(String s) => switch (s) {
'completed' => (_C.green,   _C.green.withAlpha(20)),
'pending'   => (_C.warning, _C.warning.withAlpha(25)),
'failed'    => (_C.error,   _C.error.withAlpha(20)),
'refunded'  => (_C.purple,  _C.purple.withAlpha(20)),
_           => (Colors.grey, Colors.grey.withAlpha(20)),
};

String _statusLabel(String s) => switch (s) {
'completed' => '✓ COMPLETED',
'pending'   => '⏳ PENDING',
'failed'    => '✗ FAILED',
'refunded'  => '↩ REFUNDED',
_           => s.toUpperCase(),
};

String _f(double v) => v >= 1000
? '${(v / 1000).toStringAsFixed(0)}K'
    : v.toStringAsFixed(0);
}