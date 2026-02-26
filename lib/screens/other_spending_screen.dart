import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/other_spending_provider.dart';
import '../widgets/home/other/other_category_card.dart';
import '../widgets/home/other/other_loading_widget.dart';
import '../widgets/home/other/other_overall_total_card.dart';
import '../widgets/home/other/other_spending_sheets.dart';
import '../widgets/home/other/other_expandable_section_card.dart';

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
    if (!provider.hasLoaded) {
      await provider.loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OtherSpendingProvider>();
    final text = Theme.of(context).textTheme;
    final fmt = DateFormat('yyyy-MM-dd');

    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Other spendings')),
            body: const OtherLoadingWidget(),
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

          // ✅ ONE scrollable parent so expansions never overflow
          body: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              // extra space so content won't be hidden behind FAB / bottom nav
              bottom: 110 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ------------ TOP CARD (filters + total) ------------
                OtherExpandableSectionCard(
                  title: "Filters & total",
                  subtitle: "Choose a period",
                  leadingIcon: Icons.filter_alt_outlined,
                  initiallyExpanded: true,
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
                        runSpacing: 8,
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

                const SizedBox(height: 12),

                // ------------ CATEGORY BREAKDOWN (summary) ------------
                if (categoryTotals.isNotEmpty)
                  OtherExpandableSectionCard(
                    title: "By category",
                    subtitle: "Tap to expand / collapse",
                    badgeText: "${categoryTotals.length}",
                    leadingIcon: Icons.category_outlined,
                    initiallyExpanded: false,
                    child: Column(
                      children: categoryTotals.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  e.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                e.value.toStringAsFixed(2),
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                const SizedBox(height: 12),

                // ------------ OVERALL TOTAL CARD ------------
                OtherOverallTotalCard(total: overallTotal),

                const SizedBox(height: 10),

                // ------------ GROUPED, PRINT-FRIENDLY LIST ------------
                if (groupedByCategory.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(child: Text("No other spendings yet.")),
                  )
                else
                  // ✅ this ListView is inside SingleChildScrollView, so make it non-scrollable
                  ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
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
              ],
            ),
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
