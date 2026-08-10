import 'package:flutter/material.dart';
import 'package:personal_spendings/localization/language_constants.dart';

class HomeMainDrawer extends StatelessWidget {
  final String displayName;
  final String email;
  final VoidCallback onOpenInsights;
  final VoidCallback onExport;
  final Future<void> Function() onSendTestNotifications;
  final VoidCallback onNotificationPreferences;
  final Future<void> Function() onSetBudget;
  final VoidCallback onManageRecurring;
  final VoidCallback onLanguage;
  final VoidCallback onLogout;
  final VoidCallback onToggleAppLock;
  final bool appLockEnabled;

  const HomeMainDrawer({
    super.key,
    required this.displayName,
    required this.email,
    required this.onOpenInsights,
    required this.onExport,
    required this.onSendTestNotifications,
    required this.onNotificationPreferences,
    required this.onSetBudget,
    required this.onManageRecurring,
    required this.onLanguage,
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
                          color: cs.onPrimary.withValues(alpha: 0.8),
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
                  title: Text(getTranslated(context, 'Insights')),
                  subtitle: Text(
                    getTranslated(
                      context,
                      'Charts & recommendations for this period',
                    ),
                  ),
                  onTap: onOpenInsights,
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: Text(getTranslated(context, 'Export spendings')),
                  subtitle: Text(
                    getTranslated(
                      context,
                      'Download CSV or PDF for this period',
                    ),
                  ),
                  onTap: onExport,
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_rounded),
                  title: Text(
                    getTranslated(context, 'Send test notifications'),
                  ),
                  subtitle: Text(
                    getTranslated(
                      context,
                      'Resend the latest spending summary and budget alert',
                    ),
                  ),
                  onTap: () async {
                    await onSendTestNotifications();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: Text(
                    getTranslated(context, 'Notification preferences'),
                  ),
                  subtitle: Text(
                    getTranslated(
                      context,
                      'Daily summary and financial context',
                    ),
                  ),
                  onTap: onNotificationPreferences,
                ),
                ListTile(
                  leading: const Icon(Icons.edit_rounded),
                  title: Text(getTranslated(context, 'Set budget')),
                  subtitle: Text(
                    getTranslated(
                      context,
                      'Update budget and bank account balances',
                    ),
                  ),
                  onTap: () {
                    onSetBudget();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.event_repeat_rounded),
                  title: Text(getTranslated(context, 'Recurring payments')),
                  subtitle: Text(
                    getTranslated(
                      context,
                      'Manage monthly bills & auto-reminders',
                    ),
                  ),
                  onTap: onManageRecurring,
                ),
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(getTranslated(context, 'Language')),
                  subtitle: Text(
                    getTranslated(
                      context,
                      'Choose your preferred app language',
                    ),
                  ),
                  onTap: onLanguage,
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(
              appLockEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
            ),
            title: Text(getTranslated(context, 'App lock')),
            subtitle: Text(
              appLockEnabled
                  ? getTranslated(context, 'App is secured on launch')
                  : getTranslated(
                      context,
                      'Protect app with fingerprint or PIN',
                    ),
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
              getTranslated(context, 'Logout'),
              style: TextStyle(color: cs.error, fontWeight: FontWeight.w600),
            ),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}
