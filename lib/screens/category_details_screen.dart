import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../localization/language_constants.dart';
import '../providers/spending_provider.dart';
import '../services/export_service.dart';
import '../sheets/home_sheets.dart';
import '../widgets/home/home/home_section_card.dart';

class CategoryDetailsScreen extends StatelessWidget {
  final String category;

  const CategoryDetailsScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SpendingProvider>();
    final records = provider.getCategoryRecords(category);
    final totalSpent = records.fold<double>(
      0,
      (sum, record) => sum + record.entry.amount,
    );
    final averageSpent = records.isEmpty ? 0.0 : totalSpent / records.length;
    final latestDate = records.isEmpty ? null : records.first.date;
    final earliestDate = records.isEmpty ? null : records.last.date;
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(category),
        actions: [
          IconButton(
            tooltip: getTranslated(context, 'Export PDF'),
            onPressed: records.isEmpty
                ? null
                : () async {
                    try {
                      final reportTitle = await HomeSheets.promptForReportTitle(
                        context,
                        initialTitle: '$category Spending Report',
                        helperText: getTranslated(
                          context,
                          'This custom title will be shown prominently in the exported PDF.',
                        ),
                      );
                      if (reportTitle == null || !context.mounted) {
                        return;
                      }
                      await ExportService.instance.exportCategoryPdfAndShare(
                        provider,
                        category: category,
                        reportTitle: reportTitle,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              getTranslated(
                                context,
                                'Category report exported as PDF',
                              ),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              getTranslatedWithArgs(
                                context,
                                'Export failed: {error}',
                                {'error': '$e'},
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  },
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: records.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 54,
                        color: cs.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        getTranslated(
                          context,
                          'No spending records remain in this category.',
                        ),
                        textAlign: TextAlign.center,
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  HomeSectionCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _MetricChip(
                              label: getTranslated(context, 'Transactions'),
                              value: '${records.length}',
                              icon: Icons.receipt_long_rounded,
                            ),
                            _MetricChip(
                              label: getTranslated(context, 'Total spent'),
                              value: totalSpent.toStringAsFixed(2),
                              icon: Icons.account_balance_wallet_rounded,
                            ),
                            _MetricChip(
                              label: getTranslated(context, 'Average'),
                              value: averageSpent.toStringAsFixed(2),
                              icon: Icons.bar_chart_rounded,
                            ),
                          ],
                        ),
                        if (earliestDate != null && latestDate != null) ...[
                          const SizedBox(height: 14),
                          Text(
                            '${getTranslated(context, 'History')}: ${DateFormat.yMMMd().format(earliestDate)} - ${DateFormat.yMMMd().format(latestDate)}',
                            style: text.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Icon(Icons.history_rounded, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          getTranslated(context, 'Spending history'),
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final record in records)
                    _CategoryRecordCard(record: record, category: category),
                ],
              ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: cs.primary, size: 18),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRecordCard extends StatelessWidget {
  final CategorySpendingRecord record;
  final String category;

  const _CategoryRecordCard({required this.record, required this.category});

  @override
  Widget build(BuildContext context) {
    final entry = record.entry;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final title = entry.item?.trim().isNotEmpty == true
        ? entry.item!.trim()
        : getTranslated(context, 'Spending');
    final subtitleParts = <String>[
      DateFormat.yMMMd().format(record.date),
      if (entry.bank?.trim().isNotEmpty == true) entry.bank!.trim(),
      if (entry.qty != null && entry.qty! > 1)
        '${getTranslated(context, 'Qty')} ${entry.qty}',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.05),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            cs.primary.withValues(alpha: 0.95),
                            cs.secondary.withValues(alpha: 0.85),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(
                        Icons.category_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            subtitleParts.join(' - '),
                            style: text.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      entry.amount.toStringAsFixed(2),
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          HomeSheets.showEditEntrySheet(
                            context: context,
                            date: record.date,
                            index: record.index,
                            entry: record.entry,
                            onDateChanged: (_) {},
                          );
                        },
                        icon: const Icon(Icons.edit_rounded),
                        label: Text(getTranslated(context, 'Edit')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final shouldDelete = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                title: Text(
                                  getTranslated(context, 'Delete entry?'),
                                ),
                                content: Text(
                                  getTranslatedWithArgs(
                                    context,
                                    'Remove this spending record from {category}?',
                                    {'category': category},
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(dialogContext, false);
                                    },
                                    child: Text(
                                      getTranslated(context, 'Cancel'),
                                    ),
                                  ),
                                  FilledButton(
                                    onPressed: () {
                                      Navigator.pop(dialogContext, true);
                                    },
                                    child: Text(
                                      getTranslated(context, 'Delete'),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );

                          if (shouldDelete != true || !context.mounted) return;

                          await context
                              .read<SpendingProvider>()
                              .removeEntryForDate(
                                date: record.date,
                                index: record.index,
                              );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  getTranslated(
                                    context,
                                    'Entry deleted successfully',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: cs.error,
                        ),
                        label: Text(
                          getTranslated(context, 'Delete'),
                          style: TextStyle(color: cs.error),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
