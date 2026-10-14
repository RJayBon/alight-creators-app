import 'package:flutter/material.dart';

import '../utils/category_colors.dart';

class Tutorial {
  Tutorial({
    this.tutorialId,
    this.userId,
    required this.title,
    required this.description,
    required this.category,
    this.thumbnailPath,
    this.guideVideoUrl,
    this.guideVideoFile,
    this.resultVideoUrl,
    this.resultVideoFile,
    this.views = 0,
    this.createdAt,
    this.authorName,
    this.authorUsername,
    this.authorAvatar,
    this.ratingCount = 0,
    this.avgQuality = 0,
    this.avgClarity = 0,
  });

  int? tutorialId;
  int? userId;
  String title;
  String description;
  String category;
  String? thumbnailPath;
  String? guideVideoUrl;
  String? guideVideoFile;
  String? resultVideoUrl;
  String? resultVideoFile;
  int views;
  String? createdAt;

  // Joined metadata (not columns).
  String? authorName;
  String? authorUsername;
  String? authorAvatar;
  int ratingCount;
  double avgQuality;
  double avgClarity;

  /// Single source of truth for the category colour.
  ///
  /// This class used to carry its own private copy of the `accentForCategory`
  /// switch (identical at the time of writing). Two hand-maintained copies of
  /// the same mapping is how a palette drifts, so the duplicate is gone and
  /// `utils/category_colors.dart` is now the only definition.
  Color get accent => accentForCategory(category);

  double get avgScore => ratingCount == 0 ? 0 : (avgQuality + avgClarity) / 2;

  bool get hasGuideVideo =>
      (guideVideoFile?.isNotEmpty ?? false) ||
      (guideVideoUrl?.isNotEmpty ?? false);

  /// The finished result the creator attached. Until now only the *composer*
  /// read this (to offer removal) — `tutorial_detail_screen` rendered the guide
  /// clip and nothing else, so a viewer could not watch the result clip at all.
  bool get hasResultVideo =>
      (resultVideoFile?.isNotEmpty ?? false) ||
      (resultVideoUrl?.isNotEmpty ?? false);

  Map<String, dynamic> toMap() => {
        if (tutorialId != null) 'tutorial_id': tutorialId,
        'user_id': userId,
        'title': title,
        'description': description,
        'category': category,
        'thumbnail_path': thumbnailPath,
        'guide_video_url': guideVideoUrl,
        'guide_video_file': guideVideoFile,
        'result_video_url': resultVideoUrl,
        'result_video_file': resultVideoFile,
        'views': views,
        if (createdAt != null) 'created_at': createdAt,
      };

  factory Tutorial.fromMap(Map<String, dynamic> m) => Tutorial(
        tutorialId: (m['tutorial_id'] as num?)?.toInt(),
        userId: (m['user_id'] as num?)?.toInt(),
        title: (m['title'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'Beginner',
        thumbnailPath: m['thumbnail_path'] as String?,
        guideVideoUrl: m['guide_video_url'] as String?,
        guideVideoFile: m['guide_video_file'] as String?,
        resultVideoUrl: m['result_video_url'] as String?,
        resultVideoFile: m['result_video_file'] as String?,
        views: (m['views'] as num?)?.toInt() ?? 0,
        createdAt: m['created_at'] as String?,
        authorName: m['author_name'] as String?,
        authorUsername: m['author_username'] as String?,
        authorAvatar: m['author_avatar'] as String?,
        // Aggregate columns come back as REAL from AVG() and INTEGER from
        // COUNT(); a bare `as int` on a value SQLite stored as 4.0 throws a
        // ClassCastException that used to take the whole list down.
        ratingCount: (m['rating_count'] as num?)?.toInt() ?? 0,
        avgQuality: (m['avg_quality'] as num?)?.toDouble() ?? 0,
        avgClarity: (m['avg_clarity'] as num?)?.toDouble() ?? 0,
      );
}

class TutorialStep {
  TutorialStep({
    this.stepId,
    this.tutorialId,
    required this.stepNumber,
    required this.stepTitle,
    required this.stepDescription,
  });

  int? stepId;
  int? tutorialId;
  int stepNumber;
  String stepTitle;
  String stepDescription;

  Map<String, dynamic> toMap() => {
        if (stepId != null) 'step_id': stepId,
        if (tutorialId != null) 'tutorial_id': tutorialId,
        'step_number': stepNumber,
        'step_title': stepTitle,
        'step_description': stepDescription,
      };

  factory TutorialStep.fromMap(Map<String, dynamic> m) => TutorialStep(
        stepId: (m['step_id'] as num?)?.toInt(),
        tutorialId: (m['tutorial_id'] as num?)?.toInt(),
        stepNumber: (m['step_number'] as num?)?.toInt() ?? 0,
        stepTitle: (m['step_title'] as String?) ?? '',
        stepDescription: (m['step_description'] as String?) ?? '',
      );
}

class TutorialResource {
  TutorialResource({
    this.resourceId,
    this.tutorialId,
    required this.resourceType,
    required this.resourceName,
    required this.resourceUrl,
  });

  int? resourceId;
  int? tutorialId;
  String resourceType;
  String resourceName;
  String resourceUrl;

  bool get isPreset => resourceType == 'preset';

  Map<String, dynamic> toMap() => {
        if (resourceId != null) 'resource_id': resourceId,
        if (tutorialId != null) 'tutorial_id': tutorialId,
        'resource_type': resourceType,
        'resource_name': resourceName,
        'resource_url': resourceUrl,
      };

  factory TutorialResource.fromMap(Map<String, dynamic> m) => TutorialResource(
        resourceId: (m['resource_id'] as num?)?.toInt(),
        tutorialId: (m['tutorial_id'] as num?)?.toInt(),
        resourceType: (m['resource_type'] as num?)?.toInt() == null
            ? (m['resource_type'] as String?) ?? 'asset'
            : 'asset',
        resourceName: (m['resource_name'] as String?) ?? '',
        resourceUrl: (m['resource_url'] as String?) ?? '',
      );
}