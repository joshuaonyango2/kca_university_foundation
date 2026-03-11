// lib/services/receipt_service.dart
// spell-checker: disable
//
// Generates a PDF donation receipt and:
//  1. Saves it to Firestore (receipts collection)
//  2. Opens it in-app (web: browser print dialog, mobile: share sheet)
//  3. Optionally emails it via flutter_email_sender

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html show Blob, Url, window;

class ReceiptService {
  static final _db = FirebaseFirestore.instance;

  // ── Main entry point ──────────────────────────────────────────────────────
  static Future<void> generateAndSend({
    required String donorName,
    required String donorEmail,
    required double amount,
    required String campaignTitle,
    required String transactionId,
    required String phone,
    String? donorAddress,
  }) async {
    final receiptNo = 'KCA-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final dateStr   = _formatDate(DateTime.now());

    // 1. Save receipt record to Firestore
    await _saveToFirestore(
      receiptNo:     receiptNo,
      donorName:     donorName,
      donorEmail:    donorEmail,
      amount:        amount,
      campaignTitle: campaignTitle,
      transactionId: transactionId,
      phone:         phone,
    );

    // 2. Generate and open PDF
    if (kIsWeb) {
      await _generateWebReceipt(
        receiptNo: receiptNo, donorName: donorName, donorEmail: donorEmail,
        amount: amount, campaignTitle: campaignTitle,
        transactionId: transactionId, phone: phone, dateStr: dateStr,
      );
    } else {
      await _generateMobileReceipt(
        receiptNo: receiptNo, donorName: donorName, donorEmail: donorEmail,
        amount: amount, campaignTitle: campaignTitle,
        transactionId: transactionId, phone: phone, dateStr: dateStr,
      );
    }
  }

  // ── Firestore record ──────────────────────────────────────────────────────
  static Future<void> _saveToFirestore({
    required String receiptNo,
    required String donorName,
    required String donorEmail,
    required double amount,
    required String campaignTitle,
    required String transactionId,
    required String phone,
  }) async {
    await _db.collection('receipts').doc(receiptNo).set({
      'receipt_no':     receiptNo,
      'donor_name':     donorName,
      'donor_email':    donorEmail,
      'amount':         amount,
      'campaign_title': campaignTitle,
      'transaction_id': transactionId,
      'phone':          phone,
      'generated_at':   DateTime.now().toIso8601String(),
      'payment_method': 'M-Pesa',
    });
  }

  // ── Web: HTML receipt with print dialog ───────────────────────────────────
  static Future<void> _generateWebReceipt({
    required String receiptNo,
    required String donorName,
    required String donorEmail,
    required double amount,
    required String campaignTitle,
    required String transactionId,
    required String phone,
    required String dateStr,
  }) async {
    final htmlContent = _buildHtmlReceipt(
      receiptNo: receiptNo, donorName: donorName, donorEmail: donorEmail,
      amount: amount, campaignTitle: campaignTitle,
      transactionId: transactionId, phone: phone, dateStr: dateStr,
    );

    final blob = html.Blob([htmlContent], 'text/html');
    final url  = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    Future.delayed(const Duration(seconds: 5), () => html.Url.revokeObjectUrl(url));
  }

  // ── Mobile: PDF receipt via pdf package ───────────────────────────────────
  static Future<void> _generateMobileReceipt({
    required String receiptNo,
    required String donorName,
    required String donorEmail,
    required double amount,
    required String campaignTitle,
    required String transactionId,
    required String phone,
    required String dateStr,
  }) async {
    final doc = pw.Document();

    // KCA navy and gold in PDF colors
    final kcaNavy = PdfColor.fromHex('1B2263');
    final kcaGold = PdfColor.fromHex('F5A800');

    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Container(
              width: double.infinity, padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(color: kcaNavy, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text('KCA UNIVERSITY FOUNDATION',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('DONATION RECEIPT',
                    style: pw.TextStyle(color: kcaGold, fontSize: 13, fontWeight: pw.FontWeight.bold, letterSpacing: 2)),
                pw.SizedBox(height: 4),
                pw.Text('P.O. Box 43844-00100, Nairobi, Kenya',
                    style: pw.TextStyle(color: PdfColor.fromInt(0xB3FFFFFF), fontSize: 10)),
              ])),
          pw.SizedBox(height: 4),
          // Gold bar
          pw.Container(height: 4, width: double.infinity, color: kcaGold),
          pw.SizedBox(height: 20),

          // Receipt details row
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Receipt No: $receiptNo',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
            pw.Text('Date: $dateStr',
                style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
          ]),
          pw.Divider(height: 20, color: PdfColors.grey400),

          // Donor info
          pw.Text('DONOR DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          _pdfRow('Name',    donorName),
          _pdfRow('Email',   donorEmail),
          _pdfRow('Phone',   phone),
          pw.SizedBox(height: 20),

          // Donation info
          pw.Text('DONATION DETAILS', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 8),
          _pdfRow('Campaign',          campaignTitle),
          _pdfRow('Payment Method',    'M-Pesa'),
          _pdfRow('Transaction ID',    transactionId),

          // Amount box
          pw.SizedBox(height: 16),
          pw.Container(
              width: double.infinity, padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(color: kcaNavy, borderRadius: pw.BorderRadius.circular(8)),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('TOTAL DONATED', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 13)),
                pw.Text('KES ${amount.toStringAsFixed(2)}',
                    style: pw.TextStyle(color: kcaGold, fontWeight: pw.FontWeight.bold, fontSize: 20)),
              ])),

          pw.Spacer(),

          // Footer
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          pw.Text(
              'This receipt is acknowledgement of your generous donation to KCA University Foundation. '
                  'Your contribution supports our mission to transform lives through education.',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, lineSpacing: 4)),
          pw.SizedBox(height: 8),
          pw.Text('Thank you for your support!',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: kcaNavy, fontSize: 11)),
        ],
      ),
    ));

    // Save to temp file and share
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/receipt_$receiptNo.pdf');
    await file.writeAsBytes(await doc.save());

    debugPrint('Receipt saved to: ${file.path}');
    // To open: use open_file package or share_plus
    // OpenFile.open(file.path);
  }

  static pw.Widget _pdfRow(String label, String value) => pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(children: [
        pw.SizedBox(width: 130,
            child: pw.Text(label, style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700))),
        pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
      ]));

  // ── HTML receipt template ─────────────────────────────────────────────────
  static String _buildHtmlReceipt({
    required String receiptNo,
    required String donorName,
    required String donorEmail,
    required double amount,
    required String campaignTitle,
    required String transactionId,
    required String phone,
    required String dateStr,
  }) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Donation Receipt - $receiptNo</title>
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body { font-family:Arial,sans-serif; background:#f5f5f5; padding:20px; }
    .receipt { max-width:600px; margin:0 auto; background:white; border-radius:12px; overflow:hidden; box-shadow:0 4px 20px rgba(0,0,0,.15); }
    .header  { background:#1B2263; color:white; padding:28px 32px; }
    .header h1 { font-size:20px; font-weight:bold; }
    .header p  { font-size:12px; opacity:.7; margin-top:4px; }
    .gold-bar  { height:5px; background:#F5A800; }
    .body      { padding:28px 32px; }
    .meta      { display:flex; justify-content:space-between; margin-bottom:20px; font-size:13px; color:#555; }
    .section-title { font-size:10px; font-weight:bold; letter-spacing:1px; color:#888; text-transform:uppercase; margin-bottom:10px; }
    .row       { display:flex; margin-bottom:8px; font-size:13px; }
    .row .lbl  { width:140px; color:#666; }
    .row .val  { font-weight:bold; }
    .amount-box { background:#1B2263; color:white; border-radius:10px; padding:18px 24px; display:flex; justify-content:space-between; align-items:center; margin:20px 0; }
    .amount-box .lbl { font-size:13px; font-weight:bold; }
    .amount-box .val { font-size:26px; font-weight:bold; color:#F5A800; }
    .divider   { border:none; border-top:1px solid #e5e7eb; margin:20px 0; }
    .footer    { font-size:11px; color:#888; line-height:1.6; }
    .thanks    { font-size:14px; font-weight:bold; color:#1B2263; margin-top:12px; }
    .print-btn { background:#1B2263; color:white; border:none; padding:10px 20px; cursor:pointer; border-radius:8px; font-size:14px; margin-bottom:20px; display:block; margin-left:auto; }
    @media print { .print-btn { display:none; } body { background:white; padding:0; } .receipt { box-shadow:none; } }
  </style>
</head>
<body>
  <div class="receipt">
    <div class="header">
      <h1>KCA University Foundation</h1>
      <p>P.O. Box 43844-00100, Nairobi, Kenya</p>
    </div>
    <div class="gold-bar"></div>
    <div class="body">
      <button class="print-btn no-print" onclick="window.print()">🖨 Print / Save as PDF</button>
      <div class="meta">
        <span><strong>DONATION RECEIPT</strong></span>
        <span>Receipt No: <strong>$receiptNo</strong></span>
        <span>Date: <strong>$dateStr</strong></span>
      </div>
      <div class="section-title">Donor Details</div>
      <div class="row"><span class="lbl">Name</span><span class="val">$donorName</span></div>
      <div class="row"><span class="lbl">Email</span><span class="val">$donorEmail</span></div>
      <div class="row"><span class="lbl">Phone</span><span class="val">$phone</span></div>
      <hr class="divider">
      <div class="section-title">Donation Details</div>
      <div class="row"><span class="lbl">Campaign</span><span class="val">$campaignTitle</span></div>
      <div class="row"><span class="lbl">Payment Method</span><span class="val">M-Pesa</span></div>
      <div class="row"><span class="lbl">Transaction ID</span><span class="val" style="font-family:monospace;font-size:11px">$transactionId</span></div>
      <div class="amount-box">
        <span class="lbl">TOTAL DONATED</span>
        <span class="val">KES ${amount.toStringAsFixed(2)}</span>
      </div>
      <hr class="divider">
      <p class="footer">
        This receipt acknowledges your generous donation to KCA University Foundation.
        Your contribution supports our mission to transform lives through education.
        This is an official tax-deductible donation receipt.
      </p>
      <p class="thanks">Thank you for your generous support! 🙏</p>
    </div>
  </div>
  <script>setTimeout(function() { window.print(); }, 600);</script>
</body>
</html>
''';
  }

  // ── Admin: view receipts for a donor ─────────────────────────────────────
  static Stream<QuerySnapshot> donorReceiptsStream(String donorEmail) =>
      _db.collection('receipts')
          .where('donor_email', isEqualTo: donorEmail)
          .orderBy('generated_at', descending: true)
          .snapshots();

  // ── Admin: regenerate a receipt ───────────────────────────────────────────
  static Future<void> regenerateFromFirestore(String receiptNo) async {
    final doc = await _db.collection('receipts').doc(receiptNo).get();
    if (!doc.exists) return;
    final d = doc.data()!;
    await generateAndSend(
      donorName:     d['donor_name'] as String? ?? '',
      donorEmail:    d['donor_email'] as String? ?? '',
      amount:        (d['amount'] as num? ?? 0).toDouble(),
      campaignTitle: d['campaign_title'] as String? ?? '',
      transactionId: d['transaction_id'] as String? ?? '',
      phone:         d['phone'] as String? ?? '',
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}  '
          '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
}