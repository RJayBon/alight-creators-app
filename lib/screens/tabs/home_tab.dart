import 'package:flutter/material.dart';

import '../../models/tutorial.dart';
import '../../services/session_service.dart';
import '../../services/tutorial_service.dart';
import '../../theme.dart';
import '../../widgets/section_title.dart';
import '../../widgets/toast.dart';
import '../../widgets/tutorial_card.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.onOpenTutorial});
  final void Function(Tutorial) onOpenTutorial;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<Tutorial> _recommended = [];
  List<Tutorial> _latest = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SessionService.instance.justRegistered) {
        SessionService.instance.setJustRegistered(false);
        Toast.show(context, '🎉 Welcome to Alight Creators!');
      }
    });
  }

  Future<void> _load() async {
    final s = TutorialService.instance;
    final r = await s.recommended(limit: 5);
    final l = await s.latest(limit: 5);
    if (!mounted) return;
    setState(() {
      _recommended = r;
      _latest = l;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final screenW = MediaQuery.of(context).size.width;
    final cellWidth = (screenW - 40 - 12) / 2;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          const _HeroBanner(),
          const SizedBox(height: 28),
          const SectionTitle('Recommended Tutorials'),
          const SizedBox(height: 14),
          _CardRow(
              tutorials: _recommended,
              cardWidth: cellWidth,
              onOpen: widget.onOpenTutorial),
          const SizedBox(height: 28),
          const SectionTitle('Latest Tutorials'),
          const SizedBox(height: 14),
          _CardRow(
              tutorials: _latest,
              cardWidth: cellWidth,
              onOpen: widget.onOpenTutorial),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.tutorials,
    required this.cardWidth,
    required this.onOpen,
  });
  final List<Tutorial> tutorials;
  final double cardWidth;
  final void Function(Tutorial) onOpen;

  @override
  Widget build(BuildContext context) {
    if (tutorials.isEmpty) {
      return const Text('No tutorials yet.',
          style: TextStyle(color: AppColors.textSecondary));
    }
    final rowHeight = cardWidth * 9 / 16 + 120;
    return SizedBox(
      height: rowHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: tutorials.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => TutorialCard(
          tutorial: tutorials[i],
          width: cardWidth,
          onTap: () => onOpen(tutorials[i]),
        ),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 92,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(18)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.surface, Color(0xFF0E2430)],
        ),
        border: Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Expanded(
            flex: 58,
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary,
                        ),
                        children: [
                          TextSpan(text: 'Master '),
                          TextSpan(
                            text: 'Alight Motion',
                            style: TextStyle(color: AppColors.accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Step-by-Step Video Editing Tutorials',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 42,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(0.3, 0),
                      radius: 0.95,
                      colors: [
                        Color(0x2E9333EA),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
                ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.transparent, Colors.white],
                      stops: [0.0, 0.18],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(
                    'assets/images/am-mascot.webp',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    cacheWidth: 500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}