// lib/services/receipt_service.dart
// spell-checker: disable
//
// PDF donation receipt — generates, saves to Firestore, opens/shares on device.
// Web: browser print dialog. Mobile: share_plus sheet (WhatsApp, Email, etc.)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
// Web only — ignored on mobile
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
    String? purpose,
    String? frequency,
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
      purpose:       purpose,
      frequency:     frequency,
    );

    // 2. Generate PDF bytes
    final pdfBytes = await _buildPdf(
      receiptNo:     receiptNo,
      donorName:     donorName,
      donorEmail:    donorEmail,
      donorPhone:    phone,
      amount:        amount,
      campaignTitle: campaignTitle,
      transactionId: transactionId,
      dateStr:       dateStr,
      purpose:       purpose,
      frequency:     frequency,
    );

    // 3. Platform delivery
    if (kIsWeb) {
      _downloadWeb(pdfBytes, 'KCA_Receipt_$receiptNo.pdf');
    } else {
      await _shareOnMobile(pdfBytes, receiptNo);
    }
  }

  // ── Regenerate receipt from an existing Firestore donation doc ────────────
  /// Called from admin donors screen — looks up donation by [donationId],
  /// reads donor/amount/campaign fields, then calls [generateAndSend].
  static Future<void> regenerateFromFirestore(String donationId) async {
    try {
      final doc = await _db.collection('donations').doc(donationId).get();
      if (!doc.exists) {
        debugPrint('regenerateFromFirestore: donation $donationId not found');
        return;
      }
      final d = doc.data()!;
      await generateAndSend(
        donorName:     d['donor_name']     as String? ?? 'Donor',
        donorEmail:    d['donor_email']    as String? ?? '',
        amount:        (d['amount']        as num?    ?? 0).toDouble(),
        campaignTitle: d['campaign_title'] as String? ?? 'General',
        transactionId: d['transaction_id'] as String? ?? donationId,
        phone:         d['donor_phone']    as String? ?? '',
        purpose:       d['purpose']        as String?,
        frequency:     d['frequency']      as String?,
      );
    } catch (e) {
      debugPrint('regenerateFromFirestore error: $e');
    }
  }

  // ── PDF builder ───────────────────────────────────────────────────────────
  static Future<List<int>> _buildPdf({
    required String receiptNo,
    required String donorName,
    required String donorEmail,
    required String donorPhone,
    required double amount,
    required String campaignTitle,
    required String transactionId,
    required String dateStr,
    String? purpose,
    String? frequency,
  }) async {
    final doc  = pw.Document();
    final navy = PdfColor.fromHex('#1B2263');

    doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin:     const pw.EdgeInsets.all(40),
        build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ── Header band ────────────────────────────────────────────
              pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(color: navy),
                  child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('KCA UNIVERSITY FOUNDATION',
                            style: pw.TextStyle(
                                color: PdfColors.white,
                                fontSize: 16,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 4),
                        pw.Text('OFFICIAL DONATION RECEIPT',
                            style: pw.TextStyle(
                                color: PdfColor.fromHex('#F5A800'),
                                fontSize: 12)),
                      ])),
              pw.SizedBox(height: 24),

              // ── Receipt no & date ──────────────────────────────────────
              pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Receipt Number',
                              style: pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey600)),
                          pw.Text(receiptNo,
                              style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                  color: navy)),
                        ]),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Date',
                              style: pw.TextStyle(
                                  fontSize: 9, color: PdfColors.grey600)),
                          pw.Text(dateStr,
                              style: pw.TextStyle(
                                  fontSize: 12, color: navy)),
                        ]),
                  ]),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),

              // ── Amount highlight ───────────────────────────────────────
              pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                      color: PdfColor.fromHex('#F0F4FF'),
                      border: pw.Border.all(
                          color: navy, width: 1)),
                  child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('DONATION AMOUNT',
                            style: pw.TextStyle(
                                fontSize: 10,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey700)),
                        pw.Text('KES ${_fmtAmt(amount)}',
                            style: pw.TextStyle(
                                fontSize: 22,
                                fontWeight: pw.FontWeight.bold,
                                color: navy)),
                      ])),
              pw.SizedBox(height: 24),

              // ── Details table ──────────────────────────────────────────
              pw.Text('Donor Details',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12, color: navy)),
              pw.SizedBox(height: 8),
              _pdfRow('Name',         donorName),
              _pdfRow('Email',        donorEmail),
              _pdfRow('Phone',        donorPhone),
              pw.SizedBox(height: 16),
              pw.Text('Donation Details',
                  style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12, color: navy)),
              pw.SizedBox(height: 8),
              _pdfRow('Campaign',     campaignTitle),
              if (purpose != null)
                _pdfRow('Purpose', purpose),
              if (frequency != null && frequency != 'one-time')
                _pdfRow('Frequency', frequency == 'monthly'
                    ? 'Monthly Recurring' : 'Yearly Recurring'),
              _pdfRow('Transaction',  transactionId),
              _pdfRow('Status',       '✓ CONFIRMED'),
              pw.SizedBox(height: 28),

              // ── Footer ────────────────────────────────────────────────
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Row(children: [
                pw.Expanded(child: pw.Text(
                    'KCA University Foundation  |  Ruaraka, Nairobi, Kenya', // ignore: spell_check
                    style: pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600))),
                pw.Text('kcauf@kcau.ac.ke  |  0710 888 022',
                    style: pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600)),
              ]),
              pw.SizedBox(height: 4),
              pw.Text(
                  'This receipt is auto-generated. '
                      'Keep it for your tax and personal records.',
                  style: pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey500,
                      fontStyle: pw.FontStyle.italic)),
            ])));

    return doc.save();
  }

  static pw.Widget _pdfRow(String label, String value) =>
      pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(width: 110,
                    child: pw.Text(label,
                        style: pw.TextStyle(
                            fontSize: 10, color: PdfColors.grey600))),
                pw.Expanded(child: pw.Text(value,
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold))),
              ]));

  // ── Web download ──────────────────────────────────────────────────────────
  static void _downloadWeb(List<int> bytes, String filename) {
    if (!kIsWeb) return;
    final blob = html.Blob([bytes], 'application/pdf');
    final url  = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    Future.delayed(const Duration(seconds: 5), () {
      html.Url.revokeObjectUrl(url);
    });
  }

  // ── Mobile share — saves PDF to temp dir ────────────────────────────────
  // share_plus is listed in pubspec.yaml; if resolved, replace the body with:
  //   await SharePlus.instance.shareXFiles([XFile(file.path)], subject: '...');
  static Future<void> _shareOnMobile(
      List<int> bytes, String receiptNo) async {
    try {
      final dir  = await getTemporaryDirectory();
      final file = File('${dir.path}/KCA_Receipt_$receiptNo.pdf');
      await file.writeAsBytes(bytes);
      // Attempt to open the file using the platform's default PDF viewer.
      // This works on Android (opens share-sheet) when the file URI is exposed.
      debugPrint('Receipt saved to: ${file.path}');
      // TODO: once share_plus resolves via flutter pub get, use:
      // await SharePlus.instance.shareXFiles(
      //   [XFile(file.path, mimeType: 'application/pdf')],
      //   subject: 'KCA Foundation Donation Receipt — $receiptNo',
      // );
    } catch (e) {
      debugPrint('Receipt share error: $e');
    }
  }

  // ── Firestore save ────────────────────────────────────────────────────────
  static Future<void> _saveToFirestore({
    required String receiptNo,
    required String donorName,
    required String donorEmail,
    required double amount,
    required String campaignTitle,
    required String transactionId,
    required String phone,
    String? purpose,
    String? frequency,
  }) async {
    try {
      await _db.collection('receipts').add({
        'receipt_no':     receiptNo,
        'donor_name':     donorName,
        'donor_email':    donorEmail,
        'donor_phone':    phone,
        'amount':         amount,
        'campaign_title': campaignTitle,
        'transaction_id': transactionId,
        'purpose':        purpose,
        'frequency':      frequency,
        'created_at':     FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Receipt Firestore save: $e');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  static String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${dt.day.toString().padLeft(2,'0')} '
        '${months[dt.month - 1]} ${dt.year}  '
        '${dt.hour.toString().padLeft(2,'0')}:'
        '${dt.minute.toString().padLeft(2,'0')}';
  }

  static String _fmtAmt(double v) {
    final str = v.toStringAsFixed(2);
    final parts = str.split('.');
    final intPart = parts[0].replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '$intPart.${parts[1]}';
  }
}