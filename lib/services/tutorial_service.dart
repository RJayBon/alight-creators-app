import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../models/tutorial.dart';
import 'database_service.dart';
import 'file_service.dart';

/// Tutorial CRUD + the read-side aggregation used by every list screen.
///
/// FIXES vs. the previous version:
///  1. `LIMIT $limit` and `tutorial_id != $excludeId` were interpolated
///     straight into the SQL text. They are ints today so nothing was
///     exploitable, but one call-site refactor with a String would be. All
///     values are bound now.
///  2. `search()` built `'%$q%'` without escaping LIKE metacharacters, so a
///     query containing `%` or `_` matched far more than intended (and a
///     lone `%` matched everything).
///  3. Every list query now joins `users` for the author columns. Only
///     `getById` did before, so `Tutorial.authorName`/`authorAvatar` were
///     silently null for anything that came from a list — the detail screen's
///     "More from this creator" strip and any card that renders the author
///     were showing fallbacks for data that was simply never fetched.
///  4. `recordView` no longer throws into the detail screen's `initState`
///     path; a failed view-count write is not worth a red screen.
class TutorialService {
  TutorialService._();
  static final TutorialService instance = TutorialService._();

  /// Shared projection so every list carries the same columns
  /// `Tutorial.fromMap` expects.
  static const String _selectWithAuthor = '''
    SELECT t.*,
           u.full_name     AS author_name,
           u.username      AS author_username,
           u.avatar_path   AS author_avatar,
           COALESCE(AVG(r.quality_rating), 0) AS avg_quality,
           COALESCE(AVG(r.clarity_rating), 0) AS avg_clarity,
           COUNT(r.rating_id)                 AS rating_count
    FROM tutorials t
    LEFT JOIN users u            ON u.user_id = t.user_id
    LEFT JOIN tutorial_ratings r ON r.tutorial_id = t.tutorial_id
  ''';

  // ---------- READ ----------

  Future<Tutorial?> getById(int id) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      '$_selectWithAuthor WHERE t.tutorial_id = ? GROUP BY t.tutorial_id',
      [id],
    );
    return rows.isEmpty ? null : Tutorial.fromMap(rows.first);
  }

  Future<List<Tutorial>> listByCategory(String category) async {
    final db = await DatabaseService.instance.database;
    final rows = category == 'All'
        ? await db.rawQuery(
            '$_selectWithAuthor GROUP BY t.tutorial_id '
            'ORDER BY t.created_at DESC',
          )
        : await db.rawQuery(
            '$_selectWithAuthor WHERE t.category = ? GROUP BY t.tutorial_id '
            'ORDER BY t.created_at DESC',
            [category],
          );
    return rows.map(Tutorial.fromMap).toList();
  }

  Future<List<Tutorial>> search(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return listByCategory('All');
    final db = await DatabaseService.instance.database;
    // Escape the LIKE wildcards, and pick a backslash escape char so that
    // "100% done" searches for a literal percent instead of matching all rows.
    final escaped =
        trimmed.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
    final like = '%$escaped%';
    final rows = await db.rawQuery(
      '''
      $_selectWithAuthor
      WHERE t.title LIKE ? ESCAPE '\\'
         OR t.description LIKE ? ESCAPE '\\'
         OR t.category LIKE ? ESCAPE '\\'
      GROUP BY t.tutorial_id
      ORDER BY t.created_at DESC
      LIMIT ?
      ''',
      [like, like, like, 100],
    );
    return rows.map(Tutorial.fromMap).toList();
  }

  Future<List<Tutorial>> listByUser(int userId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      '$_selectWithAuthor WHERE t.user_id = ? GROUP BY t.tutorial_id '
      'ORDER BY t.created_at DESC',
      [userId],
    );
    return rows.map(Tutorial.fromMap).toList();
  }

  /// Highest rated first, falling back to views then recency. Only tutorials
  /// with a rating or a real thumbnail are eligible, so a content-less row
  /// can't occupy the featured rail.
  Future<List<Tutorial>> recommended({int limit = 5, int? excludeId}) async {
    final db = await DatabaseService.instance.database;
    final args = <Object?>[];
    var where = 'WHERE t.thumbnail_path IS NOT NULL';
    if (excludeId != null) {
      where = '$where AND t.tutorial_id != ?';
      args.add(excludeId);
    }
    args.add(limit.clamp(1, 50));
    final rows = await db.rawQuery(
      '''
      $_selectWithAuthor
      $where
      GROUP BY t.tutorial_id
      ORDER BY avg_quality DESC, rating_count DESC, t.views DESC, t.created_at DESC
      LIMIT ?
      ''',
      args,
    );
    return rows.map(Tutorial.fromMap).toList();
  }

  Future<List<Tutorial>> latest({int limit = 5}) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.rawQuery(
      '$_selectWithAuthor GROUP BY t.tutorial_id '
      'ORDER BY t.created_at DESC LIMIT ?',
      [limit.clamp(1, 50)],
    );
    return rows.map(Tutorial.fromMap).toList();
  }

  Future<List<Tutorial>> popular({int limit = 6, int? excludeId}) async {
    final db = await DatabaseService.instance.database;
    final rows = excludeId == null
        ? await db.rawQuery(
            '$_selectWithAuthor GROUP BY t.tutorial_id '
            'ORDER BY t.views DESC LIMIT ?',
            [limit.clamp(1, 50)],
          )
        : await db.rawQuery(
            '$_selectWithAuthor WHERE t.tutorial_id != ? '
            'GROUP BY t.tutorial_id ORDER BY t.views DESC LIMIT ?',
            [excludeId, limit.clamp(1, 50)],
          );
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
    // Authors don't inflate their own counters.
    if (authorId == viewerId) return;
    try {
      final db = await DatabaseService.instance.database;
      await db.transaction((txn) async {
        // Insert-first with the UNIQUE(tutorial_id, user_id) index does the
        // "count once per user" check atomically; the old
        // SELECT-then-INSERT pair had a TOCTOU window (two screens open on
        // the same tutorial could double count).
        final inserted = await txn.insert(
          'tutorial_views',
          {
            'tutorial_id': tutorialId,
            'user_id': viewerId,
            'viewed_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        if (inserted == 0) return; // already counted for this viewer
        await txn.rawUpdate(
          'UPDATE tutorials SET views = views + 1 WHERE tutorial_id = ?',
          [tutorialId],
        );
      });
    } catch (e, st) {
      // A view counter is not worth an error screen.
      debugPrint('recordView failed: $e\n$st');
    }
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
        // Clamp before the NOT NULL CHECK sees them — an out-of-range value
        // used to throw a raw SQLite constraint error at the caller.
        'quality_rating': quality.clamp(1, 5),
        'clarity_rating': clarity.clamp(1, 5),
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
        'title': title.trim(),
        'description': description.trim(),
        'category': category,
        'thumbnail_path': thumbnailPath,
        'guide_video_url': _blankToNull(guideVideoUrl),
        'guide_video_file': _blankToNull(guideVideoFile),
        'result_video_url': _blankToNull(resultVideoUrl),
        'result_video_file': _blankToNull(resultVideoFile),
        'views': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      for (var i = 0; i < steps.length; i++) {
        final s = steps[i];
        await txn.insert('tutorial_steps', {
          'tutorial_id': id,
          'step_number': i + 1,
          'step_title': s.stepTitle.trim(),
          'step_description': s.stepDescription.trim(),
        });
      }
      for (final r in resources) {
        await txn.insert('tutorial_resources', {
          'tutorial_id': id,
          'resource_type': r.resourceType,
          'resource_name': r.resourceName.trim(),
          'resource_url': r.resourceUrl.trim(),
        });
      }
      return id;
    });
  }

  /// Returns false when the row was already gone or belongs to someone else
  /// (the old void-returning version reported success either way, so the UI
  /// popped back to a list that still contained the tutorial).
  Future<bool> updateTutorial({
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
    return db.transaction<bool>((txn) async {
      final changed = await txn.update(
        'tutorials',
        {
          'title': title.trim(),
          'description': description.trim(),
          'category': category,
          ...extraFields,
        },
        where: 'tutorial_id = ? AND user_id = ?',
        whereArgs: [tutorialId, userId],
      );
      if (changed == 0) return false;

      await txn.delete('tutorial_steps',
          where: 'tutorial_id = ?', whereArgs: [tutorialId]);
      for (var i = 0; i < steps.length; i++) {
        final s = steps[i];
        await txn.insert('tutorial_steps', {
          'tutorial_id': tutorialId,
          'step_number': i + 1,
          'step_title': s.stepTitle.trim(),
          'step_description': s.stepDescription.trim(),
        });
      }
      await txn.delete('tutorial_resources',
          where: 'tutorial_id = ?', whereArgs: [tutorialId]);
      for (final r in resources) {
        await txn.insert('tutorial_resources', {
          'tutorial_id': tutorialId,
          'resource_type': r.resourceType,
          'resource_name': r.resourceName.trim(),
          'resource_url': r.resourceUrl.trim(),
        });
      }
      return true;
    });
  }

  /// The uploaded media belonging to a tutorial. Callers must delete the
  /// files *before* the row, because the row is the only record of which
  /// paths exist (this is what `UserService.deleteUser` does too).
  Future<Set<String>> mediaPathsFor(int tutorialId) async {
    final db = await DatabaseService.instance.database;
    final rows = await db.query(
      'tutorials',
      columns: const [
        'thumbnail_path',
        'guide_video_file',
        'result_video_file',
      ],
      where: 'tutorial_id = ?',
      whereArgs: [tutorialId],
      limit: 1,
    );
    if (rows.isEmpty) return const {};
    return {
      for (final v in rows.first.values)
        if (v is String && v.isNotEmpty) v,
    };
  }

  Future<bool> deleteTutorial(int tutorialId) async {
    final db = await DatabaseService.instance.database;
    // Steps/resources/ratings/views cascade via FK, but only if
    // `PRAGMA foreign_keys = ON` (see DatabaseService). Deleting here is
    // wrapped in a transaction so a partially-failed cascade can't strand
    // orphan rows.
    return db.transaction<bool>((txn) async {
      final changed = await txn.delete('tutorials',
          where: 'tutorial_id = ?', whereArgs: [tutorialId]);
      return changed > 0;
    });
  }

  /// Row + files. Returns false when the tutorial was already gone.
  Future<bool> deleteTutorialWithFiles(int tutorialId) async {
    final paths = await mediaPathsFor(tutorialId);
    final deleted = await deleteTutorial(tutorialId);
    if (paths.isNotEmpty) {
      await FileService.instance.deleteFiles(paths);
      FileService.instance.invalidateCache();
    }
    return deleted;
  }

  static String? _blankToNull(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}