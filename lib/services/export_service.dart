// lib/services/export_service.dart
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../providers/spending_provider.dart';
import '../providers/other_spending_provider.dart';

class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  // ---------------------------------------------------------------------------
  //  Helpers
  // ---------------------------------------------------------------------------

  Future<File> _writeTempTextFile(String filename, String contents) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(contents);
    return file;
  }

  Future<File> _writeTempBytesFile(String filename, List<int> bytes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  String _escapeCsv(String value) {
    final needsQuotes =
        value.contains(',') || value.contains('"') || value.contains('\n');
    var v = value.replaceAll('"', '""');
    if (needsQuotes) v = '"$v"';
    return v;
  }

  // ===========================================================================
  // PERSONAL SPENDINGS (MAIN)
  // ===========================================================================

  Future<void> exportPersonalCsvAndShare(
    SpendingProvider provider, {
    String? categoryFilter,
  }) async {
    final dailyTotals = provider.getDailyTotalsForPeriod();
    final List<_PersonalRow> rows = [];
    final Map<String, double> categoryTotals = {};
    double overallTotal = 0;

    for (final entry in dailyTotals) {
      final date = entry.key;
      final entriesForDate = provider.getEntriesForDate(date);
      for (final e in entriesForDate) {
        final cat = (e.category == null || e.category!.trim().isEmpty)
            ? 'Uncategorized'
            : e.category!.trim();

        if (categoryFilter != null && cat != categoryFilter) continue;

        rows.add(
          _PersonalRow(
            date: date,
            item: e.item ?? '',
            category: cat,
            bank: e.bank ?? '',
            qty: e.qty,
            amount: e.amount,
          ),
        );

        overallTotal += e.amount;
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('Personal Spending Report');
    buffer.writeln(
      'Generated: ${DateFormat.yMd().add_Hm().format(DateTime.now())}',
    );
    if (provider.periodStart != null && provider.periodEnd != null) {
      buffer.writeln(
        'Period: ${_dateFmt.format(provider.periodStart!)} → ${_dateFmt.format(provider.periodEnd!)}',
      );
    }
    if (categoryFilter != null) buffer.writeln('Category: $categoryFilter');
    buffer.writeln();

    buffer.writeln(
      [
        'Date',
        'Item',
        'Category',
        'Bank',
        'Qty',
        'Amount',
      ].map(_escapeCsv).join(','),
    );

    for (final r in rows) {
      buffer.writeln(
        [
          _dateFmt.format(r.date),
          r.item,
          r.category,
          r.bank,
          r.qty?.toString() ?? '',
          r.amount.toStringAsFixed(2),
        ].map(_escapeCsv).join(','),
      );
    }

    buffer.writeln();
    buffer.writeln('Totals by category');
    buffer.writeln(['Category', 'Total'].join(','));
    categoryTotals.forEach((cat, total) {
      buffer.writeln([cat, total.toStringAsFixed(2)].join(','));
    });

    buffer.writeln();
    buffer.writeln(
      ['Overall total', overallTotal.toStringAsFixed(2)].join(','),
    );

    final suffix = categoryFilter != null
        ? '_${categoryFilter.replaceAll(' ', '_')}'
        : '';
    final file = await _writeTempTextFile(
      'personal_spendings$suffix.csv',
      buffer.toString(),
    );

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Personal spendings (CSV)');
  }

  Future<void> exportPersonalPdfAndShare(
    SpendingProvider provider, {
    String? categoryFilter,
  }) async {
    final dailyTotals = provider.getDailyTotalsForPeriod();
    final List<_PersonalRow> rows = [];
    final Map<String, double> categoryTotals = {};
    double overallTotal = 0;

    for (final entry in dailyTotals) {
      final date = entry.key;
      final entriesForDate = provider.getEntriesForDate(date);

      for (final e in entriesForDate) {
        final cat = (e.category == null || e.category!.trim().isEmpty)
            ? 'Uncategorized'
            : e.category!.trim();

        if (categoryFilter != null && cat != categoryFilter) continue;

        rows.add(
          _PersonalRow(
            date: date,
            item: e.item ?? '',
            category: cat,
            bank: e.bank ?? '',
            qty: e.qty,
            amount: e.amount,
          ),
        );

        overallTotal += e.amount;
        categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
      }
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Personal Spending Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Generated: ${DateFormat.yMd().add_Hm().format(DateTime.now())}',
          ),
          if (provider.periodStart != null && provider.periodEnd != null)
            pw.Text(
              'Period: ${_dateFmt.format(provider.periodStart!)} → ${_dateFmt.format(provider.periodEnd!)}',
            ),
          if (categoryFilter != null) pw.Text('Category: $categoryFilter'),
          pw.SizedBox(height: 12),
          pw.Text(
            'Totals by category',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          _buildCategoryTable(categoryTotals),
          pw.SizedBox(height: 12),
          pw.Text(
            'Overall total: ${overallTotal.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Detailed entries',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          _buildPersonalRowsTable(rows),
        ],
      ),
    );

    final bytes = await doc.save();
    final suffix = categoryFilter != null
        ? '_${categoryFilter.replaceAll(' ', '_')}'
        : '';
    final file = await _writeTempBytesFile(
      'personal_spendings$suffix.pdf',
      bytes,
    );

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Personal spendings (PDF)');
  }

  pw.Widget _buildCategoryTable(Map<String, double> categoryTotals) {
    final headers = ['Category', 'Total'];
    final data = categoryTotals.entries
        .map((e) => [e.key, e.value.toStringAsFixed(2)])
        .toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      cellAlignment: pw.Alignment.centerLeft,
      headerAlignment: pw.Alignment.centerLeft,
    );
  }

  pw.Widget _buildPersonalRowsTable(List<_PersonalRow> rows) {
    final headers = ['Date', 'Item', 'Category', 'Bank', 'Qty', 'Amount'];

    final data = rows
        .map(
          (r) => [
            _dateFmt.format(r.date),
            r.item,
            r.category,
            r.bank,
            r.qty?.toString() ?? '',
            r.amount.toStringAsFixed(2),
          ],
        )
        .toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    );
  }

  // ===========================================================================
  // OTHER SPENDINGS (deduplicated)
  // ===========================================================================

  Future<void> exportOtherCsvAndShare(
    OtherSpendingProvider provider, {
    String? categoryFilter,
  }) async {
    List<OtherSpendingEntry> entries = provider.uniqueEntries;

    if (categoryFilter != null) {
      entries = entries.where((e) {
        final cat = (e.category == null || e.category!.trim().isEmpty)
            ? 'Uncategorized'
            : e.category!.trim();
        return cat == categoryFilter;
      }).toList();
    }

    final Map<String, double> categoryTotals = {};
    double overallTotal = 0;

    for (final e in entries) {
      final cat = (e.category == null || e.category!.trim().isEmpty)
          ? 'Uncategorized'
          : e.category!.trim();

      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
      overallTotal += e.amount;
    }

    final buffer = StringBuffer();
    buffer.writeln('Other Spendings Report');
    buffer.writeln(
      'Generated: ${DateFormat.yMd().add_Hm().format(DateTime.now())}',
    );
    if (categoryFilter != null) buffer.writeln('Category: $categoryFilter');
    buffer.writeln();

    buffer.writeln(
      [
        'Date',
        'Title',
        'Category',
        'Bank',
        'Qty',
        'Amount',
      ].map(_escapeCsv).join(','),
    );

    for (final e in entries) {
      final cat = (e.category == null || e.category!.trim().isEmpty)
          ? 'Uncategorized'
          : e.category!.trim();

      buffer.writeln(
        [
          _dateFmt.format(e.date),
          e.title ?? '',
          cat,
          e.bank ?? '',
          e.qty?.toString() ?? '',
          e.amount.toStringAsFixed(2),
        ].map(_escapeCsv).join(','),
      );
    }

    buffer.writeln();
    buffer.writeln('Totals by category');
    buffer.writeln(['Category', 'Total'].join(','));
    categoryTotals.forEach((cat, total) {
      buffer.writeln([cat, total.toStringAsFixed(2)].join(','));
    });

    buffer.writeln();
    buffer.writeln(
      ['Overall total', overallTotal.toStringAsFixed(2)].join(','),
    );

    final suffix = categoryFilter != null
        ? '_${categoryFilter.replaceAll(' ', '_')}'
        : '';
    final file = await _writeTempTextFile(
      'other_spendings$suffix.csv',
      buffer.toString(),
    );

    await Share.shareXFiles([XFile(file.path)], text: 'Other spendings (CSV)');
  }

  Future<void> exportOtherPdfAndShare(
    OtherSpendingProvider provider, {
    String? categoryFilter,
  }) async {
    List<OtherSpendingEntry> entries = provider.uniqueEntries;

    if (categoryFilter != null) {
      entries = entries.where((e) {
        final cat = (e.category == null || e.category!.trim().isEmpty)
            ? 'Uncategorized'
            : e.category!.trim();
        return cat == categoryFilter;
      }).toList();
    }

    final Map<String, double> categoryTotals = {};
    double overallTotal = 0;

    for (final e in entries) {
      final cat = (e.category == null || e.category!.trim().isEmpty)
          ? 'Uncategorized'
          : e.category!.trim();

      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
      overallTotal += e.amount;
    }

    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Other Spendings Report',
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Generated: ${DateFormat.yMd().add_Hm().format(DateTime.now())}',
          ),
          if (categoryFilter != null) pw.Text('Category: $categoryFilter'),
          pw.SizedBox(height: 12),
          pw.Text(
            'Totals by category',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          _buildCategoryTable(categoryTotals),
          pw.SizedBox(height: 12),
          pw.Text(
            'Overall total: ${overallTotal.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Detailed entries',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          _buildOtherRowsTable(entries),
        ],
      ),
    );

    final bytes = await doc.save();
    final suffix = categoryFilter != null
        ? '_${categoryFilter.replaceAll(' ', '_')}'
        : '';
    final file = await _writeTempBytesFile('other_spendings$suffix.pdf', bytes);

    await Share.shareXFiles([XFile(file.path)], text: 'Other spendings (PDF)');
  }

  pw.Widget _buildOtherRowsTable(List<OtherSpendingEntry> entries) {
    final headers = ['Date', 'Title', 'Category', 'Bank', 'Qty', 'Amount'];

    final data = entries
        .map(
          (e) => [
            _dateFmt.format(e.date),
            e.title ?? '',
            (e.category == null || e.category!.trim().isEmpty)
                ? 'Uncategorized'
                : e.category!.trim(),
            e.bank ?? '',
            e.qty?.toString() ?? '',
            e.amount.toStringAsFixed(2),
          ],
        )
        .toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
    );
  }
}

// simple internal row model for personal entries
class _PersonalRow {
  final DateTime date;
  final String item;
  final String category;
  final String bank;
  final int? qty;
  final double amount;

  _PersonalRow({
    required this.date,
    required this.item,
    required this.category,
    required this.bank,
    required this.qty,
    required this.amount,
  });
}
