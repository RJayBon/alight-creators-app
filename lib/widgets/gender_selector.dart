import 'package:flutter/material.dart';

import '../theme.dart';

class GenderSelector extends StatelessWidget {
  const GenderSelector({
    super.key,
    required this.value,
    required this.onChanged,
    required this.customController,
  });

  /// 'Male' | 'Female' | 'Others' | null
  final String? value;
  final ValueChanged<String> onChanged;
  final TextEditingController customController;

  @override
  Widget build(BuildContext context) {
    const options = ['Male', 'Female', 'Others'];
    final showCustom = value == 'Others';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final opt in options) ...[
              Expanded(
                child: _Option(
                  label: opt,
                  selected: value == opt,
                  color: opt == 'Male'
                      ? AppColors.maleBlue
                      : opt == 'Female'
                          ? AppColors.femalePink
                          : AppColors.accent,
                  onTap: () => onChanged(opt),
                ),
              ),
              if (opt != options.last) const SizedBox(width: 10),
            ],
          ],
        ),

        // ---- Animated reveal of the "Please specify" field ----
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            opacity: showCustom ? 1.0 : 0.0,
            child: showCustom
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _CustomGenderField(
                      controller: customController,
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ]
              : const [],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? color : AppColors.textSecondary,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _CustomGenderField extends StatefulWidget {
  const _CustomGenderField({required this.controller});
  final TextEditingController controller;

  @override
  State<_CustomGenderField> createState() => _CustomGenderFieldState();
}

class _CustomGenderFieldState extends State<_CustomGenderField> {
  late final FocusNode _focusNode =
      FocusNode()..addListener(_onFocus);

  @override
  void initState() {
    super.initState();
    // Auto-focus once the field appears so the user can type right away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onFocus() => setState(() {});

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? AppColors.accent : AppColors.border,
          width: focused ? 1.5 : 1,
        ),
        boxShadow: focused
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
        style: const TextStyle(color: AppColors.textPrimary),
        decoration: const InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          hintText: 'Please specify',
          hintStyle: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}