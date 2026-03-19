// lib/screens/help/help_screen.dart
// spell-checker: disable
//
// Help / FAQ screen with KCA University Foundation contact details.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html if (dart.library.io) 'dart:io';

const _navy  = Color(0xFF1B2263);
const _gold  = Color(0xFFF5A800);
const _bg    = Color(0xFFF5F7FA);

class HelpScreen extends StatefulWidget {
const HelpScreen({super.key});
@override
State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
int? _openIndex;

static const _faqs = [
(
q: 'How do I make a donation?',
a: 'Browse the Campaigns tab, tap on a campaign you want to support, '
'then tap the "Donate" button. Choose your payment method (M-Pesa, '
'bank transfer, or card), enter your details and preferred amount, '
'then confirm your donation.',
),
(
q: 'Which payment methods are accepted?',
a: 'We accept M-Pesa STK Push (instant), Equity Bank transfer, '
'KCB Bank transfer, Visa/Mastercard debit and credit cards, '
'and international payments via PayPal or Wise. '
'All methods are available in the donation flow.',
),
(
q: 'How do I get my donation receipt?',
a: 'After a successful donation, a receipt is automatically saved to '
'your Notifications tab under "Receipts". Tap any receipt entry to '
'view your full receipt. A PDF is also generated and can be downloaded '
'from your My Donations screen.',
),
(
q: 'Can I donate anonymously?',
a: 'Yes. During the donation flow, you will find an "Anonymous Donation" '
'option. When enabled, your name will not appear on public campaign '
'displays, though your details are still stored securely for receipt '
'and tax purposes.',
),
(
q: 'What is a recurring donation?',
a: 'A recurring donation lets you give automatically on a monthly or '
'yearly schedule without having to re-enter your details each time. '
'You can set this up in the donation flow using the Frequency toggle. '
'You can cancel anytime from your My Donations screen.',
),
(
q: 'How long does M-Pesa take to process?',
a: 'M-Pesa STK Push donations are processed in real time — usually within '
'10–30 seconds. After you enter your M-Pesa PIN on the prompt sent to '
'your phone, the payment is confirmed immediately and your receipt is '
'generated automatically.',
),
(
q: 'What happens if my payment is pending?',
a: 'Bank transfer and manual payments show as "Pending" until our team '
'verifies the payment. This usually takes 1–2 business days. You will '
'receive an in-app notification once your donation is confirmed.',
),
(
q: 'Can I donate to a specific purpose?',
a: 'Yes. During the donation flow, you can select the purpose of your '
'donation — for example Scholarship Fund, Endowment Fund, '
'Infrastructure, Research & Outreach, or General Fund. '
'This helps us direct your gift exactly where you intend.',
),
(
q: 'Is my personal data secure?',
a: 'Yes. All donor data is stored on Firebase with industry-standard '
'encryption. We do not sell or share your personal information with '
'third parties. Receipts and transaction records are kept securely '
'and accessible only to you and authorised KCA Foundation staff.',
),
(
q: 'How do I update my profile or contact details?',
a: 'Tap the Profile tab at the bottom of the screen. From there you can '
'update your full name, phone number, and donor type. Email changes '
'require re-authentication for security.',
),
(
q: 'What campaigns can I support?',
a: 'The Campaigns tab shows all active fundraising initiatives from '
'KCA University Foundation — including scholarship funds, infrastructure '
'projects, research programmes, and community outreach campaigns. '
'Each campaign shows its goal, progress, and beneficiary stories.',
),
(
q: 'How do I contact support?',
a: 'You can reach us via phone on 0710 888 022 or 0734 888 022, '
'or email us at kcauf@kcau.ac.ke. Our support team is available '
'Monday to Friday, 8 AM – 5 PM EAT.',
),
];

@override
Widget build(BuildContext context) {
return Scaffold(
backgroundColor: _bg,
appBar: AppBar(
backgroundColor: _navy,
foregroundColor: Colors.white,
title: const Text('Help & FAQ',
style: TextStyle(fontWeight: FontWeight.bold)),
centerTitle: true,
bottom: PreferredSize(
preferredSize: const Size.fromHeight(3),
child: Container(height: 3, color: _gold)),
),
body: SingleChildScrollView(
child: Column(children: [
// ── Contact card ───────────────────────────────────────────────
_ContactCard(),

// ── FAQ section ────────────────────────────────────────────────
Padding(
padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
child: Row(children: [
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: _navy.withAlpha(12),
borderRadius: BorderRadius.circular(8)),
child: const Icon(Icons.quiz_outlined,
color: _navy, size: 20)),
const SizedBox(width: 10),
const Text('Frequently Asked Questions',
style: TextStyle(fontWeight: FontWeight.bold,
fontSize: 16, color: _navy)),
])),

ListView.builder(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
padding: const EdgeInsets.symmetric(horizontal: 16),
itemCount: _faqs.length,
itemBuilder: (ctx, i) {
final faq   = _faqs[i];
final isOpen = _openIndex == i;
return Container(
margin: const EdgeInsets.only(bottom: 8),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(12),
border: Border.all(
color: isOpen
? _navy.withAlpha(60)
    : Colors.grey.shade200),
boxShadow: [BoxShadow(
color: Colors.black.withAlpha(5),
blurRadius: 4)]),
child: Column(children: [
ListTile(
contentPadding: const EdgeInsets.symmetric(
horizontal: 16, vertical: 4),
title: Text(faq.q,
style: TextStyle(
fontWeight: FontWeight.w700,
fontSize: 14,
color: isOpen ? _navy : Colors.black87)),
trailing: AnimatedRotation(
duration: const Duration(milliseconds: 200),
turns: isOpen ? 0.5 : 0,
child: Icon(Icons.keyboard_arrow_down,
color: isOpen ? _navy : Colors.grey)),
onTap: () => setState(() =>
_openIndex = isOpen ? null : i),
),
if (isOpen)
Padding(
padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
child: Text(faq.a,
style: TextStyle(
fontSize: 13,
color: Colors.grey[700],
height: 1.6))),
]));
}),

const SizedBox(height: 24),

// ── Still need help? ───────────────────────────────────────────
Padding(
padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
child: Container(
width: double.infinity,
padding: const EdgeInsets.all(20),
decoration: BoxDecoration(
gradient: LinearGradient(
colors: [_navy, _navy.withAlpha(220)],
begin: Alignment.topLeft,
end: Alignment.bottomRight),
borderRadius: BorderRadius.circular(16)),
child: Column(children: [
const Icon(Icons.support_agent,
color: _gold, size: 36),
const SizedBox(height: 10),
const Text('Still need help?',
style: TextStyle(color: Colors.white,
fontWeight: FontWeight.bold, fontSize: 16)),
const SizedBox(height: 6),
Text('Our team is ready to assist you',
style: TextStyle(
color: Colors.white.withAlpha(180),
fontSize: 13)),
const SizedBox(height: 16),
Row(children: [
Expanded(child: _ActionBtn(
icon: Icons.phone, label: 'Call Us',
onTap: () => _launch('tel:+254710888022'))),
const SizedBox(width: 12),
Expanded(child: _ActionBtn(
icon: Icons.email_outlined, label: 'Email Us',
onTap: () => _launch(
'mailto:kcauf@kcau.ac.ke'
'?subject=App%20Support%20Request'))),
]),
])),
),
]),
),
);
}

void _launch(String url) {
final display = url.startsWith('tel:')
? url.replaceFirst('tel:', '')
    : url.startsWith('mailto:')
? url.replaceFirst('mailto:', '').split('?').first
    : url;

if (kIsWeb) {
// Web: open in new tab via dart:html
html.window.open(url, '_blank');
return;
}

// Mobile: copy to clipboard + show snackbar with the contact info.
// For production with url_launcher installed, replace this with:
//   launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
Clipboard.setData(ClipboardData(text: display)).then((_) {
if (mounted) {
ScaffoldMessenger.of(context).showSnackBar(SnackBar(
content: Text(
url.startsWith('tel:')
? 'Phone number copied: $display'
    : 'Email copied: $display',
),
action: SnackBarAction(label: 'OK', onPressed: () {}),
));
}
});
}
}

// ── Contact card ──────────────────────────────────────────────────────────────
class _ContactCard extends StatelessWidget {
@override
Widget build(BuildContext context) {
return Container(
margin: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: Colors.white,
borderRadius: BorderRadius.circular(16),
border: Border.all(color: Colors.grey.shade200),
boxShadow: [BoxShadow(
color: Colors.black.withAlpha(6),
blurRadius: 8, offset: const Offset(0, 2))]),
child: Column(children: [
// Header
Container(
width: double.infinity,
padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
decoration: BoxDecoration(
color: _navy,
borderRadius: const BorderRadius.vertical(
top: Radius.circular(16))),
child: const Row(children: [
Icon(Icons.location_city, color: _gold, size: 22),
SizedBox(width: 10),
Text('KCA University Foundation',
style: TextStyle(color: Colors.white,
fontWeight: FontWeight.bold, fontSize: 16)),
])),
// Contact details
Padding(
padding: const EdgeInsets.all(16),
child: Column(children: [
_contactRow(Icons.phone_outlined, 'Phone',
'0710 888 022  /  0734 888 022',
onTap: () => _copy(context, '0710888022')),
const Divider(height: 16),
_contactRow(Icons.email_outlined, 'Email',
'kcauf@kcau.ac.ke',
onTap: () => _copy(context, 'kcauf@kcau.ac.ke')),
const Divider(height: 16),
_contactRow(Icons.access_time_outlined, 'Hours',
'Mon – Fri, 8:00 AM – 5:00 PM EAT'),
const Divider(height: 16),
_contactRow(Icons.location_on_outlined, 'Address',
'KCA University, Ruaraka, Nairobi, Kenya'), // ignore: spell_check
])),
]));
}

Widget _contactRow(IconData icon, String label, String value,
{VoidCallback? onTap}) =>
GestureDetector(
onTap: onTap,
child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
Container(
padding: const EdgeInsets.all(8),
decoration: BoxDecoration(
color: _navy.withAlpha(12),
borderRadius: BorderRadius.circular(8)),
child: Icon(icon, color: _navy, size: 16)),
const SizedBox(width: 12),
Expanded(child: Column(
crossAxisAlignment: CrossAxisAlignment.start, children: [
Text(label, style: TextStyle(
fontSize: 11, color: Colors.grey[500],
fontWeight: FontWeight.w600)),
const SizedBox(height: 2),
Text(value, style: const TextStyle(
fontSize: 14, color: Colors.black87,
fontWeight: FontWeight.w500)),
])),
if (onTap != null)
const Icon(Icons.copy_outlined, size: 15, color: Colors.grey),
]));

void _copy(BuildContext ctx, String text) {
Clipboard.setData(ClipboardData(text: text));
ScaffoldMessenger.of(ctx).showSnackBar(
SnackBar(content: Text('Copied: $text'),
duration: const Duration(seconds: 2),
behavior: SnackBarBehavior.floating));
}
}

// ── Action button ─────────────────────────────────────────────────────────────
class _ActionBtn extends StatelessWidget {
final IconData icon;
final String label;
final VoidCallback onTap;
const _ActionBtn(
{required this.icon, required this.label, required this.onTap});

@override
Widget build(BuildContext context) => GestureDetector(
onTap: onTap,
child: Container(
padding: const EdgeInsets.symmetric(vertical: 12),
decoration: BoxDecoration(
color: Colors.white.withAlpha(20),
borderRadius: BorderRadius.circular(10),
border: Border.all(color: Colors.white.withAlpha(60))),
child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
Icon(icon, color: _gold, size: 18),
const SizedBox(width: 8),
Text(label, style: const TextStyle(
color: Colors.white,
fontWeight: FontWeight.bold, fontSize: 14)),
])));
}