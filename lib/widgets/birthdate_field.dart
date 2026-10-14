import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class BirthdateField extends StatefulWidget {
  const BirthdateField({
    super.key,
    required this.controller,
    this.label = 'Birthdate',
  });

  final TextEditingController controller;
  final String label;

  @override
  State<BirthdateField> createState() => _BirthdateFieldState();
}

class _BirthdateFieldState extends State<BirthdateField> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                keyboardType: TextInputType.number,
                inputFormatters: const [_BirthdateInputFormatter()],
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.surface,
                  hintText: 'YYYY-MM-DD',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: () async {
                final now = DateTime.now();
                // Pre-fill the picker with whatever the text field already
                // has, so users can fine-tune instead of starting over.
                DateTime initial = DateTime(now.year - 18);
                final parsed = DateTime.tryParse(widget.controller.text);
                if (parsed != null &&
                    parsed.isBefore(now) &&
                    now.year - parsed.year >= 13) {
                  initial = parsed;
                }
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(now.year - 120),
                  lastDate: now,
                  builder: (ctx, child) => Theme(
                    data: Theme.of(ctx).copyWith(
                      colorScheme: Theme.of(ctx).colorScheme.copyWith(
                            primary: AppColors.accent,
                            onPrimary: AppColors.background,
                            surface: AppColors.surface,
                          ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  widget.controller.text =
                      '${picked.year.toString().padLeft(4, '0')}-'
                      '${picked.month.toString().padLeft(2, '0')}-'
                      '${picked.day.toString().padLeft(2, '0')}';
                  widget.controller.selection = TextSelection.collapsed(
                    offset: widget.controller.text.length,
                  );
                }
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.calendar_today_outlined,
                    color: AppColors.textSecondary, size: 20),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('Optional. Must be 13 or older.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}

/// Formats input as `YYYY-MM-DD` on the fly:
///   • strips everything except digits
///   • caps at 8 digits (4-year + 2-month + 2-day)
///   • inserts dashes after the 4th and 6th digit
///   • preserves the cursor at the end of what the user actually typed
class _BirthdateInputFormatter extends TextInputFormatter {
  const _BirthdateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // 1. Keep only digits.
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');

    // 2. Cap at 8 digits (yyyyMMdd).
    final capped = digits.length > 8 ? digits.substring(0, 8) : digits;

    // 3. Rebuild with dashes.
    final buffer = StringBuffer();
    for (var i = 0; i < capped.length; i++) {
      if (i == 4 || i == 6) buffer.write('-');
      buffer.write(capped[i]);
    }
    final formatted = buffer.toString();

    // 4. Place the cursor at the end — simplest, matches the web's
    //    behaviour where typing appends left-to-right.
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}