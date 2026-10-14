import 'package:flutter/material.dart';

import '../theme.dart';

class StepDraft {
  StepDraft({String title = '', String desc = ''})
      : titleCtrl = TextEditingController(text: title),
        descCtrl = TextEditingController(text: desc);

  final TextEditingController titleCtrl;
  final TextEditingController descCtrl;

  void dispose() {
    titleCtrl.dispose();
    descCtrl.dispose();
  }
}

class StepBuilder extends StatelessWidget {
  const StepBuilder({
    super.key,
    required this.steps,
    required this.onAdd,
    required this.onRemove,
  });

  final List<StepDraft> steps;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Steps',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18, color: AppColors.accent),
              label: const Text('Add step',
                  style: TextStyle(
                      color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < steps.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Step ${i + 1}',
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (steps.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: AppColors.danger, size: 18),
                        onPressed: () => onRemove(i),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: steps[i].titleCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Step title',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: steps[i].descCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Describe what to do in this step…',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}