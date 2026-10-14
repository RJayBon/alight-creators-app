import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/password_reset_service.dart';
import '../../services/session_service.dart';
import '../../theme.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/top_back_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _token = TextEditingController();
  final _pw = TextEditingController();
  final _cpw = TextEditingController();

  ({int resetId, int userId})? _reset;
  bool _checked = false;
  String? _error;
  bool _busy = false;
  Timer? _tokenDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is String && arg.isNotEmpty) {
        _token.text = arg;
        _validate();
      } else {
        setState(() => _checked = true);
      }
    });
  }

  @override
  void dispose() {
    _tokenDebounce?.cancel();
    _token.dispose();
    _pw.dispose();
    _cpw.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    final token = _token.text.trim();
    if (token.length != 64) {
      if (!mounted) return;
      setState(() {
        _reset = null;
        _checked = true;
      });
      return;
    }
    final r = await PasswordResetService.instance.findValid(token);
    if (!mounted) return;
    setState(() {
      _reset = r;
      _checked = true;
    });
  }

  void _onTokenChanged(String _) {
    _tokenDebounce?.cancel();
    _tokenDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _checked = false);
      _validate();
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_pw.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (_pw.text != _cpw.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_reset == null) {
      setState(() => _error = 'Invalid or expired token.');
      return;
    }
    setState(() => _busy = true);
    try {
      await PasswordResetService.instance.consume(
        resetId: _reset!.resetId,
        userId: _reset!.userId,
        newPassword: _pw.text,
      );
      if (!mounted) return;
      SessionService.instance.setFlash('Password updated. Please log in.');
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not reset: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
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
                      const Text('Reset Password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 28,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('Paste your token and choose a new password.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14)),
                      const SizedBox(height: 28),
                      if (!_checked)
                        const Center(child: CircularProgressIndicator())
                      else if (_reset == null) ...[
                        LabeledField(
                          label: 'Token',
                          hintText: 'Paste your 64-char token',
                          controller: _token,
                          onChanged: _onTokenChanged,
                        ),
                        const SizedBox(height: 16),
                        const ErrorBanner(
                            message: 'This reset link is invalid or expired.'),
                        const SizedBox(height: 20),
                        PillButton(
                          label: 'Request a new token',
                          onPressed: () => Navigator.of(context)
                              .pushReplacementNamed('/forgot'),
                        ),
                      ] else ...[
                        LabeledField(
                          label: 'Token',
                          hintText: 'Paste your 64-char token',
                          controller: _token,
                          onChanged: _onTokenChanged,
                        ),
                        const SizedBox(height: 16),
                        LabeledField(
                          label: 'New Password',
                          hintText: 'At least 6 characters',
                          controller: _pw,
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        LabeledField(
                          label: 'Confirm New Password',
                          hintText: 'Re-enter password',
                          controller: _cpw,
                          obscureText: true,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          ErrorBanner(message: _error!),
                        ],
                        const SizedBox(height: 20),
                        PillButton(
                            label: 'Update Password',
                            onPressed: _submit,
                            loading: _busy),
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