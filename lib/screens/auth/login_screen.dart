import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/rate_limit_service.dart';
import '../../services/session_service.dart';
import '../../theme.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/top_back_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();
  final _pw = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!RateLimitService.instance.allow('login', max: 5, windowSec: 300)) {
      setState(() => _error = 'Too many attempts. Try again in a few minutes.');
      return;
    }
    setState(() => _busy = true);
    final err = await AuthService.instance.logIn(_id.text, _pw.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    RateLimitService.instance.reset('login');
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final flash = SessionService.instance.consumeFlash();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kPhoneMaxWidth),
                child: SingleChildScrollView(
                  padding: kScreenPadding.add(
                      EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 56), // room for the fixed back button
                      const Text('Welcome Back',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 30,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('Log in with your email or @username.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14)),
                      const SizedBox(height: 32),
                      if (flash != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ErrorBanner(message: flash.$1),
                        ),
                      LabeledField(
                        label: 'Email or Username',
                        hintText: 'you@example.com or @username',
                        controller: _id,
                      ),
                      const SizedBox(height: 18),
                      LabeledField(
                        label: 'Password',
                        hintText: '• • • • • • • •',
                        controller: _pw,
                        obscureText: true,
                        trailing: TextButton(
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap),
                          onPressed: () =>
                              Navigator.of(context).pushNamed('/forgot'),
                          child: const Text('Forgot?',
                              style: TextStyle(
                                  color: AppColors.accent, fontSize: 13)),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        ErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 24),
                      PillButton(
                          label: 'Log In',
                          onPressed: _submit,
                          loading: _busy),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account? ",
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14)),
                          TextButton(
                            style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            onPressed: () => Navigator.of(context)
                                .pushReplacementNamed('/signup'),
                            child: const Text('Sign up here',
                                style: TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const TopBackButton(),
        ],
      ),
    );
  }
}