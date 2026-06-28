import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../providers/notification_center_provider.dart';
import '../providers/other_spending_provider.dart';
import '../providers/secure_values_lock_service.dart';
import '../providers/spending_provider.dart';
import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import 'category_details_screen.dart';
import '../widgets/home/home/home_section_card.dart';
import '../widgets/home/home/notification_center_button.dart';
import 'insights_screen.dart';

// Reused widgets & helpers
import '../widgets/home/home/home_main_drawer.dart';
import '../widgets/home/home/spending_entry_tile.dart';
import '../sheets/home_sheets.dart';

enum _CategorySortOption {
  highestSpending,
  lowestSpending,
  alphabeticalAsc,
  alphabeticalDesc,
  mostUsed,
  leastUsed,
}

class _CategoryInsight {
  final String name;
  final double total;
  final int usageCount;

  const _CategoryInsight({
    required this.name,
    required this.total,
    required this.usageCount,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ prevent calling attachUser repeatedly from build()
  String? _lastUid;
  _CategorySortOption _categorySortOption = _CategorySortOption.highestSpending;

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

    // ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ Attach SpendingProvider once per uid change
    final uid = context.read<AuthService>().currentUser?.uid;
    if (uid != _lastUid) {
      _lastUid = uid;
      context.read<SpendingProvider>().attachUser(uid);
    }

    // ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ Auto-process recurring payments (safe to call; provider should guard internally)
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

  Future<void> _openBudgetSheetWithAuthentication(
    BuildContext context,
    SpendingProvider provider,
  ) async {
    Navigator.pop(context);

    final authSucceeded = await context.read<AppLockService>().authenticate(
      localizedReason:
          'Authenticate to access and update your budget information',
      unlockSession: false,
    );

    if (!context.mounted) return;

    if (!authSucceeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication required to access Set budget'),
        ),
      );
      return;
    }

    HomeSheets.showSetBudgetSheet(context, provider);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SpendingProvider>();
    final otherProvider = context.watch<OtherSpendingProvider>();
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
    final categoryUsageCounts = provider.getCategoryUsageCountsForPeriod();
    final sortedCategoryInsights = _buildSortedCategoryInsights(
      categoryTotals,
      categoryUsageCounts,
    );
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
    final valuesLocked = context.watch<SecureValuesLockService>().isLocked;
    final bankAccounts = provider.bankAccounts;
    final bankBalanceTotal = provider.totalBankBalance;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<NotificationCenterProvider>().syncFromData(
        spending: provider,
        other: otherProvider,
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Tracker'),
        centerTitle: true,
        actions: const [NotificationCenterButton()],
      ),

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
            if (!context.mounted) return;
            if (!ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Auth failed - lock not enabled")),
              );
              return;
            }

            await lock.setEnabled(true);
            if (!context.mounted) return;
            lock.lockAgain();

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("App Lock Enabled")));
          } else {
            await lock.setEnabled(false);
            if (!context.mounted) return;

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("App Lock Disabled")));
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
          if (!provider.notificationPreferences.dailySummaryEnabled) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Daily summary notifications are disabled'),
              ),
            );
            return;
          }
          provider.sendDailySummaryNotification();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Daily summary notification sent')),
          );
        },
        onNotificationPreferences: () {
          Navigator.pop(context);
          HomeSheets.showNotificationPreferencesSheet(context, provider);
        },
        onSetBudget: () async {
          await _openBudgetSheetWithAuthentication(context, provider);
        },
        onManageRecurring: () {
          Navigator.pop(context);
          HomeSheets.showRecurringPaymentsSheet(context, provider);
        },
        onLogout: () async {
          Navigator.pop(context);
          context
              .read<AppLockService>()
              .lockAgain(); // ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ reset
          await context
              .read<AuthService>()
              .signOut(); // ÃƒÆ’Ã‚Â¢Ãƒâ€¦Ã¢â‚¬Å“ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ token removed in signOut
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
                              "Period: ${fmt.format(provider.periodStart!)} -> ${fmt.format(provider.periodEnd!)}",
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
                      children: [
                        Expanded(
                          child: _secureInfoColumn(
                            context,
                            title: 'Budget',
                            value: budget,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _secureInfoColumn(
                            context,
                            title: 'Spent',
                            value: periodTotal,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _secureInfoColumn(
                            context,
                            title: 'Remaining',
                            value: remaining,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              if (bankAccounts.isNotEmpty) ...[
                const SizedBox(height: 16),
                HomeSectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_balance_rounded, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Bank balances",
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            valuesLocked
                                ? "****"
                                : bankBalanceTotal.toStringAsFixed(2),
                            style: text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...bankAccounts.map(
                        (account) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  account.name,
                                  style: text.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                valuesLocked
                                    ? "****"
                                    : account.balance.toStringAsFixed(2),
                                style: text.bodyMedium?.copyWith(
                                  color: account.balance >= 0
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

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
                            ? "Based on your current pace, here's how this period may end:"
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
                            child: Text("- $m", style: text.bodySmall),
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
                                  "${p.title} - due $dueStr",
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
              const SizedBox(height: 12),
              HomeSectionCard(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 180),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Top categories",
                                style: text.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Tap a category to review, edit, delete, or export its transactions.",
                                style: text.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<_CategorySortOption>(
                          initialValue: _categorySortOption,
                          onSelected: (value) {
                            setState(() {
                              _categorySortOption = value;
                            });
                          },
                          itemBuilder: (context) => [
                            for (final option in _CategorySortOption.values)
                              PopupMenuItem(
                                value: option,
                                child: Text(_categorySortLabel(option)),
                              ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: cs.primary.withValues(alpha: 0.22),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.sort_rounded,
                                  size: 18,
                                  color: cs.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _categorySortLabel(_categorySortOption),
                                  style: text.bodyMedium?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.expand_more_rounded,
                                  size: 18,
                                  color: cs.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (sortedCategoryInsights.isEmpty)
                      Text(
                        "No categories yet.",
                        style: text.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (
                            var i = 0;
                            i < sortedCategoryInsights.length;
                            i++
                          )
                            _buildCategoryInsightCard(
                              context,
                              insight: sortedCategoryInsights[i],
                              rank: i + 1,
                              totalPeriodSpending: periodTotal,
                            ),
                        ],
                      ),
                  ],
                ),
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
                  child: Text("- $r"),
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

  List<_CategoryInsight> _buildSortedCategoryInsights(
    Map<String, double> categoryTotals,
    Map<String, int> usageCounts,
  ) {
    final items = categoryTotals.entries
        .map(
          (entry) => _CategoryInsight(
            name: entry.key,
            total: entry.value,
            usageCount: usageCounts[entry.key] ?? 0,
          ),
        )
        .toList();

    items.sort((a, b) {
      switch (_categorySortOption) {
        case _CategorySortOption.highestSpending:
          final byTotal = b.total.compareTo(a.total);
          return byTotal != 0 ? byTotal : a.name.compareTo(b.name);
        case _CategorySortOption.lowestSpending:
          final byTotal = a.total.compareTo(b.total);
          return byTotal != 0 ? byTotal : a.name.compareTo(b.name);
        case _CategorySortOption.alphabeticalAsc:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case _CategorySortOption.alphabeticalDesc:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case _CategorySortOption.mostUsed:
          final byCount = b.usageCount.compareTo(a.usageCount);
          return byCount != 0 ? byCount : b.total.compareTo(a.total);
        case _CategorySortOption.leastUsed:
          final byCount = a.usageCount.compareTo(b.usageCount);
          return byCount != 0 ? byCount : a.total.compareTo(b.total);
      }
    });

    return items;
  }

  String _categorySortLabel(_CategorySortOption option) {
    switch (option) {
      case _CategorySortOption.highestSpending:
        return 'Highest spending';
      case _CategorySortOption.lowestSpending:
        return 'Lowest spending';
      case _CategorySortOption.alphabeticalAsc:
        return 'Alphabetical A-Z';
      case _CategorySortOption.alphabeticalDesc:
        return 'Alphabetical Z-A';
      case _CategorySortOption.mostUsed:
        return 'Most used';
      case _CategorySortOption.leastUsed:
        return 'Least used';
    }
  }

  Widget _buildCategoryInsightCard(
    BuildContext context, {
    required _CategoryInsight insight,
    required int rank,
    required double totalPeriodSpending,
  }) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final share = totalPeriodSpending <= 0
        ? 0.0
        : (insight.total / totalPeriodSpending).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryDetailsScreen(category: insight.name),
              ),
            );
          },
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.10),
                  cs.secondary.withValues(alpha: 0.14),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: cs.primary.withValues(alpha: 0.10)),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$rank',
                        style: text.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            insight.name,
                            style: text.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _categoryMetaChip(
                                context,
                                icon: Icons.payments_outlined,
                                label:
                                    '${insight.total.toStringAsFixed(2)} spent',
                              ),
                              _categoryMetaChip(
                                context,
                                icon: Icons.repeat_rounded,
                                label: '${insight.usageCount} entries',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          minHeight: 9,
                          value: share,
                          backgroundColor: cs.onSurface.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${(share * 100).toStringAsFixed(0)}%',
                      style: text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoryMetaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: cs.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: text.bodySmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
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
      ).showSnackBar(const SnackBar(content: Text("Locked again")));
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
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            locked ? "****" : value.toStringAsFixed(2),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
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
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
