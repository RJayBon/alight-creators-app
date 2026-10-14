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
import '../../widgets/image_crop_sheet.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/toast.dart';

/// Edit your own profile, or (as an admin) somebody else's.
///
/// This screen had three independent ways to look "frozen or crashed", all
/// fixed here:
///
///  1. **The image previews were `DecorationImage`s.** A decoration image has no
///     error channel — no `errorBuilder`, nothing. The picked/cropped file lives
///     in the cache directory, and Android purges that directory while the app
///     sits backgrounded behind the gallery. The next frame then threw
///     `FileSystemException` out of `FileImage.load`, and every frame after it
///     threw again: a red, unresponsive form with no way out. Both previews are
///     now `Image.file(..., errorBuilder:)`, so a vanished file degrades to the
///     placeholder instead of painting forever.
///  2. **The native cropper could eat the whole flow.** `image_cropper` launches a
///     second Android activity (`com.yalantis.ucrop.UCropActivity`) and Dart then
///     waits for `onActivityResult` on `MainActivity`. On the low-end vendor ROMs
///     this app ships to (observed on a Transsion device: the crop activity drew
///     one frame, `ActivityRecord … f}}` finished it three seconds later, and no
///     exception ever reached Dart) that callback does not arrive. There are
///     exactly three branches in the plugin's `onActivityResult` — `RESULT_OK`,
///     `UCrop.RESULT_ERROR`, and "anything else → `success(null)`" — so if the
///     callback never runs, *none* of them do, and the awaited Future stays
///     pending forever. Cancelled crops and dead crops were therefore
///     indistinguishable, and both locked the form.
///  3. **`Navigator.pop()` during `initState`.** With an expired session (or an
///     account that no longer exists) `_load()` popped synchronously mid-build —
///     an assertion in debug, a blank route in release. It is deferred one frame.
///
/// Defect 2 is what the earlier revisions of this file papered over (a resume
/// watchdog, then an "apply the uncropped pick" rescue, then the plugin's own
/// `recoverImage()` cache). All of that is gone: the cropper was replaced by an
/// in-app one (`lib/widgets/image_crop_sheet.dart`) that runs in this same
/// activity, so there is no second activity to lose a result. Only the gallery
/// hop is still native, and it is unavoidable — reading a photo without
/// `image_picker`'s activity is not a thing an app can do.
///
/// Supporting changes: the pick uses its own `_picking` flag (spinner on the
/// preview, form still editable) instead of the modal `_busy` one; `_busy` can
/// no longer stick, because `Save` resets it in a `finally`; a picked image is
/// checked for being readable and non-empty before it replaces the preview;
/// picking a new image clears a pending removal; removal works for banners too
/// (only the avatar had that path); and a token makes the whole flow re-entrant
/// safe, so a late result can never overwrite a newer choice.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.targetUserId});

  /// Non-null when an admin is editing somebody else's account.
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
  bool _removeAvatar = false;
  bool _removeBanner = false;
  String? _gender;
  String? _error;

  /// Save / delete-account in progress: the form is locked and the button shows
  /// its own spinner.
  bool _busy = false;

  /// A gallery round trip is in flight. Deliberately *not* `_busy`: the user is
  /// looking at the platform picker, and the form must stay editable behind it.
  bool _picking = false;

  /// Bumped whenever a pick is abandoned, so a late result cannot land on a newer
  /// choice. Cheap insurance for the one hop we do not control.
  int _pickToken = 0;

  /// Set just before popping so the `finally` in [_save] does not rebuild a
  /// route that is already animating out.
  bool _didPop = false;

  /// Paths that were on the account before this edit session, so a *removal*
  /// (rather than a replacement) can still clean up the old file.
  String? _originalAvatarPath;
  String? _originalBannerPath;

  static const double _avatarSize = 92;

  static const Widget _bannerPlaceholder = Center(
    child: Text('Tap to change banner',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
  );

  static const Widget _avatarPlaceholder = Icon(Icons.camera_alt_outlined,
      color: AppColors.textSecondary, size: 26);

  static const Widget _pickBusyLayer = Positioned.fill(
    child: ColoredBox(
      color: Color(0x66000000),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.accent),
        ),
      ),
    ),
  );

  bool get _isSelf =>
      widget.targetUserId == null ||
      widget.targetUserId == AuthService.instance.currentUser?.userId;

  int? get _targetId =>
      widget.targetUserId ?? AuthService.instance.currentUser?.userId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _handle, _email, _birth, _customGender, _bio]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final id = _targetId;
    if (id == null) {
      // Popping synchronously from initState is the "opens then dies" path.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(false);
      });
      return;
    }
    try {
      final u = await UserService.instance.getById(id);
      if (u == null) {
        if (mounted) Navigator.of(context).pop(false);
        return;
      }
      _originalAvatarPath = u.avatarPath;
      _originalBannerPath = u.bannerPath;
      _name.text = u.fullName;
      _handle.text = u.username;
      _email.text = u.email;
      _birth.text = u.birthdate ?? '';
      _gender = u.gender;
      _customGender.text = u.genderCustom ?? '';
      _bio.text = u.bio;
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('[EditProfile] load failed: $e');
      if (mounted) setState(() => _error = 'Could not load this profile.');
    }
  }

  /// Gallery → crop sheet, as one guarded sequence.
  ///
  /// Cancelling at *either* step is a successful no-op: the current image stays,
  /// no error is shown, nothing is written. A cancel of the sheet used to be
  /// indistinguishable from a cropper that died on them — with the crop in-app,
  /// `pop(null)` can only mean the user pressed ✗.
  Future<void> _pickImage({required bool forAvatar}) async {
    if (_picking || _busy) return;
    final token = ++_pickToken;
    setState(() {
      _picking = true;
      _error = null;
    });

    // Mutable and only for the catch block's temp-file cleanup. A mutable local
    // is deliberately NOT what the setState closure reads (see `applied` below).
    File? cropFile;
    try {
      final picked = await FileService.instance.pickImage();
      if (!mounted || token != _pickToken) return;
      if (picked == null) return; // gallery dismissed

      // The gallery activity is still being torn down at this instant, and
      // pushing a route into that window is how the transition gets dropped on
      // low-end devices. One frame plus a short beat, then open our own.
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (!mounted || token != _pickToken) return;

      final cropped = await ImageCropSheet(
        source: picked,
        // 1:1 for the avatar, 4:1 for the banner — the two shapes the profile
        // actually renders, so the frame the user drags is the frame they get.
        aspectRatio: forAvatar ? 1.0 : 4.0,
        // Honored as the real output size. The plugin cropper this replaces
        // discarded both values, so "400px avatars" were full-resolution files.
        outputWidth: forAvatar ? 400 : 1200,
        outputHeight: forAvatar ? 400 : 300,
        circle: forAvatar,
        title: forAvatar ? 'Profile photo' : 'Banner',
        // Same caps the old cropper applied to its output before returning.
        maxDimension: forAvatar ? 400 : 1200,
      ).show(context);
      // Kept separately from `applied` so the catch block can still see whether a
      // temp file was produced before something failed.
      cropFile = cropped;

      if (!mounted || token != _pickToken) return;
      if (cropped == null) return; // cancelled
      if (!_usable(cropped)) {
        setState(() => _error =
            'The cropped file could not be read. Please pick the photo again.');
        return;
      }
      final File applied = cropped;
      setState(() {
        if (forAvatar) {
          _avatar = applied;
          _removeAvatar = false;
        } else {
          _banner = applied;
          _removeBanner = false;
        }
      });
    } catch (e) {
      debugPrint('[EditProfile] pick/crop failed: $e');
      // Partial-write guard: the crop temp file exists but applying it failed, so
      // drop it rather than leaking it into the cache directory.
      final lost = cropFile;
      if (lost != null) {
        unawaited(_discardTemp(lost));
      }
      if (mounted && token == _pickToken) {
        setState(() => _error = e is FileSaveException
            ? e.toString()
            : 'Could not edit that image.');
      }
    } finally {
      if (mounted && token == _pickToken) setState(() => _picking = false);
    }
  }

  Future<void> _discardTemp(File f) async {
    try {
      if (f.existsSync()) await f.delete();
    } catch (_) {
      // The cache directory is reclaimable anyway; never fail a pick over this.
    }
  }

  static bool _usable(File f) {
    try {
      return f.existsSync() && f.lengthSync() > 0;
    } catch (_) {
      return false;
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    _didPop = false;
    setState(() => _error = null);

    final id = _targetId;
    if (id == null) {
      setState(() => _error = 'Your session expired. Please log in again.');
      return;
    }

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
      final existing = await UserService.instance.getById(id);
      if (existing == null) {
        throw Exception('That account no longer exists.');
      }
      oldAvatar = existing.avatarPath;
      oldBanner = existing.bannerPath;

      // Kick off both uploads in parallel; await together.
      final Future<String>? avatarSave = _avatar == null
          ? null
          : FileService.instance.saveUpload(
              src: _avatar!,
              subfolder: kAvatarsDir,
              prefix: 'user_$id',
              maxBytes: kAvatarMaxBytes,
              fallbackExtension: '.webp',
            );

      final Future<String>? bannerSave = _banner == null
          ? null
          : FileService.instance.saveUpload(
              src: _banner!,
              subfolder: kBannersDir,
              prefix: 'banner_$id',
              maxBytes: kBannerMaxBytes,
              fallbackExtension: '.webp',
            );

      if (_removeAvatar) existing.avatarPath = null;
      if (_removeBanner) existing.bannerPath = null;

      if (avatarSave != null) {
        newAvatar = await avatarSave.timeout(
          const Duration(seconds: 20),
          onTimeout: () =>
              throw Exception('Avatar upload timed out. Try a smaller image.'),
        );
        existing.avatarPath = newAvatar;
      }
      if (bannerSave != null) {
        newBanner = await bannerSave.timeout(
          const Duration(seconds: 20),
          onTimeout: () =>
              throw Exception('Banner upload timed out. Try a smaller image.'),
        );
        existing.bannerPath = newBanner;
      }

      existing
        ..fullName = _name.text.trim()
        ..username = _handle.text.trim().toLowerCase()
        ..email = _email.text.trim().toLowerCase()
        ..bio = _bio.text.trim()
        ..gender = _gender
        ..genderCustom =
            _gender == 'Others' ? _customGender.text.trim() : null
        ..birthdate = _birth.text.trim().isEmpty
            ? null
            : Validators.birthdate(_birth.text);

      // `update()` returns a message instead of throwing, and no longer
      // round-trips the password column through `toMap()` (which used to write
      // an empty hash and lock the account out).
      final err = await UserService.instance.update(existing);
      if (err != null) throw Exception(err);

      if (_isSelf) {
        await AuthService.instance.refreshCurrentUser();
      }

      // Drop files that are no longer referenced — including when the user
      // *removed* an image rather than replacing it.
      final finalAvatar = newAvatar ?? existing.avatarPath;
      final finalBanner = newBanner ?? existing.bannerPath;
      if (oldAvatar != null && oldAvatar != finalAvatar) {
        unawaited(FileService.instance.deleteFile(oldAvatar));
      }
      if (oldBanner != null && oldBanner != finalBanner) {
        unawaited(FileService.instance.deleteFile(oldBanner));
      }
      _originalAvatarPath = finalAvatar;
      _originalBannerPath = finalBanner;
      _removeAvatar = false;
      _removeBanner = false;

      if (!mounted) return;
      // Spinner off *before* the pop, so the button doesn't look stuck during
      // the exit animation on slow devices.
      setState(() => _busy = false);
      Toast.show(context, 'Profile updated.');
      _didPop = true;
      Navigator.of(context).pop(true);
    } catch (e) {
      // Roll back the files we did write; the DB row never changed.
      if (newAvatar != null) {
        unawaited(FileService.instance.deleteFile(newAvatar));
      }
      if (newBanner != null) {
        unawaited(FileService.instance.deleteFile(newBanner));
      }
      if (mounted) {
        setState(() => _error = e is FileTooLargeException || e is FileSaveException
            ? e.toString()
            : 'Could not save profile: $e');
      }
    } finally {
      // Unconditional: a stuck `_busy` *is* what made this screen look crashed —
      // spinner forever, every tap ignored.
      if (!_didPop && _busy && mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAccount() async {
    final ok = await confirmDialog(context,
        title: 'Delete account?',
        message:
            'Your account, tutorials, and uploaded files will be permanently removed.',
        confirmLabel: 'Delete',
        danger: true);
    if (!ok) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      final id = _targetId;
      if (id == null) throw Exception('Session expired.');
      await UserService.instance.deleteUser(id);
      if (widget.targetUserId == null) {
        await AuthService.instance.logOut();
        if (!mounted) return;
        _didPop = true;
        _busy = false;
        Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
      } else {
        // Admin editing someone else: popping to '/' discarded the whole admin
        // stack. Go back one route and let the list refresh.
        if (!mounted) return;
        setState(() => _busy = false);
        Toast.show(context, 'Account deleted.');
        _didPop = true;
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      Toast.show(context, 'Could not delete account.', isError: true);
      debugPrint('deleteAccount failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _busy || _picking;
    final banner = _banner;
    final avatar = _avatar;
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
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            // ---------- Banner ----------
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: locked ? null : () => _pickImage(forAvatar: false),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 130,
                  width: double.infinity,
                  child: ColoredBox(
                    color: AppColors.surface,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (banner == null)
                          _bannerPlaceholder
                        else
                          _filePreview(banner,
                              cacheWidth: 800,
                              fallback: _bannerPlaceholder),
                        if (_picking) _pickBusyLayer,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _removeRow(
              picked: banner != null,
              originalPath: _originalBannerPath,
              what: 'banner',
              locked: locked,
              onTap: () => setState(() {
                _banner = null;
                _removeBanner = _originalBannerPath != null;
              }),
            ),
            const SizedBox(height: 12),

            // ---------- Avatar ----------
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: locked ? null : () => _pickImage(forAvatar: true),
                child: Container(
                  width: _avatarSize,
                  height: _avatarSize,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (avatar == null)
                        const Center(child: _avatarPlaceholder)
                      else
                        _filePreview(avatar,
                            cacheWidth: 200,
                            fallback: const Center(child: _avatarPlaceholder)),
                      if (_picking) _pickBusyLayer,
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Tap to change avatar',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ),
            _removeRow(
              picked: avatar != null,
              originalPath: _originalAvatarPath,
              what: 'avatar',
              locked: locked,
              onTap: () => setState(() {
                _avatar = null;
                // Clear the *stored* path too, otherwise the next save silently
                // reverts to the old file.
                _removeAvatar = _originalAvatarPath != null;
              }),
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
            // Disabled while the gallery round trip is outstanding, so a pick that
            // lands after the save has started cannot be dropped without a word.
            PillButton(
                label: 'Save Changes',
                onPressed: _save,
                loading: _busy,
                disabled: _picking),
            if (_isSelf) ...[
              const SizedBox(height: 12),
              PillButton(
                label: 'Delete Account',
                outlined: true,
                danger: true,
                icon: Icons.delete_outline,
                // `PillButton.onPressed` is a NON-nullable VoidCallback, so a
                // `cond ? null : cb` ternary does not type-check (the original
                // code got around it with `() {}`, which is worse: a
                // tappable-looking button that silently eats the tap).
                // `disabled` is the widget's own affordance — it dims *and*
                // passes null to the InkWell.
                disabled: locked,
                onPressed: _deleteAccount,
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// `Image.file` + `errorBuilder`, not a `DecorationImage`: a decoration image
  /// has no error channel, so a cache file the OS reclaimed while the app was
  /// backgrounded threw on every frame (see the class doc). `cacheWidth` also
  /// stops a 12-megapixel banner from being decoded at full size into a 130 px
  /// strip.
  Widget _filePreview(File file,
      {required int cacheWidth, required Widget fallback}) {
    return Image.file(
      file,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => fallback,
    );
  }

  /// "Remove current avatar / banner", or the pending-removal notice.
  Widget _removeRow({
    required bool picked,
    required String? originalPath,
    required String what,
    required bool locked,
    required VoidCallback onTap,
  }) {
    if (!picked && originalPath == null) return const SizedBox.shrink();
    return Center(
      child: TextButton(
        onPressed: locked ? null : onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          foregroundColor: AppColors.danger,
        ),
        child: Text(
          picked ? '$what will be removed on save' : 'Remove current $what',
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }
}