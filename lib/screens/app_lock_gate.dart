import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_lock_service.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;
  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // If app lock is enabled, lock on first frame (app launch)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final lock = context.read<AppLockService>();
      if (lock.isEnabled) {
        lock.lockAgain();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = context.read<AppLockService>();

    // Lock whenever app goes background OR returns (resumed)
    if (lock.isEnabled) {
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.inactive) {
        lock.lockAgain();
      }
      if (state == AppLifecycleState.resumed) {
        lock.lockAgain();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppLockService>(
      builder: (context, lock, _) {
        if (!lock.isEnabled || lock.isUnlocked) {
          return widget.child;
        }

        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock_rounded, size: 64),
                  const SizedBox(height: 12),
                  const Text(
                    "App is locked",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.fingerprint),
                      label: Text(_authInProgress ? "Unlocking..." : "Unlock"),
                      onPressed: _authInProgress
                          ? null
                          : () async {
                              setState(() => _authInProgress = true);
                              final ok = await lock.authenticate();
                              if (!ok && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Authentication failed"),
                                  ),
                                );
                              }
                              if (mounted)
                                setState(() => _authInProgress = false);
                            },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
