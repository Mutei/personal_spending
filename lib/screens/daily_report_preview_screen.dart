import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/other_spending_provider.dart';
import '../providers/spending_provider.dart';
import '../services/export_service.dart';

class DailyReportPreviewScreen extends StatefulWidget {
  final DateTime date;

  const DailyReportPreviewScreen({super.key, required this.date});

  @override
  State<DailyReportPreviewScreen> createState() =>
      _DailyReportPreviewScreenState();
}

class _DailyReportPreviewScreenState extends State<DailyReportPreviewScreen> {
  late Future<_DailyReportPreviewState> _reportFuture;

  @override
  void initState() {
    super.initState();
    _reportFuture = _generateReport();
  }

  Future<_DailyReportPreviewState> _generateReport() async {
    final spendingProvider = context.read<SpendingProvider>();
    final otherProvider = context.read<OtherSpendingProvider>();
    final reportData = ExportService.instance.buildDailySpendingReportData(
      spendingProvider: spendingProvider,
      otherProvider: otherProvider,
      date: widget.date,
      includeOtherSpendings:
          spendingProvider.notificationPreferences.includeOtherSpending,
    );
    final file = await ExportService.instance.generateDailySpendingReportPdf(
      reportData,
    );
    return _DailyReportPreviewState(reportData: reportData, file: file);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final dateLabel = DateFormat('EEEE, MMMM d, yyyy').format(widget.date);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Report'),
        actions: [
          FutureBuilder<_DailyReportPreviewState>(
            future: _reportFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Save or share PDF',
                icon: const Icon(Icons.ios_share_rounded),
                onPressed: () async {
                  await ExportService.instance.shareGeneratedFile(
                    snapshot.data!.file,
                    text: 'Daily spending report PDF',
                  );
                },
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<_DailyReportPreviewState>(
        future: _reportFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to generate the daily report preview right now.',
                  style: text.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final report = snapshot.data!;
          final reportData = report.reportData;
          final totals = reportData.categoryTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reportData.reportTitle,
                        style: text.headlineSmall?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        dateLabel,
                        style: text.bodyMedium?.copyWith(
                          color: cs.onPrimary.withValues(alpha: 0.88),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Spent',
                              style: text.bodySmall?.copyWith(
                                color: cs.onPrimary.withValues(alpha: 0.9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${reportData.totalSpent.toStringAsFixed(2)} SAR',
                              style: text.headlineMedium?.copyWith(
                                color: cs.onPrimary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryStatCard(
                        label: 'Transactions',
                        value: '${reportData.rows.length}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryStatCard(
                        label: 'Categories',
                        value: '${reportData.categories.length}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category totals',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...totals.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Expanded(child: Text(entry.key)),
                                Text('${entry.value.toStringAsFixed(2)} SAR'),
                              ],
                            ),
                          ),
                        ),
                        const Divider(),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'All categories total',
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${reportData.totalSpent.toStringAsFixed(2)} SAR',
                              style: text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction preview',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...reportData.rows.map(
                          (row) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest.withValues(
                                  alpha: 0.45,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          row.description,
                                          style: text.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${row.amount.toStringAsFixed(2)} SAR',
                                        style: text.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${DateFormat('HH:mm').format(row.timestamp)} • ${row.source} • ${row.category}',
                                    style: text.bodySmall,
                                  ),
                                  if (row.bank.isNotEmpty ||
                                      row.qty != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Bank: ${row.bank.isEmpty ? 'N/A' : row.bank} • Qty: ${row.qty ?? 1}',
                                      style: text.bodySmall,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    await ExportService.instance.shareGeneratedFile(
                      report.file,
                      text: 'Daily spending report PDF',
                    );
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Save or Share PDF'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryStatCard extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryStatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: text.bodySmall),
            const SizedBox(height: 6),
            Text(
              value,
              style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyReportPreviewState {
  final DailySpendingReportData reportData;
  final File file;

  const _DailyReportPreviewState({
    required this.reportData,
    required this.file,
  });
}
