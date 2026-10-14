import 'dart:io';

import 'package:flutter/material.dart';

import '../../constants.dart';
import '../../models/tutorial.dart';
import '../../services/auth_service.dart';
import '../../services/file_service.dart';
import '../../services/tutorial_service.dart';
import '../../theme.dart';
import '../../utils/category_colors.dart';
import '../../widgets/error_banner.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/pill_button.dart';
import '../../widgets/resource_builder.dart';
import '../../widgets/step_builder.dart';
import '../../widgets/thumbnail_picker.dart';
import '../../widgets/toast.dart';
import '../../widgets/video_source_picker.dart';

class EditTutorialScreen extends StatefulWidget {
  const EditTutorialScreen({super.key, required this.tutorialId});
  final int tutorialId;

  @override
  State<EditTutorialScreen> createState() => _EditTutorialScreenState();
}

class _EditTutorialScreenState extends State<EditTutorialScreen> {
  Tutorial? _t;
  final _title = TextEditingController();
  final _desc = TextEditingController();
  final _guideUrl = TextEditingController();
  final _resultUrl = TextEditingController();
  final _guideFile = ValueNotifier<File?>(null);
  final _resultFile = ValueNotifier<File?>(null);

  File? _thumbnail;
  String _category = 'Beginner';
  final _steps = <StepDraft>[];
  final _resources = <ResourceDraft>[];

  String? _error;
  bool _busy = false;
  bool _loading = true;

  bool _removeThumb = false;
  bool _removeGuide = false;
  bool _removeResult = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _guideUrl.dispose();
    _resultUrl.dispose();
    for (final s in _steps) {
      s.dispose();
    }
    for (final r in _resources) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final t = await TutorialService.instance.getById(widget.tutorialId);
    if (t == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/404');
      return;
    }
    final me = AuthService.instance.currentUser;
    if (me == null) return;
    final canEdit = me.isAdmin || t.userId == me.userId;
    if (!canEdit) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/404');
      return;
    }
    final steps = await TutorialService.instance.stepsFor(widget.tutorialId);
    final res = await TutorialService.instance.resourcesFor(widget.tutorialId);

    _title.text = t.title;
    _desc.text = t.description;
    _guideUrl.text = t.guideVideoUrl ?? '';
    _resultUrl.text = t.resultVideoUrl ?? '';
    _category = t.category;

    _steps
      ..clear()
      ..addAll(steps.map(
          (s) => StepDraft(title: s.stepTitle, desc: s.stepDescription)));
    if (_steps.isEmpty) _steps.add(StepDraft());

    _resources
      ..clear()
      ..addAll(res.map((r) => ResourceDraft(
          type: r.resourceType, name: r.resourceName, url: r.resourceUrl)));

    if (!mounted) return;
    setState(() {
      _t = t;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (_title.text.trim().isEmpty || _desc.text.trim().isEmpty) {
      setState(() => _error = 'Title and description are required.');
      return;
    }
    final cleanedSteps = _steps
        .where((s) =>
            s.titleCtrl.text.trim().isNotEmpty &&
            s.descCtrl.text.trim().isNotEmpty)
        .map((s) => TutorialStep(
              stepNumber: 0,
              stepTitle: s.titleCtrl.text.trim(),
              stepDescription: s.descCtrl.text.trim(),
            ))
        .toList();
    if (cleanedSteps.isEmpty) {
      setState(() => _error = 'Please add at least one complete step.');
      return;
    }

    setState(() => _busy = true);

    final written = <String>[];
    final oldPathsToDelete = <String?>[];

    try {
      final extra = <String, dynamic>{};

      if (_removeThumb) {
        extra['thumbnail_path'] = null;
        if (_t!.thumbnailPath != null) oldPathsToDelete.add(_t!.thumbnailPath);
      } else if (_thumbnail != null) {
        final p = await FileService.instance.saveUpload(
          src: _thumbnail!,
          subfolder: 'uploads/thumbnails',
          prefix: 'tut',
          maxBytes: kThumbnailMaxBytes,
        );
        written.add(p);
        extra['thumbnail_path'] = p;
        if (_t!.thumbnailPath != null) oldPathsToDelete.add(_t!.thumbnailPath);
      }

      if (_removeGuide) {
        extra['guide_video_file'] = null;
        if (_t!.guideVideoFile != null) {
          oldPathsToDelete.add(_t!.guideVideoFile);
        }
      } else if (_guideFile.value != null) {
        final p = await FileService.instance.saveUpload(
          src: _guideFile.value!,
          subfolder: 'uploads/videos',
          prefix: 'guide',
          maxBytes: kVideoMaxBytes,
        );
        written.add(p);
        extra['guide_video_file'] = p;
        if (_t!.guideVideoFile != null) {
          oldPathsToDelete.add(_t!.guideVideoFile);
        }
      }

      if (_removeResult) {
        extra['result_video_file'] = null;
        if (_t!.resultVideoFile != null) {
          oldPathsToDelete.add(_t!.resultVideoFile);
        }
      } else if (_resultFile.value != null) {
        final p = await FileService.instance.saveUpload(
          src: _resultFile.value!,
          subfolder: 'uploads/videos',
          prefix: 'result',
          maxBytes: kVideoMaxBytes,
        );
        written.add(p);
        extra['result_video_file'] = p;
        if (_t!.resultVideoFile != null) {
          oldPathsToDelete.add(_t!.resultVideoFile);
        }
      }

      extra['guide_video_url'] =
          _guideUrl.text.trim().isEmpty ? null : _guideUrl.text.trim();
      extra['result_video_url'] =
          _resultUrl.text.trim().isEmpty ? null : _resultUrl.text.trim();

      final resources = _resources
          .where((r) =>
              r.nameCtrl.text.trim().isNotEmpty &&
              r.urlCtrl.text.trim().isNotEmpty)
          .map((r) => TutorialResource(
                resourceType: r.typeValue,
                resourceName: r.nameCtrl.text.trim(),
                resourceUrl: r.urlCtrl.text.trim(),
              ))
          .toList();

      await TutorialService.instance.updateTutorial(
        tutorialId: widget.tutorialId,
        userId: _t!.userId!,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        category: _category,
        extraFields: extra,
        steps: cleanedSteps,
        resources: resources,
      );

      for (final p in oldPathsToDelete) {
        await FileService.instance.deleteFile(p);
      }

      if (!mounted) return;
      Toast.show(context, 'Tutorial updated.');
      Navigator.of(context).pop(true);
    } catch (e) {
      for (final p in written) {
        await FileService.instance.deleteFile(p);
      }
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _categoryDropdown() {
    const opts = ['Beginner', 'Intermediate', 'Advanced', 'Tips & Tricks'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Category',
            style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _category,
              isExpanded: true,
              dropdownColor: AppColors.surface,
              items: opts
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accentForCategory(c)),
                            ),
                            const SizedBox(width: 10),
                            Text(c,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15)),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _category = v ?? _category),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Edit Tutorial'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            if (AuthService.instance.isAdmin &&
                _t!.userId != AuthService.instance.currentUser!.userId)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4)),
                ),
                child: const Text(
                    "Admin mode — editing another user's tutorial.",
                    style:
                        TextStyle(color: AppColors.accent, fontSize: 12)),
              ),
            LabeledField(
                label: 'Title', hintText: 'Title', controller: _title),
            const SizedBox(height: 16),
            _categoryDropdown(),
            const SizedBox(height: 16),
            ThumbnailPicker(
              file: _thumbnail,
              onPick: (f) => setState(() => _thumbnail = f),
            ),
            if (_t!.thumbnailPath != null)
              CheckboxListTile(
                value: _removeThumb,
                onChanged: (v) =>
                    setState(() => _removeThumb = v ?? false),
                title: const Text('Remove current thumbnail',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                activeColor: AppColors.accent,
                dense: true,
              ),
            const SizedBox(height: 16),
            VideoSourcePicker(
                title: 'Guiding Video',
                urlController: _guideUrl,
                fileNotifier: _guideFile),
            if (_t!.guideVideoFile != null)
              CheckboxListTile(
                value: _removeGuide,
                onChanged: (v) =>
                    setState(() => _removeGuide = v ?? false),
                title: const Text('Remove current guide video file',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                activeColor: AppColors.accent,
                dense: true,
              ),
            const SizedBox(height: 16),
            LabeledField(
                label: 'Short Description',
                hintText: 'Description',
                controller: _desc,
                maxLines: 3),
            const SizedBox(height: 20),
            StepBuilder(
              steps: _steps,
              onAdd: () => setState(() => _steps.add(StepDraft())),
              onRemove: (i) => setState(() => _steps.removeAt(i).dispose()),
            ),
            const SizedBox(height: 20),
            ResourceBuilder(
              resources: _resources,
              onAdd: () => setState(() => _resources.add(ResourceDraft())),
              onRemove: (i) =>
                  setState(() => _resources.removeAt(i).dispose()),
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 20),
            VideoSourcePicker(
                title: 'Result Video',
                urlController: _resultUrl,
                fileNotifier: _resultFile),
            if (_t!.resultVideoFile != null)
              CheckboxListTile(
                value: _removeResult,
                onChanged: (v) =>
                    setState(() => _removeResult = v ?? false),
                title: const Text('Remove current result video file',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
                activeColor: AppColors.accent,
                dense: true,
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 20),
            PillButton(
                label: 'Save Changes', onPressed: _submit, loading: _busy),
          ],
        ),
      ),
    );
  }
}