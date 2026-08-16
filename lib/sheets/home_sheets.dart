import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../localization/language_constants.dart';
import '../providers/spending_provider.dart';
import '../services/export_service.dart';

class HomeSheets {
  HomeSheets._();

  static const String _noBankValue = '__no_bank__';
  static const String _legacyBankValue = '__legacy_bank__';

  static List<_EditableBankAccount> _buildEditableBankAccounts(
    List<BankAccount> accounts,
  ) {
    return accounts
        .map(
          (account) => _EditableBankAccount(
            id: account.id,
            name: account.name,
            balance: account.balance,
          ),
        )
        .toList();
  }

  static Future<String?> promptForReportTitle(
    BuildContext context, {
    required String initialTitle,
    String helperText = 'This title will appear in the PDF report header.',
  }) async {
    final controller = TextEditingController(text: initialTitle);
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: Text(getTranslated(dialogContext, 'Report title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    helperText,
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: getTranslated(dialogContext, 'Title'),
                      border: const OutlineInputBorder(),
                      errorText: errorText,
                    ),
                    onSubmitted: (_) {
                      final trimmed = controller.text.trim();
                      if (trimmed.isEmpty) {
                        setState(() {
                          errorText = getTranslated(
                            dialogContext,
                            'Please enter a report title',
                          );
                        });
                        return;
                      }
                      Navigator.pop(dialogContext, trimmed);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(getTranslated(dialogContext, 'Cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final trimmed = controller.text.trim();
                    if (trimmed.isEmpty) {
                      setState(() {
                        errorText = getTranslated(
                          dialogContext,
                          'Please enter a report title',
                        );
                      });
                      return;
                    }
                    Navigator.pop(dialogContext, trimmed);
                  },
                  child: Text(getTranslated(dialogContext, 'Continue')),
                ),
              ],
            );
          },
        );
      },
    );
  }

  static List<DropdownMenuItem<String>> _bankAccountDropdownItems(
    SpendingProvider provider, {
    String? legacyBank,
  }) {
    final items = <DropdownMenuItem<String>>[
      const DropdownMenuItem(
        value: _noBankValue,
        child: Text('No payment source'),
      ),
    ];

    if (legacyBank != null && legacyBank.trim().isNotEmpty) {
      final matched = provider.findBankAccountId(bankName: legacyBank);
      if (matched == null) {
        items.add(
          DropdownMenuItem(
            value: _legacyBankValue,
            child: Text('${legacyBank.trim()} (not saved)'),
          ),
        );
      }
    }

    items.addAll(
      provider.bankAccounts.map(
        (account) => DropdownMenuItem<String>(
          value: account.id,
          child: Text(
            '${account.name} - ${account.balance.toStringAsFixed(2)}',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );

    return items;
  }

  static Widget _bankAccountDropdown({
    required SpendingProvider provider,
    required String value,
    required ValueChanged<String?> onChanged,
    String? legacyBank,
    String label = 'Payment source (optional)',
  }) {
    final ids = provider.bankAccounts.map((account) => account.id).toSet();
    final hasLegacy =
        legacyBank != null &&
        legacyBank.trim().isNotEmpty &&
        provider.findBankAccountId(bankName: legacyBank) == null;
    final isKnownValue =
        (value == _legacyBankValue && hasLegacy) ||
        value == _noBankValue ||
        ids.contains(value);
    final resolvedValue = isKnownValue ? value : _noBankValue;

    return DropdownButtonFormField<String>(
      value: resolvedValue,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        helperText: provider.bankAccounts.isEmpty && !hasLegacy
            ? 'Add bank accounts from Set Budget to select one.'
            : null,
      ),
      items: _bankAccountDropdownItems(provider, legacyBank: legacyBank),
      onChanged: onChanged,
    );
  }

  static String? _bankAccountIdFromSelection(String value) {
    if (value == _noBankValue || value == _legacyBankValue) return null;
    return value;
  }

  static String? _bankNameFromSelection(
    SpendingProvider provider,
    String value, {
    String? legacyBank,
  }) {
    if (value == _legacyBankValue) {
      final trimmed = legacyBank?.trim();
      return trimmed == null || trimmed.isEmpty ? null : trimmed;
    }
    final accountId = _bankAccountIdFromSelection(value);
    return provider.bankNameForId(accountId);
  }

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
    final selectedCategories = <String>{};

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  MediaQuery.of(ctx).viewInsets.bottom + 16,
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
                          selectedCategories.clear();
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('Categories', style: text.bodyMedium),
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
                                  child: const Text('Select all'),
                                ),
                                TextButton(
                                  onPressed: selectedCategories.isEmpty
                                      ? null
                                      : () {
                                          setState(selectedCategories.clear);
                                        },
                                  child: const Text('Clear all'),
                                ),
                              ],
                            ),
                            if (categories.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'No categories available in the current period.',
                                  style: text.bodySmall,
                                ),
                              )
                            else ...[
                              Text(
                                selectedCategories.isEmpty
                                    ? 'No categories selected'
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

                    // ---- Buttons: CSV / PDF ----
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
                                  const SnackBar(
                                    content: Text(
                                      'Please select at least one category first',
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
                                      categoryFilters: filters,
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
                              final filters = scope == 'category'
                                  ? (selectedCategories.toList()..sort())
                                  : null;

                              if (scope == 'category' &&
                                  (filters == null || filters.isEmpty)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please select at least one category first',
                                    ),
                                  ),
                                );
                                return;
                              }

                              Navigator.pop(ctx);
                              try {
                                final defaultTitle = filters == null
                                    ? 'Spending Report'
                                    : filters.length == 1
                                    ? '${filters.first} Spending Report'
                                    : 'Selected Categories Spending Report';
                                final reportTitle = await promptForReportTitle(
                                  context,
                                  initialTitle: defaultTitle,
                                );
                                if (reportTitle == null || !context.mounted) {
                                  return;
                                }
                                await ExportService.instance
                                    .exportPersonalPdfAndShare(
                                      provider,
                                      categoryFilters: filters,
                                      reportTitle: reportTitle,
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

  // ---------------- Notification Preferences Sheet ----------------
  static void showNotificationPreferencesSheet(
    BuildContext context,
    SpendingProvider provider,
  ) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    var prefs = provider.notificationPreferences;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, sheetSetState) {
            final media = MediaQuery.of(ctx);
            return SafeArea(
              child: AnimatedPadding(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: media.size.height * 0.88,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                color: cs.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Notification preferences',
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Choose which details appear in your daily spending summary.',
                                    style: text.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Flexible(
                          child: ListView(
                            shrinkWrap: true,
                            children: [
                              _buildNotificationPreferenceTile(
                                context: ctx,
                                title: 'Daily spending summary',
                                subtitle:
                                    'Receive the scheduled daily push notification.',
                                value: prefs.dailySummaryEnabled,
                                onChanged: (value) {
                                  sheetSetState(() {
                                    prefs = prefs.copyWith(
                                      dailySummaryEnabled: value,
                                    );
                                  });
                                },
                              ),
                              _buildNotificationPreferenceTile(
                                context: ctx,
                                title: 'Budget context',
                                subtitle:
                                    'Include the budget used and remaining amount.',
                                value: prefs.includeBudgetContext,
                                enabled: prefs.dailySummaryEnabled,
                                onChanged: (value) {
                                  sheetSetState(() {
                                    prefs = prefs.copyWith(
                                      includeBudgetContext: value,
                                    );
                                  });
                                },
                              ),
                              _buildNotificationPreferenceTile(
                                context: ctx,
                                title: 'Bank balance context',
                                subtitle:
                                    'Include the total balance and the lowest account balance.',
                                value: prefs.includeBankContext,
                                enabled: prefs.dailySummaryEnabled,
                                onChanged: (value) {
                                  sheetSetState(() {
                                    prefs = prefs.copyWith(
                                      includeBankContext: value,
                                    );
                                  });
                                },
                              ),
                              _buildNotificationPreferenceTile(
                                context: ctx,
                                title: 'Other spending',
                                subtitle:
                                    'Include entries from the other spending section.',
                                value: prefs.includeOtherSpending,
                                enabled: prefs.dailySummaryEnabled,
                                onChanged: (value) {
                                  sheetSetState(() {
                                    prefs = prefs.copyWith(
                                      includeOtherSpending: value,
                                    );
                                  });
                                },
                              ),
                              _buildNotificationPreferenceTile(
                                context: ctx,
                                title: 'Empty-day reminders',
                                subtitle:
                                    'Notify you even when no spending was recorded.',
                                value: prefs.notifyWhenNoSpending,
                                enabled: prefs.dailySummaryEnabled,
                                onChanged: (value) {
                                  sheetSetState(() {
                                    prefs = prefs.copyWith(
                                      notifyWhenNoSpending: value,
                                    );
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () async {
                              await provider.setNotificationPreferences(prefs);
                              if (context.mounted) Navigator.pop(ctx);
                            },
                            icon: const Icon(Icons.save_rounded),
                            label: const Text(
                              'Save preferences',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildNotificationPreferenceTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled
              ? cs.surfaceContainerHighest.withValues(alpha: 0.35)
              : cs.surfaceContainerHighest.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: enabled
                ? cs.outlineVariant.withValues(alpha: 0.55)
                : cs.outlineVariant.withValues(alpha: 0.25),
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 14, 12, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: enabled ? null : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: text.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Semantics(
                label: title,
                toggled: value,
                child: Switch.adaptive(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- Set Budget Sheet ----------------
  static void showSetBudgetSheet(
    BuildContext context,
    SpendingProvider provider,
  ) {
    final formKey = GlobalKey<FormState>();
    final budgetController = TextEditingController(
      text: provider.monthlyBudget.toString(),
    );
    final editableBanks = _buildEditableBankAccounts(provider.bankAccounts);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        final text = Theme.of(ctx).textTheme;

        return StatefulBuilder(
          builder: (ctx, sheetSetState) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(ctx).unfocus(),
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                  ),
                  child: SingleChildScrollView(
                    child: Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 35,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Set Budget Amount",
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: budgetController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: "Enter budget amount for this period",
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final parsed =
                                  double.tryParse(value?.trim() ?? '') ?? 0;
                              if (parsed <= 0) {
                                return "Please enter a valid amount";
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "Bank accounts (${editableBanks.length}/20)",
                                  style: text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: editableBanks.length >= 20
                                    ? null
                                    : () {
                                        sheetSetState(() {
                                          editableBanks.add(
                                            _EditableBankAccount(
                                              id: BankAccount.newId(),
                                            ),
                                          );
                                        });
                                      },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text("Add bank"),
                              ),
                            ],
                          ),
                          if (editableBanks.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "Press and drag to reorder. Deleting one bank will not affect the others.",
                                style: text.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ReorderableListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              buildDefaultDragHandles: false,
                              itemCount: editableBanks.length,
                              proxyDecorator: (child, index, animation) {
                                return AnimatedBuilder(
                                  animation: animation,
                                  child: child,
                                  builder: (context, child) {
                                    final t = Curves.easeOut.transform(
                                      animation.value,
                                    );
                                    return Transform.scale(
                                      scale: 1 + (0.02 * t),
                                      child: Material(
                                        color: Colors.transparent,
                                        elevation: 6 * t,
                                        borderRadius: BorderRadius.circular(18),
                                        child: child,
                                      ),
                                    );
                                  },
                                );
                              },
                              onReorder: (oldIndex, newIndex) {
                                sheetSetState(() {
                                  if (newIndex > oldIndex) newIndex -= 1;
                                  final bank = editableBanks.removeAt(oldIndex);
                                  editableBanks.insert(newIndex, bank);
                                });
                              },
                              itemBuilder: (context, index) {
                                final bank = editableBanks[index];
                                return Padding(
                                  key: ValueKey(bank.id),
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    curve: Curves.easeOutCubic,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(18),
                                      border: Border.all(
                                        color: cs.outlineVariant,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                "Bank ${index + 1}",
                                                style: text.bodyMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: "Delete bank account",
                                              onPressed: () {
                                                sheetSetState(() {
                                                  final removed = editableBanks
                                                      .removeAt(index);
                                                  removed.dispose();
                                                });
                                              },
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                              ),
                                            ),
                                            ReorderableDragStartListener(
                                              index: index,
                                              child: const Padding(
                                                padding: EdgeInsets.all(8),
                                                child: Icon(
                                                  Icons.drag_handle_rounded,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: TextFormField(
                                                controller: bank.nameController,
                                                textInputAction:
                                                    TextInputAction.next,
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: "Bank name",
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.trim().isEmpty) {
                                                    return "Required";
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: TextFormField(
                                                controller:
                                                    bank.balanceController,
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                decoration:
                                                    const InputDecoration(
                                                      labelText: "Balance",
                                                      border:
                                                          OutlineInputBorder(),
                                                    ),
                                                validator: (value) {
                                                  final parsed =
                                                      double.tryParse(
                                                        value?.trim() ?? '',
                                                      );
                                                  if (parsed == null ||
                                                      parsed < 0) {
                                                    return "Invalid";
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ] else ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              child: Text(
                                "No bank accounts added yet. Use Add bank to create one.",
                                style: text.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
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
                              onPressed: () async {
                                if (!(formKey.currentState?.validate() ??
                                    false)) {
                                  return;
                                }

                                final names = <String>{};
                                final accounts = <BankAccount>[];
                                for (final bank in editableBanks) {
                                  final name = bank.nameController.text.trim();
                                  final key = name.toLowerCase();
                                  if (names.contains(key)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          "Duplicate bank account: $name",
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  names.add(key);
                                  accounts.add(
                                    BankAccount(
                                      id: bank.id,
                                      name: name,
                                      balance: double.parse(
                                        bank.balanceController.text.trim(),
                                      ),
                                    ),
                                  );
                                }

                                final value = double.parse(
                                  budgetController.text.trim(),
                                );
                                await provider.setMonthlyBudget(
                                  value,
                                  bankAccounts: accounts,
                                );
                                if (context.mounted) Navigator.pop(ctx);
                              },
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      budgetController.dispose();
      for (final bank in editableBanks) {
        bank.dispose();
      }
    });
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
    final qtyController = TextEditingController();
    final categoryController = TextEditingController();
    String bankSelection = _noBankValue;

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

            // ✅ IMPORTANT: options must be read INSIDE builder so it updates
            // after you add new categories.
            final allCategories = provider.getAllUsedCategories();

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
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue te) {
                        final q = te.text.trim().toLowerCase();
                        if (q.isEmpty) return const Iterable<String>.empty();

                        // startsWith first, then contains
                        final starts = allCategories.where(
                          (c) => c.toLowerCase().startsWith(q),
                        );
                        final contains = allCategories.where(
                          (c) =>
                              !c.toLowerCase().startsWith(q) &&
                              c.toLowerCase().contains(q),
                        );

                        return [...starts, ...contains].take(8);
                      },
                      displayStringForOption: (opt) => opt,
                      onSelected: (selection) {
                        categoryController.text = selection;
                        categoryController
                            .selection = TextSelection.fromPosition(
                          TextPosition(offset: categoryController.text.length),
                        );
                      },
                      fieldViewBuilder:
                          (context, textController, focusNode, onSubmit) {
                            // keep your controller as the single source of truth
                            if (textController.text !=
                                categoryController.text) {
                              textController.text = categoryController.text;
                              textController.selection =
                                  categoryController.selection;
                            }

                            textController.addListener(() {
                              if (categoryController.text !=
                                  textController.text) {
                                categoryController.text = textController.text;
                                categoryController.selection =
                                    textController.selection;
                              }
                            });

                            return TextField(
                              controller: textController,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                labelText: "Category (optional)",
                                hintText: "Start typing…",
                                border: OutlineInputBorder(),
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => onSubmit(),
                            );
                          },
                      optionsViewBuilder: (context, onSelected, options) {
                        final cs = Theme.of(context).colorScheme;
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 6,
                            borderRadius: BorderRadius.circular(12),
                            color: cs.surface,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 220,
                                maxWidth: 500,
                              ),
                              child: ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                shrinkWrap: true,
                                itemCount: options.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  color: cs.outlineVariant.withOpacity(0.35),
                                ),
                                itemBuilder: (context, index) {
                                  final opt = options.elementAt(index);
                                  return InkWell(
                                    onTap: () => onSelected(opt),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.search_rounded,
                                            size: 18,
                                            color: cs.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              opt,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
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

                    _bankAccountDropdown(
                      provider: provider,
                      value: bankSelection,
                      onChanged: (value) {
                        sheetSetState(() {
                          bankSelection = value ?? _noBankValue;
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // ✅ Quantity (empty => 1, 0 not allowed) – you said this works
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Quantity (optional) — default 1",
                        border: OutlineInputBorder(),
                      ),
                    ),

                    // ✅ Category AUTOCOMPLETE (YouTube-like suggestions)
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
                                final int qty =
                                    int.tryParse(qtyController.text.trim()) ??
                                    1;

                                provider.addSpendingForDate(
                                  selectedDate,
                                  amount,
                                  replace: false,
                                  item: itemController.text.trim().isEmpty
                                      ? null
                                      : itemController.text.trim(),
                                  bank: _bankNameFromSelection(
                                    provider,
                                    bankSelection,
                                  ),
                                  bankAccountId: _bankAccountIdFromSelection(
                                    bankSelection,
                                  ),
                                  qty: qty, // provider will force >= 1
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
                                final int qty =
                                    int.tryParse(qtyController.text.trim()) ??
                                    1;

                                provider.addSpendingForDate(
                                  selectedDate,
                                  amount,
                                  replace: true,
                                  item: itemController.text.trim().isEmpty
                                      ? null
                                      : itemController.text.trim(),
                                  bank: _bankNameFromSelection(
                                    provider,
                                    bankSelection,
                                  ),
                                  bankAccountId: _bankAccountIdFromSelection(
                                    bankSelection,
                                  ),
                                  qty: qty, // provider will force >= 1
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
    final dateFormat = DateFormat('yyyy-MM-dd');

    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final dayController = TextEditingController();
    final categoryController = TextEditingController();
    String bankSelection = _noBankValue;
    bool autoAdd = true;
    String? editingId;
    RecurringFrequency selectedFrequency = RecurringFrequency.monthly;
    DateTime selectedStartDate = DateTime.now();

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
            final isEditing = editingId != null;

            void resetForm() {
              sheetSetState(() {
                editingId = null;
                titleController.clear();
                amountController.clear();
                dayController.clear();
                categoryController.clear();
                bankSelection = _noBankValue;
                autoAdd = true;
                selectedFrequency = RecurringFrequency.monthly;
                selectedStartDate = DateTime.now();
              });
            }

            void populateForm(RecurringPayment payment) {
              sheetSetState(() {
                editingId = payment.id;
                titleController.text = payment.title;
                amountController.text = payment.amount.toStringAsFixed(2);
                dayController.text = '${payment.dayOfMonth}';
                categoryController.text = payment.category ?? '';
                bankSelection =
                    provider.findBankAccountId(
                      bankAccountId: payment.bankAccountId,
                      bankName: payment.bank,
                    ) ??
                    ((payment.bank != null && payment.bank!.trim().isNotEmpty)
                        ? _legacyBankValue
                        : _noBankValue);
                autoAdd = payment.autoAdd;
                selectedFrequency = payment.frequency;
                selectedStartDate = payment.startDate;
              });
            }

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
                            'Recurring payments',
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
                        'Create repeating payments like rent, subscriptions, and weekly transport. If auto-add is on, the app records the spending automatically when it becomes due.',
                        style: text.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (list.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Existing recurring payments',
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...list.map((payment) {
                        final due = provider.getNextDueDate(payment);
                        final dueStr = DateFormat('MMM d').format(due);
                        final frequencyLabel =
                            payment.frequency == RecurringFrequency.weekly
                            ? 'Weekly'
                            : 'Monthly';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.4,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      payment.title,
                                      style: text.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${payment.amount.toStringAsFixed(2)} SAR',
                                      style: text.bodySmall,
                                    ),
                                    Text(
                                      payment.frequency ==
                                              RecurringFrequency.weekly
                                          ? '$frequencyLabel - starts ${dateFormat.format(payment.startDate)} - next: $dueStr'
                                          : '$frequencyLabel - day ${payment.dayOfMonth} - next: $dueStr',
                                      style: text.bodySmall,
                                    ),
                                    if (payment.category != null &&
                                        payment.category!.trim().isNotEmpty)
                                      Text(
                                        'Category: ${payment.category}',
                                        style: text.bodySmall,
                                      ),
                                    if (payment.bank != null &&
                                        payment.bank!.trim().isNotEmpty)
                                      Text(
                                        'Payment source: ${payment.bank}',
                                        style: text.bodySmall,
                                      ),
                                    Text(
                                      payment.autoAdd
                                          ? 'Auto-add is enabled'
                                          : 'Auto-add is disabled',
                                      style: text.bodySmall?.copyWith(
                                        color: payment.autoAdd
                                            ? Colors.green
                                            : text.bodySmall?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Edit recurring payment',
                                onPressed: () => populateForm(payment),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 20,
                                ),
                                tooltip: 'Delete recurring payment',
                                onPressed: () async {
                                  await provider.removeRecurringPayment(
                                    payment.id,
                                  );
                                  if (editingId == payment.id) {
                                    resetForm();
                                  } else {
                                    sheetSetState(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isEditing
                            ? 'Edit recurring payment'
                            : 'Add new recurring payment',
                        style: text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title (e.g. Rent, Gym, Netflix)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<RecurringFrequency>(
                      key: ValueKey(selectedFrequency),
                      initialValue: selectedFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Repeat schedule',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: RecurringFrequency.monthly,
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                          value: RecurringFrequency.weekly,
                          child: Text('Weekly'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        sheetSetState(() {
                          selectedFrequency = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: selectedStartDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked == null) return;
                        sheetSetState(() {
                          selectedStartDate = picked;
                          if (selectedFrequency == RecurringFrequency.monthly &&
                              dayController.text.trim().isEmpty) {
                            dayController.text = '${picked.day}';
                          }
                        });
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Start date',
                          border: OutlineInputBorder(),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(dateFormat.format(selectedStartDate)),
                            ),
                            const Text('Change'),
                          ],
                        ),
                      ),
                    ),
                    if (selectedFrequency == RecurringFrequency.monthly) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: dayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Day of month (1-31)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Weekly payments repeat every 7 days starting from the selected start date.',
                          style: text.bodySmall,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextField(
                      controller: categoryController,
                      decoration: const InputDecoration(
                        labelText: 'Category (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _bankAccountDropdown(
                      provider: provider,
                      value: bankSelection,
                      onChanged: (value) {
                        sheetSetState(() {
                          bankSelection = value ?? _noBankValue;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-add spending on due day'),
                      value: autoAdd,
                      onChanged: (val) {
                        sheetSetState(() {
                          autoAdd = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (isEditing) ...[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: resetForm,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Cancel edit'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: ElevatedButton.icon(
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
                                  double.tryParse(
                                    amountController.text.trim(),
                                  ) ??
                                  0;
                              final parsedDay =
                                  int.tryParse(dayController.text.trim()) ?? 0;
                              final day =
                                  selectedFrequency ==
                                      RecurringFrequency.monthly
                                  ? parsedDay
                                  : selectedStartDate.day;
                              final invalidMonthlyDay =
                                  selectedFrequency ==
                                      RecurringFrequency.monthly &&
                                  (day < 1 || day > 31);

                              if (title.isEmpty ||
                                  amount <= 0 ||
                                  invalidMonthlyDay) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      selectedFrequency ==
                                              RecurringFrequency.monthly
                                          ? 'Please enter a valid title, amount, and day of month.'
                                          : 'Please enter a valid title and amount.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final category =
                                  categoryController.text.trim().isEmpty
                                  ? null
                                  : categoryController.text.trim();
                              final bank = _bankNameFromSelection(
                                provider,
                                bankSelection,
                              );
                              final bankAccountId = _bankAccountIdFromSelection(
                                bankSelection,
                              );

                              if (editingId == null) {
                                await provider.addRecurringPayment(
                                  title: title,
                                  amount: amount,
                                  dayOfMonth: day,
                                  frequency: selectedFrequency,
                                  startDate: selectedStartDate,
                                  category: category,
                                  bank: bank,
                                  bankAccountId: bankAccountId,
                                  autoAdd: autoAdd,
                                );
                              } else {
                                await provider.updateRecurringPayment(
                                  id: editingId!,
                                  title: title,
                                  amount: amount,
                                  dayOfMonth: day,
                                  frequency: selectedFrequency,
                                  startDate: selectedStartDate,
                                  category: category,
                                  bank: bank,
                                  bankAccountId: bankAccountId,
                                  autoAdd: autoAdd,
                                );
                              }

                              await provider.processRecurringPayments();
                              resetForm();
                            },
                            icon: Icon(
                              isEditing
                                  ? Icons.save_as_rounded
                                  : Icons.save_rounded,
                            ),
                            label: Text(
                              isEditing
                                  ? 'Update recurring payment'
                                  : 'Save recurring payment',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
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
    final qtyController = TextEditingController(
      text: entry.qty != null ? '${entry.qty}' : '',
    );
    final categoryController = TextEditingController(
      text: entry.category ?? '',
    );
    final dateFormat = DateFormat('yyyy-MM-dd');
    DateTime selectedDate = date;
    String bankSelection =
        provider.findBankAccountId(
          bankAccountId: entry.bankAccountId,
          bankName: entry.bank,
        ) ??
        ((entry.bank != null && entry.bank!.trim().isNotEmpty)
            ? _legacyBankValue
            : _noBankValue);

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
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
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
                        label: const Text("Change date"),
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
                    _bankAccountDropdown(
                      provider: provider,
                      value: bankSelection,
                      legacyBank: entry.bank,
                      onChanged: (value) {
                        sheetSetState(() {
                          bankSelection = value ?? _noBankValue;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Quantity (optional) — default 1",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // (You can also make category autocomplete here later if you want)
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
                      onPressed: () async {
                        final amount =
                            double.tryParse(amountController.text.trim()) ?? 0;
                        final qty = qtyController.text.trim().isEmpty
                            ? 1
                            : int.tryParse(qtyController.text.trim()) ?? 1;

                        if (amount >= 0) {
                          await provider.saveEditedEntryForDate(
                            originalDate: date,
                            newDate: selectedDate,
                            index: index,
                            amount: amount,
                            item: itemController.text.trim().isEmpty
                                ? null
                                : itemController.text.trim(),
                            bank: _bankNameFromSelection(
                              provider,
                              bankSelection,
                              legacyBank: entry.bank,
                            ),
                            bankAccountId: _bankAccountIdFromSelection(
                              bankSelection,
                            ),
                            qty: qty, // provider will force >= 1 anyway
                            category: categoryController.text.trim().isEmpty
                                ? null
                                : categoryController.text.trim(),
                          );
                          onDateChanged(selectedDate);
                          if (!ctx.mounted) return;
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

class _EditableBankAccount {
  _EditableBankAccount({required this.id, String name = '', double? balance})
    : nameController = TextEditingController(text: name),
      balanceController = TextEditingController(
        text: balance == null ? '' : balance.toString(),
      );

  final String id;
  final TextEditingController nameController;
  final TextEditingController balanceController;

  void dispose() {
    nameController.dispose();
    balanceController.dispose();
  }
}
