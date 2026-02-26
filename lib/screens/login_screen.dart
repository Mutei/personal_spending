import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../models/saved_account.dart';
import '../services/account_store.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? initialIdentifier;
  final bool fromAccountSwitcher;

  const LoginScreen({
    super.key,
    this.initialIdentifier,
    this.fromAccountSwitcher = false,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idController = TextEditingController(); // email or username
  final _passController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _idController.text = widget.initialIdentifier ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Stack(
          children: [
            // top colored header
            Container(
              height: 220,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primary.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            // form card
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 8),
                        Icon(Icons.wallet_rounded, size: 45, color: cs.primary),
                        const SizedBox(height: 6),
                        Text(
                          "Welcome back",
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Login to track your spendings",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        if (_error != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _idController,
                          decoration: const InputDecoration(
                            labelText: "Email or Username",
                            prefixIcon: Icon(Icons.person_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: "Password",
                            prefixIcon: Icon(Icons.lock_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: cs.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: _login,
                                  child: const Text(
                                    "Login",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            );
                          },
                          child: const Text("Don't have an account? Sign up"),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  final _accountStore = AccountStore();
  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();

      await auth.signIn(
        identifier: _idController.text.trim(),
        password: _passController.text.trim(),
      );

      final user = auth.currentUser;
      if (user != null) {
        await _accountStore.upsertAccount(
          SavedAccount(
            uid: user.uid,
            identifier: _idController.text.trim(),
            email: user.email,
            displayName: user.displayName,
          ),
          password: _passController.text.trim(), // stored securely
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
}
