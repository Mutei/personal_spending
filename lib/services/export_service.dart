import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../providers/other_spending_provider.dart';
import '../providers/spending_provider.dart';

class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  Future<_PdfFonts>? _fontsFuture;

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

  Future<_PdfFonts> _loadFonts() {
    return _fontsFuture ??= () async {
      final data = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      final font = pw.Font.ttf(data);
      return _PdfFonts(base: font);
    }();
  }

  bool _containsArabic(String text) {
    return RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF]').hasMatch(text);
  }

  String _sanitizeFilenamePart(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '');
    return sanitized.isEmpty ? 'report' : sanitized;
  }

  String _formatAmount(double amount) {
    final formatted = NumberFormat('#,##0.00').format(amount);
    return '$formatted SAR';
  }

  bool _matchesCategoryFilter(
    String category,
    List<String>? selectedCategories,
  ) {
    if (selectedCategories == null || selectedCategories.isEmpty) return true;
    return selectedCategories.contains(category);
  }

  String _categorySelectionLabel(List<String>? selectedCategories) {
    if (selectedCategories == null || selectedCategories.isEmpty) {
      return 'All categories';
    }
    if (selectedCategories.length == 1) return selectedCategories.first;
    return '${selectedCategories.length} selected';
  }

  String _categoryFilenameSuffix(List<String>? selectedCategories) {
    if (selectedCategories == null || selectedCategories.isEmpty) return '';
    if (selectedCategories.length == 1) {
      return '_${_sanitizeFilenamePart(selectedCategories.first)}';
    }
    return '_${selectedCategories.length}_categories';
  }

  pw.TextDirection _directionFor(String text) {
    return _containsArabic(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  }

  pw.TextAlign _textAlignFor(String text) {
    return _containsArabic(text) ? pw.TextAlign.right : pw.TextAlign.left;
  }

  pw.Widget _text(
    String text, {
    pw.TextStyle? style,
    pw.TextAlign? align,
    int? maxLines,
  }) {
    final direction = _directionFor(text);
    return pw.Directionality(
      textDirection: direction,
      child: pw.Text(
        text,
        maxLines: maxLines,
        style: style,
        textAlign: align ?? _textAlignFor(text),
      ),
    );
  }

  Future<void> _shareFile(File file, {required String text}) async {
    await Share.shareXFiles([XFile(file.path)], text: text);
  }

  Future<void> shareGeneratedFile(File file, {required String text}) async {
    await _shareFile(file, text: text);
  }

  pw.Widget _buildHeroHeader({
    required String reportTitle,
    required String reportType,
    required String generatedAt,
    required String totalSpent,
    List<String>? selectedCategories,
    String? period,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(24),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#0F766E'),
        borderRadius: pw.BorderRadius.circular(18),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(999),
            ),
            child: _text(
              reportType,
              style: const pw.TextStyle(
                color: PdfColor.fromInt(0xFF0F766E),
                fontSize: 11,
              ),
            ),
          ),
          pw.SizedBox(height: 14),
          _text(
            reportTitle,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildMetaPill('Generated', generatedAt),
              _buildMetaPill(
                'Categories',
                _categorySelectionLabel(selectedCategories),
              ),
              if (period != null && period.isNotEmpty)
                _buildMetaPill('Period', period),
            ],
          ),
          pw.SizedBox(height: 18),
          _buildTotalSpentBanner(totalSpent),
        ],
      ),
    );
  }

  pw.Widget _buildTotalSpentBanner(String totalSpent) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0x26FFFFFF),
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: PdfColor.fromInt(0x40FFFFFF), width: 0.8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _text(
                  'Total Spent',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 11,
                  ),
                ),
                pw.SizedBox(height: 4),
                _text(
                  totalSpent,
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0x1AFFFFFF),
              borderRadius: pw.BorderRadius.circular(999),
            ),
            child: _text(
              'SAR',
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSelectedCategoriesSection(List<String> categories) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          'Selected categories',
          subtitle: 'Only transactions from these categories are included.',
        ),
        pw.SizedBox(height: 10),
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories
              .map((category) => _buildCategoryTag(category))
              .toList(),
        ),
      ],
    );
  }

  pw.Widget _buildCategoryTag(String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#E6F4F1'),
        borderRadius: pw.BorderRadius.circular(999),
        border: pw.Border.all(color: PdfColor.fromHex('#B6DCD5')),
      ),
      child: _text(
        value,
        style: pw.TextStyle(
          fontSize: 10,
          color: PdfColor.fromHex('#0F4F4A'),
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  pw.Widget _buildMetaPill(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0x1FFFFFFF),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          _text(
            label,
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
          ),
          pw.SizedBox(height: 2),
          _text(
            value,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSummarySection(
    List<_SummaryMetric> metrics, {
    String title = 'Summary',
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _text(
          title,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 10),
        pw.Wrap(
          spacing: 12,
          runSpacing: 12,
          children: metrics.map(_buildMetricCard).toList(),
        ),
      ],
    );
  }

  pw.Widget _buildMetricCard(_SummaryMetric metric) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#F3F7F7'),
        border: pw.Border.all(color: PdfColor.fromHex('#D4E4E4')),
        borderRadius: pw.BorderRadius.circular(12),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _text(
            metric.label,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromHex('#5C7272'),
            ),
          ),
          pw.SizedBox(height: 8),
          _text(
            metric.value,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title, {String? subtitle}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _text(
          title,
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        if (subtitle != null) ...[
          pw.SizedBox(height: 4),
          _text(
            subtitle,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColor.fromHex('#657373'),
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildSimpleTable({
    required List<String> headers,
    required List<List<String>> rows,
    List<double>? columnFlex,
  }) {
    final effectiveFlex =
        columnFlex ?? List<double>.filled(headers.length, 1, growable: false);
    final widths = <int, pw.TableColumnWidth>{};
    for (var i = 0; i < effectiveFlex.length; i++) {
      widths[i] = pw.FlexColumnWidth(effectiveFlex[i]);
    }

    pw.Widget buildCell(String value, {required bool header}) {
      final textColor = header ? PdfColors.white : PdfColor.fromHex('#1E293B');
      final background = header ? PdfColor.fromHex('#0F766E') : PdfColors.white;
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        color: background,
        child: _text(
          value,
          style: pw.TextStyle(
            fontSize: header ? 10 : 9.5,
            color: textColor,
            fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
      );
    }

    final tableRows = <pw.TableRow>[
      pw.TableRow(
        children: headers
            .map((header) => buildCell(header, header: true))
            .toList(),
      ),
    ];

    for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: rowIndex.isEven
                ? PdfColors.white
                : PdfColor.fromHex('#F8FBFB'),
          ),
          children: row.map((cell) => buildCell(cell, header: false)).toList(),
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(
        color: PdfColor.fromHex('#D7E3E3'),
        width: 0.6,
      ),
      columnWidths: widths,
      children: tableRows,
    );
  }

  Future<List<int>> _buildReportPdf({
    required String reportTitle,
    required String reportType,
    required String totalSpent,
    required List<_SummaryMetric> metrics,
    required List<String> detailHeaders,
    required List<List<String>> detailRows,
    required List<double> detailFlex,
    List<List<String>>? secondaryTableRows,
    List<String>? secondaryHeaders,
    List<double>? secondaryFlex,
    List<String>? selectedCategories,
    String? period,
  }) async {
    final fonts = await _loadFonts();
    final generatedAt = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: fonts.base,
          bold: fonts.base,
          italic: fonts.base,
          boldItalic: fonts.base,
        ),
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 32),
        header: (context) {
          if (context.pageNumber == 1) return pw.SizedBox.shrink();
          return pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 16),
            padding: const pw.EdgeInsets.only(bottom: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _text(
                  reportTitle,
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                _text(
                  'Page ${context.pageNumber}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromHex('#657373'),
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _text(
                  generatedAt,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromHex('#657373'),
                  ),
                ),
                _text(
                  '${context.pageNumber} / ${context.pagesCount}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromHex('#657373'),
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) => [
          _buildHeroHeader(
            reportTitle: reportTitle,
            reportType: reportType,
            generatedAt: generatedAt,
            totalSpent: totalSpent,
            selectedCategories: selectedCategories,
            period: period,
          ),
          pw.SizedBox(height: 20),
          _buildSummarySection(metrics),
          if (selectedCategories != null && selectedCategories.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            _buildSelectedCategoriesSection(selectedCategories),
          ],
          if (secondaryHeaders != null &&
              secondaryTableRows != null &&
              secondaryTableRows.isNotEmpty) ...[
            pw.SizedBox(height: 22),
            _buildSectionTitle(
              'Spending by category',
              subtitle: 'Summary totals grouped by category.',
            ),
            pw.SizedBox(height: 10),
            _buildSimpleTable(
              headers: secondaryHeaders,
              rows: secondaryTableRows,
              columnFlex: secondaryFlex,
            ),
          ],
          pw.SizedBox(height: 22),
          _buildSectionTitle(
            'Transaction details',
            subtitle: 'Detailed records included in this export.',
          ),
          pw.SizedBox(height: 10),
          _buildSimpleTable(
            headers: detailHeaders,
            rows: detailRows,
            columnFlex: detailFlex,
          ),
        ],
      ),
    );

    return doc.save();
  }

  Future<void> exportPersonalCsvAndShare(
    SpendingProvider provider, {
    List<String>? categoryFilters,
  }) async {
    final dailyTotals = provider.getDailyTotalsForPeriod();
    final rows = <_PersonalRow>[];
    final categoryTotals = <String, double>{};
    double overallTotal = 0;

    for (final entry in dailyTotals) {
      final date = entry.key;
      final entriesForDate = provider.getEntriesForDate(date);
      for (final e in entriesForDate) {
        final cat = provider.categoryLabelOf(e);
        if (!_matchesCategoryFilter(cat, categoryFilters)) continue;

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
        'Period: ${_dateFmt.format(provider.periodStart!)} -> ${_dateFmt.format(provider.periodEnd!)}',
      );
    }
    if (categoryFilters != null && categoryFilters.isNotEmpty) {
      buffer.writeln('Selected Categories: ${categoryFilters.join(', ')}');
    }
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

    final suffix = _categoryFilenameSuffix(categoryFilters);
    final file = await _writeTempTextFile(
      'personal_spendings$suffix.csv',
      buffer.toString(),
    );

    await _shareFile(file, text: 'Personal spendings (CSV)');
  }

  Future<void> exportPersonalPdfAndShare(
    SpendingProvider provider, {
    List<String>? categoryFilters,
    required String reportTitle,
  }) async {
    final dailyTotals = provider.getDailyTotalsForPeriod();
    final rows = <_PersonalRow>[];
    final categoryTotals = <String, double>{};
    double overallTotal = 0;

    for (final entry in dailyTotals) {
      final date = entry.key;
      final entriesForDate = provider.getEntriesForDate(date);

      for (final e in entriesForDate) {
        final cat = provider.categoryLabelOf(e);
        if (!_matchesCategoryFilter(cat, categoryFilters)) continue;

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

    final totalsRows =
        categoryTotals.entries
            .map((entry) => [entry.key, _formatAmount(entry.value)])
            .toList()
          ..add(['All selected categories total', _formatAmount(overallTotal)]);
    final detailRows = rows
        .map(
          (row) => [
            _dateFmt.format(row.date),
            row.item.isEmpty ? 'Spending' : row.item,
            row.category,
            row.bank,
            row.qty?.toString() ?? '',
            row.amount.toStringAsFixed(2),
          ],
        )
        .toList();

    final period = provider.periodStart != null && provider.periodEnd != null
        ? '${_dateFmt.format(provider.periodStart!)} -> ${_dateFmt.format(provider.periodEnd!)}'
        : null;

    final bytes = await _buildReportPdf(
      reportTitle: reportTitle,
      reportType: 'Personal spending report',
      totalSpent: _formatAmount(overallTotal),
      selectedCategories: categoryFilters,
      period: period,
      metrics: [
        _SummaryMetric(label: 'Transactions', value: '${rows.length}'),
        _SummaryMetric(
          label: 'Total spent',
          value: _formatAmount(overallTotal),
        ),
        _SummaryMetric(
          label: 'Average transaction',
          value: rows.isEmpty
              ? _formatAmount(0)
              : _formatAmount(overallTotal / rows.length),
        ),
      ],
      secondaryHeaders: const ['Category', 'Total'],
      secondaryTableRows: totalsRows,
      secondaryFlex: const [2.2, 1],
      detailHeaders: const [
        'Date',
        'Description',
        'Category',
        'Bank',
        'Qty',
        'Amount',
      ],
      detailRows: detailRows,
      detailFlex: const [1.2, 2.4, 1.6, 1.4, 0.8, 1],
    );

    final suffix = _categoryFilenameSuffix(categoryFilters);
    final file = await _writeTempBytesFile(
      'personal_spendings$suffix.pdf',
      bytes,
    );
    await _shareFile(file, text: 'Personal spendings (PDF)');
  }

  Future<void> exportCategoryPdfAndShare(
    SpendingProvider provider, {
    required String category,
    required String reportTitle,
  }) async {
    final rows = provider.getCategoryRecords(category);
    final total = rows.fold<double>(0, (sum, row) => sum + row.entry.amount);
    final transactionCount = rows.length;
    final average = transactionCount == 0 ? 0.0 : total / transactionCount;
    final latestDate = rows.isEmpty ? null : rows.first.date;
    final earliestDate = rows.isEmpty ? null : rows.last.date;

    final detailRows = rows
        .map(
          (row) => [
            _dateFmt.format(row.date),
            row.entry.item?.trim().isNotEmpty == true
                ? row.entry.item!.trim()
                : 'Spending',
            row.entry.bank ?? '',
            row.entry.qty?.toString() ?? '',
            row.entry.amount.toStringAsFixed(2),
          ],
        )
        .toList();

    final history = earliestDate != null && latestDate != null
        ? '${_dateFmt.format(earliestDate)} -> ${_dateFmt.format(latestDate)}'
        : null;

    final bytes = await _buildReportPdf(
      reportTitle: reportTitle,
      reportType: 'Category spending report',
      totalSpent: _formatAmount(total),
      selectedCategories: [category],
      period: history,
      metrics: [
        _SummaryMetric(label: 'Transactions', value: '$transactionCount'),
        _SummaryMetric(label: 'Total spent', value: _formatAmount(total)),
        _SummaryMetric(label: 'Average spend', value: _formatAmount(average)),
      ],
      detailHeaders: const ['Date', 'Description', 'Bank', 'Qty', 'Amount'],
      detailRows: detailRows,
      detailFlex: const [1.2, 2.8, 1.8, 0.8, 1],
    );

    final file = await _writeTempBytesFile(
      'category_${_sanitizeFilenamePart(category)}.pdf',
      bytes,
    );
    await _shareFile(file, text: 'Category spending report');
  }

  Future<void> exportOtherCsvAndShare(
    OtherSpendingProvider provider, {
    List<String>? categoryFilters,
  }) async {
    var entries = provider.uniqueEntries;

    if (categoryFilters != null && categoryFilters.isNotEmpty) {
      entries = entries.where((e) {
        final cat = (e.category == null || e.category!.trim().isEmpty)
            ? 'Uncategorized'
            : e.category!.trim();
        return categoryFilters.contains(cat);
      }).toList();
    }

    final categoryTotals = <String, double>{};
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
    if (categoryFilters != null && categoryFilters.isNotEmpty) {
      buffer.writeln('Selected Categories: ${categoryFilters.join(', ')}');
    }
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

    final suffix = _categoryFilenameSuffix(categoryFilters);
    final file = await _writeTempTextFile(
      'other_spendings$suffix.csv',
      buffer.toString(),
    );

    await _shareFile(file, text: 'Other spendings (CSV)');
  }

  Future<void> exportOtherPdfAndShare(
    OtherSpendingProvider provider, {
    List<String>? categoryFilters,
    required String reportTitle,
  }) async {
    var entries = provider.uniqueEntries;

    if (categoryFilters != null && categoryFilters.isNotEmpty) {
      entries = entries.where((e) {
        final cat = (e.category == null || e.category!.trim().isEmpty)
            ? 'Uncategorized'
            : e.category!.trim();
        return categoryFilters.contains(cat);
      }).toList();
    }

    final categoryTotals = <String, double>{};
    double overallTotal = 0;

    for (final e in entries) {
      final cat = (e.category == null || e.category!.trim().isEmpty)
          ? 'Uncategorized'
          : e.category!.trim();

      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + e.amount;
      overallTotal += e.amount;
    }

    final detailRows = entries
        .map(
          (e) => [
            _dateFmt.format(e.date),
            e.title ?? 'Other spending',
            (e.category == null || e.category!.trim().isEmpty)
                ? 'Uncategorized'
                : e.category!.trim(),
            e.bank ?? '',
            e.qty?.toString() ?? '',
            e.amount.toStringAsFixed(2),
          ],
        )
        .toList();
    final totalsRows =
        categoryTotals.entries
            .map((entry) => [entry.key, _formatAmount(entry.value)])
            .toList()
          ..add(['All selected categories total', _formatAmount(overallTotal)]);

    final bytes = await _buildReportPdf(
      reportTitle: reportTitle,
      reportType: 'Other spending report',
      totalSpent: _formatAmount(overallTotal),
      selectedCategories: categoryFilters,
      metrics: [
        _SummaryMetric(label: 'Transactions', value: '${entries.length}'),
        _SummaryMetric(
          label: 'Total spent',
          value: _formatAmount(overallTotal),
        ),
        _SummaryMetric(
          label: 'Average transaction',
          value: entries.isEmpty
              ? _formatAmount(0)
              : _formatAmount(overallTotal / entries.length),
        ),
      ],
      secondaryHeaders: const ['Category', 'Total'],
      secondaryTableRows: totalsRows,
      secondaryFlex: const [2.2, 1],
      detailHeaders: const [
        'Date',
        'Title',
        'Category',
        'Bank',
        'Qty',
        'Amount',
      ],
      detailRows: detailRows,
      detailFlex: const [1.2, 2.2, 1.5, 1.3, 0.8, 1],
    );

    final suffix = _categoryFilenameSuffix(categoryFilters);
    final file = await _writeTempBytesFile('other_spendings$suffix.pdf', bytes);
    await _shareFile(file, text: 'Other spendings (PDF)');
  }

  DailySpendingReportData buildDailySpendingReportData({
    required SpendingProvider spendingProvider,
    required OtherSpendingProvider otherProvider,
    required DateTime date,
    bool includeOtherSpendings = true,
  }) {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final personalEntries = spendingProvider.getEntriesForDate(normalizedDate);
    final otherEntries = includeOtherSpendings
        ? otherProvider.getUniqueEntriesForDate(normalizedDate)
        : const <OtherSpendingEntry>[];

    final rows = <DailySpendingReportRow>[];
    final categoryTotals = <String, double>{};

    for (final entry in personalEntries) {
      final category = spendingProvider.categoryLabelOf(entry);
      rows.add(
        DailySpendingReportRow(
          timestamp: normalizedDate,
          source: 'Personal',
          description: (entry.item?.trim().isNotEmpty ?? false)
              ? entry.item!.trim()
              : 'Spending',
          category: category,
          bank: entry.bank ?? '',
          qty: entry.qty,
          amount: entry.amount,
        ),
      );
      categoryTotals[category] = (categoryTotals[category] ?? 0) + entry.amount;
    }

    for (final entry in otherEntries) {
      final category =
          (entry.category == null || entry.category!.trim().isEmpty)
          ? 'Uncategorized'
          : entry.category!.trim();
      rows.add(
        DailySpendingReportRow(
          timestamp: entry.date,
          source: 'Other',
          description: (entry.title?.trim().isNotEmpty ?? false)
              ? entry.title!.trim()
              : 'Other spending',
          category: category,
          bank: entry.bank ?? '',
          qty: entry.qty,
          amount: entry.amount,
        ),
      );
      categoryTotals[category] = (categoryTotals[category] ?? 0) + entry.amount;
    }

    rows.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final totalSpent = rows.fold<double>(0, (sum, row) => sum + row.amount);
    final categories = categoryTotals.keys.toList()..sort();

    return DailySpendingReportData(
      date: normalizedDate,
      reportTitle: 'Daily Spending Report',
      rows: rows,
      categoryTotals: categoryTotals,
      totalSpent: totalSpent,
      categories: categories,
    );
  }

  Future<File> generateDailySpendingReportPdf(
    DailySpendingReportData reportData,
  ) async {
    final detailRows = reportData.rows
        .map(
          (row) => [
            DateFormat('HH:mm').format(row.timestamp),
            row.source,
            row.description,
            row.category,
            row.bank,
            row.qty?.toString() ?? '',
            _formatAmount(row.amount),
          ],
        )
        .toList();

    final totalsRows = reportData.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final formattedTotalsRows =
        totalsRows
            .map((entry) => [entry.key, _formatAmount(entry.value)])
            .toList()
          ..add(['All categories total', _formatAmount(reportData.totalSpent)]);

    final bytes = await _buildReportPdf(
      reportTitle: reportData.reportTitle,
      reportType: 'Daily spending report',
      totalSpent: _formatAmount(reportData.totalSpent),
      selectedCategories: reportData.categories,
      period: _dateFmt.format(reportData.date),
      metrics: [
        _SummaryMetric(
          label: 'Transactions',
          value: '${reportData.rows.length}',
        ),
        _SummaryMetric(
          label: 'Total spent',
          value: _formatAmount(reportData.totalSpent),
        ),
        _SummaryMetric(
          label: 'Average transaction',
          value: reportData.rows.isEmpty
              ? _formatAmount(0)
              : _formatAmount(reportData.totalSpent / reportData.rows.length),
        ),
      ],
      secondaryHeaders: const ['Category', 'Total'],
      secondaryTableRows: formattedTotalsRows,
      secondaryFlex: const [2.2, 1],
      detailHeaders: const [
        'Time',
        'Source',
        'Description',
        'Category',
        'Bank',
        'Qty',
        'Amount',
      ],
      detailRows: detailRows,
      detailFlex: const [1, 1.2, 2.7, 1.6, 1.3, 0.7, 1],
    );

    return _writeTempBytesFile(
      'daily_spending_${_sanitizeFilenamePart(_dateFmt.format(reportData.date))}.pdf',
      bytes,
    );
  }
}

class _PdfFonts {
  final pw.Font base;

  const _PdfFonts({required this.base});
}

class _SummaryMetric {
  final String label;
  final String value;

  const _SummaryMetric({required this.label, required this.value});
}

class _PersonalRow {
  final DateTime date;
  final String item;
  final String category;
  final String bank;
  final int? qty;
  final double amount;

  const _PersonalRow({
    required this.date,
    required this.item,
    required this.category,
    required this.bank,
    required this.qty,
    required this.amount,
  });
}

class DailySpendingReportData {
  final DateTime date;
  final String reportTitle;
  final List<DailySpendingReportRow> rows;
  final Map<String, double> categoryTotals;
  final double totalSpent;
  final List<String> categories;

  const DailySpendingReportData({
    required this.date,
    required this.reportTitle,
    required this.rows,
    required this.categoryTotals,
    required this.totalSpent,
    required this.categories,
  });
}

class DailySpendingReportRow {
  final DateTime timestamp;
  final String source;
  final String description;
  final String category;
  final String bank;
  final int? qty;
  final double amount;

  const DailySpendingReportRow({
    required this.timestamp,
    required this.source,
    required this.description,
    required this.category,
    required this.bank,
    required this.qty,
    required this.amount,
  });
}
