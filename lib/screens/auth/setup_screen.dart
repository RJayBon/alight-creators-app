import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../theme.dart';
import '../../utils/validators.dart';
import '../../widgets/birthdate_field.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/gender_selector.dart';
import '../../widgets/handle_field.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/pill_button.dart';

/// First-run account gate.
///
/// Shown by `_Bootstrap` only while the `users` table is empty. The account
/// created here is the app's first administrator: `AuthService.createFirstAdmin`
/// writes `role = 'admin'` directly, because nothing else in the app can grant
/// that role (promoting requires an admin), and it refuses to run a second time
/// so this screen can never mint an additional admin.
///
/// Deliberately has no back button and cannot be dismissed: on a fresh install
/// there is no other screen to go back to, and leaving mid-setup would put the
/// user on the Welcome screen with the same "no accounts yet" state they came
/// from.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});
  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
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
  bool _checking = true;
  String _prevName = '';
  bool _handleTouched = false;

  @override
  void initState() {
    super.initState();
    // A fresh install lands here directly from `_Bootstrap`, but if the app
    // ever routes here after an account exists (e.g. the admin wiped all data
    // and someone navigated back), the gate should re-open the normal flow
    // rather than offer an admin-creation form that will be refused anyway.
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconcile());
  }

  Future<void> _reconcile() async {
    final needsSetup = await AuthService.instance.needsSetup();
    if (!mounted) return;
    setState(() => _checking = false);
    if (!needsSetup) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _handle, _email, _birth, _customGender, _pw, _cpw]) {
      c.dispose();
    }
    super.dispose();
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

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _error = null);

    final nameErr = Validators.name(_name.text);
    final handleErr = Validators.handle(_handle.text);
    final emailErr = Validators.email(_email.text);
    final pwErr = Validators.password(_pw.text);
    final birth = _birth.text.trim().isEmpty
        ? null
        : Validators.birthdate(_birth.text);

    if (nameErr != null) return setState(() => _error = nameErr);
    if (handleErr != null) return setState(() => _error = handleErr);
    if (emailErr != null) return setState(() => _error = emailErr);
    if (pwErr != null) return setState(() => _error = pwErr);
    if (_pw.text != _cpw.text) {
      return setState(() => _error = 'Passwords do not match.');
    }
    if (_gender == null) {
      return setState(() => _error = 'Please select a gender.');
    }
    if (_gender == 'Others' && _customGender.text.trim().isEmpty) {
      return setState(() => _error = 'Please specify your gender.');
    }
    if (_birth.text.trim().isNotEmpty && birth == null) {
      return setState(
          () => _error = 'Please enter a valid birthdate (13+, not in future).');
    }

    setState(() => _busy = true);
    final err = await AuthService.instance.createFirstAdmin(
      name: _name.text,
      username: _handle.text,
      email: _email.text,
      password: _pw.text,
      gender: _gender,
      genderCustom: _gender == 'Others' ? _customGender.text.trim() : null,
      birthdate: birth,
    );
    if (!mounted) return;
    if (err != null) {
      // Stay busy=false and show the reason — the user must be able to retry
      // (a UNIQUE clash on a name imported from the web DB is the likely one).
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    // Success: AuthService flipped `isLoggedIn`, so `_Bootstrap` is already
    // rendering the logged-in HomeShell. Return to it — pushing '/home' here
    // would create a second live shell (the bug the login/signup screens had).
    setState(() => _busy = false);
    Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kPhoneMaxWidth),
            child: SingleChildScrollView(
              padding: kScreenPadding.add(EdgeInsets.only(
                  bottom: 24 + MediaQuery.of(context).viewInsets.bottom)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  const Icon(Icons.verified_user_outlined,
                      size: 40, color: AppColors.accent),
                  const SizedBox(height: 12),
                  const Text('Set Up Your App',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 30,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                    'No accounts exist yet. Create the first one — it becomes '
                    'the administrator, with access to moderation and the '
                    'inbox. Other people who join later are regular users.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shield_outlined,
                            size: 14, color: AppColors.accent),
                        SizedBox(width: 6),
                        Text('Role: Admin',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  LabeledField(
                    label: 'Display Name',
                    hintText: 'E.g. RJ AY',
                    controller: _name,
                    textInputAction: TextInputAction.next,
                    onChanged: (v) {
                      // Auto-slug the handle until the user types one by hand.
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
                    helper: 'Your public @handle.',
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
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
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
                      label: 'Create Admin Account',
                      onPressed: _submit,
                      loading: _busy),
                  const SizedBox(height: 12),
                  const Text(
                    'You can invite others to sign up as regular users from the '
                    'Welcome screen once this is done.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}