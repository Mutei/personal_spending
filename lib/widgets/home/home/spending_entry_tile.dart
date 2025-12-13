import 'package:flutter/material.dart';
import '../../../providers/spending_provider.dart';

class SpendingEntryTile extends StatelessWidget {
  final SpendingEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SpendingEntryTile({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: cs.primary.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.primary.withOpacity(0.15),
            child: Text(
              entry.amount.toStringAsFixed(0),
              style: TextStyle(
                color: cs.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.item == null || entry.item!.isEmpty
                      ? "Spending"
                      : entry.item!,
                  style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  "Amount: ${entry.amount.toStringAsFixed(2)}",
                  style: text.bodySmall,
                ),
                if (entry.category != null && entry.category!.isNotEmpty)
                  Text("Category: ${entry.category}", style: text.bodySmall),
                if (entry.bank != null && entry.bank!.isNotEmpty)
                  Text("Bank / card: ${entry.bank}", style: text.bodySmall),
                if (entry.qty != null)
                  Text("Quantity: ${entry.qty}", style: text.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit, size: 20),
                tooltip: "Edit",
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete, size: 20),
                tooltip: "Delete",
              ),
            ],
          ),
        ],
      ),
    );
  }
}
