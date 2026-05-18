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

    final slices = _buildSlices(categoryTotals, cs);
    final totalSpending = categoryTotals.values.fold<double>(
      0,
      (p, e) => p + e,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Insights'), centerTitle: false),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // =================== TOP SUMMARY CARD ===================
          _Card(
            cs: cs,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total spending",
                        style: text.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        totalSpending == 0
                            ? "0.00"
                            : totalSpending.toStringAsFixed(2),
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // =================== CATEGORY DONUT ===================
          _SectionTitle(title: "Spending by category", cs: cs, text: text),
          const SizedBox(height: 10),

          if (categoryTotals.isEmpty)
            _EmptyState(
              title: "No data yet",
              subtitle: "Add some spendings to see insights here.",
              cs: cs,
              text: text,
              icon: Icons.pie_chart_rounded,
            )
          else
            _Card(
              cs: cs,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Donut + center total
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final size = constraints.maxWidth;
                      final chartSize = size.clamp(220.0, 320.0);

                      return Center(
                        child: SizedBox(
                          height: chartSize,
                          width: chartSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  startDegreeOffset: -90,
                                  sectionsSpace: 3,
                                  centerSpaceRadius: 65,
                                  sections: _buildPieSectionsFromSlices(
                                    slices,
                                    text,
                                    cs,
                                  ),
                                ),
                              ),

                              /// Center content
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.insights_rounded,
                                    size: chartSize * 0.08,
                                    color: cs.primary,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Total",
                                    style: text.labelMedium?.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    totalSpending.toStringAsFixed(2),
                                    style: text.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.3,
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

                  const SizedBox(height: 10),

                  // Legend
                  Text(
                    "Categories",
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ...slices.map(
                    (s) => _LegendRow(slice: s, cs: cs, text: text),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 18),

          // =================== DAILY BAR CHART ===================
          _SectionTitle(title: "Daily spending", cs: cs, text: text),
          const SizedBox(height: 10),

          if (dailyTotals.isEmpty)
            _EmptyState(
              title: "No daily records",
              subtitle: "No spendings found in this period.",
              cs: cs,
              text: text,
              icon: Icons.bar_chart_rounded,
            )
          else
            _Card(
              cs: cs,
              child: SizedBox(
                height: 260,
                child: BarChart(
                  BarChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: _niceInterval(dailyTotals),
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: cs.outlineVariant.withOpacity(0.35),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          interval: _niceInterval(
                            dailyTotals,
                          ), // keep your interval logic
                          getTitlesWidget: (value, meta) {
                            final interval = _niceInterval(dailyTotals);

                            // ✅ show only clean ticks: 0, interval, 2*interval, ...
                            final isCleanTick =
                                (value % interval).abs() < 0.0001;

                            // ✅ hide 0 (optional)
                            if (value == 0) return const SizedBox.shrink();

                            // ✅ hide non-clean ticks (this stops the "extra number")
                            if (!isCleanTick) return const SizedBox.shrink();

                            // ✅ hide the very top label (often overlaps with border)
                            final maxY = meta.max;
                            if ((maxY - value) < interval * 0.35)
                              return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(right: 6.0),
                              child: Text(
                                value.toStringAsFixed(0),
                                style:
                                    (text.bodySmall ??
                                            const TextStyle(fontSize: 10))
                                        .copyWith(
                                          fontWeight: FontWeight.w600,
                                          color:
                                              text.bodySmall?.color ??
                                              cs.onSurfaceVariant,
                                        ),
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= dailyTotals.length) {
                              return const SizedBox.shrink();
                            }

                            // show max ~5 labels
                            const maxLabels = 5;
                            final step = (dailyTotals.length / maxLabels)
                                .ceil()
                                .clamp(1, 999);

                            final isFirst = index == 0;
                            final isLast = index == dailyTotals.length - 1;
                            final shouldShow =
                                isFirst || isLast || index % step == 0;

                            if (!shouldShow) return const SizedBox.shrink();

                            final date = dailyTotals[index].key;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                DateFormat('MMMd').format(date),
                                style: text.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        tooltipPadding: const EdgeInsets.all(10),
                        tooltipMargin: 10,
                        getTooltipColor: (group) => cs.surfaceContainerHighest,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final idx = group.x.toInt();
                          final date = dailyTotals[idx].key;
                          final amount = rod.toY;
                          return BarTooltipItem(
                            '${DateFormat('EEE, MMM d').format(date)}\n'
                            '${amount.toStringAsFixed(2)}',
                            TextStyle(
                              color: cs.onSurface,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          );
                        },
                      ),
                    ),
                    barGroups: List.generate(dailyTotals.length, (index) {
                      final amount = dailyTotals[index].value;
                      return BarChartGroupData(
                        x: index,
                        barRods: [
                          BarChartRodData(
                            toY: amount,
                            width: 14,
                            borderRadius: BorderRadius.circular(6),
                            color: cs.primary,
                            backDrawRodData: BackgroundBarChartRodData(
                              show: true,
                              toY: _maxY(dailyTotals),
                              color: cs.primary.withOpacity(0.10),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 18),

          // =================== RECOMMENDATIONS ===================
          _SectionTitle(title: "Recommendations", cs: cs, text: text),
          const SizedBox(height: 10),

          if (recs.isEmpty)
            _EmptyState(
              title: "No recommendations yet",
              subtitle: "Spend a bit more and I’ll suggest optimizations.",
              cs: cs,
              text: text,
              icon: Icons.lightbulb_rounded,
            )
          else
            ...recs.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _Card(
                  cs: cs,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: cs.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.lightbulb_rounded,
                          color: cs.onSecondaryContainer,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r,
                          style: text.bodyMedium?.copyWith(
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
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

  // ---------- SLICE MODEL & HELPERS ----------

  List<_CategorySlice> _buildSlices(Map<String, double> data, ColorScheme cs) {
    if (data.isEmpty) return [];
    final total = data.values.fold<double>(0, (p, e) => p + e);
    if (total == 0) return [];

    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Use scheme-based palette (works in light/dark)
    final colors = <Color>[
      cs.primary,
      cs.secondary,
      cs.tertiary,
      cs.error,
      cs.primaryContainer,
      cs.secondaryContainer,
      cs.tertiaryContainer,
    ];

    // Only show % labels inside donut for top slices and if not tiny
    const int maxLabeledSlices = 3;

    final List<_CategorySlice> slices = [];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final pct = (e.value / total) * 100;
      final color = colors[i % colors.length];
      final showLabel =
          i < maxLabeledSlices && pct >= 7; // stricter to avoid clutter

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
    TextTheme text,
    ColorScheme cs,
  ) {
    if (slices.isEmpty) return [];

    return slices.map((s) {
      // Don’t put long names inside the chart (fixes your first screenshot)
      final title = s.showLabel ? "${s.pct.toStringAsFixed(1)}%" : "";

      // Pick readable color for label
      final titleColor = _bestTextColorOn(s.color);

      return PieChartSectionData(
        value: s.value,
        color: s.color,
        radius: 80,
        title: title,
        titlePositionPercentageOffset: 0.62,
        titleStyle: TextStyle(
          color: titleColor,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      );
    }).toList();
  }

  double _maxY(List<MapEntry<DateTime, double>> dailyTotals) {
    double max = 0;
    for (final e in dailyTotals) {
      if (e.value > max) max = e.value;
    }
    // add headroom
    return (max * 1.15).clamp(10, 999999);
  }

  double _niceInterval(List<MapEntry<DateTime, double>> dailyTotals) {
    final max = _maxY(dailyTotals);
    // Basic “nice” step
    if (max <= 50) return 10;
    if (max <= 100) return 20;
    if (max <= 200) return 50;
    if (max <= 500) return 100;
    return 200;
  }

  Color _bestTextColorOn(Color bg) {
    // simple luminance check
    final l = bg.computeLuminance();
    return l > 0.5 ? Colors.black : Colors.white;
  }
}

// =================== UI HELPERS ===================

class _SectionTitle extends StatelessWidget {
  final String title;
  final ColorScheme cs;
  final TextTheme text;

  const _SectionTitle({
    required this.title,
    required this.cs,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: text.titleMedium?.copyWith(
        fontWeight: FontWeight.w900,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  final ColorScheme cs;
  final TextTheme text;
  final IconData icon;

  const _EmptyState({
    required this.title,
    required this.subtitle,
    required this.cs,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      cs: cs,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final ColorScheme cs;

  const _Card({required this.child, required this.cs});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.40)),
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: child,
    );
  }
}

class _LegendRow extends StatelessWidget {
  final _CategorySlice slice;
  final ColorScheme cs;
  final TextTheme text;

  const _LegendRow({required this.slice, required this.cs, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: slice.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              slice.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                slice.value.toStringAsFixed(2),
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                "${slice.pct.toStringAsFixed(1)}%",
                style: text.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
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
