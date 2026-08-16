import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';

import '../localization/language_constants.dart';
import '../providers/notification_center_provider.dart';
import '../providers/other_spending_provider.dart';
import '../providers/secure_values_lock_service.dart';
import '../providers/spending_provider.dart';
import '../services/app_lock_service.dart';
import '../services/auth_service.dart';
import 'category_details_screen.dart';
import 'financial_assistant_screen.dart';
import '../widgets/home/home/home_section_card.dart';
import '../widgets/home/home/notification_center_button.dart';
import 'insights_screen.dart';

// Reused widgets & helpers
import '../widgets/home/home/home_main_drawer.dart';
import '../widgets/home/home/spending_entry_tile.dart';
import '../widgets/show_language_dialog.dart';
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
  String? _lastNotificationSyncToken;
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
    if (state == AppLifecycleState.resumed) {
      context.read<SpendingProvider>().processRecurringPayments();
      return;
    }

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
      localizedReason: getTranslated(
        context,
        'Authenticate to access and update your budget information',
      ),
      unlockSession: false,
    );

    if (!context.mounted) return;

    if (!authSucceeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            getTranslated(
              context,
              'Authentication required to access Set budget',
            ),
          ),
        ),
      );
      return;
    }

    HomeSheets.showSetBudgetSheet(context, provider);
  }

  Future<void> _openFinancialAssistant(BuildContext context) async {
    Navigator.pop(context);

    final authSucceeded = await context.read<AppLockService>().authenticate(
      localizedReason: getTranslated(
        context,
        'Authenticate to open the Financial Assistant',
      ),
      unlockSession: false,
    );

    if (!context.mounted) return;

    if (!authSucceeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            getTranslated(
              context,
              'Authentication required to access the Financial Assistant',
            ),
          ),
        ),
      );
      return;
    }

    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const FinancialAssistantScreen()));
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
    final email = user?.email ?? getTranslated(context, 'Guest');
    final displayName = user?.displayName ?? getTranslated(context, 'User');
    final appLock = context.watch<AppLockService>();
    final valuesLocked = context.watch<SecureValuesLockService>().isLocked;
    final bankAccounts = provider.bankAccounts;
    final bankBalanceTotal = provider.totalBankBalance;

    final syncToken = [
      provider.periodTotal.toStringAsFixed(2),
      provider.periodIncomeTotal.toStringAsFixed(2),
      provider.totalBankBalance.toStringAsFixed(2),
      provider.bankAccounts.length,
      provider.getEntriesForDate(_selectedDate).length,
      otherProvider.totalOtherSpending.toStringAsFixed(2),
      otherProvider.uniqueEntries.length,
      _dateFormat.format(_selectedDate),
    ].join('|');
    if (_lastNotificationSyncToken != syncToken) {
      _lastNotificationSyncToken = syncToken;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<NotificationCenterProvider>().syncFromData(
          spending: provider,
          other: otherProvider,
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(getTranslated(context, 'Spending Tracker')),
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
                SnackBar(
                  content: Text(
                    getTranslated(context, 'Auth failed - lock not enabled'),
                  ),
                ),
              );
              return;
            }

            await lock.setEnabled(true);
            if (!context.mounted) return;
            lock.lockAgain();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(getTranslated(context, 'App Lock Enabled')),
              ),
            );
          } else {
            await lock.setEnabled(false);
            if (!context.mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(getTranslated(context, 'App Lock Disabled')),
              ),
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
        onSendTestNotifications: () async {
          Navigator.pop(context);
          final sent = await context
              .read<NotificationCenterProvider>()
              .sendTestSpendingNotifications(
                spending: provider,
                other: otherProvider,
              );
          if (!context.mounted) return;

          final message = sent.isEmpty
              ? getTranslated(
                  context,
                  'No spending notifications are available to send right now',
                )
              : getTranslatedWithArgs(
                  context,
                  sent.length == 1
                      ? 'Sent {items} notification'
                      : 'Sent {items} notifications',
                  {'items': sent.join(' and ')},
                );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
        onNotificationPreferences: () {
          Navigator.pop(context);
          HomeSheets.showNotificationPreferencesSheet(context, provider);
        },
        onOpenFinancialAssistant: () async {
          await _openFinancialAssistant(context);
        },
        onSetBudget: () async {
          await _openBudgetSheetWithAuthentication(context, provider);
        },
        onManageRecurring: () {
          Navigator.pop(context);
          HomeSheets.showRecurringPaymentsSheet(context, provider);
        },
        onLanguage: () {
          Navigator.pop(context);
          showLanguageDialog(context);
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
        child: ListView(
          key: const PageStorageKey('home-screen-scroll'),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            110 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              child: HomeSectionCard(
                key: ValueKey(provider.hasPeriod),
                child: provider.hasPeriod
                    ? Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  getTranslated(context, 'Period'),
                                  style: text.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${fmt.format(provider.periodStart!)} -> ${fmt.format(provider.periodEnd!)}',
                                  style: text.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => _pickCustomPeriod(context),
                            child: Text(getTranslated(context, 'Change')),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            getTranslated(context, 'Choose budget period'),
                            style: text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Set the range you want the dashboard to analyze and track.',
                            style: text.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              ElevatedButton(
                                onPressed: () =>
                                    provider.useCurrentMonthPeriod(),
                                child: Text(
                                  getTranslated(context, 'Use this month'),
                                ),
                              ),
                              OutlinedButton(
                                onPressed: () => _pickCustomPeriod(context),
                                child: Text(
                                  getTranslated(context, 'Custom period'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 16),
            HomeSectionCard(
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.support_agent_rounded,
                      color: cs.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Financial Assistant',
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ask about spending, budget, recurring payments, reports, and quick actions in one place.',
                          style: text.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.tonalIcon(
                    onPressed: () async {
                      await _openFinancialAssistant(context);
                    },
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Open'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cs.primary.withValues(alpha: 0.96),
                      cs.secondary.withValues(alpha: 0.84),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: cs.primary.withValues(alpha: 0.22),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Period Overview',
                      style: text.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A quick pulse on this period before you dive into the details.',
                      style: text.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: CircularPercentIndicator(
                        radius: 74,
                        lineWidth: 12,
                        animation: true,
                        animateFromLastPercent: true,
                        animationDuration: 700,
                        curve: Curves.easeOutCubic,
                        percent: percent,
                        progressColor: const Color(0xFFFFD166),
                        backgroundColor: Colors.white.withValues(alpha: 0.14),
                        circularStrokeCap: CircularStrokeCap.round,
                        center: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(percent * 100).toStringAsFixed(0)}%',
                              style: text.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'used',
                              style: text.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _secureInfoColumn(
                            context,
                            title: 'Budget',
                            value: budget,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _secureInfoColumn(
                            context,
                            title: 'Spent',
                            value: periodTotal,
                          ),
                        ),
                        const SizedBox(width: 10),
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
            ),
            if (bankAccounts.isNotEmpty) ...[
              const SizedBox(height: 16),
              HomeSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(
                      context,
                      title: 'Bank balances',
                      subtitle:
                          'Live budget context across your saved accounts.',
                      icon: Icons.account_balance_rounded,
                      trailing: Text(
                        valuesLocked
                            ? '****'
                            : bankBalanceTotal.toStringAsFixed(2),
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bankAccounts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final account = bankAccounts[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.38,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  account.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                valuesLocked
                                    ? '****'
                                    : account.balance.toStringAsFixed(2),
                                style: text.bodyMedium?.copyWith(
                                  color: account.balance >= 0
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            if (provider.hasPeriod) ...[
              const SizedBox(height: 16),
              HomeSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(
                      context,
                      title: 'Forecast',
                      subtitle: daysLeftInPeriod > 0
                          ? "Based on your current pace, here's how this period may end."
                          : 'This period has ended or is about to end.',
                      icon: Icons.trending_up_rounded,
                    ),
                    const SizedBox(height: 14),
                    _infoRow(
                      context,
                      label: 'Projected total',
                      value: projectedTotal.toStringAsFixed(2),
                    ),
                    if (budget > 0) ...[
                      const SizedBox(height: 10),
                      _infoRow(
                        context,
                        label: 'Vs. budget',
                        value: projectedDiff >= 0
                            ? '+${projectedDiff.toStringAsFixed(2)}'
                            : '-${(-projectedDiff).toStringAsFixed(2)}',
                        valueColor: projectedDiff > 0
                            ? Colors.red
                            : Colors.green,
                      ),
                    ],
                    if (forecastMessages.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 14),
                      ...forecastMessages.map(
                        (message) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _messageRow(context, message: message),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            if (periodIncome > 0 || periodTotal > 0) ...[
              const SizedBox(height: 16),
              HomeSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(
                      context,
                      title: 'Income vs Expenses',
                      subtitle:
                          'A cleaner view of how much came in and went out.',
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                    const SizedBox(height: 14),
                    _infoRow(
                      context,
                      label: 'Income this period',
                      value: periodIncome.toStringAsFixed(2),
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      context,
                      label: 'Expenses this period',
                      value: periodTotal.toStringAsFixed(2),
                    ),
                    const SizedBox(height: 10),
                    _infoRow(
                      context,
                      label: 'Savings rate',
                      value: '${savingsRate.toStringAsFixed(1)}%',
                      valueColor: savingsRate >= 0 ? Colors.green : Colors.red,
                    ),
                  ],
                ),
              ),
            ],
            if (upcomingRecurring.isNotEmpty) ...[
              const SizedBox(height: 16),
              HomeSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader(
                      context,
                      title: 'Upcoming recurring payments',
                      subtitle:
                          'The next scheduled items that may affect your budget.',
                      icon: Icons.event_repeat_rounded,
                    ),
                    const SizedBox(height: 14),
                    ...upcomingRecurring.take(3).map((payment) {
                      final dueDate = provider.getNextDueDate(payment);
                      final dueStr = DateFormat('MMM d').format(dueDate);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.38,
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${payment.title} • due $dueStr',
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                payment.amount.toStringAsFixed(2),
                                style: text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            _dateNavigatorCard(context, selectedDateTotal: selectedDateTotal),
            const SizedBox(height: 18),
            _sectionHeader(
              context,
              title: 'Entries for this date',
              subtitle: 'Detailed activity for the selected day.',
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              HomeSectionCard(
                child: Text(
                  'No detailed entries for this date.',
                  style: text.bodyMedium,
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 2),
                itemBuilder: (context, index) => SpendingEntryTile(
                  entry: entries[index],
                  onEdit: () {
                    HomeSheets.showEditEntrySheet(
                      context: context,
                      date: _selectedDate,
                      index: index,
                      entry: entries[index],
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
                      index: index,
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            _sectionHeader(
              context,
              title: 'Insights',
              subtitle:
                  'Average per day in this period: ${avgPerDay.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 12),
            HomeSectionCard(
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
                              'Top categories',
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap a category to review, edit, delete, or export its transactions.',
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
                      'No categories yet.',
                      style: text.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: sortedCategoryInsights.length,
                      itemBuilder: (context, index) =>
                          _buildCategoryInsightCard(
                            context,
                            insight: sortedCategoryInsights[index],
                            rank: index + 1,
                            totalPeriodSpending: periodTotal,
                          ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionHeader(
              context,
              title: 'Recommendations',
              subtitle: 'Suggestions based on your recent spending patterns.',
            ),
            const SizedBox(height: 12),
            if (recs.isEmpty)
              HomeSectionCard(
                child: Text(
                  'No recommendations yet.',
                  style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              )
            else
              HomeSectionCard(
                child: Column(
                  children: [
                    for (var i = 0; i < recs.length; i++)
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: i == recs.length - 1 ? 0 : 12,
                        ),
                        child: _recommendationTile(context, recs[i]),
                      ),
                  ],
                ),
              ),
          ],
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

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData? icon,
    Widget? trailing,
  }) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: cs.primary, size: 20),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: text.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing],
      ],
    );
  }

  Widget _infoRow(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageRow(BuildContext context, {required String message}) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Icon(Icons.insights_rounded, size: 14, color: cs.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(message, style: text.bodySmall?.copyWith(height: 1.4)),
        ),
      ],
    );
  }

  Widget _recommendationTile(BuildContext context, String message) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.secondary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 18,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: text.bodyMedium?.copyWith(height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateNavigatorCard(
    BuildContext context, {
    required double selectedDateTotal,
  }) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return HomeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DateNavButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous day',
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate.subtract(
                      const Duration(days: 1),
                    );
                  });
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Spending for',
                      style: text.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _dateFormat.format(_selectedDate),
                      textAlign: TextAlign.center,
                      style: text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _DateNavButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next day',
                onTap: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  });
                },
              ),
              const SizedBox(width: 8),
              _DateNavButton(
                icon: Icons.calendar_today_rounded,
                tooltip: 'Pick date',
                onTap: () async {
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
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.36),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              selectedDateTotal > 0
                  ? 'Total spent on this date: ${selectedDateTotal.toStringAsFixed(2)}'
                  : 'No spending recorded for this date.',
              style: text.bodyMedium,
            ),
          ),
        ],
      ),
    );
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

    Future<void> unlockSecureValues() async {
      final ok = await context
          .read<SecureValuesLockService>()
          .unlockWithBiometrics();
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Unlock failed")));
      }
    }

    void lockSecureValuesAgain() {
      context.read<SecureValuesLockService>().lock();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Locked again")));
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        if (locked) {
          await unlockSecureValues(); // biometrics
        } else {
          lockSecureValuesAgain(); // no biometrics
        }
      },
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              locked ? '****' : value.toStringAsFixed(2),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Icon(
              locked ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: 16,
              color: Colors.white70,
            ),
            const SizedBox(height: 4),
            Text(
              locked ? 'Tap to unlock' : 'Tap to lock',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateNavButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _DateNavButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
