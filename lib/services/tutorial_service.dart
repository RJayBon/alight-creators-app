import 'package:sqflite/sqflite.dart';

import '../models/tutorial.dart';
import 'database_service.dart';

class TutorialService {
  TutorialService._();
  static final TutorialService instance = TutorialService._();

  // ---------- READ ----------

  Future<Tutorial?> getById(int id) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery('''
      SELECT t.*, u.full_name AS author_name, u.username AS author_username,
             u.avatar_path AS author_avatar
      FROM tutorials t
      LEFT JOIN users u ON t.user_id = u.user_id
      WHERE t.tutorial_id = ?
    ''', [id]);
    return rows.isEmpty ? null : Tutorial.fromMap(rows.first);
  }

  Future<List<Tutorial>> listByCategory(String category) async {
    final db = await DatabaseService.instance.database;
    final List<Map<String, Object?>> rows;
    if (category == 'All') {
      rows = await db.rawQuery(
          'SELECT * FROM tutorials ORDER BY created_at DESC');
    } else {
      rows = await db.rawQuery(
          'SELECT * FROM tutorials WHERE category = ? ORDER BY created_at DESC',
          [category]);
    }
    return rows.map(Tutorial.fromMap).toList();
  }

  Future<List<Tutorial>> search(String q) async {
    final db = await DatabaseService.instance.database;
    final like = '%$q%';
    final rows = await db.rawQuery('''
      SELECT * FROM tutorials
      WHERE title LIKE ? OR description LIKE ? OR category LIKE ?
      ORDER BY created_at DESC
    ''', [like, like, like]);
    return rows.map(Tutorial.fromMap).toList();
  }

  Future<List<Tutorial>> listByUser(int userId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('tutorials',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
    return rows.map(Tutorial.fromMap).toList();
  }

  Future<List<Tutorial>> recommended({int limit = 5}) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery('''
      SELECT t.*,
             COALESCE(AVG(r.quality_rating), 0) AS avg_quality,
             COALESCE(AVG(r.clarity_rating), 0) AS avg_clarity,
             COALESCE((AVG(r.quality_rating) + AVG(r.clarity_rating)) / 2, 0) AS avg_score,
             COUNT(r.rating_id) AS rating_count
      FROM tutorials t
      LEFT JOIN tutorial_ratings r ON t.tutorial_id = r.tutorial_id
      GROUP BY t.tutorial_id
      ORDER BY avg_score DESC, rating_count DESC, t.views DESC, t.created_at DESC
      LIMIT $limit
    ''');
    return rows.map(Tutorial.fromMap).toList();
  }

  Future<List<Tutorial>> latest({int limit = 5}) async {
    final db = await DatabaseService.instance.database;
    final rows =
        await db.rawQuery('SELECT * FROM tutorials ORDER BY created_at DESC LIMIT $limit');
    return rows.map(Tutorial.fromMap).toList();
  }

  Future<List<Tutorial>> popular({int limit = 6, int? excludeId}) async {
    final db = await DatabaseService.instance.database;
    final where = excludeId != null ? 'WHERE tutorial_id != $excludeId' : '';
    final rows = await db.rawQuery(
        'SELECT * FROM tutorials $where ORDER BY views DESC LIMIT $limit');
    return rows.map(Tutorial.fromMap).toList();
  }

  Future<List<TutorialStep>> stepsFor(int tutorialId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('tutorial_steps',
        where: 'tutorial_id = ?',
        whereArgs: [tutorialId],
        orderBy: 'step_number ASC');
    return rows.map(TutorialStep.fromMap).toList();
  }

  Future<List<TutorialResource>> resourcesFor(int tutorialId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('tutorial_resources',
        where: 'tutorial_id = ?',
        whereArgs: [tutorialId],
        orderBy: 'resource_id ASC');
    return rows.map(TutorialResource.fromMap).toList();
  }

  // ---------- VIEWS ----------

  Future<void> recordView({
    required int tutorialId,
    required int authorId,
    required int viewerId,
  }) async {
    if (authorId == viewerId) return;
    final db = await DatabaseService.instance.database;
    final existing = await db.query('tutorial_views',
        where: 'tutorial_id = ? AND user_id = ?',
        whereArgs: [tutorialId, viewerId],
        limit: 1);
    if (existing.isNotEmpty) return;
    await db.insert('tutorial_views', {
      'tutorial_id': tutorialId,
      'user_id': viewerId,
      'viewed_at': DateTime.now().toIso8601String(),
    });
    await db.rawUpdate(
        'UPDATE tutorials SET views = views + 1 WHERE tutorial_id = ?',
        [tutorialId]);
  }

  // ---------- RATINGS ----------

  Future<({int total, double avgQuality, double avgClarity})>
      ratingStats(int tutorialId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS total,
             AVG(quality_rating) AS avg_q,
             AVG(clarity_rating) AS avg_c
      FROM tutorial_ratings WHERE tutorial_id = ?
    ''', [tutorialId]);
    final r = rows.first;
    return (
      total: (r['total'] as int?) ?? 0,
      avgQuality: (r['avg_q'] as num?)?.toDouble() ?? 0,
      avgClarity: (r['avg_c'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<({int quality, int clarity})?> userRating({
    required int tutorialId,
    required int userId,
  }) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query('tutorial_ratings',
        where: 'tutorial_id = ? AND user_id = ?',
        whereArgs: [tutorialId, userId],
        limit: 1);
    if (rows.isEmpty) return null;
    return (
      quality: (rows.first['quality_rating'] as int?) ?? 0,
      clarity: (rows.first['clarity_rating'] as int?) ?? 0,
    );
  }

  Future<void> upsertRating({
    required int tutorialId,
    required int userId,
    required int quality,
    required int clarity,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.insert(
      'tutorial_ratings',
      {
        'tutorial_id': tutorialId,
        'user_id': userId,
        'quality_rating': quality,
        'clarity_rating': clarity,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ---------- CREATE / UPDATE / DELETE ----------

  Future<int> createTutorial({
    required int userId,
    required String title,
    required String description,
    required String category,
    String? thumbnailPath,
    String? guideVideoUrl,
    String? guideVideoFile,
    String? resultVideoUrl,
    String? resultVideoFile,
    required List<TutorialStep> steps,
    required List<TutorialResource> resources,
  }) async {
    final db = await DatabaseService.instance.database;
    return db.transaction<int>((txn) async {
      final id = await txn.insert('tutorials', {
        'user_id': userId,
        'title': title,
        'description': description,
        'category': category,
        'thumbnail_path': thumbnailPath,
        'guide_video_url': guideVideoUrl,
        'guide_video_file': guideVideoFile,
        'result_video_url': resultVideoUrl,
        'result_video_file': resultVideoFile,
        'views': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (var i = 0; i < steps.length; i++) {
        final s = steps[i];
        await txn.insert('tutorial_steps', {
          'tutorial_id': id,
          'step_number': i + 1,
          'step_title': s.stepTitle,
          'step_description': s.stepDescription,
        });
      }
      for (final r in resources) {
        await txn.insert('tutorial_resources', {
          'tutorial_id': id,
          'resource_type': r.resourceType,
          'resource_name': r.resourceName,
          'resource_url': r.resourceUrl,
        });
      }
      return id;
    });
  }

  Future<void> updateTutorial({
    required int tutorialId,
    required int userId,
    required String title,
    required String description,
    required String category,
    required Map<String, dynamic> extraFields,
    required List<TutorialStep> steps,
    required List<TutorialResource> resources,
  }) async {
    final db = await DatabaseService.instance.database;
    await db.transaction((txn) async {
      await txn.update(
        'tutorials',
        {
          'title': title,
          'description': description,
          'category': category,
          ...extraFields,
        },
        where: 'tutorial_id = ? AND user_id = ?',
        whereArgs: [tutorialId, userId],
      );
      await txn.delete('tutorial_steps',
          where: 'tutorial_id = ?', whereArgs: [tutorialId]);
      for (var i = 0; i < steps.length; i++) {
        final s = steps[i];
        await txn.insert('tutorial_steps', {
          'tutorial_id': tutorialId,
          'step_number': i + 1,
          'step_title': s.stepTitle,
          'step_description': s.stepDescription,
        });
      }
      await txn.delete('tutorial_resources',
          where: 'tutorial_id = ?', whereArgs: [tutorialId]);
      for (final r in resources) {
        await txn.insert('tutorial_resources', {
          'tutorial_id': tutorialId,
          'resource_type': r.resourceType,
          'resource_name': r.resourceName,
          'resource_url': r.resourceUrl,
        });
      }
    });
  }

  Future<void> deleteTutorial(int tutorialId) async {
    final db = await DatabaseService.instance.database;
    await db.delete('tutorials',
        where: 'tutorial_id = ?', whereArgs: [tutorialId]);
  }
}