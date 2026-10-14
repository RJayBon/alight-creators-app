import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../models/tutorial.dart';
import '../../services/auth_service.dart';
import '../../services/file_service.dart';
import '../../services/tutorial_service.dart';
import '../../theme.dart';
import '../../widgets/app_video_player.dart';
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
  /// Which of the tutorial's clips the player is showing. A tutorial has at
  /// most two — the guide and the result — so this is a two-way switch, not a
  /// playlist (hence no next/previous anywhere in the player).
  bool _showResult = false;

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

  /// `launchUrl(Uri.parse(raw))` throws FormatException on a malformed URL
  /// and returns false when no browser is installed; both used to be invisible
  /// failures (an unhandled async error / a dead button).
  Future<void> _openResource(BuildContext context, String raw) async {
    final uri = Uri.tryParse(raw.trim());
    var ok = false;
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.hasAuthority) {
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ok = false;
      }
    }
    if (!ok && context.mounted) {
      Toast.show(context, 'That download link is not a valid web address.',
          isError: true);
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
      // `deleteTutorialWithFiles` also unlinks the thumbnail + both videos;
      // deleting only the row leaked every uploaded byte forever.
      final gone =
          await TutorialService.instance.deleteTutorialWithFiles(
              widget.tutorialId);
      if (!mounted) return;
      if (!gone) {
        Toast.show(context, 'That tutorial was already removed.',
            isError: true);
        Navigator.of(context).pop(true);
        return;
      }
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
            _videoSection(t),
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
                  tooltip: 'Open link',
                  icon: const Icon(Icons.download,
                      color: AppColors.accent, size: 20),
                  onPressed: () => _openResource(context, r.resourceUrl),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Guide / Result switch + the player host.
  ///
  /// Before this, `result_video_file` was stored, listed for deletion and
  /// rendered in the composer preview — but the detail screen only ever wired
  /// up the *guide* clip, so a "here's what you'll end up making" video was
  /// invisible on the one screen people actually watch.
  Widget _videoSection(Tutorial t) {
    final hasGuide = t.hasGuideVideo;
    final hasResult = t.hasResultVideo;
    if (!hasGuide || !hasResult) {
      // One clip only: no tabs to pretend at, but still prefer whichever clip
      // actually exists (a tutorial can ship just a result video).
      return Align(
        alignment: Alignment.centerLeft,
        child: _VideoThumb(
          key: ValueKey('video-${t.tutorialId}-single'),
          tutorial: t,
          showResult: !hasGuide && hasResult,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              for (final entry in const <String, bool>{
                  'Guide clip': false,
                  'Result clip': true,
                }.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _showResult = entry.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _showResult == entry.value
                            ? AppColors.accent
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: _showResult == entry.value
                                ? AppColors.accent
                                : AppColors.border),
                      ),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _showResult == entry.value
                                ? AppColors.background
                                : AppColors.textSecondary),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // The key rebuilds the host (and disposes the old controller) when the
        // clip changes, instead of mutating a live VideoPlayerController.
        _VideoThumb(
          key: ValueKey('video-${t.tutorialId}-$_showResult'),
          tutorial: t,
          showResult: _showResult,
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

/// Player host for one tutorial clip.
///
/// Owns the `VideoPlayerController`: created here, disposed here — both on
/// teardown and when the widget is given a different tutorial/clip
/// (`didUpdateWidget`). The overlay deliberately does *not* dispose it, so
/// there is exactly one owner and no path where the overlay outlives a
/// controller it is still listening to.
///
/// Still lazy: nothing is decoded until the viewer taps, so a detail screen
/// opened from the feed does not spin up a media codec for a video nobody
/// asked to watch.
class _VideoThumb extends StatefulWidget {
  const _VideoThumb({
    super.key,
    required this.tutorial,
    required this.showResult,
  });

  final Tutorial tutorial;

  /// false → the guide clip, true → the finished result.
  final bool showResult;

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

  @override
  void didUpdateWidget(_VideoThumb old) {
    super.didUpdateWidget(old);
    final changed = old.tutorial.tutorialId != widget.tutorial.tutorialId ||
        old.showResult != widget.showResult;
    if (changed && _controller != null) {
      // Switching Guide ⇄ Result must release the old codec handle, otherwise
      // both clips stay resident and the visible player keeps seeking the
      // hidden one.
      final stale = _controller;
      _controller = null;
      _loading = false;
      stale?.dispose();
    }
  }

  String? get _file => widget.showResult
      ? widget.tutorial.resultVideoFile
      : widget.tutorial.guideVideoFile;

  String? get _url => widget.showResult
      ? widget.tutorial.resultVideoUrl
      : widget.tutorial.guideVideoUrl;

  bool get _hasLocal => (_file ?? '').isNotEmpty;
  bool get _hasAny => _hasLocal || (_url ?? '').isNotEmpty;

  String get _clipName => widget.showResult ? 'result clip' : 'guide clip';

  String get _emptyHint =>
      _hasAny ? 'Tap to play the $_clipName' : 'No $_clipName provided';

  /// The creator's thumbnail for this tutorial, when it is on this device.
  ///
  /// `resolveFileSync` rather than the async variant, because this is called
  /// from `build()`: a Future here means a new Future (and a rebuild flash) on
  /// every parent rebuild — the exact bug `tutorial_card.dart` had.
  File? get _poster {
    final path = widget.tutorial.thumbnailPath;
    if (path == null || path.isEmpty) return null;
    return FileService.instance.resolveFileSync(path);
  }

  Future<void> _onPlayTap() async {
    if (_hasLocal) {
      setState(() => _loading = true);
      try {
        final f = await FileService.instance
            .resolveFile(_file)
            .timeout(const Duration(seconds: 3));
        if (f != null) {
          final vc = VideoPlayerController.file(f);
          await vc.initialize().timeout(const Duration(seconds: 8));
          // Looping stays on: this is a step-by-step clip you re-watch, and
          // the overlay has no next-clip button to fall back on.
          await vc.setLooping(true);
          if (!mounted) {
            vc.dispose();
            return;
          }
          await vc.play();
          setState(() {
            _controller = vc;
            _loading = false;
          });
          return;
        }
        // Row references a file that is not on this device (imported DB, or
        // the uploads folder was cleared) — an external URL, if the creator
        // supplied one, is the only remaining source.
      } catch (e) {
        debugPrint('[_VideoThumb] init failed: $e');
      }
      if (mounted) setState(() => _loading = false);
    }

    if ((_url ?? '').isNotEmpty) {
      try {
        await launchUrl(Uri.parse(_url!), mode: LaunchMode.externalApplication);
        return;
      } catch (_) {}
    }

    if (mounted) {
      Toast.show(context, 'Video not available on this device.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller != null) {
      final v = _controller!.value;
      return AspectRatio(
        aspectRatio:
            v.isInitialized && v.aspectRatio > 0 ? v.aspectRatio : 16 / 9,
        child: AppVideoPlayer(controller: _controller!, borderRadius: 12),
      );
    }

    // ---------- Poster ----------
    // The tutorial's own thumbnail, not a category-coloured gradient: the
    // gradient showed up on every tutorial that *had* an uploaded poster, so
    // the detail screen looked broken while the feed card next to it looked
    // right. The gradient stays as the fallback for a missing file.
    final poster = _poster;
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
            if (poster != null)
              Image.file(
                poster,
                fit: BoxFit.cover,
                cacheWidth: 800,
                // A torn or unsupported file must not paint a red error box
                // over an otherwise fine tutorial.
                errorBuilder: (_, __, ___) => _posterGradient(),
              )
            else
              _posterGradient(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Color(0x00000000),
                    Color(0x99000000),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Center(
              child: GestureDetector(
                onTap: _loading ? null : (_hasAny ? _onPlayTap : null),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.55),
                    border: Border.all(
                        color: _hasAny
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        width: 2),
                  ),
                  alignment: Alignment.center,
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.accent),
                        )
                      : Icon(
                          Icons.play_arrow_rounded,
                          size: 38,
                          color: _hasAny
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              bottom: 8,
              right: 10,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _emptyHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (widget.showResult)
                    const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Text('RESULT',
                          style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posterGradient() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            widget.tutorial.accent.withValues(alpha: 0.55),
            AppColors.background,
          ],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}