import 'package:flutter/material.dart';

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

  Color get accent => _accentFor(category);

  static Color _accentFor(String c) {
    switch (c) {
      case 'Beginner':      return const Color(0xFF2DD4BF);
      case 'Intermediate':  return const Color(0xFFA78BFA);
      case 'Advanced':      return const Color(0xFFF472B6);
      case 'Tips & Tricks': return const Color(0xFF38BDF8);
      default:              return const Color(0xFF00D2FF);
    }
  }

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
        tutorialId: m['tutorial_id'] as int?,
        userId: m['user_id'] as int?,
        title: (m['title'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'Beginner',
        thumbnailPath: m['thumbnail_path'] as String?,
        guideVideoUrl: m['guide_video_url'] as String?,
        guideVideoFile: m['guide_video_file'] as String?,
        resultVideoUrl: m['result_video_url'] as String?,
        resultVideoFile: m['result_video_file'] as String?,
        views: (m['views'] as int?) ?? 0,
        createdAt: m['created_at'] as String?,
        authorName: m['author_name'] as String?,
        authorUsername: m['author_username'] as String?,
        authorAvatar: m['author_avatar'] as String?,
        ratingCount: (m['rating_count'] as int?) ?? 0,
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
        'tutorial_id': tutorialId,
        'step_number': stepNumber,
        'step_title': stepTitle,
        'step_description': stepDescription,
      };

  factory TutorialStep.fromMap(Map<String, dynamic> m) => TutorialStep(
        stepId: m['step_id'] as int?,
        tutorialId: m['tutorial_id'] as int?,
        stepNumber: (m['step_number'] as int?) ?? 0,
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
  String resourceType; // 'preset' | 'asset'
  String resourceName;
  String resourceUrl;

  bool get isPreset => resourceType == 'preset';

  Map<String, dynamic> toMap() => {
        if (resourceId != null) 'resource_id': resourceId,
        'tutorial_id': tutorialId,
        'resource_type': resourceType,
        'resource_name': resourceName,
        'resource_url': resourceUrl,
      };

  factory TutorialResource.fromMap(Map<String, dynamic> m) => TutorialResource(
        resourceId: m['resource_id'] as int?,
        tutorialId: m['tutorial_id'] as int?,
        resourceType: (m['resource_type'] as String?) ?? 'preset',
        resourceName: (m['resource_name'] as String?) ?? '',
        resourceUrl: (m['resource_url'] as String?) ?? '',
      );
}

class TutorialRating {
  TutorialRating({
    required this.tutorialId,
    required this.userId,
    required this.quality,
    required this.clarity,
  });

  int tutorialId;
  int userId;
  int quality;
  int clarity;
}