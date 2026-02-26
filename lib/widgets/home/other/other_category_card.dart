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

    final total = entries.fold(0.0, (p, e) => p + e.amount);
    final latest = entries.isEmpty
        ? null
        : (entries.map((e) => e.date).toList()..sort((a, b) => b.compareTo(a)))
              .first;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openDetails(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: cs.primary.withOpacity(0.12),
              child: Text(
                category.isNotEmpty ? category[0].toUpperCase() : '?',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entries.length} payments'
                    '${latest == null ? '' : ' • last ${fmt.format(latest)}'}',
                    style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  total.toStringAsFixed(2),
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        category,
                        style: text.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: "Delete category",
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDeleteCategory();
                      },
                      icon: Icon(Icons.delete_outline, color: cs.error),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: entries.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      return ListTile(
                        title: Text(
                          (e.title == null || e.title!.isEmpty)
                              ? '-'
                              : e.title!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(fmt.format(e.date)),
                        trailing: Text(
                          e.amount.toStringAsFixed(2),
                          style: text.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        onTap: () => onEditEntry(e),
                        onLongPress: () => onDeleteEntry(e),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
