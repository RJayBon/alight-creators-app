import 'package:flutter/material.dart';

import '../theme.dart';

/// Bold white section heading used across the tabs.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.accent = false});

  final String text;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: accent ? AppColors.accent : AppColors.textPrimary,
        fontSize: accent ? 28 : 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    );
  }
}
