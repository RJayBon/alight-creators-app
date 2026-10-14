import 'package:flutter/material.dart';

import '../../services/password_reset_service.dart';
import '../../services/rate_limit_service.dart';
import '../../theme.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/top_back_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  String? _error;
  String? _token;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!RateLimitService.instance.allow('forgot', max: 3, windowSec: 600)) {
      setState(() => _error = 'Too many reset attempts. Try again later.');
      return;
    }
    setState(() => _busy = true);
    final t = await PasswordResetService.instance
        .createTokenForEmail(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _busy = false;
      _token = t;
    });
    if (t == null) {
      setState(() => _error = 'No account found for that email.');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                      const SizedBox(height: 56),
                      const Text('Forgot Password?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 28,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text(
                          "Enter your email and we'll generate a reset link.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14)),
                      const SizedBox(height: 28),
                      if (_token == null) ...[
                        LabeledField(
                          label: 'Email Address',
                          hintText: 'you@example.com',
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          ErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 20),
                        PillButton(
                            label: 'Generate Reset Token',
                            onPressed: _submit,
                            loading: _busy),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    AppColors.accent.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Your reset token is ready',
                                  style: TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              const Text(
                                  'Tap the button below. Copy the token and paste it on the next screen.',
                                  style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 13)),
                              const SizedBox(height: 10),
                              SelectableText(
                                _token!,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 11,
                                    fontFamily: 'monospace'),
                              ),
                              const SizedBox(height: 14),
                              PillButton(
                                label: 'Continue →',
                                onPressed: () => Navigator.of(context)
                                    .pushNamed('/reset',
                                        arguments: _token),
                              ),
                            ],
                          ),
                        ),
                      ],
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