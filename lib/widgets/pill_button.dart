import 'package:flutter/material.dart';

import '../theme.dart';

/// Full-width, pill-shaped button.
///
/// Default = solid cyan. When [outlined] is true it becomes a bordered ghost
/// button. When [danger] is true, the color becomes the destructive red.
/// When [loading] is true the label is replaced by a spinner and the button
/// ignores taps.
class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outlined = false,
    this.danger = false,
    this.icon,
    this.height = 54,
    this.loading = false,
    this.disabled = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool outlined;
  final bool danger;
  final IconData? icon;
  final double height;
  final bool loading;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final mainColor = danger ? AppColors.danger : AppColors.accent;
    final foreground = outlined ? mainColor : AppColors.background;

    final bool isDisabled = disabled || loading;

    final textStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: foreground,
    );

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Opacity(
        opacity: isDisabled ? 0.65 : 1.0,
        child: Material(
          color: outlined ? Colors.transparent : mainColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: outlined
                ? BorderSide(color: mainColor, width: 1.5)
                : BorderSide.none,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: isDisabled ? null : onPressed,
            splashColor: outlined
                ? mainColor.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: loading
                    ? _Spinner(
                        key: const ValueKey('spinner'),
                        color: foreground,
                      )
                    : Row(
                        key: const ValueKey('label'),
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null) ...[
                            Icon(icon, size: 18, color: foreground),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Text(
                              label,
                              style: textStyle,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 20,
      width: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}