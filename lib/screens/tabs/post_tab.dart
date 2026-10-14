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
import '../../widgets/section_title.dart';
import '../../widgets/step_builder.dart';
import '../../widgets/thumbnail_picker.dart';
import '../../widgets/toast.dart';
import '../../widgets/video_source_picker.dart';

class PostTab extends StatefulWidget {
  const PostTab({super.key});
  @override
  State<PostTab> createState() => _PostTabState();
}

class _PostTabState extends State<PostTab> {
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

  @override
  void initState() {
    super.initState();
    _steps.add(StepDraft());
    _title.addListener(_onFormChanged);
  }

  void _onFormChanged() => setState(() {});

  @override
  void dispose() {
    _title.removeListener(_onFormChanged);
    for (final c in [_title, _desc, _guideUrl, _resultUrl]) {
      c.dispose();
    }
    for (final s in _steps) {
      s.dispose();
    }
    for (final r in _resources) {
      r.dispose();
    }
    super.dispose();
  }

  void _resetForm() {
    _title.clear();
    _desc.clear();
    _guideUrl.clear();
    _resultUrl.clear();
    _guideFile.value = null;
    _resultFile.value = null;
    _thumbnail = null;
    for (final s in _steps) {
      s.dispose();
    }
    _steps
      ..clear()
      ..add(StepDraft());
    for (final r in _resources) {
      r.dispose();
    }
    _resources.clear();
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
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
    try {
      final user = AuthService.instance.currentUser!;
      String? thumbPath;
      if (_thumbnail != null) {
        thumbPath = await FileService.instance.saveUpload(
          src: _thumbnail!,
          subfolder: 'uploads/thumbnails',
          prefix: 'tut',
          maxBytes: kThumbnailMaxBytes,
        );
      }
      String? guideFilePath;
      if (_guideFile.value != null) {
        guideFilePath = await FileService.instance.saveUpload(
          src: _guideFile.value!,
          subfolder: 'uploads/videos',
          prefix: 'guide',
          maxBytes: kVideoMaxBytes,
        );
      }
      String? resultFilePath;
      if (_resultFile.value != null) {
        resultFilePath = await FileService.instance.saveUpload(
          src: _resultFile.value!,
          subfolder: 'uploads/videos',
          prefix: 'result',
          maxBytes: kVideoMaxBytes,
        );
      }

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

      await TutorialService.instance.createTutorial(
        userId: user.userId!,
        title: _title.text.trim(),
        description: _desc.text.trim(),
        category: _category,
        thumbnailPath: thumbPath,
        guideVideoUrl:
            _guideUrl.text.trim().isEmpty ? null : _guideUrl.text.trim(),
        guideVideoFile: guideFilePath,
        resultVideoUrl:
            _resultUrl.text.trim().isEmpty ? null : _resultUrl.text.trim(),
        resultVideoFile: resultFilePath,
        steps: cleanedSteps,
        resources: resources,
      );

      if (!mounted) return;
      Toast.show(context, 'Tutorial published!');
      _resetForm();
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Discard tutorial?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Your progress will be lost.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Discard',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      _resetForm();
      if (mounted) Navigator.of(context).pop(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const SectionTitle('Add Tutorial', accent: true),
          const SizedBox(height: 6),
          const Text(
            'Share your knowledge and help fellow creators build amazing motion designs.',
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 20),
          _tipsCard(),
          const SizedBox(height: 20),
          _sectionLabel('Basic Info'),
          _sectionCard(
            children: [
              LabeledField(
                  label: 'Tutorial Title',
                  hintText: 'e.g. Smooth Camera Movement',
                  controller: _title,
                  maxLength: 255),
              const SizedBox(height: 16),
              _categoryDropdown(),
              const SizedBox(height: 16),
              ThumbnailPicker(
                file: _thumbnail,
                onPick: (f) => setState(() => _thumbnail = f),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel('Description'),
          _sectionCard(
            children: [
              LabeledField(
                  label: 'Short Description',
                  hintText:
                      'Briefly describe what they will learn (max 282 chars).',
                  controller: _desc,
                  maxLines: 4,
                  maxLength: 282),
            ],
          ),
          const SizedBox(height: 20),
          _sectionLabel('Media'),
          _sectionCard(
            children: [
              VideoSourcePicker(
                  title: 'Guiding Video — shows how to do it',
                  urlController: _guideUrl,
                  fileNotifier: _guideFile),
              const SizedBox(height: 16),
              VideoSourcePicker(
                  title: 'Result Video — shows the final outcome',
                  urlController: _resultUrl,
                  fileNotifier: _resultFile),
            ],
          ),
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
          _sectionLabel('Preview'),
          _previewCard(),
          const SizedBox(height: 24),
          if (_error != null) ...[
            ErrorBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          PillButton(
              label: 'Submit Tutorial', onPressed: _submit, loading: _busy),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PillButton(
                  label: 'Clear',
                  outlined: true,
                  onPressed: _resetForm,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PillButton(
                  label: 'Cancel',
                  outlined: true,
                  danger: true,
                  onPressed: _cancel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _tipsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline,
                  size: 16, color: AppColors.accent),
              SizedBox(width: 8),
              Text('Submission Tips',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      fontSize: 13)),
            ],
          ),
          SizedBox(height: 6),
          Text(
              '• Keep titles short and searchable.\n'
              '• Break it down into 3–10 clear steps.\n'
              '• Add preset files (.xml / drive links) in Resources.',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.5)),
        ],
      ),
    );
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
                  setState(() => _category = v ?? 'Beginner'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewCard() {
    final hasThumb = _thumbnail != null;
    final title = _title.text.trim().isEmpty
        ? 'Tutorial Title'
        : _title.text.trim();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: hasThumb
                ? Image.file(_thumbnail!, fit: BoxFit.cover)
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accentForCategory(_category)
                              .withValues(alpha: 0.55),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _category,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}