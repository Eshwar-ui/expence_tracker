import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/expence.dart';

enum ExportFormat { csv, pdf }

/// Writes filtered transactions to a temp file and opens the system share
/// sheet. CSV is generated manually (no extra package); PDF uses the `pdf`
/// package with a simple table + summary layout.
class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  static final _dateFmt = DateFormat('yyyy-MM-dd');
  static final _displayDateFmt = DateFormat('dd MMM yyyy');
  static final _amountFmt = NumberFormat('#,##,##0.00', 'en_IN');

  /// Generates an export file for [expenses] and pops the system share sheet.
  ///
  /// [label] is used in the filename and the PDF title (e.g. "Mar 2026",
  /// "All Time"). Pass an empty list to no-op.
  Future<void> exportAndShare({
    required List<Expense> expenses,
    required ExportFormat format,
    required String label,
  }) async {
    if (expenses.isEmpty) return;

    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final slug = label.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_').toLowerCase();
    final ext = format == ExportFormat.csv ? 'csv' : 'pdf';
    final file = File('${dir.path}/expenses_${slug}_$timestamp.$ext');

    if (format == ExportFormat.csv) {
      await file.writeAsString(_buildCsv(expenses));
    } else {
      final bytes = await _buildPdf(expenses: expenses, label: label);
      await file.writeAsBytes(bytes);
    }

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Expenses — $label',
      text: 'Your transactions for $label',
    );
  }

  // ─── CSV ──────────────────────────────────────────────────────────────

  String _buildCsv(List<Expense> expenses) {
    final buf = StringBuffer();
    buf.writeln(
      'Date,Type,Category,Title,Amount,Description,Payment Method,Tags,Location',
    );
    for (final e in expenses) {
      buf
        ..write(_dateFmt.format(e.date))
        ..write(',')
        ..write(e.type.name)
        ..write(',')
        ..write(_csvEscape(e.category))
        ..write(',')
        ..write(_csvEscape(e.title))
        ..write(',')
        ..write(e.amount.toStringAsFixed(2))
        ..write(',')
        ..write(_csvEscape(e.description))
        ..write(',')
        ..write(_csvEscape(e.paymentMethod ?? ''))
        ..write(',')
        ..write(_csvEscape(e.tags ?? ''))
        ..write(',')
        ..writeln(_csvEscape(e.location ?? ''));
    }
    return buf.toString();
  }

  String _csvEscape(String value) {
    if (value.isEmpty) return '';
    final needsQuote =
        value.contains(',') || value.contains('"') || value.contains('\n');
    if (!needsQuote) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  // ─── PDF ──────────────────────────────────────────────────────────────

  Future<List<int>> _buildPdf({
    required List<Expense> expenses,
    required String label,
  }) async {
    // Helvetica (the PDF default) is ASCII-only, so any non-Latin char in
    // titles/categories — ₹, emoji, Hindi, etc. — explodes the build.
    // Load Noto Sans on first run; it ships full Unicode coverage.
    final base = await PdfGoogleFonts.notoSansRegular();
    final bold = await PdfGoogleFonts.notoSansBold();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: base, bold: bold),
    );

    final totalIncome = expenses
        .where((e) => e.type == TransactionType.income)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final totalExpense = expenses
        .where((e) => e.type == TransactionType.expense)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final net = totalIncome - totalExpense;

    final user = FirebaseAuth.instance.currentUser;
    final userName = user?.displayName ?? user?.email ?? '';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (ctx) => _pdfHeader(label, userName),
        footer: (ctx) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => [
          _pdfSummary(
            income: totalIncome,
            expense: totalExpense,
            net: net,
            count: expenses.length,
          ),
          pw.SizedBox(height: 18),
          _pdfTable(expenses),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfHeader(String label, String userName) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Transaction Report',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColor.fromHex('6366F1'),
              ),
            ),
            pw.Text(
              _displayDateFmt.format(DateTime.now()),
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Period: $label${userName.isEmpty ? '' : '  ·  $userName'}',
          style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
        ),
        pw.Divider(color: PdfColors.grey300, thickness: 0.5),
      ],
    );
  }

  pw.Widget _pdfSummary({
    required double income,
    required double expense,
    required double net,
    required int count,
  }) {
    pw.Widget tile(String label, String value, PdfColor color) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('F8FAFC'),
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: const pw.TextStyle(
                    fontSize: 9, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Row(
      children: [
        tile('Income', '₹${_amountFmt.format(income)}',
            PdfColor.fromHex('10B981')),
        pw.SizedBox(width: 8),
        tile('Expense', '₹${_amountFmt.format(expense)}',
            PdfColor.fromHex('EF4444')),
        pw.SizedBox(width: 8),
        tile(
          'Net',
          '${net >= 0 ? '+' : '-'}₹${_amountFmt.format(net.abs())}',
          net >= 0 ? PdfColor.fromHex('10B981') : PdfColor.fromHex('EF4444'),
        ),
        pw.SizedBox(width: 8),
        tile('Transactions', '$count', PdfColor.fromHex('64748B')),
      ],
    );
  }

  pw.Widget _pdfTable(List<Expense> expenses) {
    final headers = ['Date', 'Type', 'Category', 'Title', 'Amount'];
    final rows = expenses.map((e) {
      return [
        _displayDateFmt.format(e.date),
        e.type == TransactionType.income ? 'Income' : 'Expense',
        e.category,
        e.title.length > 32 ? '${e.title.substring(0, 32)}...' : e.title,
        '${e.type == TransactionType.income ? '+' : '-'} ₹${_amountFmt.format(e.amount)}',
      ];
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontSize: 10,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: pw.BoxDecoration(color: PdfColor.fromHex('334155')),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignment: pw.Alignment.centerLeft,
      cellAlignments: {
        4: pw.Alignment.centerRight,
      },
      rowDecoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
        ),
      ),
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.4),
        1: pw.FlexColumnWidth(0.9),
        2: pw.FlexColumnWidth(1.3),
        3: pw.FlexColumnWidth(2.2),
        4: pw.FlexColumnWidth(1.4),
      },
    );
  }
}
