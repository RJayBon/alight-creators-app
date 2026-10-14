import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/rate_limit_service.dart';
import '../../theme.dart';
import '../../utils/validators.dart';
import '../../widgets/birthdate_field.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/gender_selector.dart';
import '../../widgets/handle_field.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/top_back_button.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _email = TextEditingController();
  final _birth = TextEditingController();
  final _customGender = TextEditingController();
  final _pw = TextEditingController();
  final _cpw = TextEditingController();

  String? _gender;
  String? _error;
  bool _busy = false;
  bool _showPw = false;
  String _prevName = '';
  bool _handleTouched = false;

  @override
  void initState() {
    super.initState();
    // First-run gate: a public sign-up must not be able to create the *first*
    // account, because that account would land as `role = 'user'` and the
    // install would then have no way to reach /admin (promotion requires an
    // admin). Hand the user to the setup form instead.
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
    for (final c in [
      _name,
      _handle,
      _email,
      _birth,
      _customGender,
      _pw,
      _cpw
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _canGoBack => Navigator.of(context).canPop();

  Future<void> _submit() async {
    setState(() => _error = null);

    if (!RateLimitService.instance
        .allow('register', max: 3, windowSec: 3600)) {
      final wait = RateLimitService.instance
          .retryAfter('register', max: 3, windowSec: 3600);
      setState(() => _error = wait > 0
          ? 'Too many sign-up attempts. Try again in ${wait ~/ 60} second(s).'
          : 'Too many sign-up attempts. Try again later.');
      return;
    }

    final nameErr = Validators.name(_name.text);
    final handleErr = Validators.handle(_handle.text);
    final emailErr = Validators.email(_email.text);
    final pwErr = Validators.password(_pw.text);
    final birth = _birth.text.trim().isEmpty
        ? null
        : Validators.birthdate(_birth.text);

    if (nameErr != null) {
      setState(() => _error = nameErr);
      return;
    }
    if (handleErr != null) {
      setState(() => _error = handleErr);
      return;
    }
    if (emailErr != null) {
      setState(() => _error = emailErr);
      return;
    }
    if (pwErr != null) {
      setState(() => _error = pwErr);
      return;
    }
    if (_pw.text != _cpw.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (_gender == null) {
      setState(() => _error = 'Please select a gender.');
      return;
    }
    if (_gender == 'Others' && _customGender.text.trim().isEmpty) {
      setState(() => _error = 'Please specify your gender.');
      return;
    }
    if (_birth.text.trim().isNotEmpty && birth == null) {
      setState(() =>
          _error = 'Please enter a valid birthdate (13+, not in future).');
      return;
    }

    setState(() => _busy = true);
    final err = await AuthService.instance.signUp(
      name: _name.text,
      username: _handle.text,
      email: _email.text,
      password: _pw.text,
      gender: _gender,
      genderCustom: _gender == 'Others' ? _customGender.text.trim() : null,
      birthdate: birth,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    RateLimitService.instance.reset('register');

    // Same fix as login: AuthService already flipped the root `_Bootstrap`
    // to HomeShell, so we return to it instead of pushing a duplicate shell
    // with `pushNamedAndRemoveUntil('/home', (r) => false)`.
    if (_canGoBack) {
      Navigator.of(context).popUntil((r) => r.isFirst);
    } else {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  String _slugOf(String v) => v
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  void _setHandle(String value) {
    if (_handle.text == value) return;
    _handle.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
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
                      const Text('Create Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 30,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      const Text('Start mastering motion design today.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary, fontSize: 14)),
                      const SizedBox(height: 32),
                      LabeledField(
                        label: 'Display Name',
                        hintText: 'E.g. RJ AY',
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        onChanged: (v) {
                          // Only auto-slug while the user hasn't edited the
                          // handle by hand.
                          if (!_handleTouched ||
                              _handle.text == _slugOf(_prevName)) {
                            _setHandle(_slugOf(v));
                          }
                          _prevName = v;
                        },
                      ),
                      const SizedBox(height: 16),
                      HandleField(
                        controller: _handle,
                        helper: 'This will be your public @handle.',
                        onChanged: (_) {
                          if (!_handleTouched) {
                            setState(() => _handleTouched = true);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      LabeledField(
                        label: 'Email Address',
                        hintText: 'you@example.com',
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                      ),
                      const SizedBox(height: 16),
                      BirthdateField(controller: _birth),
                      const SizedBox(height: 16),
                      GenderSelector(
                        value: _gender,
                        onChanged: (g) => setState(() => _gender = g),
                        customController: _customGender,
                      ),
                      const SizedBox(height: 16),
                      LabeledField(
                        label: 'Password',
                        hintText: 'At least 6 characters',
                        controller: _pw,
                        obscureText: !_showPw,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        trailing: TextButton(
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap),
                          onPressed: () => setState(() => _showPw = !_showPw),
                          child: Text(_showPw ? 'Hide' : 'Show',
                              style: const TextStyle(
                                  color: AppColors.accent, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      LabeledField(
                        label: 'Confirm Password',
                        hintText: 'Re-enter password',
                        controller: _cpw,
                        obscureText: !_showPw,
                        textInputAction: TextInputAction.done,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        ErrorBanner(message: _error!),
                      ],
                      const SizedBox(height: 24),
                      PillButton(
                          label: 'Sign Up',
                          onPressed: _submit,
                          loading: _busy),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Already have an account? ',
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
                                .pushReplacementNamed('/login'),
                            child: const Text('Log in here',
                                style: TextStyle(
                                    color: AppColors.accent,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_canGoBack) const TopBackButton(),
        ],
      ),
    );
  }
}