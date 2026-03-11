// lib/utils/export_helper.dart
// ignore_for_file: avoid_web_libraries_in_flutter
// spell-checker: disable

import 'dart:convert';
import 'dart:typed_data';
// ignore: depend_on_referenced_packages
import 'package:universal_html/html.dart' as html;

enum ExportFormat { csv, pdf, xls }

class ExportHelper {
  // ── CSV Export ─────────────────────────────────────────────────────────────
  static void exportCSV({
    required String filename,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(headers.map(_csvEscape).join(','));
    for (final row in rows) {
      buffer.writeln(row.map((c) => _csvEscape(c.toString())).join(','));
    }
    _downloadFile(
      content:  utf8.encode(buffer.toString()),
      filename: '$filename.csv',
      mimeType: 'text/csv;charset=utf-8',
    );
  }

  // ── XLS (HTML table — opens in Excel) ──────────────────────────────────────
  // FIX: Removed unused xmlns:o / xmlns:x namespace attributes (warnings #1 #2 #3)
  // FIX: Added lang="en" to <html> tag (warning: missing 'lang' attribute)
  // FIX: Added <title> element (warning: missing 'title' element)
  static void exportXLS({
    required String filename,
    required String title,
    required List<String> headers,
    required List<List<dynamic>> rows,
  }) {
    final buffer = StringBuffer();
    buffer.write('''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>$title</title>
</head>
<body>
<table border="1" style="border-collapse:collapse;font-family:Arial,sans-serif;">
  <tr style="background:#1B2263;color:white;font-weight:bold;">
''');

    for (final h in headers) {
      buffer.write('<th style="padding:8px 12px;">$h</th>');
    }
    buffer.writeln('</tr>');

    for (int i = 0; i < rows.length; i++) {
      final bg = i.isEven ? '#f5f7fa' : '#ffffff';
      buffer.write('<tr style="background:$bg;">');
      for (final cell in rows[i]) {
        buffer.write('<td style="padding:6px 12px;">${_htmlEscape(cell.toString())}</td>');
      }
      buffer.writeln('</tr>');
    }

    buffer.write('</table></body></html>');

    _downloadFile(
      content:  utf8.encode(buffer.toString()),
      filename: '$filename.xls',
      mimeType: 'application/vnd.ms-excel;charset=utf-8',
    );
  }

  // ── PDF (browser print dialog) ─────────────────────────────────────────────
  // FIX: Renamed html_content → htmlContent (lowerCamelCase warning)
  // FIX: Removed null check on WindowBase — open() never returns null on web
  static void exportPDF({
    required String filename,
    required String title,
    required String subtitle,
    required List<String> headers,
    required List<List<dynamic>> rows,
    required List<int> colWidths,
  }) {
    final colDefs = headers.asMap().entries.map((e) {
      final w = e.key < colWidths.length
          ? colWidths[e.key]
          : 100 ~/ headers.length;
      return '<col style="width:$w%">';
    }).join('\n');

    final headerCells = headers
        .map((h) =>
    '<th style="padding:8px 10px;text-align:left;'
        'background:#1B2263;color:white;font-size:11px;">$h</th>')
        .join('\n');

    final dataRows = rows.asMap().entries.map((entry) {
      final i   = entry.key;
      final row = entry.value;
      final bg  = i.isEven ? '#f5f7fa' : '#ffffff';
      final cells = row
          .map((c) =>
      '<td style="padding:6px 10px;font-size:11px;'
          'border-bottom:1px solid #e5e7eb;">'
          '${_htmlEscape(c.toString())}</td>')
          .join('\n');
      return '<tr style="background:$bg;">$cells</tr>';
    }).join('\n');

    final now     = DateTime.now();
    final dateStr =
        '${now.day}/${now.month}/${now.year} '
        '${now.hour}:${now.minute.toString().padLeft(2, '0')}';

    // FIX: renamed from html_content to htmlContent
    final htmlContent = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>$title</title>
  <style>
    * { margin:0; padding:0; box-sizing:border-box; }
    body { font-family:Arial,sans-serif; font-size:12px; color:#1a1a1a; }
    .header { background:#1B2263; color:white; padding:20px 24px; }
    .header h1 { font-size:18px; font-weight:bold; }
    .header p  { font-size:11px; opacity:0.8; margin-top:4px; }
    .gold-bar  { height:4px; background:#F5A800; }
    .meta      { padding:16px 24px; border-bottom:1px solid #e5e7eb;
                 display:flex; justify-content:space-between; }
    .meta span { font-size:11px; color:#6b7280; }
    table      { width:100%; border-collapse:collapse; margin:16px 0; }
    @media print {
      @page { margin:1cm; }
      .no-print { display:none; }
    }
    .print-btn { background:#1B2263; color:white; border:none;
                 padding:10px 20px; cursor:pointer; border-radius:6px;
                 font-size:13px; margin:16px 24px; }
  </style>
</head>
<body>
  <div class="header">
    <h1>KCA University Foundation</h1>
    <p>$subtitle</p>
  </div>
  <div class="gold-bar"></div>
  <div class="meta">
    <span><strong>Report:</strong> $title</span>
    <span><strong>Generated:</strong> $dateStr</span>
  </div>
  <div style="padding:0 24px;">
    <button class="print-btn no-print" onclick="window.print()">
      Print / Save as PDF
    </button>
    <table>
      <colgroup>$colDefs</colgroup>
      <thead><tr>$headerCells</tr></thead>
      <tbody>$dataRows</tbody>
    </table>
    <p style="font-size:10px;color:#9ca3af;padding:8px 0;text-align:right;">
      KCA University Foundation &bull; Generated $dateStr
      &bull; Total records: ${rows.length}
    </p>
  </div>
  <script>
    setTimeout(function() { window.print(); }, 500);
  </script>
</body>
</html>
''';

    final blob = html.Blob([htmlContent], 'text/html');
    final url  = html.Url.createObjectUrlFromBlob(blob);

    // FIX: removed `if (win == null)` — WindowBase is non-nullable on web,
    // so that condition was always false. We just open and fall back via download.
    html.window.open(url, '_blank');

    // Fallback download in case pop-up is blocked
    _downloadFile(
      content:  utf8.encode(htmlContent),
      filename: '$filename-report.html',
      mimeType: 'text/html',
    );

    Future.delayed(
      const Duration(seconds: 3),
          () => html.Url.revokeObjectUrl(url),
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  // FIX: removed unused 'anchor' variable — chained directly without assignment
  // FIX: removed Uint8ListFromList helper — use Uint8List.fromList() directly
  static void _downloadFile({
    required List<int> content,
    required String filename,
    required String mimeType,
  }) {
    final blob = html.Blob([Uint8List.fromList(content)], mimeType);
    final url  = html.Url.createObjectUrlFromBlob(blob);
    // FIX: no variable assigned — AnchorElement used inline, no unused variable
    (html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click())
        .remove();
    html.Url.revokeObjectUrl(url);
  }

  static String _csvEscape(String value) {
    if (value.contains(',') ||
        value.contains('"') ||
        value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  static String _htmlEscape(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}