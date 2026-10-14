import 'dart:io';

import 'package:flutter/material.dart';

import '../models/tutorial.dart';
import '../services/file_service.dart';
import '../theme.dart';
import 'category_chip.dart';

class TutorialCard extends StatelessWidget {
  const TutorialCard({
    super.key,
    required this.tutorial,
    required this.onTap,
    this.width,
  });

  final Tutorial tutorial;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _Thumb(tutorial: tutorial),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tutorial.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  CategoryChip(label: tutorial.category),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (width == null) return card;
    return SizedBox(width: width, child: card);
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.tutorial});
  final Tutorial tutorial;

  @override
  Widget build(BuildContext context) {
    final path = tutorial.thumbnailPath;
    if (path != null && path.isNotEmpty) {
      return FutureBuilder<File?>(
        future: FileService.instance.resolveFile(path),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.done &&
              snap.data != null) {
            return Image.file(
              snap.data!,
              fit: BoxFit.cover,
              // Decode at 400px wide — huge memory savings on low-end phones.
              cacheWidth: 400,
              errorBuilder: (_, __, ___) => _placeholder(tutorial.accent),
            );
          }
          return _placeholder(tutorial.accent);
        },
      );
    }
    return _placeholder(tutorial.accent);
  }

  Widget _placeholder(Color accent) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.55),
            AppColors.background,
          ],
        ),
      ),
    );
  }
}