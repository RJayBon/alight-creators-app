import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../constants.dart';
import '../theme.dart';

/// How far the fullscreen control sits from the true corner of the video box.
///
/// Not zero: the inline player wraps itself in a `ClipRRect` with a 12 px
/// radius, so a button placed exactly on the corner has both its icon and its
/// hit area bitten off by the curve. 2 px is visually flush and still survives
/// the clip.
const double _cornerInset = 2.0;

/// A tutorial clip with the media controls a phone player is expected to have
/// — play/pause, a timeline you can drag, mute, one playback-speed control, an
/// auto-hiding overlay — and deliberately none of the playlist controls (no
/// previous / next).
///
/// Layout, since a player is judged by whether the controls are where your
/// thumb already is: the timeline runs across the bottom and the transport row
/// sits under it — speed, `<<5s`, play/pause, `5s>>`, hide, mute — centered as
/// one group. Fullscreen is pinned to the top-right corner, and nothing else
/// is drawn over the picture (the clip label was removed: Guide ⇄ Result is
/// already stated by the tabs above the player, and a caption burned into the
/// top-left was just covering the video).
///
/// A volume *slider* is deliberately absent: the phone's own volume keys
/// already do that, and a second gain control inside a 16:9 box is one more
/// thing to mis-drag while scrubbing. Mute stays, as a button.
///
/// Two things this widget does on purpose:
///
///  * **It never disposes the controller.** It only attaches/detaches its
///    listener. The host that called `initialize()` owns disposal, which is
///    the only way to guarantee a listener is never left attached to a
///    disposed controller.
///  * **Fullscreen is a route, not a resize.** Pushing an opaque page lets the
///    *clip* fill the screen while the detail screen behind it keeps its scroll
///    position — the pattern `chewie` uses, and the same reason two
///    `VideoPlayer` widgets on one controller are fine: `VideoPlayer` only
///    reads `value.textureId` and registers its own listener.
class AppVideoPlayer extends StatefulWidget {
  const AppVideoPlayer({
    super.key,
    required this.controller,
    this.borderRadius = 0,
    this.isFullScreen = false,
  });

  final VideoPlayerController controller;
  final double borderRadius;

  /// True when this instance *is* the fullscreen page. Flips the corner button
  /// from "enter fullscreen" to "exit" — without it, the fullscreen view would
  /// push a second fullscreen route on top of itself.
  final bool isFullScreen;

  @override
  State<AppVideoPlayer> createState() => _AppVideoPlayerState();
}

class _AppVideoPlayerState extends State<AppVideoPlayer> {
  Timer? _hideTimer;
  bool _controlsVisible = true;
  bool _scrubbing = false;
  double? _scrubValue;

  /// Volume the mute button restores to. `null` means "never touched", in
  /// which case the platform default of 1.0 is assumed.
  double? _volumeBeforeMute;

  static const _hideAfter = Duration(seconds: 4);

  VideoPlayerValue get _v => widget.controller.value;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _controlsVisible = !_v.isInitialized || !_v.isPlaying;
    if (!_controlsVisible) _startHideTimer();
  }

  @override
  void didUpdateWidget(AppVideoPlayer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      setState(() {
        _scrubbing = false;
        _scrubValue = null;
        _controlsVisible = !_v.isInitialized || !_v.isPlaying;
      });
      if (!_controlsVisible) _startHideTimer();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    // Only the listener: the caller owns the controller.
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    // Pausing reveals the controls — that is the one moment you actually want
    // to reach for the scrubber. The `!_controlsVisible` guard matters: this
    // listener also fires on every position tick while playing, and an
    // unguarded reveal there would make the chrome never hide and churn a
    // Timer ~30× a second.
    if (_v.isInitialized && !_v.isPlaying && !_scrubbing && !_controlsVisible) {
      _controlsVisible = true;
      _hideTimer?.cancel();
    }
    setState(() {});
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (mounted && _v.isPlaying && !_scrubbing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls({bool permanently = false}) {
    _hideTimer?.cancel();
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    if (!permanently && _v.isPlaying) _startHideTimer();
  }

  void _toggleControls() {
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  Future<void> _togglePlay() async {
    if (!_v.isInitialized) return;
    HapticFeedback.selectionClick();
    if (_v.isPlaying) {
      await widget.controller.pause();
    } else {
      await widget.controller.play();
    }
    if (!mounted) return;
    if (_v.isPlaying) {
      _startHideTimer();
    } else {
      _showControls(permanently: true);
    }
  }

  Future<void> _seekBy(Duration delta) async {
    if (!_v.isInitialized) return;
    HapticFeedback.selectionClick();
    final target = _v.position + delta;
    if (target < Duration.zero) {
      await widget.controller.seekTo(Duration.zero);
    } else if (target > _v.duration) {
      await widget.controller.seekTo(_v.duration);
    } else {
      await widget.controller.seekTo(target);
    }
    _showControls();
  }

  Future<void> _toggleMute() async {
    // Mute is the only gain control here, so it has to round-trip exactly:
    // remember the level, and never read `value.volume` back after muting (it
    // is 0 by then, which is how "unmute" used to leave the clip silent).
    if (_v.volume > 0) {
      _volumeBeforeMute = _v.volume;
      await widget.controller.setVolume(0);
    } else {
      await widget.controller.setVolume(_volumeBeforeMute ?? 1.0);
    }
    _showControls();
  }

  Future<void> _setSpeed(double speed) async {
    HapticFeedback.selectionClick();
    await widget.controller.setPlaybackSpeed(speed);
    _showControls();
  }

  Future<void> _openSpeedPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Playback speed',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            for (final s in kPlayerSpeeds)
              ListTile(
                dense: true,
                onTap: () => Navigator.of(ctx).pop(s),
                leading: Icon(
                  (s - _v.playbackSpeed).abs() < 0.001
                      ? Icons.check
                      : Icons.circle_outlined,
                  size: 18,
                  color: (s - _v.playbackSpeed).abs() < 0.001
                      ? AppColors.accent
                      : AppColors.textSecondary,
                ),
                title: Text(_speedLabel(s),
                    style: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 14)),
                subtitle: s < 1
                    ? const Text('Slow motion — rewatch a fast step',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 11))
                    : null,
              ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
    if (picked != null) await _setSpeed(picked);
  }

  Future<void> _toggleFullScreen(BuildContext context) async {
    HapticFeedback.selectionClick();
    if (widget.isFullScreen) {
      await Navigator.of(context, rootNavigator: true).maybePop();
      return;
    }
    // A modal page, not a re-layout of the inline box: the clip gets the whole
    // viewport and the detail screen keeps its scroll position underneath.
    await Navigator.of(context, rootNavigator: true).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _FullScreenVideoPage(controller: widget.controller),
    ));
    if (!mounted) return;
    _showControls(permanently: !_v.isPlaying);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  IconData get _volumeIcon {
    if (_v.volume <= 0) return Icons.volume_off_rounded;
    if (_v.volume < 0.5) return Icons.volume_down_rounded;
    return Icons.volume_up_rounded;
  }

  double get _durationMs => _v.duration.inMilliseconds.toDouble();

  /// Scrubber position in milliseconds, already inside the clip's range.
  ///
  /// The `.toDouble()` calls are load-bearing, not decoration: `clamp` is
  /// declared on `num`, so a double receiver clamped between *int* bounds is
  /// inferred as `num`, and `num` is not a valid return value for a `double`
  /// getter (nor a valid `Slider.value`). Every operand here is a double.
  double get _scrubValueMs {
    final double ms = _v.duration.inMilliseconds.toDouble();
    if (_scrubValue != null && ms > 0) {
      return _scrubValue!.clamp(0.0, 1.0).toDouble() * ms;
    }
    return _v.position.inMilliseconds.toDouble().clamp(0.0, ms).toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final initialized = _v.isInitialized;

    // The overlay is a sibling of the video *inside the same box*, so the
    // gradient scrim runs to the true edges and nothing can spill past the
    // rounded frame. Padding therefore only moves the controls, never the
    // background — which is what the first revision got wrong.
    Widget stack = Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.antiAlias,
      children: [
        if (initialized)
          VideoPlayer(widget.controller)
        else
          Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: _v.hasError
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('This clip could not be played.',
                        style: TextStyle(color: Colors.white70, fontSize: 13)),
                  )
                : const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white70),
                  ),
          ),
        if (initialized && !_v.hasError)
          _PlayerOverlay(
            visible: _controlsVisible,
            isPlaying: _v.isPlaying,
            isFullScreen: widget.isFullScreen,
            speed: _v.playbackSpeed,
            volume: _v.volume,
            volumeIcon: _volumeIcon,
            position: _fmt(_v.position),
            duration: _fmt(_v.duration),
            durationMs: _durationMs,
            scrubValueMs: _scrubValueMs,
            onTapSurface: _toggleControls,
            onTogglePlay: _togglePlay,
            onRewind: () => _seekBy(const Duration(seconds: -5)),
            onForward: () => _seekBy(const Duration(seconds: 5)),
            onToggleMute: _toggleMute,
            onPickSpeed: () => _openSpeedPicker(context),
            onFullScreen: () => _toggleFullScreen(context),
            onScrubStart: (fraction) => setState(() {
              _scrubbing = true;
              _scrubValue = fraction;
            }),
            onScrubUpdate: (fraction) => setState(() => _scrubValue = fraction),
            onScrubEnd: (fraction) async {
              final ms = _v.duration.inMilliseconds;
              if (ms > 0) {
                final target = (fraction * ms).round();
                await widget.controller
                    .seekTo(Duration(milliseconds: target < 0 ? 0 : target));
              }
              if (!mounted) return;
              setState(() {
                _scrubbing = false;
                _scrubValue = null;
              });
              _showControls(permanently: !_v.isPlaying);
            },
          ),
      ],
    );

    if (widget.borderRadius > 0) {
      stack = ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: stack,
      );
    }
    return ColoredBox(color: Colors.black, child: stack);
  }
}

/// The chrome. Stateless on purpose: every bit of behaviour is a callback down
/// from [_AppVideoPlayerState], so nothing here can call `setState` on a widget
/// that does not own the state.
class _PlayerOverlay extends StatelessWidget {
  const _PlayerOverlay({
    required this.visible,
    required this.isPlaying,
    required this.isFullScreen,
    required this.speed,
    required this.volume,
    required this.volumeIcon,
    required this.position,
    required this.duration,
    required this.durationMs,
    required this.scrubValueMs,
    required this.onTapSurface,
    required this.onTogglePlay,
    required this.onRewind,
    required this.onForward,
    required this.onToggleMute,
    required this.onPickSpeed,
    required this.onFullScreen,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
  });

  final bool visible;
  final bool isPlaying;
  final bool isFullScreen;
  final double speed;

  /// 0 when muted — drives the tooltip text, since there is no slider left to
  /// show the level.
  final double volume;
  final IconData volumeIcon;
  final String position;
  final String duration;
  final double durationMs;
  final double scrubValueMs;
  final VoidCallback onTapSurface;
  final Future<void> Function() onTogglePlay;
  final Future<void> Function() onRewind;
  final Future<void> Function() onForward;
  final Future<void> Function() onToggleMute;
  final Future<void> Function() onPickSpeed;
  final Future<void> Function() onFullScreen;
  final void Function(double) onScrubStart;
  final void Function(double) onScrubUpdate;
  final Future<void> Function(double) onScrubEnd;

  @override
  Widget build(BuildContext context) {
    // No clip on the overlay itself: the video is already inside a
    // `clipBehavior: Clip.antiAlias` Stack, and clipping twice is how the
    // rounded corners used to cut the scrim into a hard rectangle.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTapSurface,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Legibility scrim, painted edge-to-edge. Literal ARGB instead of
              // `Colors.black.withValues(...)` so the whole DecoratedBox stays
              // const: 0x99 = 0.6 alpha, 0xBF = 0.75.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x99000000),
                      Color(0x00000000),
                      Color(0xBF000000),
                    ],
                    stops: [0.0, 0.45, 1.0],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      kPlayerControlInset, 0, kPlayerControlInset, kPlayerControlInset),
                  child: _bottomChrome(context),
                ),
              ),
              Positioned(
                top: _cornerInset,
                right: _cornerInset,
                child: _RoundButton(
                    icon: isFullScreen
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    tooltip: isFullScreen ? 'Exit fullscreen' : 'Fullscreen',
                    onTap: () => onFullScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Timeline across the bottom, transport row under it.
  ///
  /// `crossAxisAlignment: center` is what keeps the play button on the
  /// box's vertical axis; the first Row (which contains the `Expanded`
  /// slider) is what stretches the block to the full width. `stretch` would
  /// have been the trap here — it forces the transport Row wide and silently
  /// left-aligns its children, undoing the centering.
  Widget _bottomChrome(BuildContext context) {
    const timeStyle = TextStyle(
        color: Colors.white, fontSize: 10, fontFamily: 'monospace');
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Text(position, style: timeStyle),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: AppColors.accent,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: AppColors.accent,
                  overlayColor: AppColors.accent.withValues(alpha: 0.18),
                  trackShape: const RectangularSliderTrackShape(),
                ),
                child: Slider(
                  max: durationMs > 0 ? durationMs : 1.0,
                  value: scrubValueMs
                      .clamp(0.0, durationMs > 0 ? durationMs : 1.0)
                      .toDouble(),
                  onChangeStart: (ms) => onScrubStart(_fraction(ms)),
                  onChanged: (ms) => onScrubUpdate(_fraction(ms)),
                  onChangeEnd: (ms) => onScrubEnd(_fraction(ms)),
                ),
              ),
            ),
            Text(duration, style: timeStyle),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SpeedChip(speed: speed, onTap: () => onPickSpeed()),
            const SizedBox(width: 10),
            _RoundButton(
                icon: Icons.replay_5_rounded,
                tooltip: 'Back 5 seconds',
                onTap: onRewind),
            const SizedBox(width: 6),
            _RoundButton(
              big: true,
              icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              tooltip: isPlaying ? 'Pause' : 'Play',
              onTap: onTogglePlay,
            ),
            const SizedBox(width: 6),
            _RoundButton(
                icon: Icons.forward_5_rounded,
                tooltip: 'Forward 5 seconds',
                onTap: onForward),
            const SizedBox(width: 10),
            _RoundButton(
                icon: Icons.visibility_off_rounded,
                tooltip: 'Hide controls (tap the video to bring them back)',
                onTap: onTapSurface),
            const SizedBox(width: 6),
            _RoundButton(
              icon: volumeIcon,
              tooltip: volume <= 0 ? 'Unmute' : 'Mute',
              onTap: onToggleMute,
            ),
          ],
        ),
      ],
    );
  }

  double _fraction(double ms) => durationMs > 0
      ? (ms / durationMs).clamp(0.0, 1.0).toDouble()
      : 0.0;
}

/// "1x" / "0.5x" — the label used by both the speed chip and the picker sheet,
/// so the two can never disagree. A plain 'x' rather than U+00D7: it is present
/// in every font the app ships with, and it cannot be mistaken for the start of
/// an identifier inside a string interpolation.
String _speedLabel(double s) {
  final rounded = (s * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return '${rounded.round()}x';
  var text = rounded.toStringAsFixed(2);
  while (text.endsWith('0')) {
    text = text.substring(0, text.length - 1);
  }
  if (text.endsWith('.')) text = text.substring(0, text.length - 1);
  return '${text}x';
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.speed, required this.onTap});

  final double speed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white24),
        ),
        child: Text(
          _speedLabel(speed),
          style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.big = false,
  });

  final IconData icon;
  // VoidCallback, not Future<void> Function(): the hide-control button hands it
  // a plain sync callback, and an async one is assignment-compatible with it.
  final VoidCallback onTap;
  final String? tooltip;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final size = big ? 38.0 : 26.0;
    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: big ? 0.5 : 0.4),
        ),
        child: Icon(icon, size: big ? 26 : 16, color: Colors.white),
      ),
    );
    if (tooltip != null) {
      button = Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Video at the size the phone actually is, with its own controls.
///
/// A route rather than a re-layout: it gives the clip the whole viewport (the
/// detail screen's inline box can never do that) without destroying the widget
/// that owns the controller.
class _FullScreenVideoPage extends StatefulWidget {
  const _FullScreenVideoPage({required this.controller});

  final VideoPlayerController controller;

  @override
  State<_FullScreenVideoPage> createState() => _FullScreenVideoPageState();
}

class _FullScreenVideoPageState extends State<_FullScreenVideoPage> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // A vertical Alight Motion clip should fill the phone upright; forcing it
    // landscape would letterbox a 9:16 video inside a black frame, which is
    // the opposite of what "fullscreen" promises.
    final ratio = widget.controller.value.aspectRatio;
    SystemChrome.setPreferredOrientations(ratio > 0 && ratio < 1
        ? const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]
        : const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
  }

  @override
  void dispose() {
    // Restoring here (not in the button's onTap) is what makes the system back
    // gesture safe: the bars and the orientation lock always come back.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.controller.value;
    final ratio = v.isInitialized && v.aspectRatio > 0 ? v.aspectRatio : 16 / 9;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          // Fit, not fill: stretching a portrait clip to a landscape viewport
          // is the "why does my tutorial look squashed" complaint.
          aspectRatio: ratio,
          child: AppVideoPlayer(
            controller: widget.controller,
            isFullScreen: true,
          ),
        ),
      ),
    );
  }
}