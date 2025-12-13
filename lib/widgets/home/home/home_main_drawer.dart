import 'package:flutter/material.dart';

class HomeMainDrawer extends StatelessWidget {
  final String displayName;
  final String email;
  final VoidCallback onOpenInsights;
  final VoidCallback onExport;
  final VoidCallback onSendDailySummary;
  final VoidCallback onSetBudget;
  final VoidCallback onManageRecurring;
  final VoidCallback onLogout;
  final VoidCallback onToggleAppLock;
  final bool appLockEnabled;

  const HomeMainDrawer({
    super.key,
    required this.displayName,
    required this.email,
    required this.onOpenInsights,
    required this.onExport,
    required this.onSendDailySummary,
    required this.onSetBudget,
    required this.onManageRecurring,
    required this.onLogout,
    required this.onToggleAppLock,
    required this.appLockEnabled,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final initial = (displayName.isNotEmpty ? displayName[0] : 'U')
        .toUpperCase();

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cs.surface,
                  child: Text(
                    initial,
                    style: text.titleLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleMedium?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall?.copyWith(
                          color: cs.onPrimary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.insights_rounded),
                  title: const Text('Insights'),
                  subtitle: const Text(
                    'Charts & recommendations for this period',
                  ),
                  onTap: onOpenInsights,
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Export spendings'),
                  subtitle: const Text('Download CSV or PDF for this period'),
                  onTap: onExport,
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_rounded),
                  title: const Text('Send daily summary now'),
                  subtitle: const Text('Trigger today\'s summary notification'),
                  onTap: onSendDailySummary,
                ),
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: const Text('Set budget'),
                  subtitle: const Text(
                    'Update the budget for the current period',
                  ),
                  onTap: onSetBudget,
                ),
                ListTile(
                  leading: const Icon(Icons.event_repeat_rounded),
                  title: const Text('Recurring payments'),
                  subtitle: const Text('Manage monthly bills & auto-reminders'),
                  onTap: onManageRecurring,
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(
              appLockEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
            ),
            title: const Text('App lock'),
            subtitle: Text(
              appLockEnabled
                  ? 'App is secured on launch'
                  : 'Protect app with fingerprint or PIN',
            ),
            trailing: Switch(
              value: appLockEnabled,
              onChanged: (_) => onToggleAppLock(),
            ),
            onTap: onToggleAppLock,
          ),

          const Divider(height: 0),

          ListTile(
            leading: Icon(Icons.logout, color: cs.error),
            title: Text(
              'Logout',
              style: TextStyle(color: cs.error, fontWeight: FontWeight.w600),
            ),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}
