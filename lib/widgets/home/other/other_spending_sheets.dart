import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../localization/language_constants.dart';
import '../../../providers/other_spending_provider.dart';
import '../../../sheets/home_sheets.dart';
import '../../../services/export_service.dart';

class OtherSpendingSheets {
  OtherSpendingSheets._();

  // ==================== EXPORT SHEET ====================
  static void showOtherExportSheet(
    BuildContext context,
    OtherSpendingProvider provider,
  ) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final categories = provider.categoryTotals.keys.toList()..sort();

    String scope = 'all';
    final selectedCategories = <String>{};

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getTranslated(context, 'Export other spendings'),
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      getTranslated(context, 'Choose what to export:'),
                      style: text.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'all',
                      groupValue: scope,
                      title: Text(getTranslated(context, 'All categories')),
                      onChanged: (v) {
                        setState(() {
                          scope = v!;
                          selectedCategories.clear();
                        });
                      },
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'category',
                      groupValue: scope,
                      title: Text(getTranslated(context, 'Specific category')),
                      onChanged: (v) {
                        setState(() => scope = v!);
                      },
                    ),
                    if (scope == 'category')
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  getTranslated(context, 'Categories'),
                                  style: text.bodyMedium,
                                ),
                                const Spacer(),
                                TextButton(
                                  onPressed: categories.isEmpty
                                      ? null
                                      : () {
                                          setState(() {
                                            selectedCategories
                                              ..clear()
                                              ..addAll(categories);
                                          });
                                        },
                                  child: Text(
                                    getTranslated(context, 'Select all'),
                                  ),
                                ),
                                TextButton(
                                  onPressed: selectedCategories.isEmpty
                                      ? null
                                      : () {
                                          setState(selectedCategories.clear);
                                        },
                                  child: Text(
                                    getTranslated(context, 'Clear all'),
                                  ),
                                ),
                              ],
                            ),
                            if (categories.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  getTranslated(
                                    context,
                                    'No categories available to export.',
                                  ),
                                  style: text.bodySmall,
                                ),
                              )
                            else ...[
                              Text(
                                selectedCategories.isEmpty
                                    ? getTranslated(
                                        context,
                                        'No categories selected',
                                      )
                                    : '${selectedCategories.length} selected: ${selectedCategories.join(', ')}',
                                style: text.bodySmall,
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: categories
                                    .map(
                                      (category) => FilterChip(
                                        label: Text(category),
                                        selected: selectedCategories.contains(
                                          category,
                                        ),
                                        onSelected: (selected) {
                                          setState(() {
                                            if (selected) {
                                              selectedCategories.add(category);
                                            } else {
                                              selectedCategories.remove(
                                                category,
                                              );
                                            }
                                          });
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final filters = scope == 'category'
                                  ? (selectedCategories.toList()..sort())
                                  : null;
                              if (scope == 'category' &&
                                  (filters == null || filters.isEmpty)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      getTranslated(
                                        context,
                                        'Please select at least one category first',
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }
                              try {
                                await ExportService.instance
                                    .exportOtherCsvAndShare(
                                      provider,
                                      categoryFilters: filters,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        getTranslated(
                                          context,
                                          'Other spendings exported as CSV',
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
                            icon: const Icon(Icons.table_view),
                            label: const Text('CSV'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final filters = scope == 'category'
                                  ? (selectedCategories.toList()..sort())
                                  : null;
                              if (scope == 'category' &&
                                  (filters == null || filters.isEmpty)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      getTranslated(
                                        context,
                                        'Please select at least one category first',
                                      ),
                                    ),
                                  ),
                                );
                                return;
                              }
                              try {
                                final defaultTitle = filters == null
                                    ? getTranslated(
                                        context,
                                        'Other Spending Report',
                                      )
                                    : filters.length == 1
                                    ? '${filters.first} ${getTranslated(context, 'Other Spending Report')}'
                                    : getTranslated(
                                        context,
                                        'Selected Categories Other Spending Report',
                                      );
                                final reportTitle =
                                    await HomeSheets.promptForReportTitle(
                                      context,
                                      initialTitle: defaultTitle,
                                    );
                                if (reportTitle == null || !context.mounted) {
                                  return;
                                }
                                await ExportService.instance
                                    .exportOtherPdfAndShare(
                                      provider,
                                      categoryFilters: filters,
                                      reportTitle: reportTitle,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        getTranslated(
                                          context,
                                          'Other spendings exported as PDF',
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
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('PDF'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ----------------- confirm delete dialog -----------------
  static Future<bool?> confirmDeleteDialog(
    BuildContext context, {
    String? message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(getTranslated(context, 'Delete')),
        content: Text(
          message ??
              getTranslated(
                context,
                'Are you sure you want to delete this entry?',
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(getTranslated(context, 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(getTranslated(context, 'Delete')),
          ),
        ],
      ),
    );
  }

  // ----------------- add/edit dialog -----------------
  static void showAddOrEditDialog(
    BuildContext context,
    OtherSpendingProvider provider, {
    OtherSpendingEntry? entry,
  }) {
    final amountController = TextEditingController(
      text: entry != null ? entry.amount.toString() : '',
    );
    final titleController = TextEditingController(text: entry?.title ?? '');
    final categoryController = TextEditingController(
      text: entry?.category ?? '',
    );
    final bankController = TextEditingController(text: entry?.bank ?? '');
    final qtyController = TextEditingController(
      text: entry?.qty != null ? '${entry!.qty}' : '',
    );
    DateTime selectedDate = entry?.date ?? DateTime.now();
    final dateFmt = DateFormat('yyyy-MM-dd');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry != null
                          ? getTranslated(context, 'Edit other spending')
                          : getTranslated(context, 'Add other spending'),
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${getTranslated(context, 'Date')}: ${dateFmt.format(selectedDate)}',
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              firstDate: DateTime(DateTime.now().year - 1),
                              lastDate: DateTime(DateTime.now().year + 1),
                              initialDate: selectedDate,
                            );
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: Text(getTranslated(context, 'Pick')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: getTranslated(context, 'Amount'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: getTranslated(context, 'Title (optional)'),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: InputDecoration(
                        labelText: getTranslated(
                          context,
                          'Category (e.g. Work, Parents)',
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bankController,
                      decoration: InputDecoration(
                        labelText: getTranslated(
                          context,
                          'Bank / card (optional)',
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: getTranslated(
                          context,
                          'Quantity (optional)',
                        ),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (entry != null)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Theme.of(
                                  ctx,
                                ).colorScheme.error,
                              ),
                              onPressed: () async {
                                final confirm = await confirmDeleteDialog(ctx);
                                if (confirm == true) {
                                  await provider.removeEntry(entry);
                                  if (!ctx.mounted) return;
                                  Navigator.pop(ctx);
                                }
                              },
                              icon: const Icon(Icons.delete),
                              label: Text(getTranslated(context, 'Delete')),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                final amount =
                                    double.tryParse(
                                      amountController.text.trim(),
                                    ) ??
                                    0;
                                if (amount <= 0) return;

                                final qty = qtyController.text.trim().isEmpty
                                    ? null
                                    : int.tryParse(qtyController.text.trim());

                                await provider.updateEntry(
                                  entry,
                                  date: selectedDate,
                                  amount: amount,
                                  title: titleController.text.trim().isEmpty
                                      ? null
                                      : titleController.text.trim(),
                                  category:
                                      categoryController.text.trim().isEmpty
                                      ? null
                                      : categoryController.text.trim(),
                                  bank: bankController.text.trim().isEmpty
                                      ? null
                                      : bankController.text.trim(),
                                  qty: qty,
                                );

                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.save),
                              label: Text(getTranslated(context, 'Save')),
                            ),
                          ),
                        ],
                      )
                    else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final amount =
                              double.tryParse(amountController.text.trim()) ??
                              0;
                          if (amount <= 0) return;

                          final qty = qtyController.text.trim().isEmpty
                              ? null
                              : int.tryParse(qtyController.text.trim());

                          await provider.addEntry(
                            date: selectedDate,
                            amount: amount,
                            title: titleController.text.trim().isEmpty
                                ? null
                                : titleController.text.trim(),
                            category: categoryController.text.trim().isEmpty
                                ? null
                                : categoryController.text.trim(),
                            bank: bankController.text.trim().isEmpty
                                ? null
                                : bankController.text.trim(),
                            qty: qty,
                          );

                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.save),
                        label: Text(getTranslated(context, 'Add')),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
