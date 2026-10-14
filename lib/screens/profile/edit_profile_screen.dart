import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../services/auth_service.dart';
import '../../services/file_service.dart';
import '../../services/user_service.dart';
import '../../theme.dart';
import '../../utils/validators.dart';
import '../../widgets/birthdate_field.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/gender_selector.dart';
import '../../widgets/handle_field.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/toast.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.targetUserId});
  final int? targetUserId;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _handle = TextEditingController();
  final _email = TextEditingController();
  final _birth = TextEditingController();
  final _customGender = TextEditingController();
  final _bio = TextEditingController();

  File? _avatar;
  File? _banner;
  String? _gender;
  String? _error;
  bool _busy = false;

  bool get _isSelf =>
      widget.targetUserId == null ||
      widget.targetUserId == AuthService.instance.currentUser?.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = widget.targetUserId ??
        AuthService.instance.currentUser!.userId!;
    final u = await UserService.instance.getById(id);
    if (u == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    _name.text = u.fullName;
    _handle.text = u.username;
    _email.text = u.email;
    _birth.text = u.birthdate ?? '';
    _gender = u.gender;
    _customGender.text = u.genderCustom ?? '';
    _bio.text = u.bio;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [_name, _handle, _email, _birth, _customGender, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final f = await FileService.instance.pickImage();
    if (f == null) return;
    final cropped = await FileService.instance.cropImage(
      f,
      aspectRatio: 1,
      width: 400,
      height: 400,
      circle: true,
    );
    if (cropped != null && mounted) setState(() => _avatar = cropped);
  }

  Future<void> _pickBanner() async {
    final f = await FileService.instance.pickImage();
    if (f == null) return;
    final cropped = await FileService.instance.cropImage(
      f,
      aspectRatio: 4,
      width: 1200,
      height: 300,
    );
    if (cropped != null && mounted) setState(() => _banner = cropped);
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (Validators.name(_name.text) != null ||
        Validators.handle(_handle.text) != null ||
        Validators.email(_email.text) != null) {
      setState(() => _error = 'Please fix the highlighted fields.');
      return;
    }
    if (_gender == 'Others' && _customGender.text.trim().isEmpty) {
      setState(() => _error = 'Please specify your gender.');
      return;
    }
    if (_birth.text.trim().isNotEmpty &&
        Validators.birthdate(_birth.text) == null) {
      setState(() => _error = 'Please enter a valid birthdate.');
      return;
    }

    setState(() => _busy = true);
    String? oldAvatar;
    String? oldBanner;
    String? newAvatar;
    String? newBanner;

    try {
      final id = widget.targetUserId ??
          AuthService.instance.currentUser!.userId!;
      final u = (await UserService.instance.getById(id))!;
      oldAvatar = u.avatarPath;
      oldBanner = u.bannerPath;

      // Kick off both uploads in parallel; await together.
      final Future<String>? avatarSave = _avatar == null
          ? null
          : FileService.instance.saveUpload(
              src: _avatar!,
              subfolder: 'uploads/avatars',
              prefix: 'user_$id',
              maxBytes: kAvatarMaxBytes,
            );

      final Future<String>? bannerSave = _banner == null
          ? null
          : FileService.instance.saveUpload(
              src: _banner!,
              subfolder: 'uploads/banners',
              prefix: 'banner_$id',
              maxBytes: kBannerMaxBytes,
            );

      if (avatarSave != null) {
        newAvatar = await avatarSave.timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw Exception(
              'Avatar upload timed out. Try a smaller image.'),
        );
        u.avatarPath = newAvatar;
      }
      if (bannerSave != null) {
        newBanner = await bannerSave.timeout(
          const Duration(seconds: 20),
          onTimeout: () => throw Exception(
              'Banner upload timed out. Try a smaller image.'),
        );
        u.bannerPath = newBanner;
      }

      u
        ..fullName = _name.text.trim()
        ..username = _handle.text.trim().toLowerCase()
        ..email = _email.text.trim().toLowerCase()
        ..bio = _bio.text.trim()
        ..gender = _gender
        ..genderCustom = _gender == 'Others' ? _customGender.text.trim() : null
        ..birthdate = _birth.text.trim().isEmpty
            ? null
            : Validators.birthdate(_birth.text);

      await UserService.instance.update(u);
      await AuthService.instance.refreshCurrentUser();

      if (newAvatar != null && oldAvatar != null && oldAvatar != newAvatar) {
        unawaited(FileService.instance.deleteFile(oldAvatar));
      }
      if (newBanner != null && oldBanner != null && oldBanner != newBanner) {
        unawaited(FileService.instance.deleteFile(oldBanner));
      }

      if (!mounted) return;
      // Turn off the spinner BEFORE popping, so the button doesn't look
      // "stuck" during the pop animation on slow devices.
      setState(() => _busy = false);
      Toast.show(context, 'Profile updated.');
      Navigator.of(context).pop();
    } catch (e) {
      if (newAvatar != null) {
        unawaited(FileService.instance.deleteFile(newAvatar));
      }
      if (newBanner != null) {
        unawaited(FileService.instance.deleteFile(newBanner));
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e is FileTooLargeException
              ? e.toString()
              : 'Could not save profile: $e';
        });
      }
      return;
    }
    // Note: no `finally` — we always set `_busy = false` explicitly above,
    // before pop / on error. This avoids the pop-then-setState race.
  }

  Future<void> _deleteAccount() async {
    final ok = await confirmDialog(context,
        title: 'Delete account?',
        message:
            'Your account, tutorials, and uploaded files will be permanently removed.',
        confirmLabel: 'Delete',
        danger: true);
    if (!ok) return;
    try {
      final id =
          widget.targetUserId ?? AuthService.instance.currentUser!.userId!;
      await UserService.instance.deleteUser(id);
      if (widget.targetUserId == null) {
        await AuthService.instance.logOut();
      }
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    } catch (e) {
      if (!mounted) return;
      Toast.show(context, 'Could not delete account: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(_isSelf ? 'Edit Profile' : 'Edit User'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            GestureDetector(
              onTap: _busy ? null : _pickBanner,
              child: Container(
                height: 130,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                  image: _banner != null
                      ? DecorationImage(
                          image: ResizeImage(
                              FileImage(_banner!), width: 800),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _banner == null
                    ? const Center(
                        child: Text('Tap to change banner',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13)),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: _busy ? null : _pickAvatar,
                child: Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.accent, width: 2),
                    image: _avatar != null
                        ? DecorationImage(
                            image: ResizeImage(
                                FileImage(_avatar!), width: 200),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _avatar == null
                      ? const Icon(Icons.camera_alt_outlined,
                          color: AppColors.textSecondary)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Tap to change avatar',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ),
            const SizedBox(height: 24),
            LabeledField(
                label: 'Display Name',
                hintText: 'E.g. RJ AY',
                controller: _name),
            const SizedBox(height: 16),
            HandleField(controller: _handle),
            const SizedBox(height: 16),
            LabeledField(
                label: 'Email Address',
                hintText: 'you@example.com',
                controller: _email,
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            BirthdateField(controller: _birth),
            const SizedBox(height: 16),
            GenderSelector(
              value: _gender,
              onChanged: (v) => setState(() => _gender = v),
              customController: _customGender,
            ),
            const SizedBox(height: 16),
            LabeledField(
                label: 'Bio',
                hintText: 'What kind of motion design do you do?',
                controller: _bio,
                maxLines: 4,
                maxLength: 250),
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 20),
            PillButton(
                label: 'Save Changes', onPressed: _save, loading: _busy),
            if (_isSelf) ...[
              const SizedBox(height: 12),
              PillButton(
                label: 'Delete Account',
                outlined: true,
                danger: true,
                icon: Icons.delete_outline,
                onPressed: _busy ? () {} : _deleteAccount,
              ),
            ],
          ],
        ),
      ),
    );
  }
}