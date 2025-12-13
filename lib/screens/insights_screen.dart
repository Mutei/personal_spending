import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/spending_provider.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SpendingProvider>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final categoryTotals = provider.getCategoryTotalsForPeriod();
    final dailyTotals = provider.getDailyTotalsForPeriod();
    final recs = provider.getSmartRecommendations();

    // Build slices (sorted, with colors + percentages)
    final slices = _buildSlices(categoryTotals, cs);
    final totalSpending = categoryTotals.values.fold<double>(
      0,
      (p, e) => p + e,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Insights')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =============== CATEGORY DONUT ===============
            Text(
              "Spending by category",
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (categoryTotals.isEmpty)
              const Text("No data yet for this period.")
            else ...[
              Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: cs.shadow.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
                child: SizedBox(
                  height: 260,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(
                        PieChartData(
                          startDegreeOffset: -90,
                          sectionsSpace: 2,
                          centerSpaceRadius: 70,
                          sections: _buildPieSectionsFromSlices(slices),
                        ),
                      ),
                      // Center content (total)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 26,
                            color: cs.primary,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total',
                            style: text.bodySmall?.copyWith(
                              color:
                                  text.bodySmall?.color ?? cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            totalSpending.toStringAsFixed(2),
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Legend under the chart
              _buildLegend(slices, text, cs),
            ],

            const SizedBox(height: 24),

            // =============== DAILY BAR CHART ===============
            Text(
              "Daily spending",
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (dailyTotals.isEmpty)
              const Text("No daily records in this period.")
            else
              SizedBox(
                height: 240,
                child: BarChart(
                  BarChartData(
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipPadding: const EdgeInsets.all(8),
                        tooltipMargin: 8,
                        getTooltipColor: (group) =>
                            cs.surfaceVariant.withOpacity(0.95),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final idx = group.x.toInt();
                          final date = dailyTotals[idx].key;
                          final amount = rod.toY;
                          return BarTooltipItem(
                            '${DateFormat('MMMd').format(date)}\n'
                            '${amount.toStringAsFixed(1)}',
                            TextStyle(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    gridData: FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            final length = dailyTotals.length;

                            if (index < 0 || index >= length) {
                              return const SizedBox.shrink();
                            }

                            // show at most ~6 x labels
                            const maxLabels = 6;
                            int step = (length / maxLabels).ceil();
                            if (step < 1) step = 1;

                            final isFirst = index == 0;
                            final isLast = index == length - 1;
                            final shouldShow =
                                isFirst || isLast || index % step == 0;

                            if (!shouldShow) {
                              return const SizedBox.shrink();
                            }

                            final date = dailyTotals[index].key;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                DateFormat('MMMd').format(date),
                                style:
                                    (text.bodySmall ??
                                            const TextStyle(fontSize: 10))
                                        .copyWith(
                                          fontSize: 10,
                                          color:
                                              text.bodySmall?.color ??
                                              cs.onSurface,
                                        ),
                              ),
                            );
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    barGroups: List.generate(dailyTotals.length, (index) {
                      final amount = dailyTotals[index].value;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: amount,
                            borderRadius: BorderRadius.circular(4),
                            width: 14,
                            color: cs.primary,
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // =============== RECOMMENDATIONS ===============
            Text(
              "Recommendations",
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (recs.isEmpty)
              const Text("No recommendations yet for this period.")
            else
              for (final r in recs)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    r,
                    style: text.bodyMedium?.copyWith(
                      color: text.bodyMedium?.color ?? cs.onSurface,
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  // ---------- SLICE MODEL & HELPERS ----------

  List<_CategorySlice> _buildSlices(Map<String, double> data, ColorScheme cs) {
    if (data.isEmpty) return [];

    final total = data.values.fold<double>(0, (p, e) => p + e);
    if (total == 0) return [];

    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final colors = <Color>[
      cs.primary,
      cs.secondary,
      cs.tertiary ?? cs.primary.withOpacity(0.7),
      cs.error,
      cs.primaryContainer,
      cs.secondaryContainer,
      cs.tertiaryContainer ?? cs.secondary.withOpacity(0.7),
    ];

    const int maxLabeledSlices = 3; // only top 3 labeled inside chart

    final List<_CategorySlice> slices = [];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final pct = (e.value / total) * 100;
      final color = colors[i % colors.length];

      final showLabel = i < maxLabeledSlices && pct >= 5;

      slices.add(
        _CategorySlice(
          name: e.key,
          value: e.value,
          pct: pct,
          color: color,
          showLabel: showLabel,
        ),
      );
    }

    return slices;
  }

  List<PieChartSectionData> _buildPieSectionsFromSlices(
    List<_CategorySlice> slices,
  ) {
    if (slices.isEmpty) return [];

    return slices.map((s) {
      final title = s.showLabel
          ? "${s.name}\n${s.pct.toStringAsFixed(1)}%"
          : "";

      return PieChartSectionData(
        value: s.value,
        color: s.color,
        radius: 90,
        title: title,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
    }).toList();
  }

  Widget _buildLegend(
    List<_CategorySlice> slices,
    TextTheme text,
    ColorScheme cs,
  ) {
    if (slices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Categories",
          style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: slices.map((s) {
            return SizedBox(
              width: 170,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "${s.name} • ${s.value.toStringAsFixed(2)} "
                      "(${s.pct.toStringAsFixed(1)}%)",
                      style: text.bodySmall?.copyWith(
                        color: text.bodySmall?.color ?? cs.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// Private helper model
class _CategorySlice {
  final String name;
  final double value;
  final double pct;
  final Color color;
  final bool showLabel;

  _CategorySlice({
    required this.name,
    required this.value,
    required this.pct,
    required this.color,
    required this.showLabel,
  });
}
