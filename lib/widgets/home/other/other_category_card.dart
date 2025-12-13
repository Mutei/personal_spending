import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../providers/other_spending_provider.dart';

class OtherCategoryCard extends StatelessWidget {
  final String category;
  final List<OtherSpendingEntry> entries;
  final DateFormat fmt;

  final VoidCallback onDeleteCategory;
  final void Function(OtherSpendingEntry entry) onEditEntry;
  final void Function(OtherSpendingEntry entry) onDeleteEntry;

  const OtherCategoryCard({
    super.key,
    required this.category,
    required this.entries,
    required this.fmt,
    required this.onDeleteCategory,
    required this.onEditEntry,
    required this.onDeleteEntry,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final double total = entries.fold(
      0,
      (previousValue, e) => previousValue + e.amount,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: cs.primary.withOpacity(0.12),
          child: Text(
            category.isNotEmpty ? category[0].toUpperCase() : '?',
            style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          category,
          style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Total: ${total.toStringAsFixed(2)} • ${entries.length} payments',
          style: text.bodySmall,
        ),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: Icon(Icons.delete_outline, color: cs.error),
              label: Text(
                'Delete category',
                style: text.bodySmall?.copyWith(
                  color: cs.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
              onPressed: onDeleteCategory,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Item',
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Text(
                  'Amount',
                  textAlign: TextAlign.right,
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Text(
                  'Date',
                  textAlign: TextAlign.right,
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(),
          ...entries.map(
            (e) => InkWell(
              onTap: () => onEditEntry(e),
              onLongPress: () => onDeleteEntry(e),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        (e.title == null || e.title!.isEmpty) ? '-' : e.title!,
                        style: text.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.amount.toStringAsFixed(2),
                        textAlign: TextAlign.right,
                        style: text.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        fmt.format(e.date),
                        textAlign: TextAlign.right,
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
