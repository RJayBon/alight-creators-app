import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../models/tutorial.dart';
import '../../services/auth_service.dart';
import '../../services/file_service.dart';
import '../../services/tutorial_service.dart';
import '../../theme.dart';
import '../../widgets/category_chip.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/rating_stars.dart';
import '../../widgets/share_modal.dart';
import '../../widgets/toast.dart';
import 'edit_tutorial_screen.dart';

class TutorialDetailScreen extends StatefulWidget {
  const TutorialDetailScreen({super.key, required this.tutorialId});
  final int tutorialId;

  @override
  State<TutorialDetailScreen> createState() => _TutorialDetailScreenState();
}

class _TutorialDetailScreenState extends State<TutorialDetailScreen> {
  Tutorial? _tutorial;
  List<TutorialStep> _steps = [];
  List<TutorialResource> _resources = [];
  ({int total, double avgQuality, double avgClarity})? _stats;
  ({int quality, int clarity})? _myRating;
  int _selQuality = 0;
  int _selClarity = 0;
  bool _busy = false;
  String? _feedback;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = TutorialService.instance;
      final t = await s.getById(widget.tutorialId);
      if (t == null) {
        if (mounted) Navigator.of(context).pushReplacementNamed('/404');
        return;
      }

      List<TutorialStep> steps = [];
      List<TutorialResource> res = [];
      ({int total, double avgQuality, double avgClarity}) stats =
          (total: 0, avgQuality: 0, avgClarity: 0);
      ({int quality, int clarity})? mine;

      try { steps = await s.stepsFor(widget.tutorialId); } catch (_) {}
      try { res   = await s.resourcesFor(widget.tutorialId); } catch (_) {}
      try { stats = await s.ratingStats(widget.tutorialId); } catch (_) {}

      final me = AuthService.instance.currentUser;
      if (me != null) {
        try {
          mine = await s.userRating(
              tutorialId: widget.tutorialId, userId: me.userId!);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _tutorial = t;
        _steps = steps;
        _resources = res;
        _stats = stats;
        _myRating = mine;
        _selQuality = mine?.quality ?? 0;
        _selClarity = mine?.clarity ?? 0;
      });

      if (me != null && t.userId != null && me.userId != t.userId) {
        s
            .recordView(
              tutorialId: widget.tutorialId,
              authorId: t.userId!,
              viewerId: me.userId!,
            )
            .catchError((_) {});
      }
    } catch (e) {
      if (mounted) setState(() => _loadError = e.toString());
    }
  }

  void _share() {
    showDialog(
      context: context,
      builder: (_) => ShareModal(tutorialId: widget.tutorialId),
    );
  }

  Future<void> _submitRating() async {
    final me = AuthService.instance.currentUser;
    if (me == null) return;
    if (_selQuality == 0 || _selClarity == 0) {
      setState(() => _feedback = 'Please select stars for both categories.');
      return;
    }
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      await TutorialService.instance.upsertRating(
        tutorialId: widget.tutorialId,
        userId: me.userId!,
        quality: _selQuality,
        clarity: _selClarity,
      );
      final stats =
          await TutorialService.instance.ratingStats(widget.tutorialId);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stats = stats;
        _myRating = (quality: _selQuality, clarity: _selClarity);
        _feedback = '✓ Rating saved';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _feedback = 'Could not save rating.';
      });
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context,
        title: 'Delete tutorial?',
        message:
            'This cannot be undone. All steps, ratings, and uploaded files will be removed.',
        confirmLabel: 'Delete',
        danger: true);
    if (!ok) return;
    try {
      await TutorialService.instance.deleteTutorial(widget.tutorialId);
      if (!mounted) return;
      Toast.show(context, 'Tutorial deleted.');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      Toast.show(context, 'Delete failed.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          title: const Text('Tutorial'),
        ),
        body: Center(
          child: Text(_loadError!,
              style: const TextStyle(color: AppColors.danger)),
        ),
      );
    }

    final t = _tutorial;
    if (t == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          title: const Text('Tutorial'),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    final me = AuthService.instance.currentUser;
    final isAuthor = me != null && t.userId == me.userId;
    final isAdmin = me?.isAdmin ?? false;
    final canManage = isAuthor || isAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text('Tutorial',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
              icon: const Icon(Icons.share_outlined), onPressed: _share),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            // ---------- Author ----------
            if (t.authorUsername != null && t.authorUsername!.isNotEmpty)
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed(
                  '/user',
                  arguments: t.authorUsername,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(t.authorName ?? t.authorUsername!,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            const SizedBox(height: 8),

            // ---------- Meta ----------
            Row(
              children: [
                CategoryChip(label: t.category),
                const SizedBox(width: 10),
                Text('${t.views} views',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                const Spacer(),
                if (canManage) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 15),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditTutorialScreen(
                            tutorialId: widget.tutorialId),
                      ),
                    ),
                    label: const Text('Edit',
                        style: TextStyle(color: AppColors.accent)),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline,
                        size: 15, color: AppColors.danger),
                    onPressed: _delete,
                    label: const Text('Delete',
                        style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // ---------- Title + description ----------
            Text(t.title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(t.description,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 15,
                    height: 1.6)),
            const SizedBox(height: 20),

            // ---------- Video ----------
            _VideoThumb(tutorial: t),
            const SizedBox(height: 24),

            // ---------- Resources ----------
            if (_resources.isNotEmpty) ...[
              _resourcesSection(),
              const SizedBox(height: 20),
            ],

            // ---------- Rating ----------
            if (!isAuthor) _ratingCard(),
            if (isAuthor) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("You can't rate your own tutorial",
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 6),
                    if (_stats != null)
                      Text(
                          '${_stats!.total} ratings · Quality ${_stats!.avgQuality.toStringAsFixed(1)} · Clarity ${_stats!.avgClarity.toStringAsFixed(1)}',
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 13)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // ---------- Steps ----------
            const Text('Step-by-Step',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            if (_steps.isEmpty)
              const Text('No steps yet.',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              for (final s in _steps)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Step ${s.stepNumber}',
                          style: const TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(s.stepTitle,
                          style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(s.stepDescription,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                              height: 1.5)),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _resourcesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Downloads & Assets',
            style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        for (final r in _resources)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Text(r.isPreset ? '🎁' : '📦',
                    style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(r.resourceName,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                ),
                IconButton(
                  icon: const Icon(Icons.download,
                      color: AppColors.accent, size: 20),
                  onPressed: () => launchUrl(Uri.parse(r.resourceUrl)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------- FIXED rating card: PillButton NOT wrapped in a Row ----------
  Widget _ratingCard() {
    final stats = _stats;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Rate This Tutorial',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 16)),
              const Spacer(),
              Text('${stats?.total ?? 0} ratings',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Column(
                children: [
                  Text(
                      stats == null || stats.total == 0
                          ? '—'
                          : stats.avgQuality.toStringAsFixed(1),
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const Text('QUALITY',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(width: 20),
              Column(
                children: [
                  Text(
                      stats == null || stats.total == 0
                          ? '—'
                          : stats.avgClarity.toStringAsFixed(1),
                      style: const TextStyle(
                          color: AppColors.accent,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const Text('EASY TO READ',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Quality:',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          RatingStars(
            value: _selQuality,
            onChanged: (v) => setState(() => _selQuality = v),
          ),
          const SizedBox(height: 10),
          const Text('Easy to Read:',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          RatingStars(
            value: _selClarity,
            onChanged: (v) => setState(() => _selClarity = v),
          ),
          const SizedBox(height: 14),
          // PillButton placed directly in the Column — NOT wrapped in a Row.
          PillButton(
            label: _myRating == null ? 'Submit Rating' : 'Update Rating',
            onPressed: _submitRating,
            loading: _busy,
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 8),
            Text(_feedback!,
                style: TextStyle(
                    color: _feedback!.startsWith('✓')
                        ? AppColors.accent
                        : AppColors.danger,
                    fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

/// Lazy video widget — only initializes the video player on user tap.
class _VideoThumb extends StatefulWidget {
  const _VideoThumb({required this.tutorial});
  final Tutorial tutorial;

  @override
  State<_VideoThumb> createState() => _VideoThumbState();
}

class _VideoThumbState extends State<_VideoThumb> {
  VideoPlayerController? _controller;
  bool _loading = false;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onPlayTap() async {
    final t = widget.tutorial;

    if (t.guideVideoFile != null && t.guideVideoFile!.isNotEmpty) {
      setState(() => _loading = true);
      try {
        final f = await FileService.instance
            .resolveFile(t.guideVideoFile)
            .timeout(const Duration(seconds: 3));
        if (f != null) {
          final vc = VideoPlayerController.file(f);
          await vc.initialize().timeout(const Duration(seconds: 8));
          vc.setLooping(true);
          vc.play();
          if (!mounted) {
            vc.dispose();
            return;
          }
          setState(() {
            _controller = vc;
            _loading = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('[_VideoThumb] init failed: $e');
      }
      if (mounted) setState(() => _loading = false);
    }

    if (t.guideVideoUrl != null && t.guideVideoUrl!.isNotEmpty) {
      try {
        await launchUrl(
          Uri.parse(t.guideVideoUrl!),
          mode: LaunchMode.externalApplication,
        );
        return;
      } catch (_) {}
    }

    if (mounted) {
      Toast.show(context, 'Video not available on this device.',
          isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tutorial;

    if (_controller != null && _controller!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_controller!),
              IconButton(
                icon: Icon(
                    _controller!.value.isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    size: 56,
                    color: Colors.white.withValues(alpha: 0.9)),
                onPressed: () {
                  setState(() {
                    _controller!.value.isPlaying
                        ? _controller!.pause()
                        : _controller!.play();
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    if (_loading) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
        ),
      );
    }

    final hasVideo =
        (t.guideVideoFile != null && t.guideVideoFile!.isNotEmpty) ||
        (t.guideVideoUrl != null && t.guideVideoUrl!.isNotEmpty);

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    t.accent.withValues(alpha: 0.55),
                    AppColors.background,
                  ],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(color: Color(0x66000000)),
            ),
            Center(
              child: GestureDetector(
                onTap: hasVideo ? _onPlayTap : null,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.55),
                    border: Border.all(
                        color: hasVideo
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.play_arrow_rounded,
                    size: 40,
                    color: hasVideo
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 10,
              right: 12,
              child: Text(
                hasVideo
                    ? 'Tap to play guide video'
                    : 'No guide video provided',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}