import 'dart:io';

import 'package:flutter/material.dart';

import '../services/file_service.dart';
import '../theme.dart';

class ThumbnailPicker extends StatelessWidget {
  const ThumbnailPicker({
    super.key,
    required this.file,
    required this.onPick,
  });

  final File? file;
  final ValueChanged<File?> onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thumbnail',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              width: 110,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
                image: file != null
                    ? DecorationImage(
                        image: ResizeImage(FileImage(file!), width: 400),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: file == null
                  ? const Icon(Icons.image_outlined,
                      color: AppColors.textSecondary)
                  : null,
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () async {
                final img = await FileService.instance.pickImageAsWebp();
                if (img != null) onPick(img);
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
              child: Text(file == null ? 'Choose image' : 'Change image'),
            ),
          ],
        ),
      ],
    );
  }
}