import 'package:flutter/material.dart';

import '../theme.dart';

/// Category badge — colours match the web's `.badge-beginner`,
/// `.badge-intermediate`, `.badge-advanced`, and `.badge-tip` classes.
class CategoryChip extends StatelessWidget {
  const CategoryChip({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colorsFor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  (Color fg, Color bg) _colorsFor(String category) {
    switch (category) {
      case 'Beginner':
        // Web: .badge-beginner → accent (mint) text on 15% mint bg
        return (
          AppColors.accentMint,
          AppColors.accentMint.withValues(alpha: 0.15),
        );
      case 'Intermediate':
        // Web: .badge-intermediate → primary (cyan) text on 15% cyan bg
        return (
          AppColors.accent,
          AppColors.accent.withValues(alpha: 0.15),
        );
      case 'Advanced':
        // Web: .badge-advanced → secondary (purple) text on 15% purple bg
        return (
          AppColors.secondary,
          AppColors.secondary.withValues(alpha: 0.15),
        );
      case 'Tips & Tricks':
      default:
        // Web: .badge-tip → muted-foreground text on muted bg
        return (
          AppColors.textSecondary,
          AppColors.border,
        );
    }
  }
}