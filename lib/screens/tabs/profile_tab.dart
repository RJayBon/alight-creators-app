import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/file_service.dart';
import '../../services/user_service.dart';
import '../../theme.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/section_title.dart';
import '../../widgets/toast.dart';
import '../admin/admin_messages_screen.dart';
import '../admin/admin_users_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/public_profile_screen.dart';
import 'about_tab.dart';
import 'settings_screen.dart';

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  Future<void> _deleteAccount(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete account?',
      message:
          'Your account, tutorials, and uploaded files will be permanently removed. This cannot be undone.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok) return;

    final id = AuthService.instance.currentUser?.userId;
    if (id == null) return;

    try {
      await UserService.instance.deleteUser(id);
      await AuthService.instance.logOut();
      if (!context.mounted) return;
      Toast.show(context, 'Account deleted.');
      Navigator.of(context).pushNamedAndRemoveUntil('/', (r) => false);
    } catch (e) {
      if (!context.mounted) return;
      Toast.show(context, 'Could not delete account.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    if (user == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        const Center(child: SectionTitle('Profile Settings')),
        const SizedBox(height: 10),
        const Text('Manage your public identity and account.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // ---- Banner header ----
              SizedBox(
                height: 90,
                width: double.infinity,
                child: _BannerHeader(bannerPath: user.bannerPath),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                child: Column(
                  children: [
                    Transform.translate(
                      offset: const Offset(0, -46),
                      child: _Avatar(user: user),
                    ),
                    Transform.translate(
                      offset: const Offset(0, -32),
                      child: Column(
                        children: [
                          Text(user.displayName,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                          Text('@${user.username}',
                              style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    PillButton(
                      label: 'View Public Profile',
                      outlined: true,
                      icon: Icons.visibility_outlined,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PublicProfileScreen(username: user.username),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PillButton(
                      label: 'Edit Profile',
                      icon: Icons.edit_outlined,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const EditProfileScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PillButton(
                      label: 'Settings',
                      outlined: true,
                      icon: Icons.settings_outlined,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                    ),
                    if (user.isAdmin) ...[
                      const SizedBox(height: 20),
                      const Divider(color: AppColors.border),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('ADMIN',
                            style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.2)),
                      ),
                      const SizedBox(height: 10),
                      PillButton(
                        label: 'Manage Users',
                        outlined: true,
                        icon: Icons.people_outline,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminUsersScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      PillButton(
                        label: 'Contact Messages',
                        outlined: true,
                        icon: Icons.mail_outline,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AdminMessagesScreen(),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    PillButton(
                      label: 'Log Out',
                      outlined: true,
                      icon: Icons.logout,
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: 'Log out?',
                            message: 'You will need to log in again.',
                            confirmLabel: 'Log Out');
                        if (ok) {
                          await AuthService.instance.logOut();
                          if (context.mounted) {
                            Navigator.of(context)
                                .pushNamedAndRemoveUntil('/', (r) => false);
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    PillButton(
                      label: 'Delete Account',
                      outlined: true,
                      danger: true,
                      icon: Icons.delete_outline,
                      onPressed: () => _deleteAccount(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AboutScreen(),
          )),
          child: const Text('About Alight Creators',
              style: TextStyle(color: AppColors.accent)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar: shows the saved image file if one exists, otherwise initials.
// ---------------------------------------------------------------------------
class _Avatar extends StatelessWidget {
  const _Avatar({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.background,
        border: Border.all(color: AppColors.accent, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: FutureBuilder<File?>(
        // Rebuild the future each time the widget rebuilds — cheap, and it
        // picks up the new file after the user saves a new avatar.
        key: ValueKey(user.avatarPath),
        future: FileService.instance.resolveFile(user.avatarPath),
        builder: (context, snap) {
          final file = snap.connectionState == ConnectionState.done
              ? snap.data
              : null;
          if (file != null) {
            return Image.file(
              file,
              width: 92,
              height: 92,
              fit: BoxFit.cover,
              cacheWidth: 200,
              errorBuilder: (_, __, ___) => _initials(),
            );
          }
          return _initials();
        },
      ),
    );
  }

  Widget _initials() => Text(
        user.initials,
        style: const TextStyle(
            color: AppColors.accent,
            fontSize: 30,
            fontWeight: FontWeight.w800),
      );
}

// ---------------------------------------------------------------------------
// Banner: shows the saved banner file if one exists, otherwise a gradient.
// ---------------------------------------------------------------------------
class _BannerHeader extends StatelessWidget {
  const _BannerHeader({required this.bannerPath});
  final String? bannerPath;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      key: ValueKey(bannerPath),
      future: FileService.instance.resolveFile(bannerPath),
      builder: (context, snap) {
        final file = snap.connectionState == ConnectionState.done
            ? snap.data
            : null;
        if (file != null) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            cacheWidth: 800,
            errorBuilder: (_, __, ___) => _gradient(),
          );
        }
        return _gradient();
      },
    );
  }

  Widget _gradient() => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF581C87),
              Color(0xFF9333EA),
              Color(0xFF3B82F6),
            ],
          ),
        ),
      );
}