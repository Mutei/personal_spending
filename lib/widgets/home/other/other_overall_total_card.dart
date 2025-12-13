import 'package:flutter/material.dart';

class OtherOverallTotalCard extends StatelessWidget {
  final double total;

  const OtherOverallTotalCard({super.key, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Total for all others: ${total.toStringAsFixed(2)}',
        style: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: cs.onPrimaryContainer,
        ),
      ),
    );
  }
}
