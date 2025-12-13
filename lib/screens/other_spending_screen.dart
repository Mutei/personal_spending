import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/other_spending_provider.dart';
import '../widgets/home/home/home_section_card.dart';
import '../widgets/home/other/other_category_card.dart';
import '../widgets/home/other/other_loading_widget.dart';
import '../widgets/home/other/other_overall_total_card.dart';
import '../widgets/home/other/other_spending_sheets.dart';

class OtherSpendingScreen extends StatefulWidget {
  const OtherSpendingScreen({super.key});

  @override
  State<OtherSpendingScreen> createState() => _OtherSpendingScreenState();
}

class _OtherSpendingScreenState extends State<OtherSpendingScreen> {
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadDataOnce();
  }

  Future<void> _loadDataOnce() async {
    final provider = context.read<OtherSpendingProvider>();
    if (provider.entries.isEmpty) {
      await provider.loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OtherSpendingProvider>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fmt = DateFormat('yyyy-MM-dd');

    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Other spendings')),
            body: OtherLoadingWidget(),
          );
        }

        // IMPORTANT: use DE-DUPED entries here
        final entries = provider.uniqueEntries;
        final categoryTotals = provider.categoryTotals;

        // group by category
        final Map<String, List<OtherSpendingEntry>> groupedByCategory = {};
        for (final e in entries) {
          final key = (e.category == null || e.category!.trim().isEmpty)
              ? 'Uncategorized'
              : e.category!.trim();
          groupedByCategory.putIfAbsent(key, () => []).add(e);
        }

        // overall total across all groups
        final double overallTotal = groupedByCategory.values.fold(
          0,
          (prev, list) => prev + list.fold(0, (p, e) => p + e.amount),
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Other spendings'),
            actions: [
              IconButton(
                icon: const Icon(Icons.download_rounded),
                tooltip: 'Export other spendings',
                onPressed: () =>
                    OtherSpendingSheets.showOtherExportSheet(context, provider),
              ),
            ],
          ),
          body: Column(
            children: [
              // ------------ TOP CARD (filters + total) ------------
              Padding(
                padding: const EdgeInsets.all(16),
                child: HomeSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total (filtered)",
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        provider.totalOtherSpending.toStringAsFixed(2),
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text("All"),
                            selected: !provider.hasCustomFilter,
                            onSelected: (_) => provider.clearFilter(),
                          ),
                          FilterChip(
                            label: const Text("This month"),
                            selected: false,
                            onSelected: (_) => provider.filterThisMonth(),
                          ),
                          FilterChip(
                            label: const Text("Custom"),
                            selected: provider.hasCustomFilter,
                            onSelected: (_) async {
                              final range = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(DateTime.now().year - 1),
                                lastDate: DateTime(DateTime.now().year + 1),
                                initialDateRange: DateTimeRange(
                                  start: DateTime.now().subtract(
                                    const Duration(days: 7),
                                  ),
                                  end: DateTime.now(),
                                ),
                              );
                              if (range != null) {
                                provider.setCustomFilter(
                                  range.start,
                                  range.end,
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ------------ CATEGORY BREAKDOWN (summary) ------------
              if (categoryTotals.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: HomeSectionCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "By category",
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...categoryTotals.entries.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text(e.key)),
                                Text(e.value.toStringAsFixed(2)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 10),

              // ------------ GROUPED, PRINT-FRIENDLY LIST ------------
              Expanded(
                child: groupedByCategory.isEmpty
                    ? const Center(child: Text("No other spendings yet."))
                    : ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        children: [
                          OtherOverallTotalCard(total: overallTotal),
                          const SizedBox(height: 8),
                          ...groupedByCategory.entries.map(
                            (entry) => OtherCategoryCard(
                              category: entry.key,
                              entries: entry.value,
                              fmt: fmt,
                              onDeleteCategory: () async {
                                final confirm =
                                    await OtherSpendingSheets.confirmDeleteDialog(
                                      context,
                                      message:
                                          'Delete all entries under "${entry.key}"? This cannot be undone.',
                                    );
                                if (confirm == true) {
                                  await provider.removeCategory(entry.key);
                                }
                              },
                              onEditEntry: (e) {
                                OtherSpendingSheets.showAddOrEditDialog(
                                  context,
                                  provider,
                                  entry: e,
                                );
                              },
                              onDeleteEntry: (e) async {
                                final shouldDelete =
                                    await OtherSpendingSheets.confirmDeleteDialog(
                                      context,
                                    );
                                if (shouldDelete == true) {
                                  await provider.removeEntry(e);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              OtherSpendingSheets.showAddOrEditDialog(context, provider);
            },
            icon: const Icon(Icons.add),
            label: const Text("Add"),
          ),
        );
      },
    );
  }
}
