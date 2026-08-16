import 'package:flutter/material.dart';

import '../../../localization/language_constants.dart';
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
    final itemLabel = entry.item == null || entry.item!.isEmpty
        ? getTranslated(context, 'Spending')
        : entry.item!;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onEdit,
            child: Ink(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.58),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      entry.amount.toStringAsFixed(0),
                      style: text.titleSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          itemLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _MetaChip(
                              icon: Icons.payments_outlined,
                              label:
                                  '${getTranslated(context, 'Amount')}: ${entry.amount.toStringAsFixed(2)}',
                            ),
                            if (entry.category != null &&
                                entry.category!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _MetaChip(
                                icon: Icons.category_outlined,
                                label:
                                    '${getTranslated(context, 'Category')}: ${entry.category}',
                              ),
                            ],
                            if (entry.bank != null &&
                                entry.bank!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _MetaChip(
                                icon: Icons.account_balance_wallet_outlined,
                                label:
                                    '${getTranslated(context, 'Bank / card')}: ${entry.bank}',
                              ),
                            ],
                            if (entry.qty != null) ...[
                              const SizedBox(height: 8),
                              _MetaChip(
                                icon: Icons.confirmation_number_outlined,
                                label:
                                    '${getTranslated(context, 'Quantity')}: ${entry.qty}',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      _TileActionButton(
                        icon: Icons.edit_rounded,
                        tooltip: getTranslated(context, 'Edit'),
                        onPressed: onEdit,
                      ),
                      const SizedBox(height: 8),
                      _TileActionButton(
                        icon: Icons.delete_outline_rounded,
                        tooltip: getTranslated(context, 'Delete'),
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              softWrap: true,
              style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TileActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _TileActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.40),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 18, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
