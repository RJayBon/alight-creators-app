import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Outlined input with a label row above it.
///
/// The border animates to the cyan accent (plus a soft glow) while focused.
/// Supports single-line, multi-line, password, read-only, and text format
/// restrictions (via [inputFormatters]).
class LabeledField extends StatefulWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.hintText,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.trailing,
    this.prefixIcon,
    this.maxLines = 1,
    this.maxLength,
    this.helperText,
    this.focusNode,
    this.onChanged,
    this.readOnly = false,
    this.inputFormatters,
    this.textInputAction,
    this.autofillHints,
    this.enabled = true,
  });

  final String label;
  final String hintText;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;

  /// Optional widget rendered at the far right of the label row (e.g. "Forgot?").
  final Widget? trailing;
  final IconData? prefixIcon;
  final int maxLines;
  final int? maxLength;
  final String? helperText;
  final FocusNode? focusNode;

  /// Fired on every keystroke — used by forms that need to react live
  /// (e.g. auto-slugging the username from the display name).
  final ValueChanged<String>? onChanged;

  /// Renders the field with muted styling and blocks editing.
  final bool readOnly;

  /// Useful for numeric-only fields (birthdate, etc).
  final List<TextInputFormatter>? inputFormatters;

  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  late final FocusNode _focusNode =
      widget.focusNode ?? (FocusNode()..addListener(_onFocusChange));
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode != null) {
      widget.focusNode!.addListener(_onFocusChange);
    }
  }

  void _onFocusChange() => setState(() => _focused = _focusNode.hasFocus);

  @override
  void dispose() {
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool effectivelyEnabled = widget.enabled && !widget.readOnly;
    final Color borderColor = _focused && effectivelyEnabled
        ? AppColors.accent
        : AppColors.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---------- Label row ----------
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                widget.label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
        const SizedBox(height: 8),

        // ---------- Input container ----------
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: widget.readOnly
                ? AppColors.surface.withValues(alpha: 0.5)
                : AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: _focused && effectivelyEnabled ? 1.5 : 1,
            ),
            boxShadow: _focused && effectivelyEnabled
                ? [
                    BoxShadow(
                      color: AppColors.accent.withValues(alpha: 0.22),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : const [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.obscureText,
            obscuringCharacter: '•',
            keyboardType: widget.keyboardType,
            cursorColor: AppColors.accent,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            maxLength: widget.maxLength,
            onChanged: widget.onChanged,
            readOnly: widget.readOnly || !widget.enabled,
            enabled: widget.enabled,
            inputFormatters: widget.inputFormatters,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            style: TextStyle(
              color: widget.readOnly
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              hintText: widget.hintText,
              prefixIcon: widget.prefixIcon == null
                  ? null
                  : Icon(
                      widget.prefixIcon,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
              hintStyle: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),

        // ---------- Helper text ----------
        if (widget.helperText != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.helperText!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}