import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/saved_account.dart';
import '../providers/spending_provider.dart';
import '../providers/other_spending_provider.dart';
import '../services/account_store.dart';
import '../services/auth_service.dart';
import '../services/biometric_gate.dart';

import 'home_screen.dart';
import 'login_screen.dart';
import 'other_spending_screen.dart';

class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  final _pages = const [
    HomeScreen(),
    OtherSpendingScreen(),
    SizedBox(), // Accounts tab placeholder
  ];

  final _store = AccountStore();
  final _bio = BiometricGate();

  Future<void> _showAccountSwitcher() async {
    final auth = context.read<AuthService>();

    // ✅ Ensure current logged-in account appears immediately (even if they never "logged in" manually)
    final user = auth.currentUser;
    if (user != null) {
      final identifier = user.email ?? user.uid;
      await _store.upsertAccount(
        SavedAccount(
          uid: user.uid,
          identifier: identifier,
          email: user.email,
          displayName: user.displayName,
        ),
        // password not available here; it will be saved on manual login only
      );
    }

    final accounts = await _store.getAccounts();

    // ✅ biometric before showing accounts (optional but ok)
    final ok = await _bio.unlock(reason: "Switch account");
    if (!ok || !mounted) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ListTile(
                  title: Text(
                    "Accounts",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text("Long-press to open this anytime"),
                ),
                if (accounts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "No saved accounts yet. Log in once and it will appear here.",
                    ),
                  )
                else
                  ...accounts.map((a) {
                    final isCurrent = auth.currentUser?.uid == a.uid;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          (a.displayName ?? a.identifier).trim().isNotEmpty
                              ? (a.displayName ?? a.identifier)
                                    .trim()[0]
                                    .toUpperCase()
                              : "?",
                        ),
                      ),
                      title: Text(a.displayName ?? a.identifier),
                      subtitle: Text(a.email ?? a.identifier),
                      trailing: isCurrent
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : const Icon(Icons.swap_horiz),

                      // ✅ Switch user
                      onTap: isCurrent
                          ? null
                          : () async {
                              Navigator.pop(context);

                              final pwd = await _store.getPassword(a.uid);

                              // If no stored password -> go to login prefilled
                              if (pwd == null || pwd.isEmpty) {
                                if (!mounted) return;
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => LoginScreen(
                                      initialIdentifier: a.identifier,
                                      fromAccountSwitcher: true,
                                    ),
                                  ),
                                );
                                return;
                              }

                              await auth.signIn(
                                identifier: a.identifier,
                                password: pwd,
                              );

                              await _store.upsertAccount(a); // refresh lastUsed

                              // ✅ Force providers to re-attach immediately (no hot restart)
                              final newUid = auth.currentUser?.uid;
                              context.read<SpendingProvider>().attachUser(
                                newUid,
                              );
                              context.read<OtherSpendingProvider>().attachUser(
                                newUid,
                              );
                            },

                      // ✅ Remove account
                      onLongPress: () async {
                        final removed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("Remove account?"),
                            content: Text(
                              "Remove ${a.displayName ?? a.identifier} from this device?",
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text("Remove"),
                              ),
                            ],
                          ),
                        );

                        if (removed == true) {
                          await _store.removeAccount(a.uid);
                          if (mounted) Navigator.pop(context); // close sheet
                          await _showAccountSwitcher(); // reopen refreshed
                        }
                      },
                    );
                  }).toList(),

                const Divider(),

                // ✅ Add account (DON'T sign out first)
                ListTile(
                  leading: const Icon(Icons.person_add_alt_1_rounded),
                  title: const Text("Add account"),
                  onTap: () async {
                    Navigator.pop(context);

                    if (!mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            const LoginScreen(fromAccountSwitcher: true),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    // ✅ Keep BOTH providers attached to the current user globally (affects all tabs)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = auth.currentUser?.uid;
      context.read<SpendingProvider>().attachUser(uid);
      context.read<OtherSpendingProvider>().attachUser(uid);
    });

    return Scaffold(
      body: _index == 2 ? _pages[0] : _pages[_index], // keep UX stable
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) async {
          if (i == 2) {
            await _showAccountSwitcher();
            setState(() => _index = 0);
            return;
          }
          setState(() => _index = i);
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_outlined),
            activeIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Monthly',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag),
            label: 'Other',
          ),
          BottomNavigationBarItem(
            label: 'Accounts',
            icon: GestureDetector(
              onLongPress: _showAccountSwitcher,
              child: const Icon(Icons.switch_account_outlined),
            ),
            activeIcon: const Icon(Icons.switch_account),
          ),
        ],
      ),
    );
  }
}
