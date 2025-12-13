import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../providers/other_spending_provider.dart';
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
    String? selectedCategory;

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Export other spendings',
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Choose what to export:', style: text.bodyMedium),
                  const SizedBox(height: 8),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'all',
                    groupValue: scope,
                    title: const Text('All categories'),
                    onChanged: (v) {
                      setState(() => scope = v!);
                    },
                  ),
                  RadioListTile<String>(
                    contentPadding: EdgeInsets.zero,
                    value: 'category',
                    groupValue: scope,
                    title: const Text('Specific category'),
                    onChanged: (v) {
                      setState(() => scope = v!);
                    },
                  ),
                  if (scope == 'category')
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 16),
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: categories
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c,
                                child: Text(c),
                              ),
                            )
                            .toList(),
                        value: selectedCategory,
                        onChanged: (v) {
                          setState(() => selectedCategory = v);
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final filter = (scope == 'category')
                                ? selectedCategory
                                : null;
                            if (scope == 'category' && filter == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please select a category first',
                                  ),
                                ),
                              );
                              return;
                            }
                            try {
                              await ExportService.instance
                                  .exportOtherCsvAndShare(
                                    provider,
                                    categoryFilter: filter,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Other spendings exported as CSV',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Export failed: $e')),
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
                            final filter = (scope == 'category')
                                ? selectedCategory
                                : null;
                            if (scope == 'category' && filter == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Please select a category first',
                                  ),
                                ),
                              );
                              return;
                            }
                            try {
                              await ExportService.instance
                                  .exportOtherPdfAndShare(
                                    provider,
                                    categoryFilter: filter,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Other spendings exported as PDF',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Export failed: $e')),
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
            );
          },
        );
      },
    );
  }

  // ----------------- confirm delete dialog -----------------
  static Future<bool?> confirmDeleteDialog(
    BuildContext context, {
    String message = 'Are you sure you want to delete this entry?',
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
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
                          ? "Edit other spending"
                          : "Add other spending",
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Text("Date: ${dateFmt.format(selectedDate)}"),
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
                          label: const Text("Pick"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Amount",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: "Title (optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: "Category (e.g. Work, Parents)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bankController,
                      decoration: const InputDecoration(
                        labelText: "Bank / card (optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Quantity (optional)",
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
                                  Navigator.pop(ctx);
                                }
                              },
                              icon: const Icon(Icons.delete),
                              label: const Text("Delete"),
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

                                Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.save),
                              label: const Text("Save"),
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

                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.save),
                        label: const Text("Add"),
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
