import 'dart:io';

import 'package:flutter/material.dart';

import '../../models/tutorial.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/file_service.dart';
import '../../services/tutorial_service.dart';
import '../../services/user_service.dart';
import '../../theme.dart';
import '../../widgets/tutorial_card.dart';
import '../profile/edit_profile_screen.dart';
import '../tutorial/tutorial_detail_screen.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.username});
  final String username;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  AppUser? _user;
  List<Tutorial> _tutorials = [];
  int _received = 0;
  bool _hasLoved = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    AppUser? u = await UserService.instance.getByUsername(widget.username);

    // If the lookup fails AND we're looking at our own profile, this is
    // almost certainly because the user just changed their username from
    // the edit screen. Fall back to the current session's user ID.
    if (u == null) {
      final me = AuthService.instance.currentUser;
      if (me != null && me.userId != null) {
        u = await UserService.instance.getById(me.userId!);
      }
    }

    if (u == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/404');
      return;
    }

    final tuts = await TutorialService.instance.listByUser(u.userId!);
    final stats = await UserService.instance.loveStats(u.userId!);
    final me = AuthService.instance.currentUser;
    bool loved = false;
    if (me != null && me.userId != u.userId) {
      loved = await UserService.instance.hasLoved(me.userId!, u.userId!);
    }
    if (!mounted) return;
    setState(() {
      _user = u;
      _tutorials = tuts;
      _received = stats.received;
      _hasLoved = loved;
      _loading = false;
    });
  }

  Future<void> _toggleLove() async {
    final me = AuthService.instance.currentUser;
    final u = _user;
    if (me == null || u == null) return;
    final loved =
        await UserService.instance.toggleLove(me.userId!, u.userId!);
    final stats = await UserService.instance.loveStats(u.userId!);
    if (!mounted) return;
    setState(() {
      _hasLoved = loved;
      _received = stats.received;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final u = _user!;
    final me = AuthService.instance.currentUser;
    final isSelf = me != null && me.userId == u.userId;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 120,
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF581C87),
                          Color(0xFF9333EA),
                          Color(0xFF3B82F6)
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Transform.translate(
                          offset: const Offset(0, -32),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _avatar(u),
                              _lovesPill(isSelf),
                            ],
                          ),
                        ),
                        Text(u.displayName,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('@${u.username}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                  u.isAdmin ? 'ADMIN' : 'MEMBER',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        if (u.bio.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Text('ABOUT ME',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(u.bio,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  height: 1.4)),
                        ],
                        if (isSelf) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            label: const Text('Edit Profile'),
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const EditProfileScreen(),
                                ),
                              );
                              if (mounted) _load();
                            },
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.accent,
                                side: const BorderSide(
                                    color: AppColors.accent)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Published Tutorials',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            if (_tutorials.isEmpty)
              const Text('No tutorials published yet.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              for (final t in _tutorials)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TutorialCard(
                    tutorial: t,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TutorialDetailScreen(
                            tutorialId: t.tutorialId!),
                      ),
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(AppUser u) {
    return Container(
      width: 76,
      height: 76,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF6B21A8),
        border: Border.all(color: AppColors.background, width: 4),
      ),
      alignment: Alignment.center,
      child: u.avatarPath != null
          ? FutureBuilder<File?>(
              future: FileService.instance.resolveFile(u.avatarPath),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.done &&
                    snap.data != null) {
                  return ClipOval(
                    child: Image.file(
                      snap.data!,
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                      errorBuilder: (_, __, ___) => Text(u.initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800)),
                    ),
                  );
                }
                return Text(u.initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800));
              },
            )
          : Text(u.initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
    );
  }

  Widget _lovesPill(bool isSelf) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF831843).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: const Color(0xFFF43F5E).withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite, size: 14, color: Color(0xFFF43F5E)),
          const SizedBox(width: 6),
          Text('$_received',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ],
      ),
    );
    if (isSelf) return child;
    return GestureDetector(
      onTap: _toggleLove,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: _hasLoved
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.5),
                    blurRadius: 12,
                  ),
                ],
              )
            : null,
        child: child,
      ),
    );
  }
}