import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../providers/secure_values_lock_service.dart';
import '../providers/spending_provider.dart';
import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import '../services/export_service.dart';
import '../widgets/home/home/home_section_card.dart';
import 'insights_screen.dart';

// Reused widgets & helpers
import '../widgets/home/home/home_main_drawer.dart';
import '../widgets/home/home/spending_entry_tile.dart';
import '../sheets/home_sheets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // ✅ prevent calling attachUser repeatedly from build()
  String? _lastUid;

  DateTime _selectedDate = DateTime.now();
  final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SecureValuesLockService>().lock();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ✅ Attach SpendingProvider once per uid change
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid != _lastUid) {
      _lastUid = uid;
      context.read<SpendingProvider>().attachUser(uid);
    }

    // ✅ Auto-process recurring payments (safe to call; provider should guard internally)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SpendingProvider>().processRecurringForToday();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      context.read<SecureValuesLockService>().lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SpendingProvider>();
    final auth = context.watch<AuthService>();

    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fmt = DateFormat('yyyy-MM-dd');

    final double budget = provider.monthlyBudget;
    final double periodTotal = provider.periodTotal;
    final double remaining = (budget - periodTotal).clamp(0, double.infinity);
    final double percent = budget > 0
        ? (periodTotal / budget).clamp(0.0, 1.0)
        : 0.0;

    final double selectedDateTotal = provider.getSpendingForDate(_selectedDate);
    final entries = provider.getEntriesForDate(_selectedDate);

    final categoryTotals = provider.getCategoryTotalsForPeriod();
    final avgPerDay = provider.getAveragePerDayInPeriod();
    final recs = provider.getSmartRecommendations();

    // ---- Income / forecast / recurring ----
    final periodIncome = provider.periodIncomeTotal;
    final savingsRate = provider.savingsRatePercent;
    final projectedTotal = provider.getProjectedPeriodTotal();
    final projectedDiff = projectedTotal - budget;
    final daysLeftInPeriod = provider.getDaysLeftInPeriod();
    final forecastMessages = provider.getForecastMessages();
    final upcomingRecurring = provider.getUpcomingRecurringPayments();

    final user = auth.currentUser;
    final email = user?.email ?? 'Guest';
    final displayName = user?.displayName ?? 'User';
    final appLock = context.watch<AppLockService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Spending Tracker'), centerTitle: true),

      // ---------- CUSTOM DRAWER (REUSED WIDGET) ----------
      drawer: HomeMainDrawer(
        displayName: displayName,
        email: email,
        appLockEnabled: appLock.isEnabled,
        onToggleAppLock: () async {
          final lock = context.read<AppLockService>();
          final newValue = !lock.isEnabled;

          // close drawer first so context is clean
          Navigator.pop(context);

          if (newValue) {
            final ok = await lock.authenticate();
            if (!ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Auth failed - lock not enabled")),
              );
              return;
            }

            await lock.setEnabled(true);
            lock.lockAgain();

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("✅ App Lock Enabled")));
          } else {
            await lock.setEnabled(false);

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("❌ App Lock Disabled")),
            );
          }
        },

        onOpenInsights: () {
          Navigator.pop(context);
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const InsightsScreen()));
        },
        onExport: () {
          Navigator.pop(context);
          HomeSheets.showExportOptionsSheet(context, provider);
        },
        onSendDailySummary: () {
          Navigator.pop(context);
          provider.sendDailySummaryNotification();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Daily summary notification sent')),
          );
        },
        onSetBudget: () {
          Navigator.pop(context);
          HomeSheets.showSetBudgetSheet(context, provider);
        },
        onManageRecurring: () {
          Navigator.pop(context);
          HomeSheets.showRecurringPaymentsSheet(context, provider);
        },
        onLogout: () async {
          Navigator.pop(context);
          context.read<AppLockService>().lockAgain(); // ✅ reset
          await context
              .read<AuthService>()
              .signOut(); // ✅ token removed in signOut
        },
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ========= PERIOD SECTION =========
              HomeSectionCard(
                child: provider.hasPeriod
                    ? Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Period: ${fmt.format(provider.periodStart!)} → ${fmt.format(provider.periodEnd!)}",
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _pickCustomPeriod(context),
                            child: const Text("Change"),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Choose budget period",
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () =>
                                    provider.useCurrentMonthPeriod(),
                                child: const Text("Use this month"),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: () => _pickCustomPeriod(context),
                                child: const Text("Custom period"),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),

              const SizedBox(height: 16),

              // ========= DASHBOARD CARD =========
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withOpacity(0.9),
                      cs.secondary.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Period Overview',
                      style: text.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CircularPercentIndicator(
                      radius: 70,
                      lineWidth: 10,
                      percent: percent,
                      progressColor: Colors.amberAccent,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      center: Text(
                        '${(percent * 100).toStringAsFixed(0)}%',
                        style: text.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _secureInfoColumn(
                          context,
                          title: 'Budget',
                          value: budget,
                        ),
                        _secureInfoColumn(
                          context,
                          title: 'Spent',
                          value: periodTotal,
                        ),
                        _secureInfoColumn(
                          context,
                          title: 'Remaining',
                          value: remaining,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ========= FORECAST CARD =========
              if (provider.hasPeriod) ...[
                const SizedBox(height: 16),
                HomeSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.trending_up, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            "Forecast",
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        daysLeftInPeriod > 0
                            ? "Based on your current pace, here’s how this period may end:"
                            : "This period has ended or is about to end.",
                        style: text.bodySmall,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Projected total:",
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            projectedTotal.toStringAsFixed(2),
                            style: text.bodyMedium,
                          ),
                        ],
                      ),
                      if (budget > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Vs. budget:",
                              style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              projectedDiff >= 0
                                  ? "+${projectedDiff.toStringAsFixed(2)}"
                                  : "-${(-projectedDiff).toStringAsFixed(2)}",
                              style: text.bodyMedium?.copyWith(
                                color: projectedDiff > 0
                                    ? Colors.red
                                    : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (forecastMessages.isNotEmpty) ...[
                        const Divider(),
                        const SizedBox(height: 8),
                        ...forecastMessages.map(
                          (m) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text("• $m", style: text.bodySmall),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              // ========= INCOME VS EXPENSES CARD =========
              if (periodIncome > 0 || periodTotal > 0) ...[
                const SizedBox(height: 16),
                HomeSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.account_balance_wallet_rounded,
                            size: 22,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Income vs Expenses",
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Income this period:",
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            periodIncome.toStringAsFixed(2),
                            style: text.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Expenses this period:",
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            periodTotal.toStringAsFixed(2),
                            style: text.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Savings rate:",
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            "${savingsRate.toStringAsFixed(1)}%",
                            style: text.bodyMedium?.copyWith(
                              color: savingsRate >= 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              // ========= UPCOMING RECURRING =========
              if (upcomingRecurring.isNotEmpty) ...[
                const SizedBox(height: 16),
                HomeSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.event_repeat_rounded, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            "Upcoming recurring payments",
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...upcomingRecurring.take(3).map((p) {
                        final dueDate = provider.getNextDueDate(p);
                        final dueStr = DateFormat('MMM d').format(dueDate);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  "${p.title} • due $dueStr",
                                  style: text.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                p.amount.toStringAsFixed(2),
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 30),

              // ========= DATE PICKER + DATE SUMMARY =========
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous day',
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.subtract(
                          const Duration(days: 1),
                        );
                      });
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        "Spending for ${_dateFormat.format(_selectedDate)}",
                        style: text.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next day',
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.add(
                          const Duration(days: 1),
                        );
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_today_rounded),
                    tooltip: 'Pick date',
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(DateTime.now().year - 1),
                        lastDate: DateTime(DateTime.now().year + 1),
                        initialDate: _selectedDate,
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              HomeSectionCard(
                child: Text(
                  selectedDateTotal > 0
                      ? 'Total spent on this date: ${selectedDateTotal.toStringAsFixed(2)}'
                      : 'No spending recorded for this date.',
                  style: text.bodyMedium,
                ),
              ),

              const SizedBox(height: 16),

              // ========= ENTRIES LIST FOR THIS DATE =========
              Text(
                "Entries for this date",
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              if (entries.isEmpty)
                HomeSectionCard(
                  child: Text(
                    "No detailed entries for this date.",
                    style: text.bodyMedium,
                  ),
                )
              else
                Column(
                  children: [
                    for (int i = 0; i < entries.length; i++)
                      SpendingEntryTile(
                        entry: entries[i],
                        onEdit: () {
                          HomeSheets.showEditEntrySheet(
                            context: context,
                            date: _selectedDate,
                            index: i,
                            entry: entries[i],
                            onDateChanged: (newDate) {
                              setState(() {
                                _selectedDate = newDate;
                              });
                            },
                          );
                        },
                        onDelete: () {
                          context.read<SpendingProvider>().removeEntryForDate(
                            date: _selectedDate,
                            index: i,
                          );
                        },
                      ),
                  ],
                ),

              const SizedBox(height: 24),

              // ========= INSIGHTS =========
              Text(
                "Insights",
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                "Average per day in this period: ${avgPerDay.toStringAsFixed(2)}",
                style: text.bodyMedium,
              ),
              const SizedBox(height: 6),
              Text(
                "Top categories:",
                style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 6),
              if (categoryTotals.isEmpty)
                Text("No categories yet.", style: text.bodySmall)
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: categoryTotals.entries
                      .map(
                        (e) => Text(
                          "• ${e.key}: ${e.value.toStringAsFixed(2)}",
                          style: text.bodySmall,
                        ),
                      )
                      .toList(),
                ),

              const SizedBox(height: 24),

              // ========= RECOMMENDATIONS =========
              Text(
                "Recommendations",
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final r in recs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text("• $r"),
                ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),

      // ---------- MAIN ACTION SHEET (REUSED FUNCTION) ----------
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          HomeSheets.showMainActionSheet(
            context,
            initialDate: _selectedDate,
            onDateChanged: (newDate) {
              setState(() {
                _selectedDate = newDate;
              });
            },
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text("Add / Manage"),
      ),
    );
  }

  // ---------------- Period picker ----------------
  void _pickCustomPeriod(BuildContext context) async {
    final provider = context.read<SpendingProvider>();
    final initialStart = provider.periodStart ?? DateTime.now();
    final initialEnd = provider.periodEnd ?? DateTime.now();

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDateRange: DateTimeRange(start: initialStart, end: initialEnd),
    );

    if (range != null) {
      await provider.setBudgetPeriod(range.start, range.end);
    }
  }

  Widget _secureInfoColumn(
    BuildContext context, {
    required String title,
    required double value,
  }) {
    final secure = context.watch<SecureValuesLockService>();
    final locked = secure.isLocked;

    Future<void> _unlock() async {
      final ok = await context
          .read<SecureValuesLockService>()
          .unlockWithBiometrics();
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Unlock failed")));
      }
    }

    void _lockAgain() {
      context.read<SecureValuesLockService>().lock();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("🔒 Locked again")));
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        if (locked) {
          await _unlock(); // biometrics
        } else {
          _lockAgain(); // no biometrics
        }
      },
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            locked ? "••••" : value.toStringAsFixed(2),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            locked ? Icons.lock_rounded : Icons.lock_open_rounded,
            size: 16,
            color: Colors.white70,
          ),
          const SizedBox(height: 2),
          Text(
            locked ? "Tap to unlock" : "Tap to lock",
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
