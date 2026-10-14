import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';

/// SVG app icon + the "Alight Creators" wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.fontSize = 28, this.iconSize = 40});

  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/images/icons/icon.svg',
          width: iconSize,
          height: iconSize,
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
              children: const [
                TextSpan(
                  text: 'Alight ',
                  style: TextStyle(color: AppColors.accent),
                ),
                TextSpan(
                  text: 'Creators',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
