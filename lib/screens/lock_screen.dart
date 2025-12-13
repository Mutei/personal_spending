import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/app_lock_service.dart';

class LockScreen extends StatelessWidget {
  const LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lock = context.read<AppLockService>();

    return Scaffold(
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.lock_open),
          label: const Text('Unlock App'),
          onPressed: () async {
            final ok = await lock.authenticate();
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Authentication failed')),
              );
            }
          },
        ),
      ),
    );
  }
}
