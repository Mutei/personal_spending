import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/spending_provider.dart';
import '../services/export_service.dart';

class HomeSheets {
  HomeSheets._();

  // ---------- Main Action Sheet (Add / Manage) ----------
  static void showMainActionSheet(
    BuildContext context, {
    required DateTime initialDate,
    required ValueChanged<DateTime> onDateChanged,
  }) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final provider = context.read<SpendingProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.add_rounded, size: 30),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Quick actions",
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.shopping_bag_rounded),
                  title: const Text("Add spending"),
                  onTap: () {
                    Navigator.pop(ctx);
                    showAddOrEditSpendingSheet(
                      context,
                      initialDate: initialDate,
                      onDateChanged: onDateChanged,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.attach_money_rounded),
                  title: const Text("Add income"),
                  onTap: () {
                    Navigator.pop(ctx);
                    showAddIncomeSheet(context, initialDate: initialDate);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_repeat_rounded),
                  title: const Text("Manage recurring payments"),
                  onTap: () {
                    Navigator.pop(ctx);
                    showRecurringPaymentsSheet(context, provider);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------- EXPORT OPTIONS SHEET ----------
  static void showExportOptionsSheet(
    BuildContext context,
    SpendingProvider provider,
  ) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Categories from current period
    final categories = provider.getCategoryTotalsForPeriod().keys.toList()
      ..sort();

    String scope = 'all'; // 'all' or 'category'
    String? selectedCategory; // chosen category when scope == 'category'

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 16.0,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.download_rounded, size: 32),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Export current period',
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose what and how to export:',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 16),

                    // ---- Scope: all vs specific category ----
                    Text('Scope', style: text.bodyMedium),
                    const SizedBox(height: 4),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'all',
                      groupValue: scope,
                      title: const Text('All categories'),
                      onChanged: (v) {
                        setState(() {
                          scope = v!;
                          selectedCategory = null;
                        });
                      },
                    ),
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: 'category',
                      groupValue: scope,
                      title: const Text('Specific category'),
                      onChanged: (v) {
                        setState(() {
                          scope = v!;
                        });
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
                            setState(() {
                              selectedCategory = v;
                            });
                          },
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ---- Buttons: CSV / PDF ----
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

                              Navigator.pop(ctx);
                              try {
                                await ExportService.instance
                                    .exportPersonalCsvAndShare(
                                      provider,
                                      categoryFilter: filter,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Personal spendings exported as CSV',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Export failed: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.table_chart_outlined),
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

                              Navigator.pop(ctx);
                              try {
                                await ExportService.instance
                                    .exportPersonalPdfAndShare(
                                      provider,
                                      categoryFilter: filter,
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Personal spendings exported as PDF',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Export failed: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('PDF'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------- Set Budget Sheet ----------------
  static void showSetBudgetSheet(
    BuildContext context,
    SpendingProvider provider,
  ) {
    final controller = TextEditingController(
      text: provider.monthlyBudget.toString(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ✅ important
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final text = Theme.of(ctx).textTheme;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(ctx).unfocus(), // ✅ dismiss keyboard
          child: SafeArea(
            child: Padding(
              // ✅ push content above keyboard
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
                    const Icon(Icons.account_balance_wallet_rounded, size: 35),
                    const SizedBox(height: 10),
                    Text(
                      "Set Budget Amount",
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => FocusScope.of(ctx).unfocus(),
                      decoration: const InputDecoration(
                        labelText: "Enter budget amount for this period",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.save_rounded),
                        label: const Text(
                          "Save budget",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          final value =
                              double.tryParse(controller.text.trim()) ?? 0;
                          if (value > 0) {
                            provider.setMonthlyBudget(value);
                            Navigator.pop(ctx);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter a valid amount"),
                              ),
                            );
                          }
                        },
                      ),
                    ),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------- Add / Edit Spending Sheet ----------------
  static void showAddOrEditSpendingSheet(
    BuildContext context, {
    required DateTime initialDate,
    required ValueChanged<DateTime> onDateChanged,
  }) {
    final provider = context.read<SpendingProvider>();
    final amountController = TextEditingController();
    final itemController = TextEditingController();
    final bankController = TextEditingController();
    final qtyController = TextEditingController();
    final categoryController = TextEditingController();
    DateTime selectedDate = initialDate;
    final dateFormat = DateFormat('yyyy-MM-dd');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, sheetSetState) {
            final currentForDate = provider.getSpendingForDate(selectedDate);

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
                    const Icon(Icons.attach_money_rounded, size: 35),
                    const SizedBox(height: 10),
                    Text(
                      "Add / Edit Spending",
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 20),

                    // date selector
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Date: ${dateFormat.format(selectedDate)}",
                            style: Theme.of(ctx).textTheme.bodyMedium,
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
                              sheetSetState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                          ),
                          label: const Text("Pick date"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Current total for this date: ${currentForDate.toStringAsFixed(2)}",
                        style: Theme.of(
                          ctx,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Amount",
                        hintText: "e.g. 45.75",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: itemController,
                      decoration: const InputDecoration(
                        labelText: "Item / what did you spend on (optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: bankController,
                      decoration: const InputDecoration(
                        labelText: "Bank / card used (optional)",
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: "Category (optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                ctx,
                              ).colorScheme.primaryContainer,
                              foregroundColor:
                                  Theme.of(ctx).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              final amount =
                                  double.tryParse(
                                    amountController.text.trim(),
                                  ) ??
                                  0;
                              if (amount > 0) {
                                provider.addSpendingForDate(
                                  selectedDate,
                                  amount,
                                  replace: false,
                                  item: itemController.text.trim().isEmpty
                                      ? null
                                      : itemController.text.trim(),
                                  bank: bankController.text.trim().isEmpty
                                      ? null
                                      : bankController.text.trim(),
                                  qty: qtyController.text.trim().isEmpty
                                      ? null
                                      : int.tryParse(qtyController.text.trim()),
                                  category:
                                      categoryController.text.trim().isEmpty
                                      ? null
                                      : categoryController.text.trim(),
                                );
                                onDateChanged(selectedDate);
                                Navigator.pop(ctx);
                              }
                            },
                            icon: const Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Add to this date",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(
                                ctx,
                              ).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: () {
                              final amount =
                                  double.tryParse(
                                    amountController.text.trim(),
                                  ) ??
                                  0;
                              if (amount >= 0) {
                                provider.addSpendingForDate(
                                  selectedDate,
                                  amount,
                                  replace: true,
                                  item: itemController.text.trim().isEmpty
                                      ? null
                                      : itemController.text.trim(),
                                  bank: bankController.text.trim().isEmpty
                                      ? null
                                      : bankController.text.trim(),
                                  qty: qtyController.text.trim().isEmpty
                                      ? null
                                      : int.tryParse(qtyController.text.trim()),
                                  category:
                                      categoryController.text.trim().isEmpty
                                      ? null
                                      : categoryController.text.trim(),
                                );
                                onDateChanged(selectedDate);
                                Navigator.pop(ctx);
                              }
                            },
                            icon: const Icon(Icons.save_rounded),
                            label: const Text(
                              "Replace this date",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
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

  // --------- ADD INCOME SHEET ----------
  static void showAddIncomeSheet(
    BuildContext context, {
    required DateTime initialDate,
  }) {
    final provider = context.read<SpendingProvider>();
    final amountController = TextEditingController();
    final sourceController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = initialDate;
    final dateFormat = DateFormat('yyyy-MM-dd');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, sheetSetState) {
            final currentIncomeForDate = provider.getIncomeForDate(
              selectedDate,
            );

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
                    const Icon(Icons.attach_money_rounded, size: 35),
                    const SizedBox(height: 10),
                    Text(
                      "Add Income",
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 20),

                    // date selector
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Date: ${dateFormat.format(selectedDate)}",
                            style: Theme.of(ctx).textTheme.bodyMedium,
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
                              sheetSetState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                          ),
                          label: const Text("Pick date"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Current income for this date: ${currentIncomeForDate.toStringAsFixed(2)}",
                        style: Theme.of(
                          ctx,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Amount",
                        hintText: "e.g. 5000.00",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: sourceController,
                      decoration: const InputDecoration(
                        labelText: "Source (e.g. Salary, Bonus)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      decoration: const InputDecoration(
                        labelText: "Note (optional)",
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(
                          ctx,
                        ).colorScheme.primaryContainer,
                        foregroundColor:
                            Theme.of(ctx).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final amount =
                            double.tryParse(amountController.text.trim()) ?? 0;
                        if (amount > 0) {
                          provider.addIncomeForDate(
                            selectedDate,
                            amount,
                            source: sourceController.text.trim().isEmpty
                                ? null
                                : sourceController.text.trim(),
                            note: noteController.text.trim().isEmpty
                                ? null
                                : noteController.text.trim(),
                          );
                          Navigator.pop(ctx);
                        }
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text(
                        "Add income",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
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

  // --------- RECURRING PAYMENTS SHEET ----------
  static void showRecurringPaymentsSheet(
    BuildContext context,
    SpendingProvider provider,
  ) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final dayController = TextEditingController();
    final categoryController = TextEditingController();
    final bankController = TextEditingController();
    bool autoAdd = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, sheetSetState) {
            final list = provider.recurringPayments;

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
                    Row(
                      children: [
                        const Icon(Icons.event_repeat_rounded, size: 28),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Recurring payments",
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Add monthly bills like rent, gym, subscriptions.\nIf auto-add is ON, the app will record it automatically on that day.",
                        style: text.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // existing
                    if (list.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Existing recurring payments",
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...list.map((p) {
                        final due = provider.getNextDueDate(p);
                        final dueStr = DateFormat(
                          'MMM d',
                        ).format(due); // e.g. Nov 1
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: cs.surfaceVariant.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      p.title,
                                      style: text.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "${p.amount.toStringAsFixed(2)} • day ${p.dayOfMonth} • next: $dueStr",
                                      style: text.bodySmall,
                                    ),
                                    if (p.autoAdd)
                                      Text(
                                        "Auto-add ON",
                                        style: text.bodySmall?.copyWith(
                                          color: Colors.green,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                onPressed: () async {
                                  await provider.removeRecurringPayment(p.id);
                                  sheetSetState(() {});
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 16),
                    ],

                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Add new recurring payment",
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: "Title (e.g. Rent, Gym, Netflix)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Amount",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dayController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Day of month (1–31)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: "Category (optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bankController,
                      decoration: const InputDecoration(
                        labelText: "Bank / card (optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Auto-add spending on due day"),
                      value: autoAdd,
                      onChanged: (val) {
                        sheetSetState(() {
                          autoAdd = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final title = titleController.text.trim();
                        final amount =
                            double.tryParse(amountController.text.trim()) ?? 0;
                        final day =
                            int.tryParse(dayController.text.trim()) ?? 0;

                        if (title.isEmpty || amount <= 0 || day <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please enter valid title, amount & day of month',
                              ),
                            ),
                          );
                          return;
                        }

                        await provider.addRecurringPayment(
                          title: title,
                          amount: amount,
                          dayOfMonth: day,
                          category: categoryController.text.trim().isEmpty
                              ? null
                              : categoryController.text.trim(),
                          bank: bankController.text.trim().isEmpty
                              ? null
                              : bankController.text.trim(),
                          autoAdd: autoAdd,
                        );
                        sheetSetState(() {
                          titleController.clear();
                          amountController.clear();
                          dayController.clear();
                          categoryController.clear();
                          bankController.clear();
                          autoAdd = true;
                        });
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text(
                        "Save recurring payment",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
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

  // ------------- edit existing entry sheet -------------
  static void showEditEntrySheet({
    required BuildContext context,
    required DateTime date,
    required int index,
    required SpendingEntry entry,
    required ValueChanged<DateTime> onDateChanged,
  }) {
    final provider = context.read<SpendingProvider>();
    final amountController = TextEditingController(
      text: entry.qty != null && entry.qty! > 0
          ? (entry.amount / entry.qty!).toString()
          : entry.amount.toString(),
    );
    final itemController = TextEditingController(text: entry.item ?? '');
    final bankController = TextEditingController(text: entry.bank ?? '');
    final qtyController = TextEditingController(
      text: entry.qty != null ? '${entry.qty}' : '',
    );
    final categoryController = TextEditingController(
      text: entry.category ?? '',
    );
    final dateFormat = DateFormat('yyyy-MM-dd');
    DateTime selectedDate = date;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, sheetSetState) {
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
                    const Icon(Icons.edit, size: 35),
                    const SizedBox(height: 10),
                    Text(
                      "Edit Entry",
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Date: ${dateFormat.format(selectedDate)}",
                        style: Theme.of(ctx).textTheme.bodyMedium,
                      ),
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
                      controller: itemController,
                      decoration: const InputDecoration(
                        labelText: "Item (optional)",
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: "Category (optional)",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final amount =
                            double.tryParse(amountController.text.trim()) ?? 0;
                        final qty = qtyController.text.trim().isEmpty
                            ? null
                            : int.tryParse(qtyController.text.trim());
                        if (amount >= 0) {
                          provider.updateEntryForDate(
                            date: selectedDate,
                            index: index,
                            amount: amount,
                            item: itemController.text.trim().isEmpty
                                ? null
                                : itemController.text.trim(),
                            bank: bankController.text.trim().isEmpty
                                ? null
                                : bankController.text.trim(),
                            qty: qty,
                            category: categoryController.text.trim().isEmpty
                                ? null
                                : categoryController.text.trim(),
                          );
                          onDateChanged(selectedDate);
                          Navigator.pop(ctx);
                        }
                      },
                      icon: const Icon(Icons.save_rounded),
                      label: const Text("Save changes"),
                    ),
                    const SizedBox(height: 10),
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
