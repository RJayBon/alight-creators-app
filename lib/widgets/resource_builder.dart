import 'package:flutter/material.dart';

import '../theme.dart';

class ResourceDraft {
  ResourceDraft({
    String type = 'preset',
    String name = '',
    String url = '',
  })  : typeValue = type,
        nameCtrl = TextEditingController(text: name),
        urlCtrl = TextEditingController(text: url);

  String typeValue;
  final TextEditingController nameCtrl;
  final TextEditingController urlCtrl;

  void dispose() {
    nameCtrl.dispose();
    urlCtrl.dispose();
  }
}

class ResourceBuilder extends StatelessWidget {
  const ResourceBuilder({
    super.key,
    required this.resources,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  final List<ResourceDraft> resources;
  final VoidCallback onAdd;
  final void Function(int index) onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Downloads & Assets',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18, color: AppColors.accent),
              label: const Text('Add resource',
                  style: TextStyle(
                      color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
            'Share presets, project files, fonts, or any external downloads.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        for (var i = 0; i < resources.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    DropdownButton<String>(
                      value: resources[i].typeValue,
                      dropdownColor: AppColors.surface,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                            value: 'preset',
                            child: Text('🎁 Preset',
                                style: TextStyle(
                                    color: AppColors.textPrimary))),
                        DropdownMenuItem(
                            value: 'asset',
                            child: Text('📦 Asset',
                                style: TextStyle(
                                    color: AppColors.textPrimary))),
                      ],
                      onChanged: (v) {
                        resources[i].typeValue = v ?? 'preset';
                        onChanged();
                      },
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: AppColors.danger),
                      onPressed: () => onRemove(i),
                    ),
                  ],
                ),
                TextField(
                  controller: resources[i].nameCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Resource name (e.g. Preset.xml)',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: resources[i].urlCtrl,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'https://drive.google.com/…',
                    hintStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: AppColors.border)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}