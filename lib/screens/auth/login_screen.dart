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
  bool _showPw = false;

  /// Consumed exactly once, in initState.
  ///
  /// This used to be `SessionService.instance.consumeFlash()` *inside
  /// `build()`*. Because `consumeFlash()` clears the pending message, the
  /// very first rebuild (which `setState(() => _busy = true)` guarantees)
  /// wiped it and the "Password updated. Please log in." banner disappeared
  /// after one frame — effectively never seen.
  String? _flash;

  @override
  void initState() {
    super.initState();
    _flash = SessionService.instance.consumeFlash()?.$1;
    // First-run gate: on an install with no accounts there is nothing to log
    // into, and this screen may be reached from a stale deep link. Hand the
    // user to the setup form instead of a form that can only ever fail.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (await AuthService.instance.needsSetup()) {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/setup');
      }
    });
  }

  @override
  void dispose() {
    _id.dispose();
    _pw.dispose();
    super.dispose();
  }

  bool get _canGoBack => Navigator.of(context).canPop();

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!RateLimitService.instance.allow('login', max: 5, windowSec: 300)) {
      final wait = RateLimitService.instance
          .retryAfter('login', max: 5, windowSec: 300);
      setState(() => _error = wait > 0
          ? 'Too many attempts. Try again in ${wait ~/ 60 + 1} minute(s).'
          : 'Too many attempts. Try again in a few minutes.');
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

    // A successful login already flips AuthService, so `_Bootstrap` (the
    // root '/' route) is *already* rendering HomeShell.
    //
    // Previously this was `pushNamedAndRemoveUntil('/home', (r) => false)`,
    // which destroyed '/' and pushed a second, duplicate HomeShell on top:
    // two IndexedStacks, two sets of tab State, two `_load()` fan-outs on
    // boot, and — because the stack then held exactly one route — a user who
    // logged out (`pushNamedAndRemoveUntil('/login', …)`) was left with a
    // dead Back button and no way back to the landing screen.
    if (_canGoBack) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
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
                      if (_flash != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ErrorBanner(message: _flash!),
                        ),
                      LabeledField(
                        label: 'Email or Username',
                        hintText: 'you@example.com or @username',
                        controller: _id,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 18),
                      LabeledField(
                        label: 'Password',
                        hintText: '• • • • • • • •',
                        controller: _pw,
                        obscureText: !_showPw,
                        textInputAction: TextInputAction.done,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: _showPw ? 'Hide password' : 'Show password',
                              iconSize: 20,
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                _showPw
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () => setState(() => _showPw = !_showPw),
                            ),
                            const SizedBox(width: 6),
                            TextButton(
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
                          ],
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
          // Only offer "Back" when there is somewhere to go. When this screen
          // is the root of the stack (the post-logout case above) the button
          // used to sit there doing nothing.
          if (_canGoBack) const TopBackButton(),
        ],
      ),
    );
  }
}