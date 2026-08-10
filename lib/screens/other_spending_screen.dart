import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../localization/language_constants.dart';
import '../providers/notification_center_provider.dart';
import '../providers/other_spending_provider.dart';
import '../providers/spending_provider.dart';
import '../widgets/home/home/notification_center_button.dart';
import '../widgets/home/other/other_category_card.dart';
import '../widgets/home/other/other_expandable_section_card.dart';
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
  String? _lastNotificationSyncToken;

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
    final spendingProvider = context.watch<SpendingProvider>();
    final text = Theme.of(context).textTheme;
    final fmt = DateFormat('yyyy-MM-dd');

    final syncToken = [
      spendingProvider.periodTotal.toStringAsFixed(2),
      provider.totalOtherSpending.toStringAsFixed(2),
      provider.uniqueEntries.length,
      provider.categoryTotals.length,
      provider.hasCustomFilter,
    ].join('|');
    if (_lastNotificationSyncToken != syncToken) {
      _lastNotificationSyncToken = syncToken;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<NotificationCenterProvider>().syncFromData(
          spending: spendingProvider,
          other: provider,
        );
      });
    }

    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(
              title: Text(getTranslated(context, 'Other spendings')),
            ),
            body: const OtherLoadingWidget(),
          );
        }

        final entries = provider.uniqueEntries;
        final categoryTotals = provider.categoryTotals;

        final Map<String, List<OtherSpendingEntry>> groupedByCategory = {};
        for (final entry in entries) {
          final key = (entry.category == null || entry.category!.trim().isEmpty)
              ? getTranslated(context, 'Uncategorized')
              : entry.category!.trim();
          groupedByCategory.putIfAbsent(key, () => []).add(entry);
        }

        final double overallTotal = groupedByCategory.values.fold(
          0,
          (prev, list) => prev + list.fold(0, (p, e) => p + e.amount),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(getTranslated(context, 'Other spendings')),
            actions: [
              const NotificationCenterButton(),
              IconButton(
                icon: const Icon(Icons.download_rounded),
                tooltip: getTranslated(context, 'Export other spendings'),
                onPressed: () =>
                    OtherSpendingSheets.showOtherExportSheet(context, provider),
              ),
            ],
          ),
          body: CustomScrollView(
            key: const PageStorageKey('other-spending-scroll'),
            physics: const BouncingScrollPhysics(
              decelerationRate: ScrollDecelerationRate.fast,
              parent: AlwaysScrollableScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              SliverPadding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 110 + MediaQuery.of(context).padding.bottom,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    OtherExpandableSectionCard(
                      title: getTranslated(context, 'Filters & total'),
                      subtitle: getTranslated(context, 'Choose a period'),
                      leadingIcon: Icons.filter_alt_outlined,
                      initiallyExpanded: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            getTranslated(context, 'Total (filtered)'),
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
                                label: Text(getTranslated(context, 'All')),
                                selected: !provider.hasCustomFilter,
                                onSelected: (_) => provider.clearFilter(),
                              ),
                              FilterChip(
                                label: Text(getTranslated(context, 'This month')),
                                selected: false,
                                onSelected: (_) => provider.filterThisMonth(),
                              ),
                              FilterChip(
                                label: Text(getTranslated(context, 'Custom')),
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
                    if (categoryTotals.isNotEmpty)
                      OtherExpandableSectionCard(
                        title: getTranslated(context, 'By category'),
                        subtitle: getTranslated(
                          context,
                          'Tap to expand / collapse',
                        ),
                        badgeText: '${categoryTotals.length}',
                        leadingIcon: Icons.category_outlined,
                        initiallyExpanded: false,
                        child: Column(
                          children: categoryTotals.entries.map((entry) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      entry.key,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: text.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    entry.value.toStringAsFixed(2),
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
                    OtherOverallTotalCard(total: overallTotal),
                    const SizedBox(height: 10),
                    if (groupedByCategory.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            getTranslated(context, 'No other spendings yet.'),
                          ),
                        ),
                      )
                    else
                      ...groupedByCategory.entries.map(
                        (entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: OtherCategoryCard(
                            category: entry.key,
                            entries: entry.value,
                            fmt: fmt,
                            onDeleteCategory: () async {
                              final confirm =
                                  await OtherSpendingSheets.confirmDeleteDialog(
                                    context,
                                    message: getTranslatedWithArgs(
                                      context,
                                      'Delete all entries under "{category}"? This cannot be undone.',
                                      {'category': entry.key},
                                    ),
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
                      ),
                  ]),
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              OtherSpendingSheets.showAddOrEditDialog(context, provider);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        );
      },
    );
  }
}
