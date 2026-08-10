import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../localization/demo_localization.dart';
import '../localization/language_constants.dart';
import '../providers/other_spending_provider.dart';
import '../providers/spending_provider.dart';

class ExportService {
  ExportService._();

  static final ExportService instance = ExportService._();

  final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');
  Future<_PdfFonts>? _fontsFuture;
  String _languageCode = english;
  static const PdfColor _brandTeal = PdfColor.fromInt(0xFF0F766E);
  static const PdfColor _brandTealDark = PdfColor.fromInt(0xFF0B5E58);
  static const PdfColor _brandMint = PdfColor.fromInt(0xFFD6F0EB);
  static const PdfColor _brandInk = PdfColor.fromInt(0xFF102A43);
  static const PdfColor _panelBackground = PdfColor.fromInt(0xFFF5FBFA);
  static const PdfColor _panelBorder = PdfColor.fromInt(0xFFD8EAE7);
  static const PdfColor _mutedText = PdfColor.fromInt(0xFF5F7177);
  static const PdfColor _goldAccent = PdfColor.fromInt(0xFFE8B04A);

  Future<void> prepareLocale() async {
    _languageCode = await getCurrentLanguageCode();
    await DemoLocalization.loadLanguageMap(_languageCode);
  }

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

  String _tr(String key, [Map<String, String> args = const {}]) {
    var value = DemoLocalization.translateCached(_languageCode, key);
    args.forEach((placeholder, replacement) {
      value = value.replaceAll('{$placeholder}', replacement);
    });
    return value;
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
        gradient: const pw.LinearGradient(
          colors: [_brandTeal, _brandTealDark],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(22),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: pw.BorderRadius.circular(999),
                      ),
                      child: _text(
                        reportType,
                        style: const pw.TextStyle(
                          color: _brandTeal,
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
                    pw.SizedBox(height: 10),
                    _text(
                      'A polished analytics summary of the spending records included in this export.',
                      style: pw.TextStyle(
                        color: PdfColor.fromInt(0xD9FFFFFF),
                        fontSize: 10.5,
                      ),
                    ),
                    pw.SizedBox(height: 14),
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
                  ],
                ),
              ),
              pw.SizedBox(width: 16),
              pw.Expanded(flex: 2, child: _buildTotalSpentBanner(totalSpent)),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTotalSpentBanner(String totalSpent) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0x24FFFFFF),
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: PdfColor.fromInt(0x40FFFFFF), width: 0.9),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _text(
                'Total Spent',
                style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0x1AFFFFFF),
                  borderRadius: pw.BorderRadius.circular(999),
                ),
                child: _text(
                  'SAR',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          _text(
            totalSpent,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0x18FFFFFF),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: _text(
              'Includes only the transactions visible in this report.',
              style: pw.TextStyle(
                color: PdfColor.fromInt(0xD9FFFFFF),
                fontSize: 9.5,
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

  pw.Widget _buildOverviewPanel({
    required String title,
    String? subtitle,
    required List<pw.Widget> children,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(18),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _panelBorder, width: 0.9),
        borderRadius: pw.BorderRadius.circular(20),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _text(
            title,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _brandInk,
            ),
          ),
          if (subtitle != null) ...[
            pw.SizedBox(height: 5),
            _text(
              subtitle,
              style: pw.TextStyle(fontSize: 10, color: _mutedText),
            ),
          ],
          pw.SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _buildCoverSummarySection(List<_SummaryMetric> metrics) {
    return pw.Wrap(
      spacing: 12,
      runSpacing: 12,
      children: metrics.map(_buildMetricCard).toList(),
    );
  }

  pw.Widget _buildMetricCard(_SummaryMetric metric) {
    return pw.Container(
      width: 165,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: _panelBorder),
        borderRadius: pw.BorderRadius.circular(16),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 28,
            height: 4,
            decoration: pw.BoxDecoration(
              color: _brandTeal,
              borderRadius: pw.BorderRadius.circular(999),
            ),
          ),
          pw.SizedBox(height: 12),
          _text(
            metric.label,
            style: pw.TextStyle(fontSize: 10, color: _mutedText),
          ),
          pw.SizedBox(height: 8),
          _text(
            metric.value,
            style: pw.TextStyle(
              fontSize: 17,
              fontWeight: pw.FontWeight.bold,
              color: _brandInk,
            ),
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
      final textColor = header ? PdfColors.white : _brandInk;
      final background = header
          ? _brandTeal
          : const PdfColor.fromInt(0x00FFFFFF);
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

    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(16),
        border: pw.Border.all(color: _panelBorder, width: 0.8),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Table(
        border: pw.TableBorder.all(
          color: PdfColor.fromHex('#D7E3E3'),
          width: 0.6,
        ),
        columnWidths: widths,
        children: tableRows,
      ),
    );
  }

  pw.Widget _buildDataPanel({
    required String title,
    String? subtitle,
    required pw.Widget child,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _panelBackground,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: _panelBorder),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title, subtitle: subtitle),
          pw.SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  pw.Widget _buildCategoryBreakdownSection(
    List<_CategoryBreakdownItem> items, {
    required String totalLabel,
    required double totalAmount,
  }) {
    final displayItems = items.take(6).toList();

    return _buildDataPanel(
      title: 'Category analytics',
      subtitle:
          'Visual breakdown of where the selected spending is concentrated.',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: displayItems.map((item) {
              final ratio = totalAmount <= 0
                  ? 0.0
                  : (item.total / totalAmount).clamp(0.0, 1.0);
              return pw.Container(
                width: 245,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColors.white,
                  borderRadius: pw.BorderRadius.circular(16),
                  border: pw.Border.all(color: _panelBorder),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Container(
                          width: 28,
                          height: 28,
                          decoration: pw.BoxDecoration(
                            color: item.rank == 1 ? _goldAccent : _brandMint,
                            borderRadius: pw.BorderRadius.circular(10),
                          ),
                          alignment: pw.Alignment.center,
                          child: _text(
                            '${item.rank}',
                            style: pw.TextStyle(
                              color: item.rank == 1
                                  ? PdfColors.white
                                  : _brandTeal,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        pw.SizedBox(width: 10),
                        pw.Expanded(
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              _text(
                                item.label,
                                style: pw.TextStyle(
                                  fontSize: 11,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _brandInk,
                                ),
                                maxLines: 2,
                              ),
                              pw.SizedBox(height: 3),
                              _text(
                                _formatAmount(item.total),
                                style: pw.TextStyle(
                                  fontSize: 13,
                                  fontWeight: pw.FontWeight.bold,
                                  color: _brandTeal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        pw.SizedBox(width: 6),
                        _text(
                          '${(ratio * 100).toStringAsFixed(0)}%',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: _mutedText,
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 10),
                    pw.ClipRRect(
                      horizontalRadius: 999,
                      verticalRadius: 999,
                      child: pw.LinearProgressIndicator(
                        value: ratio,
                        minHeight: 7,
                        backgroundColor: PdfColor.fromHex('#E7F2F0'),
                        valueColor: _brandTeal,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(14),
              border: pw.Border.all(color: _panelBorder),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _text(
                  totalLabel,
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: _mutedText,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                _text(
                  _formatAmount(totalAmount),
                  style: pw.TextStyle(
                    fontSize: 12,
                    color: _brandInk,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildCompactCategoryHighlights(
    List<_CategoryBreakdownItem> items, {
    required double totalAmount,
  }) {
    final displayItems = items.take(4).toList();

    return _buildOverviewPanel(
      title: 'Category spotlight',
      subtitle: 'Top categories by share of the selected spending total.',
      children: [
        pw.Wrap(
          spacing: 12,
          runSpacing: 12,
          children: displayItems.map((item) {
            final ratio = totalAmount <= 0
                ? 0.0
                : (item.total / totalAmount).clamp(0.0, 1.0);
            return pw.Container(
              width: 240,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: _panelBackground,
                borderRadius: pw.BorderRadius.circular(16),
                border: pw.Border.all(color: _panelBorder),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: 28,
                        height: 28,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          color: item.rank == 1 ? _goldAccent : _brandMint,
                          borderRadius: pw.BorderRadius.circular(9),
                        ),
                        child: _text(
                          '${item.rank}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: item.rank == 1
                                ? PdfColors.white
                                : _brandTeal,
                          ),
                        ),
                      ),
                      pw.SizedBox(width: 10),
                      pw.Expanded(
                        child: _text(
                          item.label,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: _brandInk,
                          ),
                          maxLines: 2,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      _text(
                        '${(ratio * 100).toStringAsFixed(0)}%',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _mutedText,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  _text(
                    _formatAmount(item.total),
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: _brandTeal,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.ClipRRect(
                    horizontalRadius: 999,
                    verticalRadius: 999,
                    child: pw.LinearProgressIndicator(
                      value: ratio,
                      minHeight: 7,
                      backgroundColor: PdfColor.fromHex('#E7F2F0'),
                      valueColor: _brandTeal,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  pw.Widget _buildReportSnapshotPanel({
    required int transactionCount,
    required String totalSpent,
    required String generatedAt,
    String? period,
    List<String>? selectedCategories,
  }) {
    return _buildOverviewPanel(
      title: 'Report snapshot',
      subtitle: 'A quick overview before the detailed ledger.',
      children: [
        _buildSnapshotRow('Transactions', '$transactionCount'),
        pw.SizedBox(height: 10),
        _buildSnapshotRow('Total spent', totalSpent),
        pw.SizedBox(height: 10),
        _buildSnapshotRow(
          'Category scope',
          _categorySelectionLabel(selectedCategories),
        ),
        if (period != null && period.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          _buildSnapshotRow('Period', period),
        ],
        pw.SizedBox(height: 10),
        _buildSnapshotRow('Generated', generatedAt),
      ],
    );
  }

  pw.Widget _buildSnapshotRow(String label, String value) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: pw.BoxDecoration(
        color: _panelBackground,
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: _text(
              label,
              style: pw.TextStyle(
                fontSize: 10,
                color: _mutedText,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: _text(
              value,
              style: pw.TextStyle(
                fontSize: 10.5,
                color: _brandInk,
                fontWeight: pw.FontWeight.bold,
              ),
              align: pw.TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDetailSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: pw.BoxDecoration(
        color: _panelBackground,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: _panelBorder),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _text(
            title,
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight: pw.FontWeight.bold,
              color: _brandInk,
            ),
          ),
          pw.SizedBox(height: 4),
          _text(subtitle, style: pw.TextStyle(fontSize: 10, color: _mutedText)),
        ],
      ),
    );
  }

  pw.Widget _buildCoverPageBackground() {
    return pw.Container(
      height: 150,
      decoration: pw.BoxDecoration(
        gradient: const pw.LinearGradient(
          colors: [_brandTeal, _brandTealDark],
          begin: pw.Alignment.topLeft,
          end: pw.Alignment.bottomRight,
        ),
        borderRadius: pw.BorderRadius.circular(30),
      ),
      child: pw.Align(
        alignment: pw.Alignment.topRight,
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(top: 18, right: 22),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 72,
                height: 72,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0x14FFFFFF),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Container(
                width: 34,
                height: 34,
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0x18FFFFFF),
                  shape: pw.BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_SummaryMetric> _buildDisplayMetrics({
    required String totalSpent,
    required List<_SummaryMetric> metrics,
    required int categoryCount,
  }) {
    final items = <_SummaryMetric>[
      _SummaryMetric(label: 'Total Spent', value: totalSpent),
    ];

    for (final metric in metrics) {
      if (metric.label.toLowerCase() == 'total spent') continue;
      items.add(metric);
    }

    items.add(
      _SummaryMetric(
        label: 'Categories',
        value: categoryCount <= 0 ? 'All' : '$categoryCount',
      ),
    );

    final seen = <String>{};
    final deduped = <_SummaryMetric>[];
    for (final item in items) {
      final key = item.label.toLowerCase();
      if (!seen.add(key)) continue;
      deduped.add(item);
    }
    return deduped.take(4).toList();
  }

  pw.Widget _buildOptionCHeader({
    required String reportTitle,
    required String reportType,
    required String generatedAt,
    String? period,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(22),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(18),
        border: pw.Border.all(color: _panelBorder, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Container(
                    width: 34,
                    height: 34,
                    decoration: pw.BoxDecoration(
                      color: _brandTeal,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 10),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      _text(
                        'Personal',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _brandInk,
                        ),
                      ),
                      _text(
                        'Spending Tracker',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: _brandInk,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  _text(
                    'Report Date',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: _mutedText,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  _text(
                    generatedAt,
                    style: pw.TextStyle(
                      fontSize: 10,
                      color: _brandInk,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 22),
          _text(
            reportTitle,
            style: pw.TextStyle(
              fontSize: 26,
              fontWeight: pw.FontWeight.bold,
              color: _brandInk,
            ),
          ),
          pw.SizedBox(height: 6),
          _text(
            period?.isNotEmpty == true ? period! : reportType,
            style: pw.TextStyle(fontSize: 11, color: _mutedText),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildOptionCSummaryCards(List<_SummaryMetric> metrics) {
    return pw.Wrap(
      spacing: 10,
      runSpacing: 10,
      children: metrics
          .map(
            (metric) => pw.Container(
              width: 122,
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: PdfColors.white,
                borderRadius: pw.BorderRadius.circular(18),
                border: pw.Border.all(color: _panelBorder, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _text(
                    metric.label,
                    style: pw.TextStyle(
                      fontSize: 9.5,
                      color: _mutedText,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _text(
                    metric.value,
                    style: pw.TextStyle(
                      fontSize: 16,
                      color: _brandInk,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _buildOptionCSelectedCategories(List<String>? categories) {
    final values = (categories == null || categories.isEmpty)
        ? const ['All categories']
        : categories;
    final visibleValues = values.take(8).toList();
    final hiddenCount = values.length - visibleValues.length;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _text(
          'Selected Categories',
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: _brandInk,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...visibleValues
                .map(
                  (category) => pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(999),
                      border: pw.Border.all(color: _panelBorder, width: 0.8),
                    ),
                    child: _text(
                      category,
                      style: pw.TextStyle(
                        fontSize: 9.5,
                        color: _brandInk,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                )
                .toList(),
            if (hiddenCount > 0)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F7FAFD'),
                  borderRadius: pw.BorderRadius.circular(999),
                  border: pw.Border.all(color: _panelBorder, width: 0.8),
                ),
                child: _text(
                  '+ $hiddenCount more',
                  style: pw.TextStyle(
                    fontSize: 9.5,
                    color: _mutedText,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSectionCard({
    required String title,
    required pw.Widget child,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(20),
        border: pw.Border.all(color: _panelBorder, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: _brandInk,
            ),
          ),
          pw.SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  PdfColor _paletteForRank(int rank) {
    const palette = <PdfColor>[
      PdfColor.fromInt(0xFF7BC96F),
      PdfColor.fromInt(0xFF4A90E2),
      PdfColor.fromInt(0xFF8B6FE8),
      PdfColor.fromInt(0xFFF5B544),
      PdfColor.fromInt(0xFF56C5D0),
      PdfColor.fromInt(0xFFE97979),
    ];
    return palette[(rank - 1) % palette.length];
  }

  pw.Widget _buildOverviewVisual({
    required List<_CategoryBreakdownItem> items,
    required double totalAmount,
    required String totalSpent,
  }) {
    return pw.Column(
      children: [
        pw.Container(
          width: 180,
          height: 180,
          decoration: pw.BoxDecoration(
            shape: pw.BoxShape.circle,
            border: pw.Border.all(
              color: PdfColor.fromHex('#DDE8F5'),
              width: 18,
            ),
          ),
          child: pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                _text(
                  totalSpent,
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: _brandInk,
                  ),
                  align: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 6),
                _text(
                  '${items.length} categories',
                  style: pw.TextStyle(fontSize: 9.5, color: _mutedText),
                ),
              ],
            ),
          ),
        ),
        if (items.isNotEmpty) ...[
          pw.SizedBox(height: 14),
          pw.Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: pw.WrapAlignment.center,
            children: items.take(4).map((item) {
              final ratio = totalAmount <= 0
                  ? 0.0
                  : (item.total / totalAmount).clamp(0.0, 1.0);
              return pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Container(
                    width: 8,
                    height: 8,
                    decoration: pw.BoxDecoration(
                      color: _paletteForRank(item.rank),
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                  pw.SizedBox(width: 4),
                  _text(
                    '${(ratio * 100).toStringAsFixed(1)}%',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: _mutedText,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildCategoryBreakdownList({
    required List<_CategoryBreakdownItem> items,
    required double totalAmount,
    required String totalLabel,
  }) {
    final widgets = <pw.Widget>[];
    for (final item in items) {
      final ratio = totalAmount <= 0
          ? 0.0
          : (item.total / totalAmount).clamp(0.0, 1.0);
      widgets.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 10,
                height: 10,
                margin: const pw.EdgeInsets.only(top: 3),
                decoration: pw.BoxDecoration(
                  color: _paletteForRank(item.rank),
                  shape: pw.BoxShape.circle,
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _text(
                  item.label,
                  style: pw.TextStyle(
                    fontSize: 10.5,
                    color: _brandInk,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              _text(
                _formatAmount(item.total),
                style: pw.TextStyle(
                  fontSize: 10.5,
                  color: _brandInk,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(width: 8),
              _text(
                '${(ratio * 100).toStringAsFixed(1)}%',
                style: pw.TextStyle(
                  fontSize: 9.5,
                  color: _mutedText,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    widgets.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 6),
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: pw.BoxDecoration(
          color: PdfColor.fromHex('#F7FAFD'),
          borderRadius: pw.BorderRadius.circular(14),
          border: pw.Border.all(color: _panelBorder, width: 0.8),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: _text(
                totalLabel,
                style: pw.TextStyle(
                  fontSize: 9.5,
                  color: _mutedText,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(width: 8),
            _text(
              _formatAmount(totalAmount),
              style: pw.TextStyle(
                fontSize: 10.5,
                color: _brandInk,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );

    return pw.Column(children: widgets);
  }

  pw.Widget _buildOptionCOverviewSection({
    required List<_CategoryBreakdownItem> items,
    required double totalAmount,
    required String totalSpent,
    required String totalLabel,
  }) {
    final displayItems = items.take(6).toList();
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          child: _buildSectionCard(
            title: 'Spending Overview',
            child: _buildOverviewVisual(
              items: displayItems,
              totalAmount: totalAmount,
              totalSpent: totalSpent,
            ),
          ),
        ),
        pw.SizedBox(width: 14),
        pw.Expanded(
          child: _buildSectionCard(
            title: 'Spending by Category',
            child: _buildCategoryBreakdownList(
              items: displayItems,
              totalAmount: totalAmount,
              totalLabel: totalLabel,
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildOptionCFooterBanner() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('#EEF6FF'),
        borderRadius: pw.BorderRadius.circular(14),
      ),
      child: _text(
        'Great job staying on top of your finances!',
        style: pw.TextStyle(
          fontSize: 9.5,
          color: _brandInk,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
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
    List<_CategoryBreakdownItem>? categoryBreakdown,
    String? categoryBreakdownTotalLabel,
    List<String>? selectedCategories,
    String? period,
  }) async {
    final normalizedReportTitle = reportTitle.trim().isEmpty
        ? reportType
        : reportTitle.trim();

    final fonts = await _loadFonts();
    final generatedAt = DateFormat(
      'dd MMM yyyy  hh:mm a',
    ).format(DateTime.now());

    final doc = pw.Document(
      title: normalizedReportTitle,
      author: 'Personal Spending Tracker',
    );

    final categoryItems = categoryBreakdown ?? const <_CategoryBreakdownItem>[];
    final totalAmount = categoryItems.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );

    final displayMetrics = _buildDisplayMetrics(
      totalSpent: totalSpent,
      metrics: metrics,
      categoryCount: selectedCategories?.length ?? categoryItems.length,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 28, 32, 32),
        theme: pw.ThemeData.withFont(
          base: fonts.base,
          bold: fonts.base,
          italic: fonts.base,
          boldItalic: fonts.base,
        ),
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 14),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromHex('#EEF7FF'),
                    borderRadius: pw.BorderRadius.circular(14),
                  ),
                  child: _text(
                    'Great job staying on top of your finances!',
                    style: pw.TextStyle(
                      fontSize: 9,
                      color: _brandInk,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                _text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: _mutedText,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) => [
          _buildOptionCHeader(
            reportTitle: normalizedReportTitle,
            reportType: reportType,
            generatedAt: generatedAt,
            period: period,
          ),

          pw.SizedBox(height: 18),

          _buildOptionCSummaryCards(displayMetrics),

          pw.SizedBox(height: 18),

          _buildOptionCSelectedCategories(selectedCategories),

          if (categoryItems.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            _buildOptionCOverviewSection(
              items: categoryItems,
              totalAmount: totalAmount,
              totalSpent: totalSpent,
              totalLabel:
                  categoryBreakdownTotalLabel ?? 'Selected categories total',
            ),
          ],

          pw.SizedBox(height: 20),

          _buildDetailSectionHeader(
            title: 'Transactions',
            subtitle:
                'Detailed records included in this export, formatted for review and archiving.',
          ),

          pw.SizedBox(height: 10),

          if (detailRows.isEmpty)
            _buildSectionCard(
              title: 'No transactions',
              child: _text(
                'No transactions were found for the selected filters and date range.',
                style: pw.TextStyle(fontSize: 10.5, color: _mutedText),
              ),
            )
          else
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
    await prepareLocale();
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

    final categoryBreakdown = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final detailRows = rows
        .map(
          (row) => [
            _dateFmt.format(row.date),
            row.item.isEmpty ? _tr('Spending') : row.item,
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
      reportType: _tr('Personal spending report'),
      totalSpent: _formatAmount(overallTotal),
      selectedCategories: categoryFilters,
      period: period,
      metrics: [
        _SummaryMetric(label: _tr('Transactions'), value: '${rows.length}'),
        _SummaryMetric(
          label: _tr('Total spent'),
          value: _formatAmount(overallTotal),
        ),
        _SummaryMetric(
          label: _tr('Average transaction'),
          value: rows.isEmpty
              ? _formatAmount(0)
              : _formatAmount(overallTotal / rows.length),
        ),
      ],
      categoryBreakdown: [
        for (var i = 0; i < categoryBreakdown.length; i++)
          _CategoryBreakdownItem(
            label: categoryBreakdown[i].key,
            total: categoryBreakdown[i].value,
            rank: i + 1,
          ),
      ],
      categoryBreakdownTotalLabel: _tr('All selected categories total'),
      detailHeaders: [
        _tr('Date'),
        _tr('Description'),
        _tr('Category'),
        _tr('Bank'),
        _tr('Qty'),
        _tr('Amount'),
      ],
      detailRows: detailRows,
      detailFlex: const [1.2, 2.4, 1.6, 1.4, 0.8, 1],
    );

    final suffix = _categoryFilenameSuffix(categoryFilters);
    final file = await _writeTempBytesFile(
      'personal_spendings$suffix.pdf',
      bytes,
    );
    await _shareFile(file, text: _tr('Personal spendings (PDF)'));
  }

  Future<void> exportCategoryPdfAndShare(
    SpendingProvider provider, {
    required String category,
    required String reportTitle,
  }) async {
    await prepareLocale();
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
                : _tr('Spending'),
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
      reportType: _tr('Category spending report'),
      totalSpent: _formatAmount(total),
      selectedCategories: [category],
      period: history,
      metrics: [
        _SummaryMetric(label: _tr('Transactions'), value: '$transactionCount'),
        _SummaryMetric(label: _tr('Total spent'), value: _formatAmount(total)),
        _SummaryMetric(
          label: _tr('Average spend'),
          value: _formatAmount(average),
        ),
      ],
      detailHeaders: [
        _tr('Date'),
        _tr('Description'),
        _tr('Bank'),
        _tr('Qty'),
        _tr('Amount'),
      ],
      detailRows: detailRows,
      detailFlex: const [1.2, 2.8, 1.8, 0.8, 1],
    );

    final file = await _writeTempBytesFile(
      'category_${_sanitizeFilenamePart(category)}.pdf',
      bytes,
    );
    await _shareFile(file, text: _tr('Category spending report'));
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
    final categoryBreakdown = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

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
      categoryBreakdown: [
        for (var i = 0; i < categoryBreakdown.length; i++)
          _CategoryBreakdownItem(
            label: categoryBreakdown[i].key,
            total: categoryBreakdown[i].value,
            rank: i + 1,
          ),
      ],
      categoryBreakdownTotalLabel: 'All selected categories total',
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
          source: _tr('Personal'),
          description: (entry.item?.trim().isNotEmpty ?? false)
              ? entry.item!.trim()
              : _tr('Spending'),
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
          ? _tr('Uncategorized')
          : entry.category!.trim();
      rows.add(
        DailySpendingReportRow(
          timestamp: entry.date,
          source: _tr('Other'),
          description: (entry.title?.trim().isNotEmpty ?? false)
              ? entry.title!.trim()
              : _tr('Other spending'),
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
      reportTitle: _tr('Daily Spending Report'),
      rows: rows,
      categoryTotals: categoryTotals,
      totalSpent: totalSpent,
      categories: categories,
    );
  }

  Future<File> generateDailySpendingReportPdf(
    DailySpendingReportData reportData,
  ) async {
    await prepareLocale();
    final bytes = await generateDailySpendingReportPdfBytes(reportData);

    return _writeTempBytesFile(
      'daily_spending_${_sanitizeFilenamePart(_dateFmt.format(reportData.date))}.pdf',
      bytes,
    );
  }

  Future<List<int>> generateDailySpendingReportPdfBytes(
    DailySpendingReportData reportData,
  ) async {
    await prepareLocale();
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

    final categoryBreakdown = reportData.categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final bytes = await _buildReportPdf(
      reportTitle: reportData.reportTitle,
      reportType: _tr('Daily spending report'),
      totalSpent: _formatAmount(reportData.totalSpent),
      selectedCategories: reportData.categories,
      period: _dateFmt.format(reportData.date),
      metrics: [
        _SummaryMetric(
          label: _tr('Transactions'),
          value: '${reportData.rows.length}',
        ),
        _SummaryMetric(
          label: _tr('Total spent'),
          value: _formatAmount(reportData.totalSpent),
        ),
        _SummaryMetric(
          label: _tr('Average transaction'),
          value: reportData.rows.isEmpty
              ? _formatAmount(0)
              : _formatAmount(reportData.totalSpent / reportData.rows.length),
        ),
      ],
      categoryBreakdown: [
        for (var i = 0; i < categoryBreakdown.length; i++)
          _CategoryBreakdownItem(
            label: categoryBreakdown[i].key,
            total: categoryBreakdown[i].value,
            rank: i + 1,
          ),
      ],
      categoryBreakdownTotalLabel: _tr('All categories total'),
      detailHeaders: [
        _tr('Time'),
        _tr('Source'),
        _tr('Description'),
        _tr('Category'),
        _tr('Bank'),
        _tr('Qty'),
        _tr('Amount'),
      ],
      detailRows: detailRows,
      detailFlex: const [1, 1.2, 2.7, 1.6, 1.3, 0.7, 1],
    );
    return bytes;
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

class _CategoryBreakdownItem {
  final String label;
  final double total;
  final int rank;

  const _CategoryBreakdownItem({
    required this.label,
    required this.total,
    required this.rank,
  });
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
