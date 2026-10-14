import 'dart:io';

import 'package:flutter/material.dart';

import '../services/file_service.dart';
import '../theme.dart';

class VideoSourcePicker extends StatefulWidget {
  const VideoSourcePicker({
    super.key,
    required this.title,
    required this.urlController,
    required this.fileNotifier,
  });

  final String title;
  final TextEditingController urlController;
  final ValueNotifier<File?> fileNotifier;

  @override
  State<VideoSourcePicker> createState() => _VideoSourcePickerState();
}

class _VideoSourcePickerState extends State<VideoSourcePicker> {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<File?>(
      valueListenable: widget.fileNotifier,
      builder: (context, file, _) {
        final hasFile = file != null;
        final hasUrl = widget.urlController.text.trim().isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ---- URL field (hidden once a file is chosen) ----
                  if (!hasFile)
                    TextField(
                      controller: widget.urlController,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'YouTube or any URL…',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),

                  // ---- OR divider (shown only when neither is set) ----
                  if (!hasFile && !hasUrl)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('OR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),

                  // ---- Choose / change file button (full-width) ----
                  if (!hasUrl)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: Icon(
                          hasFile
                              ? Icons.check_circle_outline
                              : Icons.upload_file,
                          size: 18,
                        ),
                        label: Text(
                          hasFile
                              ? file.path.split(Platform.pathSeparator).last
                              : 'Choose video file',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                        onPressed: () async {
                          final f = await FileService.instance.pickVideo();
                          if (f != null) {
                            widget.urlController.clear();
                            widget.fileNotifier.value = f;
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.accent,
                          side: const BorderSide(color: AppColors.accent),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),

                  // ---- Remove file link ----
                  if (hasFile)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => widget.fileNotifier.value = null,
                        child: const Text('Remove file',
                            style: TextStyle(color: AppColors.danger)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}