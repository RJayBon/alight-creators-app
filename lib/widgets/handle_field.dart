import 'package:flutter/material.dart';
import '../theme.dart';

class HandleField extends StatelessWidget {
  const HandleField({
    super.key,
    required this.controller,
    this.helper,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? helper;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Username (Unique Handle)',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 14),
                child: Text('@',
                    style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700)),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  autocorrect: false,
                  onChanged: (v) {
                    final cleaned = v
                        .toLowerCase()
                        .replaceAll(RegExp(r'[^a-z0-9_]'), '_');
                    if (cleaned != v) {
                      controller.value = TextEditingValue(
                        text: cleaned,
                        selection: TextSelection.collapsed(
                            offset: cleaned.length),
                      );
                    }
                    onChanged?.call(cleaned);
                  },
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    hintText: 'username',
                    hintStyle: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (helper != null) ...[
          const SizedBox(height: 6),
          Text(helper!,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ],
      ],
    );
  }
}